# Phase 13: Critical Bug Fixes - Research

**Researched:** 2026-03-28
**Domain:** SwiftUI / Swift Concurrency / WidgetKit / iOS Caching
**Confidence:** HIGH

## Summary

Phase 13 behebt vier Bugs in einer Swift 6 / SwiftUI iOS-App ohne externe Dependencies. Die Bugs betreffen Widget-Synchronisation, fehlende Request-Cancellation, unvollständiges Cache-Lifecycle-Management und einen fehlenden Loading-State beim Account-Wechsel.

Alle vier Bugs sind direkt im bestehenden Code lokalisierbar. Die Patterns für die Lösung (Swift Concurrency Task-Cancellation, WidgetKit `reloadAllTimelines`, `@MainActor` State-Updates, FileManager-Iteration) sind alle in der App bereits vorhanden — es fehlt nur die konsequente Anwendung. Die Lösungen erfordern keine neuen Dateien.

**Primäre Empfehlung:** Task-Ownership und klare State-Resets beim Account-Wechsel sind der rote Faden durch alle vier Fixes.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
Keine getroffenen Entscheidungen — alle Implementation Choices liegen bei Claude.

### Claude's Discretion
All implementation choices are at Claude's discretion — pure infrastructure/bug-fix phase. Use ROADMAP success criteria and codebase conventions to guide decisions.

### Deferred Ideas (OUT OF SCOPE)
None — infrastructure phase.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FIX-01 | Widget Sync Race Condition — Widget zeigt nach Account-Wechsel zuverlässig aktuelle Daten innerhalb 5 Sekunden | `AccountManager.updateWidgetCredentials` + `WidgetCenter.reloadAllTimelines` bereits vorhanden; Race Condition liegt in WidgetStorage-Lese-Timing |
| FIX-02 | Request Cancellation — Offene API-Requests abbrechen wenn User navigiert | `withTaskGroup` in `WebsiteDetailViewModel.loadData` erzeugt unstrukturierten Task-Baum ohne Cancellation-Propagation |
| FIX-03 | Cache Cleanup — LRU Eviction bei >100MB + Expired-Entry Cleanup beim App-Start | `clearExpiredCache()` existiert, wird aber nie beim App-Start aufgerufen; LRU-Eviction fehlt komplett |
| FIX-04 | Account Switch Loading State — Expliziter Loading-State statt Flash alter Daten | `DashboardViewModel.loadData` setzt zuerst Cache-Daten, dann isLoading=true; kein Reset der alten Daten |
</phase_requirements>

## Standard Stack

### Core (bereits vorhanden — keine neuen Dependencies)
| Technologie | Version | Zweck | Relevanz für Phase |
|-------------|---------|-------|-------------------|
| Swift Concurrency (async/await, Task, TaskGroup) | Swift 6.0 | Structured Concurrency | FIX-02: Task-Cancellation |
| WidgetKit | iOS 17+ | Widget-Timeline-Updates | FIX-01: `reloadAllTimelines` |
| Foundation FileManager | iOS 18+ | Datei-basierter Cache | FIX-03: Expired-Cleanup, LRU |
| SwiftUI @MainActor | Swift 6.0 | UI-State-Updates | FIX-04: Loading-State |

**Keine neuen Packages nötig.** Die App hat bewusst keine externen Dependencies (PROJECT.md Constraint).

## Architecture Patterns

### Bestehende Struktur (relevant für Bugs)

```
InsightFlow/
├── Services/
│   ├── AccountManager.swift         # @MainActor, Account-Wechsel + Widget-Sync
│   └── AnalyticsCacheService.swift  # File-basierter Cache im App Group Container
├── Views/Dashboard/
│   └── DashboardView.swift          # DashboardViewModel (Zeile 747) + DashboardView
├── Views/Detail/
│   └── WebsiteDetailViewModel.swift # withTaskGroup ohne Cancellation
InsightFlowWidget/
├── Cache/WidgetCache.swift          # Separater Widget-Cache (kein TTL-Cleanup)
├── Networking/WidgetNetworking.swift # Provider (AppIntentTimelineProvider)
└── Storage/WidgetStorage.swift      # WidgetAccountsStorage
```

