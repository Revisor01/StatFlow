import SwiftUI
import BackgroundTasks
import os
import UserNotifications

@main
struct PrivacyFlowApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var notificationManager = NotificationManager()
    @ObservedObject private var quickActionManager = QuickActionManager.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        registerBackgroundTasks()
        // Ohne erstes Einplanen kommt nie ein BGTask in die Queue.
        Self.scheduleAppRefresh()
        // Cache-Cleanup im Hintergrund beim App-Start
        Task.detached(priority: .background) {
            AnalyticsCacheService.shared.clearStaleEntries(olderThan: 7)
            let maxCacheSize: Int64 = 50 * 1024 * 1024 // 50MB
            if AnalyticsCacheService.shared.cacheSize() > maxCacheSize {
                AnalyticsCacheService.shared.evictOldestEntries(maxSize: maxCacheSize)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(notificationManager)
                .environmentObject(quickActionManager)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    // Beim Wechsel in den Hintergrund neu einplanen, sonst friert der Mitteilungstext ein.
                    if newPhase == .background {
                        Self.scheduleAppRefresh()
                    }
                }
                .task {
                    // Alte, eingefrorene Mitteilungen löschen und mit frischen Stats neu planen.
                    await UmamiAPI.shared.setFilters([])
                    await notificationManager.scheduleAllNotifications()
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        // Format: statflow://website?id=xxx&provider=umami
        guard url.scheme == "statflow",
              url.host == "website",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return
        }

        let websiteId = queryItems.first(where: { $0.name == "id" })?.value
        let providerString = queryItems.first(where: { $0.name == "provider" })?.value ?? "umami"

        if let websiteId = websiteId {
            let targetProvider: AnalyticsProviderType = providerString == "plausible" ? .plausible : .umami
            let currentProvider = AccountManager.shared.activeAccount?.providerType

            // Wenn Provider gewechselt werden muss, wechsle Account und navigiere mit Delay
            if currentProvider != targetProvider {
                if let targetAccount = AccountManager.shared.accounts.first(where: { $0.providerType == targetProvider }) {
                    Task {
                        await AccountManager.shared.setActiveAccount(targetAccount)
                    }

                    // Store pending deep link - will be processed after data loads
                    quickActionManager.pendingDeepLink = (websiteId: websiteId, provider: providerString)
                }
            } else {
                // Provider stimmt bereits, direkt navigieren
                quickActionManager.selectedWebsiteId = websiteId
            }
        }
    }

    private func registerBackgroundTasks() {
        // @Sendable und nicht isoliert: ein MainActor-Closure löst auf der Scheduler-Queue EXC_BREAKPOINT aus.
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "de.godsapp.statflow.refresh",
            using: nil
        ) { @Sendable task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Self.handleAppRefresh(task: refreshTask)
        }
    }

    private nonisolated static func handleAppRefresh(task: BGAppRefreshTask) {
        // Sofort neu einplanen, sonst reißt die Kette nach einem Lauf ab.
        scheduleAppRefresh()

        // Neu planen statt senden, weil wiederholende Trigger den Text beim Planen einfrieren.
        let work = Task { @MainActor in
            // Filter leeren, sonst drücken Detail-Filter die Stats im Hintergrund auf 0.
            await UmamiAPI.shared.setFilters([])
            let manager = NotificationManager()
            await manager.scheduleAllNotifications()
        }

        // Wird die BGTask-Frist überschritten, bricht iOS ab → laufende Arbeit canceln.
        task.expirationHandler = {
            work.cancel()
        }

        // Die Methoden von BGAppRefreshTask sind thread-safe, daher darf die Box ihn weiterreichen.
        let box = UncheckedSendableBox(task)
        Task {
            _ = await work.result
            box.value.setTaskCompleted(success: !work.isCancelled)
        }
    }

    nonisolated static func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "de.godsapp.statflow.refresh")

        let savedTime = UserDefaults.standard.object(forKey: "notificationTime") as? Date
        let hour: Int
        let minute: Int

        if let time = savedTime {
            hour = Calendar.current.component(.hour, from: time)
            minute = Calendar.current.component(.minute, from: time)
        } else {
            hour = 9
            minute = 0
        }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute

        // 30 Minuten vor der Mitteilung auffrischen, als Puffer für den BGTask.
        let leadTime: TimeInterval = -30 * 60 // 30 Minuten früher
        if let scheduledDate = Calendar.current.date(from: components) {
            let target = scheduledDate.addingTimeInterval(leadTime)
            if target < Date() {
                // Heutiger Slot bereits vorbei → für morgen planen
                request.earliestBeginDate = Calendar.current.date(byAdding: .day, value: 1, to: target)
            } else {
                request.earliestBeginDate = target
            }
        } else {
            request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        }

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            Logger.ui.error("Could not schedule app refresh: \(error.localizedDescription)")
        }
    }
}

// MARK: - Sendable Box für nicht-Sendable, aber thread-safe Apple-Typen

/// Reicht eine nicht-Sendable Referenz mit thread-sicheren Methoden über eine Concurrency-Grenze.
private struct UncheckedSendableBox<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}

// MARK: - App Delegate for Notification & Quick Action Handling

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let notificationDelegate = NotificationDelegate()
        UNUserNotificationCenter.current().delegate = notificationDelegate
        objc_setAssociatedObject(self, "notificationDelegate", notificationDelegate, .OBJC_ASSOCIATION_RETAIN)

        return true
    }
}

// Separate class for notification delegate to avoid concurrency issues
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}

// MARK: - Deep Link Manager (formerly Quick Action Manager)

@MainActor
class QuickActionManager: ObservableObject {
    static let shared = QuickActionManager()

    @Published var selectedWebsiteId: String?
    @Published var pendingDeepLink: (websiteId: String, provider: String)?

    private init() {}

    func clearSelection() {
        selectedWebsiteId = nil
        pendingDeepLink = nil
    }
}
