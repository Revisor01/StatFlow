import Foundation
import os
import UserNotifications
import SwiftUI

@MainActor
class NotificationManager: ObservableObject {
    @Published var notificationSettings: [String: NotificationSetting] = [:]
    @Published var notificationTime: Date {
        didSet {
            saveNotificationTime()
            // Neu planen wenn Zeit geändert wird
            Task {
                await scheduleAllNotifications()
            }
        }
    }
    @Published var dataSource: NotificationDataSource {
        didSet {
            saveDataSource()
            Task {
                await scheduleAllNotifications()
            }
        }
    }

    private let settingsKey = "notificationSettings"
    private let timeKey = "notificationTime"
    private let dataSourceKey = "notificationDataSource"
    private let summaryThreshold = 5

    init() {
        // Standard: 9:00 Uhr
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 9
        components.minute = 0
        let defaultTime = calendar.date(from: components) ?? Date()

        // Lade gespeicherte Zeit oder nutze Standard
        if let savedTime = UserDefaults.standard.object(forKey: timeKey) as? Date {
            self.notificationTime = savedTime
        } else {
            self.notificationTime = defaultTime
        }

        // Lade gespeicherte Datenquelle oder nutze Standard (auto)
        if let savedDataSourceString = UserDefaults.standard.string(forKey: dataSourceKey),
           let savedDataSource = NotificationDataSource(rawValue: savedDataSourceString) {
            self.dataSource = savedDataSource
        } else {
            self.dataSource = .auto
        }

        loadSettings()
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: notificationTime)
    }

    var notificationHour: Int {
        Calendar.current.component(.hour, from: notificationTime)
    }

    var notificationMinute: Int {
        Calendar.current.component(.minute, from: notificationTime)
    }

    private func saveNotificationTime() {
        UserDefaults.standard.set(notificationTime, forKey: timeKey)
    }

    private func saveDataSource() {
        UserDefaults.standard.set(dataSource.rawValue, forKey: dataSourceKey)
    }

    /// Ermittelt den DateRange basierend auf Datenquelle und Uhrzeit
    func getEffectiveDateRange(for setting: NotificationSetting) -> DateRange {
        // Für wöchentlich immer letzte 7 Tage
        if setting == .weekly {
            return .last7Days
        }

        // Für täglich: basierend auf dataSource
        switch dataSource {
        case .today:
            return .today
        case .yesterday:
            return .yesterday
        case .auto:
            // Morgens (vor 12 Uhr) = gestern, Abends (ab 12 Uhr) = heute
            let hour = notificationHour
            return hour < 12 ? .yesterday : .today
        }
    }

    var dataSourceDescription: String {
        switch dataSource {
        case .today:
            return "Statistiken von heute"
        case .yesterday:
            return "Statistiken von gestern"
        case .auto:
            let hour = notificationHour
            if hour < 12 {
                return "Automatisch: gestern (Morgens)"
            } else {
                return "Automatisch: heute (Abends)"
            }
        }
    }

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            return false
        }
    }

    func updateSetting(for websiteId: String, setting: NotificationSetting) {
        notificationSettings[websiteId] = setting
        saveSettings()
        // Notifications neu planen
        Task {
            await scheduleAllNotifications()
        }
    }

    /// Setzt alle Websites eines Accounts auf das gleiche Setting
    func updateAllSettings(for accountWebsiteIds: [String], setting: NotificationSetting) {
        for id in accountWebsiteIds {
            notificationSettings[id] = setting
        }
        saveSettings()
        Task { await scheduleAllNotifications() }
    }

    /// Prueft ob alle Websites eines Accounts aktiviert sind
    func allEnabled(for websiteIds: [String]) -> Bool {
        guard !websiteIds.isEmpty else { return false }
        return websiteIds.allSatisfy { notificationSettings[$0] != nil && notificationSettings[$0] != .disabled }
    }

    // Scheduled Notifications mit UNCalendarNotificationTrigger für zuverlässige Zeiten
    func scheduleAllNotifications() async {
        let center = UNUserNotificationCenter.current()

        // Erst alle alten scheduled notifications löschen
        center.removeAllPendingNotificationRequests()

        // Prüfe ob überhaupt Websites aktiviert sind
        let enabledWebsites = notificationSettings.filter { $0.value != .disabled }
        guard !enabledWebsites.isEmpty else { return }

        // Berechtigung prüfen
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        // Hole alle Accounts und plane für jeden
        let accounts = AccountManager.shared.accounts

        for account in accounts {
            await scheduleNotificationsForAccount(account, center: center)
        }

        // Debug: Zeige geplante Notifications
        let pending = await center.pendingNotificationRequests()
        Logger.ui.debug("Geplante Notifications: \(pending.count)")
        for req in pending {
            if let trigger = req.trigger as? UNCalendarNotificationTrigger {
                Logger.ui.debug("  - \(req.identifier): \(String(describing: trigger.dateComponents))")
            }
        }
    }

    private func scheduleNotificationsForAccount(_ account: AnalyticsAccount, center: UNUserNotificationCenter) async {
        // Struct to hold website info uniformly
        struct WebsiteInfo {
            let id: String
            let name: String
        }

        var websites: [WebsiteInfo] = []

        switch account.providerType {
        case .umami:
            guard let token = account.credentials.token,
                  let url = URL(string: account.serverURL) else { return }

            let api = UmamiAPI.shared
            await api.configure(baseURL: url, token: token)
            let umamiWebsites = (try? await api.getWebsites()) ?? []
            websites = umamiWebsites.map { WebsiteInfo(id: $0.id, name: $0.name) }

        case .plausible:
            // Für Plausible: Sites aus Account laden
            guard let sites = account.sites else { return }
            websites = sites.map { WebsiteInfo(id: $0, name: $0) }
        }

        // Bestimme aktivierte Websites und ob Summary verwendet werden soll
        let enabledWebsites = websites.filter { ws in
            guard let setting = notificationSettings[ws.id] else { return false }
            return setting != .disabled
        }
        let useSummary = enabledWebsites.count >= summaryThreshold

        if useSummary {
            // Summary-Notification: Sammle Stats aller aktivierten Websites
            struct WebsiteStats {
                let name: String
                let visitors: Int
                let changePercentage: Double
            }
            var allStats: [WebsiteStats] = []

            // Bestimme häufigstes Setting (daily vs. weekly)
            let weeklyCount = enabledWebsites.filter { notificationSettings[$0.id] == .weekly }.count
            let dominantSetting: NotificationSetting = weeklyCount > enabledWebsites.count / 2 ? .weekly : .daily
            let dateRange = getEffectiveDateRange(for: dominantSetting)

            for website in enabledWebsites {
                var stats: AnalyticsStats?
                switch account.providerType {
                case .umami:
                    if let token = account.credentials.token,
                       let url = URL(string: account.serverURL) {
                        let api = UmamiAPI.shared
                        await api.configure(baseURL: url, token: token)
                        if let umamiStats = try? await api.getStats(websiteId: website.id, dateRange: dateRange) {
                            stats = AnalyticsStats(
                                visitors: StatValue(value: umamiStats.visitors.value, change: umamiStats.visitors.change),
                                pageviews: StatValue(value: umamiStats.pageviews.value, change: umamiStats.pageviews.change),
                                visits: StatValue(value: umamiStats.visits.value, change: umamiStats.visits.change),
                                bounces: StatValue(value: umamiStats.bounces.value, change: umamiStats.bounces.change),
                                totaltime: StatValue(value: umamiStats.totaltime.value, change: umamiStats.totaltime.change)
                            )
                        }
                    }
                case .plausible:
                    if let apiKey = account.credentials.apiKey {
                        try? KeychainService.save(account.serverURL, for: .serverURL)
                        try? KeychainService.save(apiKey, for: .apiKey)
                        await PlausibleAPI.shared.reconfigureFromKeychain()
                        stats = try? await PlausibleAPI.shared.getAnalyticsStats(websiteId: website.id, dateRange: dateRange)
                    }
                }
                if let s = stats {
                    allStats.append(WebsiteStats(name: website.name, visitors: s.visitors.value, changePercentage: s.visitors.changePercentage))
                }
            }

            let content = UNMutableNotificationContent()
            content.sound = .default
            content.title = "\(account.displayName) — Zusammenfassung"
            content.threadIdentifier = "account-\(account.id.uuidString)"

            if allStats.isEmpty {
                content.body = "Tippe um deine Statistiken zu sehen"
            } else {
                let totalVisitors = allStats.reduce(0) { $0 + $1.visitors }
                let topSite = allStats.max(by: { $0.changePercentage < $1.changePercentage })
                var bodyText = "\(totalVisitors.formatted()) Besucher gesamt"
                if let top = topSite {
                    let arrow = top.changePercentage >= 0 ? "↑" : "↓"
                    bodyText += " • Top: \(top.name) \(arrow)\(abs(Int(top.changePercentage)))%"
                }
                content.body = bodyText
            }

            var dateComponents = DateComponents()
            dateComponents.hour = notificationHour
            dateComponents.minute = notificationMinute
            if dominantSetting == .weekly {
                dateComponents.weekday = 2 // Montag
            }
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: "scheduled-\(account.id.uuidString)-summary",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)

        } else {
            // Einzel-Notifications mit threadIdentifier
            for website in websites {
                guard let setting = notificationSettings[website.id], setting != .disabled else { continue }

                let dateRange = getEffectiveDateRange(for: setting)

                // Versuche aktuelle Stats zu holen für die Notification
                var stats: AnalyticsStats?

                switch account.providerType {
                case .umami:
                    if let token = account.credentials.token,
                       let url = URL(string: account.serverURL) {
                        let api = UmamiAPI.shared
                        await api.configure(baseURL: url, token: token)
                        if let umamiStats = try? await api.getStats(websiteId: website.id, dateRange: dateRange) {
                            stats = AnalyticsStats(
                                visitors: StatValue(value: umamiStats.visitors.value, change: umamiStats.visitors.change),
                                pageviews: StatValue(value: umamiStats.pageviews.value, change: umamiStats.pageviews.change),
                                visits: StatValue(value: umamiStats.visits.value, change: umamiStats.visits.change),
                                bounces: StatValue(value: umamiStats.bounces.value, change: umamiStats.bounces.change),
                                totaltime: StatValue(value: umamiStats.totaltime.value, change: umamiStats.totaltime.change)
                            )
                        }
                    }
                case .plausible:
                    if let apiKey = account.credentials.apiKey {
                        try? KeychainService.save(account.serverURL, for: .serverURL)
                        try? KeychainService.save(apiKey, for: .apiKey)
                        await PlausibleAPI.shared.reconfigureFromKeychain()
                        stats = try? await PlausibleAPI.shared.getAnalyticsStats(websiteId: website.id, dateRange: dateRange)
                    }
                }

                let content = UNMutableNotificationContent()
                content.sound = .default
                content.title = "\(website.name) (\(account.displayName))"
                content.threadIdentifier = "account-\(account.id.uuidString)"

                // Subtitle basierend auf Setting und Datenquelle
                let periodText: String
                if setting == .weekly {
                    periodText = "Letzte 7 Tage"
                } else {
                    switch dateRange {
                    case .today: periodText = "Heute"
                    case .yesterday: periodText = "Gestern"
                    default: periodText = "Gestern"
                    }
                }
                content.subtitle = periodText

                if let stats = stats {
                    var bodyParts: [String] = []

                    // Besucher mit Änderung
                    var visitorsText = "\(stats.visitors.value.formatted()) Besucher"
                    if stats.visitors.changePercentage != 0 {
                        let arrow = stats.visitors.changePercentage > 0 ? "↑" : "↓"
                        visitorsText += " \(arrow)\(abs(Int(stats.visitors.changePercentage)))%"
                    }
                    bodyParts.append(visitorsText)

                    // Aufrufe mit Änderung
                    var pageviewsText = "\(stats.pageviews.value.formatted()) Aufrufe"
                    if stats.pageviews.changePercentage != 0 {
                        let arrow = stats.pageviews.changePercentage > 0 ? "↑" : "↓"
                        pageviewsText += " \(arrow)\(abs(Int(stats.pageviews.changePercentage)))%"
                    }
                    bodyParts.append(pageviewsText)

                    // Besuche mit Änderung
                    var visitsText = "\(stats.visits.value.formatted()) Besuche"
                    if stats.visits.changePercentage != 0 {
                        let arrow = stats.visits.changePercentage > 0 ? "↑" : "↓"
                        visitsText += " \(arrow)\(abs(Int(stats.visits.changePercentage)))%"
                    }
                    bodyParts.append(visitsText)

                    content.body = bodyParts.joined(separator: " • ")
                } else {
                    content.body = "Tippe um deine Statistiken zu sehen"
                }

                // Trigger basierend auf Setting
                var dateComponents = DateComponents()
                dateComponents.hour = notificationHour
                dateComponents.minute = notificationMinute

                if setting == .weekly {
                    // Jeden Montag
                    dateComponents.weekday = 2 // Montag
                }
                // Täglich: nur hour und minute setzen

                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

                // Eindeutige ID: account + website
                let request = UNNotificationRequest(
                    identifier: "scheduled-\(account.id.uuidString)-\(website.id)",
                    content: content,
                    trigger: trigger
                )

                try? await center.add(request)
            }
        }
    }

    func getSetting(for websiteId: String) -> NotificationSetting {
        notificationSettings[websiteId] ?? .disabled
    }

    private func loadSettings() {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode([String: NotificationSetting].self, from: data) else {
            return
        }
        notificationSettings = settings
    }

    private func saveSettings() {
        guard let data = try? JSONEncoder().encode(notificationSettings) else { return }
        UserDefaults.standard.set(data, forKey: settingsKey)
    }

    nonisolated func sendScheduledNotifications() async {
        let settingsData = UserDefaults.standard.data(forKey: "notificationSettings")
        let settings = settingsData.flatMap { try? JSONDecoder().decode([String: NotificationSetting].self, from: $0) } ?? [:]

        // Lade Datenquelle aus UserDefaults
        let dataSourceString = UserDefaults.standard.string(forKey: "notificationDataSource")
        let dataSource = dataSourceString.flatMap { NotificationDataSource(rawValue: $0) } ?? .auto

        // Lade Uhrzeit für Auto-Modus
        let savedTime = UserDefaults.standard.object(forKey: "notificationTime") as? Date ?? Date()
        let notificationHour = Calendar.current.component(.hour, from: savedTime)

        // Lade alle Accounts
        let accountsData = UserDefaults.standard.data(forKey: "analytics_accounts")
        let accounts = accountsData.flatMap { try? JSONDecoder().decode([AnalyticsAccount].self, from: $0) } ?? []

        for account in accounts {
            await sendNotificationsForAccount(account, settings: settings, dataSource: dataSource, notificationHour: notificationHour)
        }
    }

    private nonisolated func sendNotificationsForAccount(_ account: AnalyticsAccount, settings: [String: NotificationSetting], dataSource: NotificationDataSource, notificationHour: Int) async {
        // Struct to hold website info uniformly
        struct WebsiteInfo: Sendable {
            let id: String
            let name: String
        }

        var websites: [WebsiteInfo] = []

        switch account.providerType {
        case .umami:
            guard let token = account.credentials.token,
                  let url = URL(string: account.serverURL) else { return }

            let api = UmamiAPI.shared
            await api.configure(baseURL: url, token: token)
            let umamiWebsites = (try? await api.getWebsites()) ?? []
            websites = umamiWebsites.map { WebsiteInfo(id: $0.id, name: $0.name) }

        case .plausible:
            guard let sites = account.sites else { return }
            websites = sites.map { WebsiteInfo(id: $0, name: $0) }
        }

        // Bestimme aktivierte Websites und ob Summary verwendet werden soll
        let enabledWebsites = websites.filter { ws in
            guard let setting = settings[ws.id] else { return false }
            return setting != .disabled
        }
        let localSummaryThreshold = 5
        let useSummary = enabledWebsites.count >= localSummaryThreshold

        if useSummary {
            // Summary-Notification: Sammle Stats aller aktivierten Websites
            struct WebsiteStats: Sendable {
                let name: String
                let visitors: Int
                let changePercentage: Double
            }
            var allStats: [WebsiteStats] = []

            // Bestimme häufigstes Setting für DateRange
            let weeklyCount = enabledWebsites.filter { settings[$0.id] == .weekly }.count
            let dominantSetting: NotificationSetting = weeklyCount > enabledWebsites.count / 2 ? .weekly : .daily

            let dateRange: DateRange
            if dominantSetting == .weekly {
                dateRange = .last7Days
            } else {
                switch dataSource {
                case .today: dateRange = .today
                case .yesterday: dateRange = .yesterday
                case .auto: dateRange = notificationHour < 12 ? .yesterday : .today
                }
            }

            for website in enabledWebsites {
                var stats: AnalyticsStats?
                switch account.providerType {
                case .umami:
                    if let token = account.credentials.token,
                       let url = URL(string: account.serverURL) {
                        let api = UmamiAPI.shared
                        await api.configure(baseURL: url, token: token)
                        if let umamiStats = try? await api.getStats(websiteId: website.id, dateRange: dateRange) {
                            stats = AnalyticsStats(
                                visitors: StatValue(value: umamiStats.visitors.value, change: umamiStats.visitors.change),
                                pageviews: StatValue(value: umamiStats.pageviews.value, change: umamiStats.pageviews.change),
                                visits: StatValue(value: umamiStats.visits.value, change: umamiStats.visits.change),
                                bounces: StatValue(value: umamiStats.bounces.value, change: umamiStats.bounces.change),
                                totaltime: StatValue(value: umamiStats.totaltime.value, change: umamiStats.totaltime.change)
                            )
                        }
                    }
                case .plausible:
                    if let apiKey = account.credentials.apiKey {
                        try? KeychainService.save(account.serverURL, for: .serverURL)
                        try? KeychainService.save(apiKey, for: .apiKey)
                        await PlausibleAPI.shared.reconfigureFromKeychain()
                        stats = try? await PlausibleAPI.shared.getAnalyticsStats(websiteId: website.id, dateRange: dateRange)
                    }
                }
                if let s = stats {
                    allStats.append(WebsiteStats(name: website.name, visitors: s.visitors.value, changePercentage: s.visitors.changePercentage))
                }
            }

            let content = UNMutableNotificationContent()
            content.sound = .default
            content.title = "\(account.displayName) — Zusammenfassung"
            content.threadIdentifier = "account-\(account.id.uuidString)"

            if allStats.isEmpty {
                content.body = "Tippe um deine Statistiken zu sehen"
            } else {
                let totalVisitors = allStats.reduce(0) { $0 + $1.visitors }
                let topSite = allStats.max(by: { $0.changePercentage < $1.changePercentage })
                var bodyText = "\(totalVisitors.formatted()) Besucher gesamt"
                if let top = topSite {
                    let arrow = top.changePercentage >= 0 ? "↑" : "↓"
                    bodyText += " • Top: \(top.name) \(arrow)\(abs(Int(top.changePercentage)))%"
                }
                content.body = bodyText
            }

            let request = UNNotificationRequest(
                identifier: "stats-\(account.id.uuidString)-summary-\(Date().timeIntervalSince1970)",
                content: content,
                trigger: nil
            )
            try? await UNUserNotificationCenter.current().add(request)

        } else {
            // Einzel-Notifications
            for website in websites {
                guard let setting = settings[website.id], setting != .disabled else { continue }

                // Ermittle den richtigen DateRange
                let dateRange: DateRange
                if setting == .weekly {
                    dateRange = .last7Days
                } else {
                    switch dataSource {
                    case .today:
                        dateRange = .today
                    case .yesterday:
                        dateRange = .yesterday
                    case .auto:
                        dateRange = notificationHour < 12 ? .yesterday : .today
                    }
                }

                var stats: AnalyticsStats?

                switch account.providerType {
                case .umami:
                    if let token = account.credentials.token,
                       let url = URL(string: account.serverURL) {
                        let api = UmamiAPI.shared
                        await api.configure(baseURL: url, token: token)
                        if let umamiStats = try? await api.getStats(websiteId: website.id, dateRange: dateRange) {
                            stats = AnalyticsStats(
                                visitors: StatValue(value: umamiStats.visitors.value, change: umamiStats.visitors.change),
                                pageviews: StatValue(value: umamiStats.pageviews.value, change: umamiStats.pageviews.change),
                                visits: StatValue(value: umamiStats.visits.value, change: umamiStats.visits.change),
                                bounces: StatValue(value: umamiStats.bounces.value, change: umamiStats.bounces.change),
                                totaltime: StatValue(value: umamiStats.totaltime.value, change: umamiStats.totaltime.change)
                            )
                        }
                    }
                case .plausible:
                    // Für Plausible muss der Keychain temporär gesetzt werden
                    if let apiKey = account.credentials.apiKey {
                        try? KeychainService.save(account.serverURL, for: .serverURL)
                        try? KeychainService.save(apiKey, for: .apiKey)
                        await PlausibleAPI.shared.reconfigureFromKeychain()
                        stats = try? await PlausibleAPI.shared.getAnalyticsStats(websiteId: website.id, dateRange: dateRange)
                    }
                }

                guard let stats = stats else { continue }

                let content = UNMutableNotificationContent()
                content.sound = .default
                content.threadIdentifier = "account-\(account.id.uuidString)"

                // Subtitle basierend auf Setting und Datenquelle
                let periodText: String
                if setting == .weekly {
                    periodText = "Letzte 7 Tage"
                } else {
                    switch dateRange {
                    case .today: periodText = "Heute"
                    case .yesterday: periodText = "Gestern"
                    default: periodText = "Gestern"
                    }
                }

                content.title = "\(website.name) (\(account.displayName))"
                content.subtitle = periodText

                // Build detailed body
                var bodyParts: [String] = []

                // Besucher mit Änderung
                var visitorsText = "\(stats.visitors.value.formatted()) Besucher"
                if stats.visitors.changePercentage != 0 {
                    let arrow = stats.visitors.changePercentage > 0 ? "↑" : "↓"
                    visitorsText += " \(arrow)\(abs(Int(stats.visitors.changePercentage)))%"
                }
                bodyParts.append(visitorsText)

                // Aufrufe mit Änderung
                var pageviewsText = "\(stats.pageviews.value.formatted()) Aufrufe"
                if stats.pageviews.changePercentage != 0 {
                    let arrow = stats.pageviews.changePercentage > 0 ? "↑" : "↓"
                    pageviewsText += " \(arrow)\(abs(Int(stats.pageviews.changePercentage)))%"
                }
                bodyParts.append(pageviewsText)

                // Besuche mit Änderung
                var visitsText = "\(stats.visits.value.formatted()) Besuche"
                if stats.visits.changePercentage != 0 {
                    let arrow = stats.visits.changePercentage > 0 ? "↑" : "↓"
                    visitsText += " \(arrow)\(abs(Int(stats.visits.changePercentage)))%"
                }
                bodyParts.append(visitsText)

                content.body = bodyParts.joined(separator: " • ")

                let request = UNNotificationRequest(
                    identifier: "stats-\(account.id.uuidString)-\(website.id)-\(Date().timeIntervalSince1970)",
                    content: content,
                    trigger: nil
                )

                try? await UNUserNotificationCenter.current().add(request)
            }
        }
    }

}

