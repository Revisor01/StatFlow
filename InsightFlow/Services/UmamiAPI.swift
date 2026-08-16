import Foundation
import os

actor UmamiAPI: AnalyticsProvider {
    static let shared = UmamiAPI()

    private var _baseURL: URL?
    private var _token: String?

    /// Active filters set by the ViewModel — applied to all data-fetching calls.
    var activeFilters: [PlausibleQueryFilter] = []

    func setFilters(_ filters: [PlausibleQueryFilter]) {
        activeFilters = filters
    }

    /// Zeitzone des Geräts — muss mitgesendet werden, damit Umami dieselbe
    /// Tages-/Stundeneinteilung verwendet wie das Widget.
    private var timezoneQueryItem: URLQueryItem {
        URLQueryItem(name: "timezone", value: TimeZone.current.identifier)
    }

    /// Segment-UUID, die an alle Datenabfragen angehängt wird (v3).
    var activeSegmentId: String?

    /// Cohort-UUID, die an alle Datenabfragen angehängt wird (v3).
    var activeCohortId: String?

    /// Verknüpfung mehrerer Filter: `all` (UND) oder `any` (ODER).
    var filterMatch: UmamiFilterMatch?

    /// Nur Sessions ohne Bounce berücksichtigen (v3-Parameter `excludeBounce`).
    var excludeBounce: Bool = false

    func setSegment(_ segmentId: String?) {
        activeSegmentId = segmentId
    }

    func setCohort(_ cohortId: String?) {
        activeCohortId = cohortId
    }

    func setFilterMatch(_ match: UmamiFilterMatch?) {
        filterMatch = match
    }

    func setExcludeBounce(_ exclude: Bool) {
        excludeBounce = exclude
    }

    /// Convert active filters to Umami URL query parameters.
    ///
    /// Umami v3 kodiert Operator und Werte im Wert selbst: `<operator>.<value>`,
    /// wobei `eq`/`neq` mehrere Werte kommasepariert entgegennehmen. Mehrere
    /// Filter auf derselben Dimension bekommen einen numerischen Suffix
    /// (`path`, `path2`, …), den Umami serverseitig wieder abschneidet.
    /// Zusätzlich hängen wir hier segment/cohort/match/excludeBounce an.
    private var filterQueryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        var seen: [String: Int] = [:]

        for filter in activeFilters {
            guard let dimension = Self.umamiFilterName(for: filter.dimension) else { continue }
            guard !filter.values.isEmpty else { continue }

            let op = Self.umamiOperator(for: filter.operator_)
            let encodedValue: String
            if op == "eq" || op == "neq" {
                // Gleichheitsoperatoren akzeptieren eine Werteliste.
                encodedValue = "\(op).\(filter.values.joined(separator: ","))"
            } else {
                encodedValue = "\(op).\(filter.values[0])"
            }

            let count = (seen[dimension] ?? 0) + 1
            seen[dimension] = count
            // Der erste Filter je Dimension bleibt unsuffigiert.
            let name = count == 1 ? dimension : "\(dimension)\(count)"
            items.append(URLQueryItem(name: name, value: encodedValue))
        }

        if let activeSegmentId {
            items.append(URLQueryItem(name: "segment", value: activeSegmentId))
        }
        if let activeCohortId {
            items.append(URLQueryItem(name: "cohort", value: activeCohortId))
        }
        if let filterMatch {
            items.append(URLQueryItem(name: "match", value: filterMatch.rawValue))
        }
        if excludeBounce {
            items.append(URLQueryItem(name: "excludeBounce", value: "true"))
        }

        return items
    }

    /// Erlaubte Filterspalten laut `filterParams` in Umami v3.
    /// Alles andere verwirft der Server ohnehin, daher hier filtern.
    private static let umamiFilterNames: Set<String> = [
        "path", "referrer", "title", "query", "os", "browser", "device",
        "country", "region", "city", "tag", "hostname", "distinctId",
        "language", "event", "utmSource", "utmMedium", "utmCampaign",
        "utmContent", "utmTerm"
    ]

    /// Mappt die Dimensionsnamen des geteilten PlausibleQueryFilter-Typs auf
    /// Umami-Spalten. Bereits umami-konforme Namen kommen unverändert durch.
    private static func umamiFilterName(for dimension: String) -> String? {
        if umamiFilterNames.contains(dimension) { return dimension }

        let mapping: [String: String] = [
            "visit:source": "referrer",
            "visit:referrer": "referrer",
            "visit:country": "country",
            "visit:region": "region",
            "visit:city": "city",
            "visit:device": "device",
            "visit:browser": "browser",
            "visit:os": "os",
            "visit:utm_source": "utmSource",
            "visit:utm_medium": "utmMedium",
            "visit:utm_campaign": "utmCampaign",
            "visit:utm_content": "utmContent",
            "visit:utm_term": "utmTerm",
            "event:page": "path",
            "event:name": "event",
            "event:hostname": "hostname",
            "event:props:title": "title"
        ]
        return mapping[dimension]
    }

    /// Übersetzt die Plausible-Operatoren in Umamis Kurzform (`OPERATORS`).
    private static func umamiOperator(for op: PlausibleFilterOperator) -> String {
        switch op {
        case .is_: return "eq"
        case .isNot: return "neq"
        case .contains: return "c"
        case .doesNotContain: return "dnc"
        case .matches, .matchesWildcard: return "re"
        case .matchesNot, .matchesWildcardNot: return "nre"
        }
    }

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
    func reconfigureFromKeychain() {
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

        // Dieser Weg kennt keine Rückfrage beim Nutzer. Verlangt der Server einen
        // zweiten Faktor, muss die Anmeldung über die Login-Ansicht laufen.
        guard case .token(let token) = try await login(
            baseURL: url,
            username: username,
            password: password
        ) else {
            throw APIError.twoFactorRequired
        }

        // Save credentials
        try KeychainService.save(serverURL, for: .serverURL)
        try KeychainService.save(token, for: .token)
        try KeychainService.save(username, for: .username)
        try KeychainService.save(AnalyticsProviderType.umami.rawValue, for: .providerType)

        await configure(baseURL: url, token: token)
    }

    // MARK: - AnalyticsProvider - Websites

    func getAnalyticsWebsites() async throws -> [AnalyticsWebsite] {
        let websites = try await getAllAccessibleWebsites()
        return websites.map { website in
            AnalyticsWebsite(
                id: website.id,
                name: website.name,
                domain: website.domain ?? website.name,
                shareId: website.shareId,
                provider: .umami,
                teamName: website.teamName
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

    func getRegions(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem] {
        let items = try await getMetrics(websiteId: websiteId, dateRange: dateRange, type: .region)
        return items.map { AnalyticsMetricItem(name: $0.name, value: $0.y) }
    }

    func getCities(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem] {
        let items = try await getMetrics(websiteId: websiteId, dateRange: dateRange, type: .city)
        return items.map { AnalyticsMetricItem(name: $0.name, value: $0.y) }
    }

    func getPageTitles(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem] {
        let items = try await getMetrics(websiteId: websiteId, dateRange: dateRange, type: .title, limit: 50)
        return items.map { AnalyticsMetricItem(name: $0.name, value: $0.y) }
    }

    func getLanguages(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem] {
        let items = try await getMetrics(websiteId: websiteId, dateRange: dateRange, type: .language)
        return items.map { AnalyticsMetricItem(name: $0.name, value: $0.y) }
    }

    func getScreens(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem] {
        let items = try await getMetrics(websiteId: websiteId, dateRange: dateRange, type: .screen)
        return items.map { AnalyticsMetricItem(name: $0.name, value: $0.y) }
    }

    func getEvents(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem] {
        let items = try await getMetrics(websiteId: websiteId, dateRange: dateRange, type: .event)
        return items.map { AnalyticsMetricItem(name: $0.name, value: $0.y) }
    }

    func getRealtimeTopPages(websiteId: String, limit: Int = 10) async throws -> [AnalyticsMetricItem] {
        let items = try await getMetrics(websiteId: websiteId, dateRange: .today, type: .path, limit: limit)
        return items.map { AnalyticsMetricItem(name: $0.name, value: $0.y) }
    }

    func getRealtimeCountries(websiteId: String, limit: Int = 10) async throws -> [AnalyticsMetricItem] {
        let items = try await getMetrics(websiteId: websiteId, dateRange: .today, type: .country, limit: limit)
        return items.map { AnalyticsMetricItem(name: $0.name, value: $0.y) }
    }

    func getRealtimePageviews(websiteId: String) async throws -> Int {
        return try await getActiveVisitors(websiteId: websiteId)
    }

    // MARK: - Authentication

    /// Ergebnis eines Login-Versuchs. Ab Umami 3.3 kann `api/auth/login` mit
    /// Status 200 antworten, ohne ein Token zu liefern: Ist für den Benutzer
    /// Zwei-Faktor-Authentifizierung aktiv, kommt stattdessen ein kurzlebiger
    /// `partialToken`, der über `api/2fa/verify` gegen das echte Token
    /// eingetauscht wird.
    enum LoginResult: Sendable {
        case token(String)
        case twoFactorRequired(partialToken: String)
    }

    nonisolated func login(baseURL: URL, username: String, password: String) async throws -> LoginResult {
        let loginURL = baseURL.appendingPathComponent("api/auth/login")

        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        // Umami Cloud expects "email" instead of "username" in the login body.
        // Self-hosted Umami accepts both. Send both fields to be compatible with either.
        let body = ["username": username, "email": username, "password": password]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.authenticationFailed
        }

        struct LoginResponse: Codable {
            let token: String?
            let requiresTwoFactor: Bool?
            let partialToken: String?
            let user: User?

            struct User: Codable {
                let id: String?
                let username: String?
            }
        }

        let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)

        if let token = loginResponse.token {
            return .token(token)
        }

        if loginResponse.requiresTwoFactor == true, let partialToken = loginResponse.partialToken {
            return .twoFactorRequired(partialToken: partialToken)
        }

        throw APIError.invalidResponse
    }

    /// Schließt einen Login ab, für den Umami Zwei-Faktor-Authentifizierung
    /// verlangt hat. Erwartet entweder einen sechsstelligen TOTP-Code oder
    /// einen Backup-Code. `POST api/2fa/verify` (ab Umami 3.3).
    nonisolated func verifyTwoFactor(
        baseURL: URL,
        partialToken: String,
        code: String,
        isBackupCode: Bool = false
    ) async throws -> String {
        let verifyURL = baseURL.appendingPathComponent("api/2fa/verify")

        var request = URLRequest(url: verifyURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(partialToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        // Das Schema akzeptiert exakt eines der beiden Felder, keine Kombination.
        let body = isBackupCode ? ["backupCode": code] : ["token": code]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // Umami meldet einen falschen Code mit 400 und eine Sperre nach zu
        // vielen Fehlversuchen mit 429 — beide mit eigenem Fehlercode.
        guard httpResponse.statusCode == 200 else {
            struct ErrorResponse: Codable {
                struct Body: Codable {
                    let code: String?
                    let lockedUntil: Double?
                }
                let error: Body?
            }

            let parsed = try? JSONDecoder().decode(ErrorResponse.self, from: data)

            if httpResponse.statusCode == 429 {
                throw APIError.twoFactorLocked(until: parsed?.error?.lockedUntil)
            }

            switch parsed?.error?.code {
            case "two-factor-error-invalid-code",
                 "two-factor-error-invalid-backup-code",
                 "two-factor-error-code-used":
                throw APIError.twoFactorInvalidCode
            default:
                throw APIError.authenticationFailed
            }
        }

        struct VerifyResponse: Codable {
            let token: String
        }

        return try JSONDecoder().decode(VerifyResponse.self, from: data).token
    }

    // MARK: - Websites

    func getWebsites() async throws -> [Website] {
        let data = try await request(endpoint: "api/websites")
        let response = try decoder.decode(WebsiteResponse.self, from: data)
        return response.websites
    }

    /// Alle Websites, auf die das Konto Zugriff hat: eigene und solche aus
    /// Teams, in denen es Mitglied ist.
    ///
    /// Teams sind erst ab Umami 3.0 abrufbar. Schlägt der Team-Abruf fehl —
    /// ältere Instanz, fehlende Berechtigung, Netzwerkfehler —, liefert die
    /// Methode die persönlichen Websites zurück, statt die Übersicht ganz
    /// leer zu lassen.
    func getAllAccessibleWebsites() async throws -> [Website] {
        let personal = try await getWebsites()

        let teams: [Team]
        do {
            teams = try await getMyTeams()
        } catch {
            return personal
        }

        guard !teams.isEmpty else { return personal }

        // Websites der Teams parallel laden; ein einzelnes fehlschlagendes Team
        // darf die übrigen nicht mitreißen.
        var teamWebsites: [Website] = []
        await withTaskGroup(of: [Website].self) { group in
            for team in teams {
                group.addTask {
                    guard let sites = try? await self.getTeamWebsites(teamId: team.id) else {
                        return []
                    }
                    return sites.map { site in
                        var tagged = site
                        tagged.teamName = team.name
                        return tagged
                    }
                }
            }

            for await sites in group {
                teamWebsites.append(contentsOf: sites)
            }
        }

        return Self.merge(personal: personal, teamWebsites: teamWebsites)
    }

    /// Führt persönliche und Team-Websites zusammen. Eigene haben Vorrang:
    /// Taucht dieselbe ID doppelt auf, bleibt die persönliche Fassung ohne
    /// Team-Kennzeichnung stehen. Auch innerhalb der Team-Liste kann eine
    /// Website mehrfach vorkommen, wenn man in mehreren Teams ist.
    static func merge(personal: [Website], teamWebsites: [Website]) -> [Website] {
        var seen = Set(personal.map(\.id))
        var combined = personal

        for site in teamWebsites where !seen.contains(site.id) {
            seen.insert(site.id)
            combined.append(site)
        }

        return combined
    }

    func getWebsite(websiteId: String) async throws -> Website {
        let data = try await request(endpoint: "api/websites/\(websiteId)")
        return try decoder.decode(Website.self, from: data)
    }

    // MARK: - Teams

    /// Teams, in denen das angemeldete Konto Mitglied ist. `api/admin/teams`
    /// bleibt Administratoren vorbehalten; für gewöhnliche Konten ist
    /// `api/me/teams` der richtige Weg (ab Umami 3.0).
    func getMyTeams() async throws -> [Team] {
        try await fetchAllPages(endpoint: "api/me/teams") { data in
            try self.decoder.decode(TeamsResponse.self, from: data).data
        }
    }

    /// Websites eines Teams. Anders als `api/me/websites?includeTeams=1` — das
    /// nur Websites von Teams liefert, in denen man Eigentümer oder Verwalter
    /// ist — genügt hier jede Mitgliedschaft, auch „nur lesen".
    func getTeamWebsites(teamId: String) async throws -> [Website] {
        try await fetchAllPages(endpoint: "api/teams/\(teamId)/websites") { data in
            try self.decoder.decode(WebsiteResponse.self, from: data).websites
        }
    }

    /// Holt alle Seiten einer paginierten Liste. Ohne `pageSize` liefert Umami
    /// nur 20 Einträge — bei größeren Teams fehlten sonst Websites.
    private func fetchAllPages<T>(
        endpoint: String,
        pageSize: Int = 100,
        decode: @escaping (Data) throws -> [T]
    ) async throws -> [T] {
        var all: [T] = []
        var page = 1

        // Obergrenze als Reißleine: Ein Server, der immer volle Seiten liefert,
        // darf die App nicht endlos beschäftigen.
        while page <= 50 {
            let data = try await request(
                endpoint: endpoint,
                queryItems: [
                    URLQueryItem(name: "page", value: String(page)),
                    URLQueryItem(name: "pageSize", value: String(pageSize)),
                ]
            )

            let items = try decode(data)
            all.append(contentsOf: items)

            if items.count < pageSize { break }
            page += 1
        }

        return all
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
                URLQueryItem(name: "endAt", value: String(endAt)),
                timezoneQueryItem
            ] + filterQueryItems
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
                URLQueryItem(name: "unit", value: dateRange.unit),
                timezoneQueryItem
            ] + filterQueryItems
        )
        return try decoder.decode(PageviewsData.self, from: data)
    }

    func getRealtime(websiteId: String) async throws -> RealtimeData {
        let data = try await request(endpoint: "api/realtime/\(websiteId)")
        return try decoder.decode(RealtimeData.self, from: data)
    }

    /// Maximale Anzahl Websites pro Batch-Charts-Anfrage (Server-Limit).
    static let batchChartsLimit = 20

    /// Ergebnis einer Batch-Charts-Abfrage.
    struct BatchCharts: Sendable {
        /// Verlaufsdaten je Website-ID.
        let charts: [String: [AnalyticsChartPoint]]
        /// `true`, wenn der Server die angefragte Auflösung geliefert hat.
        /// Server ohne `unit`-Unterstützung antworten weiterhin mit
        /// 12-Stunden-Blöcken; dann sind die Werte für Stunden- oder
        /// Tagesauflösung nicht verwendbar.
        let honoredUnit: Bool
    }

    /// Holt die Verlaufsdaten mehrerer Websites in einer einzigen Anfrage.
    /// `GET api/websites/charts` (ab Umami 3.3).
    ///
    /// Ohne `unit` bucketiert der Server fest in 12-Stunden-Blöcken. Umami
    /// wertet `unit` an dieser Route bislang nicht aus; Server, die den
    /// Parameter kennen, liefern die angefragte Auflösung. Ob das der Fall ist,
    /// lässt sich nur an der Anzahl der Werte erkennen — deshalb `honoredUnit`.
    ///
    /// Gezählt werden Sitzungen, nicht Seitenaufrufe.
    func getWebsiteListCharts(
        websiteIds: [String],
        dateRange: DateRange
    ) async throws -> BatchCharts {
        guard !websiteIds.isEmpty else { return BatchCharts(charts: [:], honoredUnit: false) }

        let dates = dateRange.dates
        let startAt = Int(dates.start.timeIntervalSince1970 * 1000)
        let endAt = Int(dates.end.timeIntervalSince1970 * 1000)
        let unit = dateRange.unit

        // Sekunden je Bucket der angefragten Auflösung. Monate sind ungleich
        // lang; dort wird der Startzeitpunkt kalendarisch bestimmt.
        let stepSeconds: Double = unit == "hour" ? 3600 : 86400

        // So viele Werte müssen zurückkommen, damit die Auflösung stimmt.
        let expected = Self.expectedBucketCount(dateRange: dateRange)

        var result: [String: [AnalyticsChartPoint]] = [:]
        var honored = true

        // Der Server nimmt höchstens 20 IDs entgegen; größere Listen werden
        // in Blöcken abgefragt.
        for chunk in stride(from: 0, to: websiteIds.count, by: Self.batchChartsLimit).map({
            Array(websiteIds[$0..<min($0 + Self.batchChartsLimit, websiteIds.count)])
        }) {
            let data = try await request(
                endpoint: "api/websites/charts",
                queryItems: [
                    URLQueryItem(name: "ids", value: chunk.joined(separator: ",")),
                    URLQueryItem(name: "startAt", value: String(startAt)),
                    URLQueryItem(name: "endAt", value: String(endAt)),
                    URLQueryItem(name: "unit", value: unit),
                    timezoneQueryItem
                ]
            )

            struct ChartsResponse: Codable {
                struct Entry: Codable {
                    let values: [Int]
                    let total: Int
                }
                let data: [String: Entry]
            }

            let response = try decoder.decode(ChartsResponse.self, from: data)

            for (websiteId, entry) in response.data {
                // Weicht die Anzahl deutlich ab, hat der Server `unit` ignoriert
                // und in 12-Stunden-Blöcken geantwortet.
                if let expected, abs(entry.values.count - expected) > 1 {
                    honored = false
                }

                result[websiteId] = entry.values.enumerated().map { index, value in
                    let date: Date
                    if unit == "month" {
                        date = Calendar.current.date(
                            byAdding: .month, value: index, to: dates.start
                        ) ?? dates.start
                    } else {
                        date = dates.start.addingTimeInterval(Double(index) * stepSeconds)
                    }
                    return AnalyticsChartPoint(date: date, value: value)
                }
            }
        }

        return BatchCharts(charts: result, honoredUnit: honored)
    }

    /// Erwartete Anzahl Buckets für die Auflösung des Zeitraums, oder `nil`,
    /// wenn sie sich nicht sinnvoll vorhersagen lässt (Monatsauflösung).
    static func expectedBucketCount(dateRange: DateRange) -> Int? {
        let dates = dateRange.dates
        let span = dates.end.timeIntervalSince(dates.start)

        switch dateRange.unit {
        case "hour":
            return max(1, Int(ceil(span / 3600)))
        case "day":
            return max(1, Int(ceil(span / 86400)))
        default:
            return nil
        }
    }

    // MARK: - Events

    func getEventsDetail(websiteId: String, dateRange: DateRange, page: Int = 1, pageSize: Int = 20) async throws -> EventsResponse {
        let dates = dateRange.dates
        let startAt = Int(dates.start.timeIntervalSince1970 * 1000)
        let endAt = Int(dates.end.timeIntervalSince1970 * 1000)

        let data = try await request(
            endpoint: "api/websites/\(websiteId)/events",
            queryItems: [
                URLQueryItem(name: "startAt", value: String(startAt)),
                URLQueryItem(name: "endAt", value: String(endAt)),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "pageSize", value: String(pageSize))
            ]
        )
        return try decoder.decode(EventsResponse.self, from: data)
    }

    func getEventsStats(websiteId: String, dateRange: DateRange) async throws -> EventStatsResponse {
        let dates = dateRange.dates
        let startAt = Int(dates.start.timeIntervalSince1970 * 1000)
        let endAt = Int(dates.end.timeIntervalSince1970 * 1000)

        let data = try await request(
            endpoint: "api/websites/\(websiteId)/event-data/stats",
            queryItems: [
                URLQueryItem(name: "startAt", value: String(startAt)),
                URLQueryItem(name: "endAt", value: String(endAt))
            ]
        )
        return try decoder.decode(EventStatsResponse.self, from: data)
    }

    /// Ereignis-Kennzahlen mit Vorperiodenvergleich.
    /// Achtung: Die Nutzdaten liegen bei diesem Endpunkt unter `data`.
    func getEventMetricStats(websiteId: String, dateRange: DateRange) async throws -> UmamiEventStats {
        let dates = dateRange.dates
        let startAt = Int(dates.start.timeIntervalSince1970 * 1000)
        let endAt = Int(dates.end.timeIntervalSince1970 * 1000)

        let data = try await request(
            endpoint: "api/websites/\(websiteId)/events/stats",
            queryItems: [
                URLQueryItem(name: "startAt", value: String(startAt)),
                URLQueryItem(name: "endAt", value: String(endAt)),
                timezoneQueryItem
            ] + filterQueryItems
        )
        return try decoder.decode(UmamiEventStatsResponse.self, from: data).data
    }

    /// Ereignisse im Zeitverlauf. `timezone` ist hier Pflicht — ohne den
    /// Parameter antwortet der Server mit 400. `unit` ist optional.
    func getEventSeries(websiteId: String, dateRange: DateRange, unit: String? = nil) async throws -> [UmamiEventSeriesPoint] {
        let dates = dateRange.dates
        let startAt = Int(dates.start.timeIntervalSince1970 * 1000)
        let endAt = Int(dates.end.timeIntervalSince1970 * 1000)

        var queryItems = [
            URLQueryItem(name: "startAt", value: String(startAt)),
            URLQueryItem(name: "endAt", value: String(endAt)),
            timezoneQueryItem
        ]
        // Ohne Angabe die zum Zeitraum passende Auflösung verwenden.
        queryItems.append(URLQueryItem(name: "unit", value: unit ?? dateRange.unit))

        let data = try await request(
            endpoint: "api/websites/\(websiteId)/events/series",
            queryItems: queryItems + filterQueryItems
        )
        return try decoder.decode([UmamiEventSeriesPoint].self, from: data)
    }

    // MARK: - Werte je Feld

    /// Werteliste eines Feldes mit Häufigkeit — für Filter-Vorschläge.
    func getFieldValues(websiteId: String, dateRange: DateRange, field: UmamiValueField) async throws -> [UmamiFieldValue] {
        let dates = dateRange.dates
        let startAt = Int(dates.start.timeIntervalSince1970 * 1000)
        let endAt = Int(dates.end.timeIntervalSince1970 * 1000)

        let data = try await request(
            endpoint: "api/websites/\(websiteId)/values",
            queryItems: [
                URLQueryItem(name: "startAt", value: String(startAt)),
                URLQueryItem(name: "endAt", value: String(endAt)),
                URLQueryItem(name: "type", value: field.rawValue),
                timezoneQueryItem
            ] + filterQueryItems
        )
        return try decoder.decode([UmamiFieldValue].self, from: data)
    }

    // MARK: - Verfügbarer Datenzeitraum

    /// Zeitraum, für den überhaupt Daten vorliegen. Kennt keine Zeitraum-
    /// oder Filterparameter.
    func getDataDateRange(websiteId: String) async throws -> UmamiDataDateRange {
        let data = try await request(endpoint: "api/websites/\(websiteId)/daterange")
        let response = try decoder.decode(DateRangeResponse.self, from: data)
        return UmamiDataDateRange(from: response)
    }

    // MARK: - Event Data

    func getEventDataFields(websiteId: String, dateRange: DateRange, eventName: String? = nil) async throws -> [EventDataField] {
        let dates = dateRange.dates
        let startAt = Int(dates.start.timeIntervalSince1970 * 1000)
        let endAt = Int(dates.end.timeIntervalSince1970 * 1000)

        var queryItems = [
            URLQueryItem(name: "startAt", value: String(startAt)),
            URLQueryItem(name: "endAt", value: String(endAt))
        ]
        // Scope to a single event so only that event's properties come back.
        // Umami's route expects the query param `event`.
        if let eventName {
            queryItems.append(URLQueryItem(name: "event", value: eventName))
        }

        let data = try await request(
            endpoint: "api/websites/\(websiteId)/event-data/fields",
            queryItems: queryItems
        )
        // The fields endpoint returns { propertyName, dataType, total } — no `value` field.
        return try decoder.decode([EventDataField].self, from: data)
    }

    func getEventDataValues(websiteId: String, dateRange: DateRange, eventName: String, propertyName: String) async throws -> [EventDataValue] {
        let dates = dateRange.dates
        let startAt = Int(dates.start.timeIntervalSince1970 * 1000)
        let endAt = Int(dates.end.timeIntervalSince1970 * 1000)

        let data = try await request(
            endpoint: "api/websites/\(websiteId)/event-data/values",
            queryItems: [
                URLQueryItem(name: "startAt", value: String(startAt)),
                URLQueryItem(name: "endAt", value: String(endAt)),
                // Umami's route expects the query param `event`, not `eventName`.
                URLQueryItem(name: "event", value: eventName),
                URLQueryItem(name: "propertyName", value: propertyName)
            ]
        )
        return try decoder.decode([EventDataValue].self, from: data)
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

    func getSession(websiteId: String, sessionId: String) async throws -> Session {
        let data = try await request(endpoint: "api/websites/\(websiteId)/sessions/\(sessionId)")
        return try decoder.decode(Session.self, from: data)
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
        if let jsonString = String(data: data, encoding: .utf8) {
            Logger.api.debug("Team create response: \(jsonString)")
        }

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

    /// Format date as ISO8601 for report parameters — Umami requires full timestamps, not yyyy-MM-dd
    private func isoDate(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }

    func getJourneyReport(websiteId: String, dateRange: DateRange, steps: Int = 5) async throws -> [JourneyPath] {
        let dates = dateRange.dates

        let body: [String: Any] = [
            "websiteId": websiteId,
            "type": "journey",
            "filters": [:],
            "parameters": [
                "startDate": isoDate(dates.start),
                "endDate": isoDate(dates.end),
                "steps": steps
            ]
        ]

        let data = try await postRequest(endpoint: "api/reports/journey", body: body)
        return try decoder.decode([JourneyPath].self, from: data)
    }

    // MARK: - Reports

    func getRetention(websiteId: String, dateRange: DateRange) async throws -> [RetentionRow] {
        let dates = dateRange.dates

        let body: [String: Any] = [
            "websiteId": websiteId,
            "type": "retention",
            "filters": [:],
            "parameters": [
                "startDate": isoDate(dates.start),
                "endDate": isoDate(dates.end)
            ]
        ]

        let data = try await postRequest(endpoint: "api/reports/retention", body: body)
        return try decoder.decode([RetentionRow].self, from: data)
    }

    func getReports(websiteId: String, page: Int = 1, pageSize: Int = 20) async throws -> ReportListResponse {
        let data = try await request(
            endpoint: "api/reports",
            queryItems: [
                URLQueryItem(name: "websiteId", value: websiteId),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "pageSize", value: String(pageSize))
            ]
        )
        return try decoder.decode(ReportListResponse.self, from: data)
    }

    func getFunnelReport(websiteId: String, dateRange: DateRange, steps: [[String: String]], window: Int = 60) async throws -> [FunnelStep] {
        let dates = dateRange.dates

        let body: [String: Any] = [
            "websiteId": websiteId,
            "type": "funnel",
            "filters": [:],
            "parameters": [
                "startDate": isoDate(dates.start),
                "endDate": isoDate(dates.end),
                "steps": steps,
                "window": window
            ]
        ]

        let data = try await postRequest(endpoint: "api/reports/funnel", body: body)
        if let jsonString = String(data: data, encoding: .utf8) {
            Logger.api.debug("getFunnelReport: \(jsonString.prefix(500))")
        }
        return try decoder.decode([FunnelStep].self, from: data)
    }

    func getUTMReport(websiteId: String, dateRange: DateRange) async throws -> [UTMReportItem] {
        // Umami stores UTM data in query metrics — parse utm_ params from query strings
        let queryMetrics = try await getMetrics(websiteId: websiteId, dateRange: dateRange, type: .query, limit: 100)

        // Umami returns one query-metric row per distinct query string, so two
        // URLs that share the same UTM tags but differ in other params (e.g. gclid,
        // or a different utm_content) arrive as separate rows. Aggregate by the full
        // UTM tuple and sum visitors, otherwise the same campaign shows up as
        // seemingly duplicate entries.
        var aggregated: [String: UTMReportItem] = [:]
        for metric in queryMetrics {
            let query = metric.name
            guard query.contains("utm_") else { continue }

            // Parse query string into UTM components
            let components = URLComponents(string: "?\(query)")
            let params = components?.queryItems ?? []

            let source = params.first(where: { $0.name == "utm_source" })?.value
            let medium = params.first(where: { $0.name == "utm_medium" })?.value
            let campaign = params.first(where: { $0.name == "utm_campaign" })?.value
            let content = params.first(where: { $0.name == "utm_content" })?.value
            let term = params.first(where: { $0.name == "utm_term" })?.value

            // Key on the full UTM tuple so only genuine duplicates are merged.
            let key = [source, medium, campaign, content, term]
                .map { $0 ?? "" }
                .joined(separator: "|")

            if let existing = aggregated[key] {
                aggregated[key] = UTMReportItem(
                    source: existing.source,
                    medium: existing.medium,
                    campaign: existing.campaign,
                    content: existing.content,
                    term: existing.term,
                    visitors: existing.visitors + metric.value
                )
            } else {
                aggregated[key] = UTMReportItem(
                    source: source,
                    medium: medium,
                    campaign: campaign,
                    content: content,
                    term: term,
                    visitors: metric.value
                )
            }
        }

        let items = Array(aggregated.values)
        Logger.api.debug("getUTMReport: parsed \(items.count) aggregated UTM entries from query metrics")
        return items
    }

    func getGoalReport(websiteId: String, dateRange: DateRange, goalType: String, goalValue: String) async throws -> GoalReportResult {
        let dates = dateRange.dates

        let body: [String: Any] = [
            "websiteId": websiteId,
            "type": "goal",
            "filters": [:],
            "parameters": [
                "startDate": isoDate(dates.start),
                "endDate": isoDate(dates.end),
                "type": goalType,
                "value": goalValue
            ]
        ]

        let data = try await postRequest(endpoint: "api/reports/goal", body: body)
        if let jsonString = String(data: data, encoding: .utf8) {
            Logger.api.debug("getGoalReport(\(goalType):\(goalValue)): \(jsonString.prefix(500))")
        }
        return try decoder.decode(GoalReportResult.self, from: data)
    }

    func getAttributionReport(websiteId: String, dateRange: DateRange, model: String = "last-click", type: String = "path", step: String = "/") async throws -> [AttributionItem] {
        let dates = dateRange.dates

        let body: [String: Any] = [
            "websiteId": websiteId,
            "type": "attribution",
            "filters": [:],
            "parameters": [
                "startDate": isoDate(dates.start),
                "endDate": isoDate(dates.end),
                "model": model,
                "type": type,
                "step": step
            ]
        ]

        let data = try await postRequest(endpoint: "api/reports/attribution", body: body)
        let response = try decoder.decode(AttributionResponse.self, from: data)

        // Attribution covers referrers, paid ads and all UTM dimensions the
        // server returns. Previously only referrer/paidAds were mapped, so sites
        // driven mainly by UTM-tagged campaigns showed an empty report.
        var items: [AttributionItem] = []
        func append(_ entries: [AttributionEntry]?, category: String, kind: AttributionItem.Kind) {
            for entry in entries ?? [] {
                items.append(AttributionItem(category: category, kind: kind, name: entry.name, count: entry.value))
            }
        }
        append(response.referrer, category: String(localized: "attribution.category.referrer"), kind: .referrer)
        append(response.paidAds, category: String(localized: "attribution.category.paidAds"), kind: .paidAds)
        append(response.utm_source, category: String(localized: "attribution.category.utmSource"), kind: .utm)
        append(response.utm_medium, category: String(localized: "attribution.category.utmMedium"), kind: .utm)
        append(response.utm_campaign, category: String(localized: "attribution.category.utmCampaign"), kind: .utm)
        append(response.utm_content, category: String(localized: "attribution.category.utmContent"), kind: .utm)
        append(response.utm_term, category: String(localized: "attribution.category.utmTerm"), kind: .utm)

        return items
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
                URLQueryItem(name: "limit", value: String(limit)),
                timezoneQueryItem
            ] + filterQueryItems
        )
        if let jsonString = String(data: data, encoding: .utf8) {
            Logger.api.debug("getMetrics(\(type.rawValue)): \(jsonString.prefix(500))")
        }
        return try decoder.decode([MetricItem].self, from: data)
    }

    // MARK: - Segments (v3)

    /// Segmente bzw. Cohorts einer Website. `type` ist serverseitig Pflicht.
    func getSegments(websiteId: String, type: UmamiSegmentType = .segment, search: String? = nil) async throws -> [UmamiSegment] {
        var queryItems = [URLQueryItem(name: "type", value: type.rawValue)]
        if let search, !search.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }

        let data = try await request(
            endpoint: "api/websites/\(websiteId)/segments",
            queryItems: queryItems
        )
        // Umamis pagedQuery liefert einen Envelope; ältere Builds ein nacktes Array.
        if let response = try? decoder.decode(UmamiSegmentsResponse.self, from: data) {
            return response.data
        }
        return try decoder.decode([UmamiSegment].self, from: data)
    }

    func getCohorts(websiteId: String, search: String? = nil) async throws -> [UmamiSegment] {
        try await getSegments(websiteId: websiteId, type: .cohort, search: search)
    }

    // MARK: - Performance / Web Vitals (v3)

    /// POST `api/reports/performance`. Das Schema verlangt startDate/endDate als
    /// ISO-Zeitstempel; `metric` steuert nur die Zeitreihe, `summary` enthält
    /// immer alle fünf Vitals.
    func getPerformanceReport(
        websiteId: String,
        dateRange: DateRange,
        metric: UmamiWebVitalMetric = .lcp
    ) async throws -> UmamiPerformanceReport {
        let dates = dateRange.dates

        let body: [String: Any] = [
            "websiteId": websiteId,
            "type": "performance",
            "filters": umamiFilterBody(dateRange: dateRange),
            "parameters": [
                "startDate": isoDate(dates.start),
                "endDate": isoDate(dates.end),
                "unit": dateRange.unit,
                "timezone": TimeZone.current.identifier,
                "metric": metric.rawValue
            ]
        ]

        let data = try await postRequest(endpoint: "api/reports/performance", body: body)
        return try decoder.decode(UmamiPerformanceReport.self, from: data)
    }

    // MARK: - Revenue (v3)

    /// GET `api/websites/{id}/revenue/stats` — inkl. Vergleichszeitraum.
    /// `currency` ist Pflicht und wird serverseitig auf Großschreibung normalisiert.
    func getRevenueStats(
        websiteId: String,
        dateRange: DateRange,
        currency: String,
        compare: UmamiCompareMode? = nil
    ) async throws -> UmamiRevenueStats {
        let dates = dateRange.dates
        let startAt = Int(dates.start.timeIntervalSince1970 * 1000)
        let endAt = Int(dates.end.timeIntervalSince1970 * 1000)

        var queryItems = [
            URLQueryItem(name: "startAt", value: String(startAt)),
            URLQueryItem(name: "endAt", value: String(endAt)),
            URLQueryItem(name: "currency", value: currency.uppercased()),
            timezoneQueryItem
        ]
        if let compare {
            queryItems.append(URLQueryItem(name: "compare", value: compare.rawValue))
        }

        let data = try await request(
            endpoint: "api/websites/\(websiteId)/revenue/stats",
            queryItems: queryItems + filterQueryItems
        )
        return try decoder.decode(UmamiRevenueStats.self, from: data)
    }

    /// GET `api/websites/{id}/revenue/chart` → `{ "chart": [...] }`.
    func getRevenueChart(
        websiteId: String,
        dateRange: DateRange,
        currency: String
    ) async throws -> [UmamiRevenueChartPoint] {
        let dates = dateRange.dates
        let startAt = Int(dates.start.timeIntervalSince1970 * 1000)
        let endAt = Int(dates.end.timeIntervalSince1970 * 1000)

        let data = try await request(
            endpoint: "api/websites/\(websiteId)/revenue/chart",
            queryItems: [
                URLQueryItem(name: "startAt", value: String(startAt)),
                URLQueryItem(name: "endAt", value: String(endAt)),
                URLQueryItem(name: "currency", value: currency.uppercased()),
                URLQueryItem(name: "unit", value: dateRange.unit),
                timezoneQueryItem
            ] + filterQueryItems
        )
        return try decoder.decode(UmamiRevenueChartResponse.self, from: data).chart
    }

    // MARK: - Session Stats (v3)

    /// GET `api/websites/{id}/sessions/stats`.
    func getSessionStats(websiteId: String, dateRange: DateRange) async throws -> UmamiSessionStats {
        let dates = dateRange.dates
        let startAt = Int(dates.start.timeIntervalSince1970 * 1000)
        let endAt = Int(dates.end.timeIntervalSince1970 * 1000)

        let data = try await request(
            endpoint: "api/websites/\(websiteId)/sessions/stats",
            queryItems: [
                URLQueryItem(name: "startAt", value: String(startAt)),
                URLQueryItem(name: "endAt", value: String(endAt)),
                // Ohne Zeitzone rechnet Umami in UTC — die Kennzahlen würden
                // dann nicht zur Heatmap derselben Ansicht passen.
                timezoneQueryItem
            ] + filterQueryItems
        )
        return try decoder.decode(UmamiSessionStats.self, from: data)
    }

    /// GET `api/websites/{id}/sessions/weekly` — 7×24-Matrix (Tag × Stunde).
    func getWeeklyTraffic(websiteId: String, dateRange: DateRange) async throws -> UmamiWeeklyTraffic {
        let dates = dateRange.dates
        let startAt = Int(dates.start.timeIntervalSince1970 * 1000)
        let endAt = Int(dates.end.timeIntervalSince1970 * 1000)

        let data = try await request(
            endpoint: "api/websites/\(websiteId)/sessions/weekly",
            queryItems: [
                URLQueryItem(name: "startAt", value: String(startAt)),
                URLQueryItem(name: "endAt", value: String(endAt)),
                timezoneQueryItem
            ] + filterQueryItems
        )
        return UmamiWeeklyTraffic(days: try decoder.decode([[Int]].self, from: data))
    }

    // MARK: - Private

    /// Filter-Objekt für POST-Reports. Report-Endpunkte erwarten die Filter im
    /// Body statt in der Query, das Wertformat ist aber dasselbe.
    /// - Parameter dateRange: Umami löst den Filter serverseitig über
    ///   `getQueryFilters` auf und liest den Zeitraum dabei aus dem Filter-Objekt
    ///   selbst. Ohne `startAt`/`endAt` bleibt er dort undefiniert, wodurch
    ///   Segment- und Cohort-Filter nicht zuverlässig greifen.
    private func umamiFilterBody(dateRange: DateRange? = nil) -> [String: Any] {
        var body: [String: Any] = [:]
        for item in filterQueryItems {
            body[item.name] = item.value
        }
        if let dateRange {
            let dates = dateRange.dates
            body["startAt"] = Int(dates.start.timeIntervalSince1970 * 1000)
            body["endAt"] = Int(dates.end.timeIntervalSince1970 * 1000)
            body["timezone"] = TimeZone.current.identifier
        }
        return body
    }

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

/// Verknüpfung mehrerer Filter (`match`-Parameter in Umami v3).
enum UmamiFilterMatch: String, Sendable, CaseIterable {
    case all
    case any
}

/// Vergleichszeitraum (`compare`-Parameter in Umami v3).
enum UmamiCompareMode: String, Sendable, CaseIterable {
    /// Unmittelbar vorangehender Zeitraum gleicher Länge.
    case previous = "prev"
    /// Gleicher Zeitraum im Vorjahr.
    case yearOverYear = "yoy"
}

enum APIError: LocalizedError, Sendable {
    case notConfigured
    case invalidURL
    case invalidResponse
    case authenticationFailed
    case unauthorized
    case serverError(Int)
    case twoFactorInvalidCode
    case twoFactorLocked(until: Double?)
    case twoFactorRequired

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
        case .twoFactorInvalidCode:
            return "Der Bestätigungscode ist ungültig"
        case .twoFactorLocked:
            return "Zu viele Fehlversuche. Bitte später erneut versuchen."
        case .twoFactorRequired:
            return "Für dieses Konto ist eine Bestätigung in zwei Schritten aktiv. Bitte über die Anmeldemaske anmelden."
        }
    }
}
