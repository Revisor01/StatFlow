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
        manager.setActiveAccount(account)

        XCTAssertEqual(manager.activeAccount?.id, account.id)
    }

    func testClearActiveAccount() async throws {
        let manager = AccountManager.shared
        let account = makeTestAccount()

        manager.addAccount(account)
        manager.setActiveAccount(account)
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
        manager.setActiveAccount(account)

        XCTAssertNotNil(UserDefaults.standard.string(forKey: "active_account_id"))
    }
}
