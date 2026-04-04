import Foundation
import os
import WidgetKit
import Combine

// Notification for account changes
extension Notification.Name {
    static let accountDidChange = Notification.Name("accountDidChange")
    static let allAccountsRemoved = Notification.Name("allAccountsRemoved")
}

// MARK: - Account Model

struct AnalyticsAccount: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let serverURL: String
    let providerType: AnalyticsProviderType
    let credentials: AccountCredentials
    var sites: [String]?  // For Plausible: stored site domains
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        serverURL: String,
        providerType: AnalyticsProviderType,
        credentials: AccountCredentials,
        sites: [String]? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.serverURL = serverURL
        self.providerType = providerType
        self.credentials = credentials
        self.sites = sites
        self.createdAt = createdAt
    }

    var displayName: String {
        if name.isEmpty {
            return serverURL
                .replacingOccurrences(of: "https://", with: "")
                .replacingOccurrences(of: "http://", with: "")
        }
        return name
    }

    var icon: String {
        providerType.icon
    }

    static func == (lhs: AnalyticsAccount, rhs: AnalyticsAccount) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Account Credentials

struct AccountCredentials: Codable {
    let token: String?      // Umami token
    let apiKey: String?     // Plausible API key

    var isEmpty: Bool {
        (token == nil || token?.isEmpty == true) && (apiKey == nil || apiKey?.isEmpty == true)
    }
}

// MARK: - Account Manager

@MainActor
class AccountManager: ObservableObject {
    static let shared = AccountManager()

    private let accountsKey = "analytics_accounts"
    private let activeAccountKey = "active_account_id"
    private let migrationV2Key = "credentials_migrated_v2"

    @Published var accounts: [AnalyticsAccount] = []
    @Published var activeAccount: AnalyticsAccount?

    private init() {
        if !UserDefaults.standard.bool(forKey: migrationV2Key) {
            migrateCredentialsToKeychain()
        }
        loadAccounts()
        // Configure API services for the active account on app start
        if let account = activeAccount {
            Task {
                await applyAccountCredentials(account)
            }
        }
    }

    // MARK: - Account Management

    func addAccount(_ account: AnalyticsAccount) {
        // Check if account with same server URL and provider already exists
        if let existingIndex = accounts.firstIndex(where: {
            $0.serverURL == account.serverURL && $0.providerType == account.providerType
        }) {
            // Update existing account
            accounts[existingIndex] = account
        } else {
            accounts.append(account)
        }
        // Credentials in Keychain speichern BEVOR saveAccounts() sie strippt
        saveCredentialsToKeychain(for: account)
        saveAccounts()

        // If this is the first account, make it active
        if activeAccount == nil {
            Task {
                await setActiveAccount(account)
            }
        }
    }

    func removeAccount(_ account: AnalyticsAccount) {
        accounts.removeAll { $0.id == account.id }
        KeychainService.deleteCredentials(for: account.id.uuidString)
        saveAccounts()

        // If we removed the active account, switch to another one
        if activeAccount?.id == account.id {
            if let firstAccount = accounts.first {
                Task {
                    await setActiveAccount(firstAccount)
                }
            } else {
                clearActiveAccount()
            }
        }
    }

