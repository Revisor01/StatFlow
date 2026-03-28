# Phase 2: Quick Wins & Widget Split - Research

**Researched:** 2026-03-27
**Domain:** Swift/SwiftUI Refactoring — Print-Statement-Cleanup, Widget Extension Splitting, View Decomposition
**Confidence:** HIGH (pure code-level analysis, kein externes Ecosystem-Wissen noetig)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
Keine — pure Infrastruktur-Phase ohne explizite User-Entscheidungen.

### Claude's Discretion
All implementation choices are at Claude's discretion — pure infrastructure/refactoring phase. Key technical context:

- Phase 1 (Security Hardening) hat AccountManager und SharedCredentials modifiziert — Widget-Code liest jetzt encrypted `widget_accounts.encrypted` statt plaintext JSON
- Print-Statements: 66 `print()` calls ueber 21 Dateien — alle in `#if DEBUG` wrappen oder entfernen
- Widget-Monolith: `InsightFlowWidget/InsightFlowWidget.swift` (2004 Zeilen) enthaelt Models, Credential Storage, API Networking, UI Views, Cache Logic und App Intents — in separate Dateien aufteilen
- Grosse Views: `WebsiteDetailView.swift` (1611), `AdminView.swift` (1318), `CompareView.swift` (1183) — Subviews extrahieren
- Widget verwendet Swift 5.0, Main App Swift 6.0 — beim Split beachten
- Xcode 16+ mit `PBXFileSystemSynchronizedRootGroup` — neue Dateien werden automatisch erkannt

### Deferred Ideas (OUT OF SCOPE)
Keine explizit deferierten Ideen — Scope ist auf STAB-03, STRUC-01, STRUC-02 beschraenkt.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| STAB-03 | Print-Statements in `#if DEBUG` gewrappt oder entfernt | Audit: 32 unwrapped prints in 17 Dateien identifiziert; widgetLog-Funktion in Widget ebenfalls zu wrappen |
| STRUC-01 | Widget-Code in separate Dateien aufgeteilt (Models, Networking, Cache, Views, Intents) | MARK-Sektionen kartiert; 7 logische Gruppen identifiziert; PBXFileSystemSynchronizedRootGroup bestaetigt |
| STRUC-02 | Grosse Views (WebsiteDetailView, AdminView, CompareView) in Subviews extrahiert | Sektionsgroessen analysiert; klare Kandidaten fuer Extraktion gefunden |
</phase_requirements>

## Summary

Phase 2 ist eine reine Refactoring-Phase ohne Verhaltensaenderungen. Die drei Requirements sind technisch klar abgegrenzt: Print-Statement-Cleanup (32 noch nicht gewrappte Calls in 17 Dateien), Widget-Datei-Split (2034 Zeilen mit klaren MARK-Sektionen als natuerliche Trennlinien), und View-Extraktion in drei grossen Views.

Der Audit des tatsaechlichen Code-Zustands nach Phase 1 zeigt, dass einige print()-Calls bereits korrekt in `#if DEBUG` gewrappt sind (37 von 69 Gesamt-Calls). 32 Calls fehlen noch. Die `widgetLog`-Funktion im Widget ist als einzige direkte `print()`-Zeile in der Widget-Datei zu behandeln — sie ist eine Wrapper-Funktion, kein direkt sichtbarer print-Call.

Das Widget verwendet Swift 5.0 (bestaetigt via project.pbxproj), die Main App Swift 6.0. Beim Split muss jede neue Widget-Datei mit Swift 5.0-kompatiblem Code verfasst werden — konkret bedeutet das: kein `Sendable`-Concurrency-Enforcement, keine strict concurrency checks. Da `PBXFileSystemSynchronizedRootGroup` im Xcode-Projekt vorhanden ist (4 Treffer in pbxproj), werden neue Dateien im `InsightFlowWidget/`-Verzeichnis automatisch erkannt ohne pbxproj-Aenderung.

**Primaere Empfehlung:** Drei separate Tasks: (1) #if DEBUG Sweep ueber alle 17 Dateien, (2) Widget-Split in 6 neue Dateien, (3) View-Extraktion aus WebsiteDetailView/AdminView/CompareView. Keine Verhaltensaenderungen, nur strukturelle Verschiebungen.

## Standard Stack

