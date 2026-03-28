//
//  WidgetStorage.swift
//  InsightFlowWidget
//

import Foundation
import CryptoKit
import WidgetKit

struct WidgetAccountsStorage {
    private static let appGroupID = "group.de.godsapp.statflow"
    private static let fileName = "widget_accounts.encrypted"
    private static let legacyFileName = "widget_accounts.json"
    private static let keyFileName = "widget_credentials.key"

    private static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    private static func loadEncryptionKey() -> SymmetricKey? {
        guard let url = containerURL?.appendingPathComponent(keyFileName),
              FileManager.default.fileExists(atPath: url.path),
              let keyData = try? Data(contentsOf: url),
              keyData.count == 32 else {
            return nil
        }
        return SymmetricKey(data: keyData)
    }

    static func loadAccounts() -> [WidgetAccount] {
        guard let containerURL = containerURL else {
            widgetLog("loadAccounts: no container URL")
            return []
        }

        // Versuche verschluesselte Datei zuerst
        let encryptedURL = containerURL.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: encryptedURL.path) {
            do {
                guard let key = loadEncryptionKey() else {
                    widgetLog("loadAccounts: no encryption key, trying legacy")
                    return loadLegacyAccounts(containerURL: containerURL)
                }
                let encryptedData = try Data(contentsOf: encryptedURL)
                let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
                let jsonData = try AES.GCM.open(sealedBox, using: key)
                let accounts = try JSONDecoder().decode([WidgetAccount].self, from: jsonData)
                widgetLog("loadAccounts: loaded \(accounts.count) accounts (encrypted)")
                for acc in accounts {
                    widgetLog("  - \(acc.name): provider=\(acc.providerType), sites=\(acc.sites ?? [])")
                }
                return accounts
            } catch {
                widgetLog("loadAccounts: decrypt error: \(error), trying legacy")
                return loadLegacyAccounts(containerURL: containerURL)
            }
        }

        // Fallback auf Legacy-Plaintext
        return loadLegacyAccounts(containerURL: containerURL)
    }

    /// Legacy-Plaintext laden (fuer Uebergangszeit nach Update)
    private static func loadLegacyAccounts(containerURL: URL) -> [WidgetAccount] {
        let legacyURL = containerURL.appendingPathComponent(legacyFileName)
        guard FileManager.default.fileExists(atPath: legacyURL.path) else {
            widgetLog("loadAccounts: no legacy file, trying legacy credentials")
            if let legacyCreds = WidgetCredentials.load() {
                widgetLog("loadAccounts: using legacy creds, provider=\(legacyCreds.providerType)")
                return [WidgetAccount(
                    id: "legacy",
                    name: "",
                    serverURL: legacyCreds.serverURL,
                    providerType: legacyCreds.providerType,
                    token: legacyCreds.token,
                    sites: legacyCreds.sites
                )]
            }
            return []
        }
        do {
            let data = try Data(contentsOf: legacyURL)
            let accounts = try JSONDecoder().decode([WidgetAccount].self, from: data)
            widgetLog("loadAccounts: loaded \(accounts.count) accounts (legacy plaintext)")
            for acc in accounts {
                widgetLog("  - \(acc.name): provider=\(acc.providerType), sites=\(acc.sites ?? [])")
            }
            return accounts
        } catch {
            widgetLog("loadAccounts: legacy decode error: \(error)")
            if let legacyCreds = WidgetCredentials.load() {
                return [WidgetAccount(
                    id: "legacy",
                    name: "",
                    serverURL: legacyCreds.serverURL,
                    providerType: legacyCreds.providerType,
                    token: legacyCreds.token,
                    sites: legacyCreds.sites
                )]
            }
            return []
        }
    }
}

struct WidgetCredentials {
    private static let appGroupID = "group.de.godsapp.statflow"
    private static let fileName = "widget_credentials.encrypted"
    private static let legacyFileName = "widget_credentials.json"
    private static let keyFileName = "widget_credentials.key"

    struct Credentials {
        let serverURL: String
        let token: String
        let providerType: WidgetProviderType
        let websiteId: String?
        let websiteName: String?
        let sites: [String]?  // Plausible sites (domains)
    }

    // MARK: - Encryption Helpers

    private static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    private static func loadEncryptionKey() -> SymmetricKey? {
        guard let url = containerURL?.appendingPathComponent(keyFileName),
              FileManager.default.fileExists(atPath: url.path),
              let keyData = try? Data(contentsOf: url),
              keyData.count == 32 else {
            return nil
        }
        return SymmetricKey(data: keyData)
    }

    private static func decrypt(_ data: Data) throws -> Data {
        guard let key = loadEncryptionKey() else {
            throw DecryptionError.noKey
        }
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }

    enum DecryptionError: Error {
        case noKey
        case decryptionFailed
    }

    static func load() -> Credentials? {
        guard let containerURL = containerURL else {
            return nil
        }

        // Try encrypted file first
        let encryptedURL = containerURL.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: encryptedURL.path) {
            do {
                let encryptedData = try Data(contentsOf: encryptedURL)
                let jsonData = try decrypt(encryptedData)
                guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                      let serverURL = json["serverURL"] as? String,
                      let token = json["token"] as? String else {
                    return nil
                }

                let providerTypeString = json["providerType"] as? String ?? "umami"
                let providerType = WidgetProviderType(rawValue: providerTypeString) ?? .umami
                let websiteId = json["websiteId"] as? String
                let websiteName = json["websiteName"] as? String
                let sites = json["sites"] as? [String]

                return Credentials(
                    serverURL: serverURL,
                    token: token,
                    providerType: providerType,
                    websiteId: websiteId,
                    websiteName: websiteName,
                    sites: sites
                )
            } catch {
                widgetLog("Failed to load encrypted credentials: \(error)")
            }
        }

        // Fallback to legacy unencrypted file (will be migrated by app on next launch)
        let legacyURL = containerURL.appendingPathComponent(legacyFileName)
        guard FileManager.default.fileExists(atPath: legacyURL.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: legacyURL)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let serverURL = json["serverURL"] as? String,
                  let token = json["token"] as? String else {
                return nil
            }

            let providerTypeString = json["providerType"] as? String ?? "umami"
            let providerType = WidgetProviderType(rawValue: providerTypeString) ?? .umami
            let websiteId = json["websiteId"] as? String
            let websiteName = json["websiteName"] as? String
            let sites = json["sites"] as? [String]

            return Credentials(
                serverURL: serverURL,
                token: token,
                providerType: providerType,
                websiteId: websiteId,
                websiteName: websiteName,
                sites: sites
            )
        } catch {
            return nil
        }
    }
}
