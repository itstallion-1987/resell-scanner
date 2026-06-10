import SwiftUI
import PhotosUI

struct ScanView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var purchases: PurchaseManager
    @StateObject private var camera = CameraService()

    @AppStorage("defaultPlatform") private var defaultPlatformRaw = Platform.ebay.rawValue
    @AppStorage("currency") private var currency = "USD"

    @State private var photos: [UIImage] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var note = ""
    @State private var showNoteInput = false
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var result: GenerateResponse?

    private var defaultPlatform: Platform {
        Platform(rawValue: defaultPlatformRaw) ?? .ebay
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.cameraDark.ignoresSafeArea()
                if camera.isAuthorized {
                    CameraPreview(session: camera.session)
                        .ignoresSafeArea()
                } else {
                    VStack(spacing: 16) {
                        TagMark(size: 40, color: Brand.paper.opacity(0.55))
                        Text("Camera unavailable")
                            .font(.headline)
                            .foregroundStyle(Brand.paper)
                        Text("Enable camera access in Settings, or pick photos from your library below.")
                            .font(.footnote)
                            .foregroundStyle(Brand.paper.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }

                // Рамка кадрирования — бумажно-белые уголки видоискателя
                if camera.isAuthorized {
                    ViewfinderBrackets(cornerLength: 0.12)
                        .stroke(Brand.paper.opacity(0.9), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .padding(.horizontal, 34)
                        .padding(.top, 130)
                        .padding(.bottom, 215)
                        .allowsHitTesting(false)
                }

                VStack(spacing: 8) {
                    if !purchases.isPro, let remaining = appState.remainingFree, remaining >= 0 {
                        freeBadge("FREE × \(remaining)")
                    }
                    if photos.count == 1 {
                        hintChip("Now add a photo of the brand/size tag — it boosts accuracy")
                    } else if photos.isEmpty {
                        hintChip("Take 1–3 photos: overall view, tag, flaws")
                    }
                    Spacer()
                    controls
                }
            }
            .overlay { if isGenerating { GenerationProgressView() } }
            .task { await camera.requestAccessAndStart() }
            .onDisappear { camera.stop() }
            // onDisappear НЕ вызывается при показе fullScreenCover — гасим камеру явно
            .onChange(of: result?.id) { _, newID in
                if newID != nil {
                    camera.stop()
                } else {
                    Task { await camera.requestAccessAndStart() }
                }
            }
            .onChange(of: pickerItems) { _, items in
                Task { await loadPickedPhotos(items) }
            }
            .fullScreenCover(item: $result) { response in
                NavigationStack {
                    ResultView(
                        draft: response.draft,
                        photos: photos,
                        isNew: true,
                        initialPlatform: defaultPlatform
                    )
                }
                .onDisappear {
                    // При нераспознавании оставляем фото — пользователь добавит бирку и повторит
                    if response.draft.recognized { photos = []; note = "" }
                }
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("Retry") { Task { await generate() } }
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("Note for the listing", isPresented: $showNoteInput) {
                TextField("e.g. bought last year, worn twice", text: $note)
                Button("Done") {}
                Button("Clear", role: .destructive) { note = "" }
            } message: {
                Text("Optional details the photos can't show — included in the generated draft.")
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 14) {
            if !photos.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 54, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(Brand.paper, lineWidth: 1.6)
                            )
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    photos.remove(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Brand.paper, Brand.ink.opacity(0.75))
                                }
                                .offset(x: 7, y: -7)
                            }
                    }
                    Spacer()
                }
                .padding(.horizontal, 18)
            }

            HStack(spacing: 0) {
                VStack(spacing: 10) {
                    Button {
                        showNoteInput = true
                    } label: {
                        Image(systemName: note.isEmpty ? "text.bubble" : "text.bubble.fill")
                            .font(.callout)
                            .frame(width: 38, height: 38)
                            .background(Brand.paper.opacity(note.isEmpty ? 0.16 : 0.92), in: Circle())
                            .foregroundStyle(note.isEmpty ? Brand.paper : Brand.ink)
                    }
                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: 3 - photos.count,
                        matching: .images
                    ) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title3)
                            .frame(width: 52, height: 52)
                            .background(Brand.paper.opacity(0.16), in: Circle())
                            .foregroundStyle(Brand.paper)
                    }
                    .disabled(photos.count >= 3)
                }
                .frame(maxWidth: .infinity)

                Button {
                    Task {
                        if let image = await camera.capture() {
                            photos.append(image)
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(Brand.paper, lineWidth: 4)
                            .frame(width: 78, height: 78)
                        Circle()
                            .fill(photos.count >= 3 ? Brand.paper.opacity(0.25) : Brand.stamp)
                            .frame(width: 62, height: 62)
                    }
                }
                .disabled(photos.count >= 3 || !camera.isAuthorized)
                .frame(maxWidth: .infinity)

                Button {
                    Task { await generate() }
                } label: {
                    Image(systemName: "sparkles")
                        .font(.title3.weight(.bold))
                        .frame(width: 52, height: 52)
                        .background(
                            photos.isEmpty ? AnyShapeStyle(Brand.paper.opacity(0.16)) : AnyShapeStyle(Brand.paper),
                            in: Circle()
                        )
                        .foregroundStyle(photos.isEmpty ? Brand.paper.opacity(0.5) : Brand.ink)
                }
                .disabled(photos.isEmpty || isGenerating)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 18)
        }
        .background(
            LinearGradient(
                colors: [.clear, Brand.ink.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
        )
    }

    private func hintChip(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.medium))
            .foregroundStyle(Brand.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Brand.ticket.opacity(0.95))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Brand.ink, lineWidth: 1.2))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .padding(.horizontal, 30)
            .padding(.top, 8)
    }

    private func freeBadge(_ text: String) -> some View {
        Button {
            appState.showPaywall = true
        } label: {
            Text(text)
                .font(.caption.weight(.bold))
                .kerning(1.4)
                .foregroundStyle(Brand.stamp)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Brand.ticket.opacity(0.95))
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Brand.stamp, lineWidth: 1.6))
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .rotationEffect(.degrees(-2))
        }
        .padding(.top, 10)
    }

    private func loadPickedPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            if photos.count >= 3 { break }
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                photos.append(image)
            }
        }
        pickerItems = []
    }

    private func generate() async {
        guard !photos.isEmpty, !isGenerating else { return }
        // Жёсткий триггер paywall: лимит Free исчерпан (по данным сервера)
        if !purchases.isPro, appState.remainingFree == 0 {
            Analytics.track("limit_reached", platform: defaultPlatform)
            appState.showPaywall = true
            return
        }
        errorMessage = nil
        isGenerating = true
        defer { isGenerating = false }
        do {
            let response = try await APIClient.generateListing(
                images: photos,
                platform: defaultPlatform,
                currency: currency,
                note: note.isEmpty ? nil : note,
                rcUserId: purchases.rcUserId
            )
            appState.remainingFree = response.meta.remainingFree
            result = response
        } catch APIError.freeLimitReached {
            appState.remainingFree = 0
            Analytics.track("limit_reached", platform: defaultPlatform)
            appState.showPaywall = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
