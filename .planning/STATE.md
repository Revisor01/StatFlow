---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: milestone
status: executing
stopped_at: Completed 22-01 App Store Listing
last_updated: "2026-04-14T13:31:15.483Z"
last_activity: 2026-04-14 -- Phase 23 execution started
progress:
  total_phases: 1
  completed_phases: 0
  total_plans: 7
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-05)

**Core value:** Nutzer können ihre Website-Analytics sicher und übersichtlich vom iPhone aus überwachen
**Current focus:** Phase 23 — screenshots-assets-submission-en-fr-de

## Current Position

Phase: 23 (screenshots-assets-submission-en-fr-de) — EXECUTING
Plan: 1 of 7
Status: Executing Phase 23
Last activity: 2026-04-14 -- Phase 23 execution started

## Accumulated Context

### Decisions

- App-Name: StatFlow (ersetzt PrivacyFlow/InsightFlow)
- Bundle ID Prefix: de.godsapp.statflow
- Privacy Policy wird auf simonluthe.de gehostet (Hugo-Website)
- Neue "Apps"-Rubrik auf simonluthe.de für alle Apps (CookMy, StatFlow, Valetudios, Guck mal!)
- Guck mal! wird von /guckmal/ in /apps/guckmal/ verschoben
- Testaccounts: Umami (t.godsapp.de, admin) + Plausible (plausible.godsapp.de, test@godsapp.de)
- Screenshot-Sprachen: DE, EN, FR (drei Lokalisierungen für App Store Connect)
- Screenshot-Tooling: Next.js + html-to-image Generator nach `app-store-screenshots-playbook/PLAYBOOK.md` (ValetudiOS-Rezept)
- StatFlow-Logo: weißer Hintergrund, drei schwarze pinselstrichartige Balken (aufsteigendes Balkendiagramm) — Design-Richtung für Screenshots: monochrom, reduziert, analytisch (nicht farbverliebt wie ValetudiOS)

### Roadmap Evolution

- Phase 23 added (2026-04-14): Screenshots, Assets, Video & App Store Submission (DE/EN/FR)

### Blockers/Concerns

None

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 260406-jli | Fix line chart X-axis labels showing time instead of dates in month view | 2026-04-06 | 3c2fd19 | [260406-jli](./quick/260406-jli-fix-line-chart-x-axis-labels-showing-tim/) |
| 260406-jtt | Rename Widget from "Umami Insights" to "StatFlow" | 2026-04-06 | 2dc75b8 | [260406-jtt](./quick/260406-jtt-rename-widget-from-umami-insights-to-sta/) |
| 260407-w5b | Fix "Alle" account filter resets after returning from detail view | 2026-04-07 | 2e3206a | [260407-w5b](./quick/260407-w5b-fix-dashboard-account-filter-resets-from/) |

## Session Continuity

Last session: 2026-04-05
Stopped at: Completed 22-01 App Store Listing
Resume file: .planning/phases/22-app-store-listing/22-01-SUMMARY.md
