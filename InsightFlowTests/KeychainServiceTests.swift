import XCTest
@testable import InsightFlow

final class KeychainServiceTests: XCTestCase {
    let testAccountId = "test-account-\(UUID().uuidString)"

    override func tearDown() {
        KeychainService.deleteCredentials(for: testAccountId)
        KeychainService.deleteAll()
        super.tearDown()
    }

    func testSaveAndLoadCredential() throws {
        let testToken = "test-token-123"
        try XCTSkipIf(
            { do { try KeychainService.saveCredential("probe", type: .token, accountId: "probe"); KeychainService.deleteCredentials(for: "probe"); return false } catch { return true } }(),
            "Keychain nicht verfuegbar (kein Entitlement im Simulator)"
        )
        try KeychainService.saveCredential(testToken, type: .token, accountId: testAccountId)
        let loaded = KeychainService.loadCredential(type: .token, accountId: testAccountId)
        XCTAssertEqual(loaded, testToken)
    }

    func testDeleteCredentials() throws {
        try XCTSkipIf(
            { do { try KeychainService.saveCredential("probe", type: .token, accountId: "probe"); KeychainService.deleteCredentials(for: "probe"); return false } catch { return true } }(),
            "Keychain nicht verfuegbar (kein Entitlement im Simulator)"
        )
        try KeychainService.saveCredential("token-to-delete", type: .token, accountId: testAccountId)
        KeychainService.deleteCredentials(for: testAccountId)
        let loaded = KeychainService.loadCredential(type: .token, accountId: testAccountId)
        XCTAssertNil(loaded)
    }

    func testAccountScopingIsolation() throws {
        let idA = "test-account-A-\(UUID().uuidString)"
        let idB = "test-account-B-\(UUID().uuidString)"
        defer {
            KeychainService.deleteCredentials(for: idA)
            KeychainService.deleteCredentials(for: idB)
        }
        try XCTSkipIf(
            { do { try KeychainService.saveCredential("probe", type: .token, accountId: "probe"); KeychainService.deleteCredentials(for: "probe"); return false } catch { return true } }(),
            "Keychain nicht verfuegbar (kein Entitlement im Simulator)"
        )
        try KeychainService.saveCredential("tokenA", type: .token, accountId: idA)
        let loadedFromB = KeychainService.loadCredential(type: .token, accountId: idB)
        XCTAssertNil(loadedFromB, "Account B sollte Token von Account A nicht sehen")
    }

    func testOverwriteCredential() throws {
        try XCTSkipIf(
            { do { try KeychainService.saveCredential("probe", type: .token, accountId: "probe"); KeychainService.deleteCredentials(for: "probe"); return false } catch { return true } }(),
            "Keychain nicht verfuegbar (kein Entitlement im Simulator)"
        )
        try KeychainService.saveCredential("v1", type: .token, accountId: testAccountId)
        try KeychainService.saveCredential("v2", type: .token, accountId: testAccountId)
        let loaded = KeychainService.loadCredential(type: .token, accountId: testAccountId)
        XCTAssertEqual(loaded, "v2", "Zweiter save-Aufruf muss alten Wert ueberschreiben")
    }

    func testDeleteAllClearsLegacyKeys() throws {
        try XCTSkipIf(
            { do { try KeychainService.save("probe", for: .token); KeychainService.delete(for: .token); return false } catch { return true } }(),
            "Keychain nicht verfuegbar (kein Entitlement im Simulator)"
        )
        try KeychainService.save("legacy-token", for: .token)
        KeychainService.deleteAll()
        let loaded = KeychainService.load(for: .token)
        XCTAssertNil(loaded, "deleteAll() muss alle Legacy-Keys entfernen")
    }

    func testApiKeyCredentialType() throws {
        let apiKeyAccountId = "test-apikey-\(UUID().uuidString)"
        defer { KeychainService.deleteCredentials(for: apiKeyAccountId) }
        try XCTSkipIf(
            { do { try KeychainService.saveCredential("probe", type: .apiKey, accountId: "probe"); KeychainService.deleteCredentials(for: "probe"); return false } catch { return true } }(),
            "Keychain nicht verfuegbar (kein Entitlement im Simulator)"
        )
        try KeychainService.saveCredential("my-api-key", type: .apiKey, accountId: apiKeyAccountId)
        let loaded = KeychainService.loadCredential(type: .apiKey, accountId: apiKeyAccountId)
        XCTAssertEqual(loaded, "my-api-key")
    }
}
