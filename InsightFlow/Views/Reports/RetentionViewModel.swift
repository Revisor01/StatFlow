import Foundation
import os

@MainActor
class RetentionViewModel: ObservableObject {
    let websiteId: String

    @Published var retentionRows: [RetentionRow] = []
    @Published var isLoading = false

    private var loadingTask: Task<Void, Never>?
    private let api: UmamiAPI

    init(websiteId: String, api: UmamiAPI = .shared) {
        self.websiteId = websiteId
        self.api = api
    }

    // Nur Zeilen mit day > 0 (echte Rückkehrer)
    var returningVisitorRows: [RetentionRow] {
        retentionRows.filter { $0.day > 0 }
    }

    var totalVisitors: Int {
        retentionRows.filter { $0.day == 0 }.reduce(0) { $0 + $1.visitors }
    }

    var uniqueDays: Int {
        Set(retentionRows.map { $0.date }).count
    }

    var averageRetention: Double {
        let rows = returningVisitorRows
        guard !rows.isEmpty else { return 0 }
        let total = rows.reduce(0.0) { $0 + $1.percentage }
        return total / Double(rows.count)
    }

    var maxRetention: Double {
        returningVisitorRows.map(\.percentage).max() ?? 0
    }

    var chartData: [RetentionChartPoint] {
        // Gruppiere nach Tag (day) und berechne Durchschnitt
        var dayAverages: [Int: [Double]] = [:]
        for row in returningVisitorRows {
            dayAverages[row.day, default: []].append(row.percentage)
        }

        return dayAverages.keys.sorted().map { day in
            let percentages = dayAverages[day]!
            let avg = percentages.reduce(0, +) / Double(percentages.count)
            return RetentionChartPoint(day: day, percentage: avg)
        }
    }

    func loadRetention(dateRange: DateRange) async {
        loadingTask?.cancel()
        let task = Task {
            isLoading = true
            defer { if !Task.isCancelled { isLoading = false } }

            do {
                let result = try await api.getRetention(websiteId: websiteId, dateRange: dateRange)
                guard !Task.isCancelled else { return }
                retentionRows = result
            } catch {
                guard !Task.isCancelled else { return }
                Logger.ui.error("Retention error: \(error.localizedDescription)")
                retentionRows = []
            }
        }
        loadingTask = task
        await task.value
    }
}
