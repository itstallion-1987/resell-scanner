import SwiftUI
import SwiftData
import UIKit

struct ResultView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview
    @EnvironmentObject private var purchases: PurchaseManager
    @EnvironmentObject private var appState: AppState

    let draft: ListingDraft
    let photos: [UIImage]
    let isNew: Bool

    @State private var platform: Platform
    @State private var showPaywall = false
    @State private var saved = false
    @State private var copiedField: String?

    init(draft: ListingDraft, photos: [UIImage], isNew: Bool, initialPlatform: Platform) {
        self.draft = draft
        self.photos = photos
        self.isNew = isNew
        _platform = State(initialValue: initialPlatform)
    }

    private var formatted: FormattedListing {
        PlatformFormatter.format(draft, for: platform)
    }

    // Без собственного NavigationStack: из истории экран пушится в существующий стек,
    // из ScanView оборачивается в NavigationStack на месте показа fullScreenCover.
    var body: some View {
        Group {
            if draft.recognized {
                listingBody
            } else {
                notRecognizedBody
            }
        }
        .navigationTitle(draft.recognized ? "Listing draft" : "Try again")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .onAppear {
            saveIfNeeded()
            if isNew, appState.consumeFirstListingPaywallTrigger(isPro: purchases.isPro) {
                showPaywall = true
            }
        }
    }

    // MARK: - Recognized

    private var listingBody: some View {
        List {
            Section {
                // Переключение платформы — фича Pro; переформатирование локальное, без нового vision-вызова
                Picker("Platform", selection: platformBinding) {
                    ForEach(Platform.allCases) { p in
                        Text(p.displayName).tag(p)
                    }
                }
                .pickerStyle(.menu)
            }

            copyRow(label: "Title (\(formatted.title.count)/\(platform.titleLimit))", value: formatted.title)
            copyRow(label: "Description", value: formatted.description, lineLimit: 12)

            Section("Details") {
                if let brand = draft.brand { copyRow(label: "Brand", value: brand) }
                if let model = draft.model { copyRow(label: "Model", value: model) }
                copyRow(label: "Category", value: draft.category)
                if let size = draft.size { copyRow(label: "Size", value: size) }
                if let materials = draft.materials { copyRow(label: "Materials", value: materials) }
                copyRow(label: "Condition", value: "\(draft.conditionLabel). \(draft.conditionDetails)")
                if !draft.keywords.isEmpty {
                    copyRow(label: "Keywords", value: draft.keywords.joined(separator: ", "))
                }
            }

            Section("Price") {
                VStack(alignment: .leading, spacing: 4) {
                    Text(draft.priceRangeText).font(.title3.bold())
                    Text(draft.priceRange.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                copyRow(label: "Check sold comps", value: draft.soldCompsQuery)
            }

            if draft.confidence == "low", let hint = draft.retryHint {
                Section {
                    Label(hint, systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
            }

            Section {
                // Юридическая гигиена: описание по фото, без вердиктов подлинности
                Text("Description is based on photos only. Verify authenticity of branded items separately before listing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                copyAll()
            } label: {
                Label(
                    copiedField == "ALL" ? "Copied!" : "Copy all",
                    systemImage: copiedField == "ALL" ? "checkmark" : "doc.on.doc.fill"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.tint, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            .background(.bar)
        }
    }

    private var platformBinding: Binding<Platform> {
        Binding(
            get: { platform },
            set: { newValue in
                guard newValue != platform else { return }
                if purchases.isPro {
                    platform = newValue
                } else {
                    showPaywall = true // переключатель платформ — Pro
                }
            }
        )
    }

    private func copyRow(label: String, value: String, lineLimit: Int = 4) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body)
                    .lineLimit(lineLimit)
                    .textSelection(.enabled)
            }
            Spacer()
            Button {
                UIPasteboard.general.string = value
                onCopied(field: label, event: "copy_field")
            } label: {
                Image(systemName: copiedField == label ? "checkmark" : "doc.on.doc")
                    .foregroundStyle(copiedField == label ? .green : .accentColor)
            }
            .buttonStyle(.borderless)
        }
    }

    private func copyAll() {
        guard purchases.isPro else {
            showPaywall = true // «копировать всё» — Pro
            return
        }
        UIPasteboard.general.string = PlatformFormatter.copyAllText(draft, platform: platform)
        onCopied(field: "ALL", event: "copy_all")
    }

    private func onCopied(field: String, event: String) {
        flashCopied(field)
        Analytics.track(event, platform: platform)
        // Запрос отзыва в момент полученной ценности (после нескольких копирований)
        ReviewManager.registerSuccessfulCopy()
        ReviewManager.maybeRequestReview(requestReview)
    }

    private func flashCopied(_ field: String) {
        copiedField = field
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if copiedField == field { copiedField = nil }
        }
    }

    private func saveIfNeeded() {
        guard isNew, !saved, draft.recognized else { return }
        saved = true
        let thumbnail = photos.first?.resizedJPEG(maxDimension: 300, quality: 0.6)
        modelContext.insert(Listing(draft: draft, platform: platform, thumbnail: thumbnail))
    }

    // MARK: - Not recognized

    private var notRecognizedBody: some View {
        VStack(spacing: 20) {
            Image(systemName: "viewfinder.trianglebadge.exclamationmark")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
            Text("Couldn't read the item")
                .font(.title2.bold())
            Text(draft.retryHint ?? "Retake the photos in better light and include the brand/size tag.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                dismiss() // фото сохранены в ScanView — добавит бирку и повторит
            } label: {
                Text(draft.retryHint != nil ? "Add the photo & retry" : "Retake photos")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.tint, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
        }
        .padding(32)
    }
}
