---
phase: 20-code-organisation
plan: 03
subsystem: logging
tags: [os.Logger, structured-logging, swift, console-app]

requires:
  - phase: 20-code-organisation
    provides: Extracted ViewModel files (Plan 01)
provides:
  - Logger+App.swift extension with 4 categories (api, cache, auth, ui)
  - All print() replaced with structured os.Logger calls
  - Zero #if DEBUG print blocks in codebase
affects: [all-services, all-viewmodels]

tech-stack:
  added: [os.Logger]
  patterns: [structured-logging-categories, zero-cost-debug-logging]

key-files:
  created:
    - InsightFlow/Extensions/Logger+App.swift
  modified:
    - InsightFlow/Services/UmamiAPI.swift
    - InsightFlow/Services/PlausibleAPI.swift
    - InsightFlow/Services/AnalyticsCacheService.swift
    - InsightFlow/Services/AccountManager.swift
    - InsightFlow/Services/SharedCredentials.swift
    - InsightFlow/Services/NotificationManager.swift
    - InsightFlow/Services/SupportManager.swift
    - InsightFlow/App/InsightFlowApp.swift
    - InsightFlow/Views/Detail/WebsiteDetailViewModel.swift
    - InsightFlow/Views/Reports/ReportsViewModel.swift
    - InsightFlow/Views/Dashboard/DashboardViewModel.swift
    - InsightFlow/Views/Sessions/SessionsViewModel.swift
    - InsightFlow/Views/Events/EventsViewModel.swift
    - InsightFlow/Views/Realtime/RealtimeViewModel.swift
    - InsightFlow/Views/Reports/PagesViewModel.swift
    - InsightFlow/Views/Admin/AdminViewModel.swift
    - InsightFlow/Views/Detail/CompareViewModel.swift
    - InsightFlow/Views/Reports/ComparisonViewModel.swift
    - InsightFlow/Views/Reports/RetentionViewModel.swift
    - InsightFlow/Views/Settings/SettingsViewModel.swift
    - InsightFlow/Views/Dashboard/AddUmamiSiteView.swift
    - InsightFlow/Views/Dashboard/AddPlausibleSiteView.swift
    - InsightFlow/Views/Dashboard/WebsiteCard.swift

key-decisions:
  - "os.Logger privacy: default privacy (auto-redacted in release) for all interpolated values - no explicit .public annotations needed for debug logging"
  - "Logger.error for catch blocks, Logger.warning for unexpected states, Logger.debug for info messages"

patterns-established:
  - "Logger category convention: api (network calls), cache (persistence), auth (accounts/credentials), ui (ViewModels/Views)"
  - "No #if DEBUG wrappers needed for logging - os.Logger.debug is zero-cost in release builds"

requirements-completed: [REFACTOR-06]

duration: 17min
completed: 2026-04-04
---

# Phase 20 Plan 03: Replace print() with os.Logger Summary

**Structured os.Logger with 4 categories (api/cache/auth/ui) replacing 88 print() statements across 24 files**

## Performance

- **Duration:** 17 min
- **Started:** 2026-04-04T21:10:44Z
- **Completed:** 2026-04-04T21:28:01Z
- **Tasks:** 2
- **Files modified:** 24

## Accomplishments
- Created Logger+App.swift extension with subsystem "de.godsapp.statflow" and 4 filterable categories
- Replaced all 88 print() statements with appropriate Logger calls (debug/error/warning)
- Eliminated all #if DEBUG wrappers — zero remain in codebase
- All logs now filterable in Console.app by subsystem and category
- Build succeeds and all tests pass

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Logger extension and migrate Service files** - `5b6b676` (refactor) — 35 prints in 9 files
2. **Task 2: Migrate ViewModel and View files** - `371af04` (refactor) — 53 prints in 15 files

