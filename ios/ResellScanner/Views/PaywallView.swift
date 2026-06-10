import SwiftUI
import RevenueCat

struct PaywallView: View {
    @EnvironmentObject private var purchases: PurchaseManager
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var isPurchasing = false
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var errorMessage: String?

    private var annualPackage: Package? { purchases.offerings?.current?.annual }
    private var monthlyPackage: Package? { purchases.offerings?.current?.monthly }

    /// Экономия годового против 12× месячного — из реальных цен (любая валюта)
    private var annualSavingsPercent: Int? {
        guard let annual = annualPackage?.storeProduct.price,
              let monthly = monthlyPackage?.storeProduct.price,
              monthly > 0 else { return nil }
        let yearlyAtMonthly = monthly * 12
        guard yearlyAtMonthly > 0 else { return nil }
        let saved = (yearlyAtMonthly - annual) / yearlyAtMonthly
        let percent = Int(NSDecimalNumber(decimal: saved).doubleValue * 100)
        return percent > 0 ? percent : nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.paper.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        header
                        passTicket

                        if isLoading {
                            ProgressView("Loading plans…")
                                .tint(Brand.ink)
                                .foregroundStyle(Brand.inkSoft)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 22)
                        } else if loadFailed {
                            loadFailedState
                        } else {
                            plans
                        }

                        Button("Restore purchases") {
                            Task {
                                await purchases.restore()
                                if purchases.isPro { dismiss() }
                            }
                        }
                        .font(.footnote.weight(.semibold))
                        .tint(Brand.stamp)

                        legalFooter
                    }
                    .padding(.horizontal, 20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Brand.ink)
                    }
                }
            }
            .alert("Purchase failed", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .task { await load() }
            .onAppear { Analytics.track("paywall_shown") }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 10) {
            TagMark(size: 40, color: Brand.ink)
                .padding(.top, 8)
            Text("PRO PASS")
                .font(.system(size: 38, weight: .heavy))
                .kerning(2)
                .foregroundStyle(Brand.ink)
            if !purchases.isPro, appState.remainingFree == 0 {
                StampLabel(text: "5 of 5 free used", angle: -2)
            }
            Text("Pays for itself with one sale — a fraction of the $29+/mo crosslisting platforms, with no setup.")
                .font(.subheadline)
                .foregroundStyle(Brand.inkSoft)
                .multilineTextAlignment(.center)
        }
    }

    private var passTicket: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Admit one · reseller").printLabel()
            feature("infinity", "Unlimited listings")
            feature("clock.arrow.circlepath", "Full listing history")
            feature("arrow.left.arrow.right", "Switch platforms on any draft")
            feature("doc.on.doc.fill", "Copy the whole listing in one tap")
            Perforation()
            BarcodeView(seed: "resell-scanner-pro-pass", height: 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ticketCard(holePunch: true)
    }

    private var plans: some View {
        VStack(spacing: 10) {
            if let annual = annualPackage {
                ZStack(alignment: .topTrailing) {
                    purchaseButton(package: annual, prominent: true)
                    if let pct = annualSavingsPercent {
                        StampLabel(text: "Save \(pct)%", angle: 6)
                            .offset(x: -8, y: -10)
                    }
                }
            }
            if let monthly = monthlyPackage {
                purchaseButton(package: monthly, prominent: false)
            }
        }
    }

    private var loadFailedState: some View {
        VStack(spacing: 12) {
            Text("Couldn't load subscription options.")
                .font(.subheadline)
                .foregroundStyle(Brand.inkSoft)
            Button("Retry") {
                Task { await load() }
            }
            .buttonStyle(GhostInkButtonStyle())
        }
        .padding(.vertical, 12)
    }

    private var legalFooter: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                Link("Privacy Policy", destination: AppConfig.privacyPolicyURL)
                Text("·").foregroundStyle(Brand.inkFaint)
                Link("Terms of Use", destination: AppConfig.termsOfUseURL)
            }
            .font(.footnote)
            .tint(Brand.stamp)

            Text("Payment is charged to your Apple ID. Subscription renews automatically unless cancelled at least 24 hours before the period ends. Manage in App Store settings.")
                .font(.caption2)
                .foregroundStyle(Brand.inkFaint)
                .multilineTextAlignment(.center)
                .padding(.bottom, 14)
        }
    }

    private func feature(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .frame(width: 26)
                .foregroundStyle(Brand.stamp)
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Brand.ink)
        }
    }

    private func purchaseButton(package: Package, prominent: Bool) -> some View {
        Button {
            Task { await purchase(package) }
        } label: {
            // Только реальная локализованная цена — без захардкоженных значений (3.1.2)
            Text("\(periodLabel(package)) · \(package.storeProduct.localizedPriceString)")
        }
        .buttonStyle(
            prominent
                ? InkButtonStyle(fill: Brand.ink, textColor: Brand.ticket)
                : InkButtonStyle(fill: Brand.ticket, textColor: Brand.ink)
        )
        .overlay {
            if !prominent {
                RoundedRectangle(cornerRadius: 5).strokeBorder(Brand.ink, lineWidth: 1.4)
            }
        }
        .disabled(isPurchasing)
        .overlay { if isPurchasing { ProgressView().tint(prominent ? Brand.ticket : Brand.ink) } }
    }

    private func periodLabel(_ package: Package) -> String {
        switch package.packageType {
        case .annual: "Yearly"
        case .monthly: "Monthly"
        case .weekly: "Weekly"
        default: package.storeProduct.localizedTitle
        }
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        loadFailed = false
        await purchases.refresh()
        isLoading = false
        loadFailed = (annualPackage == nil && monthlyPackage == nil)
    }

    private func purchase(_ package: Package) async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await purchases.purchase(package)
            if purchases.isPro {
                Analytics.track("purchase", trigger: package.packageType == .annual ? "annual" : "monthly")
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
