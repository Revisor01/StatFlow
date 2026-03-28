//
//  PrivacyFlowWidget.swift
//  PrivacyFlowWidget
//

import WidgetKit
import SwiftUI
import AppIntents
import CryptoKit

// MARK: - Debug

private func widgetLog(_ message: String) {
    print("[Widget] \(message)")
}

// MARK: - Credentials

enum WidgetProviderType: String, Codable {
    case umami
    case plausible
}

// MARK: - Widget Account (stored in App Group)

struct WidgetAccount: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let serverURL: String
    private let providerTypeRaw: String
    let token: String
    let sites: [String]?

    var providerType: WidgetProviderType {
        WidgetProviderType(rawValue: providerTypeRaw) ?? .umami
    }

    var displayName: String {
        if name.isEmpty {
            return serverURL
                .replacingOccurrences(of: "https://", with: "")
                .replacingOccurrences(of: "http://", with: "")
        }
        return name
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // Manual initializer for creating from legacy credentials
    init(id: String, name: String, serverURL: String, providerType: WidgetProviderType, token: String, sites: [String]?) {
        self.id = id
        self.name = name
        self.serverURL = serverURL
        self.providerTypeRaw = providerType.rawValue
        self.token = token
        self.sites = sites
    }

    enum CodingKeys: String, CodingKey {
        case id, name, serverURL, token, sites
        case providerTypeRaw = "providerType"
    }
}

struct WidgetAccountsStorage {
    private static let appGroupID = "group.de.godsapp.PrivacyFlow"
    private static let fileName = "widget_accounts.encrypted"
    private static let legacyFileName = "widget_accounts.json"
    private static let keyFileName = "widget_credentials.key"

    private static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    private static func loadEncryptionKey() -> SymmetricKey? {
        guard let url = containerURL?.appendingPathComponent(keyFileName),
              FileManager.default.fileExists(atPath: url.path),
              let keyData = try? Data(contentsOf: url),
              keyData.count == 32 else {
            return nil
        }
        return SymmetricKey(data: keyData)
    }

    static func loadAccounts() -> [WidgetAccount] {
        guard let containerURL = containerURL else {
            widgetLog("loadAccounts: no container URL")
            return []
        }

        // Versuche verschluesselte Datei zuerst
        let encryptedURL = containerURL.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: encryptedURL.path) {
            do {
                guard let key = loadEncryptionKey() else {
                    widgetLog("loadAccounts: no encryption key, trying legacy")
                    return loadLegacyAccounts(containerURL: containerURL)
                }
                let encryptedData = try Data(contentsOf: encryptedURL)
                let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
                let jsonData = try AES.GCM.open(sealedBox, using: key)
                let accounts = try JSONDecoder().decode([WidgetAccount].self, from: jsonData)
                widgetLog("loadAccounts: loaded \(accounts.count) accounts (encrypted)")
                for acc in accounts {
                    widgetLog("  - \(acc.name): provider=\(acc.providerType), sites=\(acc.sites ?? [])")
                }
                return accounts
            } catch {
                widgetLog("loadAccounts: decrypt error: \(error), trying legacy")
                return loadLegacyAccounts(containerURL: containerURL)
            }
        }

        // Fallback auf Legacy-Plaintext
        return loadLegacyAccounts(containerURL: containerURL)
    }

    /// Legacy-Plaintext laden (fuer Uebergangszeit nach Update)
    private static func loadLegacyAccounts(containerURL: URL) -> [WidgetAccount] {
        let legacyURL = containerURL.appendingPathComponent(legacyFileName)
        guard FileManager.default.fileExists(atPath: legacyURL.path) else {
            widgetLog("loadAccounts: no legacy file, trying legacy credentials")
            if let legacyCreds = WidgetCredentials.load() {
                widgetLog("loadAccounts: using legacy creds, provider=\(legacyCreds.providerType)")
                return [WidgetAccount(
                    id: "legacy",
                    name: "",
                    serverURL: legacyCreds.serverURL,
                    providerType: legacyCreds.providerType,
                    token: legacyCreds.token,
                    sites: legacyCreds.sites
                )]
            }
            return []
        }
        do {
            let data = try Data(contentsOf: legacyURL)
            let accounts = try JSONDecoder().decode([WidgetAccount].self, from: data)
            widgetLog("loadAccounts: loaded \(accounts.count) accounts (legacy plaintext)")
            for acc in accounts {
                widgetLog("  - \(acc.name): provider=\(acc.providerType), sites=\(acc.sites ?? [])")
            }
            return accounts
        } catch {
            widgetLog("loadAccounts: legacy decode error: \(error)")
            if let legacyCreds = WidgetCredentials.load() {
                return [WidgetAccount(
                    id: "legacy",
                    name: "",
                    serverURL: legacyCreds.serverURL,
                    providerType: legacyCreds.providerType,
                    token: legacyCreds.token,
                    sites: legacyCreds.sites
                )]
            }
            return []
        }
    }
}

struct WidgetCredentials {
    private static let appGroupID = "group.de.godsapp.PrivacyFlow"
    private static let fileName = "widget_credentials.encrypted"
    private static let legacyFileName = "widget_credentials.json"
    private static let keyFileName = "widget_credentials.key"

    struct Credentials {
        let serverURL: String
        let token: String
        let providerType: WidgetProviderType
        let websiteId: String?
        let websiteName: String?
        let sites: [String]?  // Plausible sites (domains)
    }

    // MARK: - Encryption Helpers

    private static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    private static func loadEncryptionKey() -> SymmetricKey? {
        guard let url = containerURL?.appendingPathComponent(keyFileName),
              FileManager.default.fileExists(atPath: url.path),
              let keyData = try? Data(contentsOf: url),
              keyData.count == 32 else {
            return nil
        }
        return SymmetricKey(data: keyData)
    }

    private static func decrypt(_ data: Data) throws -> Data {
        guard let key = loadEncryptionKey() else {
            throw DecryptionError.noKey
        }
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }

    enum DecryptionError: Error {
        case noKey
        case decryptionFailed
    }

    static func load() -> Credentials? {
        guard let containerURL = containerURL else {
            return nil
        }

        // Try encrypted file first
        let encryptedURL = containerURL.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: encryptedURL.path) {
            do {
                let encryptedData = try Data(contentsOf: encryptedURL)
                let jsonData = try decrypt(encryptedData)
                guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                      let serverURL = json["serverURL"] as? String,
                      let token = json["token"] as? String else {
                    return nil
                }

                let providerTypeString = json["providerType"] as? String ?? "umami"
                let providerType = WidgetProviderType(rawValue: providerTypeString) ?? .umami
                let websiteId = json["websiteId"] as? String
                let websiteName = json["websiteName"] as? String
                let sites = json["sites"] as? [String]

                return Credentials(
                    serverURL: serverURL,
                    token: token,
                    providerType: providerType,
                    websiteId: websiteId,
                    websiteName: websiteName,
                    sites: sites
                )
            } catch {
                widgetLog("Failed to load encrypted credentials: \(error)")
            }
        }

        // Fallback to legacy unencrypted file (will be migrated by app on next launch)
        let legacyURL = containerURL.appendingPathComponent(legacyFileName)
        guard FileManager.default.fileExists(atPath: legacyURL.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: legacyURL)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let serverURL = json["serverURL"] as? String,
                  let token = json["token"] as? String else {
                return nil
            }

            let providerTypeString = json["providerType"] as? String ?? "umami"
            let providerType = WidgetProviderType(rawValue: providerTypeString) ?? .umami
            let websiteId = json["websiteId"] as? String
            let websiteName = json["websiteName"] as? String
            let sites = json["sites"] as? [String]

