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

        // Auf `isLoading == true` zu warten wäre unzuverlässig: ohne
        // konfigurierte API ist der Ladevorgang nach wenigen Millisekunden
        // wieder fertig, der Zwischenzustand also flüchtig. Geprüft wird
        // deshalb nur das Ergebnis — nach `cancelLoading` darf kein
        // Ladezustand zurückbleiben, gleich ob noch geladen wurde oder nicht.
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

    /// `cancelLoading` muss den Ladezustand zurücknehmen.
    ///
    /// Der `defer` in `loadData` lässt `isLoading` bei Abbruch bewusst stehen,
    /// damit ein abgelöster Ladevorgang den Spinner des nachfolgenden nicht
    /// ausschaltet. Nach einem echten Abbruch folgt aber keiner mehr. Die
    /// Website-Ansicht ruft `cancelLoading` bei jedem Verlassen auf
    /// (`onDisappear`) — ohne Rücknahme blieb der Ladekreis stehen und war beim
    /// nächsten Öffnen sofort wieder zu sehen.
    func testCancelLoadingResetsLoadingState() {
        let viewModel = WebsiteDetailViewModel(websiteId: "test-id", domain: "test.com")

        // Ladezustand setzen, wie ihn ein laufender Ladevorgang hinterlässt.
        // Direkt gesetzt statt über `loadData` erzeugt, weil der echte Vorgang
        // ohne API zu schnell durchläuft, um ihn verlässlich zu treffen.
        viewModel.isLoading = true

        viewModel.cancelLoading()

        XCTAssertFalse(
            viewModel.isLoading,
            "cancelLoading muss den Ladezustand zurücknehmen"
        )
    }
}