## Files Created/Modified
- `InsightFlow/Extensions/Logger+App.swift` - Logger extension with 4 categories (api, cache, auth, ui)
- `InsightFlow/Services/UmamiAPI.swift` - 5 prints migrated to Logger.api
- `InsightFlow/Services/PlausibleAPI.swift` - 2 prints migrated to Logger.api
- `InsightFlow/Services/AnalyticsCacheService.swift` - 9 prints migrated to Logger.cache
- `InsightFlow/Services/AccountManager.swift` - 9 prints migrated to Logger.auth
- `InsightFlow/Services/SharedCredentials.swift` - 8 prints migrated to Logger.auth
- `InsightFlow/Services/NotificationManager.swift` - 2 prints migrated to Logger.ui
- `InsightFlow/Services/SupportManager.swift` - 1 print migrated to Logger.ui
- `InsightFlow/App/InsightFlowApp.swift` - 1 print migrated to Logger.ui
- `InsightFlow/Views/Detail/WebsiteDetailViewModel.swift` - 17 prints migrated to Logger.ui
- `InsightFlow/Views/Reports/ReportsViewModel.swift` - 7 prints migrated to Logger.ui
- `InsightFlow/Views/Dashboard/DashboardViewModel.swift` - 5 prints migrated to Logger.ui
- `InsightFlow/Views/Sessions/SessionsViewModel.swift` - 4 prints migrated to Logger.ui
- `InsightFlow/Views/Events/EventsViewModel.swift` - 3 prints migrated to Logger.ui
- `InsightFlow/Views/Realtime/RealtimeViewModel.swift` - 3 prints migrated to Logger.ui
- `InsightFlow/Views/Reports/PagesViewModel.swift` - 2 prints migrated to Logger.ui
- `InsightFlow/Views/Admin/AdminViewModel.swift` - 2 prints migrated to Logger.ui
- `InsightFlow/Views/Detail/CompareViewModel.swift` - 2 prints migrated to Logger.ui
- `InsightFlow/Views/Reports/ComparisonViewModel.swift` - 1 print migrated to Logger.ui
- `InsightFlow/Views/Reports/RetentionViewModel.swift` - 1 print migrated to Logger.ui
- `InsightFlow/Views/Settings/SettingsViewModel.swift` - 1 print migrated to Logger.ui
- `InsightFlow/Views/Dashboard/AddUmamiSiteView.swift` - 1 print migrated to Logger.ui
- `InsightFlow/Views/Dashboard/AddPlausibleSiteView.swift` - 1 print migrated to Logger.ui
- `InsightFlow/Views/Dashboard/WebsiteCard.swift` - 1 print migrated to Logger.ui

## Decisions Made
- Used default privacy for all interpolated values (auto-redacted in release) rather than explicit `.public` — simpler and safer
- Used `Logger.error` for catch blocks (not just debug) to properly categorize log severity
- Used `Logger.warning` for unexpected but non-fatal states (e.g., account not found, no container URL)
- Stripped class-name prefixes from messages since Logger category already identifies the source

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed Bundle not in scope in Logger+App.swift**
- **Found during:** Task 1 (build verification)
- **Issue:** `Bundle.main.bundleIdentifier` requires `import Foundation`, but only `import os` was present
- **Fix:** Added `import Foundation` to Logger+App.swift
- **Files modified:** InsightFlow/Extensions/Logger+App.swift
- **Committed in:** 5b6b676

**2. [Rule 1 - Bug] Removed invalid privacy: .public annotations**
- **Found during:** Task 1 (build verification)
- **Issue:** os.Logger string interpolation does not support `privacy: .public` for Int/count values in the same way — compiler error
- **Fix:** Removed all `privacy: .public` annotations, using default privacy instead
- **Files modified:** UmamiAPI.swift, AnalyticsCacheService.swift, AccountManager.swift, NotificationManager.swift
- **Committed in:** 5b6b676

**3. [Rule 1 - Bug] Fixed implicit self capture in PlausibleSitesManager**
- **Found during:** Task 1 (build verification)
- **Issue:** `Logger.api.debug("... \(sites)")` requires explicit `self.sites` because Logger uses autoclosures
- **Fix:** Changed to `self.sites`
- **Files modified:** InsightFlow/Services/PlausibleAPI.swift
- **Committed in:** 5b6b676

**4. [Rule 2 - Missing Critical] Migrated additional files not in plan**
- **Found during:** Task 1 and Task 2
- **Issue:** Plan listed 88 prints across specific files but SupportManager.swift, InsightFlowApp.swift, ComparisonViewModel.swift, RetentionViewModel.swift, SettingsViewModel.swift, WebsiteCard.swift, AddUmamiSiteView.swift, and AddPlausibleSiteView.swift also had print statements
- **Fix:** Migrated all additional files to achieve zero remaining print() calls
- **Committed in:** 5b6b676 (Services), 371af04 (Views)

---

**Total deviations:** 4 auto-fixed (3 bug fixes, 1 scope extension)
**Impact on plan:** All auto-fixes necessary for correctness. Scope extension ensured truly zero print() calls remain.

## Issues Encountered
None beyond the build errors documented as deviations above.

## Known Stubs
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Structured logging fully operational across entire codebase
- Future code should use Logger.{category} instead of print()
- Console.app filtering available via subsystem "de.godsapp.statflow" and categories api/cache/auth/ui

---
*Phase: 20-code-organisation*
*Completed: 2026-04-04*