            return Credentials(
                serverURL: serverURL,
                token: token,
                providerType: providerType,
                websiteId: websiteId,
                websiteName: websiteName,
                sites: sites
            )
        } catch {
            return nil
        }
    }
}

// MARK: - Time Range Enum

enum WidgetTimeRange: String, CaseIterable, AppEnum {
    case today
    case yesterday
    case last7Days
    case last30Days

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "widget.timerange.type"
    static var caseDisplayRepresentations: [WidgetTimeRange: DisplayRepresentation] = [
        .today: "widget.timerange.today",
        .yesterday: "widget.timerange.yesterday",
        .last7Days: "widget.timerange.last7days",
        .last30Days: "widget.timerange.last30days"
    ]

    var localizedName: String {
        switch self {
        case .today: return String(localized: "widget.timerange.today")
        case .yesterday: return String(localized: "widget.timerange.yesterday")
        case .last7Days: return String(localized: "widget.timerange.last7days")
        case .last30Days: return String(localized: "widget.timerange.last30days")
        }
    }

    var days: Int {
        switch self {
        case .today: return 0
        case .yesterday: return 1
        case .last7Days: return 6
        case .last30Days: return 29
        }
    }

    var unit: String {
        switch self {
        case .today, .yesterday: return "hour"
        default: return "day"
        }
    }
}

// MARK: - Account Entity

struct AccountEntity: AppEntity {
    static let allAccountsId = "__all__"

    let id: String
    let name: String
    let providerType: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "widget.account"
    static var defaultQuery = AccountQuery()

    var displayRepresentation: DisplayRepresentation {
        if id == Self.allAccountsId {
            return DisplayRepresentation(
                title: "\(name)",
                image: .init(systemName: "square.grid.2x2")
            )
        }
        let icon = providerType == "umami" ? "chart.bar.xaxis" : "chart.line.uptrend.xyaxis"
        return DisplayRepresentation(
            title: "\(name)",
            subtitle: providerType == "umami" ? "Umami" : "Plausible",
            image: .init(systemName: icon)
        )
    }

    init(id: String, name: String, providerType: String) {
        self.id = id
        self.name = name
        self.providerType = providerType
    }

    /// "All accounts" option
    static var allAccounts: AccountEntity {
        AccountEntity(id: allAccountsId, name: String(localized: "widget.account.all"), providerType: "")
    }
}

struct AccountQuery: EntityQuery {
    func entities(for identifiers: [AccountEntity.ID]) async throws -> [AccountEntity] {
        var result: [AccountEntity] = []

        // Handle "all" option
        if identifiers.contains(AccountEntity.allAccountsId) {
            result.append(AccountEntity.allAccounts)
        }

        let accounts = WidgetAccountsStorage.loadAccounts()
        result.append(contentsOf: accounts
            .filter { identifiers.contains($0.id) }
            .map { AccountEntity(id: $0.id, name: $0.displayName, providerType: $0.providerType.rawValue) })

        return result
    }

    func suggestedEntities() async throws -> [AccountEntity] {
        var result: [AccountEntity] = [AccountEntity.allAccounts]
        result.append(contentsOf: WidgetAccountsStorage.loadAccounts()
            .map { AccountEntity(id: $0.id, name: $0.displayName, providerType: $0.providerType.rawValue) })
        return result
    }

    func defaultResult() async -> AccountEntity? {
        // Default to "All" option
        return AccountEntity.allAccounts
    }
}

// MARK: - Website Entity

struct WebsiteEntity: AppEntity {
    let id: String
    let name: String
    let accountId: String?
    let providerType: String?  // "umami" or "plausible"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Website"
    static var defaultQuery = WebsiteQuery()

    var displayRepresentation: DisplayRepresentation {
        let providerLabel = providerType == "plausible" ? "Plausible" : "Umami"
        return DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(providerLabel)"
        )
    }

    init(id: String, name: String, accountId: String? = nil, providerType: String? = nil) {
        self.id = id
        self.name = name
        self.accountId = accountId
        self.providerType = providerType
    }
}

struct WebsiteQuery: EntityQuery {
    func entities(for identifiers: [WebsiteEntity.ID]) async throws -> [WebsiteEntity] {
        let all = await fetchAllWebsites()
        return all.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [WebsiteEntity] {
        await fetchAllWebsites()
    }

    func defaultResult() async -> WebsiteEntity? {
        await fetchAllWebsites().first
    }

    /// Fetch websites from ALL accounts (both Umami and Plausible)
    func fetchAllWebsites() async -> [WebsiteEntity] {
        let accounts = WidgetAccountsStorage.loadAccounts()
        widgetLog("WebsiteQuery: fetching websites from \(accounts.count) accounts")

        var allWebsites: [WebsiteEntity] = []

        // If no accounts, try legacy credentials
        if accounts.isEmpty {
            if let creds = WidgetCredentials.load() {
                widgetLog("WebsiteQuery: using legacy credentials, provider=\(creds.providerType)")
                let websites = await fetchWebsitesFromCredentials(creds)
                allWebsites.append(contentsOf: websites)
            }
            return allWebsites
        }

        // Fetch websites from each account
        for account in accounts {
            widgetLog("WebsiteQuery: processing account '\(account.displayName)' (provider=\(account.providerType))")
            let websites = await fetchWebsitesFromAccount(account)
            widgetLog("WebsiteQuery: found \(websites.count) websites from '\(account.displayName)'")
            allWebsites.append(contentsOf: websites)
        }

        widgetLog("WebsiteQuery: total websites found: \(allWebsites.count)")
        return allWebsites
    }

    private func fetchWebsitesFromAccount(_ account: WidgetAccount) async -> [WebsiteEntity] {
        // For Plausible: use locally stored sites
        if account.providerType == .plausible {
            guard let sites = account.sites, !sites.isEmpty else {
                widgetLog("WebsiteQuery: Plausible account '\(account.displayName)' has no sites")
                return []
            }
            widgetLog("WebsiteQuery: Plausible sites: \(sites)")
            return sites.map { WebsiteEntity(id: $0, name: $0, accountId: account.id, providerType: "plausible") }
        }

        // For Umami: fetch from API
        guard let url = URL(string: account.serverURL) else {
            widgetLog("WebsiteQuery: invalid server URL for '\(account.displayName)'")
            return []
        }

        let websitesURL = url.appendingPathComponent("api/websites")
        var request = URLRequest(url: websitesURL)
        request.setValue("Bearer \(account.token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        do {
            let (data, _) = try await URLSession.shared.data(for: request)

            struct WS: Decodable { let id: String; let name: String }
            struct Wrapper: Decodable { let data: [WS] }

            let websites: [WS]
            if let w = try? JSONDecoder().decode(Wrapper.self, from: data) {
                websites = w.data
            } else if let w = try? JSONDecoder().decode([WS].self, from: data) {
                websites = w
            } else {
                widgetLog("WebsiteQuery: failed to decode Umami response for '\(account.displayName)'")
                return []
            }
            return websites.map { WebsiteEntity(id: $0.id, name: $0.name, accountId: account.id, providerType: "umami") }
        } catch {
            widgetLog("WebsiteQuery: Umami API error for '\(account.displayName)': \(error)")
            return []
        }
    }

    private func fetchWebsitesFromCredentials(_ creds: WidgetCredentials.Credentials) async -> [WebsiteEntity] {
        let providerStr = creds.providerType == .plausible ? "plausible" : "umami"

        // For Plausible: use locally stored sites
        if creds.providerType == .plausible {
            guard let sites = creds.sites, !sites.isEmpty else {
                return []
            }
            return sites.map { WebsiteEntity(id: $0, name: $0, accountId: nil, providerType: providerStr) }
        }

        // For Umami: fetch from API
        guard let url = URL(string: creds.serverURL) else {
            return []
        }

        let websitesURL = url.appendingPathComponent("api/websites")
        var request = URLRequest(url: websitesURL)
        request.setValue("Bearer \(creds.token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        do {
            let (data, _) = try await URLSession.shared.data(for: request)

            struct WS: Decodable { let id: String; let name: String }
            struct Wrapper: Decodable { let data: [WS] }

            let websites: [WS]
            if let w = try? JSONDecoder().decode(Wrapper.self, from: data) {
                websites = w.data
            } else if let w = try? JSONDecoder().decode([WS].self, from: data) {
                websites = w
            } else {
                return []
            }
            return websites.map { WebsiteEntity(id: $0.id, name: $0.name, accountId: nil, providerType: providerStr) }
        } catch {
            return []
        }
    }
}

// MARK: - Chart Style Enum

enum WidgetChartStyle: String, CaseIterable, AppEnum {
    case bars
    case line

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Chart Style"
    static var caseDisplayRepresentations: [WidgetChartStyle: DisplayRepresentation] = [
        .bars: "Bars",
        .line: "Line"
    ]
}

// MARK: - Website Options Provider (filtered by account)

struct WebsiteOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [WebsiteEntity] {
        await WebsiteQuery().fetchAllWebsites()
    }
}

