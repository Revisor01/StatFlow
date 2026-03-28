---
phase: 08-events-reports-screens
plan: 02
subsystem: ui
tags: [swiftui, reports, funnel, utm, goals, attribution, umami]

# Dependency graph
requires:
  - phase: 08-01-events
    provides: Events views pattern (Sessions-style drill-down, DateRange picker)
provides:
  - Reports.swift models (Report, FunnelStep, UTMReportItem, GoalReportItem, AttributionItem)
  - ReportsViewModel with all 4 report type loaders
  - ReportsHubView with 4 NavigationLink category cards
  - UTMReportView, AttributionReportView, FunnelReportView, GoalReportView
  - UmamiAPI report methods (getReports, getFunnelReport, getUTMReport, getGoalReport, getAttributionReport)
affects: [08-03-integration, reports, umami-api]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - ReportsViewModel as @MainActor ObservableObject with per-report-type load methods
    - JSON parameters parsing from Report.parameters string for Funnel/Goal steps
    - Empty state using ContentUnavailableView for missing data vs. missing configuration
    - LazyVGrid 2-column layout for hub-style category overview

key-files:
  created:
    - InsightFlow/Models/Reports.swift
    - InsightFlow/Views/Reports/ReportsViewModel.swift
    - InsightFlow/Views/Reports/ReportsHubView.swift
    - InsightFlow/Views/Reports/ReportDetailViews.swift
  modified:
    - InsightFlow/Services/UmamiAPI.swift
    - InsightFlow/Resources/en.lproj/Localizable.strings
    - InsightFlow/Resources/de.lproj/Localizable.strings

key-decisions:
  - "Created Reports.swift and added UmamiAPI report methods as auto-fix (Rule 3 - missing blocking dependencies not added by 08-01 yet)"
  - "Funnel/Goal views show ContentUnavailableView when no reports configured in Umami, UTM/Attribution load data directly"
  - "TagBadge helper view for source/medium/campaign display in UTM and Attribution rows"

patterns-established:
  - "Hub view with LazyVGrid + NavigationLink cards for multi-section navigation"
  - "Separate viewModel per detail view (StateObject init from parent parameters)"

requirements-completed: [SCREEN-02]

# Metrics
duration: 5min
completed: 2026-03-28
---

# Phase 08 Plan 02: Reports Hub and Detail Views Summary

**Reports-Hub mit 4 Karten (Funnel, UTM, Goals, Attribution) und zugehoerige Detail-Views mit leerem Zustand fuer fehlende Konfiguration vs. fehlende Daten**

## Performance

- **Duration:** 5 min
- **Started:** 2026-03-28T20:43:31Z
- **Completed:** 2026-03-28T20:48:19Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments
- Reports.swift Datenmodelle fuer alle 4 Report-Typen (inkl. computed properties fuer dropoffRate/completionRate)
- UmamiAPI um 5 neue Methoden erweitert: getReports, getFunnelReport, getUTMReport, getGoalReport, getAttributionReport
- ReportsViewModel mit sauberem Loading-Pattern, JSON-Parameter-Parsing fuer Funnel/Goal Reports
- ReportsHubView mit 2-Spalten-Grid und 4 Kategorie-Karten als NavigationLinks
- Alle 4 Detail-Views mit Loading State, Empty State, Daten-Anzeige
- Funnel- und Goal-Views unterscheiden zwischen "keine Reports konfiguriert" und "keine Daten"
- 23 Lokalisierungs-Keys in en.lproj und de.lproj

## Task Commits

1. **Task 1: ReportsViewModel mit Data Loading** - `6a8685d` (feat)
2. **Task 2: ReportsHubView und Report-Detail-Views** - `01af9d0` (feat)

## Files Created/Modified
- `InsightFlow/Models/Reports.swift` - Report, FunnelStep, UTMReportItem, GoalReportItem, AttributionItem Modelle
- `InsightFlow/Views/Reports/ReportsViewModel.swift` - ViewModel mit 5 Load-Methoden, JSON-Parameter-Parsing
- `InsightFlow/Views/Reports/ReportsHubView.swift` - Hub mit 4 NavigationLink-Karten, ReportCategoryCard
- `InsightFlow/Views/Reports/ReportDetailViews.swift` - UTMReportView, AttributionReportView, FunnelReportView, GoalReportView, TagBadge
- `InsightFlow/Services/UmamiAPI.swift` - 5 neue Report-API-Methoden hinzugefuegt
- `InsightFlow/Resources/en.lproj/Localizable.strings` - 23 reports.* Keys
- `InsightFlow/Resources/de.lproj/Localizable.strings` - 23 reports.* Keys (Deutsch)

## Decisions Made
- Separater `ReportsViewModel` pro Detail-View (nicht geteilt) — sauberes State-Isolation fuer unabhaengige Navigation
- FunnelReportView und GoalReportView erhalten `reports: [Report]` als Parameter vom Hub und laden sofort bei `onAppear` den ersten Report
- TagBadge fuer UTM/Attribution-Felder: konsistente Darstellung von source/medium/campaign als farbige Capsules

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Reports.swift Modell-Datei erstellt**
- **Found during:** Task 1 (ReportsViewModel)
- **Issue:** Plan referenziert InsightFlow/Models/Reports.swift, aber die Datei existiert nicht (08-01 noch nicht ausgefuehrt)
- **Fix:** Reports.swift mit allen 4 Model-Typen (Report, FunnelStep, UTMReportItem, GoalReportItem, AttributionItem) erstellt
- **Files modified:** InsightFlow/Models/Reports.swift (neu)
- **Verification:** Build erfolgreich
- **Committed in:** 6a8685d (Task 1 commit)

**2. [Rule 3 - Blocking] UmamiAPI Report-Methoden hinzugefuegt**
- **Found during:** Task 1 (ReportsViewModel)
- **Issue:** Plan referenziert getReports, getFunnelReport, getUTMReport, getGoalReport, getAttributionReport — keine dieser Methoden in UmamiAPI vorhanden
- **Fix:** Alle 5 Methoden mit korrekten API-Endpunkten und Body-Parametern implementiert
- **Files modified:** InsightFlow/Services/UmamiAPI.swift
- **Verification:** Build erfolgreich, ViewModel kompiliert
- **Committed in:** 6a8685d (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (2x Rule 3 - blocking missing dependencies)
**Impact on plan:** Beide Fixes notwendig da 08-01 noch nicht in diesem Worktree ausgefuehrt wurde. Kein Scope Creep.

## Issues Encountered
- Simulator "iPhone 16" nicht mehr verfuegbar (iOS 26 Simulatoren), Build mit "iPhone 17" durchgefuehrt

## User Setup Required
None - keine externe Service-Konfiguration erforderlich.

## Next Phase Readiness
- ReportsHub und alle 4 Detail-Views bereit fuer Integration in WebsiteDetailView (08-03)
- Reports-Navigation via QuickActionCard in WebsiteDetailView (Phase 08-03 Aufgabe)
- Alle Report-Typen mit Empty States und Loading States implementiert

---
*Phase: 08-events-reports-screens*
*Completed: 2026-03-28*
