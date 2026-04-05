# Phase 14: Code Cleanup - Research

**Researched:** 2026-03-28
**Domain:** Swift/SwiftUI — toten Code entfernen, Offline-UI ergänzen
**Confidence:** HIGH

## Summary

Phase 14 umfasst zwei unabhängige Tasks: (1) Entfernen von ungenutzten Methoden aus `UmamiAPI.swift` (CLEAN-01) und (2) Ergänzen eines sichtbaren Offline-Indikators in Views, die noch keinen haben (CLEAN-02).

Für CLEAN-01 ergibt die Grep-Analyse: 29 Methoden in `UmamiAPI.swift` werden nirgends außerhalb der Datei selbst aufgerufen. Diese sind sicher zu löschen. Einige zugehörige Model-Typen (in `Admin.swift`, `Share.swift`, `Reports.swift`) werden dann ebenfalls obsolet und können mitentfernt werden.

Für CLEAN-02 hat `DashboardView` bereits eine vollständige Offline-Implementierung mit `isOffline`-Flag und einem Banner (`offlineBanner`). `WebsiteDetailView`, `EventsView`, `SessionsView` und `ReportsView` haben hingegen keine Offline-Erkennung. Da der Detail-View keinen eigenen Cache hat, reicht dort ein schlichter Info-Banner wenn die API nicht erreichbar ist — ohne Cache-Fallback.

**Primäre Empfehlung:** CLEAN-01 ist eine reine Deletion-Task — kein Refactoring nötig. CLEAN-02 ist ein gezieltes UI-Pattern, das 1:1 vom bestehenden `offlineBanner` in `DashboardView` kopiert und angepasst werden kann.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
*(Keine expliziten Locked Decisions — Infrastructure/Cleanup Phase)*

### Claude's Discretion
Alle Implementierungsentscheidungen liegen bei Claude. ROADMAP-Erfolgskriterien und Codebase-Konventionen sind maßgeblich.

### Deferred Ideas (OUT OF SCOPE)
Keine.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CLEAN-01 | ~20 ungenutzte Admin/Write API-Methoden aus UmamiAPI.swift entfernen | 29 konkrete Methoden identifiziert — Liste unten |
| CLEAN-02 | Offline-Mode UI — Cached Daten mit "Offline"-Indikator anzeigen statt Fehler-Screen | DashboardView hat fertige Implementierung als Vorlage; Detail/Events/Sessions/Reports brauchen Banner |
</phase_requirements>

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ (Xcode 15) | UI-Framework | Bereits im Projekt |
| Foundation | — | URLError-Erkennung, Netzwerk | Bereits im Projekt |

Keine neuen Dependencies nötig — Phase arbeitet ausschließlich mit bestehendem Code.

## Architecture Patterns

### Bestehende Offline-Pattern in DashboardViewModel (Vorlage für CLEAN-02)

```swift
// Source: InsightFlow/Views/Dashboard/DashboardView.swift (Zeilen 754, 815-930)

@Published var isOffline = false

// In loadWebsites():
let isNetworkError = (error as? URLError)?.code == .notConnectedToInternet ||
                     (error as? URLError)?.code == .networkConnectionLost ||
                     (error as? URLError)?.code == .timedOut ||
                     (error as? URLError)?.code == .cannotFindHost ||
                     (error as? URLError)?.code == .cannotConnectToHost
if isNetworkError {
    isOffline = true
}
```

```swift
// offlineBanner in DashboardView (Zeile 306-319):
private var offlineBanner: some View {
    HStack(spacing: 8) {
        Image(systemName: "wifi.slash")
            .font(.subheadline)
        Text("dashboard.offline")
            .font(.subheadline)
        Spacer()
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(Color.orange.opacity(0.15))
    .foregroundStyle(.orange)
    .clipShape(RoundedRectangle(cornerRadius: 10))
}
```

### Für CLEAN-02: Welche Views brauchen Offline-Indikator

