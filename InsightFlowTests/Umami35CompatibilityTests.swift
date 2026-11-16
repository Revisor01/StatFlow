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
}
