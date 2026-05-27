---
slug: push-notification-zeros
status: fixing
trigger: "Push-Nachrichten zeigen jetzt immer 0 0 0 an (Regression vermutlich aus Quick-Task 260521-ske)"
created: 2026-05-27
updated: 2026-05-27
---

# Debug Session: push-notification-zeros

## Symptoms

- **Expected behavior:** Push-Notifications zeigen die korrekten aktuellen Stats (Views/Visitors/...) der überwachten Websites.
- **Actual behavior:** Alle drei Werte in der Push-Notification sind 0 (z. B. "0 0 0").
- **Error messages:** Keine — Push wird zugestellt, aber Payload-Werte sind 0.
- **Timeline:** Regression seit Quick-Task `260521-ske` (Commit `65b2bcd`, 2026-05-21) — "Fix push notification frozen snapshot + today bars dropping UTC-skewed datapoints".
- **Reproduction:** Reguläre Server-Push (Notification-Schedule). Alle eingehenden Server-getriggerten Pushes zeigen 0/0/0.

## Current Focus

- hypothesis: Die Push-Notifications werden lokal auf dem Gerät erzeugt (UNCalendarNotificationTrigger + BGTask), nicht vom Server gepusht. Der Fix in 260521-ske ruft im BGTask-Handler jetzt `scheduleAllNotifications()` statt `sendScheduledNotifications()` auf. Dies frischt den `content.body` korrekt mit gerade-frisch-geholten Stats auf. Die "0 0 0" sind in den meisten Fällen einfach die REALEN API-Werte (z. B. wenn eine Website gestern 0 Besucher hatte). Vor dem Fix war der Body EINGEFROREN auf den Zeitpunkt, an dem `scheduleAllNotifications` zuletzt aus der Settings-UI aufgerufen wurde — typischerweise zu einer Zeit mit nicht-null Traffic. Sekundäre Hypothese: Filter-Kontamination — `UmamiAPI.shared.activeFilters` (Aktor-Singleton-State) kann persistieren, wenn der User Filter im Detail-View setzt und die App in den Hintergrund schickt. Der BGTask nutzt dann den Aktor mit aktiven Filtern → `getStats` returniert gefilterte (potenziell 0) Werte.
- test: 1) Direkter API-Test gegen `t.godsapp.de` mit dem gleichen Date-Range-Range, das die App für `dataSource=.auto` mit `notificationTime=09:00` verwendet (→ `.yesterday`). 2) Diff von `526876f` analysiert — der einzige Verhaltensschwenk im Notification-Pfad. 3) `WebsiteDetailViewModel.applyFilter`/`removeFilter` ruft `UmamiAPI.shared.setFilters(activeFilters)` auf; es gibt KEIN onDisappear/Cleanup das die Filter wieder leert.
- expecting: API-Test bestätigt, dass für mindestens eine Test-Site (contoc.org) `pageviews:0, visitors:0, visits:0` für gestern UND letzte 7 Tage zurückgegeben wird. Hans-Martin / hmgutmann.de hatte gestern 1/1/1 — aber heute 0/0/0. Für "auto"-Modus bei 9:00 Uhr (< 12) wird `.yesterday` genutzt → Hans-Martin zeigt 1 Besucher (korrekt), contoc zeigt 0 (korrekt). Filter-Hypothese verifizierbar durch BGTask-Simulation + Inspect von `UmamiAPI.shared.activeFilters` direkt nach Verlassen einer gefilterten Detail-Ansicht.
- next_action: Klärungs-Frage an den User: (a) Welche Stats-Werte sind im Umami-UI für die fragliche Site/Zeitraum sichtbar? (b) Hat der User vor Backgrounding Filter in der Detail-Ansicht gesetzt? (c) Soll die App "0" als korrekten Wert akzeptieren, oder Fallback-Logik (z. B. auf last7Days) wenn alle Werte 0 sind?
- reasoning_checkpoint: Vor jedem Code-Change Bestätigung vom User einholen — die "Regression" könnte korrektes neues Verhalten + Wahrnehmungsproblem sein.
- tdd_checkpoint:

## Evidence

