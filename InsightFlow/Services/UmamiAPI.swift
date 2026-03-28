import Foundation

actor UmamiAPI: AnalyticsProvider {
    static let shared = UmamiAPI()

    private var _baseURL: URL?
    private var _token: String?

    // MARK: - AnalyticsProvider Protocol

    nonisolated let providerType: AnalyticsProviderType = .umami

    nonisolated var serverURL: String {
        KeychainService.load(for: .serverURL) ?? ""
    }

    nonisolated var isAuthenticated: Bool {
        KeychainService.load(for: .token) != nil
    }

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            let formatters = [
                ISO8601DateFormatter(),
                {
                    let f = ISO8601DateFormatter()
                    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    return f
                }()
            ]

            for formatter in formatters {
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }
        return decoder
    }()

    func configure(baseURL: URL, token: String) {
        self._baseURL = baseURL
        self._token = token
    }

    func clearConfiguration() {
        self._baseURL = nil
        self._token = nil
    }

    /// Reconfigure from Keychain - called when switching accounts
    nonisolated func reconfigureFromKeychain() {
        Task {
            await reconfigureFromKeychainInternal()
        }
    }

    private func reconfigureFromKeychainInternal() {
        if let serverURL = KeychainService.load(for: .serverURL),
           let url = URL(string: serverURL),
           let token = KeychainService.load(for: .token) {
            self._baseURL = url
            self._token = token
        } else {
            self._baseURL = nil
            self._token = nil
        }
    }

    // MARK: - AnalyticsProvider - Authentication

    nonisolated func authenticate(serverURL: String, credentials: AnalyticsCredentials) async throws {
        guard case .umami(let username, let password) = credentials else {
            throw APIError.authenticationFailed
        }

        guard let url = URL(string: serverURL) else {
            throw APIError.invalidURL
        }

        let token = try await login(baseURL: url, username: username, password: password)

        // Save credentials
        try KeychainService.save(serverURL, for: .serverURL)
        try KeychainService.save(token, for: .token)
        try KeychainService.save(username, for: .username)
        try KeychainService.save(AnalyticsProviderType.umami.rawValue, for: .providerType)

        await configure(baseURL: url, token: token)
    }

    // MARK: - AnalyticsProvider - Websites

    func getAnalyticsWebsites() async throws -> [AnalyticsWebsite] {
        let websites = try await getWebsites()
        return websites.map { website in
            AnalyticsWebsite(
                id: website.id,
                name: website.name,
                domain: website.domain ?? website.name,
                shareId: website.shareId,
                provider: .umami
            )
        }
    }

    // MARK: - AnalyticsProvider - Stats

    func getAnalyticsStats(websiteId: String, dateRange: DateRange) async throws -> AnalyticsStats {
        let stats = try await getStats(websiteId: websiteId, dateRange: dateRange)
        return AnalyticsStats(
            visitors: StatValue(value: stats.visitors.value, change: stats.visitors.change),
            pageviews: StatValue(value: stats.pageviews.value, change: stats.pageviews.change),
            visits: StatValue(value: stats.visits.value, change: stats.visits.change),
            bounces: StatValue(value: stats.bounces.value, change: stats.bounces.change),
            totaltime: StatValue(value: stats.totaltime.value, change: stats.totaltime.change)
        )
    }

    func getPageviewsData(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsChartPoint] {
        let data = try await getPageviews(websiteId: websiteId, dateRange: dateRange)
        return data.pageviews.map { point in
            AnalyticsChartPoint(date: point.date, value: point.value)
        }
    }

    func getVisitorsData(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsChartPoint] {
        let data = try await getPageviews(websiteId: websiteId, dateRange: dateRange)
        return data.sessions.map { point in
            AnalyticsChartPoint(date: point.date, value: point.value)
        }
    }

    // MARK: - AnalyticsProvider - Realtime

    func getRealtimeData(websiteId: String) async throws -> AnalyticsRealtimeData {
        let realtime = try await getRealtime(websiteId: websiteId)
        let pageviewEvents = realtime.events.filter { $0.isPageview }
        let customEvents = realtime.events.filter { !$0.isPageview && !$0.isSession }
        return AnalyticsRealtimeData(
            activeVisitors: realtime.totals?.visitors ?? 0,
            pageviews: pageviewEvents.map { pv in
                AnalyticsPageview(
                    url: pv.urlPath ?? "",
                    referrer: pv.referrerDomain,
                    timestamp: pv.createdDate,
                    country: pv.country,
                    city: nil
                )
            },
            events: customEvents.map { ev in
                AnalyticsEvent(
                    name: ev.eventName ?? "",
                    url: ev.urlPath ?? "",
                    timestamp: ev.createdDate
                )
            }
        )
    }

    // MARK: - AnalyticsProvider - Metrics

    func getPages(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem] {
        let metrics = try await getMetrics(websiteId: websiteId, dateRange: dateRange, type: .path)
        return metrics.map { AnalyticsMetricItem(name: $0.name, value: $0.value) }
    }

    func getReferrers(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem] {
        let metrics = try await getMetrics(websiteId: websiteId, dateRange: dateRange, type: .referrer)
        return metrics.map { AnalyticsMetricItem(name: $0.name, value: $0.value) }
    }

    func getCountries(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem] {
        let metrics = try await getMetrics(websiteId: websiteId, dateRange: dateRange, type: .country)
        return metrics.map { AnalyticsMetricItem(name: $0.name, value: $0.value) }
    }

    func getDevices(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem] {
        let metrics = try await getMetrics(websiteId: websiteId, dateRange: dateRange, type: .device)
        return metrics.map { AnalyticsMetricItem(name: $0.name, value: $0.value) }
    }

    func getBrowsers(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem] {
        let metrics = try await getMetrics(websiteId: websiteId, dateRange: dateRange, type: .browser)
        return metrics.map { AnalyticsMetricItem(name: $0.name, value: $0.value) }
    }

    func getOS(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem] {
        let metrics = try await getMetrics(websiteId: websiteId, dateRange: dateRange, type: .os)
        return metrics.map { AnalyticsMetricItem(name: $0.name, value: $0.value) }
    }

    // MARK: - Authentication

    nonisolated func login(baseURL: URL, username: String, password: String) async throws -> String {
        let loginURL = baseURL.appendingPathComponent("api/auth/login")

        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body = ["username": username, "password": password]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.authenticationFailed
        }

        struct LoginResponse: Codable {
            let token: String
            let user: User?

            struct User: Codable {
                let id: String?
                let username: String?
            }
        }

        let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
        return loginResponse.token
    }

    // MARK: - Websites

    func getWebsites() async throws -> [Website] {
        let data = try await request(endpoint: "api/websites")
        let response = try decoder.decode(WebsiteResponse.self, from: data)
        return response.websites
    }

    // MARK: - Stats

    func getActiveVisitors(websiteId: String) async throws -> Int {
        let data = try await request(endpoint: "api/websites/\(websiteId)/active")
        let response = try decoder.decode(ActiveVisitorsResponse.self, from: data)
        return response.count
    }

    func getStats(websiteId: String, dateRange: DateRange) async throws -> WebsiteStats {
        let dates = dateRange.dates
        let startAt = Int(dates.start.timeIntervalSince1970 * 1000)
        let endAt = Int(dates.end.timeIntervalSince1970 * 1000)

        let data = try await request(
            endpoint: "api/websites/\(websiteId)/stats",
            queryItems: [
                URLQueryItem(name: "startAt", value: String(startAt)),
                URLQueryItem(name: "endAt", value: String(endAt))
            ]
        )
        let response = try decoder.decode(WebsiteStatsResponse.self, from: data)
        return WebsiteStats(from: response)
    }

    func getPageviews(websiteId: String, dateRange: DateRange) async throws -> PageviewsData {
        let dates = dateRange.dates
        let startAt = Int(dates.start.timeIntervalSince1970 * 1000)
        let endAt = Int(dates.end.timeIntervalSince1970 * 1000)

        let data = try await request(
            endpoint: "api/websites/\(websiteId)/pageviews",
            queryItems: [
                URLQueryItem(name: "startAt", value: String(startAt)),
                URLQueryItem(name: "endAt", value: String(endAt)),
                URLQueryItem(name: "unit", value: dateRange.unit)
            ]
        )
        return try decoder.decode(PageviewsData.self, from: data)
    }

    func getRealtime(websiteId: String) async throws -> RealtimeData {
        let data = try await request(endpoint: "api/realtime/\(websiteId)")
        return try decoder.decode(RealtimeData.self, from: data)
    }

    // MARK: - Sessions

    func getSessions(websiteId: String, dateRange: DateRange, page: Int = 1, pageSize: Int = 20) async throws -> SessionsResponse {
        let dates = dateRange.dates
        let startAt = Int(dates.start.timeIntervalSince1970 * 1000)
        let endAt = Int(dates.end.timeIntervalSince1970 * 1000)

        let data = try await request(
            endpoint: "api/websites/\(websiteId)/sessions",
            queryItems: [
                URLQueryItem(name: "startAt", value: String(startAt)),
                URLQueryItem(name: "endAt", value: String(endAt)),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "pageSize", value: String(pageSize))
            ]
        )
        return try decoder.decode(SessionsResponse.self, from: data)
    }

    func getSessionActivity(websiteId: String, sessionId: String, dateRange: DateRange) async throws -> [SessionActivity] {
        let dates = dateRange.dates
        let startAt = Int(dates.start.timeIntervalSince1970 * 1000)
        let endAt = Int(dates.end.timeIntervalSince1970 * 1000)

        let data = try await request(
            endpoint: "api/websites/\(websiteId)/sessions/\(sessionId)/activity",
            queryItems: [
                URLQueryItem(name: "startAt", value: String(startAt)),
                URLQueryItem(name: "endAt", value: String(endAt))
            ]
        )
        return try decoder.decode([SessionActivity].self, from: data)
    }

    // MARK: - Website Management

    func createWebsite(name: String, domain: String, teamId: String? = nil) async throws -> Website {
        var body: [String: Any] = [
            "name": name,
            "domain": domain
        ]
        if let teamId = teamId {
            body["teamId"] = teamId
        }
        let data = try await postRequest(endpoint: "api/websites", body: body)
        return try decoder.decode(Website.self, from: data)
    }

    func updateWebsite(websiteId: String, name: String? = nil, domain: String? = nil, shareId: String? = nil, clearShareId: Bool = false) async throws -> Website {
        var body: [String: Any] = [:]
        if let name = name { body["name"] = name }
        if let domain = domain { body["domain"] = domain }
        if clearShareId {
            body["shareId"] = NSNull() // Sends null to API to disable share link
        } else if let shareId = shareId {
            body["shareId"] = shareId
        }
        // Note: teamId assignment is not supported via API, use Umami web UI instead

        let data = try await postRequest(endpoint: "api/websites/\(websiteId)", body: body)
        return try decoder.decode(Website.self, from: data)
    }

    func deleteWebsite(websiteId: String) async throws {
        _ = try await deleteRequest(endpoint: "api/websites/\(websiteId)")
    }

    func resetWebsiteStats(websiteId: String) async throws {
        _ = try await postRequest(endpoint: "api/websites/\(websiteId)/reset", body: [:])
    }

    // MARK: - Teams

    func getTeams() async throws -> [Team] {
        let data = try await request(endpoint: "api/admin/teams")
        let response = try decoder.decode(TeamsResponse.self, from: data)
        return response.data
    }

    func createTeam(name: String) async throws -> Team {
        let body: [String: Any] = ["name": name]
        let data = try await postRequest(endpoint: "api/teams", body: body)

        // API returns array with [Team, TeamMembership] - parse manually since they have different structures
        if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
           let teamJson = jsonArray.first,
           let id = teamJson["id"] as? String,
           let teamName = teamJson["name"] as? String {
            let accessCode = teamJson["accessCode"] as? String
            var createdAt: Date?
            if let dateString = teamJson["createdAt"] as? String {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                createdAt = formatter.date(from: dateString)
            }
            return Team(
                id: id,
                name: teamName,
                accessCode: accessCode,
                createdAt: createdAt,
                members: nil
            )
        }

        // Try to decode as single object
        if let teamResponse = try? decoder.decode(TeamCreateResponse.self, from: data) {
            return Team(
                id: teamResponse.id,
                name: teamResponse.name,
                accessCode: teamResponse.accessCode,
                createdAt: teamResponse.createdAt,
                members: nil
            )
        }

        // Debug output for troubleshooting
        #if DEBUG
        if let jsonString = String(data: data, encoding: .utf8) {
            print("Team create response: \(jsonString)")
        }
        #endif

        throw APIError.invalidResponse
    }

    func deleteTeam(teamId: String) async throws {
        _ = try await deleteRequest(endpoint: "api/teams/\(teamId)")
    }

    func getTeamMembers(teamId: String) async throws -> [TeamMember] {
        let data = try await request(endpoint: "api/teams/\(teamId)/users")
        let response = try decoder.decode(TeamMembersResponse.self, from: data)
        return response.data
    }

    func addTeamMember(teamId: String, userId: String, role: String = "team-member") async throws -> TeamMember {
        let body: [String: Any] = ["userId": userId, "role": role]
        let data = try await postRequest(endpoint: "api/teams/\(teamId)/users", body: body)
        return try decoder.decode(TeamMember.self, from: data)
    }

    func removeTeamMember(teamId: String, userId: String) async throws {
        _ = try await deleteRequest(endpoint: "api/teams/\(teamId)/users/\(userId)")
    }

    // MARK: - Users (Admin)

    func getUsers() async throws -> [UmamiUser] {
        let data = try await request(endpoint: "api/admin/users")
        let response = try decoder.decode(UsersResponse.self, from: data)
        return response.data
    }

    func createUser(username: String, password: String, role: String = "user") async throws -> UmamiUser {
        let body: [String: Any] = [
            "username": username,
            "password": password,
            "role": role
        ]
        let data = try await postRequest(endpoint: "api/users", body: body)
        return try decoder.decode(UmamiUser.self, from: data)
    }

    func deleteUser(userId: String) async throws {
        _ = try await deleteRequest(endpoint: "api/users/\(userId)")
    }

    // MARK: - Journey Report

    func getJourneyReport(websiteId: String, dateRange: DateRange, steps: Int = 5) async throws -> [JourneyPath] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dates = dateRange.dates

        let body: [String: Any] = [
            "websiteId": websiteId,
            "type": "journey",
            "filters": [:],
            "parameters": [
                "startDate": formatter.string(from: dates.start),
                "endDate": formatter.string(from: dates.end),
                "steps": steps
            ]
        ]

        let data = try await postRequest(endpoint: "api/reports/journey", body: body)
        return try decoder.decode([JourneyPath].self, from: data)
    }

    // MARK: - Reports

    func getRetention(websiteId: String, dateRange: DateRange) async throws -> [RetentionRow] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let dates = dateRange.dates

        let body: [String: Any] = [
            "websiteId": websiteId,
            "type": "retention",
            "filters": [:],
            "parameters": [
                "startDate": formatter.string(from: dates.start),
                "endDate": formatter.string(from: dates.end)
            ]
        ]

        let data = try await postRequest(endpoint: "api/reports/retention", body: body)
        return try decoder.decode([RetentionRow].self, from: data)
    }

    func getMetrics(websiteId: String, dateRange: DateRange, type: MetricType, limit: Int = 10) async throws -> [MetricItem] {
        let dates = dateRange.dates
        let startAt = Int(dates.start.timeIntervalSince1970 * 1000)
        let endAt = Int(dates.end.timeIntervalSince1970 * 1000)

        let data = try await request(
            endpoint: "api/websites/\(websiteId)/metrics",
            queryItems: [
                URLQueryItem(name: "startAt", value: String(startAt)),
                URLQueryItem(name: "endAt", value: String(endAt)),
                URLQueryItem(name: "type", value: type.rawValue),
                URLQueryItem(name: "unit", value: dateRange.unit),
                URLQueryItem(name: "limit", value: String(limit))
            ]
        )
        return try decoder.decode([MetricItem].self, from: data)
    }

    // MARK: - Private

    private func request(endpoint: String, queryItems: [URLQueryItem] = []) async throws -> Data {
        guard let baseURL = _baseURL, let token = _token else {
            throw APIError.notConfigured
        }

        guard var components = URLComponents(url: baseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: true) else {
            throw APIError.invalidURL
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            throw APIError.serverError(httpResponse.statusCode)
        }

        return data
    }

    private func postRequest(endpoint: String, body: [String: Any]) async throws -> Data {
        guard let baseURL = _baseURL, let token = _token else {
            throw APIError.notConfigured
        }

        let url = baseURL.appendingPathComponent(endpoint)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            throw APIError.serverError(httpResponse.statusCode)
        }

        return data
    }

    private func deleteRequest(endpoint: String) async throws -> Data {
        guard let baseURL = _baseURL, let token = _token else {
            throw APIError.notConfigured
        }

        let url = baseURL.appendingPathComponent(endpoint)

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            throw APIError.serverError(httpResponse.statusCode)
        }

        return data
    }
}

enum APIError: LocalizedError, Sendable {
    case notConfigured
    case invalidURL
    case invalidResponse
    case authenticationFailed
    case unauthorized
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "API ist nicht konfiguriert"
        case .invalidURL:
            return "Ungültige URL"
        case .invalidResponse:
            return "Ungültige Server-Antwort"
        case .authenticationFailed:
            return "Anmeldung fehlgeschlagen"
        case .unauthorized:
            return "Nicht autorisiert"
        case .serverError(let code):
            return "Server-Fehler (\(code))"
        }
    }
}