### Core (Swift/SwiftUI Patterns)
| Pattern | Version | Zweck | Begruendung |
|---------|---------|-------|-------------|
| `#if DEBUG` Compiler-Direktive | Swift 5+ | Print-Calls auf Debug-Builds einschraenken | Apple-Empfehlung fuer Debug-Logging; kein Performance-Overhead in Release |
| `private func widgetLog(_ message: String)` | Swift 5.0 | Zentraler Logging-Wrapper im Widget | Bereits vorhanden — nur Inhalt wrappen |
| SwiftUI View Decomposition | iOS 16+ | Subviews in eigene `struct View`-Typen | Standard SwiftUI-Muster; verbessert Xcode-Preview-Isolation |
| `// MARK: -` als Trennlinie | Swift | Natuerliche Splits im Monolith | Bereits vorhanden im Widget und in allen Views |

### Keine externen Dependencies
Diese Phase fuehrt keine neuen Libraries ein. Alle Aenderungen sind rein strukturell im bestehenden Swift-Code.

## Architecture Patterns

### Empfohlene Widget-Dateistruktur nach Split

```
InsightFlowWidget/
├── InsightFlowWidget.swift          # Nur noch: PrivacyFlowWidget + PrivacyFlowWidgetEntryView (~60 Zeilen)
├── InsightFlowWidgetBundle.swift    # Unveraendert (schon eigenstaendig)
├── InsightFlowWidgetLiveActivity.swift  # Unveraendert (schon eigenstaendig)
├── Models/
│   ├── WidgetModels.swift           # WidgetProviderType, WidgetAccount, WidgetData, StatsEntry (~160 Zeilen)
│   └── WidgetTimeRange.swift        # WidgetTimeRange enum + WidgetChartStyle enum (~80 Zeilen)
├── Storage/
│   └── WidgetStorage.swift          # WidgetAccountsStorage + WidgetCredentials (~270 Zeilen)
├── Cache/
│   └── WidgetCache.swift            # WidgetCache struct (~120 Zeilen)
├── Intents/
│   └── WidgetIntents.swift          # AccountEntity, WebsiteEntity, WebsiteQuery, ConfigureWidgetIntent, FilteredWebsiteOptionsProvider, WebsiteOptionsProvider (~380 Zeilen)
├── Networking/
│   └── WidgetNetworking.swift       # Provider + fetchStats + fetchUmamiStats + fetchPlausibleStats (~680 Zeilen)
└── Views/
    ├── WidgetChartViews.swift        # BarChartView + LineChartView (~370 Zeilen)
    └── WidgetSizeViews.swift         # SmallWidgetView + MediumWidgetView (~240 Zeilen)
```

**Wichtig:** Swift 5.0 fuer alle Widget-Dateien (SWIFT_VERSION = 5.0 in Build Settings fuer InsightFlowWidgetExtension-Target). Xcode erkennt neue Dateien im Verzeichnis automatisch via PBXFileSystemSynchronizedRootGroup.

### Empfohlene View-Extraktion

**WebsiteDetailView.swift (1611 → ~400 Zeilen Ziel)**

Kandidaten fuer eigene Dateien:
- `WebsiteDetailChartSection.swift` — MARK "Main Chart" (390 Zeilen Kern) mit `selectedMetric`, `selectedChartStyle`, `selectedChartPoint`-State
- `WebsiteDetailMetricsSection.swift` — Location (82Z), Tech (96Z), Language & Screen (49Z), Events (26Z) als kombinierte Metrics-Datei (~270 Zeilen)
- `WebsiteDetailSupportingViews.swift` — `SectionHeader`, `DateRangeChip`, `StatCard` u.a. Supporting Views (ab Zeile 1280, 331 Zeilen) — sind bereits global verwendbar

Der verbleibende Kern `WebsiteDetailView.swift` enthaelt: HeroStats, DateRangePicker, QuickActions, TopPages, Referrers, Helper Functions + die body/init-Struktur.

**AdminView.swift (1318 → ~350 Zeilen Ziel)**

Alle MARK-Sektionen ausserhalb der AdminView-Struct sind bereits eigenstaendige Typen. Kandidaten:
- `AdminSheets.swift` — CreateSheets (141Z), PlausibleTrackingCode (56Z), UmamiTrackingCode (59Z), ShareLink (99Z), EditWebsite (60Z), TeamMember (105Z) = ~520 Zeilen Sheet-Definitionen
- `AdminCards.swift` — WebsiteAdminCard (105Z), TeamCard (84Z), UserCard (46Z), PlausibleSiteAdminCard (55Z) = ~290 Zeilen Card-Views
- Die 3 Sections (Websites/Teams/Users) bleiben in AdminView.swift, ViewModel bleibt inline

