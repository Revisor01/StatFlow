import os
import SwiftUI

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var websites: [Website] = []
    @Published var stats: [String: WebsiteStats] = [:]
    @Published var activeVisitors: [String: Int] = [:]
    @Published var sparklineData: [String: [TimeSeriesPoint]] = [:]
    @Published var isLoading = false
    @Published var error: String?
    @Published var isOffline = false
    @Published var offlineCacheDate: Date?
    private var loadingTask: Task<Void, Never>?
    @Published var websiteOrder: [String] = [] {
        didSet {
            saveWebsiteOrder()
        }
    }

    private let umamiAPI: UmamiAPI
    private let plausibleAPI: PlausibleAPI
    private let cache: AnalyticsCacheService
    private var currentDateRange: DateRange = .today

    /// Sortierte Websites basierend auf gespeicherter Reihenfolge
    var sortedWebsites: [Website] {
        if websiteOrder.isEmpty {
            return websites
        }

        return websites.sorted { a, b in
            let indexA = websiteOrder.firstIndex(of: a.id) ?? Int.max
            let indexB = websiteOrder.firstIndex(of: b.id) ?? Int.max
            return indexA < indexB
        }
    }

    init(umamiAPI: UmamiAPI = .shared, plausibleAPI: PlausibleAPI = .shared, cache: AnalyticsCacheService = .shared) {
        self.umamiAPI = umamiAPI
        self.plausibleAPI = plausibleAPI
        self.cache = cache
        loadWebsiteOrder()
    }

    func cancelLoading() {
        loadingTask?.cancel()
        loadingTask = nil
    }

    private var orderKey: String {
        "websiteOrder_\(currentAccountId)"
    }

    private func loadWebsiteOrder() {
        if let order = UserDefaults.standard.stringArray(forKey: orderKey) {
            websiteOrder = order
        }
    }

    private func saveWebsiteOrder() {
        UserDefaults.standard.set(websiteOrder, forKey: orderKey)
    }

    func moveWebsite(from source: IndexSet, to destination: Int) {
        var order = sortedWebsites.map { $0.id }
        order.move(fromOffsets: source, toOffset: destination)
        websiteOrder = order
    }

    private var isPlausible: Bool {
        AnalyticsManager.shared.providerType == .plausible
    }

    private var currentAccountId: String {
        AccountManager.shared.activeAccount?.id.uuidString ?? "default"
    }

    /// Loads websites from all accounts into a flat list, returns a map of website-id -> account
    func loadAllAccountsData(dateRange: DateRange, accounts: [AnalyticsAccount]) async -> [String: AnalyticsAccount] {
        isLoading = true
        currentDateRange = dateRange
        isOffline = false

        let originalAccount = AccountManager.shared.activeAccount
        var allWebsites: [Website] = []
        var accountMap: [String: AnalyticsAccount] = [:]

        for account in accounts {
            do {
                // Configure API for this account WITHOUT switching global state (BUG-03 fix)
                await AccountManager.shared.configureProviderForAccount(account)

                var accountWebsites: [Website] = []
                if account.providerType == .plausible {
                    let analyticsWebsites = try await plausibleAPI.getAnalyticsWebsites()
                    accountWebsites = analyticsWebsites.map { site in
                        Website(id: site.id, name: site.name, domain: site.domain, shareId: nil, teamId: nil, resetAt: nil, createdAt: nil)
                    }
                } else {
                    accountWebsites = try await umamiAPI.getWebsites()
                }

                for website in accountWebsites {
                    accountMap[website.id] = account
                }
                allWebsites.append(contentsOf: accountWebsites)
            } catch {
                Logger.ui.error("loadAllAccountsData: failed for account \(account.displayName): \(error.localizedDescription)")
                // Continue loading other accounts
            }
        }

        websites = allWebsites

        // Load stats for all websites concurrently per account (BUG-03: no global account switch)
        for account in accounts {
            let accountWebsites = allWebsites.filter { accountMap[$0.id]?.id == account.id }
            guard !accountWebsites.isEmpty else { continue }

            await AccountManager.shared.configureProviderForAccount(account)
            await withTaskGroup(of: Void.self) { group in
                for website in accountWebsites {
                    group.addTask { await self.loadWebsiteData(website, dateRange: dateRange) }
                }
            }
        }

        // Restore original active account with full side effects (widget reload, notifications — once)
        if let original = originalAccount {
            await AccountManager.shared.setActiveAccount(original)
        }

        isLoading = false
        return accountMap
    }

    func loadData(dateRange: DateRange, clearFirst: Bool = false) async {
        loadingTask?.cancel()
        let task = Task {
            if clearFirst {
                websites = []
                stats = [:]
                sparklineData = [:]
                activeVisitors = [:]
            }
            isLoading = true
            currentDateRange = dateRange
            isOffline = false
            offlineCacheDate = nil
            defer { if !Task.isCancelled { isLoading = false } }

            // Lade die Website-Reihenfolge für den aktuellen Account
            loadWebsiteOrder()

            // Online-First: ALWAYS fetch fresh from API, NO cache preload
            do {
                if isPlausible {
                    let analyticsWebsites = try await plausibleAPI.getAnalyticsWebsites()
                    guard !Task.isCancelled else { return }
                    websites = analyticsWebsites.map { site in
                        Website(id: site.id, name: site.name, domain: site.domain, shareId: nil, teamId: nil, resetAt: nil, createdAt: nil)
                    }
                    // Cache die Websites
                    cache.saveWebsites(analyticsWebsites.toCached(), accountId: currentAccountId)
                } else {
                    let freshWebsites = try await umamiAPI.getWebsites()
                    guard !Task.isCancelled else { return }
                    websites = freshWebsites
                    // Cache die Websites
                    let analyticsWebsites = freshWebsites.map { site in
                        AnalyticsWebsite(id: site.id, name: site.name, domain: site.domain ?? site.name, shareId: site.shareId, provider: .umami)
                    }
                    cache.saveWebsites(analyticsWebsites.toCached(), accountId: currentAccountId)
                }

                guard !Task.isCancelled else { return }
                await withTaskGroup(of: Void.self) { group in
                    for website in websites {
                        group.addTask { await self.loadWebsiteData(website, dateRange: dateRange) }
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                if error.isNetworkError {
                    // ONLY load cache as offline fallback
                    loadFromCache(dateRange: dateRange)
                    isOffline = true
                } else {
                    self.error = error.localizedDescription
                }
            }
        }
        loadingTask = task
        await task.value
    }

    /// Lädt Daten aus dem lokalen Cache (nur als Offline-Fallback, max 24h alt)
    private func loadFromCache(dateRange: DateRange) {
        let websitesKey = "websites_\(currentAccountId)"
        guard let result = cache.isValidForOfflineDisplay(forKey: websitesKey, type: [CachedWebsite].self) else {
            // Cache zu alt (> 24h) oder nicht vorhanden — keine Offline-Anzeige
            self.error = String(localized: "dashboard.offlineExpired")
            return
        }

        let analyticsWebsites = result.data.toAnalyticsWebsites()
        websites = analyticsWebsites.map { site in
            Website(id: site.id, name: site.name, domain: site.domain, shareId: site.shareId, teamId: nil, resetAt: nil, createdAt: nil)
        }
        offlineCacheDate = result.cachedAt

        // Lade gecachte Stats und Sparklines für sofortige Anzeige
        for website in websites {
            let dateRangeId = dateRange.preset.rawValue

            // Stats laden
            if let cachedStats = cache.loadStats(websiteId: website.id, dateRangeId: dateRangeId) {
                stats[website.id] = cachedStats.data.toAnalyticsStats().toWebsiteStats()
            }

            // Sparkline laden
            if let cachedSparkline = cache.loadSparkline(websiteId: website.id, dateRangeId: dateRangeId) {
                let points = cachedSparkline.data.toAnalyticsChartPoints()
                sparklineData[website.id] = points.map { point in
                    TimeSeriesPoint(x: DateFormatters.iso8601.string(from: point.date), y: point.value)
                }
            }
        }
    }

    func refresh(dateRange: DateRange) async {
        await loadData(dateRange: dateRange)
    }

    func updateWebsite(_ website: Website) {
        if let index = websites.firstIndex(where: { $0.id == website.id }) {
            websites[index] = website
        }
    }

    func removeSite(_ websiteId: String) async {
        if isPlausible {
            await plausibleAPI.removeSite(domain: websiteId)
        } else {
            // Umami: Delete via API
            do {
                try await umamiAPI.deleteWebsite(websiteId: websiteId)
            } catch {
                Logger.ui.error("Failed to delete Umami website: \(error.localizedDescription)")
                return
            }
        }
        websites.removeAll { $0.id == websiteId }
        stats.removeValue(forKey: websiteId)
        activeVisitors.removeValue(forKey: websiteId)
        sparklineData.removeValue(forKey: websiteId)
    }

    private func loadWebsiteData(_ website: Website, dateRange: DateRange) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadStats(for: website.id, dateRange: dateRange) }
            group.addTask { await self.loadActiveVisitors(for: website.id) }
            group.addTask { await self.loadSparkline(for: website.id, dateRange: dateRange) }
        }
    }

    private func loadStats(for websiteId: String, dateRange: DateRange) async {
        let dateRangeId = dateRange.preset.rawValue

        do {
            let analyticsStats: AnalyticsStats
            if isPlausible {
                analyticsStats = try await plausibleAPI.getAnalyticsStats(websiteId: websiteId, dateRange: dateRange)
            } else {
                let websiteStats = try await umamiAPI.getStats(websiteId: websiteId, dateRange: dateRange)
                analyticsStats = AnalyticsStats(
                    visitors: websiteStats.visitors,
                    pageviews: websiteStats.pageviews,
                    visits: websiteStats.visits,
                    bounces: websiteStats.bounces,
                    totaltime: websiteStats.totaltime
                )
            }

            guard !Task.isCancelled else { return }
            stats[websiteId] = analyticsStats.toWebsiteStats()

            // Cache die Stats
            cache.saveStats(CachedStats(from: analyticsStats), websiteId: websiteId, dateRangeId: dateRangeId)
        } catch {
            if !Task.isCancelled { Logger.ui.error("Failed to load stats for \(websiteId): \(error.localizedDescription)") }
        }
    }

    private func loadActiveVisitors(for websiteId: String) async {
        do {
            let count: Int
            if isPlausible {
                count = try await plausibleAPI.getActiveVisitors(websiteId: websiteId)
            } else {
                count = try await umamiAPI.getActiveVisitors(websiteId: websiteId)
            }
            guard !Task.isCancelled else { return }
            activeVisitors[websiteId] = count
        } catch {
            if !Task.isCancelled { Logger.ui.error("Failed to load active visitors for \(websiteId): \(error.localizedDescription)") }
        }
    }

    private func loadSparkline(for websiteId: String, dateRange: DateRange) async {
        let dateRangeId = dateRange.preset.rawValue

        do {
            let chartPoints: [AnalyticsChartPoint]
            if isPlausible {
                chartPoints = try await plausibleAPI.getPageviewsData(websiteId: websiteId, dateRange: dateRange)
            } else {
                let pageviews = try await umamiAPI.getPageviews(websiteId: websiteId, dateRange: dateRange)
                chartPoints = pageviews.pageviews.map { point in
                    AnalyticsChartPoint(date: point.date, value: point.value)
                }
            }

            guard !Task.isCancelled else { return }
            let rawData = chartPoints.map { point in
                TimeSeriesPoint(x: DateFormatters.iso8601.string(from: point.date), y: point.value)
            }
            sparklineData[websiteId] = fillMissingTimeSlots(data: rawData, dateRange: dateRange)

            // Cache die Sparkline-Daten
            cache.saveSparkline(chartPoints.toCached(), websiteId: websiteId, dateRangeId: dateRangeId)
        } catch {
            if !Task.isCancelled { Logger.ui.error("Failed to load sparkline for \(websiteId): \(error.localizedDescription)") }
        }
    }

    /// Fills in missing time slots with zero values for complete chart display
    private func fillMissingTimeSlots(data: [TimeSeriesPoint], dateRange: DateRange) -> [TimeSeriesPoint] {
        let calendar = Calendar.current
        let now = Date()
        let isHourly = dateRange.unit == "hour"

        // Build O(1) lookup by normalized date components (UTC to match API)
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        var dataByKey: [String: Int] = [:]
        for point in data {
            let date = point.date
            if isHourly {
                let comps = utcCalendar.dateComponents([.year, .month, .day, .hour], from: date)
                dataByKey["\(comps.year!)-\(comps.month!)-\(comps.day!)-\(comps.hour!)"] = point.value
            } else {
                let comps = utcCalendar.dateComponents([.year, .month, .day], from: date)
                dataByKey["\(comps.year!)-\(comps.month!)-\(comps.day!)"] = point.value
            }
        }

        var result: [TimeSeriesPoint] = []

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
            let currentHour = dateRange.preset == .today ? utcCalendar.component(.hour, from: now) : 23

            for hour in 0...currentHour {
                if let hourDate = utcCalendar.date(byAdding: .hour, value: hour, to: startOfDay) {
                    let comps = utcCalendar.dateComponents([.year, .month, .day, .hour], from: hourDate)
                    let key = "\(comps.year!)-\(comps.month!)-\(comps.day!)-\(comps.hour!)"
                    result.append(TimeSeriesPoint(x: DateFormatters.iso8601.string(from: hourDate), y: dataByKey[key] ?? 0))
                }
            }
        } else {
            let dates = dateRange.dates
            var currentDate = utcCalendar.startOfDay(for: dates.start)
            let endDate = utcCalendar.startOfDay(for: dates.end)

            while currentDate <= endDate {
                let comps = utcCalendar.dateComponents([.year, .month, .day], from: currentDate)
                let key = "\(comps.year!)-\(comps.month!)-\(comps.day!)"
                result.append(TimeSeriesPoint(x: DateFormatters.iso8601.string(from: currentDate), y: dataByKey[key] ?? 0))

                if let nextDay = utcCalendar.date(byAdding: .day, value: 1, to: currentDate) {
                    currentDate = nextDay
                } else {
                    break
                }
            }
        }

        return result.isEmpty ? data : result
    }
}
