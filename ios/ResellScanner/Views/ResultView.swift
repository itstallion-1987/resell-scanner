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
    @State private var savedListing: Listing?
    @State private var copiedField: String?
    @State private var copyGeneration = UUID()

    init(draft: ListingDraft, photos: [UIImage], isNew: Bool, initialPlatform: Platform) {
        self.draft = draft
        self.photos = photos
        self.isNew = isNew
        _platform = State(initialValue: initialPlatform)
    }

    private var formatted: FormattedListing {
        PlatformFormatter.format(draft, for: platform)
    }

    // Без собственного NavigationStack: из истории — пуш, из ScanView — обёртка на месте cover
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
        .toolbarBackground(Brand.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    TagMark(size: 15)
                    Text("RESELL SCANNER").printLabel(Brand.ink)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .font(.subheadline.weight(.semibold))
                    .tint(Brand.stamp)
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
                receiptHeader
                priceTicket
                copyTicket(label: "Title · \(formatted.title.count)/\(platform.titleLimit)", value: formatted.title)
                copyTicket(label: "Description", value: formatted.description, lineLimit: 14)
                detailsTicket
                if !draft.keywords.isEmpty {
                    copyTicket(label: "Keywords", value: draft.keywords.joined(separator: ", "))
                }
                if draft.confidence == "low", let hint = draft.retryHint {
                    hintTicket(hint)
                }
                Text("* Description is based on photos only. Verify authenticity of branded items separately before listing.")
                    .font(.caption2)
                    .foregroundStyle(Brand.inkFaint)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(Brand.paper.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            Button {
                copyAll()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: copiedField == "ALL" ? "checkmark" : "doc.on.doc.fill")
                    Text(copiedField == "ALL" ? "Copied" : "Copy all")
                }
            }
            .buttonStyle(InkButtonStyle())
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .background(Brand.paper.opacity(0.97))
        }
    }

    private var receiptHeader: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                if let photo = photos.first {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 54, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Brand.ink, lineWidth: 1.2))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Marketplace").printLabel()
                    Picker("Platform", selection: platformBinding) {
                        ForEach(Platform.allCases) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Brand.ink)
                    .labelsHidden()
                }
                Spacer()
                StampLabel(text: draft.confidence == "high" ? "Ready" : "Check")
            }
            BarcodeView(seed: draft.title + draft.category, height: 18)
        }
        .ticketCard()
    }

    private var priceTicket: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Price estimate").printLabel()
                    Text(draft.priceRangeText).mono(30, weight: .bold)
                }
                Spacer()
                TagMark(size: 24, color: Brand.stamp)
            }
            Text(draft.priceRange.note)
                .font(.caption)
                .foregroundStyle(Brand.inkSoft)
            if !draft.soldCompsQuery.isEmpty {
                Perforation()
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Check sold comps").printLabel()
                        Text(draft.soldCompsQuery)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(Brand.ink)
                            .lineLimit(2)
                    }
                    Spacer()
                    copyButton(label: "Sold comps", value: draft.soldCompsQuery)
                }
            }
        }
        .ticketCard(holePunch: true)
    }

    private var detailsTicket: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 0) {
                if let brand = draft.brand {
                    detailColumn("Brand", brand)
                }
                if let size = draft.size {
                    detailColumn("Size", size)
                }
                detailColumn("Category", draft.category)
            }
            if let materials = draft.materials {
                detailColumn("Materials", materials)
            }
            Perforation()
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Condition").printLabel()
                    Text("\(draft.conditionLabel). \(draft.conditionDetails)")
                        .font(.footnote)
                        .foregroundStyle(Brand.ink)
                }
                Spacer()
                copyButton(label: "Condition", value: "\(draft.conditionLabel). \(draft.conditionDetails)")
            }
        }
        .ticketCard()
    }

    private func detailColumn(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).printLabel()
            Text(value)
                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .foregroundStyle(Brand.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func copyTicket(label: String, value: String, lineLimit: Int = 6) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text(label).printLabel()
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(Brand.ink)
                    .lineLimit(lineLimit)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
            copyButton(label: label, value: value)
        }
        .ticketCard()
    }

    private func copyButton(label: String, value: String) -> some View {
        Button {
            UIPasteboard.general.string = value
            onCopied(field: label, event: "copy_field")
        } label: {
            Image(systemName: copiedField == label ? "checkmark" : "doc.on.doc")
                .font(.subheadline.weight(.bold))
                .frame(width: 34, height: 34)
                .foregroundStyle(copiedField == label ? Brand.ticket : Brand.ink)
                .background(copiedField == label ? Brand.ink : Brand.ticket)
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Brand.ink, lineWidth: 1.3))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }

    private func hintTicket(_ hint: String) -> some View {
        HStack(spacing: 10) {
            StampLabel(text: "Tip", angle: 0)
            Text(hint)
                .font(.footnote)
                .foregroundStyle(Brand.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Brand.ticket)
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Brand.stamp, lineWidth: 1.3))
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private var platformBinding: Binding<Platform> {
        Binding(
            get: { platform },
            set: { newValue in
                guard newValue != platform else { return }
                if purchases.isPro {
                    platform = newValue
                    // История должна открываться в той же платформе, что видел пользователь
                    savedListing?.platformRaw = newValue.rawValue
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
        ReviewManager.registerSuccessfulCopy()
        ReviewManager.maybeRequestReview(requestReview)
    }

    private func flashCopied(_ field: String) {
        copiedField = field
        let generation = UUID()
        copyGeneration = generation
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if copyGeneration == generation { copiedField = nil }
        }
    }

    private func saveIfNeeded() {
        guard isNew, savedListing == nil, draft.recognized else { return }
        let thumbnail = photos.first?.resizedJPEG(maxDimension: 300, quality: 0.6)
        let listing = Listing(draft: draft, platform: platform, thumbnail: thumbnail)
        modelContext.insert(listing)
        savedListing = listing
    }

    // MARK: - Not recognized

    private var notRecognizedBody: some View {
        VStack(spacing: 22) {
            Spacer()
            VStack(spacing: 16) {
                TagMark(size: 44, color: Brand.inkFaint)
                StampLabel(text: "Void", angle: -8)
            }
            Text("Couldn't read the item")
                .font(.title2.weight(.heavy))
                .foregroundStyle(Brand.ink)
            Text(draft.retryHint ?? "Retake the photos in better light and include the brand/size tag.")
                .font(.body)
                .foregroundStyle(Brand.inkSoft)
                .multilineTextAlignment(.center)
            Spacer()
            Button {
                dismiss() // фото сохранены в ScanView — добавит бирку и повторит
            } label: {
                Text(draft.retryHint != nil ? "Add the photo & retry" : "Retake photos")
            }
            .buttonStyle(InkButtonStyle())
        }
        .padding(28)
        .background(Brand.paper.ignoresSafeArea())
    }
}
