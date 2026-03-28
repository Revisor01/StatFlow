import Foundation
import CryptoKit

/// Shares credentials between app and widget using a file in the App Group container
/// This avoids UserDefaults issues with "System Containers" error
/// Credentials are encrypted using AES-GCM for security
enum SharedCredentials {
    private static let appGroupID = "group.de.godsapp.statflow"
    private static let fileName = "widget_credentials.encrypted"
    private static let keyFileName = "widget_credentials.key"

    // MARK: - Encryption Helpers

    /// Get or create the encryption key
    private static var encryptionKey: SymmetricKey {
        if let existingKey = loadEncryptionKey() {
            return existingKey
        }
        let newKey = SymmetricKey(size: .bits256)
        saveEncryptionKey(newKey)
        return newKey
    }

    private static func saveEncryptionKey(_ key: SymmetricKey) {
        guard let url = containerURL?.appendingPathComponent(keyFileName) else { return }
        let keyData = key.withUnsafeBytes { Data($0) }
        try? keyData.write(to: url, options: [.atomic, .completeFileProtection])
    }

    private static func loadEncryptionKey() -> SymmetricKey? {
        guard let url = containerURL?.appendingPathComponent(keyFileName),
              FileManager.default.fileExists(atPath: url.path),
              let keyData = try? Data(contentsOf: url),
              keyData.count == 32 else { // 256 bits = 32 bytes
            return nil
        }
        return SymmetricKey(data: keyData)
    }

