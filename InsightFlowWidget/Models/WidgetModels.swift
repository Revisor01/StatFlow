//
//  WidgetModels.swift
//  InsightFlowWidget
//

import WidgetKit
import SwiftUI
import Foundation

// MARK: - Debug

func widgetLog(_ message: String) {
    #if DEBUG
    print("[Widget] \(message)")
    #endif
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
        return URL(string: "statflow://website?id=\(websiteId)&provider=\(provider)")
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