**CompareView.swift (1183 → ~350 Zeilen Ziel)**

- `CompareChartSection.swift` — MARK "Comparison Chart" (588 Zeilen!) — der groesste einzelne Block
- `CompareHeroCard.swift` — bereits eigenstaendiger Typ (99Z), kann direkt extrahiert werden
- `CompareViewModel.swift` — MARK "ViewModel" (117Z) als eigene Datei

### Anti-Patterns vermeiden

- **Kein Behavior-Change beim Wrapping:** `#if DEBUG` ausschliesslich um den `print()`-Call setzen, nicht um umgebende Logik
- **Kein Import-Stripping:** Beim Widget-Split benoetigt jede neue Datei ihre eigenen Imports (`WidgetKit`, `SwiftUI`, `AppIntents`, `CryptoKit` wo noetig)
- **Keine Swift-Version-Inkompatibilitaet:** Widget-Dateien muessen Swift 5.0-kompatibel sein — keine `@unchecked Sendable`-Annotationen aus Swift 6.0 importieren
- **Keine Circular Dependencies:** `WidgetModels.swift` darf nicht von `WidgetNetworking.swift` oder `WidgetStorage.swift` importiert werden — einseitige Abhaengigkeit

## Don't Hand-Roll

| Problem | Nicht bauen | Stattdessen nutzen | Warum |
|---------|-------------|-------------------|-------|
| Debug-Logging | Eigenes Logger-Framework | `#if DEBUG` + `print()` | Reicht fuer die Phase; Logger-Refactoring ist Out of Scope |
| Xcode Target Membership | pbxproj manuell editieren | PBXFileSystemSynchronizedRootGroup | Bereits aktiv — neue Dateien werden automatisch aufgenommen |
| View State Sharing | Komplexe State-Bindung | Bestehende `@State`/`@StateObject`-Properties weitergeben | Keine Architekturaenderung in dieser Phase |

## Runtime State Inventory

> Gilt fuer diese Phase: Es handelt sich um Refactoring/Splitting, keine Daten- oder Service-Umbenennung.

| Kategorie | Gefundenes | Aktion noetig |
|-----------|-----------|----------------|
| Gespeicherte Daten | Keine Umbenennung von App-Group-Dateien oder Keys | Keine — Widget liest dieselben Dateinamen |
| Live Service Config | Keine externen Services betroffen | Keine |
| OS-registrierter Zustand | Keine Widget-Kind-Strings geaendert (`PrivacyFlowWidget` bleibt) | Keine — Widget bleibt unter gleichem Kind-String registriert |
| Secrets/Env-Vars | Keine Keys umbenannt | Keine |
| Build-Artefakte | Nach Widget-Split: Xcode Clean Build empfohlen | Clean Build nach Split (Compiler-Caches) |

**Zusammenfassung:** Diese Phase aendert keine Runtime-Bezeichner. Der Widget-Split verschiebt Code nur in neue Dateien — `kind: "PrivacyFlowWidget"` bleibt unveraendert, App-Group-Pfade bleiben unveraendert, keine Keychain-Schluessel aendern sich.

## Common Pitfalls

### Pitfall 1: Partial #if DEBUG Wrapping
**Was schieflaeuft:** Nur der `print()`-Call wird gewrappt, aber der zugehoerige `error`-Parameter wird ausserhalb des DEBUG-Blocks verwendet. Kompilierungsfehler wenn `error` nur im catch-Block relevant ist.
**Warum:** Bei `catch { print("error: \(error)") }` ist `error` nur innerhalb des catch-Blocks gueltig — kein Problem. Bei `let msg = "error: \(error)"; print(msg)` ausserhalb eines catch waere es anders.
**Vorbeugung:** Immer den gesamten `print(...)`-Aufruf wrappen, nie den umgebenden Code aendern.

### Pitfall 2: widgetLog bleibt in Release
**Was schieflaeuft:** `widgetLog()` ist eine Wrapper-Funktion die `print()` aufruft. Die Funktion selbst wird in Release nicht entfernt — nur ihr Inhalt muss konditionell sein.
**Loesung:** `private func widgetLog(_ message: String) { #if DEBUG\nprint("[Widget] \\(message)")\n#endif }` — die Funktion-Aufrufe bleiben, aber der print-Call faellt weg.