### Pattern 1: Swift Structured Concurrency — Task-Cancellation (FIX-02)

**Was:** `WebsiteDetailViewModel.loadData` verwendet `withTaskGroup`, aber die Task-Gruppe läuft bis zum Ende ohne Cancellation-Schutz. Wenn der User navigiert (View verschwindet), lebt die Task-Gruppe weiter.

**Lösung:** Ein `Task`-Handle im ViewModel speichern, beim Navigieren weg (`.onDisappear`) oder beim erneuten Aufrufen von `loadData` canceln.

```swift
// Quelle: Swift Concurrency Dokumentation, Apple — Task.cancel()
private var loadingTask: Task<Void, Never>?

func loadData(dateRange: DateRange) async {
    loadingTask?.cancel()
    loadingTask = Task {
        isLoading = true
        defer { isLoading = false }
        // ...withTaskGroup...
        guard !Task.isCancelled else { return }
    }
    await loadingTask?.value
}
```

**Anti-Pattern:** `try Task.checkCancellation()` in einer `@MainActor`-Klasse mit `withTaskGroup(of: Void.self)` schmeißt einen Fehler, der nicht propagiert wird — daher `Task.isCancelled` als Guard prüfen.

### Pattern 2: Widget-Synchronisation nach Account-Wechsel (FIX-01)

**Was:** `AccountManager.setActiveAccount` ruft bereits `updateWidgetCredentials` auf, welches `WidgetCenter.shared.reloadAllTimelines()` aufruft. Der Bug liegt woanders:

- `WidgetNetworking.fetchStats` lädt `WidgetAccountsStorage.loadAccounts()` — diese Funktion liest die verschlüsselte Datei aus dem App Group Container.
- Es gibt eine potenzielle Race Condition: `reloadAllTimelines()` triggert das Widget bevor `SharedCredentials.saveWidgetAccounts` fertig geschrieben hat, da beide synchron/asynchron gemischt laufen.

**Lösung:** Sicherstellen dass `saveWidgetAccounts` abgeschlossen ist bevor `reloadAllTimelines()` aufgerufen wird. Da beide synchron sind (kein `async`), reicht es sicherzustellen dass sie im gleichen Aufruf-Stack sequentiell laufen — was bereits der Fall ist. Der echte Bug ist wahrscheinlich, dass `reloadAllTimelines` das Widget mit dem alten Timeline-Cache bedient, wenn die neue Timeline schon verfügbar ist.

**Verfizierung nötig:** `WidgetCenter.shared.reloadAllTimelines()` ist async-safe und kann von jedem Thread aufgerufen werden. Das Widget re-fetcht dann via `Provider.timeline(for:in:)`. Das Widget verwendet `WidgetAccountsStorage.loadAccounts()` als erstes — dieser liest aus dem Filesystem. Wenn die App den Account-Wechsel schreibt und dann sofort `reloadAllTimelines` aufruft, muss das Filesystem-Write bereits committed sein.

**Einfachste robuste Lösung:** Nach `SharedCredentials.save` und `syncAccountsToWidget` eine kurze `Task.sleep` einfügen ist ein Anti-Pattern. Stattdessen: `WidgetCenter.shared.reloadAllTimelines()` erst am Ende von `applyAccountCredentials` aufrufen (nach dem `await`) — das stellt sicher, dass alle Async-Operationen (UmamiAPI/PlausibleAPI Rekonfiguration) abgeschlossen sind.

**Aktuelle Reihenfolge in `applyAccountCredentials`:**
1. `await UmamiAPI.shared.reconfigureFromKeychain()` (korrekt)
2. `NotificationCenter.post(accountDidChange)` (korrekt)
3. Widget-Update passiert in `updateWidgetCredentials` → `syncAccountsToWidget` → `WidgetCenter.reloadAllTimelines()`