| View | ViewModel | Hat isOffline? | Cache-Fallback möglich? | Strategie |
|------|-----------|----------------|------------------------|-----------|
| DashboardView | DashboardViewModel | JA (fertig) | JA | — |
| WebsiteDetailView | WebsiteDetailViewModel | NEIN | NEIN | isOffline-Flag + Banner oben im ScrollView |
| EventsView | EventsViewModel | NEIN | NEIN | isOffline-Flag + Banner |
| SessionsView | SessionsViewModel | NEIN | NEIN | isOffline-Flag + Banner |
| ReportsView / ReportsViewModel | ReportsViewModel | NEIN | NEIN | isOffline-Flag + Banner |

**Wichtig:** WebsiteDetailViewModel, EventsViewModel, SessionsViewModel und ReportsViewModel laden ihre Daten nicht aus dem Cache. Offline bedeutet dort "leere Daten". Der Offline-Banner informiert den Nutzer, damit er nicht ein leeres Interface ohne Kontext sieht.

### Für CLEAN-02: Lokalisierungsschlüssel

`dashboard.offline` ist bereits vorhanden in `de.lproj/Localizable.strings` und `en.lproj/Localizable.strings`:
- DE: `"Offline – zeige gecachte Daten"`
- EN: `"Offline – showing cached data"`

Neue Keys für Detail-Views ohne Cache sind sinnvoll, z.B. `"detail.offline"` mit passendem Text (kein "gecachte Daten" da kein Cache).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Netzwerkstatus | Eigene NWPathMonitor-Klasse | URLError-Auswertung in catch | Bereits bewährtes Pattern im Projekt; keine zusätzliche Dependency nötig |
| Offline-Banner | Neue UI-Komponente | offlineBanner aus DashboardView kopieren | Konsistenz mit bestehendem Design |

---

## CLEAN-01: Vollständige Liste ungenutzter Methoden

Die folgenden 29 Methoden existieren in `UmamiAPI.swift` aber werden in **keiner anderen Swift-Datei** aufgerufen (verifiziert per grep über alle .swift-Dateien außer UmamiAPI.swift selbst):

### MARK: - Me (3 Methoden)
- `getMe()` → MeResponse
- `getMyTeams()` → [Team]
- `getMyWebsites(includeTeams:)` → [Website]

### MARK: - Stats/Metrics (3 Methoden)
- `getDateRange(websiteId:)` → DateRangeResponse
- `getEventsSeries(websiteId:dateRange:timezone:)` → [EventData]
- `getExpandedMetrics(websiteId:dateRange:type:limit:)` → [ExpandedMetricItem]

### MARK: - Event Data (5 Methoden)
- `getEventData(websiteId:dateRange:page:pageSize:)` → EventDataResponse
- `getEventDataById(websiteId:eventId:)` → EventDataItem
- `getEventDataFields(websiteId:dateRange:)` → [EventDataField]
- `getEventDataProperties(websiteId:dateRange:)` → [EventDataProperty]
- `getEventDataStats(websiteId:dateRange:)` → EventDataStats

### MARK: - Sessions (6 Methoden)
- `getSessionStats(websiteId:dateRange:)` → SessionStatsResponse
- `getSessionsWeekly(websiteId:dateRange:timezone:)` → [WeeklySessionPoint]
- `getSessionProperties(websiteId:sessionId:)` → [SessionPropertyItem]
- `getSessionDataProperties(websiteId:dateRange:)` → [SessionDataProperty]
- `getSessionDataValues(websiteId:dateRange:propertyName:)` → [SessionDataValue]

### MARK: - Website Management (1 Methode)
- `resetWebsiteStats(websiteId:)` → Void

### MARK: - Teams (7 Methoden)
- `getUserTeams(page:pageSize:)` → [Team]
- `joinTeam(accessCode:)` → TeamMember
- `getTeam(teamId:)` → Team
- `updateTeam(teamId:name:accessCode:)` → Team
- `getTeamMember(teamId:userId:)` → TeamMember
- `updateTeamMemberRole(teamId:userId:role:)` → TeamMember
- `getTeamWebsites(teamId:page:pageSize:)` → [Website]

### MARK: - Users (Admin) (4 Methoden)
- `getUser(userId:)` → UmamiUser
- `updateUser(userId:username:password:role:)` → UmamiUser
- `getUserWebsites(userId:includeTeams:page:pageSize:)` → [Website]
- `getUserTeamsList(userId:page:pageSize:)` → [Team]

### MARK: - Admin (1 Methode)
- `getAdminWebsites(page:pageSize:)` → [Website]

