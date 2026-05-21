---
quick_id: 260521-ske
slug: notif-snapshot-today-bars
date: 2026-05-21
status: ready-for-planning
---

# Quick Task 260521-ske: Push-Notification snapshot + heutige Bars - Context

**Gathered:** 2026-05-21
**Status:** Ready for planning

<domain>
## Task Boundary

Zwei Bugs gleichzeitig fixen:

1. **Push-Notification-Bug:** Die erste Website mit aktivierten täglichen Notifications zeigt Tag für Tag DIESELBEN, eingefrorenen Werte. User-Symptom: "Nur die erste Website zeigt alte/eingefrorene Werte". Root Cause: `UNCalendarNotificationTrigger(repeats: true)` friert den `content.body` beim Planen ein. Werden Notifications nur bei App-Start/Settings-Änderung neu geplant, bleibt der erste geplante Snapshot endlos hängen.

2. **Bar-Chart-Bug aktueller Tag:** Wenn es heute nur 1 Aufruf gab, fehlen die Bars im Chart komplett (nicht falsche Höhe — komplett leer). Root Cause-Hypothese in `WebsiteDetailViewModel.fillMissingTimeSlots`: `currentHour` wird in UTC genommen (`utcCalendar.component(.hour, from: now)`), aber wenn der einzige API-Datenpunkt in einer UTC-Stunde > `currentHour` liegt (z.B. CEST = UTC+2, lokale Stunde 1:30 → UTC-Stunde 23 vom Vortag oder umgekehrt), wird er verworfen.

</domain>

<decisions>
## Implementation Decisions

### Bug 1: Push-Notification-Snapshot-Refresh
- **Lösung: BGTaskScheduler (Background App Refresh)**
- App registriert einen `BGAppRefreshTask`-Identifier (`de.godsapp.statflow.refresh-notifications`).
- Beim Backgrounding wird ein Refresh-Task für ca. 30 Min vor `notificationTime` eingeplant.
- Im Task-Handler: Stats neu laden, alle pending Notifications neu planen (gleicher Trigger, frischer Body), nächsten Refresh re-schedulen.
- Info.plist ergänzen: `BGTaskSchedulerPermittedIdentifiers` + `UIBackgroundModes` mit `fetch` und `processing`.
- Capability "Background Modes → Background fetch" in den Build Settings setzen (manuell durch User, falls Xcode-Projekt-Datei nicht direkt manipulierbar) — Task-Plan vermerkt das als Hinweis.

### Bug 2: fillMissingTimeSlots Timezone-Konsistenz
- **Lösung: `currentHour` in derselben TimeZone berechnen, in der die Slots generiert werden (UTC).**
- Tatsächlich aktuell schon UTC — aber: die `0...currentHour`-Schleife begrenzt zu hart. Wenn der API-Datenpunkt z.B. in UTC-Stunde 22 liegt aber lokal noch nicht 22 UTC erreicht ist, geht der Punkt verloren.
- Fix: `currentHour` auf das **Maximum** aus „aktuelle UTC-Stunde" und „höchste UTC-Stunde mit Daten" setzen. Damit fällt nie ein vorhandener Datenpunkt unten durch.
- Zusätzlich: für `today` muss auch der vorherige UTC-Tag berücksichtigt werden, falls in lokaler Zeit „heute" UTC-mäßig schon gestern angefangen hat. Da die Umami-API selbst pro `startAt`/`endAt` filtert (`dateRange.dates` lokal generiert), kann ein Punkt mit lokalem Zeitstempel "heute 1:30" einen UTC-Tag früher liegen. Lösung: Daten-Keys nach UTC-Datum gruppieren und die Slot-Range vom UTC-startOfDay des frühesten Datenpunkts bis UTC-jetzt erzeugen.

### Claude's Discretion
- Notification re-scheduling-Frequenz, exakte Background-Task-Implementierung (`BGTaskScheduler` Registrierung in `InsightFlowApp.swift`).
- Exakte Timezone-Fix-Implementierung in `fillMissingTimeSlots`.
- Keine UI-Änderungen am Chart selbst — die Daten müssen einfach vollständig durchkommen.

</decisions>

<specifics>
## Specific Ideas

- Notifications-Trigger bleibt `UNCalendarNotificationTrigger` mit `repeats: true` — das verhindert nur „Sofort-Aufruf der App nötig". Der Hintergrund-Task aktualisiert den Body täglich vor dem Trigger-Zeitpunkt.
- Fallback: zusätzlich beim `scenePhase == .active` aus `InsightFlowApp` `scheduleAllNotifications()` triggern (passiert vermutlich schon — verifizieren).
- Test-Strategie: BGTaskScheduler kann im Simulator via `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"…"]` getriggert werden. Für den Bar-Bug: testen mit Account auf t.godsapp.de mit nur wenigen Aufrufen heute.

</specifics>

<canonical_refs>
## Canonical References

- Apple Doc: `BGTaskScheduler` und `BGAppRefreshTaskRequest`
- Datei `InsightFlow/Services/NotificationManager.swift` (Snapshot-Bug)
- Datei `InsightFlow/Views/Detail/WebsiteDetailViewModel.swift::fillMissingTimeSlots` (Timezone-Bug)
- Datei `InsightFlow/App/InsightFlowApp.swift` (App-Lifecycle, scheduleAllNotifications-Call)
- Datei `InsightFlow/Info.plist` (BGTaskSchedulerPermittedIdentifiers)

</canonical_refs>
