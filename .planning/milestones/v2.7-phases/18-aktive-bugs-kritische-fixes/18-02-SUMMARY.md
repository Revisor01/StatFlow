---
phase: 18-aktive-bugs-kritische-fixes
plan: 02
subsystem: cache, ui
tags: [swift, swiftui, offline-fallback, cache-strategy, task-cancellation]

requires:
  - phase: none
    provides: n/a
provides:
  - "Online-first cache strategy: API always loaded first, cache only on network error"
  - "50MB cache eviction limit (down from 100MB)"
  - "24h offline display TTL with isValidForOfflineDisplay method"
  - "Offline banner with cache timestamp in DashboardView"
  - "loadingTask pattern with Task.isCancelled guards in DashboardViewModel"
affects: [dashboard, cache, offline-mode]

tech-stack:
  added: []
  patterns: ["Online-first cache: never preload cache, only fallback on network error", "isValidForOfflineDisplay checks 24h TTL before showing stale data"]

key-files:
  created: []
  modified:
    - InsightFlow/Services/AnalyticsCacheService.swift
    - InsightFlow/Views/Dashboard/DashboardView.swift
    - InsightFlow/App/InsightFlowApp.swift
    - InsightFlow/Resources/en.lproj/Localizable.strings
    - InsightFlow/Resources/de.lproj/Localizable.strings

key-decisions:
  - "Cache only as offline fallback, never as preview/preload"
  - "24h TTL for offline display — older cache not shown, error displayed instead"
  - "50MB eviction threshold (halved from 100MB)"

patterns-established:
  - "Online-first pattern: loadData fetches API first, loadFromCache only in catch block for network errors"
  - "loadingTask pattern: cancellable Task with guard !Task.isCancelled after every await"

requirements-completed: [BUG-02]

duration: 2min
completed: 2026-04-04
---

# Phase 18 Plan 02: Cache nur Offline-Fallback Summary

**Online-first cache strategy: API immer zuerst, Cache nur bei Netzwerkfehler als Fallback mit 24h TTL, 50MB Limit, Offline-Banner mit Zeitstempel**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-04T20:02:42Z
- **Completed:** 2026-04-04T20:05:04Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Removed cache preloading in `loadData()` — API is always fetched first, cache only loaded on network error
- Added `isValidForOfflineDisplay` method with 24h TTL to prevent showing very stale data
- Reduced cache eviction threshold from 100MB to 50MB
- Added `loadingTask` pattern with `Task.isCancelled` guards (11 occurrences) for proper cancellation
- Offline banner now shows timestamp of cached data via `offlineCacheDate`
- Added localization strings for offline banner and expired cache messages (en/de)

## Task Commits

Each task was committed atomically:

1. **Task 1: Cache-Service Limits anpassen + Offline-Display-TTL** - `222ea87` (fix)
2. **Task 2: DashboardViewModel auf Online-First umbauen + Offline-Banner** - `30f8b75` (fix)

## Files Created/Modified
- `InsightFlow/Services/AnalyticsCacheService.swift` - Added offlineDisplayTTL constant and isValidForOfflineDisplay method
- `InsightFlow/App/InsightFlowApp.swift` - Changed eviction threshold from 100MB to 50MB
- `InsightFlow/Views/Dashboard/DashboardView.swift` - Online-first loadData, loadingTask pattern, offline banner with timestamp
- `InsightFlow/Resources/en.lproj/Localizable.strings` - Added dashboard.offlineData and dashboard.offlineExpired strings
- `InsightFlow/Resources/de.lproj/Localizable.strings` - Added German translations for offline strings

## Decisions Made
- Cache only as offline fallback, never as preview/preload — fixes stale data issue (147 vs 213 visitors)
- 24h TTL for offline display — cache older than 24h not shown, error message displayed instead
- Also load cached stats (not just sparklines) in offline mode for complete offline experience

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Load cached stats in offline mode**
- **Found during:** Task 2 (loadFromCache rewrite)
- **Issue:** Original loadFromCache only loaded sparklines, not stats — offline mode would show website cards without any numbers
- **Fix:** Added stats loading from cache alongside sparklines in loadFromCache
- **Files modified:** InsightFlow/Views/Dashboard/DashboardView.swift
- **Verification:** loadFromCache now loads both stats and sparklines
- **Committed in:** 30f8b75

---

**Total deviations:** 1 auto-fixed (1 missing critical)
**Impact on plan:** Essential for complete offline display. No scope creep.

## Issues Encountered
None

## Known Stubs
None — all data paths are wired.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Cache strategy is now online-first across DashboardViewModel
- Pattern can be applied to other ViewModels (WebsiteDetailViewModel etc.) in future plans
- `loadAllAccountsData` does not use loadFromCache — already correct

---
*Phase: 18-aktive-bugs-kritische-fixes*
*Completed: 2026-04-04*
