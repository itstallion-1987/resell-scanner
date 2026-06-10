import Foundation

/// Единая точка для всех внешних значений — перед сабмитом заменить плейсхолдеры
/// и прогнать: grep -r "YOUR-SUBDOMAIN\|REPLACE_\|YOUR-DOMAIN" ios/
enum AppConfig {
    static let workerBaseURL = URL(string: "https://resell-scanner-proxy.sane4ek07.workers.dev")!

    /// Токен приложения для воркера. В публичный репозиторий настоящее значение не коммитим:
    /// оно подставляется при релизной сборке через build setting APP_SHARED_TOKEN
    /// (Info.plist ключ ниже). Без подстановки остаётся плейсхолдер — CI compile-check работает.
    static let appToken: String = {
        let v = Bundle.main.object(forInfoDictionaryKey: "APP_SHARED_TOKEN") as? String ?? ""
        return (v.isEmpty || v.hasPrefix("$(")) ? "REPLACE_APP_SHARED_SECRET" : v
    }()

    static let privacyPolicyURL = URL(string: "https://resell-scanner-site.pages.dev/privacy")!
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