// MARK: - Widget Intent

struct ConfigureWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "widget.configure.title"
    static var description = IntentDescription("widget.configure.description")

    @Parameter(title: "widget.configure.account", default: AccountEntity.allAccounts)
    var account: AccountEntity

    @Parameter(title: "widget.configure.website", optionsProvider: FilteredWebsiteOptionsProvider())
    var website: WebsiteEntity?

    @Parameter(title: "widget.timerange.type", default: .last7Days)
    var timeRange: WidgetTimeRange

    @Parameter(title: "Chart Style", default: .bars)
    var chartStyle: WidgetChartStyle
}

/// Provides website options filtered by the selected account
struct FilteredWebsiteOptionsProvider: DynamicOptionsProvider {
    @IntentParameterDependency<ConfigureWidgetIntent>(\.$account)
    var accountDependency

    func results() async throws -> [WebsiteEntity] {
        let allWebsites = await WebsiteQuery().fetchAllWebsites()

        // If "All" is selected or no account dependency, return all websites
        guard let account = accountDependency?.account,
              account.id != AccountEntity.allAccountsId else {
            return allWebsites
        }

        // Filter by selected account
        return allWebsites.filter { $0.accountId == account.id }
    }
}

// MARK: - Widget Cache

/// Einfacher Cache für Widget-Daten, der im App Group Container gespeichert wird
struct WidgetCache {
    private static let appGroupID = "group.de.godsapp.PrivacyFlow"
    private static let cacheFolder = "analytics_cache"

    private static var cacheDirectory: URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }
        let cacheURL = containerURL.appendingPathComponent(cacheFolder)
        if !FileManager.default.fileExists(atPath: cacheURL.path) {
            try? FileManager.default.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        }
        return cacheURL
    }

    private static func cacheKey(websiteId: String, timeRange: WidgetTimeRange) -> String {
        "widget_\(websiteId)_\(timeRange.rawValue)"
    }

    struct CachedWidgetData: Codable {
        let websiteName: String
        let websiteId: String
        let providerType: String
        let visitors: Int
        let pageviews: Int
        let activeVisitors: Int
        let visitorsChange: Int
        let pageviewsChange: Int
        let sparklineData: [Int]
        let timeRange: String
        let cachedAt: Date

        func toWidgetData() -> WidgetData {
            WidgetData(
                websiteName: websiteName,
                websiteId: websiteId,
                providerType: providerType,
                visitors: visitors,
                pageviews: pageviews,
                activeVisitors: activeVisitors,
                visitorsChange: visitorsChange,
                pageviewsChange: pageviewsChange,
                sparklineData: sparklineData,
                timeRange: timeRange,
                isConfigured: true,
                errorMessage: nil
            )
        }
    }

    static func save(_ data: WidgetData, websiteId: String, timeRange: WidgetTimeRange) {
        guard let cacheDir = cacheDirectory, data.errorMessage == nil else { return }

        let cached = CachedWidgetData(
            websiteName: data.websiteName,
            websiteId: data.websiteId ?? websiteId,
            providerType: data.providerType ?? "umami",
            visitors: data.visitors,
            pageviews: data.pageviews,
            activeVisitors: data.activeVisitors,
            visitorsChange: data.visitorsChange,
            pageviewsChange: data.pageviewsChange,
            sparklineData: data.sparklineData,
            timeRange: data.timeRange,
            cachedAt: Date()
        )

        let fileURL = cacheDir.appendingPathComponent("\(cacheKey(websiteId: websiteId, timeRange: timeRange)).json")

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let encoded = try encoder.encode(cached)
            try encoded.write(to: fileURL, options: [.atomic])
            widgetLog("Cache saved for \(websiteId)")
        } catch {
            widgetLog("Cache save error: \(error)")
        }
    }

    static func load(websiteId: String, timeRange: WidgetTimeRange) -> WidgetData? {
        guard let cacheDir = cacheDirectory else { return nil }

        let fileURL = cacheDir.appendingPathComponent("\(cacheKey(websiteId: websiteId, timeRange: timeRange)).json")

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let cached = try decoder.decode(CachedWidgetData.self, from: data)

            // Cache ist maximal 1 Stunde gültig, aber wir geben ihn trotzdem zurück
            // wenn kein Netzwerk verfügbar ist
            widgetLog("Cache loaded for \(websiteId), age: \(Int(Date().timeIntervalSince(cached.cachedAt)))s")
            return cached.toWidgetData()
        } catch {
            widgetLog("Cache load error: \(error)")
            return nil
        }
    }
}

// MARK: - Widget Data

struct WidgetData {
    let websiteName: String
    let websiteId: String?
    let providerType: String?
    let visitors: Int
    let pageviews: Int
    let activeVisitors: Int
    let visitorsChange: Int
    let pageviewsChange: Int
    let sparklineData: [Int]
    let timeRange: String
    let isConfigured: Bool
    let errorMessage: String?

    var deepLinkURL: URL? {
        guard let websiteId = websiteId, let provider = providerType else { return nil }
        return URL(string: "insightflow://website?id=\(websiteId)&provider=\(provider)")
    }

    static let placeholder = WidgetData(
        websiteName: "Website",
        websiteId: nil,
        providerType: nil,
        visitors: 1234,
        pageviews: 5678,
        activeVisitors: 5,
        visitorsChange: 12,
        pageviewsChange: -5,
        sparklineData: [45, 52, 38, 65, 78, 92, 85, 73, 68, 95, 110, 125],
        timeRange: String(localized: "widget.timerange.last7days"),
        isConfigured: true,
        errorMessage: nil
    )

    static let notConfigured = WidgetData(
        websiteName: "",
        websiteId: nil,
        providerType: nil,
        visitors: 0,
        pageviews: 0,
        activeVisitors: 0,
        visitorsChange: 0,
        pageviewsChange: 0,
        sparklineData: [],
        timeRange: "",
        isConfigured: false,
        errorMessage: String(localized: "widget.error.login")
    )

    static let selectWebsite = WidgetData(
        websiteName: "",
        websiteId: nil,
        providerType: nil,
        visitors: 0,
        pageviews: 0,
        activeVisitors: 0,
        visitorsChange: 0,
        pageviewsChange: 0,
        sparklineData: [],
        timeRange: "",
        isConfigured: true,
        errorMessage: String(localized: "widget.error.selectWebsite")
    )

