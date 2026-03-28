---
phase: 05-umami-api-coverage
plan: 03
subsystem: api
tags: [swift, umami, reports, api, crud]

# Dependency graph
requires:
  - phase: 05-01
    provides: Report model types (ReportListResponse, Report, FunnelStep, UTMReportItem, GoalReportItem, AttributionItem, PerformanceItem, BreakdownItem, RevenueItem)
provides:
  - Report CRUD API methods (getReports, createReport, getReport, updateReport, deleteReport)
  - 7 specialized report endpoint methods (funnel, utm, goal, attribution, performance, breakdown, revenue)
affects: [05-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Report POST pattern: postRequest with websiteId, type, filters, parameters body"
    - "Date formatting in report bodies uses yyyy-MM-dd string format (not epoch milliseconds)"

key-files:
  created: []
  modified:
    - InsightFlow/Services/UmamiAPI.swift

key-decisions:
  - "Inserted 12 new methods into existing MARK: - Reports section after getRetention, keeping file organization consistent"

patterns-established:
  - "Specialized report methods: postRequest to api/reports/{type} with standardized body shape"
  - "CRUD methods: getReports uses GET with query params, create/update use postRequest, delete uses deleteRequest"

requirements-completed: [API-01]

# Metrics
duration: 8min
completed: 2026-03-28
---

# Phase 05 Plan 03: Report API Methods Summary

**12 Report API methods added to UmamiAPI.swift: 5 CRUD operations and 7 specialized report types (funnel, utm, goal, attribution, performance, breakdown, revenue)**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-03-28T16:30:00Z
- **Completed:** 2026-03-28T16:38:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Added 5 Report CRUD methods: getReports (list with pagination), createReport, getReport, updateReport, deleteReport
- Added 7 specialized report methods: getFunnelReport, getUTMReport, getGoalReport, getAttributionReport, getPerformanceReport, getBreakdownReport, getRevenueReport
- All methods follow the established POST body pattern (websiteId, type, filters, parameters) consistent with existing getRetention and getJourneyReport
- Xcode build passes without errors

## Task Commits

Each task was committed atomically:

1. **Task 1: Report CRUD + spezialisierte Report-Methoden** - `bbe3169` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified
- `InsightFlow/Services/UmamiAPI.swift` - Added 12 Report API methods after the existing getRetention method in MARK: - Reports section

## Decisions Made
None - followed plan as specified. Methods inserted exactly as specified in the plan, after existing getRetention.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- `iPhone 16` simulator not available in current Xcode installation; used `iPhone 17` instead. Build succeeded.

## Next Phase Readiness
- All Report API methods are available for use in ViewModels and Views
- Plan 05-04 can proceed to add any remaining endpoint coverage

---
*Phase: 05-umami-api-coverage*
*Completed: 2026-03-28*