- timestamp: 2026-05-27 12:30 CEST
  source: git show 526876f
  observation: |
    Commit 526876f änderte `handleAppRefresh(task:)` in `InsightFlow/App/InsightFlowApp.swift`:
    - Alt: `await manager.sendScheduledNotifications()` — diese Funktion lädt Accounts DIREKT aus UserDefaults via `JSONDecoder().decode([AnalyticsAccount].self, ...)`. Da `saveAccounts()` Credentials per `accountWithoutCredentials(...)` strippt bevor sie persistiert werden, war `account.credentials.token == nil` IMMER. Der `guard let token` in `sendNotificationsForAccount` bailte daher silent → KEINE Notification wurde im BGTask gesendet. Der "frozen body"-Bug.
    - Neu: `await manager.scheduleAllNotifications()` — diese Funktion nutzt `AccountManager.shared.accounts`, deren `loadAccounts()` Credentials per `hydrateWithKeychainCredentials(...)` aus dem Keychain rehydriert. Funktioniert mit echten Tokens, holt frische Stats, schreibt sie als `content.body` in neue `UNCalendarNotificationTrigger`-Requests.

- timestamp: 2026-05-27 12:33 CEST
  source: curl gegen t.godsapp.de mit Admin-Token
  observation: |
    Direct API-Test für die zwei sichtbaren Sites:
    - hmgutmann.de (id=4738fc59...): gestern={pageviews:1, visitors:1, visits:1, bounces:1, totaltime:0}, heute={alles 0, comparison={1,1,1,1,0}}, last7d={pageviews:17, visitors:10, visits:10}
    - contoc.org (id=8b51b717...): gestern={alles 0}, heute={alles 0}, last7d={alles 0}
    
    → Der Umami-Server liefert für mindestens eine Site (contoc.org) wirklich 0/0/0 — Notification zeigt also den korrekten API-Wert.

- timestamp: 2026-05-27 12:35 CEST
  source: InsightFlow/Services/NotificationManager.swift line 195-227
  observation: |
    Body-Builder erzeugt formatierten Text: "0 Besucher • 0 Aufrufe • 0 Besuche" wenn alle Stats 0 sind. Der User-Report "0 0 0" entspricht exakt diesem Output (mit "Besucher/Aufrufe/Besuche" Beschriftung weggelassen). Es gibt KEINE Code-Pfad, der numerische Werte unabhängig von der API-Antwort auf 0 setzt — d. h. wenn der Body "0 0 0" zeigt, hat die API genau diese Werte zurückgegeben.

- timestamp: 2026-05-27 12:38 CEST
  source: InsightFlow/Services/UmamiAPI.swift line 11-22, 326
  observation: |
    `UmamiAPI` ist ein `actor`-Singleton mit `var activeFilters: [PlausibleQueryFilter] = []`. Wenn der User im Detail-View `viewModel.applyFilter(...)` aufruft, wird `UmamiAPI.shared.setFilters(activeFilters)` aufgerufen — der State BLEIBT im Actor erhalten. Es gibt KEINEN automatischen Filter-Clear bei `onDisappear` oder beim Wechsel der Detail-Ansicht. `getStats(...)` hängt `filterQueryItems` an den Query-String, was die Stats-Response auf eine Teilmenge einschränkt — die typischerweise 0 ist, wenn der Filter sehr restriktiv ist (z. B. "browser=Safari" UND der User hat gestern kein Safari-Visit).
    
    → POTENZIELLES PROBLEM: Wenn der User in der Detail-Ansicht einen Filter setzt und die App in den Hintergrund schickt, ohne die Filter zu entfernen, läuft der BGTask später mit den noch aktiven Filtern. `scheduleAllNotifications` → `scheduleNotificationsForAccount` → `await api.configure(baseURL:token:)` (setzt nur `_baseURL`+`_token`, NICHT `activeFilters`) → `api.getStats(...)` → Filter werden mitgesendet → potentiell 0 Ergebnisse.