**Problem:** `updateWidgetCredentials` wird am Ende von `applyAccountCredentials` aufgerufen. Das ist richtig. Aber `updateAccountSites` ruft auch `updateWidgetCredentials` auf — das kann zu einem frühzeitigen Widget-Reload führen bevor die API rekonfiguriert ist.

### Pattern 3: Cache Lifecycle — Expired Cleanup + LRU Eviction (FIX-03)

**Was:** `AnalyticsCacheService.clearExpiredCache()` existiert (Zeile 172), wird aber **nie aufgerufen**. LRU Eviction wenn >100MB fehlt komplett.

**Wo aufrufen:** In `InsightFlowApp.init()` oder beim App-Foreground-Event (`.scenePhase == .active`). App-Start ist die richtige Wahl — niedrige Frequenz, keine UI-Blockierung (synchrone FileManager-Iteration auf Background-Thread nötig).

**LRU Eviction Implementierung:**
- `AnalyticsCacheService.cacheSize()` existiert bereits (Zeile 223)
- Fehlende Methode: `evictOldestEntries(maxSize: Int64)` — FileManager-Attribute `creationDateKey`/`contentModificationDateKey` verwenden, nach Datum sortieren, älteste löschen bis unter Limit
- Schwellenwert: 100MB = 100 * 1024 * 1024 Bytes

**Expired-Entry Definition (FIX-03 Requirement):** Einträge >7 Tage alt. Die bestehende `clearExpiredCache()` löscht bereits Einträge nach `expiresAt` — aber `defaultTTL` ist 1 Stunde und `sparklineTTL` 15 Minuten. Für >7 Tage brauchen wir eine andere Prüfung: `cachedAt` vor 7 Tagen.

**Lösung:** Eine neue Methode `clearStaleEntries(olderThan days: Int)` hinzufügen die `cachedAt` prüft (nicht `expiresAt`). Diese beim App-Start aufrufen.

```swift
// Prüft cachedAt statt expiresAt — löscht Einträge älter als N Tage
func clearStaleEntries(olderThan days: Int = 7) {
    guard let cacheDir = cacheDirectory,
          let files = try? FileManager.default.contentsOfDirectory(
              at: cacheDir, includingPropertiesForKeys: nil) else { return }
    let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    for fileURL in files where fileURL.pathExtension == "json" {
        if let data = try? Data(contentsOf: fileURL),
           let wrapper = try? decoder.decode(CacheMetadata.self, from: data),
           wrapper.cachedAt < cutoff {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
}
```

**App-Start-Integration:**
```swift
// In InsightFlowApp.init() — bereits vorhanden, einfach anhängen
Task.detached(priority: .background) {
    AnalyticsCacheService.shared.clearStaleEntries()
    if AnalyticsCacheService.shared.cacheSize() > 100 * 1024 * 1024 {
        AnalyticsCacheService.shared.evictOldestEntries(maxSize: 100 * 1024 * 1024)
    }
}
```

### Pattern 4: Account-Wechsel Loading-State (FIX-04)

**Was:** `DashboardView.onReceive(.accountDidChange)` ruft `viewModel.loadData` auf. `loadData` macht folgendes:
1. `isLoading = true`
2. `loadFromCache(dateRange:)` — schreibt sofort alte Cache-Daten in `websites`, `stats`, `sparklineData`
3. Netzwerk-Request...

Der Flash entsteht weil: beim Account-Wechsel werden **zuerst** die gecachten Daten des *neuen* Accounts geladen (Schritt 2), aber bevor der Cache des neuen Accounts vorhanden ist, kann es passieren dass kurz die alten Daten sichtbar sind. Oder umgekehrt: die alten `websites`/`stats` bleiben im ViewModel stehen bis Schritt 2 sie überschreibt.

**Lösung:** Am Anfang von `loadData` die alten Daten explizit clearen wenn ein Account-Wechsel stattgefunden hat, und `isLoading = true` VOR dem Cache-Load setzen (was bereits der Fall ist). Was fehlt ist ein Clear der alten Published-Properties:

```swift
// Am Anfang von loadData — VOR loadFromCache
func loadData(dateRange: DateRange, accountChanged: Bool = false) async {
    if accountChanged {
        // Sofort alte Daten löschen — kein Flash
        websites = []
        stats = [:]
        sparklineData = [:]
        activeVisitors = [:]
    }
    isLoading = true
    // ...dann Cache laden (gibt ggf. direkt neue Account-Daten zurück)
```

**Alternative:** Den `onReceive(.accountDidChange)` Handler im DashboardView so anpassen dass er `accountChanged: true` übergibt.

**Kompliziertere Variante:** `isLoading` früher auf `true` setzen und in `DashboardView` auf Basis von `isLoading && websites.isEmpty` einen ProgressView zeigen (das macht der View schon: `.overlay { if viewModel.isLoading && viewModel.websites.isEmpty { ProgressView... } }`). Das Problem ist dass `websites` beim Wechsel nicht leer wird.

## Don't Hand-Roll

| Problem | Don't bauen | Verwende stattdessen | Warum |
|---------|-------------|---------------------|-------|
| HTTP-Request abbrechen | Eigenen URLSession-Wrapper | `Task.cancel()` + strukturierte Concurrency | Swift Concurrency propagiert Cancellation automatisch durch await-Ketten |
| Cache-Größe berechnen | Eigenen Byte-Counter | `FileManager.resourceValues(.fileSizeKey)` | Bereits in `cacheSize()` implementiert |
| Widget-Reload erzwingen | Polling-Loop | `WidgetCenter.shared.reloadAllTimelines()` | Bereits aufgerufen, kein Polling nötig |

## Common Pitfalls

### Pitfall 1: Task-Cancellation in @MainActor-Klassen
**Was schiefgeht:** `Task { await viewModel.loadData() }` in einer View erstellt einen unstrukturierten Task. Wenn die View verschwindet, wird der Task NICHT automatisch gecancelt. Das führt zu Battery-Drain und möglichen Crashes wenn nach View-Dealloc auf `@Published` Properties geschrieben wird.
**Warum:** Swift Structured Concurrency cancelt nur Tasks die direkt unter einem `TaskGroup`-Child hängen oder durch `.task {}` Modifier erstellt wurden. `.task {}` in SwiftUI cancelt automatisch beim View-Disappear.
**Vorbeugung:** Entweder `.task {}` Modifier statt `onAppear { Task {} }` verwenden, oder ein Task-Handle speichern und in `onDisappear` canceln.
**Warnsignal:** `Task {` in ViewModels oder `onAppear`-Handlers ohne entsprechendes Handle-Handling.

### Pitfall 2: Widget-Timeline-Timing
**Was schiefgeht:** `reloadAllTimelines()` triggert den Widget-Provider sofort. Wenn die App Group Filesystem-Writes noch nicht committed sind, liest der Widget-Provider alte Daten.
**Warum:** iOS koordiniert App-Group-Container-Zugriffe nicht automatisch zwischen App und Extension-Prozessen.
**Vorbeugung:** `reloadAllTimelines()` erst nach allen `saveWidgetAccounts`-Calls aufrufen. Beide sind synchron, also reicht sequenzieller Aufruf im gleichen Execution-Kontext.
**Warnsignal:** Widget zeigt nach Account-Wechsel sporadisch (nicht immer) falsche Daten.

### Pitfall 3: clearExpiredCache vs clearStaleEntries
**Was schiefgeht:** `clearExpiredCache` prüft `expiresAt` (1 Stunde TTL). Nach einer Stunde ist alles "expired". Das Requirement FIX-03 fordert aber das Löschen von Einträgen >7 Tage — das ist eine andere Bedingung (App-Start-Cleanup, nicht TTL-Cleanup).
**Warum:** Die App lädt immer frische Daten; expired Einträge werden trotzdem zurückgegeben (als stale Cache für Offline). "Stale" ≠ "expired" in dieser Codebase.
**Vorbeugung:** Neue Methode `clearStaleEntries(olderThan: 7)` einführen die `cachedAt` prüft.