    private static func encrypt(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: encryptionKey)
        guard let combined = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }
        return combined
    }

    private static func decrypt(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: encryptionKey)
    }

    enum EncryptionError: Error {
        case encryptionFailed
        case decryptionFailed
    }

    enum TimeRange: String, Codable, CaseIterable {
        case today = "Heute"
        case yesterday = "Gestern"
        case last7Days = "7 Tage"
        case last30Days = "30 Tage"

        var days: Int {
            switch self {
            case .today: return 0
            case .yesterday: return 1
            case .last7Days: return 6
            case .last30Days: return 29
            }
        }

        var unit: String {
            switch self {
            case .today, .yesterday: return "hour"
            default: return "day"
            }
        }
    }

    enum ProviderType: String, Codable {
        case umami
        case plausible
    }

    struct Credentials: Codable {
        let serverURL: String
        let token: String  // Umami token or Plausible API key
        let providerType: ProviderType
        let websiteId: String?
        let websiteName: String?
        let timeRange: String? // TimeRange.rawValue
        let sites: [String]?  // Plausible sites (domains)
    }

    struct Status {
        let containerExists: Bool
        let containerPath: String?
        let fileExists: Bool
        let filePath: String?
    }

    /// Get the shared container URL
    private static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    /// Get the credentials file URL
    private static var fileURL: URL? {
        containerURL?.appendingPathComponent(fileName)
    }

    /// Get debug status
    static func getStatus() -> Status {
        let container = containerURL
        let file = fileURL
        return Status(
            containerExists: container != nil,
            containerPath: container?.path,
            fileExists: file != nil && FileManager.default.fileExists(atPath: file!.path),
            filePath: file?.path
        )
    }

    /// Save credentials for widget to read (encrypted)
    @discardableResult
    static func save(
        serverURL: String,
        token: String,
        providerType: ProviderType = .umami,
        websiteId: String? = nil,
        websiteName: String? = nil,
        timeRange: TimeRange? = nil,
        sites: [String]? = nil
    ) -> Bool {
        guard let url = fileURL else {
            #if DEBUG
            print("SharedCredentials: No container URL - App Group not configured?")
            #endif
            return false
        }

        let credentials = Credentials(
            serverURL: serverURL,
            token: token,
            providerType: providerType,
            websiteId: websiteId,
            websiteName: websiteName,
            timeRange: timeRange?.rawValue,
            sites: sites
        )

        do {
            let jsonData = try JSONEncoder().encode(credentials)
            let encryptedData = try encrypt(jsonData)
            try encryptedData.write(to: url, options: [.atomic, .completeFileProtection])
            #if DEBUG
            print("SharedCredentials: Saved encrypted credentials")
            #endif
            return true
        } catch {
            #if DEBUG
            print("SharedCredentials: Save error - \(error)")
            #endif
            return false
        }
    }

    /// Load credentials (used by widget) - decrypts automatically
    static func load() -> Credentials? {
        guard let url = fileURL else {
            #if DEBUG
            print("SharedCredentials: No container URL")
            #endif
            return nil
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            // Try loading legacy unencrypted file and migrate
            if let legacyCreds = loadLegacyCredentials() {
                // Re-save with encryption
                _ = save(
                    serverURL: legacyCreds.serverURL,
                    token: legacyCreds.token,
                    providerType: legacyCreds.providerType,
                    websiteId: legacyCreds.websiteId,
                    websiteName: legacyCreds.websiteName,
                    timeRange: legacyCreds.timeRange.flatMap { TimeRange(rawValue: $0) },
                    sites: legacyCreds.sites
                )
                deleteLegacyFile()
                return legacyCreds
            }
            return nil
        }

        do {
            let encryptedData = try Data(contentsOf: url)
            let jsonData = try decrypt(encryptedData)
            let credentials = try JSONDecoder().decode(Credentials.self, from: jsonData)
            return credentials
        } catch {
            #if DEBUG
            print("SharedCredentials: Load error - \(error)")
            #endif
            return nil
        }
    }

    /// Load legacy unencrypted credentials for migration
    private static func loadLegacyCredentials() -> Credentials? {
        guard let url = containerURL?.appendingPathComponent("widget_credentials.json"),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(Credentials.self, from: data)
        } catch {
            return nil
        }
    }

    /// Delete legacy unencrypted file after migration
    private static func deleteLegacyFile() {
        guard let url = containerURL?.appendingPathComponent("widget_credentials.json") else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Delete credentials file and encryption key
    static func delete() {
        // Delete encrypted credentials
        if let url = fileURL {
            try? FileManager.default.removeItem(at: url)
        }
        // Delete encryption key
        if let keyURL = containerURL?.appendingPathComponent(keyFileName) {
            try? FileManager.default.removeItem(at: keyURL)
        }
        // Delete legacy file if exists
        deleteLegacyFile()
        #if DEBUG
        print("SharedCredentials: Deleted")
        #endif
    }

    // MARK: - Widget Accounts (Encrypted)

    private static let widgetAccountsFileName = "widget_accounts.encrypted"
    private static let legacyWidgetAccountsFileName = "widget_accounts.json"

    /// Speichert Widget-Accounts verschluesselt im App Group Container
    @discardableResult
    static func saveWidgetAccounts(_ accountsData: Data) -> Bool {
        guard let url = containerURL?.appendingPathComponent(widgetAccountsFileName) else {
            return false
        }
        do {
            let encrypted = try encrypt(accountsData)
            try encrypted.write(to: url, options: [.atomic, .completeFileProtection])
            // Legacy-Datei loeschen falls vorhanden
            if let legacyURL = containerURL?.appendingPathComponent(legacyWidgetAccountsFileName) {
                try? FileManager.default.removeItem(at: legacyURL)
            }
            return true
        } catch {
            #if DEBUG
            print("SharedCredentials: Failed to save widget accounts - \(error)")
            #endif
            return false
        }
    }

    /// Laedt und entschluesselt Widget-Accounts (fuer App-seitigen Zugriff)
    static func loadWidgetAccounts() -> Data? {
        guard let url = containerURL?.appendingPathComponent(widgetAccountsFileName),
              FileManager.default.fileExists(atPath: url.path) else {
            // Fallback auf Legacy-Plaintext
            guard let legacyURL = containerURL?.appendingPathComponent(legacyWidgetAccountsFileName),
                  FileManager.default.fileExists(atPath: legacyURL.path) else {
                return nil
            }
            return try? Data(contentsOf: legacyURL)
        }
        do {
            let encrypted = try Data(contentsOf: url)
            return try decrypt(encrypted)
        } catch {
            #if DEBUG
            print("SharedCredentials: Failed to load widget accounts - \(error)")
            #endif
            return nil
        }
    }
}
