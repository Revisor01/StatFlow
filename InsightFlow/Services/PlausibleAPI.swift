import Foundation
import WidgetKit

// MARK: - Plausible API

actor PlausibleAPI: AnalyticsProvider {
    static let shared = PlausibleAPI()

    nonisolated let providerType: AnalyticsProviderType = .plausible

    nonisolated var serverURL: String {
        KeychainService.load(for: .serverURL) ?? "https://plausible.io"
    }

    nonisolated var apiKey: String? {
        KeychainService.load(for: .apiKey)
    }

    nonisolated var isAuthenticated: Bool {
        KeychainService.load(for: .apiKey) != nil
    }

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private init() {}

    // MARK: - Authentication

    func authenticate(serverURL: String, credentials: AnalyticsCredentials) async throws {
        guard case .plausible(let apiKey) = credentials else {
            throw PlausibleError.invalidCredentials
        }

        // Normalize server URL
        let normalizedURL = normalizeServerURL(serverURL)

        guard let queryURL = URL(string: "\(normalizedURL)/api/v2/query") else {
            throw PlausibleError.invalidResponse
        }

        // Validate the API key by checking if the server responds correctly
        // We use a simple query that will return 401 if the key is invalid
        // or 400 if there's no site_id (which is fine - means the key is valid)
        var request = URLRequest(url: queryURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        // Send empty body - will get 400 (missing params) if key is valid, 401 if invalid
        let testQuery: [String: Any] = [:]
        request.httpBody = try JSONSerialization.data(withJSONObject: testQuery)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlausibleError.invalidResponse
        }

        // 400 means key is valid but request is malformed (expected)
        // 401 means key is invalid
        guard httpResponse.statusCode == 400 || httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw PlausibleError.unauthorized
            }
            throw PlausibleError.serverError(httpResponse.statusCode)
        }

        // Save credentials with normalized URL
        try KeychainService.save(normalizedURL, for: .serverURL)
        try KeychainService.save(apiKey, for: .apiKey)
        await MainActor.run { AnalyticsManager.shared.saveProviderType(.plausible) }
    }

    /// Normalizes the server URL by ensuring it has https:// prefix and no trailing slash
    private func normalizeServerURL(_ url: String) -> String {
        var normalized = url.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove trailing slashes
        while normalized.hasSuffix("/") {
            normalized.removeLast()
        }

        // Add https:// if no scheme present
        if !normalized.lowercased().hasPrefix("http://") && !normalized.lowercased().hasPrefix("https://") {
            normalized = "https://" + normalized
        }

        return normalized
    }

    /// Reconfigure from Keychain - called when switching accounts
    func reconfigureFromKeychain() {
        // PlausibleAPI reads from Keychain via nonisolated computed properties — no actor state to update
    }

    // MARK: - Site Management

    func getSitesList() async throws -> [PlausibleSite] {
        let data = try await request(endpoint: "api/v1/sites")
        let response = try decoder.decode(PlausibleSitesResponse.self, from: data)
        return response.sites
    }

    func addSite(domain: String) async throws {
        // Normalize the domain (remove http/https, trailing slashes, whitespace)
        let normalizedDomain = normalizeDomain(domain)

        guard !normalizedDomain.isEmpty else {
            throw PlausibleError.invalidCredentials
        }

        // Validate the site by querying it
        let body: [String: Any] = [
            "site_id": normalizedDomain,
            "metrics": ["visitors"],
            "date_range": "7d"
        ]

        let data = try await postRequest(endpoint: "api/v2/query", body: body)
        // If we get here without error, the site is valid
        _ = try decoder.decode(PlausibleAPIResponse.self, from: data)

        // Save to local storage
        await MainActor.run { PlausibleSitesManager.shared.addSite(normalizedDomain) }
    }

    /// Normalizes a domain by removing protocol, trailing slashes, and whitespace
    private func normalizeDomain(_ domain: String) -> String {
        var normalized = domain.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove protocol
        normalized = normalized.replacingOccurrences(of: "https://", with: "")
        normalized = normalized.replacingOccurrences(of: "http://", with: "")

        // Remove trailing slashes
        while normalized.hasSuffix("/") {
            normalized.removeLast()
        }

        // Remove www. prefix if present
        if normalized.hasPrefix("www.") {
            normalized = String(normalized.dropFirst(4))
        }

        return normalized.lowercased()
    }

    func removeSite(domain: String) async {
        await MainActor.run { PlausibleSitesManager.shared.removeSite(domain) }
    }

    // MARK: - Websites

    func getAnalyticsWebsites() async throws -> [AnalyticsWebsite] {
        let sites = await MainActor.run { PlausibleSitesManager.shared.sites }
        return sites.map { domain in
            AnalyticsWebsite(
                id: domain,
                name: domain,
                domain: domain,
                shareId: nil,
                provider: .plausible
            )
        }
    }

    // MARK: - Date Range Helper

    /// Converts DateRange to Plausible API date_range format
    /// Uses native shortcuts where available for consistency with Plausible web dashboard
    private func plausibleDateRange(for dateRange: DateRange) -> Any {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        switch dateRange.preset {
        case .today:
            return "day"
        case .yesterday:
            // Plausible doesn't have a "yesterday" shortcut, use custom range
            let dates = dateRange.dates
            return [formatter.string(from: dates.start), formatter.string(from: dates.end)]
        case .last7Days:
            return "7d"
        case .last30Days:
            return "30d"
        case .thisMonth:
            return "month"
        case .thisYear:
            return "year"
        case .thisWeek, .lastMonth, .lastYear, .custom:
            // Use custom date range for presets without native Plausible shortcut
            let dates = dateRange.dates
            return [formatter.string(from: dates.start), formatter.string(from: dates.end)]
        }
    }

    /// Calculates previous period date range for comparison
    private func plausiblePreviousDateRange(for dateRange: DateRange) -> Any {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let previousRange = dateRange.previousPeriod
        return [formatter.string(from: previousRange.start), formatter.string(from: previousRange.end)]
    }

    // MARK: - Stats

    func getAnalyticsStats(websiteId: String, dateRange: DateRange) async throws -> AnalyticsStats {
        let body: [String: Any] = [
            "site_id": websiteId,
            "metrics": ["visitors", "pageviews", "visits", "bounce_rate", "visit_duration"],
            "date_range": plausibleDateRange(for: dateRange)
        ]

        let data = try await postRequest(endpoint: "api/v2/query", body: body)
        let response = try decoder.decode(PlausibleAPIResponse.self, from: data)

        // Calculate previous period for comparison
        let previousBody: [String: Any] = [
            "site_id": websiteId,
            "metrics": ["visitors", "pageviews", "visits", "bounce_rate", "visit_duration"],
            "date_range": plausiblePreviousDateRange(for: dateRange)
        ]

        let previousData = try await postRequest(endpoint: "api/v2/query", body: previousBody)
        let previousResponse = try decoder.decode(PlausibleAPIResponse.self, from: previousData)

        let current = response.results.first.map { PlausibleStatsResult(from: $0) } ?? PlausibleStatsResult()
        let previous = previousResponse.results.first.map { PlausibleStatsResult(from: $0) } ?? PlausibleStatsResult()

        // Plausible returns visit_duration as average per visit (in seconds)
        // To match Umami's totaltime (total time / visits = average), we multiply by visits
        let currentTotalTime = current.visitDuration * current.visits
        let previousTotalTime = previous.visitDuration * previous.visits

        // Plausible returns bounce_rate as percentage (e.g., 31 for 31%)
        // Umami expects absolute bounce count, so we calculate: bounces = bounce_rate * visits / 100
        let currentBounces = Int(round(current.bounceRate * Double(current.visits) / 100))
        let previousBounces = Int(round(previous.bounceRate * Double(previous.visits) / 100))

        return AnalyticsStats(
            visitors: StatValue(value: current.visitors, change: current.visitors - previous.visitors),
            pageviews: StatValue(value: current.pageviews, change: current.pageviews - previous.pageviews),
            visits: StatValue(value: current.visits, change: current.visits - previous.visits),
            bounces: StatValue(value: currentBounces, change: currentBounces - previousBounces),
            totaltime: StatValue(value: currentTotalTime, change: currentTotalTime - previousTotalTime)
        )
    }

    func getPageviewsData(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsChartPoint] {
        return try await getTimeseriesData(websiteId: websiteId, dateRange: dateRange, metric: "pageviews")
    }

    func getVisitorsData(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsChartPoint] {
        return try await getTimeseriesData(websiteId: websiteId, dateRange: dateRange, metric: "visitors")
    }

    private func getTimeseriesData(websiteId: String, dateRange: DateRange, metric: String) async throws -> [AnalyticsChartPoint] {
        // Use hourly data for today/yesterday, daily for longer ranges
        let isShortRange = dateRange.preset == .today || dateRange.preset == .yesterday
        let timeDimension = isShortRange ? "time:hour" : "time:day"

        let body: [String: Any] = [
            "site_id": websiteId,
            "metrics": [metric],
            "date_range": plausibleDateRange(for: dateRange),
            "dimensions": [timeDimension]
        ]

        let data = try await postRequest(endpoint: "api/v2/query", body: body)
        let response = try decoder.decode(PlausibleAPIResponse.self, from: data)

        // Parse both date formats: "yyyy-MM-dd" and "yyyy-MM-dd HH:mm:ss"
        let dayParser = DateFormatter()
        dayParser.dateFormat = "yyyy-MM-dd"

        let hourParser = DateFormatter()
        hourParser.dateFormat = "yyyy-MM-dd HH:mm:ss"

        return response.results.compactMap { apiResult in
            let result = PlausibleTimeseriesResult(from: apiResult)
            let date = hourParser.date(from: result.date) ?? dayParser.date(from: result.date)
            guard let parsedDate = date else { return nil }
            return AnalyticsChartPoint(date: parsedDate, value: result.value)
        }
    }

    // MARK: - Realtime

    func getActiveVisitors(websiteId: String) async throws -> Int {
        // Use v1 API for realtime - works with all Plausible CE versions
        guard let apiKey = apiKey else {
            throw PlausibleError.notAuthenticated
        }

        guard let baseURL = URL(string: serverURL) else {
            throw PlausibleError.invalidResponse
        }

        guard var components = URLComponents(url: baseURL.appendingPathComponent("api/v1/stats/realtime/visitors"), resolvingAgainstBaseURL: false) else {
            throw PlausibleError.invalidResponse
        }
        components.queryItems = [URLQueryItem(name: "site_id", value: websiteId)]

        guard let componentsURL = components.url else {
            throw PlausibleError.invalidResponse
        }
        var request = URLRequest(url: componentsURL)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 401 {
                throw PlausibleError.unauthorized
            } else if httpResponse.statusCode != 200 {
                throw PlausibleError.serverError(httpResponse.statusCode)
            }
        }

        // Response is just a plain integer
        if let count = Int(String(data: data, encoding: .utf8) ?? "") {
            return count
        }

        return 0
    }

    func getRealtimeData(websiteId: String) async throws -> AnalyticsRealtimeData {
        let activeVisitors = try await getActiveVisitors(websiteId: websiteId)
        // Plausible doesn't provide detailed realtime pageviews/events like Umami
        return AnalyticsRealtimeData(
            activeVisitors: activeVisitors,
            pageviews: [],
            events: []
        )
    }

    func getRealtimeTopPages(websiteId: String, limit: Int = 10) async throws -> [AnalyticsMetricItem] {
        // Note: Plausible "realtime" only supports visitors metric, not pageviews
        // Use "day" for breakdown with pages since realtime doesn't support dimensions
        let body: [String: Any] = [
            "site_id": websiteId,
            "metrics": ["visitors"],
            "date_range": "day",
            "dimensions": ["event:page"],
            "limit": limit
        ]

        let data = try await postRequest(endpoint: "api/v2/query", body: body)
        let response = try decoder.decode(PlausibleAPIResponse.self, from: data)

        return response.results.map { apiResult in
            let result = PlausibleBreakdownResult(from: apiResult)
            return AnalyticsMetricItem(name: result.dimension, value: result.visitors)
        }
    }

    func getRealtimeCountries(websiteId: String, limit: Int = 10) async throws -> [AnalyticsMetricItem] {
        // Use "day" for breakdown since realtime doesn't support dimensions
        let body: [String: Any] = [
            "site_id": websiteId,
            "metrics": ["visitors"],
            "date_range": "day",
            "dimensions": ["visit:country"],
            "limit": limit
        ]

        let data = try await postRequest(endpoint: "api/v2/query", body: body)
        let response = try decoder.decode(PlausibleAPIResponse.self, from: data)

        return response.results.map { apiResult in
            let result = PlausibleBreakdownResult(from: apiResult)
            return AnalyticsMetricItem(name: result.dimension, value: result.visitors)
        }
    }

    func getRealtimePageviews(websiteId: String) async throws -> Int {
        // Use "day" since realtime doesn't support pageviews metric
        let body: [String: Any] = [
            "site_id": websiteId,
            "metrics": ["pageviews"],
            "date_range": "day"
        ]

        let data = try await postRequest(endpoint: "api/v2/query", body: body)
        let response = try decoder.decode(PlausibleAPIResponse.self, from: data)
        return response.results.first?.metrics.first.map { Int($0) } ?? 0
    }

    // MARK: - Metrics

    func getPages(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem] {
        return try await getBreakdown(websiteId: websiteId, dateRange: dateRange, dimension: "event:page")
    }

    func getReferrers(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem] {
        return try await getBreakdown(websiteId: websiteId, dateRange: dateRange, dimension: "visit:source")
    }

    func getCountries(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem] {
        return try await getBreakdown(websiteId: websiteId, dateRange: dateRange, dimension: "visit:country")
    }

    func getRegions(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem] {
        return try await getBreakdown(websiteId: websiteId, dateRange: dateRange, dimension: "visit:region")
    }

    func getCities(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem] {
        return try await getBreakdown(websiteId: websiteId, dateRange: dateRange, dimension: "visit:city")
    }

    func getDevices(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem] {
        return try await getBreakdown(websiteId: websiteId, dateRange: dateRange, dimension: "visit:device")
    }

    func getBrowsers(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem] {
        return try await getBreakdown(websiteId: websiteId, dateRange: dateRange, dimension: "visit:browser")
    }

    func getOS(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem] {
        return try await getBreakdown(websiteId: websiteId, dateRange: dateRange, dimension: "visit:os")
    }

    private func getBreakdown(websiteId: String, dateRange: DateRange, dimension: String, filters: [PlausibleQueryFilter] = []) async throws -> [AnalyticsMetricItem] {
        let body = buildQueryBody(siteId: websiteId, metrics: ["visitors"], dateRange: dateRange, dimensions: [dimension], filters: filters)

        let data = try await postRequest(endpoint: "api/v2/query", body: body)
        let response = try decoder.decode(PlausibleAPIResponse.self, from: data)

        return response.results.map { apiResult in
            let result = PlausibleBreakdownResult(from: apiResult)
            return AnalyticsMetricItem(name: result.dimension, value: result.visitors)
        }
    }

    // MARK: - Website Management

    func createSite(domain: String, timezone: String = "Europe/Berlin") async throws -> PlausibleSite {
        guard let apiKey = apiKey else {
            throw PlausibleError.notAuthenticated
        }

        guard let url = URL(string: "\(serverURL)/api/v1/sites") else {
            throw PlausibleError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "domain": domain,
            "timezone": timezone
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlausibleError.invalidResponse
        }

        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            if httpResponse.statusCode == 401 {
                throw PlausibleError.unauthorized
            }
            throw PlausibleError.serverError(httpResponse.statusCode)
        }

        return try decoder.decode(PlausibleSite.self, from: data)
    }

    func deleteSite(domain: String) async throws {
        guard let apiKey = apiKey else {
            throw PlausibleError.notAuthenticated
        }

        let encodedDomain = domain.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? domain
        guard let url = URL(string: "\(serverURL)/api/v1/sites/\(encodedDomain)") else {
            throw PlausibleError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlausibleError.invalidResponse
        }

        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
            if httpResponse.statusCode == 401 {
                throw PlausibleError.unauthorized
            }
            throw PlausibleError.serverError(httpResponse.statusCode)
        }
    }

    func getSiteDetails(domain: String) async throws -> PlausibleSiteDetails {
        let encodedDomain = domain.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? domain
        let data = try await request(endpoint: "api/v1/sites/\(encodedDomain)")
        return try decoder.decode(PlausibleSiteDetails.self, from: data)
    }

    // MARK: - Shared Links

    func createOrGetSharedLink(domain: String, name: String = "Public Dashboard") async throws -> PlausibleSharedLink {
        guard let apiKey = apiKey else {
            throw PlausibleError.notAuthenticated
        }

        let encodedDomain = domain.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? domain
        guard let url = URL(string: "\(serverURL)/api/v1/sites/\(encodedDomain)/shared-links") else {
            throw PlausibleError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = ["name": name]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlausibleError.invalidResponse
        }

        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            if httpResponse.statusCode == 401 {
                throw PlausibleError.unauthorized
            }
            throw PlausibleError.serverError(httpResponse.statusCode)
        }

        return try decoder.decode(PlausibleSharedLink.self, from: data)
    }

    // MARK: - Goals

    func getGoals(domain: String) async throws -> [PlausibleGoal] {
        let encodedDomain = domain.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? domain
        let data = try await request(endpoint: "api/v1/sites/\(encodedDomain)/goals")
        let response = try decoder.decode(PlausibleGoalsResponse.self, from: data)
        return response.goals
    }

    func createGoal(domain: String, goalType: PlausibleGoalType, value: String) async throws -> PlausibleGoal {
        guard let apiKey = apiKey else {
            throw PlausibleError.notAuthenticated
        }

        let encodedDomain = domain.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? domain
        guard let url = URL(string: "\(serverURL)/api/v1/sites/\(encodedDomain)/goals") else {
            throw PlausibleError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        var body: [String: Any] = ["goal_type": goalType.rawValue]
        switch goalType {
        case .event:
            body["event_name"] = value
        case .page:
            body["page_path"] = value
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlausibleError.invalidResponse
        }

        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            if httpResponse.statusCode == 401 {
                throw PlausibleError.unauthorized
            }
            throw PlausibleError.serverError(httpResponse.statusCode)
        }

        return try decoder.decode(PlausibleGoal.self, from: data)
    }

    func deleteGoal(domain: String, goalId: Int) async throws {
        guard let apiKey = apiKey else {
            throw PlausibleError.notAuthenticated
        }

        let encodedDomain = domain.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? domain
        guard let url = URL(string: "\(serverURL)/api/v1/sites/\(encodedDomain)/goals/\(goalId)") else {
            throw PlausibleError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlausibleError.invalidResponse
        }

        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
            if httpResponse.statusCode == 401 {
                throw PlausibleError.unauthorized
            }
            throw PlausibleError.serverError(httpResponse.statusCode)
        }
    }

    // MARK: - Tracking Code

    nonisolated func getTrackingCode(domain: String) -> String {
        """
        <script defer data-domain="\(domain)" src="\(serverURL)/js/script.js"></script>
        """
    }

    // MARK: - Query Builder

    /// Builds v2 query body with optional filters
    private func buildQueryBody(
        siteId: String,
        metrics: [String],
        dateRange: DateRange,
        dimensions: [String] = [],
        filters: [PlausibleQueryFilter] = [],
        limit: Int? = nil
    ) -> [String: Any] {
        var body: [String: Any] = [
            "site_id": siteId,
            "metrics": metrics,
            "date_range": plausibleDateRange(for: dateRange)
        ]
        if !dimensions.isEmpty { body["dimensions"] = dimensions }
        if !filters.isEmpty { body["filters"] = filters.map { $0.toQueryParam() } }
        if let limit = limit { body["limit"] = limit }
        return body
    }

    // MARK: - Network

    private func request(endpoint: String) async throws -> Data {
        guard let apiKey = apiKey else {
            throw PlausibleError.notAuthenticated
        }

        guard let url = URL(string: "\(serverURL)/\(endpoint)") else {
            throw PlausibleError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlausibleError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw PlausibleError.unauthorized
            }
            throw PlausibleError.serverError(httpResponse.statusCode)
        }

        return data
    }

    private func postRequest(endpoint: String, body: [String: Any]) async throws -> Data {
        guard let apiKey = apiKey else {
            throw PlausibleError.notAuthenticated
        }

        guard let url = URL(string: "\(serverURL)/\(endpoint)") else {
            throw PlausibleError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlausibleError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            // Try to extract error message from response
            if let errorResponse = try? JSONDecoder().decode(PlausibleErrorResponse.self, from: data) {
                throw PlausibleError.apiError(errorResponse.error)
            }
            if httpResponse.statusCode == 401 {
                throw PlausibleError.unauthorized
            }
            throw PlausibleError.serverError(httpResponse.statusCode)
        }

        return data
    }
}

