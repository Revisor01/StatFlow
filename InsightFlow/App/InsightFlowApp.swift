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
                .task {
                    // Beim ersten Vordergrund-Start alle noch pending (ggf. aus einem alten
                    // Build eingefrorenen) Notification-Requests löschen und mit frischen
                    // Stats neu planen. Verhindert, dass alte Bodies (z. B. die entfernte
                    // 4-Werte-Summary) per repeats:true weiter gefeuert werden.
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
        // WICHTIG: Der Completion-Block muss nonisolated sein. BGTaskScheduler ruft ihn auf
        // seiner eigenen Hintergrund-Queue (com.apple.BGTaskScheduler) auf, NICHT auf dem
        // MainActor. Da registerBackgroundTasks() als App-Methode @MainActor-isoliert ist,
        // würde ein normales Closure die Isolation erben — die Swift-Runtime prüft dann beim
        // Eintritt swift_task_checkIsolated, stellt "nicht auf MainActor" fest und löst einen
        // EXC_BREAKPOINT (SIGTRAP) aus. Genau das war der tägliche Background-Crash.
        // `using: nil` heißt explizit: Apple wählt die Queue, also darf der Block nicht
        // MainActor-isoliert sein.
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
        // Nächsten Refresh-Task sofort wieder einplanen, sonst läuft die Kette nach einem
        // Hintergrund-Lauf nicht weiter.
        scheduleAppRefresh()

        // Die eigentliche Arbeit läuft auf dem MainActor (NotificationManager ist
        // @MainActor-isoliert). `task` selbst bleibt im nonisolated Kontext und wird NICHT
        // über eine Concurrency-Boundary geschickt — BGAppRefreshTask ist nicht Sendable.
        // expirationHandler und setTaskCompleted sind thread-safe (Apple-API) und werden
        // daher synchron bzw. aus dem nonisolated Task heraus aufgerufen.
        //
        // WICHTIG: scheduleAllNotifications() statt sendScheduledNotifications() aufrufen.
        // UNCalendarNotificationTrigger(repeats: true) friert den content.body beim Planen
        // ein. scheduleAllNotifications() entfernt pending Requests und legt sie mit frisch
        // geladenen Stats neu an — das ist exakt der Fix für den Frozen-Body-Bug.
        let work = Task { @MainActor in
            // UmamiAPI-Aktor-Filter clearen, sonst leaken in der Detail-View gesetzte
            // Filter in den Background-Refresh und reduzieren Stats auf 0.
            await UmamiAPI.shared.setFilters([])
            let manager = NotificationManager()
            await manager.scheduleAllNotifications()
        }

        // Wird die BGTask-Frist überschritten, bricht iOS ab → laufende Arbeit canceln.
        task.expirationHandler = {
            work.cancel()
        }

        // BGAppRefreshTask ist nicht Sendable, seine Methoden sind aber thread-safe. Über
        // eine @unchecked-Sendable-Box dürfen wir die Referenz sicher in den await-Task
        // reichen, um nach Abschluss setTaskCompleted aufzurufen.
        let box = UncheckedSendableBox(task)
        Task {
            _ = await work.result
            box.value.setTaskCompleted(success: !work.isCancelled)
        }
    }

    nonisolated static func scheduleAppRefresh() {
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

// MARK: - Sendable Box für nicht-Sendable, aber thread-safe Apple-Typen

/// Reicht eine nicht-Sendable Referenz (z. B. BGAppRefreshTask) sicher über eine
/// Concurrency-Boundary, wenn deren Methoden dokumentiert thread-safe sind.
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
