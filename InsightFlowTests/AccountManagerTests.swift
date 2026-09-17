import XCTest
@testable import InsightFlow

@MainActor
class AccountManagerTests: XCTestCase {

    // MARK: - Setup / Teardown

    override func setUp() async throws {
        try await super.setUp()
        let manager = AccountManager.shared
        for account in manager.accounts {
            manager.removeAccount(account)
        }
        UserDefaults.standard.removeObject(forKey: "analytics_accounts")
        UserDefaults.standard.removeObject(forKey: "active_account_id")
    }

    override func tearDown() async throws {
        let manager = AccountManager.shared
        for account in manager.accounts {
            manager.removeAccount(account)
        }
        UserDefaults.standard.removeObject(forKey: "analytics_accounts")
        UserDefaults.standard.removeObject(forKey: "active_account_id")
        try await super.tearDown()
    }

    // MARK: - Helper

    private func makeTestAccount(
        name: String = "Test",
        serverURL: String = "https://test.example.com",
        providerType: AnalyticsProviderType = .umami
    ) -> AnalyticsAccount {
        AnalyticsAccount(
            name: name,
            serverURL: serverURL,
            providerType: providerType,
            credentials: AccountCredentials(token: "test-token", apiKey: nil)
        )
    }

    // MARK: - Tests

    func testAddAccount() async throws {
        let manager = AccountManager.shared
        let account = makeTestAccount(name: "My Account")

        manager.addAccount(account)

        XCTAssertEqual(manager.accounts.count, 1)
        XCTAssertEqual(manager.accounts[0].name, "My Account")
    }

    func testAddDuplicateServerURLUpdatesExisting() async throws {
        let manager = AccountManager.shared
        let account1 = makeTestAccount(name: "Account 1", serverURL: "https://a.com")
        let account2 = makeTestAccount(name: "Account 2 Updated", serverURL: "https://a.com")

        manager.addAccount(account1)
        manager.addAccount(account2)

        XCTAssertEqual(manager.accounts.count, 1)
        XCTAssertEqual(manager.accounts[0].name, "Account 2 Updated")
    }

    func testRemoveAccount() async throws {
        let manager = AccountManager.shared
        let account = makeTestAccount()

        manager.addAccount(account)
        manager.removeAccount(account)

        XCTAssertEqual(manager.accounts.count, 0)
    }

    func testRemoveAccountClearsKeychain() async throws {
        let manager = AccountManager.shared
        let account = makeTestAccount()

        manager.addAccount(account)
        manager.removeAccount(account)

        let token = KeychainService.loadCredential(type: .token, accountId: account.id.uuidString)
        XCTAssertNil(token)
    }

    func testSetActiveAccount() async throws {
        let manager = AccountManager.shared
        let account = makeTestAccount()

        manager.addAccount(account)
        await manager.setActiveAccount(account)

        XCTAssertEqual(manager.activeAccount?.id, account.id)
    }

    func testClearActiveAccount() async throws {
        let manager = AccountManager.shared
        let account = makeTestAccount()

        manager.addAccount(account)
        await manager.setActiveAccount(account)
        manager.clearActiveAccount()

        XCTAssertNil(manager.activeAccount)
    }

    /// Regression: Abmelden loeschte nur die globalen Zugangsdaten, nicht die
    /// Kontenliste. Nach einem Neustart waren deshalb alle Konten wieder da,
    /// und die App sprang auf ein noch vorhandenes Konto eines anderen Anbieters.
    func testLogoutAllRemovesAccountsAndSurvivesReload() async throws {
        let manager = AccountManager.shared
        let account = makeTestAccount()

        manager.addAccount(account)
        await manager.setActiveAccount(account)
        manager.logoutAll()

        XCTAssertNil(manager.activeAccount)
        XCTAssertTrue(manager.accounts.isEmpty, "Konten muessen entfernt sein")

        // Das ist der Kern: der gespeicherte Stand darf keine Konten mehr enthalten,
        // sonst kehren sie beim naechsten Start zurueck.
        let stored = UserDefaults.standard.data(forKey: "analytics_accounts")
        let decoded = stored.flatMap { try? JSONDecoder().decode([AnalyticsAccount].self, from: $0) }
        XCTAssertEqual(decoded?.count ?? 0, 0, "Gespeicherte Konten muessen geloescht sein")
    }

