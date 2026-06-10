import SwiftUI

@MainActor
final class AppState: ObservableObject {
    /// Остаток бесплатных объявлений по данным сервера (источник истины — воркер).
    /// nil — ещё не было ни одного ответа; -1 — Pro (безлимит).
    @Published var remainingFree: Int?
    @Published var showPaywall = false

    /// Soft-показ paywall один раз после первого успешного объявления.
    /// Возвращает true, если вызывающий экран должен показать paywall.
    func consumeFirstListingPaywallTrigger(isPro: Bool) -> Bool {
        guard !isPro else { return false }
        let key = "paywallShownAfterFirstListing"
        guard !UserDefaults.standard.bool(forKey: key) else { return false }
        UserDefaults.standard.set(true, forKey: key)
        return true
    }
}
