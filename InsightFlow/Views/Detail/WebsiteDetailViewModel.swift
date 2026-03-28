import Foundation

@MainActor
class WebsiteDetailViewModel: ObservableObject {
    let websiteId: String

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
    @Published var isLoading = false
    @Published var error: String?

    init(websiteId: String) {
        self.websiteId = websiteId
    }

    func loadData(dateRange: DateRange) async {
        isLoading = true
        defer { isLoading = false }

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
        }
    }

    private func loadStats(dateRange: DateRange) async {
        guard let provider = AnalyticsManager.shared.currentProvider else { return }
        do {
            let analyticsStats = try await provider.getAnalyticsStats(websiteId: websiteId, dateRange: dateRange)
            stats = analyticsStats.toWebsiteStats()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func loadActiveVisitors() async {
        guard let provider = AnalyticsManager.shared.currentProvider else { return }
        do {
            activeVisitors = try await provider.getActiveVisitors(websiteId: websiteId)
        } catch {
            #if DEBUG
            print("Failed to load active visitors: \(error)")
            #endif
        }
    }

    private func loadPageviews(dateRange: DateRange) async {
        guard let provider = AnalyticsManager.shared.currentProvider else { return }
        do {
            let formatter = ISO8601DateFormatter()
            let pageviewData = try await provider.getPageviewsData(websiteId: websiteId, dateRange: dateRange)
            let visitorData = try await provider.getVisitorsData(websiteId: websiteId, dateRange: dateRange)
            pageviewsData = fillMissingTimeSlots(
                data: pageviewData.map { TimeSeriesPoint(x: formatter.string(from: $0.date), y: $0.value) },
                dateRange: dateRange
            )
            sessionsData = fillMissingTimeSlots(
                data: visitorData.map { TimeSeriesPoint(x: formatter.string(from: $0.date), y: $0.value) },
                dateRange: dateRange
            )
        } catch {
            #if DEBUG
            print("Failed to load pageviews: \(error)")
            #endif
        }
    }

    /// Fills in missing time slots with zero values for complete chart display
    private func fillMissingTimeSlots(data: [TimeSeriesPoint], dateRange: DateRange) -> [TimeSeriesPoint] {
        let calendar = Calendar.current
        let now = Date()
        let isHourly = dateRange.unit == "hour"

        // Create a map of existing data by date
        var dataMap: [Date: Int] = [:]
        for point in data {
            dataMap[point.date] = point.value
        }

        var result: [TimeSeriesPoint] = []
        let formatter = ISO8601DateFormatter()

        if isHourly {
            // Generate all hours for the day
            let baseDate: Date
            switch dateRange.preset {
            case .today:
                baseDate = now
            case .yesterday:
                baseDate = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            default:
                baseDate = dateRange.dates.start
            }

            let startOfDay = calendar.startOfDay(for: baseDate)
            let currentHour = dateRange.preset == .today ? calendar.component(.hour, from: now) : 23

            for hour in 0...currentHour {
                if let hourDate = calendar.date(byAdding: .hour, value: hour, to: startOfDay) {
                    // Find matching value in data
                    let value = dataMap.first { existing in
                        calendar.component(.hour, from: existing.key) == hour &&
                        calendar.isDate(existing.key, inSameDayAs: hourDate)
                    }?.value ?? 0

                    result.append(TimeSeriesPoint(x: formatter.string(from: hourDate), y: value))
                }
            }
        } else {
            // Generate all days in range
            let dates = dateRange.dates
            var currentDate = calendar.startOfDay(for: dates.start)
            let endDate = calendar.startOfDay(for: dates.end)

            while currentDate <= endDate {
                // Find matching value in data
                let value = dataMap.first { existing in
                    calendar.isDate(existing.key, inSameDayAs: currentDate)
                }?.value ?? 0

                result.append(TimeSeriesPoint(x: formatter.string(from: currentDate), y: value))

                if let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) {
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
            topPages = items.map { MetricItem(x: $0.name, y: $0.value) }
        } catch {
            #if DEBUG
            print("Failed to load top pages: \(error)")
            #endif
        }
    }

    private func loadPageTitles(dateRange: DateRange) async {
        guard let provider = AnalyticsManager.shared.currentProvider else { return }
        do {
            let items = try await provider.getPageTitles(websiteId: websiteId, dateRange: dateRange)
            pageTitles = items.map { MetricItem(x: $0.name, y: $0.value) }
        } catch {
            #if DEBUG
            print("Failed to load page titles: \(error)")
            #endif
        }
    }

    private func loadReferrers(dateRange: DateRange) async {
        guard let provider = AnalyticsManager.shared.currentProvider else { return }
        do {
            let items = try await provider.getReferrers(websiteId: websiteId, dateRange: dateRange)
            referrers = items.map { MetricItem(x: $0.name, y: $0.value) }
        } catch {
            #if DEBUG
            print("Failed to load referrers: \(error)")
            #endif
        }
    }

    private func loadCountries(dateRange: DateRange) async {
        guard let provider = AnalyticsManager.shared.currentProvider else { return }
        do {
            let items = try await provider.getCountries(websiteId: websiteId, dateRange: dateRange)
            countries = items.map { MetricItem(x: $0.name, y: $0.value) }
        } catch {
            #if DEBUG
            print("Failed to load countries: \(error)")
            #endif
        }
    }

    private func loadRegions(dateRange: DateRange) async {
        guard let provider = AnalyticsManager.shared.currentProvider else { return }
        do {
            let items = try await provider.getRegions(websiteId: websiteId, dateRange: dateRange)
            regions = items.map { MetricItem(x: $0.name, y: $0.value) }
        } catch {
            #if DEBUG
            print("Failed to load regions: \(error)")
            #endif
        }
    }

    private func loadCities(dateRange: DateRange) async {
        guard let provider = AnalyticsManager.shared.currentProvider else { return }
        do {
            let items = try await provider.getCities(websiteId: websiteId, dateRange: dateRange)
            cities = items.map { MetricItem(x: $0.name, y: $0.value) }
        } catch {
            #if DEBUG
            print("Failed to load cities: \(error)")
            #endif
        }
    }

    private func loadDevices(dateRange: DateRange) async {
        guard let provider = AnalyticsManager.shared.currentProvider else { return }
        do {
            let items = try await provider.getDevices(websiteId: websiteId, dateRange: dateRange)
            devices = items.map { MetricItem(x: $0.name, y: $0.value) }
        } catch {
            #if DEBUG
            print("Failed to load devices: \(error)")
            #endif
        }
    }

    private func loadBrowsers(dateRange: DateRange) async {
        guard let provider = AnalyticsManager.shared.currentProvider else { return }
        do {
            let items = try await provider.getBrowsers(websiteId: websiteId, dateRange: dateRange)
            browsers = items.map { MetricItem(x: $0.name, y: $0.value) }
        } catch {
            #if DEBUG
            print("Failed to load browsers: \(error)")
            #endif
        }
    }

    private func loadOperatingSystems(dateRange: DateRange) async {
        guard let provider = AnalyticsManager.shared.currentProvider else { return }
        do {
            let items = try await provider.getOS(websiteId: websiteId, dateRange: dateRange)
            operatingSystems = items.map { MetricItem(x: $0.name, y: $0.value) }
        } catch {
            #if DEBUG
            print("Failed to load operating systems: \(error)")
            #endif
        }
    }

    private func loadLanguages(dateRange: DateRange) async {
        guard let provider = AnalyticsManager.shared.currentProvider else { return }
        do {
            let items = try await provider.getLanguages(websiteId: websiteId, dateRange: dateRange)
            languages = items.map { MetricItem(x: $0.name, y: $0.value) }
        } catch {
            #if DEBUG
            print("Failed to load languages: \(error)")
            #endif
        }
    }

    private func loadScreens(dateRange: DateRange) async {
        guard let provider = AnalyticsManager.shared.currentProvider else { return }
        do {
            let items = try await provider.getScreens(websiteId: websiteId, dateRange: dateRange)
            screens = items.map { MetricItem(x: $0.name, y: $0.value) }
        } catch {
            #if DEBUG
            print("Failed to load screens: \(error)")
            #endif
        }
    }

    private func loadEvents(dateRange: DateRange) async {
        guard let provider = AnalyticsManager.shared.currentProvider else { return }
        do {
            let items = try await provider.getEvents(websiteId: websiteId, dateRange: dateRange)
            events = items.map { MetricItem(x: $0.name, y: $0.value) }
        } catch {
            #if DEBUG
            print("Failed to load events: \(error)")
            #endif
        }
    }

    private func loadEntryPages(dateRange: DateRange) async {
        guard let provider = AnalyticsManager.shared.currentProvider,
              let plausible = provider as? PlausibleAPI else { return }
        do {
            let items = try await plausible.getEntryPages(websiteId: websiteId, dateRange: dateRange)
            entryPages = items.map { MetricItem(x: $0.name, y: $0.value) }
        } catch {
            #if DEBUG
            print("Failed to load entry pages: \(error)")
            #endif
        }
    }

    private func loadExitPages(dateRange: DateRange) async {
        guard let provider = AnalyticsManager.shared.currentProvider,
              let plausible = provider as? PlausibleAPI else { return }
        do {
            let items = try await plausible.getExitPages(websiteId: websiteId, dateRange: dateRange)
            exitPages = items.map { MetricItem(x: $0.name, y: $0.value) }
        } catch {
            #if DEBUG
            print("Failed to load exit pages: \(error)")
            #endif
        }
    }
}
