---
phase: 18-aktive-bugs-kritische-fixes
plan: 03
subsystem: dashboard, realtime
tags: [swift, swiftui, widget, task-cancellation, race-condition]

requires:
  - phase: 18-02
    provides: "loadingTask pattern in DashboardViewModel, online-first cache"
provides:
  - "configureProviderForAccount() for side-effect-free API switching"
  - "loadAllAccountsData without global account switch or widget reloads per iteration"
  - "Task.isCancelled guards in RealtimeViewModel and LiveEventDetailViewModel"
affects: [dashboard, realtime, widgets, multi-account]

tech-stack:
  added: []
  patterns: ["configureProviderForAccount for multi-account iteration without side effects", "loadingTask + isCancelled guard pattern for all async ViewModels"]

key-files:
  created: []
  modified:
    - InsightFlow/Services/AccountManager.swift
    - InsightFlow/Views/Dashboard/DashboardView.swift
    - InsightFlow/Views/Realtime/RealtimeView.swift

key-decisions:
  - "Option A chosen: configureProviderForAccount() reconfigures API actors without widget reload or notifications"
  - "setActiveAccount called only once at end of loadAllAccountsData to restore original account"

patterns-established:
  - "configureProviderForAccount: lightweight API config for multi-account loops, no activeAccount change, no notifications, no widget reload"
  - "LiveEventDetailViewModel loadingTask pattern: cancel/assign/guard after every await"

requirements-completed: [BUG-03, TASK-01]

duration: 3min
completed: 2026-04-04
---

# Phase 18 Plan 03: Widget Race Condition + Realtime Task Cancellation Summary

**configureProviderForAccount() eliminates widget reload storm during multi-account iteration; RealtimeViewModel + LiveEventDetailViewModel get full task cancellation**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-04T20:12:38Z
- **Completed:** 2026-04-04T20:16:00Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Created `configureProviderForAccount()` in AccountManager that reconfigures API actors without changing `activeAccount`, posting notifications, or reloading widgets
- `loadAllAccountsData` now uses `configureProviderForAccount` in both loops (website fetch + stats fetch), with `setActiveAccount` called only once at the end to restore the original account
- Added `guard !Task.isCancelled else { return }` after all `await` calls in `refreshPlausible()` and `refreshUmami()` (4 guards total in RealtimeViewModel)
- Added full `loadingTask` cancellation pattern to `LiveEventDetailViewModel` with `cancelLoading()` method

## Task Commits

Both tasks committed together as requested:

1. **Task 1+2: BUG-03 + TASK-01** - `55e786e` (fix)

## Files Created/Modified
- `InsightFlow/Services/AccountManager.swift` - Added `configureProviderForAccount()` method for side-effect-free API configuration
- `InsightFlow/Views/Dashboard/DashboardView.swift` - Replaced `setActiveAccount` calls in `loadAllAccountsData` loop with `configureProviderForAccount`
- `InsightFlow/Views/Realtime/RealtimeView.swift` - Added Task.isCancelled guards in RealtimeViewModel, full loadingTask pattern in LiveEventDetailViewModel

## Decisions Made
- Chose Option A (configureProviderForAccount) over Option B (suppressWidgetReload flag) because the API actors already have reconfigureFromKeychain methods, making direct configuration cleaner than a flag-based approach
- Combined both tasks in a single commit per user request

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs
None - all code paths are fully wired.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Multi-account iteration pattern is now safe for widget state
- All async ViewModels in Realtime module have proper task cancellation
- Pattern can be referenced for any future multi-account data loading

---
*Phase: 18-aktive-bugs-kritische-fixes*
*Completed: 2026-04-04*
