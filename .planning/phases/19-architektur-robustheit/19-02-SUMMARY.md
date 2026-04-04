---
phase: 19-architektur-robustheit
plan: 02
subsystem: performance
tags: [dateformatter, iso8601, swift-concurrency, hot-path-optimization]

requires:
  - phase: 19-architektur-robustheit
    provides: "Error+Network dedup and LazyVStack audit from Plan 01"
provides:
  - "Shared DateFormatters enum with 7 static formatters for app-wide reuse"
  - "Zero formatter allocations in computed properties and .map closures"
affects: [any-future-date-parsing, performance-profiling]

tech-stack:
  added: []
  patterns: ["nonisolated(unsafe) static let for non-Sendable shared formatters"]

key-files:
  created:
    - InsightFlow/Extensions/DateFormatters.swift
  modified:
    - InsightFlow/Models/Stats.swift
    - InsightFlow/Views/Detail/WebsiteDetailViewModel.swift
    - InsightFlow/Views/Detail/CompareViewModel.swift
    - InsightFlow/Views/Detail/CompareChartSection.swift
    - InsightFlow/Views/Dashboard/DashboardView.swift

key-decisions:
  - "nonisolated(unsafe) for DateFormatter/ISO8601DateFormatter static lets to satisfy Swift strict concurrency"
  - "shortDate formatter reused for monthSymbols access instead of allocating new DateFormatter"

patterns-established:
  - "DateFormatters.xxx pattern: all date formatting goes through shared enum, never allocate inline"

requirements-completed: [REFACTOR-02]

duration: 6min
completed: 2026-04-04
---

# Phase 19 Plan 02: Shared DateFormatter Instances Summary

**DateFormatters enum with 7 shared static instances replacing 16 hot-path allocations across Stats.swift and 4 ViewModel files**

## Performance

- **Duration:** 6 min
- **Started:** 2026-04-04T20:33:51Z
- **Completed:** 2026-04-04T20:39:45Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Created DateFormatters enum with 7 shared static formatters (iso8601WithFractional, iso8601, yyyyMMdd, shortDate, yyyyMMddHHmmss, mediumDateTime, monthYear)
- Eliminated all 7 formatter allocations in Stats.swift computed properties (called per data point, up to 365x for charts)
- Eliminated all 9 formatter allocations in ViewModel .map closures and data-mapping functions across 4 files
- Zero formatter allocations remain in Models/ and target Views/ directories

## Task Commits

Each task was committed atomically:

1. **Tasks 1+2: Create DateFormatters enum + replace all hot-path allocations** - `d278bc0` (refactor)

**Plan metadata:** pending

## Files Created/Modified
- `InsightFlow/Extensions/DateFormatters.swift` - Shared static DateFormatter/ISO8601DateFormatter instances
- `InsightFlow/Models/Stats.swift` - 7 computed properties now use DateFormatters.xxx
- `InsightFlow/Views/Detail/WebsiteDetailViewModel.swift` - loadPageviews and fillMissingTimeSlots use shared formatters
- `InsightFlow/Views/Detail/CompareViewModel.swift` - loadPlausibleComparison .map closures use shared formatters
- `InsightFlow/Views/Detail/CompareChartSection.swift` - padDataToExpectedCount/B and monthName use shared formatters
- `InsightFlow/Views/Dashboard/DashboardView.swift` - loadFromCache, loadSparkline, fillMissingTimeSlots use shared formatters

## Decisions Made
- Used `nonisolated(unsafe)` on all static lets to satisfy Swift strict concurrency checks, since DateFormatter/ISO8601DateFormatter are not Sendable but are thread-safe for read-only access after initialization
- Reused `DateFormatters.shortDate` for `monthSymbols` access in CompareChartSection.monthName() instead of adding a dedicated formatter

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added nonisolated(unsafe) for Swift strict concurrency**
- **Found during:** Task 1 (build verification)
- **Issue:** ISO8601DateFormatter and DateFormatter are not Sendable, causing compiler errors with strict concurrency
- **Fix:** Added `nonisolated(unsafe)` to all 7 static let declarations
- **Files modified:** InsightFlow/Extensions/DateFormatters.swift
- **Verification:** BUILD SUCCEEDED
- **Committed in:** d278bc0

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary for compilation under Swift strict concurrency. No scope creep.

## Issues Encountered
None beyond the concurrency deviation above.

## User Setup Required
None - no external service configuration required.

## Known Stubs
None - all formatters are fully functional with correct format configurations.

## Next Phase Readiness
- DateFormatters pattern established for all future date formatting needs
- Out-of-scope one-shot allocations in DateRange.swift and CompareView.swift remain (low priority, not in hot paths)

---
*Phase: 19-architektur-robustheit*
*Completed: 2026-04-04*
