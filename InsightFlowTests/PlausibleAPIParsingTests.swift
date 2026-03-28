import XCTest
@testable import InsightFlow

final class PlausibleAPIParsingTests: XCTestCase {

    // MARK: - PlausibleAPIResponse

    func testPlausibleAPIResponseDecoding() throws {
        let json = """
        {
            "results": [
                {"metrics": [100.0, 200.0, 150.0, 45.5, 120.0], "dimensions": []},
                {"metrics": [50.0, 80.0, 60.0, 30.0, 90.0], "dimensions": []}
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(PlausibleAPIResponse.self, from: json)
        XCTAssertEqual(response.results.count, 2)
        XCTAssertEqual(response.results[0].metrics.count, 5)
        XCTAssertEqual(response.results[1].metrics[0], 50.0, accuracy: 0.001)
    }

    // MARK: - PlausibleStatsResult

    func testPlausibleStatsResultFromAPIResult() throws {
        let json = """
        {"metrics": [100.0, 200.0, 150.0, 45.5, 120.0], "dimensions": []}
        """.data(using: .utf8)!

        let apiResult = try JSONDecoder().decode(PlausibleAPIResult.self, from: json)
        let stats = PlausibleStatsResult(from: apiResult)

        XCTAssertEqual(stats.visitors, 100)
        XCTAssertEqual(stats.pageviews, 200)
        XCTAssertEqual(stats.visits, 150)
        XCTAssertEqual(stats.bounceRate, 45.5, accuracy: 0.001)
        XCTAssertEqual(stats.visitDuration, 120)
    }

    func testPlausibleStatsResultEmptyMetrics() throws {
        let json = """
        {"metrics": [], "dimensions": []}
        """.data(using: .utf8)!

        let apiResult = try JSONDecoder().decode(PlausibleAPIResult.self, from: json)
        let stats = PlausibleStatsResult(from: apiResult)

        XCTAssertEqual(stats.visitors, 0)
        XCTAssertEqual(stats.pageviews, 0)
        XCTAssertEqual(stats.visits, 0)
        XCTAssertEqual(stats.bounceRate, 0.0, accuracy: 0.001)
        XCTAssertEqual(stats.visitDuration, 0)
    }

    func testPlausibleStatsResultPartialMetrics() throws {
        let json = """
        {"metrics": [75.0, 120.0], "dimensions": []}
        """.data(using: .utf8)!

        let apiResult = try JSONDecoder().decode(PlausibleAPIResult.self, from: json)
        let stats = PlausibleStatsResult(from: apiResult)

        XCTAssertEqual(stats.visitors, 75)
        XCTAssertEqual(stats.pageviews, 120)
        XCTAssertEqual(stats.visits, 0)
        XCTAssertEqual(stats.bounceRate, 0.0, accuracy: 0.001)
        XCTAssertEqual(stats.visitDuration, 0)
    }

    // MARK: - PlausibleTimeseriesResult

    func testPlausibleTimeseriesResult() throws {
        let json = """
        {"dimensions": ["2025-01-15"], "metrics": [42.0]}
        """.data(using: .utf8)!

        let apiResult = try JSONDecoder().decode(PlausibleAPIResult.self, from: json)
        let timeseries = PlausibleTimeseriesResult(from: apiResult)

        XCTAssertEqual(timeseries.date, "2025-01-15")
        XCTAssertEqual(timeseries.value, 42)
    }

    // MARK: - PlausibleBreakdownResult

    func testPlausibleBreakdownResult() throws {
        let json = """
        {"dimensions": ["Chrome"], "metrics": [500.0]}
        """.data(using: .utf8)!

        let apiResult = try JSONDecoder().decode(PlausibleAPIResult.self, from: json)
        let breakdown = PlausibleBreakdownResult(from: apiResult)

        XCTAssertEqual(breakdown.dimension, "Chrome")
        XCTAssertEqual(breakdown.visitors, 500)
    }

    // MARK: - PlausibleSitesResponse

    func testPlausibleSitesResponseDecoding() throws {
        let json = """
        {
            "data": [
                {"domain": "example.com", "timezone": "Europe/Berlin"},
                {"domain": "other.org", "timezone": "America/New_York"}
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(PlausibleSitesResponse.self, from: json)
        XCTAssertEqual(response.sites.count, 2)
        XCTAssertEqual(response.sites[0].domain, "example.com")
        XCTAssertEqual(response.sites[0].timezone, "Europe/Berlin")
        XCTAssertEqual(response.sites[1].domain, "other.org")
    }

    func testPlausibleSitesResponseEmptyArray() throws {
        let json = """
        {"data": []}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(PlausibleSitesResponse.self, from: json)
        XCTAssertEqual(response.sites.count, 0)
    }

    // MARK: - Edge Cases

    func testPlausibleAPIResultEmptyDimensions() throws {
        let jsonTimeseries = """
        {"dimensions": [], "metrics": [10.0]}
        """.data(using: .utf8)!

        let apiResultTimeseries = try JSONDecoder().decode(PlausibleAPIResult.self, from: jsonTimeseries)
        let timeseries = PlausibleTimeseriesResult(from: apiResultTimeseries)
        XCTAssertEqual(timeseries.date, "")

        let jsonBreakdown = """
        {"dimensions": [], "metrics": [5.0]}
        """.data(using: .utf8)!

        let apiResultBreakdown = try JSONDecoder().decode(PlausibleAPIResult.self, from: jsonBreakdown)
        let breakdown = PlausibleBreakdownResult(from: apiResultBreakdown)
        XCTAssertEqual(breakdown.dimension, "Unknown")
    }

    func testInvalidPlausibleJSONThrowsError() {
        let invalidData = "this is not json".data(using: .utf8)!
        XCTAssertThrowsError(
            try JSONDecoder().decode(PlausibleAPIResponse.self, from: invalidData)
        ) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }
}
