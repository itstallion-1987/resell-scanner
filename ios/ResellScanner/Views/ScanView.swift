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
                if camera.isAuthorized {
                    CameraPreview(session: camera.session)
                        .ignoresSafeArea()
                } else {
                    ContentUnavailableView(
                        "Camera unavailable",
                        systemImage: "camera.fill",
                        description: Text("Enable camera access in Settings, or pick photos from your library below.")
                    )
                }
                VStack {
                    if photos.count == 1 {
                        hintBanner("Now add a photo of the brand/size tag — it boosts accuracy")
                    } else if photos.isEmpty {
                        hintBanner("Take 1–3 photos: overall view, tag, flaws")
                    }
                    Spacer()
                    controls
                }
            }
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
                .onDisappear { photos = []; note = "" }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            if !photos.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    photos.remove(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white, .black.opacity(0.6))
                                }
                                .offset(x: 6, y: -6)
                            }
                    }
                    Spacer()
                }
                .padding(.horizontal)
            }

            HStack(spacing: 24) {
                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: 3 - photos.count,
                    matching: .images
                ) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title2)
                        .frame(width: 56, height: 56)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .disabled(photos.count >= 3)

                Button {
                    Task {
                        if let image = await camera.capture() {
                            photos.append(image)
                        }
                    }
                } label: {
                    Circle()
                        .strokeBorder(.white, lineWidth: 4)
                        .frame(width: 76, height: 76)
                        .background(Circle().fill(.white.opacity(0.3)))
                }
                .disabled(photos.count >= 3 || !camera.isAuthorized)

                Button {
                    Task { await generate() }
                } label: {
                    if isGenerating {
                        ProgressView()
                            .frame(width: 56, height: 56)
                            .background(.ultraThinMaterial, in: Circle())
                    } else {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .frame(width: 56, height: 56)
                            .background(
                                photos.isEmpty ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.tint),
                                in: Circle()
                            )
                            .foregroundStyle(photos.isEmpty ? Color.secondary : Color.white)
                    }
                }
                .disabled(photos.isEmpty || isGenerating)
            }
            .padding(.bottom, 24)
        }
    }

    private func hintBanner(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.top, 12)
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
        // Жёсткий триггер paywall: лимит Free исчерпан (по данным сервера)
        if !purchases.isPro, appState.remainingFree == 0 {
            appState.showPaywall = true
            return
        }
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
            appState.showPaywall = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension GenerateResponse: Identifiable {
    var id: String { draft.title + draft.soldCompsQuery }
}
