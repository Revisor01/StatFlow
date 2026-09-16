import XCTest
@testable import InsightFlow

/// Tests für die Anbindung an Umami Cloud.
///
/// Die JSON-Beispiele stammen aus echten Antworten von
/// `https://api.umami.is/v1` (abgefragt am 17.09.2026); IDs, Domain und
/// Benutzername sind durch Platzhalter ersetzt.
final class UmamiCloudTests: XCTestCase {

    // MARK: - Erkennung der Cloud-Adresse

    func testCloudBaseURLIsAPIHostNotWebInterface() {
        // Die Weboberfläche cloud.umami.is beantwortet keine API-Anfragen;
        // eingetragen werden muss die API-Basis.
        XCTAssertEqual(UmamiAPI.cloudBaseURL, "https://api.umami.is/v1")
    }

    func testIsCloudURLRecognizesAPIHost() {
        XCTAssertTrue(UmamiAPI.isCloudURL("https://api.umami.is/v1"))
    }

    func testIsCloudURLRecognizesWebInterface() {
        // Wer die Weboberfläche einträgt, meint ebenfalls Umami Cloud — auch
        // dann darf nicht der Anmeldeweg mit Passwort versucht werden.
        XCTAssertTrue(UmamiAPI.isCloudURL("https://cloud.umami.is"))
    }

    func testIsCloudURLRejectsSelfHosted() {
        // Der erlaubte Fall: eine eigene Instanz bleibt beim Login mit
        // Benutzername und Passwort.
        XCTAssertFalse(UmamiAPI.isCloudURL("https://analytics.example.com"))
        XCTAssertFalse(UmamiAPI.isCloudURL("https://umami.example.com/api"))
    }

    func testIsCloudURLRejectsMalformedInput() {
        XCTAssertFalse(UmamiAPI.isCloudURL(""))
        XCTAssertFalse(UmamiAPI.isCloudURL("keine-url"))
    }

    func testIsCloudURLIgnoresHostCasing() {
        XCTAssertTrue(UmamiAPI.isCloudURL("https://API.Umami.IS/v1"))
    }

    // MARK: - Fehlermeldungen

    func testCloudLoginWithPasswordHasOwnErrorMessage() throws {
        // Der verbotene Fall darf nicht als generisches
        // „Anmeldung fehlgeschlagen“ erscheinen, sonst sieht er aus wie ein
        // Tippfehler im Passwort.
        let message = try XCTUnwrap(APIError.umamiCloudRequiresAPIKey.errorDescription)
        XCTAssertTrue(message.contains("API keys"), "Meldung nennt den Weg zum Schlüssel nicht: \(message)")
        XCTAssertNotEqual(message, APIError.authenticationFailed.errorDescription)
    }

    func testInvalidAPIKeyHasOwnErrorMessage() throws {
        let message = try XCTUnwrap(APIError.invalidAPIKey.errorDescription)
        XCTAssertTrue(message.contains("API"), "Meldung nennt den Schlüssel nicht: \(message)")
        XCTAssertNotEqual(message, APIError.authenticationFailed.errorDescription)
    }

    // MARK: - Antwortformate der Cloud-API

    func testCloudWebsitesResponseIsPaginatedObject() throws {
        // Cloud liefert ein Objekt mit Pagination, kein nacktes Array.
        let json = """
        {"data":[{"id":"00000000-0000-0000-0000-000000000000","name":"Example Site","domain":"example.com","resetAt":null,"userId":"11111111-1111-1111-1111-111111111111","teamId":null,"createdBy":"11111111-1111-1111-1111-111111111111","createdAt":"2026-04-22T22:25:03.537Z","updatedAt":"2026-04-22T22:25:03.537Z","deletedAt":null,"recorderEnabled":false,"replayConfig":null,"user":{"username":"tester@example.com","id":"11111111-1111-1111-1111-111111111111"},"shareId":null}],"count":1,"page":1,"pageSize":20,"orderBy":"name"}
        """.data(using: .utf8)!

        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: json) as? [String: Any])
        let data = try XCTUnwrap(object["data"] as? [[String: Any]])
        XCTAssertEqual(object["count"] as? Int, 1)
        XCTAssertEqual(object["page"] as? Int, 1)
        XCTAssertEqual(object["pageSize"] as? Int, 20)
        XCTAssertEqual(data.count, 1)
        XCTAssertEqual(data[0]["domain"] as? String, "example.com")
    }

    func testCloudStatsMatchesSelfHostedShape() throws {
        // Entscheidend für die Wiederverwendung des bestehenden Clients:
        // Cloud liefert dieselbe flache Form samt `comparison` wie v3.
        let json = """
        {"pageviews":884,"visitors":294,"visits":395,"bounces":165,"totaltime":60556,"comparison":{"pageviews":294,"visitors":115,"visits":135,"bounces":55,"totaltime":17610}}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(WebsiteStatsResponse.self, from: json)
        XCTAssertEqual(response.pageviews, 884)
        XCTAssertEqual(response.visitors, 294)
        XCTAssertEqual(response.visits, 395)
        XCTAssertEqual(response.bounces, 165)
        XCTAssertEqual(response.totaltime, 60556)
        XCTAssertEqual(response.comparison.pageviews, 294)
        XCTAssertEqual(response.comparison.visitors, 115)
    }

    func testCloudActiveVisitorsIsObjectNotArray() throws {
        // Umami v1 lieferte hier ein Array; Cloud antwortet mit einem Objekt.
        let json = #"{"visitors":0}"#.data(using: .utf8)!

        let parsed = try JSONSerialization.jsonObject(with: json)
        let object = try XCTUnwrap(parsed as? [String: Any])
        XCTAssertEqual(object["visitors"] as? Int, 0)
        XCTAssertNil(parsed as? [[String: Any]])
    }

    func testCloudMetricsIsArray() throws {
        let json = """
        [{"x":"/","y":241},{"x":"/ergebnisse/","y":94},{"x":"/strecken/","y":69}]
        """.data(using: .utf8)!

        let items = try XCTUnwrap(JSONSerialization.jsonObject(with: json) as? [[String: Any]])
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0]["x"] as? String, "/")
        XCTAssertEqual(items[0]["y"] as? Int, 241)
    }

    // MARK: - Ablage der Zugangsdaten

    func testCloudAccountStoresKeyAsToken() {
        // Der Schlüssel liegt im Feld `token`, damit Widget-Sync und
        // Kontowechsel unverändert funktionieren.
        let account = AnalyticsAccount(
            name: "Umami Cloud",
            serverURL: UmamiAPI.cloudBaseURL,
            providerType: .umami,
            credentials: AccountCredentials(token: "api_testschluessel", apiKey: nil)
        )

        XCTAssertEqual(account.credentials.token, "api_testschluessel")
        XCTAssertNil(account.credentials.apiKey)
        XCTAssertFalse(account.credentials.isEmpty)
        XCTAssertEqual(account.providerType, .umami)
    }
}
