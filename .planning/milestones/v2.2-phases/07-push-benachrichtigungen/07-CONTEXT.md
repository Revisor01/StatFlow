# Phase 07: Push-Benachrichtigungen - Context

**Gathered:** 2026-03-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Push-Benachrichtigungs-Logik überarbeiten: Strukturierte Gruppierung statt flacher Liste. Skaliert bei vielen Websites. Settings-UI übersichtlicher gestalten.

</domain>

<decisions>
## Implementation Decisions

### Notification-Architektur
- Bestehende NotificationManager-Architektur beibehalten (BGAppRefreshTask, UNUserNotificationCenter)
- NotificationSetting enum beibehalten (disabled/daily/weekly)
- Notification-Time und DataSource (today/yesterday/auto) beibehalten

### Gruppierung & Skalierung
- Notifications nach Account gruppieren statt flache Website-Liste
- Bei 5+ Websites pro Account: Summary-Notification statt einzelne Notifications pro Website
- Summary zeigt Gesamtstatistiken + Top-Änderungen (höchster %-Anstieg)
- Einzelne Websites mit .daily oder .weekly behalten individuelle Notification
- UNNotificationCategory + threadIdentifier für Notification-Gruppierung nutzen

### Settings-UI
- Settings nach Account gruppieren (Section pro Account)
- "Alle an" / "Alle aus" Toggle pro Account
- Bestehende per-Website Einstellung (disabled/daily/weekly) beibehalten
- Collapsed-State für Accounts mit vielen Websites

### Claude's Discretion
- Exakte Summary-Notification Formatierung
- Schwelle ab wann Summary statt Einzel-Notifications (Vorschlag: 5+)
- Sortierung innerhalb der Account-Sections

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- NotificationManager.swift — @MainActor class, UserDefaults-basierte Settings, BGAppRefreshTask
- NotificationSetting enum (disabled/daily/weekly)
- NotificationDataSource enum (today/yesterday/auto)
- sendScheduledNotifications() — iteriert Accounts+Websites, fetched Stats, erstellt UNNotificationRequest
- scheduleAllNotifications() — erstellt UNCalendarNotificationTrigger

### Established Patterns
- Per-Website Settings in [String: NotificationSetting] Dictionary (UserDefaults "notificationSettings")
- notificationTime: Date (UserDefaults "notificationTime")
- SettingsView enthält Notification-Section mit DatePicker, DataSource Picker, per-Website NotificationSettingRow

### Integration Points
- InsightFlowApp.swift — BGTaskScheduler Registration
- SettingsView.swift — Notification Settings UI (Zeilen in der Notifications Section)
- AccountManager.shared — Account-Liste für Gruppierung

</code_context>

<specifics>
## Specific Ideas

- User will "strukturierte Gruppierung statt einer plumpen Liste"
- Problem bei vielen Seiten: Notification-Flood und unübersichtliche Settings
- Lösung: Account-basierte Gruppierung + Summary-Notifications

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>