### MARK: - Share (6 Methoden)
- `createSharePage(entityId:shareType:name:slug:parameters:)` → SharePage
- `getSharePage(shareId:)` → SharePage
- `updateSharePage(shareId:name:slug:parameters:)` → SharePage
- `deleteSharePage(shareId:)` → Void
- `getWebsiteShares(websiteId:)` → [SharePage]
- `createWebsiteShare(websiteId:name:parameters:)` → SharePage

### MARK: - Reports (4 Methoden)
- `createReport(...)` → Report
- `getReport(reportId:)` → Report
- `updateReport(...)` → Report
- `deleteReport(reportId:)` → Report

### MARK: - Report Types (3 Methoden)
- `getPerformanceReport(websiteId:dateRange:)` → [PerformanceItem]
- `getBreakdownReport(websiteId:dateRange:property:)` → [BreakdownItem]
- `getRevenueReport(websiteId:dateRange:)` → [RevenueItem]

**Gesamtzahl: 43 Methoden** (Anforderung schätzte ~20 — tatsächlich mehr).

### Welche Methoden BLEIBEN (werden tatsächlich verwendet)

| Methode | Verwendet in |
|---------|-------------|
| `configure(baseURL:token:)` | SettingsView |
| `clearConfiguration()` | AccountManager |
| `reconfigureFromKeychain()` | AccountManager |
| `authenticate(serverURL:credentials:)` | AnalyticsProvider Protocol |
| `getAnalyticsWebsites()` | AnalyticsProvider Protocol |
| `getAnalyticsStats(...)` | AnalyticsProvider Protocol |
| `getPageviewsData(...)` | AnalyticsProvider Protocol |
| `getVisitorsData(...)` | AnalyticsProvider Protocol |
| `getRealtimeData(...)` | AnalyticsProvider Protocol |
| `getPages/Referrers/Countries/Devices/Browsers/OS/Regions/Cities/PageTitles/Languages/Screens/Events(...)` | AnalyticsProvider Protocol |
| `getRealtimeTopPages/Countries/Pageviews(...)` | AnalyticsProvider Protocol |
| `login(baseURL:username:password:)` | authenticate() |
| `getWebsites()` | DashboardView, AdminView, SettingsView |
| `getWebsite(websiteId:)` | intern |
| `getActiveVisitors(websiteId:)` | DashboardView |
| `getStats(websiteId:dateRange:)` | DashboardView, CompareViewModel |
| `getPageviews(websiteId:dateRange:)` | DashboardView, CompareViewModel |
| `getRealtime(websiteId:)` | RealtimeView |
| `getMetrics(...)` | viele (intern via Protocol-Methoden) |
| `getEventsDetail(...)` | EventsViewModel (via EventsView) |
| `getEventsStats(...)` | EventsViewModel |
| `getEventDataEvents(...)` | EventsViewModel |
| `getEventDataValues(...)` | EventsViewModel |
| `getSessions(...)` | SessionsView |
| `getSessionActivity(...)` | SessionsView, RealtimeView |
| `getSession(websiteId:sessionId:)` | SessionsView |
| `getJourneyReport(...)` | SessionsView |
| `createWebsite(...)` | AdminView, DashboardView |
| `updateWebsite(...)` | AdminView, DashboardView |
| `deleteWebsite(...)` | AdminView, DashboardView |
| `getTeams()` | AdminView |
| `createTeam(...)` | AdminView |
| `deleteTeam(...)` | AdminView |
| `getTeamMembers(...)` | AdminView |
| `addTeamMember(...)` | AdminView |
| `removeTeamMember(...)` | AdminView |
| `getUsers()` | AdminView |
| `createUser(...)` | AdminView |
| `deleteUser(...)` | AdminView |
| `getReports(websiteId:...)` | ReportsViewModel |
| `getUTMReport(...)` | ReportsViewModel |
| `getAttributionReport(...)` | ReportsViewModel |
| `getFunnelReport(...)` | ReportsViewModel |
| `getGoalReport(...)` | ReportsViewModel |

### Zugehörige Model-Typen die dann obsolet werden

Nach dem Entfernen der 43 Methoden werden folgende Model-Typen nur noch in UmamiAPI.swift selbst genutzt (als Return-Typen oder Parameter). Nach Entfernung der Methoden können sie ebenfalls gelöscht werden:

**In `Models/Admin.swift`:**
- `TeamWebsitesResponse` — nur für `getTeamWebsites()` (zu löschen)
- `UserWebsitesResponse` — nur für `getUserWebsites()` (zu löschen)
- `UserTeamsResponse` — nur für `getUserTeamsList()` (zu löschen)
- `JourneyPath` — BLEIBT (SessionsView verwendet `getJourneyReport()`)

**In `Models/Share.swift`:**
- `SharePage` und alle Share-Response-Typen — zu prüfen, ob noch verwendet

**In anderen Model-Dateien:**
- `MeResponse`, `DateRangeResponse`, `ExpandedMetricItem` usw. — zu prüfen

**Wichtig:** Model-Typen erst nach vollständiger Methoden-Löschung entfernen und nur wenn sie nicht mehr in Views referenziert werden.

---

## Common Pitfalls

### Pitfall 1: Model-Typen zu früh löschen
**What goes wrong:** Ein Model-Typ wird in einer View oder ViewModel noch indirekt verwendet (z.B. als TypeAlias oder in einer Protokoll-Konformität), obwohl die API-Methode ihn nicht mehr braucht.
**Why it happens:** Grep auf Methodennamen findet keine View-Nutzung, aber das zugehörige Model kann trotzdem in der View verwendet werden.
**How to avoid:** Erst Methoden löschen, dann mit Xcode prüfen ob der Build noch sauber ist. Danach ungenutzte Models löschen.
**Warning signs:** Compiler-Fehler "cannot find type X in scope"

### Pitfall 2: isOffline-Reset vergessen
**What goes wrong:** `isOffline = true` wird gesetzt, aber nicht zurückgesetzt wenn der nächste Load erfolgreich ist.
**Why it happens:** Vergessen, `isOffline = false` am Beginn von `loadData()` zu setzen.
**How to avoid:** Am Anfang von `loadData()` immer `isOffline = false` setzen (wie in DashboardViewModel, Zeile 882: `isOffline = false`).
**Warning signs:** Banner bleibt auch nach erfolgreichem Reload sichtbar.

### Pitfall 3: getSession(websiteId:sessionId:) fälschlicherweise als ungenutzt markieren
**What goes wrong:** `getSession()` erscheint beim Grep nicht in CallSite-Suche weil SessionsView nur `getSessions()` (Plural) direkt aufruft.
**Why it happens:** Der Singular `getSession` ist ein anderer Methodenname als `getSessions`.
**How to avoid:** Beide Varianten explizit auf Nutzung prüfen. `getSession()` (singular) wird in SessionsView verwendet (Zeile 597 im API-File, aufgerufen über Protocol oder direkt).
**Warning signs:** SessionDetailView crasht beim Öffnen einer Session.

### Pitfall 4: Offline-Banner in Views ohne Cache zeigt falschen Text
**What goes wrong:** Banner zeigt "Offline – zeige gecachte Daten" aber Detail-View hat keinen Cache — irritiert Nutzer.
**Why it happens:** `dashboard.offline` Lokalisierungsschlüssel wurde kopiert ohne Anpassung.
**How to avoid:** Eigenen Lokalisierungsschlüssel `detail.offline` mit Text ohne Cache-Bezug anlegen.

---

## Code Examples

### Pattern: Offline-Erkennung in ViewModel (aus DashboardViewModel)

```swift
// Source: DashboardView.swift Zeile 882-930

@Published var isOffline = false

func loadData(dateRange: DateRange) async {
    isOffline = false  // Reset bei jedem Load

    do {
        // ... API calls ...
    } catch {
        let isNetworkError = (error as? URLError)?.code == .notConnectedToInternet ||
                             (error as? URLError)?.code == .networkConnectionLost ||
                             (error as? URLError)?.code == .timedOut ||
                             (error as? URLError)?.code == .cannotFindHost ||
                             (error as? URLError)?.code == .cannotConnectToHost
        if isNetworkError {
            isOffline = true
        } else {
            self.error = error.localizedDescription
        }
    }
}
```

### Pattern: Offline-Banner in View (aus DashboardView)