    /// Die Sitzung zu beenden darf die Konten NICHT entfernen — das ist der
    /// Unterschied zwischen `clearActiveAccount` und `logoutAll`.
    func testClearActiveAccountKeepsAccounts() async throws {
        let manager = AccountManager.shared
        let account = makeTestAccount()

        manager.addAccount(account)
        await manager.setActiveAccount(account)
        manager.clearActiveAccount()

        XCTAssertNil(manager.activeAccount)
        XCTAssertFalse(manager.accounts.isEmpty, "Konten bleiben erhalten")
    }

    func testAccountsPersistInUserDefaults() async throws {
        let manager = AccountManager.shared
        let account = makeTestAccount()

        manager.addAccount(account)

        XCTAssertNotNil(UserDefaults.standard.data(forKey: "analytics_accounts"))
    }

    func testActiveAccountIdPersistsInUserDefaults() async throws {
        let manager = AccountManager.shared
        let account = makeTestAccount()

        manager.addAccount(account)
        await manager.setActiveAccount(account)

        XCTAssertNotNil(UserDefaults.standard.string(forKey: "active_account_id"))
    }

    func testMigrateFromLegacyCredentials_Umami() async throws {
        let manager = AccountManager.shared
        // setUp ensures accounts is empty

        addTeardownBlock {
            try? KeychainService.delete(for: .serverURL)
            try? KeychainService.delete(for: .providerType)
            try? KeychainService.delete(for: .token)
        }

        try KeychainService.save("https://umami.test.com", for: .serverURL)
        try KeychainService.save("umami", for: .providerType)
        try KeychainService.save("legacy-token-123", for: .token)

        manager.migrateFromLegacyCredentials()

        XCTAssertEqual(manager.accounts.count, 1)
        XCTAssertEqual(manager.accounts[0].serverURL, "https://umami.test.com")
        XCTAssertEqual(manager.accounts[0].providerType, .umami)
        // setActiveAccount runs in a Task — give it time to complete
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertNotNil(manager.activeAccount)
    }

    func testMigrateFromLegacyCredentials_SkipsWhenAccountsExist() async throws {
        let manager = AccountManager.shared
        let existing = makeTestAccount(name: "Existing", serverURL: "https://existing.com")
        manager.addAccount(existing)

        addTeardownBlock {
            try? KeychainService.delete(for: .serverURL)
            try? KeychainService.delete(for: .providerType)
            try? KeychainService.delete(for: .token)
        }

        try KeychainService.save("https://umami.test.com", for: .serverURL)
        try KeychainService.save("umami", for: .providerType)
        try KeychainService.save("legacy-token-123", for: .token)

        manager.migrateFromLegacyCredentials()

        XCTAssertEqual(manager.accounts.count, 1)
        XCTAssertEqual(manager.accounts[0].serverURL, "https://existing.com")
    }

    // MARK: - FIX-01: Widget Sync

    func testUpdateAccountSitesDoesNotCallReloadTimelines() throws {
        // Verifiziere dass updateAccountSites nur syncWidgetData aufruft (kein reloadAllTimelines)
        // syncWidgetData schreibt Daten ohne Widget-Timeline-Reload
        let manager = AccountManager.shared
        let account = makeTestAccount(name: "Widget Test")
        manager.addAccount(account)

        manager.updateAccountSites(account, sites: ["site1.com", "site2.com"])

        let updated = manager.accounts.first(where: { $0.id == account.id })
        XCTAssertEqual(updated?.sites, ["site1.com", "site2.com"])
    }