### Pitfall 3: Widget-Split bricht Xcode-Build wegen fehlender Imports
**Was schieflaeuft:** `WidgetIntents.swift` benoetigt `import AppIntents`, `import WidgetKit`. `WidgetStorage.swift` benoetigt `import CryptoKit`. Beim Split vergessene Imports fuehren zu sofortigen Compiler-Fehlern.
**Vorbeugung:** Jeden neuen File mit denselben Imports starten wie der relevante MARK-Block im Original.

### Pitfall 4: Swift 5.0 vs 6.0 Concurrency im Widget-Split
**Was schieflaeuft:** Wenn Code aus der Main App (Swift 6.0) als Referenz dient und strict concurrency Patterns enthaelt, sind diese nicht direkt auf Widget-Code uebertragbar.
**Warum:** Widget-Extension hat `SWIFT_VERSION = 5.0` in Build Settings (bestaetigt). Swift 5.0 erzwingt keine `Sendable`-Konformanz.
**Vorbeugung:** Keine Swift 6.0-spezifischen Annotationen einfuehren. Bestehende Widget-Code-Patterns beibehalten.

### Pitfall 5: View-Extraktion bricht @State-Sharing
**Was schieflaeuft:** Computed Properties in `WebsiteDetailView` nutzen `selectedChartPoint`, `selectedMetric` etc. aus dem Parent-View. Beim Extrahieren in eigenstaendige Views muessen diese als Bindungen (`@Binding`) oder Parameter uebergeben werden.
**Loesung:** Extrahierte Views erhalten alle benoetigen State-Werte als Parameter (bei read-only) oder `@Binding` (bei read-write).

### Pitfall 6: AdminView Sheets verlieren ViewModel-Referenz
**Was schieflaeuft:** Sheet-Views wie `EditWebsiteSheet` haben `@ObservedObject var viewModel: AdminViewModel`. Beim Extrahieren in eigene Datei muss `AdminViewModel` importierbar sein (liegt in derselben Module-Group, kein Problem) und die Property bleibt.
**Vorbeugung:** Beim Extrahieren die `@ObservedObject`-Property unveraendert lassen.

## Code Examples

### Pattern: #if DEBUG Wrap (Standard)

```swift
// Vorher:
catch {
    print("Failed to load websites: \(error)")
}

// Nachher:
catch {
    #if DEBUG
    print("Failed to load websites: \(error)")
    #endif
}
```

### Pattern: widgetLog DEBUG-safe machen

```swift
// Vorher:
private func widgetLog(_ message: String) {
    print("[Widget] \(message)")
}

// Nachher:
private func widgetLog(_ message: String) {
    #if DEBUG
    print("[Widget] \(message)")
    #endif
}
```

### Pattern: View-Extraktion mit @Binding

```swift
// WebsiteDetailView zieht mainChart in eigene Datei
// Original (computed property in WebsiteDetailView):
//   private var mainChart: some View { ... nutzt selectedMetric, selectedChartPoint ... }

// Nach Extraktion als Subview-Struct:
struct WebsiteDetailChartSection: View {
    let pageviewsData: [TimeSeriesPoint]
    @Binding var selectedMetric: ChartMetric
    @Binding var selectedChartPoint: TimeSeriesPoint?
    @Binding var selectedChartStyle: ChartStyle

    var body: some View {
        // bisheriger mainChart-Inhalt
    }
}

// Im Parent (WebsiteDetailView):
WebsiteDetailChartSection(
    pageviewsData: viewModel.pageviewsData,
    selectedMetric: $selectedMetric,
    selectedChartPoint: $selectedChartPoint,
    selectedChartStyle: $selectedChartStyle
)
```

### Pattern: Widget-Datei-Header

```swift
// Jede neue Widget-Datei benoetigt passende Imports
// Beispiel WidgetModels.swift:
import WidgetKit
import SwiftUI

// WidgetStorage.swift benoetigt zusaetzlich:
import CryptoKit

// WidgetIntents.swift benoetigt:
import WidgetKit
import SwiftUI
import AppIntents
```

## Detaillierter Print-Statement-Audit

Aktueller Stand (nach Phase 1): 69 `print()`-Calls total, 37 bereits in `#if DEBUG`, **32 noch unwrapped**.