### Pitfall 4: Flash beim Account-Wechsel durch Cache-Load
**Was schiefgeht:** `loadFromCache` in `loadData` lädt sofort die gecachten Daten des *aktuellen* Accounts — aber wenn der Account gewechselt hat und kein Cache für den neuen Account existiert, bleibt der alte `websites`-Array kurz sichtbar.
**Warum:** `websites`, `stats`, `sparklineData` werden nicht geleert bevor `loadFromCache` läuft.
**Vorbeugung:** Beim Account-Wechsel (erkennbar am `accountDidChange` Notification) explizit `websites = []` setzen vor dem ersten `loadFromCache`-Call.

### Pitfall 5: @unchecked Sendable in AnalyticsCacheService
**Was schiefgeht:** `AnalyticsCacheService` ist als `@unchecked Sendable` markiert. Das bedeutet die Swift-Concurrency-Checks sind für diese Klasse deaktiviert. Wenn `clearStaleEntries` und `evictOldestEntries` von einem Background-Task aufgerufen werden, gibt es potentielle Data Races mit dem Main-Thread-Cache-Zugriff.
**Vorbeugung:** `Task.detached(priority: .background)` für Cache-Cleanup ist OK da die Cache-Operationen filesystem-basiert sind (atomic writes). Aber niemals gleichzeitig `clearAllCache()` und einen `save()` Call starten.

## Code Examples

### FIX-02: Task-Handle-Pattern für ViewModels

```swift
// Quelle: Swift Concurrency Dokumentation
// In WebsiteDetailViewModel (bereits @MainActor):
private var loadingTask: Task<Void, Never>?

func loadData(dateRange: DateRange) async {
    loadingTask?.cancel()
    loadingTask = Task { [weak self] in
        guard let self else { return }
        self.isLoading = true
        defer {
            if !Task.isCancelled { self.isLoading = false }
        }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadStats(dateRange: dateRange) }
            // ... andere Tasks
        }
    }
    await loadingTask?.value
}

// In WebsiteDetailView — bereits .task{} pattern nutzbar:
// .task(id: dateRange) { await viewModel.loadData(dateRange: dateRange) }
// SwiftUI cancelt diesen Task automatisch beim Navigieren weg.
```

### FIX-03: Cache-Startup-Cleanup in InsightFlowApp.init()

```swift
// In PrivacyFlowApp.init() — bestehende init() Methode ergänzen:
init() {
    registerBackgroundTasks()
    // Cache-Cleanup im Hintergrund beim App-Start
    Task.detached(priority: .background) {
        AnalyticsCacheService.shared.clearStaleEntries(olderThan: 7)
        let maxCacheSize: Int64 = 100 * 1024 * 1024 // 100MB
        if AnalyticsCacheService.shared.cacheSize() > maxCacheSize {
            AnalyticsCacheService.shared.evictOldestEntries(maxSize: maxCacheSize)
        }
    }
}
```

### FIX-04: Alten State löschen beim Account-Wechsel

```swift
// In DashboardView — onReceive Handler anpassen:
.onReceive(NotificationCenter.default.publisher(for: .accountDidChange)) { _ in
    if !showAllAccounts {
        Task {
            await viewModel.loadData(dateRange: selectedDateRange, clearFirst: true)
        }
    }
}

// In DashboardViewModel.loadData — optionaler clearFirst-Parameter:
func loadData(dateRange: DateRange, clearFirst: Bool = false) async {
    if clearFirst {
        websites = []
        stats = [:]
        sparklineData = [:]
        activeVisitors = [:]
    }
    isLoading = true
    loadWebsiteOrder()
    loadFromCache(dateRange: dateRange)
    // ...
}
```

## Validation Architecture

`nyquist_validation` ist nicht explizit deaktiviert → Validierungsarchitektur ist relevant.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (Apple, kein SPM) |
| Config file | InsightFlow.xcodeproj (kein separates Config-File) |
| Quick run command | `xcodebuild test -project InsightFlow.xcodeproj -scheme InsightFlow -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -30` |
| Full suite command | gleich wie Quick run |