    static func error(_ msg: String) -> WidgetData {
        WidgetData(websiteName: "", websiteId: nil, providerType: nil,
                   visitors: 0, pageviews: 0, activeVisitors: 0,
                   visitorsChange: 0, pageviewsChange: 0, sparklineData: [],
                   timeRange: "", isConfigured: true, errorMessage: msg)
    }
}

// MARK: - Timeline Entry

struct StatsEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
    let configuration: ConfigureWidgetIntent
}

// MARK: - Provider

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> StatsEntry {
        StatsEntry(date: Date(), data: .placeholder, configuration: ConfigureWidgetIntent())
    }

    func snapshot(for configuration: ConfigureWidgetIntent, in context: Context) async -> StatsEntry {
        StatsEntry(date: Date(), data: .placeholder, configuration: configuration)
    }

    func timeline(for configuration: ConfigureWidgetIntent, in context: Context) async -> Timeline<StatsEntry> {
        let data = await fetchStats(config: configuration)
        let now = Date()
        let entry = StatsEntry(date: now, data: data, configuration: configuration)

        // Mehr Einträge für bessere Aktualisierung erzeugen
        var entries: [StatsEntry] = [entry]

        // Zusätzliche Einträge alle 5 Minuten für die nächsten 15 Minuten
        for minutes in stride(from: 5, through: 15, by: 5) {
            if let nextDate = Calendar.current.date(byAdding: .minute, value: minutes, to: now) {
                entries.append(StatsEntry(date: nextDate, data: data, configuration: configuration))
            }
        }

        // Nächste Aktualisierung nach 15 Minuten
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: now)!
        return Timeline(entries: entries, policy: .after(nextRefresh))
    }

    private func fetchStats(config: ConfigureWidgetIntent) async -> WidgetData {
        guard let website = config.website else {
            widgetLog("fetchStats: no website selected")
            return .selectWebsite
        }

        // Versuche zuerst aus dem Cache zu laden (für Offline-Support)
        let cachedData = WidgetCache.load(websiteId: website.id, timeRange: config.timeRange)

        // Try to get credentials - prioritize website's associated account
        // The widget should work independently of the app's currently active account
        let accounts = WidgetAccountsStorage.loadAccounts()
        var creds: WidgetCredentials.Credentials?

        widgetLog("fetchStats: looking for credentials for website '\(website.name)' (accountId=\(website.accountId ?? "nil"))")

        // First priority: Use credentials from the website's associated account
        if let websiteAccountId = website.accountId,
           let account = accounts.first(where: { $0.id == websiteAccountId }) {
            widgetLog("fetchStats: using website's account '\(account.displayName)', provider=\(account.providerType)")
            creds = WidgetCredentials.Credentials(
                serverURL: account.serverURL,
                token: account.token,
                providerType: account.providerType,
                websiteId: nil,
                websiteName: nil,
                sites: account.sites
            )
        }
        // Second priority: Use explicitly configured account in widget settings (if not "All")
        else if config.account.id != AccountEntity.allAccountsId,
                let account = accounts.first(where: { $0.id == config.account.id }) {
            widgetLog("fetchStats: using configured account '\(account.displayName)', provider=\(account.providerType)")
            creds = WidgetCredentials.Credentials(
                serverURL: account.serverURL,
                token: account.token,
                providerType: account.providerType,
                websiteId: nil,
                websiteName: nil,
                sites: account.sites
            )
        }
        // Third priority: Try to find matching account by website ID
        else {
            // For Plausible: website.id is the domain, check if any account has this site
            // For Umami: website.id is UUID, need to find which account owns it
            for account in accounts {
                if account.providerType == .plausible {
                    if let sites = account.sites, sites.contains(website.id) {
                        widgetLog("fetchStats: found Plausible account '\(account.displayName)' containing site '\(website.id)'")
                        creds = WidgetCredentials.Credentials(
                            serverURL: account.serverURL,
                            token: account.token,
                            providerType: account.providerType,
                            websiteId: nil,
                            websiteName: nil,
                            sites: account.sites
                        )
                        break
                    }
                }
            }
        }
        // Last resort: Fall back to legacy credentials
        if creds == nil, let legacyCreds = WidgetCredentials.load() {
            widgetLog("fetchStats: using legacy credentials as fallback, provider=\(legacyCreds.providerType)")
            creds = legacyCreds
        }

        guard let credentials = creds else {
            widgetLog("fetchStats: no credentials found")
            return .notConfigured
        }

        // Validate website ID matches provider type
        // Plausible uses domains (contains "."), Umami uses UUIDs
        let websiteIdLooksLikeDomain = website.id.contains(".")
        let isPlausible = credentials.providerType == .plausible

        var effectiveWebsite = website

        if isPlausible && !websiteIdLooksLikeDomain {
            // Widget configured with Umami website but provider is Plausible
            // Try to use first available Plausible site
            widgetLog("fetchStats: website ID '\(website.id)' doesn't match Plausible provider (expected domain)")
            if let sites = credentials.sites, let firstSite = sites.first {
                widgetLog("fetchStats: falling back to first Plausible site: \(firstSite)")
                effectiveWebsite = WebsiteEntity(id: firstSite, name: firstSite, accountId: website.accountId)
            } else {
                widgetLog("fetchStats: no Plausible sites available")
                return .error(String(localized: "widget.error.reconfigure"))
            }
        } else if !isPlausible && websiteIdLooksLikeDomain {
            // Widget configured with Plausible website but provider is Umami
            widgetLog("fetchStats: website ID '\(website.id)' doesn't match Umami provider (expected UUID)")
            return .error(String(localized: "widget.error.reconfigure"))
        }

        widgetLog("fetchStats: provider=\(credentials.providerType), website=\(effectiveWebsite.id), timeRange=\(config.timeRange.rawValue)")

        // Route to provider-specific implementation
        let result: WidgetData
        if isPlausible {
            result = await fetchPlausibleStats(creds: credentials, website: effectiveWebsite, timeRange: config.timeRange)
        } else {
            result = await fetchUmamiStats(creds: credentials, website: effectiveWebsite, timeRange: config.timeRange)
        }

        // Bei Erfolg: Cache speichern
        if result.errorMessage == nil {
            WidgetCache.save(result, websiteId: effectiveWebsite.id, timeRange: config.timeRange)
            return result
        }

        // Bei Netzwerkfehler: Gecachte Daten zurückgeben falls vorhanden
        if let cached = cachedData {
            widgetLog("fetchStats: returning cached data due to network error")
            return cached
        }

        return result
    }

    // MARK: - Umami Stats

    private func fetchUmamiStats(creds: WidgetCredentials.Credentials, website: WebsiteEntity, timeRange: WidgetTimeRange) async -> WidgetData {
        guard let baseURL = URL(string: creds.serverURL) else {
            return .error(String(localized: "widget.error.invalidURL"))
        }

        let rangeLabel = timeRange.localizedName
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date
        let endDate: Date

        switch timeRange {
        case .today:
            startDate = calendar.startOfDay(for: now)
            endDate = now
        case .yesterday:
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
            startDate = calendar.startOfDay(for: yesterday)
            endDate = calendar.startOfDay(for: now).addingTimeInterval(-1)
        case .last7Days:
            startDate = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))!
            endDate = now
        case .last30Days:
            startDate = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now))!
            endDate = now
        }

        let startAt = Int(startDate.timeIntervalSince1970 * 1000)
        let endAt = Int(endDate.timeIntervalSince1970 * 1000)

        let timezone = TimeZone.current.identifier

        do {
            // Stats
            var statsURL = URLComponents(url: baseURL.appendingPathComponent("api/websites/\(website.id)/stats"), resolvingAgainstBaseURL: false)!
            statsURL.queryItems = [
                URLQueryItem(name: "startAt", value: String(startAt)),
                URLQueryItem(name: "endAt", value: String(endAt)),
                URLQueryItem(name: "timezone", value: timezone)
            ]
            var statsReq = URLRequest(url: statsURL.url!)
            statsReq.setValue("Bearer \(creds.token)", forHTTPHeaderField: "Authorization")
            statsReq.timeoutInterval = 15

            let (statsData, statsResp) = try await URLSession.shared.data(for: statsReq)
            if let http = statsResp as? HTTPURLResponse, http.statusCode == 401 {
                return .error(String(localized: "widget.error.tokenExpired"))
            }

            guard let statsJson = try? JSONSerialization.jsonObject(with: statsData) as? [String: Any] else {
                return .error(String(localized: "widget.error.format"))
            }

            var visitors = 0, pageviews = 0, visitorsChange = 0, pageviewsChange = 0
            var compVisitors = 0, compPageviews = 0

            if let v = statsJson["visitors"] as? Int { visitors = v }
            else if let v = statsJson["visitors"] as? Double { visitors = Int(v) }
            else if let v = statsJson["uniques"] as? Int { visitors = v }
            else if let v = statsJson["uniques"] as? Double { visitors = Int(v) }

            if let v = statsJson["pageviews"] as? Int { pageviews = v }
            else if let v = statsJson["pageviews"] as? Double { pageviews = Int(v) }

            if let comp = statsJson["comparison"] as? [String: Any] {
                if let v = comp["visitors"] as? Int { compVisitors = v }
                else if let v = comp["visitors"] as? Double { compVisitors = Int(v) }
                else if let v = comp["uniques"] as? Int { compVisitors = v }
                else if let v = comp["uniques"] as? Double { compVisitors = Int(v) }

                if let v = comp["pageviews"] as? Int { compPageviews = v }
                else if let v = comp["pageviews"] as? Double { compPageviews = Int(v) }
            }

            let visitorsChangeAbs = visitors - compVisitors
            let pageviewsChangeAbs = pageviews - compPageviews

            if compVisitors > 0 {
                visitorsChange = Int(round(Double(visitorsChangeAbs) / Double(compVisitors) * 100))
            }
            if compPageviews > 0 {
                pageviewsChange = Int(round(Double(pageviewsChangeAbs) / Double(compPageviews) * 100))
            }

            // Sparkline
            var pvURL = URLComponents(url: baseURL.appendingPathComponent("api/websites/\(website.id)/pageviews"), resolvingAgainstBaseURL: false)!
            pvURL.queryItems = [
                URLQueryItem(name: "startAt", value: String(startAt)),
                URLQueryItem(name: "endAt", value: String(endAt)),
                URLQueryItem(name: "unit", value: timeRange.unit),
                URLQueryItem(name: "timezone", value: timezone)
            ]
            var pvReq = URLRequest(url: pvURL.url!)
            pvReq.setValue("Bearer \(creds.token)", forHTTPHeaderField: "Authorization")
            pvReq.timeoutInterval = 15

            var sparkline: [Int] = []
            let isHourlyData = timeRange == .today || timeRange == .yesterday
            if let (pvData, _) = try? await URLSession.shared.data(for: pvReq),
               let pvJson = try? JSONSerialization.jsonObject(with: pvData) as? [String: Any],
               let arr = pvJson["pageviews"] as? [[String: Any]] {
                // Parse data into map by x (timestamp string) AND keep raw data order
                var dataMap: [String: Int] = [:]
                var rawSparklineData: [Int] = []
                for item in arr {
                    if let x = item["x"] as? String, let y = item["y"] as? Int {
                        dataMap[x] = y
                        rawSparklineData.append(y)
                        widgetLog("Umami dataMap entry: '\(x)' = \(y)")
                    }
                }

                widgetLog("Umami sparkline: dataMap count=\(dataMap.count), rawData count=\(rawSparklineData.count)")

                // Generate complete time slots
                let calendar = Calendar.current
                let today = Date()

                // Umami returns dates like "2025-12-17 00:00:00" (space, not T)
                let umamiFormatter = DateFormatter()
                umamiFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

                if isHourlyData {
                    // Hourly: generate all hours
                    let currentHour = calendar.component(.hour, from: today)
                    let maxHour = timeRange == .today ? currentHour : 23

                    let baseDate = timeRange == .today ? today : calendar.date(byAdding: .day, value: -1, to: today)!
                    let startOfDay = calendar.startOfDay(for: baseDate)

                    for hour in 0...maxHour {
                        if let hourDate = calendar.date(byAdding: .hour, value: hour, to: startOfDay) {
                            let umamiStr = umamiFormatter.string(from: hourDate)
                            sparkline.append(dataMap[umamiStr] ?? 0)
                        }
                    }
                } else {
                    // Daily: generate all days
                    let dayCount = timeRange == .last7Days ? 7 : 30

                    for dayOffset in (0..<dayCount).reversed() {
                        if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                            let startOfDay = calendar.startOfDay(for: date)
                            let umamiStr = umamiFormatter.string(from: startOfDay)
                            sparkline.append(dataMap[umamiStr] ?? 0)
                        }
                    }
                }

                widgetLog("Umami sparkline generated: \(sparkline.count) slots, values: \(sparkline)")

                // Fallback: if all generated values are 0 but we have raw data with values, use raw data
                let hasNonZero = sparkline.contains { $0 > 0 }
                if !hasNonZero && !rawSparklineData.isEmpty && rawSparklineData.contains(where: { $0 > 0 }) {
                    widgetLog("Umami: sparkline all zeros, using rawSparklineData: \(rawSparklineData)")
                    sparkline = rawSparklineData
                }
            }

            // Active
            let activeURL = baseURL.appendingPathComponent("api/websites/\(website.id)/active")
            var activeReq = URLRequest(url: activeURL)
            activeReq.setValue("Bearer \(creds.token)", forHTTPHeaderField: "Authorization")
            var active = 0
            if let (activeData, _) = try? await URLSession.shared.data(for: activeReq),
               let activeJson = try? JSONSerialization.jsonObject(with: activeData) as? [String: Any],
               let x = activeJson["x"] as? Int {
                active = x
            }

            widgetLog("Umami returning: visitors=\(visitors), pageviews=\(pageviews), sparkline.count=\(sparkline.count)")

            return WidgetData(
                websiteName: website.name,
                websiteId: website.id,
                providerType: "umami",
                visitors: visitors,
                pageviews: pageviews,
                activeVisitors: active,
                visitorsChange: visitorsChange,
                pageviewsChange: pageviewsChange,
                sparklineData: sparkline,
                timeRange: rangeLabel,
                isConfigured: true,
                errorMessage: nil
            )
        } catch {
            widgetLog("Umami error: \(error)")
            return .error(String(localized: "widget.error.network"))
        }
    }

    // MARK: - Plausible Stats

    private func fetchPlausibleStats(creds: WidgetCredentials.Credentials, website: WebsiteEntity, timeRange: WidgetTimeRange) async -> WidgetData {
        guard let baseURL = URL(string: creds.serverURL) else {
            return .error(String(localized: "widget.error.invalidURL"))
        }

        let rangeLabel = timeRange.localizedName
        let siteId = website.id  // For Plausible, this is the domain
        let calendar = Calendar.current
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        // Build date range for current period and comparison period
        let dateRangeValue: Any  // Can be String or [String]
        let comparisonDateRangeValue: Any

        switch timeRange {
        case .today:
            dateRangeValue = "day"
            // Compare with yesterday - Plausible needs [start, end] array format
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
            let yesterdayStr = formatter.string(from: yesterday)
            comparisonDateRangeValue = [yesterdayStr, yesterdayStr]
        case .yesterday:
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
            let yesterdayStr = formatter.string(from: yesterday)
            dateRangeValue = [yesterdayStr, yesterdayStr]
            // Compare with day before yesterday
            let dayBefore = calendar.date(byAdding: .day, value: -2, to: today)!
            let dayBeforeStr = formatter.string(from: dayBefore)
            comparisonDateRangeValue = [dayBeforeStr, dayBeforeStr]
        case .last7Days:
            dateRangeValue = "7d"
            // Compare with previous 7 days
            let start = calendar.date(byAdding: .day, value: -13, to: today)!
            let end = calendar.date(byAdding: .day, value: -7, to: today)!
            comparisonDateRangeValue = [formatter.string(from: start), formatter.string(from: end)]
        case .last30Days:
            dateRangeValue = "30d"
            // Compare with previous 30 days
            let start = calendar.date(byAdding: .day, value: -59, to: today)!
            let end = calendar.date(byAdding: .day, value: -30, to: today)!
            comparisonDateRangeValue = [formatter.string(from: start), formatter.string(from: end)]
        }

        do {
            let apiURL = baseURL.appendingPathComponent("api/v2/query")

            // Fetch current period stats
            var request = URLRequest(url: apiURL)
            request.httpMethod = "POST"
            request.setValue("Bearer \(creds.token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 15

            let statsBody: [String: Any] = [
                "site_id": siteId,
                "metrics": ["visitors", "pageviews"],
                "date_range": dateRangeValue
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: statsBody)

            let (statsData, statsResp) = try await URLSession.shared.data(for: request)
            if let http = statsResp as? HTTPURLResponse, http.statusCode == 401 {
                return .error(String(localized: "widget.error.tokenExpired"))
            }

            guard let statsJson = try? JSONSerialization.jsonObject(with: statsData) as? [String: Any],
                  let results = statsJson["results"] as? [[String: Any]],
                  let firstResult = results.first,
                  let metrics = firstResult["metrics"] as? [Any] else {
                widgetLog("Plausible stats parse failed")
                return .error(String(localized: "widget.error.format"))
            }

            var visitors = 0, pageviews = 0
            if metrics.count > 0 {
                if let v = metrics[0] as? Int { visitors = v }
                else if let v = metrics[0] as? Double { visitors = Int(v) }
            }
            if metrics.count > 1 {
                if let v = metrics[1] as? Int { pageviews = v }
                else if let v = metrics[1] as? Double { pageviews = Int(v) }
            }

            // Fetch comparison period stats
            var compVisitors = 0, compPageviews = 0
            let compBody: [String: Any] = [
                "site_id": siteId,
                "metrics": ["visitors", "pageviews"],
                "date_range": comparisonDateRangeValue
            ]

            var compRequest = URLRequest(url: apiURL)
            compRequest.httpMethod = "POST"
            compRequest.setValue("Bearer \(creds.token)", forHTTPHeaderField: "Authorization")
            compRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            compRequest.httpBody = try JSONSerialization.data(withJSONObject: compBody)
            compRequest.timeoutInterval = 15

            if let (compData, _) = try? await URLSession.shared.data(for: compRequest),
               let compJson = try? JSONSerialization.jsonObject(with: compData) as? [String: Any],
               let compResults = compJson["results"] as? [[String: Any]],
               let compFirst = compResults.first,
               let compMetrics = compFirst["metrics"] as? [Any] {
                if compMetrics.count > 0 {
                    if let v = compMetrics[0] as? Int { compVisitors = v }
                    else if let v = compMetrics[0] as? Double { compVisitors = Int(v) }
                }
                if compMetrics.count > 1 {
                    if let v = compMetrics[1] as? Int { compPageviews = v }
                    else if let v = compMetrics[1] as? Double { compPageviews = Int(v) }
                }
            }

            // Calculate percentage change
            var visitorsChange = 0, pageviewsChange = 0
            if compVisitors > 0 {
                visitorsChange = Int(round(Double(visitors - compVisitors) / Double(compVisitors) * 100))
            }
            if compPageviews > 0 {
                pageviewsChange = Int(round(Double(pageviews - compPageviews) / Double(compPageviews) * 100))
            }

            // Fetch timeseries for sparkline
            var sparkline: [Int] = []
            let isShortRange = timeRange == .today || timeRange == .yesterday
            let timeDimension = isShortRange ? "time:hour" : "time:day"

            let timeseriesBody: [String: Any] = [
                "site_id": siteId,
                "metrics": ["pageviews"],
                "date_range": dateRangeValue,
                "dimensions": [timeDimension]
            ]

            var timeseriesRequest = URLRequest(url: apiURL)
            timeseriesRequest.httpMethod = "POST"
            timeseriesRequest.setValue("Bearer \(creds.token)", forHTTPHeaderField: "Authorization")
            timeseriesRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            timeseriesRequest.httpBody = try JSONSerialization.data(withJSONObject: timeseriesBody)
            timeseriesRequest.timeoutInterval = 15

            // Parse timeseries and fill in missing slots
            var timeseriesMap: [String: Int] = [:]
            var rawSparkline: [Int] = []

            if let (tsData, _) = try? await URLSession.shared.data(for: timeseriesRequest),
               let tsJson = try? JSONSerialization.jsonObject(with: tsData) as? [String: Any],
               let tsResults = tsJson["results"] as? [[String: Any]] {
                widgetLog("Plausible timeseries results count: \(tsResults.count)")
                for result in tsResults {
                    if let dimensions = result["dimensions"] as? [String], !dimensions.isEmpty,
                       let tsMetrics = result["metrics"] as? [Any], !tsMetrics.isEmpty {
                        let timeKey = dimensions[0]
                        var value = 0
                        if let v = tsMetrics[0] as? Int { value = v }
                        else if let v = tsMetrics[0] as? Double { value = Int(v) }
                        timeseriesMap[timeKey] = value
                        rawSparkline.append(value)
                        widgetLog("Plausible timeseries: \(timeKey) = \(value)")
                    }
                }
            }

            widgetLog("Plausible timeseriesMap count: \(timeseriesMap.count), rawSparkline count: \(rawSparkline.count)")

            // Generate complete time slots with 0 for missing values
            if isShortRange {
                // Hourly data: 0-23 for yesterday, 0-currentHour for today
                let currentHour = calendar.component(.hour, from: today)
                let maxHour = timeRange == .today ? currentHour : 23

                // Determine base date for generating timestamps
                let baseDate = timeRange == .today ? today : calendar.date(byAdding: .day, value: -1, to: today)!
                let startOfDay = calendar.startOfDay(for: baseDate)

                // Try multiple hour formats that Plausible might return
                for hour in 0...maxHour {
                    var value = 0

                    // Format 1: Full datetime "2025-12-17 00:00:00"
                    if let hourDate = calendar.date(byAdding: .hour, value: hour, to: startOfDay) {
                        let fullDateStr = "\(formatter.string(from: hourDate)) \(String(format: "%02d", hour)):00:00"
                        if let v = timeseriesMap[fullDateStr] {
                            value = v
                        }
                    }

                    // Format 2: Just time "HH:00:00"
                    if value == 0 {
                        let hourStr1 = String(format: "%02d:00:00", hour)
                        if let v = timeseriesMap[hourStr1] {
                            value = v
                        }
                    }

                    // Format 3: Just time "H:00:00"
                    if value == 0 {
                        let hourStr2 = "\(hour):00:00"
                        if let v = timeseriesMap[hourStr2] {
                            value = v
                        }
                    }

                    sparkline.append(value)
                }
                widgetLog("Plausible hourly sparkline (\(sparkline.count) slots): \(sparkline)")

                // Fallback: if all zeros but we have raw data, use raw data
                if !sparkline.contains(where: { $0 > 0 }) && rawSparkline.contains(where: { $0 > 0 }) {
                    widgetLog("Plausible: hourly sparkline all zeros, using rawSparkline: \(rawSparkline)")
                    sparkline = rawSparkline
                }
            } else {
                // Daily data: generate all days in range
                let dayCount = timeRange == .last7Days ? 7 : 30
                for dayOffset in (0..<dayCount).reversed() {
                    if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                        let dateStr = formatter.string(from: date)
                        let value = timeseriesMap[dateStr] ?? 0
                        sparkline.append(value)
                    }
                }
                widgetLog("Plausible daily sparkline (\(sparkline.count) slots): \(sparkline)")
            }

            // Fallback: only use raw data if sparkline generation failed completely
            if sparkline.isEmpty && !rawSparkline.isEmpty {
                widgetLog("Plausible: using rawSparkline as fallback (sparkline was empty)")
                sparkline = rawSparkline
            }

            // Fetch active visitors (realtime) using v1 API - works with all Plausible CE versions
            var active = 0
            var realtimeComponents = URLComponents(url: baseURL.appendingPathComponent("api/v1/stats/realtime/visitors"), resolvingAgainstBaseURL: false)!
            realtimeComponents.queryItems = [URLQueryItem(name: "site_id", value: siteId)]

            var realtimeRequest = URLRequest(url: realtimeComponents.url!)
            realtimeRequest.setValue("Bearer \(creds.token)", forHTTPHeaderField: "Authorization")
            realtimeRequest.timeoutInterval = 10

            if let (rtData, _) = try? await URLSession.shared.data(for: realtimeRequest),
               let rtString = String(data: rtData, encoding: .utf8),
               let rtCount = Int(rtString) {
                active = rtCount
            }

            widgetLog("Plausible returning: visitors=\(visitors), pageviews=\(pageviews), sparkline.count=\(sparkline.count)")

            return WidgetData(
                websiteName: website.name,
                websiteId: website.id,
                providerType: "plausible",
                visitors: visitors,
                pageviews: pageviews,
                activeVisitors: active,
                visitorsChange: visitorsChange,
                pageviewsChange: pageviewsChange,
                sparklineData: sparkline,
                timeRange: rangeLabel,
                isConfigured: true,
                errorMessage: nil
            )
        } catch {
            widgetLog("Plausible error: \(error)")
            return .error(String(localized: "widget.error.network"))
        }
    }
}