    func testSetActiveAccountAppliesCredentialsToKeychain() async throws {
        let manager = AccountManager.shared

        addTeardownBlock {
            try? KeychainService.delete(for: .serverURL)
            try? KeychainService.delete(for: .providerType)
            try? KeychainService.delete(for: .token)
        }

        let account = makeTestAccount(name: "Cred Test", serverURL: "https://cred.test.com")
        manager.addAccount(account)
        await manager.setActiveAccount(account)

        XCTAssertEqual(KeychainService.load(for: .serverURL), "https://cred.test.com")
        XCTAssertEqual(KeychainService.load(for: .providerType), "umami")
        XCTAssertEqual(KeychainService.load(for: .token), "test-token")
    }

    // MARK: - Kontowechsel darf keine fremden Zugangsdaten stehen lassen

    /// Der verbotene Fall: Ein Konto ohne hinterlegtes Token darf nicht das
    /// Token des zuvor aktiven Kontos weiterverwenden.
    ///
    /// `applyAccountCredentials` schrieb `serverURL` bedingungslos, das Token
    /// aber nur, wenn eines vorhanden war. Beim Wechsel auf ein Konto ohne
    /// Token blieb dadurch das fremde Token in der Keychain stehen und wurde
    /// gegen die neue Serveradresse gesendet. Der Server antwortet darauf auf
    /// allen Routen gleichzeitig mit 401 — Verläufe, Orte und Ziele bleiben
    /// zusammen leer, ohne dass die App zur Anmeldung zurückkehrt.
    func testSwitchingToAccountWithoutTokenDoesNotKeepPreviousToken() async throws {
        let manager = AccountManager.shared

        // Diese Tests setzen ein aktives Konto und konfigurieren darüber den
        // global geteilten AnalyticsManager. Ohne Rücknahme erbt der nächste
        // Test im selben Lauf diesen Zustand.
        addTeardownBlock { @MainActor in
            AccountManager.shared.clearActiveAccount()
            KeychainService.delete(for: .serverURL)
            KeychainService.delete(for: .providerType)
            KeychainService.delete(for: .token)
        }

        let withToken = AnalyticsAccount(
            name: "Mit Token",
            serverURL: "https://erste.example.com",
            providerType: .umami,
            credentials: AccountCredentials(token: "token-des-ersten-kontos", apiKey: nil)
        )
        manager.addAccount(withToken)
        await manager.setActiveAccount(withToken)
        XCTAssertEqual(KeychainService.load(for: .token), "token-des-ersten-kontos")

        let withoutToken = AnalyticsAccount(
            name: "Ohne Token",
            serverURL: "https://zweite.example.com",
            providerType: .umami,
            credentials: AccountCredentials(token: nil, apiKey: nil)
        )
        manager.addAccount(withoutToken)
        await manager.setActiveAccount(withoutToken)

        // Die Adresse gehört zum zweiten Konto ...
        XCTAssertEqual(KeychainService.load(for: .serverURL), "https://zweite.example.com")
        // ... also darf dort nicht das Token des ersten Kontos liegen.
        XCTAssertNotEqual(
            KeychainService.load(for: .token),
            "token-des-ersten-kontos",
            "Fremdes Token nach Kontowechsel: Server und Token stammen aus verschiedenen Konten"
        )
        XCTAssertNil(KeychainService.load(for: .token))
    }

    /// Der erlaubte Fall: Ein Konto mit eigenem Token ersetzt das vorherige
    /// vollständig.
    func testSwitchingBetweenAccountsReplacesToken() async throws {
        let manager = AccountManager.shared

        // Diese Tests setzen ein aktives Konto und konfigurieren darüber den
        // global geteilten AnalyticsManager. Ohne Rücknahme erbt der nächste
        // Test im selben Lauf diesen Zustand.
        addTeardownBlock { @MainActor in
            AccountManager.shared.clearActiveAccount()
            KeychainService.delete(for: .serverURL)
            KeychainService.delete(for: .providerType)
            KeychainService.delete(for: .token)
        }

        let first = AnalyticsAccount(
            name: "Erstes",
            serverURL: "https://erste.example.com",
            providerType: .umami,
            credentials: AccountCredentials(token: "token-eins", apiKey: nil)
        )
        let second = AnalyticsAccount(
            name: "Zweites",
            serverURL: "https://zweite.example.com",
            providerType: .umami,
            credentials: AccountCredentials(token: "token-zwei", apiKey: nil)
        )

        manager.addAccount(first)
        await manager.setActiveAccount(first)
        manager.addAccount(second)
        await manager.setActiveAccount(second)

        XCTAssertEqual(KeychainService.load(for: .serverURL), "https://zweite.example.com")
        XCTAssertEqual(KeychainService.load(for: .token), "token-zwei")
    }

