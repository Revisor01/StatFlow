---
phase: 09-entry-exit-plausible-filters
plan: "01"
subsystem: website-detail-view
tags: [plausible, entry-pages, exit-pages, traffic-flow, localization]
dependency_graph:
  requires: []
  provides: [entry-exit-pages-ui, traffic-flow-section]
  affects: [WebsiteDetailMetricsSections, WebsiteDetailViewModel]
tech_stack:
  added: []
  patterns: [PlausibleAPI-direct-cast, TaskGroup-parallel-load, ViewBuilder-conditional-section]
key_files:
  created: []
  modified:
    - InsightFlow/Views/Detail/WebsiteDetailViewModel.swift
    - InsightFlow/Views/Detail/WebsiteDetailMetricsSections.swift
    - InsightFlow/Resources/en.lproj/Localizable.strings
    - InsightFlow/Resources/de.lproj/Localizable.strings
decisions:
  - "Plausible-only check via provider cast (as? PlausibleAPI) — no protocol change needed"
  - "Side-by-side HStack when both entry and exit data available; full-width GlassCard when only one"
metrics:
  duration: ~3 minutes
  completed: "2026-03-28T21:07:51Z"
  tasks_completed: 1
  files_modified: 4
---

# Phase 09 Plan 01: Traffic Flow Section (Entry/Exit Pages) Summary

Entry/Exit Pages as a "Traffic Flow" section in the Website detail view for Plausible websites, loaded in parallel via TaskGroup and displayed in a side-by-side GlassCard layout.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Entry/Exit Pages laden + Traffic Flow Section | 846e2e5 | WebsiteDetailViewModel.swift, WebsiteDetailMetricsSections.swift, en/de Localizable.strings |

## What Was Built

- `loadEntryPages(dateRange:)` and `loadExitPages(dateRange:)` private methods in `WebsiteDetailViewModel`, both using `guard let plausible = provider as? PlausibleAPI` — Umami providers return early
- Both methods added as concurrent tasks in the existing `loadData` TaskGroup
- `trafficFlowSection` computed property in `WebsiteDetailMetricsSections` with `@ViewBuilder`
- Section only renders when `isPlausible && (!entryPages.isEmpty || !exitPages.isEmpty)`
- When both datasets have data: side-by-side `HStack(alignment: .top, spacing: 16)` with two `GlassCard` views
- When only one dataset has data: single full-width `GlassCard`
- Each row: page path (`.caption`, `lineLimit(1)`) + visitor count (`.caption`, `.fontWeight(.medium)`)
- Top 5 entries shown per card
- Localization: `website.entryPages` (EN: "Entry Pages" / DE: "Einstiegsseiten"), `website.exitPages` (EN: "Exit Pages" / DE: "Absprungseiten")

## Acceptance Criteria Verified

- [x] Plausible websites show Traffic Flow section with Entry/Exit Pages
- [x] Entry/Exit data loaded in parallel via TaskGroup
- [x] Umami websites do NOT show Traffic Flow section (early return on non-PlausibleAPI cast)
- [x] Empty state: section hidden when both arrays are empty
- [x] Localization keys exist in both en and de
- [x] Build succeeds

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — data is fetched from PlausibleAPI and wired directly to the UI.

## Self-Check: PASSED

- [x] `InsightFlow/Views/Detail/WebsiteDetailViewModel.swift` — modified
- [x] `InsightFlow/Views/Detail/WebsiteDetailMetricsSections.swift` — modified
- [x] `InsightFlow/Resources/en.lproj/Localizable.strings` — modified
- [x] `InsightFlow/Resources/de.lproj/Localizable.strings` — modified
- [x] Commit 846e2e5 exists
