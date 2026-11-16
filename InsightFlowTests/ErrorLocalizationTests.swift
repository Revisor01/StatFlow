import XCTest
@testable import InsightFlow

final class ErrorLocalizationTests: XCTestCase {

    /// Deutsche Texte wörtlich: die früheren Meldungen, mit Du-Anrede wie im Rest der App.
    private let germanTexts: [String: String] = [
        "error.api.notConfigured": "API ist nicht konfiguriert",
        "error.api.invalidURL": "Ungültige URL",
        "error.api.invalidResponse": "Ungültige Server-Antwort",
        "error.api.authenticationFailed": "Anmeldung fehlgeschlagen",
        "error.api.unauthorized": "Nicht autorisiert",
        "error.api.server %lld": "Server-Fehler (%lld)",
        "error.api.twoFactorInvalidCode": "Der Bestätigungscode ist ungültig",
        "error.api.twoFactorLocked": "Zu viele Fehlversuche. Bitte versuche es später erneut.",
        "error.api.twoFactorRequired": "Für dieses Konto ist eine Bestätigung in zwei Schritten aktiv. Bitte melde dich über die Anmeldemaske an.",
        "error.api.umamiCloudRequiresAPIKey": "Umami Cloud verwendet keine Anmeldung mit Benutzername und Passwort. Bitte erzeuge in Umami unter Einstellungen → API keys einen Schlüssel und trage ihn hier ein.",
        "error.api.invalidAPIKey": "Der API-Schlüssel wurde nicht akzeptiert. Bitte prüfe ihn in Umami unter Einstellungen → API keys.",
        "error.keychain.saveFailed %@": "Keychain Speicherfehler: %@",
        "error.keychain.encodingFailed": "Wert konnte nicht als UTF-8 kodiert werden"
    ]

    private let allAPIErrors: [APIError] = [
        .notConfigured, .invalidURL, .invalidResponse, .authenticationFailed, .unauthorized,
        .serverError(503), .twoFactorInvalidCode, .twoFactorLocked(until: nil), .twoFactorRequired,
        .umamiCloudRequiresAPIKey, .invalidAPIKey, .twoFactorSetupRequired, .cohortNeedsUpdate
    ]

    private func bundle(_ language: String) throws -> Bundle {
        let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"), "\(language).lproj fehlt")
        return try XCTUnwrap(Bundle(path: path))
    }

    private func text(_ key: String, in bundle: Bundle) -> String {
        bundle.localizedString(forKey: key, value: "", table: nil)
    }

    func testGermanTableMatchesExpectedMessages() throws {
        let de = try bundle("de")
        for (key, expected) in germanTexts {
            XCTAssertEqual(text(key, in: de), expected, key)
        }
        XCTAssertEqual(String(format: text("error.api.server %lld", in: de), 503), "Server-Fehler (503)")
    }

    func testEnglishTableTranslatesEveryMessage() throws {
        let de = try bundle("de")
        let en = try bundle("en")
        for key in germanTexts.keys {
            let english = text(key, in: en)
            XCTAssertFalse(english.isEmpty, key)
            XCTAssertNotEqual(english, key, "Schlüssel nicht aufgelöst: \(key)")
            XCTAssertNotEqual(english, text(key, in: de), "Nicht übersetzt: \(key)")
        }
        XCTAssertEqual(text("error.api.authenticationFailed", in: en), "Login failed")
        XCTAssertEqual(String(format: text("error.api.server %lld", in: en), 503), "Server error (503)")
    }

    func testEveryAPIErrorResolvesFromCatalog() throws {
        var seen = Set<String>()
        for error in allAPIErrors {
            let message = try XCTUnwrap(error.errorDescription)
            XCTAssertFalse(message.isEmpty)
            XCTAssertFalse(message.hasPrefix("error."), "Schlüssel nicht aufgelöst: \(message)")
            seen.insert(message)
        }
        XCTAssertEqual(seen.count, allAPIErrors.count, "Zwei Fehler teilen sich eine Meldung")
        XCTAssertEqual(APIError.notConfigured.errorDescription, String(localized: "error.api.notConfigured"))
        XCTAssertTrue(try XCTUnwrap(APIError.serverError(503).errorDescription).contains("503"))
    }

    func testKeychainErrorsResolveFromCatalog() throws {
        let saveFailed = try XCTUnwrap(KeychainError.saveFailed(-25299).errorDescription)
        XCTAssertFalse(saveFailed.hasPrefix("error."))
        XCTAssertTrue(saveFailed.contains("-25299"))
        XCTAssertFalse(saveFailed.contains("25,299") || saveFailed.contains("25.299"))
        XCTAssertEqual(KeychainError.encodingFailed.errorDescription, String(localized: "error.keychain.encodingFailed"))
        XCTAssertNotEqual(KeychainError.encodingFailed.errorDescription, "error.keychain.encodingFailed")
    }
}