// MARK: - Bar Chart View

struct BarChartView: View {
    let data: [Int]
    let color: Color
    let timeRange: String
    let showYScale: Bool
    let showXScale: Bool

    init(data: [Int], color: Color = .blue, timeRange: String = "", showYScale: Bool = false, showXScale: Bool = false) {
        self.data = data
        self.color = color
        self.timeRange = timeRange
        self.showYScale = showYScale
        self.showXScale = showXScale
    }

    private var xLabels: [String] {
        let count = data.count
        guard count >= 2 else { return [] }

        let todayLabel = String(localized: "widget.timerange.today")
        let yesterdayLabel = String(localized: "widget.timerange.yesterday")
        let last7DaysLabel = String(localized: "widget.timerange.last7days")
        let isHourly = timeRange == todayLabel || timeRange == yesterdayLabel
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        let today = Date()
        let calendar = Calendar.current

        if isHourly {
            let currentHour = calendar.component(.hour, from: today)
            if timeRange == todayLabel {
                let midHour = currentHour / 2
                return ["0h", "\(midHour)h", "\(currentHour)h"]
            } else {
                return ["0h", "12h", "24h"]
            }
        } else if timeRange == last7DaysLabel {
            var labels: [String] = []
            for i in [0, 3, 6] {
                if let date = calendar.date(byAdding: .day, value: -(6-i), to: today) {
                    formatter.dateFormat = "d. MMM"
                    labels.append(formatter.string(from: date))
                }
            }
            return labels
        } else {
            var labels: [String] = []
            for i in [0, 14, 29] {
                if let date = calendar.date(byAdding: .day, value: -(29-i), to: today) {
                    formatter.dateFormat = "d. MMM"
                    labels.append(formatter.string(from: date))
                }
            }
            return labels
        }
    }

