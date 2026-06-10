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

    /// Экономия годового тарифа против 12× месячного — считается из реальных цен (любая валюта)
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
                Brand.forestGradient.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 22) {
                        header
                        featureList

                        if isLoading {
                            ProgressView("Loading plans…")
                                .tint(.white)
                                .foregroundStyle(.white.opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
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
                        .font(.footnote.weight(.medium))
                        .tint(Brand.mint)

                        legalFooter
                    }
                    .padding(.horizontal, 22)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.55))
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
            BrandMark(size: 52, color: Brand.amber)
                .padding(.top, 18)
            Text("Resell Scanner Pro")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
            if !purchases.isPro, appState.remainingFree == 0 {
                Text("You've used all 5 free listings.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Brand.amber)
            }
            Text("Pays for itself with one sale — a fraction of the $29+/mo crosslisting platforms, with no setup.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            feature("infinity", "Unlimited listings")
            feature("clock.arrow.circlepath", "Full listing history")
            feature("arrow.left.arrow.right", "Switch platforms on any draft")
            feature("doc.on.doc.fill", "Copy the whole listing in one tap")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var plans: some View {
        VStack(spacing: 10) {
            // Якорь — годовой тариф, на янтаре
            if let annual = annualPackage {
                purchaseButton(
                    package: annual,
                    badge: annualSavingsPercent.map { "Save \($0)% vs monthly" } ?? "Best value",
                    prominent: true
                )
            }
            if let monthly = monthlyPackage {
                purchaseButton(package: monthly, badge: nil, prominent: false)
            }
        }
    }

    private var loadFailedState: some View {
        VStack(spacing: 12) {
            Text("Couldn't load subscription options.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
            Button("Retry") {
                Task { await load() }
            }
            .buttonStyle(BrandGhostButtonStyle())
        }
        .padding(.vertical, 14)
    }

    private var legalFooter: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                Link("Privacy Policy", destination: AppConfig.privacyPolicyURL)
                Text("·").foregroundStyle(.white.opacity(0.4))
                Link("Terms of Use", destination: AppConfig.termsOfUseURL)
            }
            .font(.footnote)
            .tint(Brand.mint)

            Text("Payment is charged to your Apple ID. Subscription renews automatically unless cancelled at least 24 hours before the period ends. Manage in App Store settings.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(.bottom, 14)
        }
    }

    private func feature(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 28)
                .foregroundStyle(Brand.mint)
            Text(text)
                .font(.body.weight(.medium))
                .fontDesign(.rounded)
                .foregroundStyle(.white)
        }
    }

    private func purchaseButton(package: Package, badge: String?, prominent: Bool) -> some View {
        Button {
            Task { await purchase(package) }
        } label: {
            VStack(spacing: 2) {
                // Только реальная локализованная цена — никаких захардкоженных значений (3.1.2)
                Text("\(periodLabel(package)) · \(package.storeProduct.localizedPriceString)")
                if let badge {
                    Text(badge)
                        .font(.caption)
                        .fontDesign(.rounded)
                        .opacity(0.8)
                }
            }
        }
        .buttonStyle(
            prominent
                ? BrandPrimaryButtonStyle(fill: Brand.amber, textColor: Brand.amberInk)
                : BrandPrimaryButtonStyle(fill: .white.opacity(0.1), textColor: .white)
        )
        .disabled(isPurchasing)
        .overlay { if isPurchasing { ProgressView().tint(.white) } }
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
