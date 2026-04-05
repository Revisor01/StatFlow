---
phase: 09-entry-exit-plausible-filters
plan: 02
subsystem: ui
tags: [swift, swiftui, plausible, goals, filters, analytics]

# Dependency graph
requires:
  - phase: 09-entry-exit-plausible-filters/09-01
    provides: Entry/Exit Pages integration via PlausibleAPI cast pattern
provides:
  - GoalConversion model with visitors/events metrics
  - PlausibleAPI.getGoalConversions via event:goal dimension
  - Goals section in WebsiteDetailView for Plausible websites
  - Filter chip bar with 6 dimensions (source, medium, campaign, country, device, browser)
  - FilterSelectionSheet for picking filter values from existing breakdown data
  - applyFilter/removeFilter in WebsiteDetailViewModel with live reload
affects:
  - future Plausible-specific features
  - WebsiteDetailView

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "filterChipBar as @ViewBuilder computed property with sheet state"
    - "GoalConversion parsed from two-metric Plausible v2 results array"
    - "activeFilters array in ViewModel passed to all PlausibleAPI breakdown calls"

key-files:
  created: []
  modified:
    - InsightFlow/Models/PlausibleGoal.swift
    - InsightFlow/Services/PlausibleAPI.swift
    - InsightFlow/Views/Detail/WebsiteDetailViewModel.swift
    - InsightFlow/Views/Detail/WebsiteDetailView.swift
    - InsightFlow/Resources/en.lproj/Localizable.strings
    - InsightFlow/Resources/de.lproj/Localizable.strings

key-decisions:
  - "GoalConversion struct placed in PlausibleGoal.swift (co-location with related Plausible models)"
  - "Filter values sourced from existing ViewModel breakdown data — no extra API calls needed"
  - "website.domain is optional String? — pass with ?? '' default to ViewModel domain param"

patterns-established:
  - "filterChipBar pattern: capsule chips, active state highlighted with accentColor, sheet for value selection"
  - "two-metric Plausible response parsed inline in getGoalConversions (metrics[0]=visitors, metrics[1]=events)"

requirements-completed: [SCREEN-04]

# Metrics
duration: 25min
completed: 2026-03-28
---

# Phase 09 Plan 02: Plausible Goals + Filter Summary

**Plausible Goals section with conversion rates and 6-dimension filter chip bar that live-reloads all metrics on selection**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-03-28
- **Completed:** 2026-03-28
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- GoalConversion model and getGoalConversions method query event:goal dimension with visitors+events metrics via Plausible v2 API
- Goals section in WebsiteDetailView shows goal name, event count, and conversion rate (Plausible-only, hidden for Umami)
- Filter chip bar appears between date picker and hero stats for Plausible websites — 6 dimensions with active/inactive state
- FilterSelectionSheet populates values from existing ViewModel breakdown data (countries, devices, browsers, referrers)
- applyFilter/removeFilter in ViewModel triggers full loadData reload with activeFilters passed to all Plausible API calls

## Task Commits

1. **Task 1: GoalConversion + getGoalConversions + ViewModel state** - `225175c` (feat)
2. **Task 2: Goals Section UI + Filter Chip Bar** - `6f127b1` (feat)

## Files Created/Modified

- `InsightFlow/Models/PlausibleGoal.swift` - Added GoalConversion struct
- `InsightFlow/Services/PlausibleAPI.swift` - Added getGoalConversions method
- `InsightFlow/Views/Detail/WebsiteDetailViewModel.swift` - Added goals, totalVisitors, activeFilters, loadGoals, applyFilter, removeFilter, domain param
- `InsightFlow/Views/Detail/WebsiteDetailView.swift` - Added filterChipBar, goalsSection, FilterSelectionSheet, updated init
- `InsightFlow/Resources/en.lproj/Localizable.strings` - Added goals and filter keys
- `InsightFlow/Resources/de.lproj/Localizable.strings` - Added goals and filter keys

## Decisions Made

- GoalConversion placed in PlausibleGoal.swift for co-location with related Plausible models — no new file needed
- Filter values reuse existing ViewModel breakdown data instead of fetching extra dimensions — UTM source/medium/campaign fall back to referrers list; dedicated UTM dimension queries would require additional PlausibleAPI methods
- website.domain is `String?` in the Website model — passed with `?? ""` default

## Deviations from Plan

**1. [Rule 1 - Bug] website.domain is optional String?, not String**
- **Found during:** Task 2 (WebsiteDetailView init update)
- **Issue:** Plan specified `domain: website.domain` but `Website.domain` is `String?`, causing compile error
- **Fix:** Changed to `domain: website.domain ?? ""`
- **Files modified:** InsightFlow/Views/Detail/WebsiteDetailView.swift
- **Verification:** Build succeeded
- **Committed in:** `6f127b1` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — optional type handling)
**Impact on plan:** Minimal — single nil-coalescing fix, no scope change.

## Known Stubs

- UTM dimensions (visit:medium, visit:campaign) in FilterSelectionSheet return empty arrays — no existing ViewModel property maps to these dimensions. Filter chips appear but selecting opens an empty sheet. Wiring these would require dedicated `utmMediums` and `utmCampaigns` breakdown properties in ViewModel + API calls, which is a separate scope item. The chips are functional for country/device/browser/source where existing data exists.

## Issues Encountered

None beyond the optional String fix above.

## Next Phase Readiness

- SCREEN-04 requirement fulfilled: Goals and filter UI live for Plausible websites
- Phase 09 plans complete — Plausible Entry/Exit pages (09-01) and Goals+Filters (09-02) shipped

---
*Phase: 09-entry-exit-plausible-filters*
*Completed: 2026-03-28*
