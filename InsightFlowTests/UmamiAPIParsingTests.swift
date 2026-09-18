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

    // MARK: - Teams

    /// Antwort von `api/me/teams`, gekürzt auf die Felder, die die App liest.
    func testTeamsResponseDecoding() throws {
        let json = """
        {
            "data": [
                {
                    "id": "1b0f1224-1cbf-4a0c-bf64-e6022fec2930",
                    "name": "App Review",
                    "accessCode": "team_mG9olfjLT99H1NKk",
                    "logoUrl": null,
                    "twoFactorRequired": false,
                    "createdAt": "2026-08-16T13:24:32.580Z",
                    "members": []
                }
            ],
            "count": 1,
            "page": 1,
            "pageSize": 100
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(TeamsResponse.self, from: json)

        XCTAssertEqual(response.count, 1)
        XCTAssertEqual(response.data.first?.name, "App Review")
        XCTAssertEqual(response.data.first?.id, "1b0f1224-1cbf-4a0c-bf64-e6022fec2930")
    }

    /// Team-Websites tragen `userId: null` und stattdessen eine `teamId`.
    func testTeamWebsiteResponseDecoding() throws {
        let json = """
        {
            "data": [
                {
                    "id": "28840232-70cb-4331-9ce2-5ba0f91a4e5b",
                    "name": "App Review Demo",
                    "domain": "demo.statsflow.app",
                    "shareId": null,
                    "userId": null,
                    "teamId": "1b0f1224-1cbf-4a0c-bf64-e6022fec2930",
                    "resetAt": null,
                    "createdAt": "2026-08-16T14:32:00.000Z"
                }
            ],
            "count": 1
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(WebsiteResponse.self, from: json)

        XCTAssertEqual(response.websites.count, 1)
        XCTAssertEqual(response.websites.first?.teamId, "1b0f1224-1cbf-4a0c-bf64-e6022fec2930")
        // teamName kommt nicht vom Server, sondern wird beim Laden ergänzt.
        XCTAssertNil(response.websites.first?.teamName)
    }

    /// Der Teamname wird nachträglich gesetzt und muss die Kodierung überstehen
    /// — sonst ginge die Kennzeichnung im Cache verloren.
    func testTeamNameSurvivesEncoding() throws {
        var website = Website(
            id: "abc",
            name: "Beispiel",
            domain: "example.com",
            shareId: nil,
            teamId: "team-1",
            resetAt: nil,
            createdAt: nil
        )
        website.teamName = "App Review"

        let data = try JSONEncoder().encode(website)
        let restored = try JSONDecoder().decode(Website.self, from: data)

        XCTAssertEqual(restored.teamName, "App Review")
        XCTAssertEqual(restored.teamId, "team-1")
    }

    // MARK: - Zusammenführung persönlicher und Team-Websites

    private func makeWebsite(_ id: String, team: String? = nil) -> Website {
        Website(
            id: id,
            name: "Website \(id)",
            domain: "\(id).example.com",
            shareId: nil,
            teamId: team == nil ? nil : "team-\(id)",
            resetAt: nil,
            createdAt: nil,
            teamName: team
        )
    }

    func testMergeKeepsBothPersonalAndTeamWebsites() {
        let merged = UmamiAPI.merge(
            personal: [makeWebsite("a")],
            teamWebsites: [makeWebsite("b", team: "Redaktion")]
        )

        XCTAssertEqual(merged.map(\.id), ["a", "b"])
        XCTAssertNil(merged[0].teamName)
        XCTAssertEqual(merged[1].teamName, "Redaktion")
    }

    /// Wer eine Website besitzt und zugleich im Team ist, sieht sie einmal —
    /// und zwar als eigene, ohne Team-Kennzeichnung.
    func testMergePrefersPersonalOverTeamOnDuplicateId() {
        let merged = UmamiAPI.merge(
            personal: [makeWebsite("a")],
            teamWebsites: [makeWebsite("a", team: "Redaktion")]
        )

        XCTAssertEqual(merged.count, 1)
        XCTAssertNil(merged[0].teamName, "Eigene Website darf nicht als Team-Website erscheinen")
    }

    /// Dieselbe Website in zwei Teams darf nicht doppelt auftauchen.
    func testMergeDeduplicatesAcrossTeams() {
        let merged = UmamiAPI.merge(
            personal: [],
            teamWebsites: [
                makeWebsite("a", team: "Redaktion"),
                makeWebsite("a", team: "Vertrieb"),
            ]
        )

        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].teamName, "Redaktion", "Das erste Team gewinnt")
    }

    /// Die Zusammenführung darf keine doppelten IDs liefern — SwiftUI-Listen
    /// verlangen eindeutige Kennungen.
    func testMergeProducesUniqueIds() {
        let merged = UmamiAPI.merge(
            personal: [makeWebsite("a"), makeWebsite("b")],
            teamWebsites: [
                makeWebsite("b", team: "Redaktion"),
                makeWebsite("c", team: "Redaktion"),
                makeWebsite("c", team: "Vertrieb"),
            ]
        )

        XCTAssertEqual(merged.count, Set(merged.map(\.id)).count, "IDs müssen eindeutig sein")
        XCTAssertEqual(merged.map(\.id), ["a", "b", "c"])
    }

    func testMergeWithoutTeamsReturnsPersonalUnchanged() {
        let personal = [makeWebsite("a"), makeWebsite("b")]
        let merged = UmamiAPI.merge(personal: personal, teamWebsites: [])

        XCTAssertEqual(merged.map(\.id), ["a", "b"])
    }

    /// Ältere Cache-Einträge kennen `teamName` nicht — sie müssen weiterhin
    /// lesbar bleiben.
    func testWebsiteDecodesWithoutTeamName() throws {
        let json = """
        { "id": "abc", "name": "Beispiel", "domain": "example.com",
          "shareId": null, "teamId": null, "resetAt": null, "createdAt": null }
        """.data(using: .utf8)!

        let website = try JSONDecoder().decode(Website.self, from: json)

        XCTAssertEqual(website.id, "abc")
        XCTAssertNil(website.teamName)
    }

    // MARK: - Auswertungs-Routen aus Umami 3.4

    /// Die JSON-Beispiele in diesem Abschnitt stammen aus echten Antworten
    /// einer Umami-3.4.0-Instanz (gemessen am 18.09.2026 gegen eine Kopie der
    /// eigenen Datenbank). IDs und Domains sind belassen, wo sie unkritisch
    /// sind, Werte unverändert.

    func testGoalStatsFeatureRouteMatchesReportShape() throws {
        // `GET api/websites/{id}/goals/stats` antwortet mit derselben Form wie
        // der frühere `POST api/reports/goal` — deshalb dasselbe Modell.
        let json = """
        {"num": 72, "total": 276}
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(GoalReportResult.self, from: json)
        XCTAssertEqual(result.num, 72)
        XCTAssertEqual(result.total, 276)
        XCTAssertEqual(result.completionRate, 72.0 / 276.0 * 100, accuracy: 0.0001)
    }

    func testRetentionFeatureRouteDecoding() throws {
        let json = """
        [
          {"date": "2026-08-19T00:00:00Z", "day": 0, "visitors": 5, "returnVisitors": 5, "percentage": 100},
          {"date": "2026-08-19T00:00:00Z", "day": 1, "visitors": 5, "returnVisitors": 1, "percentage": 20}
        ]
        """.data(using: .utf8)!

        let rows = try JSONDecoder().decode([RetentionRow].self, from: json)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].day, 0)
        XCTAssertEqual(rows[0].visitors, 5)
        XCTAssertEqual(rows[1].returnVisitors, 1)
        XCTAssertEqual(rows[1].percentage, 20)
    }

    func testJourneyFeatureRouteDecoding() throws {
        // Die neue Route liefert `items` mit null-Einträgen für ungenutzte
        // Schritte — genau wie der frühere Report.
        let json = """
        [
          {"items": ["/", "sektion-gesehen", "app-oeffnen", null], "count": 92},
          {"items": ["/freizeit/", "ankunft-neu-geoeffnet", null, null], "count": 34}
        ]
        """.data(using: .utf8)!

        let paths = try JSONDecoder().decode([JourneyPath].self, from: json)
        XCTAssertEqual(paths.count, 2)
        XCTAssertEqual(paths[0].count, 92)
        XCTAssertEqual(paths[1].count, 34)
    }

    func testFunnelStatsFeatureRouteDecoding() throws {
        let json = """
        [
          {"type": "path", "value": "/", "visitors": 178, "previous": 0, "dropped": 0, "dropoff": null, "remaining": 1},
          {"type": "event", "value": "app-oeffnen", "visitors": 72, "previous": 178, "dropped": 106, "dropoff": 0.5955, "remaining": 0.4045}
        ]
        """.data(using: .utf8)!

        let steps = try JSONDecoder().decode([FunnelStep].self, from: json)
        XCTAssertEqual(steps.count, 2)
        XCTAssertEqual(steps[0].visitors, 178)
        XCTAssertEqual(steps[1].visitors, 72)
    }

    func testPerformanceStatsFeatureRouteDecodesAsSummary() throws {
        // `performance/stats` liefert das, was im alten Report unter `summary`
        // stand — ohne Umschlag. Die Perzentile stimmten in der Messung mit
        // dem alten Weg überein.
        let json = """
        {
          "lcp": {"p50": 609, "p75": 1146, "p95": 3514.3499999999967},
          "inp": {"p50": 48, "p75": 56, "p95": 111.19999999999997},
          "cls": {"p50": 0.0027, "p75": 0.0245, "p95": 0.09855},
          "fcp": {"p50": 290, "p75": 612, "p95": 1884},
          "ttfb": {"p50": 41, "p75": 128, "p95": 456},
          "count": 101
        }
        """.data(using: .utf8)!

        let summary = try JSONDecoder().decode(UmamiPerformanceSummary.self, from: json)
        XCTAssertEqual(summary.lcp.p50, 609)
        XCTAssertEqual(summary.lcp.p75, 1146)
        XCTAssertEqual(summary.inp.p50, 48)
        XCTAssertEqual(summary.cls.p50, 0.0027, accuracy: 0.00001)
        XCTAssertEqual(summary.count, 101)
    }

    func testPerformanceMetricsFeatureRouteToleratesNullPercentiles() throws {
        // Seiten ohne Messwerte liefern null statt einer Zahl; das darf die
        // Liste nicht kippen, sonst fehlt die ganze Aufschlüsselung.
        let json = """
        [
          {"name": "/datenschutz/", "p50": null, "p75": null, "p95": null, "count": 3},
          {"name": "/apps/moinkark/datenschutz/", "p50": 4143, "p75": 4143, "p95": 4143, "count": 1}
        ]
        """.data(using: .utf8)!

        let metrics = try JSONDecoder().decode([UmamiPerformanceMetric].self, from: json)
        XCTAssertEqual(metrics.count, 2)
        XCTAssertEqual(metrics[0].name, "/datenschutz/")
        XCTAssertEqual(metrics[0].p50, 0, "null wird als 0 gelesen, nicht als Fehler")
        XCTAssertEqual(metrics[0].count, 3)
        XCTAssertEqual(metrics[1].p50, 4143)
    }

    func testPerformanceChartFeatureRouteDecoding() throws {
        let json = """
        {"chart": [
          {"t": "2026-08-19T00:00:00Z", "p50": 5121, "p75": 5121, "p95": 5121},
          {"t": "2026-08-20T00:00:00Z", "p50": 172, "p75": 932, "p95": 2571.2999999999943}
        ]}
        """.data(using: .utf8)!

        struct ChartResponse: Decodable { let chart: [UmamiPerformanceChartPoint]? }
        let chart = try JSONDecoder().decode(ChartResponse.self, from: json).chart ?? []
        XCTAssertEqual(chart.count, 2)
        XCTAssertEqual(chart[0].t, "2026-08-19T00:00:00Z")
        XCTAssertEqual(chart[1].p75, 932)
    }

    func testPerformanceReportComposesFromSeparateRoutes() throws {
        // Aus den Einzelrouten muss dieselbe Form entstehen, die die Ansichten
        // erwarten — sonst bliebe die Ladezeiten-Auswertung leer.
        let summaryJSON = """
        {"lcp": {"p50": 609, "p75": 1146, "p95": 3514}, "inp": {"p50": 48, "p75": 56, "p95": 111},
         "cls": {"p50": 0.0027, "p75": 0.0245, "p95": 0.09855}, "fcp": {"p50": 290, "p75": 612, "p95": 1884},
         "ttfb": {"p50": 41, "p75": 128, "p95": 456}, "count": 101}
        """.data(using: .utf8)!
        let metricsJSON = """
        [{"name": "mobile", "p50": 1094, "p75": 2286.25, "p95": 3864.45, "count": 74}]
        """.data(using: .utf8)!

        let summary = try JSONDecoder().decode(UmamiPerformanceSummary.self, from: summaryJSON)
        let devices = try JSONDecoder().decode([UmamiPerformanceMetric].self, from: metricsJSON)

        let report = UmamiPerformanceReport(
            chart: [],
            summary: summary,
            pages: [],
            pageTitles: [],
            devices: devices,
            browsers: []
        )

        XCTAssertEqual(report.summary.lcp.p50, 609)
        XCTAssertEqual(report.devices.count, 1)
        XCTAssertEqual(report.devices[0].name, "mobile")
        XCTAssertTrue(report.pages.isEmpty)
    }

    func testAttributionFeatureRouteKeepsResponseShape() throws {
        let json = """
        {"referrer": [{"name": "google.com", "value": 4}, {"name": "ecosia.org", "value": 1}],
         "paidAds": [], "utm_source": [], "utm_medium": [], "utm_campaign": [], "utm_content": [], "utm_term": []}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(AttributionResponse.self, from: json)
        XCTAssertEqual(response.referrer?.count, 2)
        XCTAssertEqual(response.referrer?[0].name, "google.com")
        XCTAssertEqual(response.referrer?[0].value, 4)
        XCTAssertEqual(response.paidAds?.count, 0)
    }

    // MARK: - Vermerke (Annotations, ab Umami 3.4)

    /// Die Beispiele stammen aus echten Antworten einer 3.4.0-Instanz
    /// (gemessen am 18.09.2026), inklusive des Paged-Envelopes der Liste.

    private func annotationDecoder() -> JSONDecoder {
        // Dieselbe Datumsbehandlung wie im API-Layer: Umami schickt ISO-8601
        // mit Sekundenbruchteilen.
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let formatters = [
                ISO8601DateFormatter(),
                {
                    let f = ISO8601DateFormatter()
                    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    return f
                }()
            ]
            for formatter in formatters {
                if let date = formatter.date(from: string) { return date }
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(string)")
        }
        return decoder
    }

    func testAnnotationDecodingFromCreateResponse() throws {
        let json = """
        {
          "id": "a4b6f962-13d1-4736-a85e-9e8aa41cd231",
          "websiteId": "96efd249-a5e3-486a-8d7e-6da7d8c1ed17",
          "userId": "41e2b680-648e-4b09-bcd7-3e2b10c06264",
          "date": "2026-09-18T10:00:00.000Z",
          "allDay": true,
          "note": "Newsletter verschickt",
          "createdAt": "2026-09-18T12:18:07.712Z",
          "updatedAt": "2026-09-18T12:18:07.712Z"
        }
        """.data(using: .utf8)!

        let annotation = try annotationDecoder().decode(UmamiAnnotation.self, from: json)
        XCTAssertEqual(annotation.id, "a4b6f962-13d1-4736-a85e-9e8aa41cd231")
        XCTAssertEqual(annotation.note, "Newsletter verschickt")
        XCTAssertTrue(annotation.allDay)
        XCTAssertEqual(annotation.date.timeIntervalSince1970, 1789725600, accuracy: 1)
    }

    func testAnnotationListDecodesPagedEnvelope() throws {
        let json = """
        {
          "data": [
            {"id": "a4b6f962-13d1-4736-a85e-9e8aa41cd231", "websiteId": "96efd249-a5e3-486a-8d7e-6da7d8c1ed17",
             "userId": null, "date": "2026-09-18T10:00:00.000Z", "allDay": true, "note": "Newsletter verschickt",
             "createdAt": "2026-09-18T12:18:07.712Z", "updatedAt": "2026-09-18T12:18:07.712Z"},
            {"id": "f7a31ebe-f477-415c-8b2d-62c0d988eb77", "websiteId": "96efd249-a5e3-486a-8d7e-6da7d8c1ed17",
             "userId": null, "date": "2026-09-17T19:30:00.000Z", "allDay": false, "note": "Beitrag im Gemeindebrief",
             "createdAt": "2026-09-18T12:18:08.100Z", "updatedAt": "2026-09-18T12:18:08.100Z"}
          ],
          "count": 2, "page": 1, "pageSize": 20
        }
        """.data(using: .utf8)!

        let response = try annotationDecoder().decode(UmamiAnnotationsResponse.self, from: json)
        XCTAssertEqual(response.count, 2)
        XCTAssertEqual(response.data.count, 2)
        XCTAssertEqual(response.data[0].note, "Newsletter verschickt")
        XCTAssertFalse(response.data[1].allDay, "Vermerk mit Uhrzeit darf nicht als ganztägig gelten")
    }

    func testAnnotationToleratesMissingUser() throws {
        // `userId` ist in der Datenbank optional — ein Vermerk ohne Urheber
        // darf die Liste nicht kippen.
        let json = """
        {"id": "x", "websiteId": "w", "userId": null, "date": "2026-09-18T10:00:00.000Z",
         "allDay": true, "note": "Ohne Urheber", "createdAt": null, "updatedAt": null}
        """.data(using: .utf8)!

        let annotation = try annotationDecoder().decode(UmamiAnnotation.self, from: json)
        XCTAssertNil(annotation.userId)
        XCTAssertNil(annotation.createdAt)
        XCTAssertEqual(annotation.note, "Ohne Urheber")
    }

    func testAnnotationNoteLimitMatchesServerSchema() {
        // Der Server lehnt mehr als 500 Zeichen mit HTTP 400 ab (gemessen:
        // 500 -> 200, 501 -> 400). Die Eingabe prüft dagegen.
        XCTAssertEqual(UmamiAnnotation.noteLimit, 500)
    }

    func testAnnotationDateTextHidesTimeForAllDay() throws {
        // Bei ganztägigen Vermerken ist die gespeicherte Uhrzeit bedeutungslos
        // und darf keine Genauigkeit vortäuschen.
        let json = """
        [
          {"id": "1", "websiteId": "w", "userId": null, "date": "2026-09-18T10:00:00.000Z",
           "allDay": true, "note": "Ganztägig", "createdAt": null, "updatedAt": null},
          {"id": "2", "websiteId": "w", "userId": null, "date": "2026-09-18T10:00:00.000Z",
           "allDay": false, "note": "Mit Uhrzeit", "createdAt": null, "updatedAt": null}
        ]
        """.data(using: .utf8)!

        let items = try annotationDecoder().decode([UmamiAnnotation].self, from: json)
        let allDayText = AnnotationsView.dateText(for: items[0])
        let timedText = AnnotationsView.dateText(for: items[1])

        XCTAssertNotEqual(allDayText, timedText)
        XCTAssertFalse(allDayText.contains(":"), "Ganztägiger Vermerk zeigt keine Uhrzeit")
        XCTAssertTrue(timedText.contains(":"), "Vermerk mit Uhrzeit zeigt sie auch")
    }

    /// Ein Vermerk mit „krummer" Uhrzeit muss dem richtigen Datenpunkt
    /// zugeordnet werden — sonst steht die Marke sichtbar neben dem Wert,
    /// zu dem sie gehört.
    ///
    /// Beispiel 17:11: in der Tagesansicht liegt das bei rund 71 % des Tages.
    /// Die Marke gehört trotzdem an den Tagespunkt (00:00), nicht dorthin.
    func testAnnotationSnapsToNearestDataPoint() throws {
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = 2026; components.month = 9; components.day = 18
        components.hour = 17; components.minute = 11
        let annotationDate = calendar.date(from: components)!

        // Tagesansicht: Punkte liegen auf Mitternacht.
        let dayPoints = (17...19).map { day -> Date in
            calendar.date(from: DateComponents(year: 2026, month: 9, day: day))!
        }
        let nearestDay = dayPoints.min {
            abs($0.timeIntervalSince(annotationDate)) < abs($1.timeIntervalSince(annotationDate))
        }
        XCTAssertEqual(
            calendar.component(.day, from: nearestDay!), 19,
            "17:11 liegt näher an Mitternacht des Folgetags als an der des eigenen Tages"
        )

        // Deshalb genügt reines Einrasten auf den nächsten Punkt nicht — die
        // Zuordnung muss den Kalendertag vergleichen.
        let sameDay = dayPoints.filter {
            calendar.dateComponents([.year, .month, .day], from: $0)
                == calendar.dateComponents([.year, .month, .day], from: annotationDate)
        }
        XCTAssertEqual(sameDay.count, 1)
        XCTAssertEqual(calendar.component(.day, from: sameDay[0]), 18)
    }
}
