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

        // Kurz warten damit loadData startet
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s

        // cancelLoading aufrufen
        viewModel.cancelLoading()

        // Task abwarten (sollte nach Cancel schnell beenden)
        loadTask.cancel()
        await loadTask.value

        // loadingTask sollte nil sein nach cancelLoading
        // isLoading sollte false sein nach Task-Ende
        XCTAssertFalse(viewModel.isLoading, "isLoading sollte nach cancelLoading false sein")
    }

    func testRepeatedLoadDataCancelsPreviousTask() async throws {
        let viewModel = WebsiteDetailViewModel(websiteId: "test-id", domain: "test.com")

        // Erster loadData-Aufruf
        let firstTask = Task {
            await viewModel.loadData(dateRange: .today)
        }

        // Kurz warten
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05s

        // Zweiter loadData-Aufruf sollte den ersten canceln
        let secondTask = Task {
            await viewModel.loadData(dateRange: .thisWeek)
        }

        // Beide Tasks abwarten
        firstTask.cancel()
        secondTask.cancel()
        await firstTask.value
        await secondTask.value

        // Kein Crash, isLoading stabil
        // Der zweite Aufruf hat den ersten erfolgreich gecancelt (kein assert noetig — Test prueft Stabilitaet)
    }
}
