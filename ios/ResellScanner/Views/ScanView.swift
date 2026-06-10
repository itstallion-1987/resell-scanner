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
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var result: GenerateResponse?

    private var defaultPlatform: Platform {
        Platform(rawValue: defaultPlatformRaw) ?? .ebay
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: 0x10201C).ignoresSafeArea()
                if camera.isAuthorized {
                    CameraPreview(session: camera.session)
                        .ignoresSafeArea()
                } else {
                    VStack(spacing: 16) {
                        ZStack {
                            ViewfinderBrackets()
                                .stroke(Brand.mint.opacity(0.5), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .frame(width: 72, height: 72)
                            Image(systemName: "camera.fill")
                                .font(.title2)
                                .foregroundStyle(Brand.mint.opacity(0.6))
                        }
                        Text("Camera unavailable")
                            .font(.headline)
                            .fontDesign(.rounded)
                            .foregroundStyle(.white)
                        Text("Enable camera access in Settings, or pick photos from your library below.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }

                // Фирменные уголки видоискателя поверх превью
                if camera.isAuthorized {
                    ViewfinderBrackets(cornerLength: 0.12)
                        .stroke(Brand.mint.opacity(0.85), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                        .padding(.horizontal, 34)
                        .padding(.top, 130)
                        .padding(.bottom, 210)
                        .allowsHitTesting(false)
                }

                VStack(spacing: 8) {
                    if !purchases.isPro, let remaining = appState.remainingFree, remaining >= 0 {
                        freeBadge("\(remaining) of 5 free left")
                    }
                    if photos.count == 1 {
                        hintBanner("Now add a photo of the brand/size tag — it boosts accuracy")
                    } else if photos.isEmpty {
                        hintBanner("Take 1–3 photos: overall view, tag, flaws")
                    }
                    Spacer()
                    controls
                }
            }
            .overlay { if isGenerating { GenerationProgressView() } }
            .task { await camera.requestAccessAndStart() }
            .onDisappear { camera.stop() }
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
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Brand.mint, lineWidth: 1.5)
                            )
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    photos.remove(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white, .black.opacity(0.6))
                                }
                                .offset(x: 7, y: -7)
                            }
                    }
                    Spacer()
                }
                .padding(.horizontal, 18)
            }

            HStack(spacing: 0) {
                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: 3 - photos.count,
                    matching: .images
                ) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title3)
                        .frame(width: 52, height: 52)
                        .background(.white.opacity(0.12), in: Circle())
                        .foregroundStyle(.white)
                }
                .disabled(photos.count >= 3)
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
                            .strokeBorder(.white, lineWidth: 4)
                            .frame(width: 78, height: 78)
                        Circle()
                            .fill(photos.count >= 3 ? Color.white.opacity(0.25) : Brand.emerald)
                            .frame(width: 62, height: 62)
                    }
                }
                .disabled(photos.count >= 3 || !camera.isAuthorized)
                .frame(maxWidth: .infinity)

                Button {
                    Task { await generate() }
                } label: {
                    Image(systemName: "sparkles")
                        .font(.title3.weight(.semibold))
                        .frame(width: 52, height: 52)
                        .background(
                            photos.isEmpty ? AnyShapeStyle(.white.opacity(0.12)) : AnyShapeStyle(Brand.amber),
                            in: Circle()
                        )
                        .foregroundStyle(photos.isEmpty ? Color.white.opacity(0.5) : Brand.amberInk)
                }
                .disabled(photos.isEmpty || isGenerating)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 18)
        }
        .background(
            LinearGradient(
                colors: [.clear, Color(hex: 0x0A1714).opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
        )
    }

    private func hintBanner(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.medium))
            .fontDesign(.rounded)
            .foregroundStyle(Brand.forest)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Brand.paper.opacity(0.94), in: Capsule())
            .padding(.top, 8)
    }

    private func freeBadge(_ text: String) -> some View {
        Button {
            appState.showPaywall = true
        } label: {
            Label(text, systemImage: "sparkles")
                .font(.caption.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(Brand.mint)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Brand.mint.opacity(0.16), in: Capsule())
                .overlay(Capsule().strokeBorder(Brand.mint.opacity(0.5), lineWidth: 1))
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