// MARK: - Plausible Response Models

struct PlausibleSitesResponse: Codable {
    let sites: [PlausibleSite]

    enum CodingKeys: String, CodingKey {
        case sites = "data"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sites = try container.decodeIfPresent([PlausibleSite].self, forKey: .sites) ?? []
    }
}

struct PlausibleSite: Codable, Identifiable {
    let domain: String
    let timezone: String?

    var id: String { domain }
}

struct PlausibleSiteDetails: Codable {
    let domain: String
    let timezone: String?
    let customDomain: String?
    let sharedLinks: [PlausibleSharedLink]?

    enum CodingKeys: String, CodingKey {
        case domain, timezone
        case customDomain = "custom_domain"
        case sharedLinks = "shared_links"
    }
}

struct PlausibleSharedLink: Codable, Identifiable {
    let name: String
    let slug: String
    let href: String?

    var id: String { slug }

    var url: String {
        href ?? ""
    }
}

// MARK: - Plausible API v2 Response Models

struct PlausibleAPIResponse: Codable {
    let results: [PlausibleAPIResult]
}

struct PlausibleAPIResult: Codable {
    let metrics: [Double]
    let dimensions: [String]
}

// Helper to parse stats response (metrics in order: visitors, pageviews, visits, bounce_rate, visit_duration)
struct PlausibleStatsResult {
    var visitors: Int = 0
    var pageviews: Int = 0
    var visits: Int = 0
    var bounceRate: Double = 0
    var visitDuration: Int = 0

