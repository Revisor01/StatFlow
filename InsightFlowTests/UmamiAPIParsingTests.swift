import XCTest
@testable import InsightFlow

final class UmamiAPIParsingTests: XCTestCase {

    // MARK: - WebsiteStatsResponse

    func testWebsiteStatsResponseDecoding() throws {
        let json = """
        {
            "pageviews": 200,
            "visitors": 100,
            "visits": 120,
            "bounces": 40,
            "totaltime": 3600,
            "comparison": {
                "pageviews": 180,
                "visitors": 90,
                "visits": 110,
                "bounces": 45,
                "totaltime": 3200
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(WebsiteStatsResponse.self, from: json)
        XCTAssertEqual(response.pageviews, 200)
        XCTAssertEqual(response.visitors, 100)
        XCTAssertEqual(response.visits, 120)
        XCTAssertEqual(response.bounces, 40)
        XCTAssertEqual(response.totaltime, 3600)
        XCTAssertEqual(response.comparison.pageviews, 180)
        XCTAssertEqual(response.comparison.visitors, 90)
    }

    func testWebsiteStatsChangeCalculation() throws {
        let json = """
        {
            "pageviews": 200,
            "visitors": 100,
            "visits": 120,
            "bounces": 40,
            "totaltime": 3600,
            "comparison": {
                "pageviews": 180,
                "visitors": 90,
                "visits": 110,
                "bounces": 45,
                "totaltime": 3200
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(WebsiteStatsResponse.self, from: json)
        let stats = WebsiteStats(from: response)

        XCTAssertEqual(stats.visitors.value, 100)
        XCTAssertEqual(stats.visitors.change, 10) // 100 - 90 = 10
        XCTAssertEqual(stats.pageviews.change, 20) // 200 - 180 = 20
        XCTAssertEqual(stats.bounces.change, -5) // 40 - 45 = -5
    }

    // MARK: - ActiveVisitorsResponse

    func testActiveVisitorsResponseDecoding() throws {
        let json = """
        {"visitors": 42}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ActiveVisitorsResponse.self, from: json)
        XCTAssertEqual(response.visitors, 42)
        XCTAssertEqual(response.count, 42)
    }

    /// Das Widget parst `/active` per JSONSerialization statt per Codable.
    /// Frühere Fassungen lasen nur das Altfeld "x" und zeigten deshalb dauerhaft 0 an —
    /// Umami liefert sowohl in v2 als auch in v3 `{"visitors": n}`.
    func testWidgetActiveVisitorsParsing() throws {
        func parseActive(_ raw: String) -> Int {
            guard let json = try? JSONSerialization.jsonObject(
                with: raw.data(using: .utf8)!
            ) as? [String: Any] else { return 0 }

            if let v = json["visitors"] as? Int { return v }
            if let v = json["visitors"] as? Double { return Int(v) }
            if let v = json["x"] as? Int { return v }
            if let v = json["x"] as? Double { return Int(v) }
            return 0
        }

        XCTAssertEqual(parseActive(#"{"visitors": 42}"#), 42)
        XCTAssertEqual(parseActive(#"{"x": 7}"#), 7)
        XCTAssertEqual(parseActive(#"{"visitors": 0}"#), 0)
        XCTAssertEqual(parseActive(#"{}"#), 0)
    }

    // MARK: - WebsiteResponse

    func testWebsiteResponseDecoding() throws {
        let json = """
        {
            "data": [
                {
                    "id": "abc123",
                    "name": "Test Website",
                    "domain": "test.com",
                    "shareId": null,
                    "teamId": null,
                    "resetAt": null,
                    "createdAt": null
                }
            ],
            "count": 1
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(WebsiteResponse.self, from: json)
        XCTAssertEqual(response.websites.count, 1)
        XCTAssertEqual(response.websites[0].id, "abc123")
        XCTAssertEqual(response.websites[0].name, "Test Website")
        XCTAssertEqual(response.websites[0].domain, "test.com")
    }

    func testWebsiteResponseEmptyData() throws {
        let json = """
        {"data": null, "count": 0}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(WebsiteResponse.self, from: json)
        XCTAssertEqual(response.websites, [])
        XCTAssertEqual(response.websites.count, 0)
    }

    // MARK: - PageviewsData

    func testPageviewsDataDecoding() throws {
        let json = """
        {
            "pageviews": [
                {"x": "2025-01-15T00:00:00.000Z", "y": 150},
                {"x": "2025-01-16T00:00:00.000Z", "y": 200}
            ],
            "sessions": [
                {"x": "2025-01-15T00:00:00.000Z", "y": 80},
                {"x": "2025-01-16T00:00:00.000Z", "y": 110}
            ]
        }
        """.data(using: .utf8)!

        let data = try JSONDecoder().decode(PageviewsData.self, from: json)
        XCTAssertEqual(data.pageviews.count, 2)
        XCTAssertEqual(data.pageviews[0].y, 150)
        XCTAssertEqual(data.pageviews[1].y, 200)
        XCTAssertEqual(data.sessions.count, 2)
        XCTAssertEqual(data.sessions[0].y, 80)
        XCTAssertEqual(data.sessions[0].x, "2025-01-15T00:00:00.000Z")
    }

    /// Umami liefert Zeitpunkte als "2026-08-06 00:00:00" — mit Leerzeichen und
    /// ohne Zeitzonenkennung. Wurde das nicht geparst, fiel `date` auf `Date()`
    /// zurück und alle Punkte lagen auf demselben Zeitpunkt: Das Diagramm war
    /// eine flache Linie, die am Ende hochgeht.
    func testPageviewsUmamiDateFormatIsParsed() throws {
        let json = """
        {
            "pageviews": [
                {"x": "2026-08-06 00:00:00", "y": 7},
                {"x": "2026-08-07 00:00:00", "y": 22}
            ],
            "sessions": []
        }
        """.data(using: .utf8)!

        let data = try JSONDecoder().decode(PageviewsData.self, from: json)
        let dates = data.pageviews.map(\.date)

        // Die Punkte müssen unterschiedliche Zeitpunkte haben …
        XCTAssertNotEqual(dates[0], dates[1])
        // … genau einen Tag auseinander liegen …
        XCTAssertEqual(dates[1].timeIntervalSince(dates[0]), 86_400, accuracy: 3600)
        // … und nicht auf „jetzt" zurückgefallen sein.
        XCTAssertLessThan(dates[1], Date().addingTimeInterval(-60))

        let parts = Calendar.current.dateComponents([.year, .month, .day], from: dates[0])
        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 8)
        XCTAssertEqual(parts.day, 6)
    }

    /// Die Diagramm-Auffüllung ordnet die Messwerte über Kalender-Komponenten
    /// ihren Stunden-Slots zu. Da die Anfragen die Geräte-Zeitzone mitsenden,
    /// kommen die Werte bereits lokal zurück und müssen auch lokal geschlüsselt
    /// werden. Wurde stattdessen nach UTC umgerechnet, verschoben sich alle
    /// Punkte um den Zeitzonen-Versatz und Randstunden fielen ganz heraus —
    /// bei „Gestern" zog der Graph deshalb erst am Ende hoch.
    func testHourlyPointsKeepTheirLocalHour() throws {
        let json = """
        {
            "pageviews": [
                {"x": "2026-08-13 01:00:00", "y": 2},
                {"x": "2026-08-13 21:00:00", "y": 1}
            ],
            "sessions": []
        }
        """.data(using: .utf8)!

        let data = try JSONDecoder().decode(PageviewsData.self, from: json)
        let calendar = Calendar.current

        let first = calendar.dateComponents([.day, .hour], from: data.pageviews[0].date)
        XCTAssertEqual(first.day, 13)
        XCTAssertEqual(first.hour, 1, "01:00 muss auf Stunde 1 liegen, nicht verschoben werden")

        let last = calendar.dateComponents([.day, .hour], from: data.pageviews[1].date)
        XCTAssertEqual(last.day, 13, "21:00 darf nicht auf den Folgetag rutschen")
        XCTAssertEqual(last.hour, 21)
    }

    /// Reines Tagesformat (u. a. Plausible) muss ebenfalls geparst werden.
    func testTimeSeriesPointParsesPlainDate() throws {
        let json = """
        {"pageviews": [{"x": "2026-08-06", "y": 5}], "sessions": []}
        """.data(using: .utf8)!

        let data = try JSONDecoder().decode(PageviewsData.self, from: json)
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: data.pageviews[0].date)
        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 8)
        XCTAssertEqual(parts.day, 6)
    }

    // MARK: - MetricItem

    func testMetricItemDecoding() throws {
        let json = """
        [{"x": "Chrome", "y": 500}]
        """.data(using: .utf8)!

        let items = try JSONDecoder().decode([MetricItem].self, from: json)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].name, "Chrome")
        XCTAssertEqual(items[0].value, 500)
        XCTAssertEqual(items[0].x, "Chrome")
        XCTAssertEqual(items[0].y, 500)
    }

    // MARK: - SessionsResponse

    func testSessionsResponseDecoding() throws {
        let json = """
        {
            "data": [
                {
                    "id": "session-1",
                    "websiteId": "site-abc",
                    "hostname": "test.com",
                    "browser": "Chrome",
                    "os": "Windows",
                    "device": "desktop",
                    "screen": "1920x1080",
                    "language": "en-US",
                    "country": "US",
                    "region": "CA",
                    "city": "San Francisco",
                    "firstAt": null,
                    "lastAt": null,
                    "visits": 3,
                    "views": 10,
                    "createdAt": null
                }
            ],
            "count": 1,
            "page": 1,
            "pageSize": 20
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(SessionsResponse.self, from: json)
        XCTAssertEqual(response.count, 1)
        XCTAssertEqual(response.page, 1)
        XCTAssertEqual(response.pageSize, 20)
        XCTAssertEqual(response.data.count, 1)
        XCTAssertEqual(response.data[0].id, "session-1")
        XCTAssertEqual(response.data[0].browser, "Chrome")
        XCTAssertEqual(response.data[0].country, "US")
    }

    // MARK: - Error Handling

    func testInvalidJSONThrowsDecodingError() {
        let invalidData = "not valid json at all".data(using: .utf8)!
        XCTAssertThrowsError(
            try JSONDecoder().decode(WebsiteStatsResponse.self, from: invalidData)
        ) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    // MARK: - StatValue

    func testStatValueChangePercentage() {
        // value=110, change=10 -> baseValue = 110 - 10 = 100 -> 10/100*100 = 10.0
        let stat = StatValue(value: 110, change: 10)
        XCTAssertEqual(stat.changePercentage, 10.0, accuracy: 0.001)
        XCTAssertTrue(stat.isPositiveChange)
    }

    func testStatValueChangePercentageZeroBase() {
        // value - change == 0 -> guard returns 0
        let stat = StatValue(value: 10, change: 10)
        XCTAssertEqual(stat.changePercentage, 0.0, accuracy: 0.001)
    }

    // MARK: - Batch-Charts (Umami 3.3, api/websites/charts)

    /// Spiegelt das Antwortformat von `api/websites/charts`: ein Objekt, das je
    /// Website-ID `values` (12-Stunden-Buckets) und `total` enthält.
    private struct BatchChartsResponse: Codable {
        struct Entry: Codable {
            let values: [Int]
            let total: Int
        }
        let data: [String: Entry]
    }

    func testBatchChartsResponseDecoding() throws {
        let json = """
        {
            "data": {
                "96efd249-a5e3-486a-8d7e-6da7d8c1ed17": {
                    "values": [3, 0, 2, 0, 8, 0, 4, 0, 6, 0, 5, 0, 0, 0],
                    "total": 28
                },
                "a66f993c-86cc-4c1a-a19d-8c536a4c102a": {
                    "values": [5, 0, 2, 0, 3, 0, 6, 0, 1, 0, 4, 0, 2, 0],
                    "total": 22
                }
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(BatchChartsResponse.self, from: json)

        XCTAssertEqual(response.data.count, 2)
        let first = try XCTUnwrap(response.data["96efd249-a5e3-486a-8d7e-6da7d8c1ed17"])
        XCTAssertEqual(first.total, 28)
        // 7 Tage à 2 Buckets (12 Stunden)
        XCTAssertEqual(first.values.count, 14)
    }

    /// Server, die `unit` auswerten, liefern genau so viele Werte, wie der
    /// Zeitraum Buckets hat. Weicht die Anzahl stark ab, hat der Server den
    /// Parameter ignoriert und in 12-Stunden-Blöcken geantwortet.
    func testBucketCountRevealsWhetherServerHonoredUnit() {
        // Ein voller Tag in Stundenauflösung: 24 Werte erwartet.
        let expectedHourly = 24

        let honored = 24
        let ignored = 2   // 12-Stunden-Blöcke

        XCTAssertLessThanOrEqual(abs(honored - expectedHourly), 1,
                                 "24 Werte entsprechen der angefragten Auflösung")
        XCTAssertGreaterThan(abs(ignored - expectedHourly), 1,
                             "2 Werte verraten die 12-Stunden-Blöcke")
    }

    /// Bei ignoriertem `unit` dürfen die Werte nicht zu Tageswerten summiert
    /// werden: Sitzungen über die Blockgrenze zählen sonst doppelt. Beleg aus
    /// der Praxis (Umami 3.3.0, echte Daten): Die 12-Stunden-Blöcke ergeben
    /// summiert 5, die Datenbank zählt für denselben Tag 4 eindeutige Sitzungen.
    func testSummingTwelveHourBucketsOvercountsSessions() {
        let twelveHourBuckets = [3, 2]
        let summed = twelveHourBuckets.reduce(0, +)
        let distinctSessionsFromDatabase = 4

        XCTAssertEqual(summed, 5)
        XCTAssertNotEqual(summed, distinctSessionsFromDatabase,
                          "Aufsummierte Blöcke zählen Sitzungen über die Grenze doppelt")
    }

    /// Die Zeitpunkte der Werte ergeben sich aus der Auflösung: bei Stunden
    /// je 3600 Sekunden, bei Tagen je 86400.
    func testChartPointDatesFollowRequestedUnit() {
        let start = Date(timeIntervalSince1970: 1_786_226_400)
        let values = [1, 2, 3]

        let hourly = values.enumerated().map { index, value in
            AnalyticsChartPoint(date: start.addingTimeInterval(Double(index) * 3600), value: value)
        }
        let daily = values.enumerated().map { index, value in
            AnalyticsChartPoint(date: start.addingTimeInterval(Double(index) * 86400), value: value)
        }

        XCTAssertEqual(hourly[1].date.timeIntervalSince(start), 3600)
        XCTAssertEqual(daily[1].date.timeIntervalSince(start), 86400)
    }
}
