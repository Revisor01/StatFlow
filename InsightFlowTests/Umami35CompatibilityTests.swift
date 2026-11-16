import XCTest
@testable import InsightFlow

final class Umami35CompatibilityTests: XCTestCase {

    // MARK: - Erzwungene 2FA-Einrichtung

    private let setupRequiredBody = """
    {"error":{"message":"Two-factor authentication setup is required","code":"two-factor-error-setup-required","status":403}}
    """.data(using: .utf8)!

    func testSetupRequiredIsDetectedInNestedErrorBody() {
        XCTAssertTrue(UmamiAPI.isTwoFactorSetupRequired(statusCode: 403, data: setupRequiredBody))
        XCTAssertEqual(UmamiAPI.errorCode(in: setupRequiredBody), "two-factor-error-setup-required")
    }

    func testSetupRequiredIsDetectedInFlatBody() {
        let flat = """
        {"code":"two-factor-error-setup-required","message":"Two-factor authentication setup is required"}
        """.data(using: .utf8)!

        XCTAssertTrue(UmamiAPI.isTwoFactorSetupRequired(statusCode: 403, data: flat))
    }

    func testSetupRequiredNeedsStatus403() {
        XCTAssertFalse(UmamiAPI.isTwoFactorSetupRequired(statusCode: 200, data: setupRequiredBody))
        XCTAssertFalse(UmamiAPI.isTwoFactorSetupRequired(statusCode: 401, data: setupRequiredBody))
    }

    func testOtherForbiddenIsNotSetupRequired() {
        let forbidden = """
        {"error":{"message":"Forbidden","code":"forbidden","status":403}}
        """.data(using: .utf8)!

        XCTAssertFalse(UmamiAPI.isTwoFactorSetupRequired(statusCode: 403, data: forbidden))
        guard case .serverError(let code) = UmamiAPI.apiError(statusCode: 403, data: forbidden) else {
            return XCTFail("Ein anderes 403 muss ein Serverfehler bleiben")
        }
        XCTAssertEqual(code, 403)
    }

    func testForbiddenWithoutJSONIsServerError() {
        let html = "<html>Forbidden</html>".data(using: .utf8)!

        XCTAssertNil(UmamiAPI.errorCode(in: html))
        guard case .serverError(let code) = UmamiAPI.apiError(statusCode: 403, data: html) else {
            return XCTFail("403 ohne JSON muss ein Serverfehler bleiben")
        }
        XCTAssertEqual(code, 403)
    }

    func testSetupRequiredMapsToOwnError() {
        guard case .twoFactorSetupRequired = UmamiAPI.apiError(statusCode: 403, data: setupRequiredBody) else {
            return XCTFail("two-factor-error-setup-required muss einen eigenen Fehler ergeben")
        }
    }

    func testUnauthorizedStaysUnauthorized() {
        guard case .unauthorized = UmamiAPI.apiError(statusCode: 401, data: Data()) else {
            return XCTFail("401 muss .unauthorized bleiben")
        }
    }

    func testSetupRequiredHasLocalizedMessage() {
        let message = APIError.twoFactorSetupRequired.errorDescription

        XCTAssertEqual(message, String(localized: "error.twoFactorSetupRequired"))
        XCTAssertNotEqual(message, "error.twoFactorSetupRequired")
        XCTAssertNotEqual(message, APIError.authenticationFailed.errorDescription)
    }

    // MARK: - passwordChangeRequired

    func testLoginResponseFrom35DecodesPasswordChangeRequired() throws {
        let json = """
        {"token":"abc","user":{"id":"u1","username":"admin","role":"admin","isAdmin":true,"passwordChangeRequired":true,"teams":[]}}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(UmamiAuthResponse.self, from: json)

        XCTAssertEqual(response.token, "abc")
        XCTAssertEqual(response.user?.passwordChangeRequired, true)
        XCTAssertTrue(response.passwordChangeRequired)
    }

    func testLoginResponseWithFalseFlag() throws {
        let json = """
        {"token":"abc","user":{"id":"u1","username":"admin","passwordChangeRequired":false}}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(UmamiAuthResponse.self, from: json)

        XCTAssertEqual(response.user?.passwordChangeRequired, false)
        XCTAssertFalse(response.passwordChangeRequired)
    }

    func testLoginResponseFromOlderServerDecodesWithoutFlag() throws {
        let json = """
        {"token":"abc","user":{"id":"u1","username":"admin","role":"admin","isAdmin":true}}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(UmamiAuthResponse.self, from: json)

        XCTAssertEqual(response.token, "abc")
        XCTAssertEqual(response.user?.username, "admin")
        XCTAssertNil(response.user?.passwordChangeRequired)
        XCTAssertFalse(response.passwordChangeRequired)
    }

    func testTwoFactorLoginResponseDecodesWithoutUser() throws {
        let json = """
        {"requiresTwoFactor":true,"partialToken":"partial"}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(UmamiAuthResponse.self, from: json)

        XCTAssertNil(response.token)
        XCTAssertEqual(response.requiresTwoFactor, true)
        XCTAssertEqual(response.partialToken, "partial")
        XCTAssertNil(response.user)
        XCTAssertFalse(response.passwordChangeRequired)
    }

    func testPasswordChangeNoticeMarksAndClearsOneAccount() {
        let first = UUID()
        let second = UUID()

        var raw = PasswordChangeNotice.updated("", accountId: first, required: true)
        raw = PasswordChangeNotice.updated(raw, accountId: second, required: true)
        XCTAssertTrue(PasswordChangeNotice.isMarked(raw, accountId: first))
        XCTAssertTrue(PasswordChangeNotice.isMarked(raw, accountId: second))
        XCTAssertEqual(PasswordChangeNotice.accountIds(in: raw).count, 2)

        raw = PasswordChangeNotice.updated(raw, accountId: first, required: false)
        XCTAssertFalse(PasswordChangeNotice.isMarked(raw, accountId: first))
        XCTAssertTrue(PasswordChangeNotice.isMarked(raw, accountId: second))
        XCTAssertEqual(raw, second.uuidString)
    }

    func testPasswordChangeNoticeRecordWritesDefaults() throws {
        let suite = "PasswordChangeNoticeTests"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let account = UUID()

        PasswordChangeNotice.record(accountId: account, required: true, defaults: defaults)
        XCTAssertEqual(defaults.string(forKey: PasswordChangeNotice.storageKey), account.uuidString)

        PasswordChangeNotice.record(accountId: account, required: false, defaults: defaults)
        XCTAssertEqual(defaults.string(forKey: PasswordChangeNotice.storageKey), "")
    }
}