    init() {}

    init(from apiResult: PlausibleAPIResult) {
        if apiResult.metrics.count > 0 { visitors = Int(apiResult.metrics[0]) }
        if apiResult.metrics.count > 1 { pageviews = Int(apiResult.metrics[1]) }
        if apiResult.metrics.count > 2 { visits = Int(apiResult.metrics[2]) }
        if apiResult.metrics.count > 3 { bounceRate = apiResult.metrics[3] }
        if apiResult.metrics.count > 4 { visitDuration = Int(apiResult.metrics[4]) }
    }
}

// Helper to parse timeseries response (dimension is date, metric is value)
struct PlausibleTimeseriesResult {
    let date: String
    let value: Int

    init(from apiResult: PlausibleAPIResult) {
        date = apiResult.dimensions.first ?? ""
        value = apiResult.metrics.first.map { Int($0) } ?? 0
    }
}

// Helper to parse breakdown response (dimension is name, metric is visitors)
struct PlausibleBreakdownResult {
    let dimension: String
    let visitors: Int

    init(from apiResult: PlausibleAPIResult) {
        dimension = apiResult.dimensions.first ?? "Unknown"
        visitors = apiResult.metrics.first.map { Int($0) } ?? 0
    }
}

// Error response from Plausible API
struct PlausibleErrorResponse: Codable {
    let error: String
}

