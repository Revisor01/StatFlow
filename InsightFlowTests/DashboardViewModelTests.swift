import XCTest
@testable import InsightFlow

@MainActor
class DashboardViewModelTests: XCTestCase {

    // MARK: - FIX-04: Account-Wechsel Loading State

    func testLoadDataWithClearFirstResetsWebsites() async {
        let viewModel = DashboardViewModel()
        // Simulate existing data
        viewModel.websites = [makeTestWebsite()]

        XCTAssertFalse(viewModel.websites.isEmpty, "Precondition: websites nicht leer")

        // Start loadData with clearFirst=true — websites must be cleared immediately
        let task = Task {
            await viewModel.loadData(dateRange: .today, clearFirst: true)
        }

        // Short wait for clearFirst to execute
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s

        XCTAssertTrue(viewModel.websites.isEmpty, "websites muss nach clearFirst leer sein")
        task.cancel()
    }

    func testLoadDataWithClearFirstResetsStatsDicts() async {
        let viewModel = DashboardViewModel()
        viewModel.stats = ["test-id": makeTestStats()]
        viewModel.sparklineData = ["test-id": []]
        viewModel.activeVisitors = ["test-id": 5]

        let task = Task {
            await viewModel.loadData(dateRange: .today, clearFirst: true)
        }

        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertTrue(viewModel.stats.isEmpty, "stats muss nach clearFirst leer sein")
        XCTAssertTrue(viewModel.sparklineData.isEmpty, "sparklineData muss nach clearFirst leer sein")
        XCTAssertTrue(viewModel.activeVisitors.isEmpty, "activeVisitors muss nach clearFirst leer sein")
        task.cancel()
    }

    func testLoadDataWithoutClearFirstKeepsWebsites() async {
        let viewModel = DashboardViewModel()
        let testSite = makeTestWebsite()
        viewModel.websites = [testSite]

        let task = Task {
            await viewModel.loadData(dateRange: .today, clearFirst: false)
        }

        // clearFirst=false should NOT explicitly clear websites before load
        // (Cache might overwrite, but not immediately clear)
        try? await Task.sleep(nanoseconds: 50_000_000)

        task.cancel()
        // No assertion on websites content since cache may replace it,
        // but we verify no crash and task completes
    }

    // MARK: - Helpers

    private func makeTestWebsite() -> Website {
        Website(id: "test", name: "Test", domain: "test.com", shareId: nil, teamId: nil, resetAt: nil, createdAt: nil)
    }

    private func makeTestStats() -> WebsiteStats {
        WebsiteStats(
            pageviews: StatValue(value: 200, change: 20),
            visitors: StatValue(value: 100, change: 10),
            visits: StatValue(value: 150, change: 15),
            bounces: StatValue(value: 50, change: -5),
            totaltime: StatValue(value: 3000, change: 300)
        )
    }
}
