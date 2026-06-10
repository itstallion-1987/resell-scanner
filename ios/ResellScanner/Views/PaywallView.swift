import SwiftUI
import RevenueCat

struct PaywallView: View {
    @EnvironmentObject private var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    @State private var isPurchasing = false
    @State private var errorMessage: String?

    private var annualPackage: Package? {
        purchases.offerings?.current?.annual
    }
    private var monthlyPackage: Package? {
        purchases.offerings?.current?.monthly
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 44))
                            .foregroundStyle(.tint)
                        Text("Resell Scanner Pro")
                            .font(.largeTitle.bold())
                        Text("A fraction of the price of crosslisting platforms — none of the setup.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    VStack(alignment: .leading, spacing: 14) {
                        feature("infinity", "Unlimited listings")
                        feature("clock.arrow.circlepath", "Full listing history")
                        feature("arrow.left.arrow.right", "Switch platforms on any draft")
                        feature("doc.on.doc.fill", "Copy the whole listing in one tap")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(AnyShapeStyle(.quaternary).opacity(0.5), in: RoundedRectangle(cornerRadius: 16))

                    VStack(spacing: 12) {
                        // Якорь — годовой тариф
                        purchaseButton(
                            package: annualPackage,
                            fallbackTitle: "Yearly — $39.99/year",
                            badge: "Best value · ~$3.33/mo",
                            prominent: true
                        )
                        purchaseButton(
                            package: monthlyPackage,
                            fallbackTitle: "Monthly — $6.99/month",
                            badge: nil,
                            prominent: false
                        )
                    }

                    Button("Restore purchases") {
                        Task {
                            await purchases.restore()
                            if purchases.isPro { dismiss() }
                        }
                    }
                    .font(.footnote)

                    Text("Payment is charged to your Apple ID. Subscription renews automatically unless cancelled at least 24 hours before the period ends. Manage in App Store settings.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
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
            .task { await purchases.refresh() }
        }
    }

    private func feature(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 28)
                .foregroundStyle(.tint)
            Text(text).font(.body.weight(.medium))
        }
    }

    private func purchaseButton(
        package: Package?,
        fallbackTitle: String,
        badge: String?,
        prominent: Bool
    ) -> some View {
        Button {
            guard let package else { return }
            Task { await purchase(package) }
        } label: {
            VStack(spacing: 2) {
                Text(package?.localizedTitleWithPrice ?? fallbackTitle)
                    .font(.headline)
                if let badge {
                    Text(badge)
                        .font(.caption)
                        .opacity(0.85)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                prominent ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .foregroundStyle(prominent ? Color.white : Color.primary)
        }
        .disabled(isPurchasing || package == nil)
        .overlay {
            if isPurchasing { ProgressView() }
        }
    }

    private func purchase(_ package: Package) async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await purchases.purchase(package)
            if purchases.isPro { dismiss() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension Package {
    var localizedTitleWithPrice: String {
        switch packageType {
        case .annual: "Yearly — \(localizedPriceString)/year"
        case .monthly: "Monthly — \(localizedPriceString)/month"
        default: "\(storeProduct.localizedTitle) — \(localizedPriceString)"
        }
    }
}
