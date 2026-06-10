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
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Brand.forest, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    BrandMark(size: 18)
                    Text(draft.recognized ? "Listing draft" : "Try again")
                        .font(.headline)
                        .fontDesign(.rounded)
                        .foregroundStyle(.white)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .tint(Brand.mint)
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
        ScrollView {
            VStack(spacing: 12) {
                headerCard
                priceCard
                copyCard(label: "Title (\(formatted.title.count)/\(platform.titleLimit))", value: formatted.title)
                copyCard(label: "Description", value: formatted.description, lineLimit: 14)
                detailsCard
                if !draft.keywords.isEmpty {
                    copyCard(label: "Keywords", value: draft.keywords.joined(separator: ", "))
                }
                if draft.confidence == "low", let hint = draft.retryHint {
                    hintBanner(hint)
                }
                Text("Description is based on photos only. Verify authenticity of branded items separately before listing.")
                    .font(.caption2)
                    .foregroundStyle(Brand.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 8)
        }
        .background(Brand.paper.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            Button {
                copyAll()
            } label: {
                Label(
                    copiedField == "ALL" ? "Copied!" : "Copy all",
                    systemImage: copiedField == "ALL" ? "checkmark" : "doc.on.doc.fill"
                )
            }
            .buttonStyle(BrandPrimaryButtonStyle())
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .background(Brand.paper.opacity(0.96))
        }
    }

    private var headerCard: some View {
        HStack(alignment: .center, spacing: 10) {
            if let photo = photos.first {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 3) {
                FieldLabel(text: "Platform")
                // Переключение платформы — фича Pro; переформатирование локальное
                Picker("Platform", selection: platformBinding) {
                    ForEach(Platform.allCases) { p in
                        Text(p.displayName).tag(p)
                    }
                }
                .pickerStyle(.menu)
                .tint(Brand.emerald)
                .labelsHidden()
            }
            Spacer()
            Text(draft.conditionLabel)
                .font(.caption.weight(.semibold))
                .fontDesign(.rounded)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Brand.emerald.opacity(0.12), in: Capsule())
                .foregroundStyle(Brand.emerald)
        }
        .paperCard()
    }

    private var priceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    FieldLabel(text: "Price estimate")
                    Text(draft.priceRangeText)
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .foregroundStyle(Brand.ink)
                }
                Spacer()
                Image(systemName: "tag.fill")
                    .font(.title3)
                    .foregroundStyle(Brand.amber)
                    .rotationEffect(.degrees(-15))
            }
            Text(draft.priceRange.note)
                .font(.caption)
                .foregroundStyle(Brand.inkMuted)
            if !draft.soldCompsQuery.isEmpty {
                Divider().overlay(Brand.lineOnPaper)
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        FieldLabel(text: "Check sold comps")
                        Text(draft.soldCompsQuery)
                            .font(.footnote)
                            .foregroundStyle(Brand.ink)
                            .lineLimit(2)
                    }
                    Spacer()
                    copyButton(label: "Sold comps", value: draft.soldCompsQuery)
                }
            }
        }
        .padding(14)
        .background(Brand.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 16)
                .fill(Brand.amber)
                .frame(width: 4)
        }
        .shadow(color: Brand.ink.opacity(0.05), radius: 10, y: 3)
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 0) {
                if let brand = draft.brand {
                    BrandChipLabel(title: "Brand", value: brand)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let size = draft.size {
                    BrandChipLabel(title: "Size", value: size)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                BrandChipLabel(title: "Category", value: draft.category)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let materials = draft.materials {
                BrandChipLabel(title: "Materials", value: materials)
            }
            Divider().overlay(Brand.lineOnPaper)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    FieldLabel(text: "Condition")
                    Text("\(draft.conditionLabel). \(draft.conditionDetails)")
                        .font(.footnote)
                        .foregroundStyle(Brand.ink)
                }
                Spacer()
                copyButton(label: "Condition", value: "\(draft.conditionLabel). \(draft.conditionDetails)")
            }
        }
        .paperCard()
    }

    private func copyCard(label: String, value: String, lineLimit: Int = 6) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                FieldLabel(text: label)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(Brand.ink)
                    .lineLimit(lineLimit)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
            copyButton(label: label, value: value)
        }
        .paperCard()
    }

    private func copyButton(label: String, value: String) -> some View {
        Button {
            UIPasteboard.general.string = value
            onCopied(field: label, event: "copy_field")
        } label: {
            Image(systemName: copiedField == label ? "checkmark" : "doc.on.doc")
                .font(.subheadline.weight(.semibold))
                .frame(width: 34, height: 34)
                .background(
                    (copiedField == label ? Color.green : Brand.emerald).opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .foregroundStyle(copiedField == label ? .green : Brand.emerald)
        }
        .buttonStyle(.plain)
    }

    private func hintBanner(_ hint: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Brand.amber)
            Text(hint)
                .font(.footnote)
                .foregroundStyle(Brand.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Brand.amber.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                ViewfinderBrackets()
                    .stroke(Brand.amber, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 84, height: 84)
                Image(systemName: "questionmark")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Brand.amber)
            }
            Text("Couldn't read the item")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(Brand.ink)
            Text(draft.retryHint ?? "Retake the photos in better light and include the brand/size tag.")
                .font(.body)
                .foregroundStyle(Brand.inkMuted)
                .multilineTextAlignment(.center)
            Spacer()
            Button {
                dismiss() // фото сохранены в ScanView — добавит бирку и повторит
            } label: {
                Text(draft.retryHint != nil ? "Add the photo & retry" : "Retake photos")
            }
            .buttonStyle(BrandPrimaryButtonStyle())
        }
        .padding(28)
        .background(Brand.paper.ignoresSafeArea())
    }
}
