import Foundation
import Security

/// Стабильный анонимный ID устройства в Keychain — переживает переустановку,
/// чтобы бесплатный лимит нельзя было сбросить удалением приложения.
enum DeviceID {
    private static let service = "resell-scanner.device-id"
    private static let account = "device"

    static var current: String {
        if let existing = read() { return existing }
        let newId = UUID().uuidString.lowercased()
        save(newId)
        return newId
    }

    private static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return nil }
        return value
    }

    private static func save(_ value: String) {
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }
}
