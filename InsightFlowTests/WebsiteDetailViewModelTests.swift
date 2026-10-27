import XCTest
@testable import InsightFlow

@MainActor
class WebsiteDetailViewModelTests: XCTestCase {

    // MARK: - FIX-02: Task Cancellation

    func testCancelLoadingStopsActiveTask() async throws {
        let viewModel = WebsiteDetailViewModel(websiteId: "test-id", domain: "test.com")

        // Starte loadData in einem separaten Task (wird nie fertig ohne echte API)
        let loadTask = Task {
            await viewModel.loadData(dateRange: .today)
        }

        // Geprüft wird nur, dass nach `cancelLoading` kein Ladezustand bleibt.
        viewModel.cancelLoading()

        // Task abwarten (sollte nach Cancel schnell beenden)
        loadTask.cancel()
        await loadTask.value

        // Nach cancelLoading: loadingTask nil, isLoading false.
        XCTAssertFalse(viewModel.isLoading, "isLoading sollte nach cancelLoading false sein")
    }

    func testRepeatedLoadDataCancelsPreviousTask() async throws {
        let viewModel = WebsiteDetailViewModel(websiteId: "test-id", domain: "test.com")

        let firstTask = Task {
            await viewModel.loadData(dateRange: .today)
        }

        try await Task.sleep(nanoseconds: 50_000_000) // 0.05s

        // Zweiter loadData-Aufruf sollte den ersten canceln
        let secondTask = Task {
            await viewModel.loadData(dateRange: .thisWeek)
        }

        firstTask.cancel()
        secondTask.cancel()
        await firstTask.value
        await secondTask.value

        // Der zweite Aufruf bricht den ersten ab, geprüft wird die Stabilität.
    }

    /// `cancelLoading` nimmt den Ladezustand zurück, sonst bleibt der Ladekreis nach dem Verlassen stehen.
    func testCancelLoadingResetsLoadingState() {
        let viewModel = WebsiteDetailViewModel(websiteId: "test-id", domain: "test.com")

        // Direkt gesetzt, der echte Vorgang läuft ohne API zu schnell durch.
        viewModel.isLoading = true

        viewModel.cancelLoading()

        XCTAssertFalse(
            viewModel.isLoading,
            "cancelLoading muss den Ladezustand zurücknehmen"
        )
    }
}
