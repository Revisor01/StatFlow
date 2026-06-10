import Foundation
import os

@MainActor
class WebsiteDetailViewModel: ObservableObject {
    let websiteId: String
    let domain: String
    /// Besitzender Account dieser Website. Wird (falls gesetzt) vor jedem Load als
    /// Provider konfiguriert, damit die Detailansicht im "Alle Accounts"-Modus nicht
    /// versehentlich gegen den falschen (zuletzt aktiven) Account abfragt und
    /// dadurch eingefrorene Werte anzeigt.
    let account: AnalyticsAccount?

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
    /// True, solange für den aktuellen Zeitraum noch KEINE Chart-Daten vorliegen
    /// (weder aus Cache noch vom Netzwerk). Steuert das Lade-Skeleton des Graphen.
    @Published var isChartLoading = false
    @Published var isOffline = false
    @Published var error: String?
    private var loadingTask: Task<Void, Never>?
    private let cache: AnalyticsCacheService

    init(websiteId: String, domain: String = "", account: AnalyticsAccount? = nil, cache: AnalyticsCacheService = .shared) {
        self.websiteId = websiteId
        self.domain = domain
        self.account = account
        self.cache = cache
    }

    /// `silent`: lädt im Hintergrund neu, ohne den Lade-Spinner zu zeigen
    /// (für periodisches Auto-Refresh der Tages-Stats, solange die Ansicht offen ist).
    func loadData(dateRange: DateRange, silent: Bool = false) async {
        // Cancel vorherigen Load — verhindert Background-Battery-Drain (FIX-02)
        loadingTask?.cancel()
        let task = Task {
            if !silent { isLoading = true }
            isOffline = false
            defer {
                if !Task.isCancelled && !silent {
                    isLoading = false
                }
            }

            // Provider für den besitzenden Account konfigurieren, BEVOR Daten geladen
            // werden. Stellt sicher, dass alle nachfolgenden API-Calls (auch nach
            // Datumswechsel) gegen den korrekten Account/Server laufen.
            await ensureProviderConfigured()
            guard !Task.isCancelled else { return }

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

    /// Konfiguriert den Provider für den besitzenden Account, falls dieser nicht
    /// bereits aktiv ist. No-op, wenn kein Account übergeben wurde (Single-Account-Flow).
    private func ensureProviderConfigured() async {
        guard let account else { return }
        if AccountManager.shared.activeAccount?.id != account.id {
            await AccountManager.shared.configureProviderForAccount(account)
        }
    }

    func cancelLoading() {
        loadingTask?.cancel()
        loadingTask = nil
    }

    /// Zeiträume, die im Hintergrund vorgeladen und gecacht werden, damit beim
    /// Umschalten der Chips sofort der korrekte Wert steht (kein sichtbares Springen).
    private static let prefetchPresets: [DateRangePreset] = [.today, .yesterday, .thisWeek, .last7Days]

    private var prefetchTask: Task<Void, Never>?

    /// Lädt still die Hero-Stats für die übrigen Standard-Zeiträume in den Cache.
    /// Aktualisiert KEINE @Published-Werte — befüllt nur den Cache, damit `loadStats`
    /// (cache-first) beim Zeitraumwechsel sofort den richtigen Wert anzeigen kann.
    func prefetchOtherRanges(except current: DateRange) {
        prefetchTask?.cancel()
        prefetchTask = Task { [weak self] in
            guard let self else { return }
            await self.ensureProviderConfigured()
            guard let provider = AnalyticsManager.shared.currentProvider else { return }
            for preset in Self.prefetchPresets where preset != current.preset {
                if Task.isCancelled { return }
                let range = DateRange(preset: preset)
                do {
                    let analyticsStats = try await provider.getAnalyticsStats(websiteId: self.websiteId, dateRange: range)
                    if Task.isCancelled { return }
                    self.cache.saveStats(CachedStats(from: analyticsStats), websiteId: self.websiteId, dateRangeId: preset.rawValue)
                } catch {
                    // Vorladen ist best-effort — Fehler still ignorieren.
                }
            }
        }
    }

    func stopPrefetch() {
        prefetchTask?.cancel()
        prefetchTask = nil
    }

    // MARK: - Periodisches Hintergrund-Refresh

    private var autoRefreshTask: Task<Void, Never>?
    private let autoRefreshInterval: Duration = .seconds(45)

    /// Startet ein stilles periodisches Nachladen der Tages-Stats, solange die
    /// Detailansicht offen ist. Der erste Load läuft hier NICHT — den übernimmt
    /// `.task(id: selectedDateRange)` in der View. Hält nur die Werte aktuell.
    func startAutoRefresh(dateRange: DateRange) {
        autoRefreshTask?.cancel()
        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: self?.autoRefreshInterval ?? .seconds(45))
                guard !Task.isCancelled, let self else { return }
                await self.loadData(dateRange: dateRange, silent: true)
            }
        }
    }

    func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    private func loadStats(dateRange: DateRange) async {
        guard let provider = AnalyticsManager.shared.currentProvider else { return }
        let dateRangeId = dateRange.preset.rawValue

        // Cache-first: gecachten Wert für genau diesen Zeitraum sofort anzeigen,
        // damit beim Öffnen / Zeitraumwechsel direkt die korrekte Zahl steht statt
        // eines leeren oder fremden Werts. Danach wird still revalidiert.
        if let cached = cache.loadStats(websiteId: websiteId, dateRangeId: dateRangeId) {
            let cachedStats = cached.data.toAnalyticsStats().toWebsiteStats()
            if stats != cachedStats {
                stats = cachedStats
                totalVisitors = cachedStats.visitors.value
            }
        }

        do {
            let analyticsStats = try await provider.getAnalyticsStats(websiteId: websiteId, dateRange: dateRange)
            guard !Task.isCancelled else { return }
            let websiteStats = analyticsStats.toWebsiteStats()
            // Nur überschreiben, wenn sich der Wert wirklich geändert hat — verhindert
            // sichtbares Springen der Zahl beim stillen Hintergrund-Refresh.
            if stats != websiteStats {
                stats = websiteStats
                totalVisitors = websiteStats.visitors.value
            }
            cache.saveStats(CachedStats(from: analyticsStats), websiteId: websiteId, dateRangeId: dateRangeId)
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
        let dateRangeId = dateRange.preset.rawValue

        // Cache-first: zuletzt gerenderten Graphen für genau diesen Zeitraum sofort
        // anzeigen (analog zu loadStats), damit beim Öffnen / Zeitraumwechsel kein
        // leerer Platz entsteht. Danach wird still revalidiert.
        if let cached = cache.loadChart(websiteId: websiteId, dateRangeId: dateRangeId) {
            if pageviewsData != cached.data.pageviews { pageviewsData = cached.data.pageviews }
            if sessionsData != cached.data.visitors { sessionsData = cached.data.visitors }
        }

        // Skeleton nur zeigen, wenn wirklich noch nichts da ist (kein Cache-Treffer).
        isChartLoading = pageviewsData.isEmpty

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
            // Update both at once to avoid partial render — nur bei echter Änderung,
            // damit der stille Refresh den Graphen nicht unnötig neu zeichnet.
            if pageviewsData != filledPageviews { pageviewsData = filledPageviews }
            if sessionsData != filledSessions { sessionsData = filledSessions }
            isChartLoading = false
            cache.saveChart(CachedChart(pageviews: filledPageviews, visitors: filledSessions),
                            websiteId: websiteId, dateRangeId: dateRangeId)
        } catch {
            if !Task.isCancelled {
                isChartLoading = false
                Logger.ui.error("Failed to load pageviews: \(error.localizedDescription)")
            }
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

        // Frühestes / spätestes Datum in den API-Daten ermitteln. Nur im `today`-Zweig
        // verwendet, um UTC-vs-lokal-Skew abzufangen ohne andere Presets zu verändern.
        var earliestDataDate: Date? = nil
        var latestDataDate: Date? = nil
        for point in data {
            let pointDate = point.date
            if earliestDataDate == nil || pointDate < earliestDataDate! { earliestDataDate = pointDate }
            if latestDataDate == nil || pointDate > latestDataDate! { latestDataDate = pointDate }
        }

        if isHourly {
            let nowStartOfDay = utcCalendar.startOfDay(for: now)

            // Slot-Anfang und -Ende abhängig vom Preset bestimmen.
            let startOfDay: Date
            let lastHourOffset: Int // Stunden seit startOfDay (inklusiver Endwert)

            switch dateRange.preset {
            case .today:
                // Die frühere von (heutiger UTC-startOfDay) und (UTC-startOfDay des frühesten
                // Datenpunkts) verwenden — fängt den Fall ab, dass lokales "heute" UTC-mäßig
                // bereits gestern Abend begonnen hat (z.B. CEST 01:30 → UTC 23:30 vom Vortag).
                let earliestUtcStart: Date
                if let earliest = earliestDataDate {
                    earliestUtcStart = utcCalendar.startOfDay(for: earliest)
                } else {
                    earliestUtcStart = nowStartOfDay
                }
                startOfDay = min(nowStartOfDay, earliestUtcStart)

                // Aktuelle Stunde relativ zu startOfDay (kann >23 sein wenn startOfDay
                // auf dem vorherigen UTC-Tag liegt).
                let currentHourOffset = Int(
                    (now.timeIntervalSince(startOfDay) / 3600.0).rounded(.down)
                )
                // Stunden-Offset des spätesten Datenpunkts. Kann currentHourOffset
                // überschreiten, wenn die API-Daten in einer UTC-Stunde *vor* der
                // aktuellen UTC-Uhrzeit des Geräts liegen.
                let latestDataHourOffset: Int
                if let latest = latestDataDate {
                    latestDataHourOffset = Int(
                        (latest.timeIntervalSince(startOfDay) / 3600.0).rounded(.down)
                    )
                } else {
                    latestDataHourOffset = currentHourOffset
                }
                lastHourOffset = max(currentHourOffset, latestDataHourOffset)

            case .yesterday:
                let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
                startOfDay = utcCalendar.startOfDay(for: yesterday)
                lastHourOffset = 23

            default:
                startOfDay = utcCalendar.startOfDay(for: dateRange.dates.start)
                lastHourOffset = 23
            }

            // Defensive Untergrenze — sollte im normalen Flow nicht eintreten.
            let upperBound = max(0, lastHourOffset)

            for hourOffset in 0...upperBound {
                if let hourDate = utcCalendar.date(byAdding: .hour, value: hourOffset, to: startOfDay) {
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
        // Sync to UmamiAPI actor so all API calls pick up the filter
        Task { await UmamiAPI.shared.setFilters(activeFilters) }
    }

    func removeFilter(dimension: String) {
        activeFilters.removeAll { $0.dimension == dimension }
        Task { await UmamiAPI.shared.setFilters(activeFilters) }
    }
}