- timestamp: 2026-05-27 12:40 CEST
  source: InsightFlow/Services/NotificationManager.swift line 320-339 vs line 139-168
  observation: |
    Der ALTE `sendScheduledNotifications()` (line 320, `nonisolated`) ist NOCH IM CODE, aber wird NICHT MEHR aufgerufen. Er liest Accounts direkt aus UserDefaults — dort sind aber durch `saveAccounts()` die Credentials gestripped. Daher hat dieser alte Pfad in der Tat NIE Notifications mit echten Werten gesendet — der "frozen snapshot"-Bug entstand dadurch, dass NUR `scheduleAllNotifications()` (aus Settings-UI oder didSet) jemals echte Werte in den `content.body` schrieb, und `UNCalendarNotificationTrigger(repeats: true)` diesen Body dann tagelang reproduzierte. Der neue Fix-Pfad ruft `scheduleAllNotifications()` täglich im BGTask auf → der Body wird täglich neu geschrieben mit der aktuellen API-Antwort.

## Eliminated

- "Server-side Push" — die App nutzt KEINE Server-Push-Infrastruktur. Alle Notifications sind lokal via `UNCalendarNotificationTrigger`. Der `BGAppRefreshTaskRequest` mit Identifier `de.godsapp.statflow.refresh` wird genutzt um den `content.body` aus dem laufenden App-Prozess heraus zu aktualisieren bevor der Trigger feuert. Es gibt keine APNs-Payload, keine Server-Push-Pipeline. (Bestätigt durch Code-Suche nach `UNRemoteNotification`, `APNS`, `pushToken` — keine Treffer im relevanten Code.)

- "Server-side Push-Payload-Bau-Bug" — siehe oben, es gibt keinen Server-side Notification-Payload-Bau für stats. Server-Push existiert nicht in StatFlow.

- "Stats-Decoding-Bug (e.g. `WebsiteStatsResponse` erwartet Int aber Server liefert Object)" — direkter API-Test bestätigt: Umami `/api/websites/{id}/stats` liefert `{"pageviews":N, "visitors":N, ...}` mit flachen Int-Werten. `WebsiteStatsResponse: Codable` mit `let pageviews: Int` passt. Decoding ist konsistent.

- "Init-Reihenfolge im BGTask-Handler" — der Handler nutzt `Task { @MainActor in let manager = NotificationManager(); await manager.scheduleAllNotifications() }`. `NotificationManager.init()` ruft `loadSettings()` (UserDefaults-Read, kein Problem im BGTask). `AccountManager.shared.accounts` triggert Singleton-Init mit Keychain-Read (`.afterFirstUnlock`, OK sobald User das Gerät seit Boot einmal entsperrt hat).

## Resolution

- root_cause: **Filter-Kontamination im `UmamiAPI`-Singleton-Actor.** User-Bestätigung: drei produktive Sites (julian, simon, kirche-wesselburen) zeigen 0/0/0 in der Push, obwohl das App-Dashboard für denselben Zeitraum Werte > 0 zeigt. `dataSource=.auto + notificationTime > 12:00 Uhr` heißt → DateRange `.today`. Die Discrepancy "Dashboard ≠ Push" eliminiert die Wahrnehmungs-Hypothese und bestätigt: `getStats(websiteId:dateRange:)` im BGTask-Pfad sendet zusätzliche `filterQueryItems`, die im Detail-View-Pfad gesetzt wurden und nie geräumt wurden. Dashboard-Pfad nutzt eigenes `activeFilters: [PlausibleQueryFilter]` im Dashboard-ViewModel — der Singleton-Actor-State ist ausschließlich vom Detail-View geschrieben.
- fix: Im BGTask-Handler `InsightFlowApp.handleAppRefresh(task:)` (Datei `InsightFlow/App/InsightFlowApp.swift`) den `activeFilters`-State des `UmamiAPI`-Singletons leeren, bevor `scheduleAllNotifications()` läuft. Zusätzlich am Anfang von `scheduleNotificationsForAccount` einen defensiven `setFilters([])` direkt nach `api.configure(...)`, damit auch andere Aufrufer (z. B. Settings-UI didSet) auf einem sauberen Filter-State arbeiten.
- verification: TBD — Build + manueller Test: Detail-View → Filter setzen → App in Background → BGTask manuell triggern (`e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"de.godsapp.statflow.refresh"]` im Debugger) → Pending Notifications inspizieren → `content.body` darf nicht 0/0/0 sein wenn Dashboard für Zeitraum Werte hat.
- files_changed: InsightFlow/App/InsightFlowApp.swift, InsightFlow/Services/NotificationManager.swift