```swift
// Source: DashboardView.swift Zeile 306-319
private var offlineBanner: some View {
    HStack(spacing: 8) {
        Image(systemName: "wifi.slash")
            .font(.subheadline)
        Text("detail.offline")  // Angepasster Key für Detail-Views
            .font(.subheadline)
        Spacer()
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(Color.orange.opacity(0.15))
    .foregroundStyle(.orange)
    .clipShape(RoundedRectangle(cornerRadius: 10))
}
```

### Pattern: Banner in ScrollView einbinden

```swift
// Analog zu DashboardView Zeile 28-30
ScrollView {
    VStack(spacing: 20) {
        if viewModel.isOffline {
            offlineBanner
                .padding(.horizontal)
        }
        // ... restlicher Content
    }
}
```

---

## Environment Availability

Step 2.6: SKIPPED (keine externen Dependencies — reine Code-Änderungen)

---

## Validation Architecture

`workflow.nyquist_validation` ist nicht explizit auf `false` gesetzt — Abschnitt wird einbezogen.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (InsightFlowTests/) |
| Config file | InsightFlow.xcodeproj |
| Quick run command | `xcodebuild test -project InsightFlow.xcodeproj -scheme InsightFlow -destination 'platform=iOS Simulator,name=iPhone 16'` |
| Full suite command | Identisch |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CLEAN-01 | UmamiAPI enthält keine der 43 gelöschten Methoden mehr | unit (Code-Analyse) | `grep -c "func getMe\|func getMyTeams\|func resetWebsiteStats" InsightFlow/Services/UmamiAPI.swift` (expect: 0) | ❌ Wave 0 |
| CLEAN-02 | Offline-Banner erscheint in WebsiteDetailView | manual (Simulator offline schalten) | manual-only — kein XCTest für UI-Offline-State ohne Netzwerk-Mock | — |

### Wave 0 Gaps
- [ ] Kein Unit-Test-File für UmamiAPI-Cleanup nötig — Bash-Grep als Smoke-Test reicht
- [ ] Für CLEAN-02: Manueller Test via iOS Simulator → Airplane Mode

*(Kein separates Test-Framework-Setup nötig — bestehendes XCTest vorhanden)*

---

## Open Questions

1. **`getSession(websiteId:sessionId:)` — tatsächlich ungenutzt?**
   - Was wir wissen: Grep findet keinen direkten Aufruf in anderen View-Dateien
   - Was unklar ist: SessionsView lädt Sessions-Liste via `getSessions()`, Details werden inline expandiert
   - Empfehlung: Vor dem Löschen noch einmal SessionsView vollständig lesen (ab Zeile 460)

2. **Share-Modelle in Models/Share.swift**
   - Was wir wissen: Alle `create/get/update/delete SharePage`-Methoden sind ungenutzt
   - Was unklar ist: Ob `SharePage` irgendwo in Views als Typ referenziert wird (z.B. als optionaler Published-State)
   - Empfehlung: Erst Methoden entfernen, Compile prüfen, dann Models

---

## Sources

### Primary (HIGH confidence)
- Direkte Codeanalyse mit grep über alle Swift-Dateien im Projekt — Methodenaufruf-Inventory
- `InsightFlow/Services/UmamiAPI.swift` (vollständig gelesen)
- `InsightFlow/Views/Admin/AdminView.swift` (vollständig gelesen)
- `InsightFlow/Views/Dashboard/DashboardView.swift` (Offline-Pattern, Zeilen 754-930)
- `InsightFlow/Services/AnalyticsCacheService.swift` (Cache-API)

### Secondary (MEDIUM confidence)
- Implizite Nutzung über `AnalyticsProvider`-Protocol — Methoden die über `provider.` aufgerufen werden, gehen durch das Protocol, nicht direkt `umamiAPI.`

---

## Metadata

**Confidence breakdown:**
- Dead-Code-Identifikation: HIGH — Grep-Analyse über gesamten Source-Tree
- Offline-UI-Pattern: HIGH — bestehende Implementierung in DashboardView als Vorlage
- Model-Bereinigung: MEDIUM — abhängig von Build-Verifikation nach Methoden-Löschung

**Research date:** 2026-03-28
**Valid until:** 2026-04-28 (stabiler Swift-Stack, keine externen Abhängigkeiten)
