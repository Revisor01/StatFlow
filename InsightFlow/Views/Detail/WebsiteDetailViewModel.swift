import Foundation
import os

@MainActor
class WebsiteDetailViewModel: ObservableObject {
    let websiteId: String
    let domain: String

    @Published var stats: WebsiteStats?
    @Published var activeVisitors: Int = 0
    @Published var pageviewsData: [TimeSeriesPoint] = []
    @Published var sessionsData: [TimeSeriesPoint] = []
    @Published var topPages: [MetricItem] = []
    @Published var pageTitles: [MetricItem] = []
    @Published var entryPages: [MetricItem] = []
    @Published var exitPages: [MetricItem] = []
    @Published var referrers: [MetricItem] = []
    @Published var countries: [MetricItem] = []
    @Published var regions: [MetricItem] = []
    @Published var cities: [MetricItem] = []
    @Published var devices: [MetricItem] = []
    @Published var browsers: [MetricItem] = []
    @Published var operatingSystems: [MetricItem] = []
    @Published var languages: [MetricItem] = []
    @Published var screens: [MetricItem] = []
    @Published var events: [MetricItem] = []
    @Published var goals: [GoalConversion] = []
    @Published var totalVisitors: Int = 0
    @Published var activeFilters: [PlausibleQueryFilter] = []
    @Published var isLoading = false
    @Published var isOffline = false
    @Published var error: String?
    private var loadingTask: Task<Void, Never>?

    init(websiteId: String, domain: String = "") {
        self.websiteId = websiteId
        self.domain = domain
    }

