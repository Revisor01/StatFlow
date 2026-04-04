import Foundation
import os

// MARK: - ViewModel

enum ComparisonPeriod: CaseIterable {
    case weekOverWeek
    case monthOverMonth

    var displayName: String {
        switch self {
        case .weekOverWeek: return String(localized: "compare.week")
        case .monthOverMonth: return String(localized: "compare.month")
        }
    }

    var currentLabel: String {
        switch self {
        case .weekOverWeek: return String(localized: "insights.thisWeek")
        case .monthOverMonth: return String(localized: "compare.month")
        }
    }

    var previousLabel: String {
        switch self {
        case .weekOverWeek: return String(localized: "insights.lastWeek")
        case .monthOverMonth: return String(localized: "insights.lastMonth")
        }
    }

    var currentRange: DateRange {
        switch self {
        case .weekOverWeek: return .last7Days
        case .monthOverMonth: return .thisMonth
        }
    }

    var previousRange: DateRange {
        switch self {
        case .weekOverWeek:
            let calendar = Calendar.current
            let now = Date()
            let start = calendar.date(byAdding: .day, value: -13, to: calendar.startOfDay(for: now))!
            let end = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now))!
            return .custom(start: start, end: end)
        case .monthOverMonth:
            return .lastMonth
        }
    }
}

struct ComparisonDataPoint: Identifiable {
    let id = UUID()
    let dayIndex: Int
    let value: Int
}

@MainActor
class ComparisonViewModel: ObservableObject {
    let websiteId: String

    @Published var selectedPeriod: ComparisonPeriod = .weekOverWeek
    @Published var currentStats: WebsiteStats?
    @Published var previousStats: WebsiteStats?
    @Published var currentPageviews: [ComparisonDataPoint] = []
    @Published var previousPageviews: [ComparisonDataPoint] = []
    @Published var isLoading = false

    private var loadingTask: Task<Void, Never>?
    private let api: UmamiAPI

    init(websiteId: String, api: UmamiAPI = .shared) {
        self.websiteId = websiteId
        self.api = api
    }

    func loadComparison() async {
        loadingTask?.cancel()
        let task = Task {
            isLoading = true
            defer { if !Task.isCancelled { isLoading = false } }

            do {
                async let currentStatsTask = api.getStats(websiteId: websiteId, dateRange: selectedPeriod.currentRange)
                async let previousStatsTask = api.getStats(websiteId: websiteId, dateRange: selectedPeriod.previousRange)
                async let currentPageviewsTask = api.getPageviews(websiteId: websiteId, dateRange: selectedPeriod.currentRange)
                async let previousPageviewsTask = api.getPageviews(websiteId: websiteId, dateRange: selectedPeriod.previousRange)

                let (current, previous, currentPV, previousPV) = try await (
                    currentStatsTask, previousStatsTask, currentPageviewsTask, previousPageviewsTask
                )
                guard !Task.isCancelled else { return }

                currentStats = current
                previousStats = previous

                currentPageviews = currentPV.pageviews.enumerated().map { index, point in
                    ComparisonDataPoint(dayIndex: index, value: point.value)
                }

                previousPageviews = previousPV.pageviews.enumerated().map { index, point in
                    ComparisonDataPoint(dayIndex: index, value: point.value)
                }

            } catch {
                guard !Task.isCancelled else { return }
                Logger.ui.error("Comparison error: \(error.localizedDescription)")
            }
        }
        loadingTask = task
        await task.value
    }
}
