import XCTest
@testable import InsightFlow

class AnalyticsCacheServiceTests: XCTestCase {

    var tempDir: URL!
    var sut: AnalyticsCacheService!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        sut = AnalyticsCacheService(cacheDirectoryOverride: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        sut = nil
        tempDir = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeCachedWebsite(id: String = "1", domain: String = "test.com") -> CachedWebsite {
        CachedWebsite(from: AnalyticsWebsite(
            id: id,
            name: "Test Site",
            domain: domain,
            shareId: nil,
            provider: .umami
        ))
    }

    private func makeCachedStats(visitors: Int = 100) -> CachedStats {
        CachedStats(from: AnalyticsStats(
            visitors: StatValue(value: visitors, change: 10),
            pageviews: StatValue(value: 200, change: 20),
            visits: StatValue(value: 150, change: 15),
            bounces: StatValue(value: 50, change: -5),
            totaltime: StatValue(value: 3000, change: 300)
        ))
    }

    // MARK: - Tests

    func testSaveAndLoadWebsites() {
        let website = makeCachedWebsite(domain: "test.com")

        sut.saveWebsites([website], accountId: "acc-1")
        let result = sut.loadWebsites(accountId: "acc-1")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.data.count, 1)
        XCTAssertEqual(result?.data[0].domain, "test.com")
    }

    func testLoadWebsitesNotExpired() {
        let website = makeCachedWebsite()

        sut.saveWebsites([website], accountId: "acc-1")
        let result = sut.loadWebsites(accountId: "acc-1")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.isExpired, false)
    }

    func testSaveAndLoadStats() {
        let stats = makeCachedStats(visitors: 42)

        sut.saveStats(stats, websiteId: "web-1", dateRangeId: "7d")
        let result = sut.loadStats(websiteId: "web-1", dateRangeId: "7d")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.data.visitors.value, 42)
    }

    func testLoadNonExistentKeyReturnsNil() {
        let result = sut.loadWebsites(accountId: "nonexistent")

        XCTAssertNil(result)
    }

    func testClearAllCache() {
        let website = makeCachedWebsite()
        sut.saveWebsites([website], accountId: "acc-1")

        sut.clearAllCache()

        XCTAssertNil(sut.loadWebsites(accountId: "acc-1"))
    }

    func testClearCacheForAccount() {
        let website = makeCachedWebsite()
        sut.saveWebsites([website], accountId: "acc-1")
        sut.saveWebsites([website], accountId: "acc-2")

        sut.clearCache(forAccount: "acc-1")

        XCTAssertNil(sut.loadWebsites(accountId: "acc-1"))
        XCTAssertNotNil(sut.loadWebsites(accountId: "acc-2"))
    }

    func testClearCacheForWebsite() {
        let stats1 = makeCachedStats(visitors: 10)
        let stats2 = makeCachedStats(visitors: 20)
        sut.saveStats(stats1, websiteId: "web-1", dateRangeId: "7d")
        sut.saveStats(stats2, websiteId: "web-2", dateRangeId: "7d")

        sut.clearCache(for: "web-1")

        XCTAssertNil(sut.loadStats(websiteId: "web-1", dateRangeId: "7d"))
        XCTAssertNotNil(sut.loadStats(websiteId: "web-2", dateRangeId: "7d"))
    }

    func testCacheSizeReturnsNonZeroAfterSave() {
        let website = makeCachedWebsite()

        sut.saveWebsites([website], accountId: "acc-1")

        XCTAssertGreaterThan(sut.cacheSize(), 0)
    }

    func testLoadExpiredWebsitesReturnsIsExpiredTrue() {
        let expiredJSON = """
        {
          "data": [{"id": "1", "name": "Test Site", "domain": "expired.com", "shareId": null, "provider": "umami"}],
          "cachedAt": "2020-01-01T00:00:00Z",
          "expiresAt": "2020-01-02T00:00:00Z"
        }
        """.data(using: .utf8)!

        let fileURL = tempDir.appendingPathComponent("websites_acc-expired.json")
        try! expiredJSON.write(to: fileURL)

        let result = sut.loadWebsites(accountId: "acc-expired")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.isExpired, true)
        XCTAssertEqual(result?.data.count, 1)
    }

    func testClearExpiredCacheRemovesExpiredEntries() {
        // Save a fresh (non-expired) entry
        sut.saveWebsites([makeCachedWebsite()], accountId: "acc-fresh")

        // Write an expired entry manually
        let expiredJSON = """
        {
          "data": [{"id": "1", "name": "Old Site", "domain": "old.com", "shareId": null, "provider": "umami"}],
          "cachedAt": "2020-01-01T00:00:00Z",
          "expiresAt": "2020-01-02T00:00:00Z"
        }
        """.data(using: .utf8)!
        let expiredFileURL = tempDir.appendingPathComponent("websites_acc-old.json")
        try! expiredJSON.write(to: expiredFileURL)

        sut.clearExpiredCache()

        XCTAssertNil(sut.loadWebsites(accountId: "acc-old"))
        XCTAssertNotNil(sut.loadWebsites(accountId: "acc-fresh"))
    }
}
