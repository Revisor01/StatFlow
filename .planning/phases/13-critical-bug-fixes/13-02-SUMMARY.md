---
phase: 13-critical-bug-fixes
plan: 02
subsystem: ui, api
tags: [swift, swiftui, widgetkit, concurrency, task-cancellation, race-condition]

# Dependency graph
requires:
  - phase: 13-critical-bug-fixes
    provides: Wave-0 XCTest stubs fuer FIX-02
provides:
  - syncWidgetData: Daten-Schreib-Methode ohne reloadAllTimelines fuer updateAccountSites
  - loadingTask/cancelLoading Pattern in WebsiteDetailViewModel
  - .task(id:) + .onDisappear Verdrahtung in WebsiteDetailView
affects:
  - Widget-Synchronisation nach Account-Wechsel
  - Battery-Drain durch unkontrollierte Background-Tasks

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "syncWidgetData vs updateWidgetCredentials: Trennung von Daten-Schreiben und Timeline-Reload"
    - "Task-Handle-Pattern: loadingTask?.cancel() am Anfang von loadData verhindert Background-Drain"
    - ".task(id:) Modifier cancelt automatisch bei ID-Wechsel und View-Disappear"

key-files:
  created:
    - InsightFlowTests/WebsiteDetailViewModelTests.swift
  modified:
    - InsightFlow/Services/AccountManager.swift
    - InsightFlow/Views/Detail/WebsiteDetailViewModel.swift
    - InsightFlow/Views/Detail/WebsiteDetailView.swift
    - InsightFlowTests/AccountManagerTests.swift

key-decisions:
  - "syncWidgetData schreibt Widget-Daten ohne Timeline-Reload — reloadAllTimelines nur in updateWidgetCredentials nach abgeschlossenen async-Ops"
  - "NotificationCenter.post VOR updateWidgetCredentials in applyAccountCredentials — Views erhalten Benachrichtigung bevor Widget-Reload"
  - "loadingTask als private var Task<Void, Never>? statt Task-Gruppen-Cancellation — einfacher, klarer Cancel-Aufruf"

patterns-established:
  - "Task-Handle-Pattern: private var loadingTask mit cancel/replace Logik fuer ViewModel-Methoden mit async Hintergrund-Arbeit"
  - "syncData vs updateWithSideEffects: Trenne Datenpersistenz-Calls von Side-Effect-Calls (Timeline-Reload, Notifications)"

requirements-completed: [FIX-01, FIX-02]

# Metrics
duration: 25min
completed: 2026-03-28
---

# Phase 13 Plan 02: Critical Bug Fixes — Widget Race Condition & Request Cancellation Summary

**Widget-Sync Race Condition behoben (syncWidgetData ohne reloadAllTimelines) und Task-Cancellation in WebsiteDetailViewModel implementiert (.task(id:) + loadingTask-Handle-Pattern)**

## Performance

- **Duration:** 25 min
- **Started:** 2026-03-28T22:30:00Z
- **Completed:** 2026-03-28T22:55:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- FIX-01: Neue Methode `syncWidgetData` trennt Datenpersistenz von Widget-Timeline-Reload — `updateAccountSites` loest keinen vorzeitigen Widget-Reload mehr aus
- FIX-01: In `applyAccountCredentials` kommt `NotificationCenter.post` jetzt VOR `updateWidgetCredentials` — Widget-Reload passiert nach allen async-Operationen
- FIX-02: `loadData` speichert Task-Handle in `loadingTask` und cancelt vorherigen Task bei erneutem Aufruf — kein Background-Battery-Drain mehr
- FIX-02: `WebsiteDetailView` verwendet `.task(id: selectedDateRange)` — automatische Cancellation bei DateRange-Wechsel und View-Disappear
- Tests fuer beide Fixes hinzugefuegt (AccountManagerTests + neue WebsiteDetailViewModelTests)

## Task Commits

1. **Task 1: Widget Sync Race Condition fixen (FIX-01)** - `a561973` (fix)
2. **Task 2: RED — Failing tests fuer FIX-02** - `d900abe` (test)
3. **Task 2: GREEN — Request Cancellation implementiert (FIX-02)** - `5eed770` (feat)

## Files Created/Modified

- `InsightFlow/Services/AccountManager.swift` - syncWidgetData Methode, Fix der Reihenfolge in applyAccountCredentials
- `InsightFlow/Views/Detail/WebsiteDetailViewModel.swift` - loadingTask Property, loadData mit Task-Handle, cancelLoading Methode
- `InsightFlow/Views/Detail/WebsiteDetailView.swift` - .task(id: selectedDateRange) + .onDisappear cancelLoading
- `InsightFlowTests/AccountManagerTests.swift` - testUpdateAccountSitesDoesNotCallReloadTimelines
- `InsightFlowTests/WebsiteDetailViewModelTests.swift` - Neue Datei mit FIX-02 Tests

## Decisions Made

- `syncWidgetData` ist eine separate private Methode statt Erweiterung von `updateWidgetCredentials` — klare Trennung der Verantwortlichkeiten
- `loadingTask` als `Task<Void, Never>?` — einfacheres Cancel-Pattern als strukturierte Concurrency
- `.task(id:)` ersetzt `.task` + `.onChange` Kombination — idiomatisches SwiftUI, automatisches Lifecycle-Management

## Deviations from Plan

None - Plan exakt ausgefuehrt. TDD-Flow wie geplant: RED commit, dann GREEN commit.

## Issues Encountered

- iPhone 16 Simulator nicht verfuegbar (iOS 26.4 Simulatoren, iPhone 17 Pro verwendet) — kein Problem, Build und Tests erfolgreich

## Next Phase Readiness

- FIX-01 und FIX-02 abgeschlossen
- Weitere Fixes aus Phase 13 (FIX-03, FIX-04) koennen unabhaengig implementiert werden
- Build fehlerfrei, keine Test-Regressionen

---
*Phase: 13-critical-bug-fixes*
*Completed: 2026-03-28*
