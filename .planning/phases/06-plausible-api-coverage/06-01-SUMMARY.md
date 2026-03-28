---
phase: 06-plausible-api-coverage
plan: 01
subsystem: api
tags: [swift, plausible, rest-api, filter, goals, sites]

# Dependency graph
requires: []
provides:
  - PlausibleGoal, PlausibleGoalsResponse, PlausibleGoalType response models
  - PlausibleQueryFilter + PlausibleFilterOperator for v2 query filter infrastructure
  - getSitesList() — GET /api/v1/sites returns server-side site list
  - getGoals(), createGoal(), deleteGoal() — Goals CRUD via /api/v1/sites/{domain}/goals
  - buildQueryBody() — private v2 query builder with optional filters, dimensions, limit
affects: [06-plausible-api-coverage, future plans using Goals or filter-based queries]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Codable+Sendable structs for all actor-API response models
    - snake_case CodingKeys via explicit enum (not decoder strategy) for model clarity
    - Filter-as-value-type: PlausibleQueryFilter Sendable struct with toQueryParam() serialization
    - buildQueryBody central query builder pattern (DRY for v2 queries)

key-files:
  created:
    - InsightFlow/Models/PlausibleGoal.swift
  modified:
    - InsightFlow/Services/PlausibleAPI.swift

key-decisions:
  - "PlausibleQueryFilter as Sendable struct (not enum) — simpler to construct and compose, toQueryParam() converts to Any array for JSONSerialization"
  - "buildQueryBody refactors getBreakdown — consistent query construction, optional filters propagate cleanly"
  - "Goals CodingKeys explicit (not convertFromSnakeCase) — goal_type/event_name/page_path are non-obvious, explicit keys are clearer"

patterns-established:
  - "Filter pattern: PlausibleQueryFilter { dimension, operator_, values }.toQueryParam() -> [Any]"
  - "Query builder: buildQueryBody(siteId:metrics:dateRange:dimensions:filters:limit:) centralizes v2 body construction"

requirements-completed: [API-02]

# Metrics
duration: 3min
completed: 2026-03-28
---

# Phase 6 Plan 1: Sites-Liste, Goals-API und Filter-Infrastruktur Summary

**Plausible CE v1 Goals CRUD, server-side site listing via GET /api/v1/sites, and reusable v2 query filter infrastructure with PlausibleQueryFilter**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-03-28T18:47:12Z
- **Completed:** 2026-03-28T18:50:02Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- New `InsightFlow/Models/PlausibleGoal.swift` with all five types: PlausibleGoal, PlausibleGoalsResponse, PlausibleGoalType, PlausibleQueryFilter, PlausibleFilterOperator
- PlausibleAPI extended with getSitesList (server-side), getGoals, createGoal, deleteGoal, buildQueryBody
- getBreakdown refactored to use buildQueryBody with optional filters parameter — consistent, DRY v2 query construction

## Task Commits

Each task was committed atomically:

1. **Task 1: Response-Modelle und Filter-Typen** - `31e9e1d` (feat)
2. **Task 2: Sites-Liste, Goals-API und Filter-Infrastruktur in PlausibleAPI** - `9f54823` (feat)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified
- `InsightFlow/Models/PlausibleGoal.swift` — PlausibleGoal (Codable+Sendable+Identifiable), PlausibleGoalsResponse, PlausibleGoalType, PlausibleQueryFilter, PlausibleFilterOperator
- `InsightFlow/Services/PlausibleAPI.swift` — getSitesList(), getGoals(), createGoal(), deleteGoal(), buildQueryBody(), getBreakdown() refactored

## Decisions Made
- `PlausibleQueryFilter` as a Sendable struct (not an enum) — simpler to construct inline, toQueryParam() serializes to [Any] for JSONSerialization
- `buildQueryBody` centralizes v2 query construction — getBreakdown gains optional `filters` parameter at zero cost to existing callers
- Goals use explicit CodingKeys (not decoder snake_case strategy) — goal_type/event_name/page_path are non-obvious, explicit keys improve readability

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered
- Xcode target simulator changed from "iPhone 16" to "iPhone 17" (iOS 26 simulator generation update) — build command adjusted, no code impact.

## User Setup Required
None — no external service configuration required.

## Next Phase Readiness
- Goals CRUD and filter infrastructure ready for Plan 02 (Plausible UI integration or remaining API coverage)
- buildQueryBody accepts filters — any future endpoint can pass PlausibleQueryFilter arrays without additional scaffolding
- All existing methods remain signature-compatible (getBreakdown's filters parameter is optional, default [])

---
*Phase: 06-plausible-api-coverage*
*Completed: 2026-03-28*
