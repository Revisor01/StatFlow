import SwiftUI
import BackgroundTasks
import UserNotifications

@main
struct PrivacyFlowApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var notificationManager = NotificationManager()
    @ObservedObject private var quickActionManager = QuickActionManager.shared

    init() {
        registerBackgroundTasks()
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
        scheduleAppRefresh()

        let operation = Task {
            let manager = NotificationManager()
            await manager.sendScheduledNotifications()
        }

        task.expirationHandler = {
            operation.cancel()
        }

        Task {
            await operation.value
            task.setTaskCompleted(success: true)
        }
    }

    private static func scheduleAppRefresh() {
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

        if let scheduledDate = Calendar.current.date(from: components) {
            // Falls Zeit heute schon vorbei ist, nimm morgen
            if scheduledDate < Date() {
                request.earliestBeginDate = Calendar.current.date(byAdding: .day, value: 1, to: scheduledDate)
            } else {
                request.earliestBeginDate = scheduledDate
            }
        } else {
            request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        }

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            #if DEBUG
            print("Could not schedule app refresh: \(error)")
            #endif
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
