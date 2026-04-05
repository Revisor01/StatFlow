---
phase: 13-critical-bug-fixes
plan: 01
subsystem: caching, ui
tags: [swift, swiftui, ios, cache, tdd, analytics]

requires:
  - phase: 12-rename-to-statflow
    provides: AnalyticsCacheService with App Group container support

provides:
  - clearStaleEntries(olderThan:) — deletes cache entries older than N days based on cachedAt
  - evictOldestEntries(maxSize:) — LRU eviction keeping cache under size limit
  - App-start cache cleanup via Task.detached in PrivacyFlowApp.init()
  - DashboardViewModel.loadData(clearFirst:) — clears Published properties before cache load
  - Flash-free account switching via clearFirst: true on accountDidChange

affects: [14-any-future-caching-work, dashboard-data-loading, account-switching]

tech-stack:
  added: []
  patterns:
    - "TDD: test-first for both cache methods and ViewModel behavior"
    - "Task.detached(priority: .background) for non-blocking app-start work"
    - "clearFirst flag pattern for flash-free state transitions"

key-files:
  created:
    - InsightFlowTests/DashboardViewModelTests.swift
  modified:
    - InsightFlow/Services/AnalyticsCacheService.swift
    - InsightFlow/App/InsightFlowApp.swift
    - InsightFlow/Views/Dashboard/DashboardView.swift
    - InsightFlowTests/AnalyticsCacheServiceTests.swift

key-decisions:
  - "clearStaleEntries checks cachedAt (not expiresAt) to catch entries that are stale by age regardless of their TTL"
  - "evictOldestEntries uses contentModificationDate from filesystem for sort — no extra metadata parsing needed"
  - "App-start cleanup runs on background priority Task.detached to not block UI startup"
  - "clearFirst defaults to false to maintain backwards compatibility at all call sites except accountDidChange"

patterns-established:
  - "Cache lifecycle: stale-by-age cleanup + LRU size eviction both triggered on app start"
  - "Account switch loading: clear @Published state first, then load — ProgressView becomes visible immediately"

requirements-completed: [FIX-03, FIX-04]

duration: 30min
completed: 2026-03-29
---

# Phase 13 Plan 01: Cache Lifecycle + Account Switch Loading State Summary

**AnalyticsCacheService extended with stale/LRU cleanup (app-start triggered) and DashboardViewModel clearFirst parameter eliminates account-switch data flash**

## Performance

- **Duration:** ~30 min
- **Started:** 2026-03-29T00:40:00Z
- **Completed:** 2026-03-29T01:01:00Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- `clearStaleEntries(olderThan: 7)` removes JSON cache files whose `cachedAt` is older than N days
- `evictOldestEntries(maxSize: 100MB)` removes oldest files until cache is under the size limit
- App-start (`PrivacyFlowApp.init()`) triggers both cleanup methods on a background `Task.detached`
- `DashboardViewModel.loadData(clearFirst:)` clears `websites`, `stats`, `sparklineData`, `activeVisitors` before loading
- `onReceive(.accountDidChange)` passes `clearFirst: true` so the `ProgressView` overlay becomes visible immediately on account switch
- 8 new tests (5 cache, 3 ViewModel), all green

## Task Commits

1. **Task 1: Cache clearStaleEntries + evictOldestEntries mit Tests** - `cd958d4` (feat)
2. **Task 2: App-Start Cache-Cleanup + Account-Wechsel Loading State mit Tests** - `f8b429c` (feat)

## Files Created/Modified

- `InsightFlow/Services/AnalyticsCacheService.swift` — added `clearStaleEntries` and `evictOldestEntries` methods
- `InsightFlow/App/InsightFlowApp.swift` — `init()` extended with background cache cleanup `Task.detached`
- `InsightFlow/Views/Dashboard/DashboardView.swift` — `loadData` gains `clearFirst` param, `onReceive` uses `clearFirst: true`
- `InsightFlowTests/AnalyticsCacheServiceTests.swift` — 5 new tests for stale/LRU eviction
- `InsightFlowTests/DashboardViewModelTests.swift` — new file, 3 tests for clearFirst behavior

## Decisions Made

- Used `cachedAt` (not `expiresAt`) for stale detection: entries with long TTLs would otherwise survive indefinitely
- `evictOldestEntries` uses filesystem `contentModificationDate` rather than parsing JSON metadata for sorting — simpler and more reliable
- `clearFirst` defaults to `false` to preserve all existing call sites that don't need the clear behavior
- Only `onReceive(.accountDidChange)` passes `clearFirst: true` — other call sites (date range change, sheet callbacks, task) retain old data during reload

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None — TDD cycle completed cleanly. RED/GREEN confirmed at each stage.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Cache lifecycle management fully implemented and tested
- Account-switch loading state fixed — ProgressView guaranteed to show on account change
- Both FIX-03 and FIX-04 requirements satisfied
- No regressions in existing test suites

---
*Phase: 13-critical-bug-fixes*
*Completed: 2026-03-29*
