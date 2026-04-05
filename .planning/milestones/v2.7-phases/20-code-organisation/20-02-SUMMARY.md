---
phase: 20-code-organisation
plan: 02
subsystem: architecture
tags: [dependency-injection, swift, keychain, security, viewmodel]

# Dependency graph
requires:
  - phase: 20-code-organisation
    provides: "Extracted ViewModels into dedicated files (Plan 01)"
provides:
  - "All ViewModels accept injectable API dependencies via init parameters"
  - "KeychainService uses safe guard-let instead of force unwraps"
  - "KeychainError.encodingFailed error case for UTF-8 encoding failures"
affects: [testing, future-mock-injection]

# Tech tracking
tech-stack:
  added: []
  patterns: ["init-parameter DI with .shared defaults for backward compatibility"]

key-files:
  created: []
  modified:
    - "InsightFlow/Views/Dashboard/DashboardViewModel.swift"
    - "InsightFlow/Views/Sessions/SessionsViewModel.swift"
    - "InsightFlow/Views/Realtime/RealtimeViewModel.swift"
    - "InsightFlow/Views/Settings/SettingsViewModel.swift"
    - "InsightFlow/Views/Admin/AdminViewModel.swift"
    - "InsightFlow/Views/Reports/RetentionViewModel.swift"
    - "InsightFlow/Views/Reports/ComparisonViewModel.swift"
    - "InsightFlow/Views/Reports/PagesViewModel.swift"
    - "InsightFlow/Views/Detail/CompareViewModel.swift"
    - "InsightFlow/Views/Events/EventsViewModel.swift"
    - "InsightFlow/Views/Reports/ReportsViewModel.swift"
    - "InsightFlow/Views/Auth/LoginViewModel.swift"
    - "InsightFlow/Services/KeychainService.swift"
    - "InsightFlowTests/KeychainServiceTests.swift"

key-decisions:
  - "DI pattern: init parameters with .shared defaults — zero call-site changes needed"
  - "WebsiteDetailViewModel skipped for direct API DI — uses AnalyticsManager.currentProvider abstraction instead"
  - "AnalyticsManager.shared references kept as-is — provider-type detection only, not data fetching"

patterns-established:
  - "ViewModel DI: init(existingParams..., api: UmamiAPI = .shared) for single-provider VMs"
  - "ViewModel DI: init(existingParams..., umamiAPI: UmamiAPI = .shared, plausibleAPI: PlausibleAPI = .shared) for dual-provider VMs"
  - "DashboardViewModel: also injects AnalyticsCacheService via init"

requirements-completed: [REFACTOR-04, SEC-01]

# Metrics
duration: 5min
completed: 2026-04-04
---

# Phase 20 Plan 02: Dependency Injection + Safe KeychainService Summary

**Init-parameter DI for 15 ViewModels (single+dual provider) with .shared defaults, plus guard-let replacing force unwraps in KeychainService**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-04T21:04:07Z
- **Completed:** 2026-04-04T21:09:00Z
- **Tasks:** 2
- **Files modified:** 14

## Accomplishments
- Converted 15 ViewModels from direct `.shared` singleton assignment to init-parameter injection with defaults
- Eliminated 2 force unwraps in KeychainService (save + saveCredential methods)
- Added KeychainError.encodingFailed case with German error description
- Added test for encodingFailed error case — all tests pass

## Task Commits

Each task was committed atomically:

1. **Task 1+2: DI for ViewModels + KeychainService safety** - `f21d043` (refactor)

**Plan metadata:** pending (docs: complete plan)

## Files Created/Modified
- `InsightFlow/Views/Dashboard/DashboardViewModel.swift` - DI for umamiAPI, plausibleAPI, cache
- `InsightFlow/Views/Sessions/SessionsViewModel.swift` - DI for api (SessionsVM, SessionDetailVM, JourneyVM)
- `InsightFlow/Views/Realtime/RealtimeViewModel.swift` - DI for umamiAPI, plausibleAPI (RealtimeVM, LiveEventDetailVM)
- `InsightFlow/Views/Settings/SettingsViewModel.swift` - DI for umamiAPI, plausibleAPI + new init
- `InsightFlow/Views/Admin/AdminViewModel.swift` - DI for umamiAPI, plausibleAPI + new init
- `InsightFlow/Views/Reports/RetentionViewModel.swift` - DI for api
- `InsightFlow/Views/Reports/ComparisonViewModel.swift` - DI for api
- `InsightFlow/Views/Reports/PagesViewModel.swift` - DI for api
- `InsightFlow/Views/Detail/CompareViewModel.swift` - DI for umamiAPI, plausibleAPI
- `InsightFlow/Views/Events/EventsViewModel.swift` - DI for api
- `InsightFlow/Views/Reports/ReportsViewModel.swift` - DI for api
- `InsightFlow/Views/Auth/LoginViewModel.swift` - DI for umamiAPI, plausibleAPI + replaced inline .shared calls
- `InsightFlow/Services/KeychainService.swift` - guard-let replacing force unwraps, encodingFailed error case
- `InsightFlowTests/KeychainServiceTests.swift` - testKeychainErrorEncodingFailed

## Decisions Made
- WebsiteDetailViewModel not modified: uses AnalyticsManager.shared.currentProvider (protocol-based abstraction), not direct UmamiAPI/PlausibleAPI — different DI approach needed if desired
- AnalyticsManager.shared references in computed properties (isPlausible checks) left as-is — these are provider-type detection, not data-fetching dependencies
- WebsiteCard.swift has UmamiAPI.shared but is a View component, not a ViewModel — out of plan scope

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All ViewModels now testable via mock injection
- KeychainService safe from crash on encoding edge cases
- Ready for test infrastructure or further refactoring phases

---
## Self-Check: PASSED

All 14 modified files verified on disk. Commit f21d043 verified in git log.

---
*Phase: 20-code-organisation*
*Completed: 2026-04-04*