### Phase Requirements → Test Map

| Req ID | Verhalten | Test-Typ | Testbar mit | Datei vorhanden? |
|--------|-----------|----------|-------------|-----------------|
| FIX-01 | Widget reload nach Account-Wechsel | unit/integration | Manuell + WidgetCenter-Mock | ✅ AccountManagerTests.swift (erweitern) |
| FIX-02 | loadingTask?.cancel() cancelt laufende Tasks | unit | Task-Handle-Test in neuem TestFile | ❌ Wave 0 |
| FIX-03 | clearStaleEntries löscht Einträge >7 Tage | unit | AnalyticsCacheServiceTests.swift erweitern | ✅ vorhanden (erweitern) |
| FIX-03 | evictOldestEntries reduziert Cache auf <100MB | unit | AnalyticsCacheServiceTests.swift erweitern | ✅ vorhanden (erweitern) |
| FIX-04 | websites=[] beim Account-Wechsel vor loadFromCache | unit | DashboardViewModelTests (neu) | ❌ Wave 0 |

### Wave 0 Gaps

- [ ] `InsightFlowTests/WebsiteDetailViewModelTests.swift` — prüft FIX-02 Task-Cancellation
- [ ] `InsightFlowTests/DashboardViewModelTests.swift` — prüft FIX-04 clearFirst-Behavior

*`AnalyticsCacheServiceTests.swift` existiert und kann direkt mit neuen Test-Cases für FIX-03 erweitert werden — kein neues File nötig.*

## Environment Availability

Step 2.6: SKIPPED (keine externen Dependencies — reine Code-Änderungen in bestehenden Swift-Dateien)

## Sources

### Primary (HIGH confidence)
- Direkter Code-Review aller betroffenen Dateien (AccountManager.swift, AnalyticsCacheService.swift, DashboardView.swift, WebsiteDetailViewModel.swift, WidgetNetworking.swift, WidgetCache.swift, WidgetStorage.swift)
- PROJECT.md + REQUIREMENTS.md — Constraints und Anforderungen

### Secondary (MEDIUM confidence)
- Swift Concurrency Dokumentation (Apple) — Task.cancel(), Task.isCancelled Pattern
- WidgetKit Dokumentation — WidgetCenter.reloadAllTimelines Semantik

## Open Questions

1. **FIX-01: Ist der Widget-Bug tatsächlich ein Timing-Problem oder etwas anderes?**
   - Was wir wissen: `reloadAllTimelines` wird nach `syncAccountsToWidget` aufgerufen
   - Was unklar ist: Ob `saveWidgetAccounts` (verschlüsselt + filesystem write) jemals NACH `reloadAllTimelines` committet — d.h. ob iOS die Reihenfolge garantiert
   - Empfehlung: FIX-01 als "Widget lädt nach 15 Minuten automatisch neu" testen — wenn das Widget nach 5 Sekunden noch falsche Daten zeigt, ist es ein Timing-Bug; wenn es erst nach 15 Minuten richtig wird, ist das der normale WidgetKit-Refresh-Zyklus

2. **FIX-02: Welche ViewModels sind betroffen?**
   - Was wir wissen: `WebsiteDetailViewModel.loadData` verwendet unstrukturierten `withTaskGroup`
   - Was unklar ist: Ob `CompareViewModel`, `EventsViewModel`, `ReportsViewModel` das gleiche Anti-Pattern haben
   - Empfehlung: Alle ViewModels auf `Task {` ohne Handle prüfen — Scope des Fix ggf. ausweiten

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH — direkt aus Codebase
- Architecture: HIGH — direkt aus Codebase, alle relevanten Dateien gelesen
- Pitfalls: HIGH — aus direktem Code-Review + Swift Concurrency Dokumentation
- Testability: MEDIUM — XCTest-Infrastruktur vorhanden, aber ViewModelTests müssen neu angelegt werden

**Research date:** 2026-03-28
**Valid until:** 2026-06-28 (stabiler Stack, keine externen Dependencies)