    func loadData(dateRange: DateRange) async {
        // Cancel vorherigen Load — verhindert Background-Battery-Drain (FIX-02)
        loadingTask?.cancel()
        let task = Task {
            isLoading = true
            isOffline = false
            defer {
                if !Task.isCancelled {
                    isLoading = false
                }
            }

            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadStats(dateRange: dateRange) }
                group.addTask { await self.loadActiveVisitors() }
                group.addTask { await self.loadPageviews(dateRange: dateRange) }
                group.addTask { await self.loadTopPages(dateRange: dateRange) }
                group.addTask { await self.loadPageTitles(dateRange: dateRange) }
                group.addTask { await self.loadReferrers(dateRange: dateRange) }
                group.addTask { await self.loadCountries(dateRange: dateRange) }
                group.addTask { await self.loadRegions(dateRange: dateRange) }
                group.addTask { await self.loadCities(dateRange: dateRange) }
                group.addTask { await self.loadDevices(dateRange: dateRange) }
                group.addTask { await self.loadBrowsers(dateRange: dateRange) }
                group.addTask { await self.loadOperatingSystems(dateRange: dateRange) }
                group.addTask { await self.loadLanguages(dateRange: dateRange) }
                group.addTask { await self.loadScreens(dateRange: dateRange) }
                group.addTask { await self.loadEvents(dateRange: dateRange) }
                group.addTask { await self.loadEntryPages(dateRange: dateRange) }
                group.addTask { await self.loadExitPages(dateRange: dateRange) }
                group.addTask { await self.loadGoals(dateRange: dateRange) }
            }
        }
        loadingTask = task
        await task.value
    }

    func cancelLoading() {
        loadingTask?.cancel()
        loadingTask = nil
    }

    private func loadStats(dateRange: DateRange) async {
        guard let provider = AnalyticsManager.shared.currentProvider else { return }
        do {
            let analyticsStats = try await provider.getAnalyticsStats(websiteId: websiteId, dateRange: dateRange)
            guard !Task.isCancelled else { return }
            let websiteStats = analyticsStats.toWebsiteStats()
            stats = websiteStats
            totalVisitors = websiteStats.visitors.value
        } catch {
            guard !Task.isCancelled else { return }
            if error.isNetworkError {
                isOffline = true
            } else {
                self.error = error.localizedDescription
            }
        }
    }

    private func loadActiveVisitors() async {
        guard let provider = AnalyticsManager.shared.currentProvider else { return }
        do {
            let result = try await provider.getActiveVisitors(websiteId: websiteId)
            guard !Task.isCancelled else { return }
            activeVisitors = result
        } catch {
            if !Task.isCancelled { Logger.ui.error("Failed to load active visitors: \(error.localizedDescription)") }
        }
    }

    private func loadPageviews(dateRange: DateRange) async {
        guard let provider = AnalyticsManager.shared.currentProvider else { return }
        do {
            // Load both in parallel
            async let pageviewTask = provider.getPageviewsData(websiteId: websiteId, dateRange: dateRange)
            async let visitorTask = provider.getVisitorsData(websiteId: websiteId, dateRange: dateRange)
            let (pageviewData, visitorData) = try await (pageviewTask, visitorTask)

            let filledPageviews = fillMissingTimeSlots(
                data: pageviewData.map { TimeSeriesPoint(x: DateFormatters.iso8601.string(from: $0.date), y: $0.value) },
                dateRange: dateRange
            )
            let filledSessions = fillMissingTimeSlots(
                data: visitorData.map { TimeSeriesPoint(x: DateFormatters.iso8601.string(from: $0.date), y: $0.value) },
                dateRange: dateRange
            )
            guard !Task.isCancelled else { return }
            // Update both at once to avoid partial render
            pageviewsData = filledPageviews
            sessionsData = filledSessions
        } catch {
            if !Task.isCancelled { Logger.ui.error("Failed to load pageviews: \(error.localizedDescription)") }
        }
    }

    /// Fills in missing time slots with zero values for complete chart display
    private func fillMissingTimeSlots(data: [TimeSeriesPoint], dateRange: DateRange) -> [TimeSeriesPoint] {
        let calendar = Calendar.current
        let now = Date()
        let isHourly = dateRange.unit == "hour"

        // Build lookup by normalized date components to avoid timezone mismatch
        var dataByComponent: [String: Int] = [:]
        for point in data {
            let date = point.date
            if isHourly {
                // Key by day+hour in UTC to match API data
                let utcCalendar = {
                    var c = Calendar(identifier: .gregorian)
                    c.timeZone = TimeZone(identifier: "UTC")!
                    return c
                }()
                let comps = utcCalendar.dateComponents([.year, .month, .day, .hour], from: date)
                let key = "\(comps.year!)-\(comps.month!)-\(comps.day!)-\(comps.hour!)"
                dataByComponent[key] = point.value
            } else {
                // Key by day in UTC
                let utcCalendar = {
                    var c = Calendar(identifier: .gregorian)
                    c.timeZone = TimeZone(identifier: "UTC")!
                    return c
                }()
                let comps = utcCalendar.dateComponents([.year, .month, .day], from: date)
                let key = "\(comps.year!)-\(comps.month!)-\(comps.day!)"
                dataByComponent[key] = point.value
            }
        }

        var result: [TimeSeriesPoint] = []

        // Use UTC calendar for generating slots to match API timezone
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        if isHourly {
            let baseDate: Date
            switch dateRange.preset {
            case .today:
                baseDate = now
            case .yesterday:
                baseDate = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            default:
                baseDate = dateRange.dates.start
            }

            let startOfDay = utcCalendar.startOfDay(for: baseDate)
            let currentHour: Int
            if dateRange.preset == .today {
                // Show up to current hour in UTC
                currentHour = utcCalendar.component(.hour, from: now)
            } else {
                currentHour = 23
            }

            for hour in 0...currentHour {
                if let hourDate = utcCalendar.date(byAdding: .hour, value: hour, to: startOfDay) {
                    let comps = utcCalendar.dateComponents([.year, .month, .day, .hour], from: hourDate)
                    let key = "\(comps.year!)-\(comps.month!)-\(comps.day!)-\(comps.hour!)"
                    let value = dataByComponent[key] ?? 0
                    result.append(TimeSeriesPoint(x: DateFormatters.iso8601.string(from: hourDate), y: value))
                }
            }
        } else {
            let dates = dateRange.dates
            var currentDate = utcCalendar.startOfDay(for: dates.start)
            let endDate = utcCalendar.startOfDay(for: dates.end)

            while currentDate <= endDate {
                let comps = utcCalendar.dateComponents([.year, .month, .day], from: currentDate)
                let key = "\(comps.year!)-\(comps.month!)-\(comps.day!)"
                let value = dataByComponent[key] ?? 0
                result.append(TimeSeriesPoint(x: DateFormatters.iso8601.string(from: currentDate), y: value))

                if let nextDay = utcCalendar.date(byAdding: .day, value: 1, to: currentDate) {
                    currentDate = nextDay
                } else {
                    break
                }
            }
        }

        return result.isEmpty ? data : result
    }

    private func loadTopPages(dateRange: DateRange) async {
        guard let provider = AnalyticsManager.shared.currentProvider else { return }
        do {
            let items = try await provider.getPages(websiteId: websiteId, dateRange: dateRange)
            guard !Task.isCancelled else { return }
            topPages = items.map { MetricItem(x: $0.name, y: $0.value) }
        } catch {
            if !Task.isCancelled { Logger.ui.error("Failed to load top pages: \(error.localizedDescription)") }
        }
    }

    private func loadPageTitles(dateRange: DateRange) async {
        guard let provider = AnalyticsManager.shared.currentProvider else { return }
        do {
            let items = try await provider.getPageTitles(websiteId: websiteId, dateRange: dateRange)
            guard !Task.isCancelled else { return }
            pageTitles = items.map { MetricItem(x: $0.name, y: $0.value) }
        } catch {
            if !Task.isCancelled { Logger.ui.error("Failed to load page titles: \(error.localizedDescription)") }
        }
    }

    private func loadReferrers(dateRange: DateRange) async {
        guard let provider = AnalyticsManager.shared.currentProvider else { return }
        do {
            let items = try await provider.getReferrers(websiteId: websiteId, dateRange: dateRange)
            guard !Task.isCancelled else { return }
            referrers = items.map { MetricItem(x: $0.name, y: $0.value) }
        } catch {
            if !Task.isCancelled { Logger.ui.error("Failed to load referrers: \(error.localizedDescription)") }
        }
    }

    private func loadCountries(dateRange: DateRange) async {
        guard let provider = AnalyticsManager.shared.currentProvider else { return }
        do {
            let items = try await provider.getCountries(websiteId: websiteId, dateRange: dateRange)
            guard !Task.isCancelled else { return }
            countries = items.map { MetricItem(x: $0.name, y: $0.value) }
        } catch {
            if !Task.isCancelled { Logger.ui.error("Failed to load countries: \(error.localizedDescription)") }
        }
    }

    private func loadRegions(dateRange: DateRange) async {
        guard let provider = AnalyticsManager.shared.currentProvider else { return }
        do {
            let items = try await provider.getRegions(websiteId: websiteId, dateRange: dateRange)
            guard !Task.isCancelled else { return }
            regions = items.map { MetricItem(x: $0.name, y: $0.value) }
        } catch {
            if !Task.isCancelled { Logger.ui.error("Failed to load regions: \(error.localizedDescription)") }
        }
    }

    private func loadCities(dateRange: DateRange) async {
        guard let provider = AnalyticsManager.shared.currentProvider else { return }
        do {
            let items = try await provider.getCities(websiteId: websiteId, dateRange: dateRange)
            guard !Task.isCancelled else { return }
            cities = items.map { MetricItem(x: $0.name, y: $0.value) }
        } catch {
            if !Task.isCancelled { Logger.ui.error("Failed to load cities: \(error.localizedDescription)") }
        }
    }

    private func loadDevices(dateRange: DateRange) async {
        guard let provider = AnalyticsManager.shared.currentProvider else { return }
        do {
            let items = try await provider.getDevices(websiteId: websiteId, dateRange: dateRange)
            guard !Task.isCancelled else { return }
            devices = items.map { MetricItem(x: $0.name, y: $0.value) }
        } catch {
            if !Task.isCancelled { Logger.ui.error("Failed to load devices: \(error.localizedDescription)") }
        }
    }

    private func loadBrowsers(dateRange: DateRange) async {
        guard let provider = AnalyticsManager.shared.currentProvider else { return }
        do {
            let items = try await provider.getBrowsers(websiteId: websiteId, dateRange: dateRange)
            guard !Task.isCancelled else { return }
            browsers = items.map { MetricItem(x: $0.name, y: $0.value) }
        } catch {
            if !Task.isCancelled { Logger.ui.error("Failed to load browsers: \(error.localizedDescription)") }
        }
    }

    private func loadOperatingSystems(dateRange: DateRange) async {
        guard let provider = AnalyticsManager.shared.currentProvider else { return }
        do {
            let items = try await provider.getOS(websiteId: websiteId, dateRange: dateRange)
            guard !Task.isCancelled else { return }
            operatingSystems = items.map { MetricItem(x: $0.name, y: $0.value) }
        } catch {
            if !Task.isCancelled { Logger.ui.error("Failed to load operating systems: \(error.localizedDescription)") }
        }
    }

    private func loadLanguages(dateRange: DateRange) async {
        guard let provider = AnalyticsManager.shared.currentProvider else { return }
        do {
            let items = try await provider.getLanguages(websiteId: websiteId, dateRange: dateRange)
            guard !Task.isCancelled else { return }
            languages = items.map { MetricItem(x: $0.name, y: $0.value) }
        } catch {
            if !Task.isCancelled { Logger.ui.error("Failed to load languages: \(error.localizedDescription)") }
        }
    }

    private func loadScreens(dateRange: DateRange) async {
        guard let provider = AnalyticsManager.shared.currentProvider else { return }
        do {
            let items = try await provider.getScreens(websiteId: websiteId, dateRange: dateRange)
            guard !Task.isCancelled else { return }
            screens = items.map { MetricItem(x: $0.name, y: $0.value) }
        } catch {
            if !Task.isCancelled { Logger.ui.error("Failed to load screens: \(error.localizedDescription)") }
        }
    }

    private func loadEvents(dateRange: DateRange) async {
        guard let provider = AnalyticsManager.shared.currentProvider else { return }
        do {
            let items = try await provider.getEvents(websiteId: websiteId, dateRange: dateRange)
            guard !Task.isCancelled else { return }
            events = items.map { MetricItem(x: $0.name, y: $0.value) }
        } catch {
            if !Task.isCancelled { Logger.ui.error("Failed to load events: \(error.localizedDescription)") }
        }
    }

    private func loadEntryPages(dateRange: DateRange) async {
        guard let provider = AnalyticsManager.shared.currentProvider,
              let plausible = provider as? PlausibleAPI else { return }
        do {
            let items = try await plausible.getEntryPages(websiteId: websiteId, dateRange: dateRange, filters: activeFilters)
            guard !Task.isCancelled else { return }
            entryPages = items.map { MetricItem(x: $0.name, y: $0.value) }
        } catch {
            if !Task.isCancelled { Logger.ui.error("Failed to load entry pages: \(error.localizedDescription)") }
        }
    }

    private func loadExitPages(dateRange: DateRange) async {
        guard let provider = AnalyticsManager.shared.currentProvider,
              let plausible = provider as? PlausibleAPI else { return }
        do {
            let items = try await plausible.getExitPages(websiteId: websiteId, dateRange: dateRange, filters: activeFilters)
            guard !Task.isCancelled else { return }
            exitPages = items.map { MetricItem(x: $0.name, y: $0.value) }
        } catch {
            if !Task.isCancelled { Logger.ui.error("Failed to load exit pages: \(error.localizedDescription)") }
        }
    }

    private func loadGoals(dateRange: DateRange) async {
        guard let provider = AnalyticsManager.shared.currentProvider,
              let plausible = provider as? PlausibleAPI else { return }
        do {
            let conversions = try await plausible.getGoalConversions(websiteId: websiteId, dateRange: dateRange, filters: activeFilters)
            guard !Task.isCancelled else { return }
            goals = conversions
        } catch {
            if !Task.isCancelled { Logger.ui.error("Failed to load goals: \(error.localizedDescription)") }
        }
    }

    func applyFilter(_ filter: PlausibleQueryFilter) {
        // Remove any existing filter for this dimension before adding new one
        activeFilters.removeAll { $0.dimension == filter.dimension }
        activeFilters.append(filter)
    }

    func removeFilter(dimension: String) {
        activeFilters.removeAll { $0.dimension == dimension }
    }
}