    func updateAccountSites(_ account: AnalyticsAccount, sites: [String]) {
        Logger.auth.debug("updateAccountSites called for \(account.name) with \(sites.count) sites: \(sites)")
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            var updated = accounts[index]
            updated.sites = sites
            accounts[index] = updated
            saveAccounts()
            Logger.auth.debug("saved accounts, account.sites = \(updated.sites ?? [])")

            if activeAccount?.id == account.id {
                activeAccount = updated
                Logger.auth.debug("updated activeAccount.sites = \(updated.sites ?? [])")
                // Nur Daten schreiben — kein reloadAllTimelines (FIX-01)
                // Widget-Reload passiert ausschliesslich ueber applyAccountCredentials
                syncWidgetData(for: updated)
            }
        } else {
            Logger.auth.warning("account not found in accounts list!")
        }
    }

    func setActiveAccount(_ account: AnalyticsAccount) async {
        activeAccount = account
        UserDefaults.standard.set(account.id.uuidString, forKey: activeAccountKey)

        // Apply credentials to the system (awaits actor reconfiguration)
        await applyAccountCredentials(account)
    }

    func clearActiveAccount() {
        activeAccount = nil
        UserDefaults.standard.removeObject(forKey: activeAccountKey)

        // Clear system credentials
        KeychainService.deleteAll()
        SharedCredentials.delete()
        AnalyticsManager.shared.logout()

        // API-Services aufraumen (aus AuthManager.logout)
        Task {
            await UmamiAPI.shared.clearConfiguration()
        }
        PlausibleSitesManager.shared.clearAll()

        // Notify that user should be logged out (no accounts left)
        NotificationCenter.default.post(name: .allAccountsRemoved, object: nil)
    }

    // MARK: - Persistence

    private func loadAccounts() {
        if let data = UserDefaults.standard.data(forKey: accountsKey),
           let decoded = try? JSONDecoder().decode([AnalyticsAccount].self, from: data) {
            accounts = decoded.map { hydrateWithKeychainCredentials($0) }
        }

        // Load active account
        if let activeIdString = UserDefaults.standard.string(forKey: activeAccountKey),
           let activeId = UUID(uuidString: activeIdString),
           let account = accounts.first(where: { $0.id == activeId }) {
            activeAccount = account
        } else if let firstAccount = accounts.first {
            // Default to first account if no active account set
            activeAccount = firstAccount
        }
    }

    private func saveAccounts() {
        let stripped = accounts.map { accountWithoutCredentials($0) }
        if let encoded = try? JSONEncoder().encode(stripped) {
            UserDefaults.standard.set(encoded, forKey: accountsKey)
        }
    }

    // MARK: - Keychain Credential Management

    /// Schreibt Credentials eines Accounts in die Keychain (account-ID-scoped)
    private func saveCredentialsToKeychain(for account: AnalyticsAccount) {
        let accountId = account.id.uuidString
        if let token = account.credentials.token, !token.isEmpty {
            try? KeychainService.saveCredential(token, type: .token, accountId: accountId)
        }
        if let apiKey = account.credentials.apiKey, !apiKey.isEmpty {
            try? KeychainService.saveCredential(apiKey, type: .apiKey, accountId: accountId)
        }
    }

    /// Erstellt eine Kopie des Accounts ohne Credentials (für UserDefaults-Persistenz)
    private func accountWithoutCredentials(_ account: AnalyticsAccount) -> AnalyticsAccount {
        AnalyticsAccount(
            id: account.id,
            name: account.name,
            serverURL: account.serverURL,
            providerType: account.providerType,
            credentials: AccountCredentials(token: nil, apiKey: nil),
            sites: account.sites,
            createdAt: account.createdAt
        )
    }

    /// Lädt Credentials aus der Keychain und gibt einen hydratisierten Account zurück
    private func hydrateWithKeychainCredentials(_ account: AnalyticsAccount) -> AnalyticsAccount {
        let accountId = account.id.uuidString
        let token = KeychainService.loadCredential(type: .token, accountId: accountId)
        let apiKey = KeychainService.loadCredential(type: .apiKey, accountId: accountId)
        return AnalyticsAccount(
            id: account.id,
            name: account.name,
            serverURL: account.serverURL,
            providerType: account.providerType,
            credentials: AccountCredentials(token: token, apiKey: apiKey),
            sites: account.sites,
            createdAt: account.createdAt
        )
    }

    // MARK: - Lightweight Provider Configuration (no side effects)

    /// Configures API provider for a specific account WITHOUT changing global state.
    /// Does NOT: update activeAccount, post notifications, reload widgets.
    /// Used by loadAllAccountsData to iterate accounts without side effects.
    func configureProviderForAccount(_ account: AnalyticsAccount) async {
        // Write credentials to Keychain so API actors can read them
        try? KeychainService.save(account.serverURL, for: .serverURL)
        try? KeychainService.save(account.providerType.rawValue, for: .providerType)

        switch account.providerType {
        case .umami:
            if let token = account.credentials.token {
                try? KeychainService.save(token, for: .token)
            }
            // Reconfigure UmamiAPI actor with these credentials
            await UmamiAPI.shared.reconfigureFromKeychain()
            AnalyticsManager.shared.setProvider(UmamiAPI.shared)

        case .plausible:
            if let apiKey = account.credentials.apiKey {
                try? KeychainService.save(apiKey, for: .apiKey)
            }
            if let sites = account.sites, !sites.isEmpty {
                PlausibleSitesManager.shared.setSitesWithoutPersist(sites)
            } else {
                PlausibleSitesManager.shared.clearAll()
            }
            await PlausibleAPI.shared.reconfigureFromKeychain()
            AnalyticsManager.shared.setProvider(PlausibleAPI.shared)
        }
        // NO NotificationCenter post, NO widget reload
    }

    // MARK: - Apply Credentials

    private func applyAccountCredentials(_ account: AnalyticsAccount) async {
        // Save to Keychain for the API services
        try? KeychainService.save(account.serverURL, for: .serverURL)
        try? KeychainService.save(account.providerType.rawValue, for: .providerType)

        switch account.providerType {
        case .umami:
            if let token = account.credentials.token {
                try? KeychainService.save(token, for: .token)
            }
            // Reconfigure UmamiAPI with stored credentials (await actor method)
            await UmamiAPI.shared.reconfigureFromKeychain()
            AnalyticsManager.shared.setProvider(UmamiAPI.shared)

        case .plausible:
            if let apiKey = account.credentials.apiKey {
                try? KeychainService.save(apiKey, for: .apiKey)
            }
            // Restore Plausible sites - use setSitesWithoutPersist to avoid double-save
            Logger.auth.debug("applying Plausible account, account.sites = \(account.sites ?? [])")
            if let sites = account.sites, !sites.isEmpty {
                Logger.auth.debug("restoring \(sites.count) sites from account")
                PlausibleSitesManager.shared.setSitesWithoutPersist(sites)
            } else {
                Logger.auth.debug("account has no sites, clearing PlausibleSitesManager")
                PlausibleSitesManager.shared.clearAll()
            }
            // Reconfigure PlausibleAPI with stored credentials (await actor method)
            await PlausibleAPI.shared.reconfigureFromKeychain()
            // Notify PlausibleSitesManager observers (previously done inside PlausibleAPI.reconfigureFromKeychain)
            PlausibleSitesManager.shared.objectWillChange.send()
            AnalyticsManager.shared.setProvider(PlausibleAPI.shared)
        }

        // Erst Views benachrichtigen, dann Widget-Reload (alle Writes sind abgeschlossen, FIX-01)
        NotificationCenter.default.post(name: .accountDidChange, object: nil)

        // Widget-Reload NACH allen async-Operationen und Filesystem-Writes
        updateWidgetCredentials(for: account)
    }

    private func updateWidgetCredentials(for account: AnalyticsAccount) {
        let token: String
        switch account.providerType {
        case .umami:
            token = account.credentials.token ?? ""
        case .plausible:
            token = account.credentials.apiKey ?? ""
        }

        // Legacy single-account support
        let sharedProviderType: SharedCredentials.ProviderType = account.providerType == .umami ? .umami : .plausible
        SharedCredentials.save(
            serverURL: account.serverURL,
            token: token,
            providerType: sharedProviderType,
            sites: account.sites
        )

        // New multi-account support for widget
        syncAccountsToWidget()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Schreibt Widget-Credentials und Account-Daten ohne Timeline-Reload (FIX-01)
    /// Nur fuer updateAccountSites — reloadAllTimelines passiert ausschliesslich in updateWidgetCredentials
    private func syncWidgetData(for account: AnalyticsAccount) {
        let token: String
        switch account.providerType {
        case .umami:
            token = account.credentials.token ?? ""
        case .plausible:
            token = account.credentials.apiKey ?? ""
        }

        let sharedProviderType: SharedCredentials.ProviderType = account.providerType == .umami ? .umami : .plausible
        SharedCredentials.save(
            serverURL: account.serverURL,
            token: token,
            providerType: sharedProviderType,
            sites: account.sites
        )

        syncAccountsToWidget()
    }

    /// Syncs all accounts to widget storage (encrypted)
    private func syncAccountsToWidget() {
        // Convert accounts to widget format using Codable struct
        struct WidgetAccount: Codable {
            let id: String
            let name: String
            let serverURL: String
            let providerType: String
            let token: String
            let sites: [String]?
        }

        let widgetAccounts = accounts.map { account -> WidgetAccount in
            let token: String
            switch account.providerType {
            case .umami:
                token = account.credentials.token ?? ""
            case .plausible:
                token = account.credentials.apiKey ?? ""
            }

            return WidgetAccount(
                id: account.id.uuidString,
                name: account.name,
                serverURL: account.serverURL,
                providerType: account.providerType.rawValue,
                token: token,
                sites: account.sites
            )
        }

        do {
            let data = try JSONEncoder().encode(widgetAccounts)
            if SharedCredentials.saveWidgetAccounts(data) {
                Logger.auth.debug("synced \(widgetAccounts.count) accounts to widget (encrypted)")
            }
        } catch {
            Logger.auth.error("Failed to encode widget accounts: \(error.localizedDescription)")
        }
    }

    // MARK: - Migration from old system

    /// Migriert bestehende Credentials aus UserDefaults in die Keychain (SEC-04)
    private func migrateCredentialsToKeychain() {
        guard let data = UserDefaults.standard.data(forKey: accountsKey),
              let existingAccounts = try? JSONDecoder().decode([AnalyticsAccount].self, from: data) else {
            // Kein UserDefaults-Eintrag: Neuinstallation oder schon migriert
            UserDefaults.standard.set(true, forKey: migrationV2Key)
            return
        }

        for account in existingAccounts {
            if let token = account.credentials.token, !token.isEmpty {
                try? KeychainService.saveCredential(token, type: .token, accountId: account.id.uuidString)
            }
            if let apiKey = account.credentials.apiKey, !apiKey.isEmpty {
                try? KeychainService.saveCredential(apiKey, type: .apiKey, accountId: account.id.uuidString)
            }
        }

        UserDefaults.standard.set(true, forKey: migrationV2Key)
    }

    func migrateFromLegacyCredentials() {
        // Check if we already have accounts
        guard accounts.isEmpty else { return }

        // Try to migrate existing credentials
        guard let serverURL = KeychainService.load(for: .serverURL),
              let providerTypeString = KeychainService.load(for: .providerType),
              let providerType = AnalyticsProviderType(rawValue: providerTypeString) else {
            return
        }

        var credentials: AccountCredentials
        var sites: [String]?

        switch providerType {
        case .umami:
            let token = KeychainService.load(for: .token)
            credentials = AccountCredentials(token: token, apiKey: nil)
        case .plausible:
            let apiKey = KeychainService.load(for: .apiKey)
            credentials = AccountCredentials(token: nil, apiKey: apiKey)
            sites = PlausibleSitesManager.shared.sites
        }

        let account = AnalyticsAccount(
            name: "",
            serverURL: serverURL,
            providerType: providerType,
            credentials: credentials,
            sites: sites
        )

        addAccount(account)
        Task {
            await setActiveAccount(account)
        }
    }

    // MARK: - Helpers

    var hasMultipleAccounts: Bool {
        accounts.count > 1
    }

    var accountCount: Int {
        accounts.count
    }
}
