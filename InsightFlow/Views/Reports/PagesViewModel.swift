import Foundation
import os

@MainActor
class PagesViewModel: ObservableObject {
    let websiteId: String

    @Published var topPages: [MetricItem] = []
    @Published var pageTitles: [MetricItem] = []
    @Published var combinedPages: [CombinedPage] = []
    @Published var isLoading = false

    private var loadingTask: Task<Void, Never>?
    private let api: UmamiAPI

    init(websiteId: String, api: UmamiAPI = .shared) {
        self.websiteId = websiteId
        self.api = api
    }

    func loadData(dateRange: DateRange) async {
        loadingTask?.cancel()
        let task = Task {
            isLoading = true
            defer { if !Task.isCancelled { isLoading = false } }

            async let pagesTask = api.getMetrics(websiteId: websiteId, dateRange: dateRange, type: .path, limit: 100)
            async let titlesTask = api.getMetrics(websiteId: websiteId, dateRange: dateRange, type: .title, limit: 100)

            do {
                let result = try await pagesTask
                guard !Task.isCancelled else { return }
                topPages = result
            } catch {
                guard !Task.isCancelled else { return }
                Logger.ui.error("Failed to load top pages: \(error.localizedDescription)")
            }

            do {
                let result = try await titlesTask
                guard !Task.isCancelled else { return }
                pageTitles = result
            } catch {
                guard !Task.isCancelled else { return }
                Logger.ui.error("Failed to load page titles: \(error.localizedDescription)")
            }

            guard !Task.isCancelled else { return }
            // Kombiniere Titel und Pfade
            combinedPages = createCombinedPages()
        }
        loadingTask = task
        await task.value
    }

    private func createCombinedPages() -> [CombinedPage] {
        // Erstelle eine Liste mit allen Pfaden und versuche passende Titel zu finden
        var result: [CombinedPage] = []
        var usedTitles: Set<String> = []

        for page in topPages {
            let matchingTitle = findBestTitleMatch(for: page, excluding: usedTitles)

            if let title = matchingTitle {
                usedTitles.insert(title.name)
                result.append(CombinedPage(
                    title: title.name,
                    path: page.name,
                    views: page.value
                ))
            } else {
                // Kein passender Titel gefunden - verwende Pfad als Fallback
                result.append(CombinedPage(
                    title: extractTitleFromPath(page.name),
                    path: page.name,
                    views: page.value
                ))
            }
        }

        return result.sorted { $0.views > $1.views }
    }

    private func findBestTitleMatch(for page: MetricItem, excluding usedTitles: Set<String>) -> MetricItem? {
        // Strategie 1: Exakte Übereinstimmung der Aufrufzahlen
        if let exactMatch = pageTitles.first(where: {
            $0.value == page.value && !usedTitles.contains($0.name)
        }) {
            return exactMatch
        }

        // Strategie 2: Ähnliche Aufrufzahlen (±5%)
        let tolerance = max(1, Int(Double(page.value) * 0.05))
        if let closeMatch = pageTitles.first(where: {
            abs($0.value - page.value) <= tolerance && !usedTitles.contains($0.name)
        }) {
            return closeMatch
        }

        // Strategie 3: Noch breitere Toleranz (±15%)
        let broaderTolerance = max(2, Int(Double(page.value) * 0.15))
        return pageTitles.first(where: {
            abs($0.value - page.value) <= broaderTolerance && !usedTitles.contains($0.name)
        })
    }

    // Versuche einen sinnvollen Titel aus dem Pfad zu extrahieren
    private func extractTitleFromPath(_ path: String) -> String {
        // Für /details?postId=123 -> "Details"
        // Für /kontakt -> "Kontakt"
        // Für / -> "Startseite"

        if path == "/" {
            return String(localized: "pages.homepage")
        }

        // Extrahiere den Hauptpfad ohne Query-Parameter
        let mainPath = path.split(separator: "?").first ?? Substring(path)

        // Entferne führenden Slash und nimm den letzten Teil
        let segments = mainPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .split(separator: "/")

        if let lastSegment = segments.last {
            // Formatiere: details -> Details, mein-artikel -> Mein Artikel
            return String(lastSegment)
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }

        return path
    }
}
