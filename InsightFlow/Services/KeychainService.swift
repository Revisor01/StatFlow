import Foundation
import Security

enum KeychainService: Sendable {
    private static let service = "de.godsapp.PrivacyFlow"

    enum Key: String, Sendable {
        case serverURL = "serverURL"
        case token = "authToken"
        case username = "username"
        case providerType = "providerType"
        case serverType = "serverType"
        case apiKey = "apiKey"
        case plausibleSiteId = "plausibleSiteId"
    }

    static func save(_ value: String, for key: Key) throws {
        let data = value.data(using: .utf8)!

        // Delete existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Save new item - no kSecAttrAccessGroup needed when Keychain Sharing capability is enabled
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    static func load(for key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    static func delete(for key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func deleteAll() {
        for key in [Key.serverURL, Key.token, Key.username, Key.providerType, Key.serverType, Key.apiKey] {
            delete(for: key)
        }
    }

    // MARK: - Account-Scoped Credentials

    enum CredentialType: String, CaseIterable {
        case token = "token"
        case apiKey = "apiKey"
    }

    static func saveCredential(_ value: String, type: CredentialType, accountId: String) throws {
        let accountKey = "\(type.rawValue)_\(accountId)"
        let data = value.data(using: .utf8)!
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    static func loadCredential(type: CredentialType, accountId: String) -> String? {
        let accountKey = "\(type.rawValue)_\(accountId)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    static func deleteCredentials(for accountId: String) {
        for type in CredentialType.allCases {
            let accountKey = "\(type.rawValue)_\(accountId)"
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: accountKey
            ]
            SecItemDelete(query as CFDictionary)
        }
    }
}

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Keychain Speicherfehler: \(status)"
        }
    }
}

// MARK: - Utility Functions

enum StringUtils {
    /// Generates a random alphanumeric share ID
    static func generateShareId(length: Int = 16) -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).compactMap { _ in chars.randomElement() })
    }
}
