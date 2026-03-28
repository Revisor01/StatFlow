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
}
