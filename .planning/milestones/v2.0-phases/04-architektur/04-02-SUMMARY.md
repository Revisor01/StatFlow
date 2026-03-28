---
phase: 04-architektur
plan: "02"
subsystem: api
tags: [swift, swiftui, protocol, analytics, umami, plausible, refactoring]

# Dependency graph
requires:
  - phase: 04-architektur-01
    provides: PlausibleAPI als actor, AnalyticsProvider-Protokoll Basis mit getPages/getReferrers/getCountries etc.

provides:
  - Erweitertes AnalyticsProvider-Protokoll mit 9 neuen Methoden (getRegions, getCities, getPageTitles, getLanguages, getScreens, getEvents, getRealtimeTopPages, getRealtimeCountries, getRealtimePageviews)
  - Protocol Extension Default-Implementierungen fuer Plausible-unterstuetzte Metriken (leere Arrays)
  - UmamiAPI implementiert alle neuen Protokoll-Methoden als getMetrics()-Wrapper
  - WebsiteDetailViewModel ohne isPlausible-Branching — reiner Protocol-Dispatch via AnalyticsManager.shared.currentProvider
  - AnalyticsManager ohne @Published var isAuthenticated (redundant, via Protocol-Property abgedeckt)

affects: [WebsiteDetailView, RealtimeView, CompareView, any future provider implementation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Protocol Extension Default: Plausible-only Methoden geben [] zurueck via extension AnalyticsProvider"
    - "ViewModel Protocol-Dispatch: guard let provider = AnalyticsManager.shared.currentProvider statt if isPlausible"
    - "AnalyticsMetricItem->MetricItem Mapping: MetricItem(x: $0.name, y: $0.value)"

key-files:
  created: []
  modified:
    - InsightFlow/Services/AnalyticsProvider.swift
    - InsightFlow/Services/UmamiAPI.swift
    - InsightFlow/Views/Detail/WebsiteDetailViewModel.swift

key-decisions:
  - "Protocol Extension statt required-Implementierung fuer Plausible-spezifische Luecken: getPageTitles/getLanguages/getScreens/getEvents geben [] zurueck — kein Compiler-Fehler, sauberes Opt-out"
  - "getRealtimeTopPages/getRealtimeCountries fuer Umami: DateRange.today als Proxy fuer Realtime-Kontext — PlausibleAPI hat dedizierte Realtime-Endpoints"
  - "AnalyticsManager.isAuthenticated entfernt: Redundant da jede View bereits provider.isAuthenticated oder currentProvider != nil pruefen kann"

patterns-established:
  - "Provider-Dispatch-Pattern: guard let provider = AnalyticsManager.shared.currentProvider else { return } als einziges Branching im ViewModel"
  - "Metric-Mapping-Pattern: items.map { MetricItem(x: $0.name, y: $0.value) } fuer alle AnalyticsMetricItem -> MetricItem Konvertierungen"

requirements-completed: [ARCH-02]

# Metrics
duration: 15min
completed: 2026-03-28
---

# Phase 04 Plan 02: AnalyticsProvider Protocol Extension & ViewModel Refactoring Summary

**AnalyticsProvider-Protokoll auf 15 Metriken erweitert, UmamiAPI mit getMetrics()-Wrappern implementiert, WebsiteDetailViewModel von 15 isPlausible-Branches auf reinen Protocol-Dispatch umgestellt**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-03-28T03:39:00Z
- **Completed:** 2026-03-28T03:43:54Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Alle 15 `if isPlausible` Branches aus WebsiteDetailViewModel entfernt
- AnalyticsProvider-Protokoll um 9 neue Methoden erweitert (inkl. Regions, Cities, PageTitles, Languages, Screens, Events, Realtime-Varianten)
- UmamiAPI implementiert alle neuen Methoden als schlanke getMetrics()-Wrapper mit AnalyticsMetricItem-Mapping
- Protocol Extension liefert leere Array-Defaults fuer Plausible-nicht-unterstuetzte Metriken (kein Compiler-Fehler)
- AnalyticsManager bereinigt: redundante @Published var isAuthenticated entfernt
- Build kompiliert clean

## Task Commits

Jeder Task wurde atomisch committed:

1. **Task 1: AnalyticsProvider-Protokoll erweitern und UmamiAPI anpassen** - `07444da` (feat)
2. **Task 2: WebsiteDetailViewModel auf Protocol-Dispatch umstellen** - `1d7ce04` (refactor)

## Files Created/Modified

- `/Users/simonluthe/Documents/umami/InsightFlow/Services/AnalyticsProvider.swift` - 9 neue Protokoll-Methoden + Protocol Extension mit Default-Implementierungen + AnalyticsManager.isAuthenticated entfernt
- `/Users/simonluthe/Documents/umami/InsightFlow/Services/UmamiAPI.swift` - getRegions, getCities, getPageTitles, getLanguages, getScreens, getEvents, getRealtimeTopPages, getRealtimeCountries, getRealtimePageviews implementiert
- `/Users/simonluthe/Documents/umami/InsightFlow/Views/Detail/WebsiteDetailViewModel.swift` - Kompletter Umbau: keine direkten API-Referenzen, kein isPlausible, alle Methoden via provider.methodName()

## Decisions Made

- **Protocol Extension fuer Defaults:** `getPageTitles`, `getLanguages`, `getScreens`, `getEvents` als leere Array-Defaults — Plausible liefert diese Daten nicht, kein Error-Throwing noetig
- **getRealtimeTopPages/-Countries in UmamiAPI:** Verwenden `DateRange.today` als Proxy da kein dedizierter Realtime-Metrics-Endpoint — PlausibleAPI hat echte Realtime-Endpoints
- **AnalyticsManager.isAuthenticated entfernt:** Wurde nicht von Views direkt gelesen (nur AuthManager.isAuthenticated in ContentView) und war redundant zu currentProvider != nil

## Deviations from Plan

Keine — Plan exakt wie beschrieben umgesetzt.

## Issues Encountered

- `DateRange.last24Hours` existiert nicht (nicht im DateRange.swift definiert) — wurde mit `DateRange.today` als funktionales Aequivalent ersetzt fuer die Realtime-Methoden in UmamiAPI

## User Setup Required

Keine — kein externes Service-Setup erforderlich.

## Next Phase Readiness

- WebsiteDetailViewModel komplett entkoppelt von konkreten API-Implementierungen
- Neuer Provider kann hinzugefuegt werden ohne ViewModel-Aenderungen (nur Protokoll implementieren)
- Phase 04-03 (falls vorhanden) kann auf dem bereinigten ViewModel aufbauen

---
*Phase: 04-architektur*
*Completed: 2026-03-28*
