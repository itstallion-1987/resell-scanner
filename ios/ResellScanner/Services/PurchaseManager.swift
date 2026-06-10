import Foundation
import RevenueCat

@MainActor
final class PurchaseManager: NSObject, ObservableObject {
    static let shared = PurchaseManager()

    @Published var isPro = false
    @Published var offerings: Offerings?

    private static let entitlementId = "pro"

    func configure() {
        // TODO: заменить на публичный (Apple) API-ключ проекта RevenueCat
        Purchases.configure(withAPIKey: "REPLACE_REVENUECAT_PUBLIC_API_KEY")
        Purchases.shared.delegate = self
        Task { await refresh() }
    }

    var rcUserId: String {
        Purchases.shared.appUserID
    }

    func refresh() async {
        if let info = try? await Purchases.shared.customerInfo() {
            apply(info)
        }
        offerings = try? await Purchases.shared.offerings()
    }

    func purchase(_ package: Package) async throws {
        let result = try await Purchases.shared.purchase(package: package)
        apply(result.customerInfo)
    }

    func restore() async {
        if let info = try? await Purchases.shared.restorePurchases() {
            apply(info)
        }
    }

    private func apply(_ info: CustomerInfo) {
        isPro = info.entitlements[Self.entitlementId]?.isActive == true
    }
}

extension PurchaseManager: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.apply(customerInfo)
        }
    }
}