    private var hasData: Bool {
        data.contains { $0 > 0 }
    }

    var body: some View {
        GeometryReader { geometry in
            let maxVal = max(data.max() ?? 1, 1)

            let yScaleWidth: CGFloat = showYScale ? 24 : 0
            let xScaleHeight: CGFloat = showXScale ? 12 : 0
            let graphWidth = geometry.size.width - yScaleWidth
            let graphHeight = geometry.size.height - xScaleHeight

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    // Y-Achse
                    if showYScale {
                        VStack {
                            Text("\(maxVal)")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("0")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: yScaleWidth, height: graphHeight)
                    }

                    // Bar Chart
                    if !data.isEmpty && hasData {
                        let barCount = CGFloat(data.count)
                        let totalSpacing = CGFloat(data.count - 1) * 1 // spacing: 1
                        let barWidth = max((graphWidth - totalSpacing) / barCount, 2)

                        HStack(alignment: .bottom, spacing: 1) {
                            ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                                let barHeight = graphHeight * CGFloat(value) / CGFloat(maxVal)
                                let isLast = index == data.count - 1

                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(
                                        LinearGradient(
                                            colors: [color, color.opacity(0.6)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: barWidth, height: max(barHeight, 2))
                                    .overlay(
                                        isLast ?
                                        RoundedRectangle(cornerRadius: 1.5)
                                            .stroke(color, lineWidth: 1)
                                        : nil
                                    )
                            }
                        }
                        .frame(width: graphWidth, height: graphHeight, alignment: .bottom)
                    } else {
                        // Keine Daten: zeige Baseline
                        VStack {
                            Spacer()
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                        }
                        .frame(width: graphWidth, height: graphHeight)
                    }
                }

                // X-Achse
                if showXScale {
                    HStack {
                        if showYScale {
                            Spacer().frame(width: yScaleWidth)
                        }
                        HStack {
                            ForEach(Array(xLabels.enumerated()), id: \.offset) { _, label in
                                if label != xLabels.first {
                                    Spacer()
                                }
                                Text(label)
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: graphWidth)
                    }
                    .frame(height: xScaleHeight)
                }
            }
        }
    }
}

