---
phase: 20-code-organisation
plan: 01
subsystem: ui
tags: [swift, swiftui, viewmodel, refactoring, code-organisation]

# Dependency graph
requires: []
provides:
  - "8 dedicated ViewModel files separated from View files"
  - "Clean View/ViewModel separation for testability and maintainability"
affects: [20-code-organisation]

# Tech tracking
tech-stack:
  added: []
  patterns: ["ViewModel in dedicated file, View references via @StateObject"]

key-files:
  created:
    - InsightFlow/Views/Dashboard/DashboardViewModel.swift
    - InsightFlow/Views/Sessions/SessionsViewModel.swift
    - InsightFlow/Views/Realtime/RealtimeViewModel.swift
    - InsightFlow/Views/Settings/SettingsViewModel.swift
    - InsightFlow/Views/Admin/AdminViewModel.swift
    - InsightFlow/Views/Reports/RetentionViewModel.swift
    - InsightFlow/Views/Reports/ComparisonViewModel.swift
    - InsightFlow/Views/Reports/PagesViewModel.swift
  modified:
    - InsightFlow/Views/Dashboard/DashboardView.swift
    - InsightFlow/Views/Sessions/SessionsView.swift
    - InsightFlow/Views/Realtime/RealtimeView.swift
    - InsightFlow/Views/Settings/SettingsView.swift
    - InsightFlow/Views/Admin/AdminView.swift
    - InsightFlow/Views/Reports/RetentionView.swift
    - InsightFlow/Views/Reports/InsightsView.swift
    - InsightFlow/Views/Reports/PagesView.swift

key-decisions:
  - "Pure extraction with no logic changes - verbatim move of ViewModel code"
  - "ComparisonPeriod enum and ComparisonDataPoint struct moved with ComparisonViewModel since they are ViewModel-layer types"

patterns-established:
  - "Every ViewModel lives in its own dedicated *ViewModel.swift file alongside its *View.swift"

requirements-completed: [REFACTOR-03]

# Metrics
duration: 8min
completed: 2026-04-04
---

# Phase 20 Plan 01: Extract ViewModels Summary

**Extracted 8 embedded ViewModels (DashboardVM, SessionsVM, RealtimeVM, SettingsVM, AdminVM, RetentionVM, ComparisonVM, PagesVM) into dedicated files with zero logic changes**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-04T20:54:04Z
- **Completed:** 2026-04-04T21:02:12Z
- **Tasks:** 2
- **Files modified:** 16 (8 new ViewModel files created, 8 View files trimmed)

## Accomplishments
- All 8 ViewModel classes extracted from View files into their own dedicated files
- No ViewModel class definitions remain in any *View.swift file
- Project builds clean with zero errors
- Pure extraction: no logic, method signatures, or access control changes

## Task Commits

Each task was committed atomically:

1. **Task 1+2: Extract all 8 ViewModels** - `be5dadc` (refactor)

## Files Created/Modified

### New ViewModel Files
- `InsightFlow/Views/Dashboard/DashboardViewModel.swift` - DashboardViewModel (409 LOC)
- `InsightFlow/Views/Sessions/SessionsViewModel.swift` - SessionsViewModel + SessionDetailViewModel + JourneyViewModel (166 LOC)
- `InsightFlow/Views/Realtime/RealtimeViewModel.swift` - RealtimeViewModel + LiveEventDetailViewModel (160 LOC)
- `InsightFlow/Views/Settings/SettingsViewModel.swift` - SettingsViewModel (62 LOC)
- `InsightFlow/Views/Admin/AdminViewModel.swift` - AdminViewModel + extension (260 LOC)
- `InsightFlow/Views/Reports/RetentionViewModel.swift` - RetentionViewModel (76 LOC)
- `InsightFlow/Views/Reports/ComparisonViewModel.swift` - ComparisonPeriod + ComparisonDataPoint + ComparisonViewModel (113 LOC)
- `InsightFlow/Views/Reports/PagesViewModel.swift` - PagesViewModel (136 LOC)

### Trimmed View Files
- `InsightFlow/Views/Dashboard/DashboardView.swift` - Now 797 LOC (pure View code)
- `InsightFlow/Views/Sessions/SessionsView.swift` - Trimmed, View + UI structs only
- `InsightFlow/Views/Realtime/RealtimeView.swift` - Trimmed, View + UI structs only
- `InsightFlow/Views/Settings/SettingsView.swift` - Now 692 LOC (pure View code)
- `InsightFlow/Views/Admin/AdminView.swift` - Trimmed, View + UI structs only
- `InsightFlow/Views/Reports/RetentionView.swift` - Trimmed, View + UI structs only
- `InsightFlow/Views/Reports/InsightsView.swift` - Trimmed, View + UI structs only
- `InsightFlow/Views/Reports/PagesView.swift` - Trimmed, View + UI structs only

## Decisions Made
- Combined Task 1 and Task 2 into a single commit since all extractions are the same refactoring operation
- Moved ComparisonPeriod enum and ComparisonDataPoint struct into ComparisonViewModel.swift (they are ViewModel-layer types, not View types)
- AdminViewModel extension (isUserInTeam, getTeamMembers) moved alongside the main class

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None - pure extraction, no new functionality.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- All ViewModels are now in dedicated files, ready for dependency injection (Plan 02)
- DashboardView.swift (797 LOC) and SettingsView.swift (692 LOC) exceed 500 LOC but are pure View code

---
*Phase: 20-code-organisation*
*Completed: 2026-04-04*
