import Foundation

// MARK: - Analytics Provider Type

enum AnalyticsProviderType: String, Codable, CaseIterable {
    case umami
    case plausible

    var displayName: String {
        switch self {
        case .umami: return "Umami"
        case .plausible: return "Plausible"
        }
    }

    var icon: String {
        switch self {
        case .umami: return "chart.bar.xaxis"
        case .plausible: return "chart.line.uptrend.xyaxis"
        }
    }

    var websiteURL: String {
        switch self {
        case .umami: return "https://umami.is"
        case .plausible: return "https://plausible.io"
        }
    }

    /// API-Basis für Umami; `cloud.umami.is` ist nur die Weboberfläche.
    var cloudURL: String {
        switch self {
        case .umami: return UmamiAPI.cloudBaseURL
        case .plausible: return "https://plausible.io"
        }
    }
}

// MARK: - Server Type

enum AnalyticsServerType: String, Codable, CaseIterable {
    case cloud
    case selfHosted

    var displayName: String {
        switch self {
        case .cloud: return String(localized: "login.cloud.title")
        case .selfHosted: return String(localized: "login.selfhosted.title")
        }
    }

    var icon: String {
        switch self {
        case .cloud: return "cloud.fill"
        case .selfHosted: return "server.rack"
        }
    }
}

// MARK: - Unified Website Model

struct AnalyticsWebsite: Identifiable, Codable {
    let id: String
    let name: String
    let domain: String
    let shareId: String?
    let provider: AnalyticsProviderType
    /// Teamname der Website, nil bei persönlichen; nur zur Kennzeichnung.
    var teamName: String?

    var displayDomain: String {
        domain.replacingOccurrences(of: "https://", with: "")
              .replacingOccurrences(of: "http://", with: "")
    }
}

// MARK: - Unified Stats Model

struct AnalyticsStats {
    let visitors: StatValue
    let pageviews: StatValue
    let visits: StatValue
    let bounces: StatValue
    let totaltime: StatValue

    /// Konvertiert zu WebsiteStats für die Dashboard-Anzeige
    func toWebsiteStats() -> WebsiteStats {
        WebsiteStats(
            pageviews: pageviews,
            visitors: visitors,
            visits: visits,
            bounces: bounces,
            totaltime: totaltime
        )
    }
}


// MARK: - Unified Chart Data

struct AnalyticsChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Int
}

// MARK: - Unified Realtime Data

struct AnalyticsRealtimeData {
    let activeVisitors: Int
    let pageviews: [AnalyticsPageview]
    let events: [AnalyticsEvent]
}

struct AnalyticsPageview: Identifiable {
    let id = UUID()
    let url: String
    let referrer: String?
    let timestamp: Date
    let country: String?
    let city: String?
}

struct AnalyticsEvent: Identifiable {
    let id = UUID()
    let name: String
    let url: String
    let timestamp: Date
}

// MARK: - Analytics Provider Protocol

protocol AnalyticsProvider: Sendable {
    nonisolated var providerType: AnalyticsProviderType { get }
    nonisolated var serverURL: String { get }
    nonisolated var isAuthenticated: Bool { get }

    func authenticate(serverURL: String, credentials: AnalyticsCredentials) async throws

    func getAnalyticsWebsites() async throws -> [AnalyticsWebsite]

    func getAnalyticsStats(websiteId: String, dateRange: DateRange) async throws -> AnalyticsStats
    func getPageviewsData(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsChartPoint]
    func getVisitorsData(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsChartPoint]

    func getActiveVisitors(websiteId: String) async throws -> Int
    func getRealtimeData(websiteId: String) async throws -> AnalyticsRealtimeData

    func getPages(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem]
    func getReferrers(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem]
    func getCountries(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem]
    func getDevices(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem]
    func getBrowsers(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem]
    func getOS(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem]
    func getRegions(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem]
    func getCities(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem]
    func getPageTitles(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem]
    func getLanguages(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem]
    func getScreens(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem]
    func getEvents(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem]
    func getRealtimeTopPages(websiteId: String, limit: Int) async throws -> [AnalyticsMetricItem]
    func getRealtimeCountries(websiteId: String, limit: Int) async throws -> [AnalyticsMetricItem]
    func getRealtimePageviews(websiteId: String) async throws -> Int
}

// MARK: - Default Implementations for Provider-specific Metrics

extension AnalyticsProvider {
    func getPageTitles(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem] { [] }
    func getLanguages(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem] { [] }
    func getScreens(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem] { [] }
    func getEvents(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem] { [] }
}

struct AnalyticsMetricItem: Identifiable {
    let id = UUID()
    let name: String
    let value: Int
}

// MARK: - Credentials

enum AnalyticsCredentials {
    case umami(username: String, password: String)
    /// Umami Cloud: der API-Schlüssel ist das Bearer-Token, eine Passwort-Anmeldung gibt es nicht.
    case umamiCloud(apiKey: String)
    /// Eigene Instanz mit API-Schlüssel (ab Umami 3.4), ohne zweiten Faktor und ohne Ablauf.
    case umamiSelfHostedKey(apiKey: String)
    case plausible(apiKey: String)
}

// MARK: - Analytics Manager

@MainActor
class AnalyticsManager: ObservableObject {
    static let shared = AnalyticsManager()

    @Published var currentProvider: (any AnalyticsProvider)?
    @Published var providerType: AnalyticsProviderType?
    @Published var serverType: AnalyticsServerType?

    private init() {
        loadSavedProvider()
    }

    func setProvider(_ provider: any AnalyticsProvider) {
        currentProvider = provider
        providerType = provider.providerType
    }

    func logout() {
        currentProvider = nil
        providerType = nil
        serverType = nil
        KeychainService.delete(for: .providerType)
        KeychainService.delete(for: .serverType)
        KeychainService.delete(for: .serverURL)
        KeychainService.delete(for: .token)
        KeychainService.delete(for: .apiKey)
    }

    private func loadSavedProvider() {
        guard let providerTypeString = KeychainService.load(for: .providerType),
              let savedProviderType = AnalyticsProviderType(rawValue: providerTypeString) else {
            return
        }

        providerType = savedProviderType

        switch savedProviderType {
        case .umami:
            if KeychainService.load(for: .token) != nil {
                currentProvider = UmamiAPI.shared
            }
        case .plausible:
            if KeychainService.load(for: .apiKey) != nil {
                currentProvider = PlausibleAPI.shared
            }
        }
    }

    func saveProviderType(_ type: AnalyticsProviderType) {
        try? KeychainService.save(type.rawValue, for: .providerType)
        providerType = type
    }

    func saveServerType(_ type: AnalyticsServerType) {
        try? KeychainService.save(type.rawValue, for: .serverType)
        serverType = type
    }
}

