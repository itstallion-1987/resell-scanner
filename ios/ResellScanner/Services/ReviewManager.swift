import SwiftUI
import StoreKit

/// Запрос отзыва в момент полученной ценности: после нескольких успешных копирований,
/// не чаще одного раза на версию приложения.
@MainActor
enum ReviewManager {
    private static let copyCountKey = "successfulCopyCount"
    private static let promptedVersionKey = "reviewPromptedVersion"
    private static let threshold = 3

    static func registerSuccessfulCopy() {
        let n = UserDefaults.standard.integer(forKey: copyCountKey) + 1
        UserDefaults.standard.set(n, forKey: copyCountKey)
    }

    static func maybeRequestReview(_ requestReview: RequestReviewAction) {
        guard UserDefaults.standard.integer(forKey: copyCountKey) >= threshold else { return }
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        guard UserDefaults.standard.string(forKey: promptedVersionKey) != version else { return }
        UserDefaults.standard.set(version, forKey: promptedVersionKey)
        requestReview()
    }
}
