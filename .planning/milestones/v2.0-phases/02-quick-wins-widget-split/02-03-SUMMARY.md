---
phase: 02-quick-wins-widget-split
plan: 03
subsystem: views
tags: [refactoring, view-splitting, struct-02, stab-03]
dependency_graph:
  requires: []
  provides:
    - WebsiteDetailChartSection (chart rendering with @Binding state)
    - WebsiteDetailMetricsSections (location/tech/language/events grouping)
    - WebsiteDetailSupportingViews (shared UI components)
    - CompareChartSection (comparison chart with dual-period rendering)
    - CompareViewModel (ObservableObject for compare data loading)
    - CompareHeroCard (comparison metric card component)
    - AdminCards (WebsiteAdminCard, TeamCard, UserCard, PlausibleSiteAdminCard)
    - AdminSheets (all admin sheet views)
  affects:
    - WebsiteDetailView (reduced to 555 lines, uses new subviews)
    - CompareView (reduced to 402 lines, uses new subviews)
    - AdminView (reduced to 502 lines, uses new subviews)
tech_stack:
  added: []
  patterns:
    - View extraction with @Binding for mutable state
    - let parameters for read-only ViewModel access
    - "#if DEBUG print() wrapping"
key_files:
  created:
    - InsightFlow/Views/Detail/WebsiteDetailChartSection.swift
    - InsightFlow/Views/Detail/WebsiteDetailMetricsSections.swift
    - InsightFlow/Views/Detail/WebsiteDetailSupportingViews.swift
    - InsightFlow/Views/Detail/CompareChartSection.swift
    - InsightFlow/Views/Detail/CompareViewModel.swift
    - InsightFlow/Views/Detail/CompareHeroCard.swift
    - InsightFlow/Views/Admin/AdminCards.swift
    - InsightFlow/Views/Admin/AdminSheets.swift
  modified:
    - InsightFlow/Views/Detail/WebsiteDetailView.swift
    - InsightFlow/Views/Detail/CompareView.swift
    - InsightFlow/Views/Admin/AdminView.swift
decisions:
  - "View extraction pattern: mutable state via @Binding, read-only ViewModel as let parameter"
  - "CompareViewModel extracted into own file to allow independent testing"
  - "Chart interaction helpers duplicated into CompareChartSection (not shared) to keep subview self-contained"
metrics:
  duration: "~45min"
  completed: "2026-03-28"
  tasks: 2
  files_created: 8
  files_modified: 3
---

# Phase 02 Plan 03: View Split — WebsiteDetailView, CompareView, AdminView Summary

Three 1000+ line view monoliths split into focused subview files. All views are now under 600 lines. 4 unwrapped print() calls wrapped in `#if DEBUG`. Project builds successfully.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | WebsiteDetailView + CompareView Subviews | cda82b5 | 7 files (6 created, 1 modified each) |
| 2 | AdminView Subviews + Build Verify | 57b8f18 | 3 files (2 created, 1 modified) |

## Results

| File | Before | After | Reduction |
|------|--------|-------|-----------|
| WebsiteDetailView.swift | 1611 lines | 555 lines | -65% |
| CompareView.swift | 1183 lines | 402 lines | -66% |
| AdminView.swift | 1319 lines | 502 lines | -62% |

## Extracted Files

**Detail Views:**
- `WebsiteDetailChartSection.swift` — Complete chart rendering (line/bar, overlays, x-axis logic) with `@Binding` for selectedMetric, selectedChartPoint, selectedChartStyle
- `WebsiteDetailMetricsSections.swift` — Location, Tech, Language+Screen, Events sections, all helper functions duplicated (countryFlag, deviceColor etc.)
- `WebsiteDetailSupportingViews.swift` — SectionHeader, DateRangeChip, HeroStatCard, HeroStatCardWithLink, GlassCard, QuickActionCard, LegendItem, CustomDateRangePicker
- `CompareChartSection.swift` — Comparison chart (line+bar), data padding logic for both periods, chart interaction handlers
- `CompareViewModel.swift` — @MainActor ObservableObject for Umami and Plausible comparison data loading
- `CompareHeroCard.swift` — Metric comparison card with period A/B values and trend indicator

**Admin Views:**
- `AdminCards.swift` — WebsiteAdminCard, TeamCard, UserCard, PlausibleSiteAdminCard
- `AdminSheets.swift` — CreateWebsiteSheet, CreateTeamSheet, CreateUserSheet, TrackingCodeSheet, PlausibleTrackingCodeSheet, ShareLinkSheet, EditWebsiteSheet, TeamMemberSheet

## Deviations from Plan

### Auto-fixed Issues

None — plan executed exactly as written.

### print() Wrapping (STAB-03 partial)

4 unwrapped print() calls wrapped in `#if DEBUG`:
- `CompareViewModel.swift` lines ~70, ~80: `loadPlausibleComparison` and `loadUmamiComparison` error prints
- `AdminView.swift` (AdminViewModel): `loadTeams` and `loadUsers` error prints

## Self-Check: PASSED

All required files exist and commits are present.
