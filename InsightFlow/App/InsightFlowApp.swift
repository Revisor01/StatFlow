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
        // Initial BGTask einplanen — ohne dies wird nie ein Task in die Queue gestellt
        // und der Handler läuft nie. Re-Submit erfolgt zusätzlich bei scenePhase == .background.
        Self.scheduleAppRefresh()
        // Cache-Cleanup im Hintergrund beim App-Start (FIX-03)
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
                    // Re-Submit BGTask, sobald die App in den Hintergrund geht — sonst kann iOS
                    // den nächsten Refresh nicht planen und der Notification-Body bleibt eingefroren.
                    if newPhase == .background {
                        Self.scheduleAppRefresh()
                    }
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
                // Find matching account and switch to it
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
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "de.godsapp.statflow.refresh",
            using: nil
        ) { task in
            Self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }

    private static func handleAppRefresh(task: BGAppRefreshTask) {
        // Nächsten Refresh-Task sofort wieder einplanen, sonst läuft die Kette nach einem
        // Hintergrund-Lauf nicht weiter.
        scheduleAppRefresh()

        // WICHTIG: scheduleAllNotifications() statt sendScheduledNotifications() aufrufen.
        // UNCalendarNotificationTrigger(repeats: true) friert den content.body beim Planen
        // ein. scheduleAllNotifications() entfernt pending Requests und legt sie mit frisch
        // geladenen Stats neu an — das ist exakt der Fix für den Frozen-Body-Bug.
        // NotificationManager ist @MainActor-isoliert, deshalb das @MainActor-Task.
        let operation = Task { @MainActor in
            // UmamiAPI-Aktor-Filter clearen, sonst leaken in der Detail-View gesetzte
            // Filter in den Background-Refresh und reduzieren Stats auf 0.
            await UmamiAPI.shared.setFilters([])
            let manager = NotificationManager()
            await manager.scheduleAllNotifications()
        }

        task.expirationHandler = {
            operation.cancel()
        }

        Task {
            await operation.value
            task.setTaskCompleted(success: true)
        }
    }

    static func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "de.godsapp.statflow.refresh")

        // Lade konfigurierte Zeit oder Standard 9:00 Uhr
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

        // Lead time: 30 Minuten vor der eigentlichen Notification-Zeit refreshen, damit das
        // System einen Puffer hat um den BGTask zu feuern bevor der Calendar-Trigger zuschlägt.
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
