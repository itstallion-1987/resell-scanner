import Foundation
import Security

/// Стабильный анонимный ID устройства в Keychain — переживает переустановку,
/// чтобы бесплатный лимит нельзя было сбросить удалением приложения.
///
/// Надёжность: значение резолвится ОДИН раз за запуск (static let — без гонок
/// и без повторных походов в Keychain), статусы различаются (errSecItemNotFound
/// vs транзиентная ошибка), результат SecItemAdd проверяется, дубликат — перечитывается.
enum DeviceID {
    private static let service = "resell-scanner.device-id"
    private static let account = "device"

    static let current: String = resolve()

    private static func resolve() -> String {
        switch read() {
        case .found(let value):
            return value
        case .notFound:
            let newId = UUID().uuidString.lowercased()
            let addStatus = save(newId)
            if addStatus == errSecSuccess { return newId }
            if addStatus == errSecDuplicateItem, case .found(let existing) = read() {
                return existing // параллельная запись успела раньше — берём её
            }
            return newId // Keychain недоступен — стабильный id хотя бы на этот запуск
        case .error:
            // Транзиентная ошибка (например, до первой разблокировки) — НЕ создаём
            // новую запись поверх существующей; временный id на один запуск
            return UUID().uuidString.lowercased()
        }
    }

    private enum ReadResult {
        case found(String)
        case notFound
        case error
    }

    private static func read() -> ReadResult {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
                return .error
            }
            return .found(value)
        case errSecItemNotFound:
            return .notFound
        default:
            return .error
        }
    }

    private static func save(_ value: String) -> OSStatus {
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(value.utf8),
            // ThisDeviceOnly: id не мигрирует через бэкап на другое устройство
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        return SecItemAdd(attributes as CFDictionary, nil)
    }
}