enum NotificationSetting: String, Codable, CaseIterable, Sendable {
    case disabled = "disabled"
    case daily = "daily"
    case weekly = "weekly"

    var localizedName: String {
        switch self {
        case .disabled: return String(localized: "notifications.setting.disabled", defaultValue: "Off")
        case .daily: return String(localized: "notifications.setting.daily", defaultValue: "Daily")
        case .weekly: return String(localized: "notifications.setting.weekly", defaultValue: "Weekly")
        }
    }
}

enum NotificationDataSource: String, Codable, CaseIterable, Sendable {
    case today = "today"
    case yesterday = "yesterday"
    case auto = "auto"

    var localizedName: String {
        switch self {
        case .today: return String(localized: "settings.notifications.stats.today")
        case .yesterday: return String(localized: "settings.notifications.stats.yesterday")
        case .auto: return String(localized: "settings.notifications.stats.auto")
        }
    }

    var description: String {
        switch self {
        case .today: return String(localized: "notifications.datasource.today.desc", defaultValue: "Shows today's statistics")
        case .yesterday: return String(localized: "notifications.datasource.yesterday.desc", defaultValue: "Shows yesterday's statistics")
        case .auto: return String(localized: "notifications.datasource.auto.desc", defaultValue: "Morning: yesterday, Evening: today")
        }
    }
}
