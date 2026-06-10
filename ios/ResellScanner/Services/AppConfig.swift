import Foundation

/// Единая точка для всех внешних значений — перед сабмитом заменить плейсхолдеры
/// и прогнать: grep -r "YOUR-SUBDOMAIN\|REPLACE_\|YOUR-DOMAIN" ios/
enum AppConfig {
    static let workerBaseURL = URL(string: "https://resell-scanner-proxy.YOUR-SUBDOMAIN.workers.dev")!
    static let appToken = "REPLACE_APP_SHARED_SECRET"

    static let privacyPolicyURL = URL(string: "https://resell-scanner.YOUR-DOMAIN/privacy.html")!
    // Стандартная Apple EULA (если в App Store Connect не загружена своя)
    static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let supportEmail = "sane4ek07@gmail.com"

    /// Основной язык устройства (de, fr, pl…) для генерации описания на языке продавца.
    /// nil — сервер использует английский по умолчанию.
    static var deviceLanguage: String? {
        guard let pref = Locale.preferredLanguages.first else { return nil }
        return Locale(identifier: pref).language.languageCode?.identifier
    }
}
