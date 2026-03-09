import Foundation
import Security

final class KeychainManager {
    private let service = "com.invlog.app"

    private enum Key: String {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }

    // MARK: - Access Token

    func saveAccessToken(_ token: String) {
        save(key: Key.accessToken.rawValue, value: token)
    }

    func getAccessToken() -> String? {
        load(key: Key.accessToken.rawValue)
    }

    // MARK: - Refresh Token

    func saveRefreshToken(_ token: String) {
        save(key: Key.refreshToken.rawValue, value: token)
    }

    func getRefreshToken() -> String? {
        load(key: Key.refreshToken.rawValue)
    }

    // MARK: - Clear

    func clearTokens() {
        delete(key: Key.accessToken.rawValue)
        delete(key: Key.refreshToken.rawValue)
    }

    // MARK: - Private

    private func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        // Delete existing item first
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    private func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        SecItemDelete(query as CFDictionary)
    }
}
