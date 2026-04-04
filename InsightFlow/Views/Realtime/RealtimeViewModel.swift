import Foundation
import os

// MARK: - ViewModel

@MainActor
class RealtimeViewModel: ObservableObject {
    let websiteId: String

    @Published var activeVisitors: Int = 0
    @Published var totalPageviews: Int = 0
    @Published var totalEvents: Int = 0
    @Published var topPages: [(key: String, value: Int)] = []
    @Published var countries: [(key: String, value: Int)] = []
    @Published var recentEvents: [RealtimeEvent] = []

    private var pollingTask: Task<Void, Never>?
    private let umamiAPI: UmamiAPI
    private let plausibleAPI: PlausibleAPI

    var isPlausible: Bool {
        AnalyticsManager.shared.providerType == .plausible
    }

    init(websiteId: String, umamiAPI: UmamiAPI = .shared, plausibleAPI: PlausibleAPI = .shared) {
        self.websiteId = websiteId
        self.umamiAPI = umamiAPI
        self.plausibleAPI = plausibleAPI
    }

    func startPolling() async {
        await refresh()

        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                if !Task.isCancelled {
                    await refresh()
                }
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func refresh() async {
        if isPlausible {
            await refreshPlausible()
        } else {
            await refreshUmami()
        }
    }

    private func refreshPlausible() async {
        do {
            // Fetch all data in parallel
            async let visitors = plausibleAPI.getActiveVisitors(websiteId: websiteId)
            async let pageviews = plausibleAPI.getRealtimePageviews(websiteId: websiteId)
            async let pages = plausibleAPI.getRealtimeTopPages(websiteId: websiteId)
            async let countriesData = plausibleAPI.getRealtimeCountries(websiteId: websiteId)

            let (v, pv, p, c) = try await (visitors, pageviews, pages, countriesData)

            guard !Task.isCancelled else { return }
            activeVisitors = v
            totalPageviews = pv
            totalEvents = 0 // Plausible doesn't track custom events in realtime the same way
            topPages = p.map { ($0.name, $0.value) }
            countries = c.map { ($0.name, $0.value) }
            recentEvents = [] // Plausible doesn't provide individual events

        } catch {
            guard !Task.isCancelled else { return }
            Logger.ui.error("Plausible Realtime error: \(error.localizedDescription)")
        }
    }

    private func refreshUmami() async {
        do {
            let data = try await umamiAPI.getRealtime(websiteId: websiteId)

            guard !Task.isCancelled else { return }

            // Aktive Besucher = unique Sessions in den letzten 5 Minuten
            let fiveMinutesAgo = Date().addingTimeInterval(-300)
            let recentSessions = Set(data.events.filter { $0.createdDate > fiveMinutesAgo }.map { $0.sessionId })
            activeVisitors = recentSessions.count

            // Totals
            totalPageviews = data.totals?.views ?? data.events.filter { $0.isPageview }.count
            totalEvents = data.totals?.events ?? data.events.filter { !$0.isPageview && !$0.isSession }.count

            // Top Pages sortiert
            topPages = data.urls.sorted { $0.value > $1.value }

            // Countries sortiert
            countries = data.countries.sorted { $0.value > $1.value }

            // Recent Events (nur pageviews, sortiert nach Zeit)
            recentEvents = data.events
                .filter { $0.isPageview }
                .sorted { $0.createdDate > $1.createdDate }

        } catch {
            guard !Task.isCancelled else { return }
            Logger.ui.error("Realtime error: \(error.localizedDescription)")
        }
    }
}

@MainActor
class LiveEventDetailViewModel: ObservableObject {
    let websiteId: String
    let sessionId: String

    @Published var activities: [SessionActivity] = []
    @Published var isLoading = false

    private let api: UmamiAPI
    private var loadingTask: Task<Void, Never>?

    init(websiteId: String, sessionId: String, api: UmamiAPI = .shared) {
        self.websiteId = websiteId
        self.sessionId = sessionId
        self.api = api
    }

    func loadActivity() async {
        loadingTask?.cancel()
        let task = Task {
            isLoading = true
            defer { if !Task.isCancelled { isLoading = false } }

            do {
                let result = try await api.getSessionActivity(
                    websiteId: websiteId,
                    sessionId: sessionId,
                    dateRange: .today
                )
                guard !Task.isCancelled else { return }
                activities = result
            } catch {
                guard !Task.isCancelled else { return }
                Logger.ui.error("Live session activity error: \(error.localizedDescription)")
            }
        }
        loadingTask = task
        await task.value
    }

    func cancelLoading() {
        loadingTask?.cancel()
        loadingTask = nil
    }
}
