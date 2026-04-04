import SwiftUI
import Foundation

// MARK: - ViewModel

@MainActor
class CompareViewModel: ObservableObject {
    let websiteId: String

    @Published var stats1: WebsiteStats?
    @Published var stats2: WebsiteStats?
    @Published var pageviews1: [TimeSeriesPoint] = []
    @Published var pageviews2: [TimeSeriesPoint] = []
    @Published var visitors1: [TimeSeriesPoint] = []
    @Published var visitors2: [TimeSeriesPoint] = []
    @Published var isLoading = false

    private var loadingTask: Task<Void, Never>?
    private let umamiAPI = UmamiAPI.shared
    private let plausibleAPI = PlausibleAPI.shared

    private var isPlausible: Bool {
        AnalyticsManager.shared.providerType == .plausible
    }

    init(websiteId: String) {
        self.websiteId = websiteId
    }

    func loadComparison(dateRange1: DateRange, dateRange2: DateRange) async {
        loadingTask?.cancel()
        let task = Task {
            isLoading = true
            defer { if !Task.isCancelled { isLoading = false } }

            if isPlausible {
                await loadPlausibleComparison(dateRange1: dateRange1, dateRange2: dateRange2)
            } else {
                await loadUmamiComparison(dateRange1: dateRange1, dateRange2: dateRange2)
            }
        }
        loadingTask = task
        await task.value
    }

    private func loadPlausibleComparison(dateRange1: DateRange, dateRange2: DateRange) async {
        do {
            async let s1 = plausibleAPI.getAnalyticsStats(websiteId: websiteId, dateRange: dateRange1)
            async let s2 = plausibleAPI.getAnalyticsStats(websiteId: websiteId, dateRange: dateRange2)
            async let pv1 = plausibleAPI.getPageviewsData(websiteId: websiteId, dateRange: dateRange1)
            async let pv2 = plausibleAPI.getPageviewsData(websiteId: websiteId, dateRange: dateRange2)
            async let v1 = plausibleAPI.getVisitorsData(websiteId: websiteId, dateRange: dateRange1)
            async let v2 = plausibleAPI.getVisitorsData(websiteId: websiteId, dateRange: dateRange2)

            let (analyticsStats1, analyticsStats2, pageviewsData1, pageviewsData2, visitorsData1, visitorsData2) = try await (s1, s2, pv1, pv2, v1, v2)
            guard !Task.isCancelled else { return }

            stats1 = WebsiteStats(
                pageviews: StatValue(value: analyticsStats1.pageviews.value, change: analyticsStats1.pageviews.change),
                visitors: StatValue(value: analyticsStats1.visitors.value, change: analyticsStats1.visitors.change),
                visits: StatValue(value: analyticsStats1.visits.value, change: analyticsStats1.visits.change),
                bounces: StatValue(value: analyticsStats1.bounces.value, change: analyticsStats1.bounces.change),
                totaltime: StatValue(value: analyticsStats1.totaltime.value, change: analyticsStats1.totaltime.change)
            )

            stats2 = WebsiteStats(
                pageviews: StatValue(value: analyticsStats2.pageviews.value, change: analyticsStats2.pageviews.change),
                visitors: StatValue(value: analyticsStats2.visitors.value, change: analyticsStats2.visitors.change),
                visits: StatValue(value: analyticsStats2.visits.value, change: analyticsStats2.visits.change),
                bounces: StatValue(value: analyticsStats2.bounces.value, change: analyticsStats2.bounces.change),
                totaltime: StatValue(value: analyticsStats2.totaltime.value, change: analyticsStats2.totaltime.change)
            )

            pageviews1 = pageviewsData1.map { TimeSeriesPoint(x: DateFormatters.iso8601WithFractional.string(from: $0.date), y: $0.value) }
            pageviews2 = pageviewsData2.map { TimeSeriesPoint(x: DateFormatters.iso8601WithFractional.string(from: $0.date), y: $0.value) }
            visitors1 = visitorsData1.map { TimeSeriesPoint(x: DateFormatters.iso8601WithFractional.string(from: $0.date), y: $0.value) }
            visitors2 = visitorsData2.map { TimeSeriesPoint(x: DateFormatters.iso8601WithFractional.string(from: $0.date), y: $0.value) }

        } catch {
            guard !Task.isCancelled else { return }
            #if DEBUG
            print("Plausible Compare error: \(error)")
            #endif
        }
    }

    private func loadUmamiComparison(dateRange1: DateRange, dateRange2: DateRange) async {
        do {
            async let s1 = umamiAPI.getStats(websiteId: websiteId, dateRange: dateRange1)
            async let s2 = umamiAPI.getStats(websiteId: websiteId, dateRange: dateRange2)
            async let pv1 = umamiAPI.getPageviews(websiteId: websiteId, dateRange: dateRange1)
            async let pv2 = umamiAPI.getPageviews(websiteId: websiteId, dateRange: dateRange2)

            let (stats1Result, stats2Result, pageviews1Result, pageviews2Result) = try await (s1, s2, pv1, pv2)
            guard !Task.isCancelled else { return }

            stats1 = stats1Result
            stats2 = stats2Result
            pageviews1 = pageviews1Result.pageviews
            pageviews2 = pageviews2Result.pageviews
            // Sessions/Visitors Zeitreihe vom gleichen Endpoint
            visitors1 = pageviews1Result.sessions
            visitors2 = pageviews2Result.sessions

        } catch {
            guard !Task.isCancelled else { return }
            #if DEBUG
            print("Compare error: \(error)")
            #endif
        }
    }
}