// MARK: - Plausible Errors

enum PlausibleError: LocalizedError {
    case notAuthenticated
    case invalidCredentials
    case invalidResponse
    case unauthorized
    case serverError(Int)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return String(localized: "error.notAuthenticated")
        case .invalidCredentials:
            return String(localized: "error.invalidCredentials")
        case .invalidResponse:
            return String(localized: "error.invalidResponse")
        case .unauthorized:
            return String(localized: "error.unauthorized")
        case .serverError(let code):
            return String(localized: "error.server \(code)")
        case .apiError(let message):
            return message
        }
    }
}

// MARK: - DateRange Extension

extension DateRange {
    var previousPeriod: (start: Date, end: Date) {
        let current = dates
        let duration = current.end.timeIntervalSince(current.start)
        let previousEnd = current.start.addingTimeInterval(-1)
        let previousStart = previousEnd.addingTimeInterval(-duration)
        return (previousStart, previousEnd)
    }
}

// MARK: - Plausible Sites Manager

@MainActor
class PlausibleSitesManager: ObservableObject {
    static let shared = PlausibleSitesManager()

    private let sitesKey = "plausible_sites"
    private var skipSaveOnSet = false

    @Published var sites: [String] = [] {
        didSet {
            if !skipSaveOnSet {
                saveSites()
            }
        }
    }

