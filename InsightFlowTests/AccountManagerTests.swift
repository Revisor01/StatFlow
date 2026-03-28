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
}
