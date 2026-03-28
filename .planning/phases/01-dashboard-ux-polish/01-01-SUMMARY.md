---
phase: 01-dashboard-ux-polish
plan: 01
subsystem: ui
tags: [swiftui, toolbar, menu, account-switcher, ux-polish]

# Dependency graph
requires: []
provides:
  - Kompakter Menu-basierter Account-Switcher in der Dashboard-Toolbar (Picker mit automatischer Checkmark)
  - Cancel-Button aus AddAccountView entfernt
affects: [phase-02, phase-03]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SwiftUI Menu mit Picker fuer automatische Checkmark-Markierung des aktiven Accounts"
    - "@ViewBuilder computed property fuer komplexe Menu-Subviews zur Vermeidung von Type-Check-Timeouts"

key-files:
  created: []
  modified:
    - InsightFlow/Views/Dashboard/DashboardView.swift

key-decisions:
  - "Picker-in-Menu-Pattern fuer automatische Checkmark-Markierung statt manuellem Button mit Checkmark-Logik"
  - "accountSwitcherMenu als @ViewBuilder computed property ausgelagert um Swift Compiler Type-Check-Timeouts zu vermeiden"
  - "UUID als Picker-Selection-Typ (nicht String) entsprechend AnalyticsAccount.id Typ"

patterns-established:
  - "Complex SwiftUI Menu bodies als @ViewBuilder computed properties auslagern fuer bessere Compiler-Performance"

requirements-completed: [UX-01, UX-02]

# Metrics
duration: 15min
completed: 2026-03-27
---

# Phase 01 Plan 01: Account-Switcher Toolbar-Menu Summary

**Dashboard-Account-Switcher von grossem ScrollView-Bereich zu kompaktem Toolbar-Icon-Menu mit Picker-basierter Checkmark-Markierung umgebaut, Cancel-Button aus AddAccountView entfernt**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-03-27T00:00:00Z
- **Completed:** 2026-03-27T00:15:00Z
- **Tasks:** 1 completed, 1 deferred (checkpoint:human-verify)
- **Files modified:** 1

## Accomplishments
- `showingAccountSwitcher` State und grosser `accountSwitcherButton` ScrollView-Bereich entfernt
- Neues kompaktes Toolbar-Menu mit Provider-Icon als Button-Label (orange=Umami, blau=Plausible)
- Picker innerhalb des Menus fuer automatische Checkmark-Markierung des aktiven Accounts
- "Konto hinzufuegen"-Eintrag am Ende des Menus oeffnet AddAccountView als Sheet
- `AccountSwitcherSheet` struct vollstaendig entfernt
- Cancel-Button in `AddAccountView` Toolbar entfernt (Back-Button reicht)
- Projekt kompiliert erfolgreich (BUILD SUCCEEDED)

## Task Commits

1. **Task 1: Account-Switcher zu Toolbar-Menu umbauen, Cancel-Button entfernen** - `e03b38f` (feat)
2. **Task 2: Visuelles Verify** - Deferred (checkpoint:human-verify, visuelle Verifikation durch User ausstehend)

## Files Created/Modified
- `InsightFlow/Views/Dashboard/DashboardView.swift` - Account-Switcher umgebaut, AccountSwitcherSheet entfernt, Cancel-Button entfernt

## Decisions Made
- Picker-in-Menu-Pattern gewaehlt (automatische Checkmark ohne manuelle Logik)
- accountSwitcherMenu als `@ViewBuilder` computed property ausgelagert, da SwiftUI Compiler bei komplexem Menu-Body Type-Check-Timeout meldet
- UUID statt String als Picker-Selection-Typ (entspricht AnalyticsAccount.id)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Swift Compiler Type-Check-Timeout beim komplexen Menu-Body**
- **Found during:** Task 1 (Build-Verifikation)
- **Issue:** Swift Compiler meldete "unable to type-check this expression in reasonable time" bei der Picker-Closure im Toolbar-Menu
- **Fix:** Menu-Body in `@ViewBuilder` computed property `accountSwitcherMenu` ausgelagert, UUID-Typ explizit annotiert (`Binding<UUID>`)
- **Files modified:** InsightFlow/Views/Dashboard/DashboardView.swift
- **Verification:** BUILD SUCCEEDED
- **Committed in:** e03b38f (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - Bug)
**Impact on plan:** Notwendige Refactoring-Massnahme fuer Compiler-Kompatibilitaet. Kein Scope Creep.

## Issues Encountered
- Swift Compiler Type-Inference-Grenze beim verschachtelten Picker-in-Menu-Body erreicht. Loesung: Auslagerung in @ViewBuilder computed property und explizite UUID-Typ-Annotation.

## Checkpoint Deferred

**Task 2 (Visuelles Verify)** ist ein `checkpoint:human-verify` und wurde als "deferred to phase verification" markiert. Visuelle Pruefung im Simulator durch den User steht noch aus.

## Next Phase Readiness
- UX-01 und UX-02 sind implementiert und kompilieren erfolgreich
- Visuelle Verifikation im Simulator durch User empfohlen vor Phase 02

---
*Phase: 01-dashboard-ux-polish*
*Completed: 2026-03-27*