| Datei | Unwrapped | Wrapped (bereits) |
|-------|-----------|-------------------|
| WebsiteDetailViewModel.swift | 0 | 14 — komplett erledigt |
| AccountManager.swift | 7 | 2 |
| SharedCredentials.swift | 0 | 8 — komplett erledigt |
| AnalyticsCacheService.swift | 0 | 7 — komplett erledigt |
| SessionsView.swift | 4 | 0 |
| DashboardView.swift | 1 | 3 |
| RealtimeView.swift | 3 | 0 |
| CompareView.swift | 2 | 0 |
| AdminView.swift | 2 | 0 |
| NotificationManager.swift | 2 | 0 |
| PagesView.swift | 0 | 2 — komplett erledigt |
| PlausibleAPI.swift | 2 | 0 |
| InsightFlowApp.swift | 1 | 0 |
| WebsiteCard.swift | 1 | 0 |
| AddUmamiSiteView.swift | 1 | 0 |
| AddPlausibleSiteView.swift | 1 | 0 |
| RetentionView.swift | 1 | 0 |
| InsightsView.swift | 1 | 0 |
| SettingsView.swift | 0 | 1 — komplett erledigt |
| SupportManager.swift | 1 | 0 |
| UmamiAPI.swift | 1 | 0 |
| InsightFlowWidget.swift | 1 (widgetLog) | 0 |

**Hochvolumen-Dateien zum Priorisieren:** AccountManager.swift (7), SessionsView.swift (4), RealtimeView.swift (3).

## Detaillierter Widget-Split-Plan

Zeilen nach Split (Schaetzung):

| Neue Datei | Inhalt (MARK-Sektionen) | Geschaetzte Zeilen |
|------------|------------------------|-------------------|
| `WidgetModels.swift` | Credentials-Enums, WidgetAccount, WidgetData, StatsEntry | ~170 |
| `WidgetTimeRange.swift` | WidgetTimeRange, WidgetChartStyle | ~80 |
| `WidgetStorage.swift` | WidgetAccountsStorage, WidgetCredentials | ~270 |
| `WidgetCache.swift` | WidgetCache | ~120 |
| `WidgetIntents.swift` | AccountEntity, WebsiteEntity, WebsiteQuery, ConfigureWidgetIntent, FilteredWebsiteOptionsProvider, WebsiteOptionsProvider | ~380 |
| `WidgetNetworking.swift` | Provider, fetchStats, Umami Stats, Plausible Stats | ~680 |
| `WidgetChartViews.swift` | BarChartView, LineChartView | ~370 |
| `WidgetSizeViews.swift` | PrivacyFlowWidgetEntryView, SmallWidgetView, MediumWidgetView | ~240 |
| `InsightFlowWidget.swift` (Rest) | PrivacyFlowWidget + #Preview | ~35 |

Gesamt: ~2345 Zeilen in 9 Dateien (vs. 2034 in 1 Datei — leicht mehr durch neue File-Header).

## Detaillierter View-Extraktion-Plan

**Ziel: Jede Datei unter 600 Zeilen (Success Criterion)**

**WebsiteDetailView.swift (1611 → ~420 Zeilen):**
- `WebsiteDetailChartSection.swift` (~420 Zeilen) — MARK "Main Chart" (390Z) + chart-spezifische Helper
- `WebsiteDetailMetricsSections.swift` (~290 Zeilen) — Location + Tech + Language/Screen + Events
- `WebsiteDetailSupportingViews.swift` (~360 Zeilen) — SectionHeader, DateRangeChip, QuickActionCard + restliche Supporting Views ab Zeile 1280

**AdminView.swift (1318 → ~350 Zeilen):**
- `AdminCards.swift` (~320 Zeilen) — WebsiteAdminCard, TeamCard, UserCard, PlausibleSiteAdminCard
- `AdminSheets.swift` (~560 Zeilen) — alle Sheet-Views (CreateSheets, TrackingCode-Sheets, ShareLink, EditWebsite, TeamMember)
- AdminView.swift selbst: Haupt-View + Sections + AdminSection Enum + ViewModel + Extensions (~380 Zeilen)

**CompareView.swift (1183 → ~370 Zeilen):**
- `CompareChartSection.swift` (~620 Zeilen) — MARK "Comparison Chart" (588Z) + direkt zugehoerige Helper
- `CompareViewModel.swift` (~120 Zeilen) — ViewModel + Extensions
- `CompareHeroCard.swift` (~110 Zeilen) — CompareHeroCard View
- CompareView.swift selbst: Haupt-View + PeriodSelection + Button + Stats (~350 Zeilen)

## Environment Availability

> Phase ist rein code/config-basiert. Xcode und Swift sind vorausgesetzt.

