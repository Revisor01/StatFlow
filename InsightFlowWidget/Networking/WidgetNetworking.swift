//
//  WidgetNetworking.swift
//  InsightFlowWidget
//

import WidgetKit
import SwiftUI
import Foundation

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
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(15 * 60)
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
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            startDate = calendar.startOfDay(for: yesterday)
            endDate = calendar.startOfDay(for: now).addingTimeInterval(-1)
        case .last7Days:
            startDate = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
            endDate = now
        case .last30Days:
            startDate = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now)) ?? now
            endDate = now
        }

        let startAt = Int(startDate.timeIntervalSince1970 * 1000)
        let endAt = Int(endDate.timeIntervalSince1970 * 1000)

        let timezone = TimeZone.current.identifier

        do {
            // Stats
            guard var statsURL = URLComponents(url: baseURL.appendingPathComponent("api/websites/\(website.id)/stats"), resolvingAgainstBaseURL: false) else {
                return .error(String(localized: "widget.error.invalidURL"))
            }
            statsURL.queryItems = [
                URLQueryItem(name: "startAt", value: String(startAt)),
                URLQueryItem(name: "endAt", value: String(endAt)),
                URLQueryItem(name: "timezone", value: timezone)
            ]
            guard let statsURLBuilt = statsURL.url else {
                return .error(String(localized: "widget.error.invalidURL"))
            }
            var statsReq = URLRequest(url: statsURLBuilt)
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
            guard var pvURL = URLComponents(url: baseURL.appendingPathComponent("api/websites/\(website.id)/pageviews"), resolvingAgainstBaseURL: false) else {
                return .error(String(localized: "widget.error.invalidURL"))
            }
            pvURL.queryItems = [
                URLQueryItem(name: "startAt", value: String(startAt)),
                URLQueryItem(name: "endAt", value: String(endAt)),
                URLQueryItem(name: "unit", value: timeRange.unit),
                URLQueryItem(name: "timezone", value: timezone)
            ]
            guard let pvURLBuilt = pvURL.url else {
                return .error(String(localized: "widget.error.invalidURL"))
            }
            var pvReq = URLRequest(url: pvURLBuilt)
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

                    let baseDate = timeRange == .today ? today : calendar.date(byAdding: .day, value: -1, to: today) ?? today
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
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
            let yesterdayStr = formatter.string(from: yesterday)
            comparisonDateRangeValue = [yesterdayStr, yesterdayStr]
        case .yesterday:
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
            let yesterdayStr = formatter.string(from: yesterday)
            dateRangeValue = [yesterdayStr, yesterdayStr]
            // Compare with day before yesterday
            let dayBefore = calendar.date(byAdding: .day, value: -2, to: today) ?? today
            let dayBeforeStr = formatter.string(from: dayBefore)
            comparisonDateRangeValue = [dayBeforeStr, dayBeforeStr]
        case .last7Days:
            dateRangeValue = "7d"
            // Compare with previous 7 days
            let start = calendar.date(byAdding: .day, value: -13, to: today) ?? today
            let end = calendar.date(byAdding: .day, value: -7, to: today) ?? today
            comparisonDateRangeValue = [formatter.string(from: start), formatter.string(from: end)]
        case .last30Days:
            dateRangeValue = "30d"
            // Compare with previous 30 days
            let start = calendar.date(byAdding: .day, value: -59, to: today) ?? today
            let end = calendar.date(byAdding: .day, value: -30, to: today) ?? today
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
                let baseDate = timeRange == .today ? today : calendar.date(byAdding: .day, value: -1, to: today) ?? today
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
            guard var realtimeComponents = URLComponents(url: baseURL.appendingPathComponent("api/v1/stats/realtime/visitors"), resolvingAgainstBaseURL: false) else {
                return .error(String(localized: "widget.error.invalidURL"))
            }
            realtimeComponents.queryItems = [URLQueryItem(name: "site_id", value: siteId)]

            guard let realtimeURL = realtimeComponents.url else {
                return .error(String(localized: "widget.error.invalidURL"))
            }
            var realtimeRequest = URLRequest(url: realtimeURL)
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