// MARK: - Line Chart View

struct LineChartView: View {
    let data: [Int]
    let color: Color
    let timeRange: String
    let showYScale: Bool
    let showXScale: Bool

    init(data: [Int], color: Color = .blue, timeRange: String = "", showYScale: Bool = false, showXScale: Bool = false) {
        self.data = data
        self.color = color
        self.timeRange = timeRange
        self.showYScale = showYScale
        self.showXScale = showXScale
    }

    private var xLabels: [String] {
        let count = data.count
        guard count >= 2 else { return [] }

        let todayLabel = String(localized: "widget.timerange.today")
        let yesterdayLabel = String(localized: "widget.timerange.yesterday")
        let last7DaysLabel = String(localized: "widget.timerange.last7days")
        let isHourly = timeRange == todayLabel || timeRange == yesterdayLabel
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        let today = Date()
        let calendar = Calendar.current

        if isHourly {
            let currentHour = calendar.component(.hour, from: today)
            if timeRange == todayLabel {
                let midHour = currentHour / 2
                return ["0h", "\(midHour)h", "\(currentHour)h"]
            } else {
                return ["0h", "12h", "24h"]
            }
        } else if timeRange == last7DaysLabel {
            var labels: [String] = []
            for i in [0, 3, 6] {
                if let date = calendar.date(byAdding: .day, value: -(6-i), to: today) {
                    formatter.dateFormat = "d. MMM"
                    labels.append(formatter.string(from: date))
                }
            }
            return labels
        } else {
            var labels: [String] = []
            for i in [0, 14, 29] {
                if let date = calendar.date(byAdding: .day, value: -(29-i), to: today) {
                    formatter.dateFormat = "d. MMM"
                    labels.append(formatter.string(from: date))
                }
            }
            return labels
        }
    }