    private init() {
        loadSites()
    }

    func getSites() -> [String] {
        return sites
    }

    /// Set sites without triggering save (used when loading from account)
    func setSitesWithoutPersist(_ newSites: [String]) {
        skipSaveOnSet = true
        sites = newSites
        skipSaveOnSet = false
    }

    func addSite(_ domain: String) {
        let normalizedDomain = domain.lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if !sites.contains(normalizedDomain) {
            sites.append(normalizedDomain)
            saveSites()
        }
    }

    func removeSite(_ domain: String) {
        sites.removeAll { $0 == domain }
        saveSites()
    }

    func clearAll() {
        sites.removeAll()
        saveSites()
    }

    private func loadSites() {
        if let data = UserDefaults.standard.data(forKey: sitesKey),
           let savedSites = try? JSONDecoder().decode([String].self, from: data) {
            skipSaveOnSet = true
            sites = savedSites
            skipSaveOnSet = false
        }
    }

    private func saveSites() {
        if let data = try? JSONEncoder().encode(sites) {
            UserDefaults.standard.set(data, forKey: sitesKey)
        }
        // Update SharedCredentials for widget
        updateWidgetCredentials()
        // Update active account with sites
        updateActiveAccountSites()
    }

    private func updateActiveAccountSites() {
        guard let activeAccount = AccountManager.shared.activeAccount,
              activeAccount.providerType == .plausible else {
            #if DEBUG
            print("PlausibleSitesManager: updateActiveAccountSites skipped - no active Plausible account")
            #endif
            return
        }
        #if DEBUG
        print("PlausibleSitesManager: updating account \(activeAccount.name) with sites: \(sites)")
        #endif
        AccountManager.shared.updateAccountSites(activeAccount, sites: sites)
    }

    private func updateWidgetCredentials() {
        // Read credentials from Keychain and update SharedCredentials for widget
        guard let serverURL = KeychainService.load(for: .serverURL),
              let apiKey = KeychainService.load(for: .apiKey) else {
            return
        }
        SharedCredentials.save(
            serverURL: serverURL,
            token: apiKey,
            providerType: .plausible,
            sites: sites
        )
        // Refresh widget
        WidgetCenter.shared.reloadAllTimelines()
    }
}