| Abhaengigkeit | Benoetigt fuer | Verfuegbar | Version | Fallback |
|---------------|---------------|------------|---------|----------|
| Xcode 16+ | PBXFileSystemSynchronizedRootGroup | bestaetigt (4 Eintraege in pbxproj) | 16+ | — |
| Swift 5.0 (Widget) | Widget-Extension-Target | bestaetigt via project.pbxproj | 5.0 | — |
| Swift 6.0 (Main App) | Main App + Tests | bestaetigt via project.pbxproj | 6.0 | — |

## Validation Architecture

> `workflow.nyquist_validation` ist nicht gesetzt — Validierungssektion wird eingeschlossen.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Kein Test-Target im Projekt vorhanden (TEST-01 erst Phase 5) |
| Config file | Nicht vorhanden |
| Quick run command | Xcode Build: `xcodebuild build -project InsightFlow.xcodeproj -scheme InsightFlow -destination 'platform=iOS Simulator,name=iPhone 16'` |
| Full suite command | Identisch — kein Testrunner bis Phase 5 |

### Phase Requirements → Test Map
| Req ID | Verhalten | Test-Typ | Automatisierbar | Datei vorhanden? |
|--------|-----------|---------|----------------|-----------------|
| STAB-03 | Kein print() in Release-Build | Build-Verification | `xcodebuild build -configuration Release` — 0 Warnings zu print | Kein Test — Wave 0 |
| STRUC-01 | Widget-Datei < 400 Zeilen | Struktur-Check | `wc -l InsightFlowWidget/InsightFlowWidget.swift` | Kein Test |
| STRUC-02 | Views < 600 Zeilen | Struktur-Check | `wc -l <View-Datei>` | Kein Test |

### Sampling Rate
- **Per Task Commit:** `xcodebuild build -project InsightFlow.xcodeproj -scheme InsightFlow -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5`
- **Per Wave Merge:** Identisch + `xcodebuild build -project InsightFlow.xcodeproj -scheme InsightFlowWidgetExtension -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5`
- **Phase Gate:** Release-Build erfolgreich + `wc -l`-Checks bestehen vor `/gsd:verify-work`

### Wave 0 Gaps
- [ ] Kein Test-Framework vorhanden — bewusst bis Phase 5 (TEST-01) aufgeschoben
- [ ] Manuelle Verifikation erforderlich: Widget-Simulator zeigt Daten korrekt nach Split

*(Bestehende Infrastruktur deckt Phase-Requirements nicht automatisch ab — Zeilen-Checks via `wc -l` sind trivial, werden als manuelle Verifikationsschritte behandelt)*

## Sources

### Primary (HIGH confidence)
- Direkter Code-Audit: `/Users/simonluthe/Documents/umami/InsightFlowWidget/InsightFlowWidget.swift` — alle MARK-Sektionen kartiert, Zeilenzahlen verifiziert
- Direkter Code-Audit: `/Users/simonluthe/Documents/umami/InsightFlow/Views/Detail/WebsiteDetailView.swift` — MARK-Sektionen und Zeilenzahlen verifiziert
- Direkter Code-Audit: `/Users/simonluthe/Documents/umami/InsightFlow/Views/Admin/AdminView.swift` — MARK-Sektionen kartiert
- Direkter Code-Audit: `/Users/simonluthe/Documents/umami/InsightFlow/Views/Detail/CompareView.swift` — MARK-Sektionen kartiert
- Xcode `project.pbxproj` — Swift-Versionen und PBXFileSystemSynchronizedRootGroup bestaetigt
- Python3 Audit-Script — alle 69 print()-Calls klassifiziert (37 wrapped, 32 unwrapped)

### Secondary (MEDIUM confidence)
- Apple Swift Documentation: `#if DEBUG` Compiler-Direktive — etabliertes Standardmuster

### Tertiary (LOW confidence)
- Keine

## Metadata

**Confidence breakdown:**
- Print-Statement-Audit: HIGH — vollstaendiger programmatischer Scan aller Swift-Dateien
- Widget-Split-Plan: HIGH — direkte Analyse der MARK-Sektionen mit Zeilenzahlen
- View-Extraktion: HIGH — MARK-Sektionen kartiert, Zeilenziele berechnet
- Swift 5.0/6.0 Constraint: HIGH — direkt aus project.pbxproj gelesen

**Research date:** 2026-03-27
**Valid until:** 2026-06-27 (stabiles Swift-Aenderungsverhalten, 90 Tage)