    private var hasData: Bool {
        data.contains { $0 > 0 }
    }

    var body: some View {
        GeometryReader { geometry in
            let maxVal = max(data.max() ?? 1, 1)

            let yScaleWidth: CGFloat = showYScale ? 24 : 0
            let xScaleHeight: CGFloat = showXScale ? 12 : 0
            let graphWidth = geometry.size.width - yScaleWidth
            let graphHeight = geometry.size.height - xScaleHeight

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    // Y-Achse
                    if showYScale {
                        VStack {
                            Text("\(maxVal)")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("0")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: yScaleWidth, height: graphHeight)
                    }

                    // Line Chart
                    if !data.isEmpty && hasData {
                        let points = data.enumerated().map { index, value -> CGPoint in
                            let x = graphWidth * CGFloat(index) / CGFloat(max(data.count - 1, 1))
                            let y = graphHeight - (graphHeight * CGFloat(value) / CGFloat(maxVal))
                            return CGPoint(x: x, y: y)
                        }

                        ZStack {
                            // Fill area under curved line
                            Path { path in
                                guard points.count > 1 else { return }
                                path.move(to: CGPoint(x: points[0].x, y: graphHeight))
                                path.addLine(to: points[0])

                                for i in 1..<points.count {
                                    let p0 = points[i - 1]
                                    let p1 = points[i]
                                    let midX = (p0.x + p1.x) / 2

                                    path.addCurve(
                                        to: p1,
                                        control1: CGPoint(x: midX, y: p0.y),
                                        control2: CGPoint(x: midX, y: p1.y)
                                    )
                                }

                                path.addLine(to: CGPoint(x: points.last!.x, y: graphHeight))
                                path.closeSubpath()
                            }
                            .fill(
                                LinearGradient(
                                    colors: [color.opacity(0.3), color.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                            // Curved Line
                            Path { path in
                                guard points.count > 1 else { return }
                                path.move(to: points[0])

                                for i in 1..<points.count {
                                    let p0 = points[i - 1]
                                    let p1 = points[i]
                                    let midX = (p0.x + p1.x) / 2

                                    path.addCurve(
                                        to: p1,
                                        control1: CGPoint(x: midX, y: p0.y),
                                        control2: CGPoint(x: midX, y: p1.y)
                                    )
                                }
                            }
                            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                            // End dot
                            if let lastPoint = points.last {
                                Circle()
                                    .fill(color)
                                    .frame(width: 6, height: 6)
                                    .position(lastPoint)
                            }
                        }
                        .frame(width: graphWidth, height: graphHeight)
                    } else {
                        // Keine Daten: zeige Baseline
                        VStack {
                            Spacer()
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                        }
                        .frame(width: graphWidth, height: graphHeight)
                    }
                }

                // X-Achse
                if showXScale {
                    HStack {
                        if showYScale {
                            Spacer().frame(width: yScaleWidth)
                        }
                        HStack {
                            ForEach(Array(xLabels.enumerated()), id: \.offset) { _, label in
                                if label != xLabels.first {
                                    Spacer()
                                }
                                Text(label)
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: graphWidth)
                    }
                    .frame(height: xScaleHeight)
                }
            }
        }
    }
}

// MARK: - Widget Views

struct PrivacyFlowWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(data: entry.data)
            case .systemMedium:
                MediumWidgetView(data: entry.data, chartStyle: entry.configuration.chartStyle)
            default:
                SmallWidgetView(data: entry.data)
            }
        }
        .widgetURL(entry.data.deepLinkURL)
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let data: WidgetData

    private func formatNumber(_ value: Int) -> String {
        if value >= 1000000 {
            return String(format: "%.1fM", Double(value) / 1000000)
        } else if value >= 10000 {
            return String(format: "%.0fk", Double(value) / 1000)
        } else if value >= 1000 {
            return String(format: "%.1fk", Double(value) / 1000)
        }
        return "\(value)"
    }

    private func formatPercentage(_ value: Int) -> String {
        if value > 0 { return "+\(value)%" }
        if value < 0 { return "\(value)%" }
        return "0%"
    }

    private func changeColor(_ value: Int) -> Color {
        if value > 0 { return .green }
        if value < 0 { return .red }
        return .secondary
    }

    var body: some View {
        if let error = data.errorMessage {
            VStack(spacing: 6) {
                Image(systemName: data.isConfigured ? "hand.tap" : "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 4) {
                    if data.activeVisitors > 0 {
                        Circle().fill(.green).frame(width: 6, height: 6)
                    }
                    Text(data.websiteName)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Spacer()
                    Text(data.timeRange)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Besucher:innen
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.purple)
                    Text(formatNumber(data.visitors))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(formatPercentage(data.visitorsChange))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(changeColor(data.visitorsChange))
                }

                Text(String(localized: "widget.stats.visitors"))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 15)

                Spacer()

                // Pageviews
                HStack(spacing: 4) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.blue)
                    Text(formatNumber(data.pageviews))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(formatPercentage(data.pageviewsChange))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(changeColor(data.pageviewsChange))
                }

                Text(String(localized: "widget.stats.pageviews"))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 15)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(10)
        }
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let data: WidgetData
    let chartStyle: WidgetChartStyle

    private func formatPercentage(_ value: Int) -> String {
        if value > 0 { return "+\(value)%" }
        if value < 0 { return "\(value)%" }
        return "0%"
    }

    private func changeColor(_ value: Int) -> Color {
        if value > 0 { return .green }
        if value < 0 { return .red }
        return .secondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let error = data.errorMessage {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: data.isConfigured ? "hand.tap" : "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                // Header
                HStack(spacing: 5) {
                    Text(data.websiteName)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if data.activeVisitors > 0 {
                        Circle().fill(.green).frame(width: 6, height: 6)
                        Text("\(data.activeVisitors)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.green)
                    }
                    Spacer()
                    Text(data.timeRange)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                // Stats mit Icons und Prozenten
                HStack(spacing: 16) {
                    // Visitors
                    HStack(spacing: 5) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.purple)
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text("\(data.visitors)")
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                Text(formatPercentage(data.visitorsChange))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(changeColor(data.visitorsChange))
                            }
                            Text(String(localized: "widget.stats.visitors"))
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Pageviews
                    HStack(spacing: 5) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text("\(data.pageviews)")
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                Text(formatPercentage(data.pageviewsChange))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(changeColor(data.pageviewsChange))
                            }
                            Text(String(localized: "widget.stats.pageviews"))
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding(.top, 4)

                Spacer(minLength: 2)

                // Graph mit Skala - Bar oder Line je nach Einstellung
                Group {
                    if chartStyle == .line {
                        LineChartView(data: data.sparklineData, color: .blue, timeRange: data.timeRange, showYScale: true, showXScale: true)
                    } else {
                        BarChartView(data: data.sparklineData, color: .blue, timeRange: data.timeRange, showYScale: true, showXScale: true)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 60)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(6)
    }
}

// MARK: - Widget

struct PrivacyFlowWidget: Widget {
    let kind: String = "PrivacyFlowWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigureWidgetIntent.self, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                PrivacyFlowWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                PrivacyFlowWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("widget.displayName")
        .description("widget.description")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    PrivacyFlowWidget()
} timeline: {
    StatsEntry(date: .now, data: .placeholder, configuration: ConfigureWidgetIntent())
}

#Preview(as: .systemMedium) {
    PrivacyFlowWidget()
} timeline: {
    StatsEntry(date: .now, data: .placeholder, configuration: ConfigureWidgetIntent())
}
