---
phase: 14-code-cleanup
plan: 01
subsystem: API / Models
tags: [dead-code-removal, cleanup, UmamiAPI, swift]
requirements: [CLEAN-01]

dependency_graph:
  requires: []
  provides: [lean-UmamiAPI, cleaned-Admin-models, cleaned-Share-models, cleaned-Reports-models]
  affects: [InsightFlow/Services/UmamiAPI.swift, InsightFlow/Models/Admin.swift, InsightFlow/Models/Share.swift, InsightFlow/Models/Reports.swift]

tech_stack:
  added: []
  patterns: [dead-code-deletion]

key_files:
  created: []
  modified:
    - InsightFlow/Services/UmamiAPI.swift
    - InsightFlow/Models/Admin.swift
    - InsightFlow/Models/Share.swift
    - InsightFlow/Models/Reports.swift

decisions:
  - "Share.swift reduced to empty import — all types (SharePage, ShareListResponse, MeResponse) were exclusively used by deleted API methods"
  - "Stats.swift and Events.swift contain additional orphaned types (SessionStatsResponse, WeeklySessionPoint, EventDataResponse, etc.) — deferred, not in plan scope"

metrics:
  duration_seconds: 269
  completed_date: "2026-03-29"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 4
---

# Phase 14 Plan 01: UmamiAPI Dead Code Removal Summary

**One-liner:** Removed 43 unused API methods from UmamiAPI.swift (1295 → 847 lines) and cleaned orphaned model types from Admin.swift, Share.swift, and Reports.swift; build passes cleanly.

## What Was Done

Deleted all 43 unused Umami API methods identified in the research phase, then removed the model types that became orphaned after those deletions. The project compiles without errors after all changes.

## Tasks Completed

| Task | Description | Commit | Lines Removed |
|------|-------------|--------|---------------|
| 1 | Remove 43 unused methods from UmamiAPI.swift | 7c39da4 | 448 |
| 2 | Clean orphaned model types + verify build | a16bb40 | 94 |

## Methods Removed (43 total)

**MARK: - Me (3):** getMe, getMyTeams, getMyWebsites

**MARK: - Stats/Metrics (3):** getDateRange, getEventsSeries, getExpandedMetrics

**MARK: - Event Data (5):** getEventData, getEventDataById, getEventDataFields, getEventDataProperties, getEventDataStats

**MARK: - Sessions (5):** getSessionStats, getSessionsWeekly, getSessionProperties, getSessionDataProperties, getSessionDataValues

**MARK: - Website Management (1):** resetWebsiteStats

**MARK: - Teams (7):** getUserTeams, joinTeam, getTeam, updateTeam, getTeamMember, updateTeamMemberRole, getTeamWebsites

**MARK: - Users (Admin) (4):** getUser, updateUser, getUserWebsites, getUserTeamsList

**MARK: - Admin (1):** getAdminWebsites

**MARK: - Share (6):** createSharePage, getSharePage, updateSharePage, deleteSharePage, getWebsiteShares, createWebsiteShare

**MARK: - Reports (4):** createReport, getReport, updateReport, deleteReport

**MARK: - Report Types (3):** getPerformanceReport, getBreakdownReport, getRevenueReport

## Model Types Removed

- **Admin.swift:** TeamWebsitesResponse, UserWebsitesResponse, UserTeamsResponse
- **Share.swift:** SharePage, ShareListResponse, MeResponse (file now empty)
- **Reports.swift:** PerformanceItem, BreakdownItem, RevenueItem, RevenueComparison

## Methods Kept (verified still in use)

getWebsites, getWebsite, getStats, getPageviews, getRealtime, getActiveVisitors, getMetrics, getEventsDetail, getEventsStats, getEventDataEvents, getEventDataValues, getSessions, getSessionActivity, getSession, getJourneyReport, getTeams, createTeam, deleteTeam, getTeamMembers, addTeamMember, removeTeamMember, getUsers, createUser, deleteUser, getReports, getFunnelReport, getUTMReport, getGoalReport, getAttributionReport, getRetention + all AnalyticsProvider protocol methods

## Build Verification

```
** BUILD SUCCEEDED **
```
(via `xcodebuild build -project InsightFlow.xcodeproj -scheme InsightFlow -destination 'platform=iOS Simulator,name=iPhone 17'`)

## Deviations from Plan

None — plan executed exactly as written.

The plan listed `getTeamMember` as unused but there is also a kept `getTeamMembers` (plural) — both were correctly handled (singular deleted, plural kept).

## Deferred Items

The following model types in other files are now also orphaned (referenced only in their own model file) but were outside the explicit scope of this plan:

- **Stats.swift:** SessionStatsResponse, WeeklySessionPoint, SessionPropertyItem, SessionDataProperty, SessionDataValue, DateRangeResponse, ExpandedMetricItem, EventData
- **Events.swift:** EventDataResponse, EventDataItem, EventDataField, EventDataProperty, EventDataStats

These can be cleaned in a future cleanup pass.

## Known Stubs

None.

## Self-Check: PASSED

- [x] InsightFlow/Services/UmamiAPI.swift exists and contains `func getWebsites`
- [x] InsightFlow/Models/Admin.swift exists and does not contain TeamWebsitesResponse
- [x] InsightFlow/Models/Share.swift exists (empty except import)
- [x] InsightFlow/Models/Reports.swift exists and does not contain PerformanceItem
- [x] Commits 7c39da4 and a16bb40 exist in git log
- [x] BUILD SUCCEEDED verified
