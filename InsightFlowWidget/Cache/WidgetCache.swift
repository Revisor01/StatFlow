//
//  WidgetCache.swift
//  InsightFlowWidget
//

import Foundation

// MARK: - Widget Cache

/// Einfacher Cache für Widget-Daten, der im App Group Container gespeichert wird
struct WidgetCache {
    private static let appGroupID = "group.de.godsapp.statflow"
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
