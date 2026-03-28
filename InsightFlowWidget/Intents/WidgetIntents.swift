//
//  WidgetIntents.swift
//  InsightFlowWidget
//

import WidgetKit
import SwiftUI
import AppIntents

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