    /// Beim Wechsel von Plausible auf Umami darf der Plausible-Schlüssel nicht
    /// als Umami-Token zurückbleiben und umgekehrt.
    func testSwitchingProviderDoesNotLeaveForeignCredential() async throws {
        let manager = AccountManager.shared

        addTeardownBlock { @MainActor in
            AccountManager.shared.clearActiveAccount()
            KeychainService.delete(for: .serverURL)
            KeychainService.delete(for: .providerType)
            KeychainService.delete(for: .token)
            KeychainService.delete(for: .apiKey)
        }

        let umami = AnalyticsAccount(
            name: "Umami",
            serverURL: "https://umami.example.com",
            providerType: .umami,
            credentials: AccountCredentials(token: "umami-token", apiKey: nil)
        )
        manager.addAccount(umami)
        await manager.setActiveAccount(umami)

        let plausible = AnalyticsAccount(
            name: "Plausible",
            serverURL: "https://plausible.example.com",
            providerType: .plausible,
            credentials: AccountCredentials(token: nil, apiKey: "plausible-key")
        )
        manager.addAccount(plausible)
        await manager.setActiveAccount(plausible)

        XCTAssertEqual(KeychainService.load(for: .serverURL), "https://plausible.example.com")
        XCTAssertEqual(KeychainService.load(for: .apiKey), "plausible-key")
        XCTAssertNil(
            KeychainService.load(for: .token),
            "Umami-Token bleibt nach Wechsel auf Plausible in der Keychain stehen"
        )
    }

    /// Läuft ein Hintergrundlauf über mehrere Konten (Zusammenfassungen), setzt
    /// er die globalen Zugangsdaten nacheinander auf jedes Konto. Danach muss
    /// wieder das aktive Konto gelten, sonst laufen die Auswertungen der App
    /// gegen die Zugangsdaten des zuletzt bearbeiteten Kontos.
    func testRestoreActiveAccountCredentialsUndoesIteration() async throws {
        let manager = AccountManager.shared

        addTeardownBlock { @MainActor in
            AccountManager.shared.clearActiveAccount()
            KeychainService.delete(for: .serverURL)
            KeychainService.delete(for: .providerType)
            KeychainService.delete(for: .token)
            KeychainService.delete(for: .apiKey)
        }

        let aktiv = AnalyticsAccount(
            name: "Aktiv",
            serverURL: "https://aktiv.example.com",
            providerType: .umami,
            credentials: AccountCredentials(token: "token-aktiv", apiKey: nil)
        )
        let anderes = AnalyticsAccount(
            name: "Anderes",
            serverURL: "https://anderes.example.com",
            providerType: .umami,
            credentials: AccountCredentials(token: "token-anderes", apiKey: nil)
        )

        manager.addAccount(aktiv)
        manager.addAccount(anderes)
        await manager.setActiveAccount(aktiv)

        // Der Hintergrundlauf konfiguriert zwischendurch ein anderes Konto ...
        await manager.configureProviderForAccount(anderes)
        XCTAssertEqual(KeychainService.load(for: .token), "token-anderes")

        // ... und stellt am Ende das aktive wieder her.
        await manager.restoreActiveAccountCredentials()

        XCTAssertEqual(KeychainService.load(for: .serverURL), "https://aktiv.example.com")
        XCTAssertEqual(KeychainService.load(for: .token), "token-aktiv")
    }
}
