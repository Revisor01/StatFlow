---
gsd_state_version: 1.0
milestone: v2.2
milestone_name: Support & API Coverage
status: executing
stopped_at: Completed 06-01-PLAN.md (Sites-Liste, Goals-API und Filter-Infrastruktur)
last_updated: "2026-03-28T18:50:56.033Z"
last_activity: 2026-03-28
progress:
  total_phases: 4
  completed_phases: 2
  total_plans: 7
  completed_plans: 6
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-28)

**Core value:** Nutzer können ihre Website-Analytics sicher und übersichtlich vom iPhone aus überwachen
**Current focus:** Phase 06 — plausible-api-coverage

## Current Position

Phase: 06 (plausible-api-coverage) — EXECUTING
Plan: 2 of 2
Status: Ready to execute
Last activity: 2026-03-28

## Performance Metrics

**Velocity:**

- Total plans completed: 0
- Average duration: —
- Total execution time: —

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.

- [Phase 01-dashboard-ux-polish]: Picker-in-Menu-Pattern fuer Account-Switcher mit automatischer Checkmark-Markierung
- [Phase 01-dashboard-ux-polish]: @ViewBuilder computed property fuer komplexe Menu-Bodies (Compiler Type-Check-Timeout vermeiden)
- [Phase 03-alle-accounts-ansicht]: Manual Buttons (not Picker) in account switcher Menu for heterogeneous 'Alle' + account options
- [Phase 03-alle-accounts-ansicht]: websiteAccountMap pattern for website-to-account lookup in flat All-mode view
- [Phase 04-support-branding]: Product.emoji vollstaendig durch symbolName ersetzt — kein deprecated-Pfad, sauberer Schnitt
- [Phase 04-support-branding]: tierColor als eigene Product-Extension — View bleibt schlank, ValetudiOS kann direkt nutzen
- [Phase 05-umami-api-coverage]: Alle neuen Modelle Codable+Sendable — actor-API-Clients erfordern Sendable
- [Phase 05-umami-api-coverage]: Identifiable nur wo SwiftUI-Listen-Verwendung sinnvoll (nicht bei reinen Wrapper-Responses)
- [Phase 05-umami-api-coverage]: TeamWebsitesResponse/UserWebsitesResponse/UserTeamsResponse als separate Structs fuer paginierte API-Antworten
- [Phase 05-umami-api-coverage]: getUserTeams (non-admin, GET /api/teams) und getTeams (admin, GET /api/admin/teams) co-existieren — unterschiedliche Endpunkte
- [Phase 06]: PlausibleQueryFilter als Sendable struct mit toQueryParam() — einfacher zu konstruieren als Enum, serialisiert direkt zu [Any] fuer JSONSerialization
- [Phase 06]: buildQueryBody zentralisiert v2 Query-Bau in PlausibleAPI — getBreakdown erhaelt optionalen filters-Parameter ohne Breaking Change
- [Phase 06]: Goals CodingKeys explizit (nicht convertFromSnakeCase) — goal_type/event_name/page_path sind non-obvious, explizite Keys verbessern Lesbarkeit

### Pending Todos

None yet.

### Blockers/Concerns

None.

## Session Continuity

Last session: 2026-03-28T18:50:56.031Z
Stopped at: Completed 06-01-PLAN.md (Sites-Liste, Goals-API und Filter-Infrastruktur)
Resume file: None
Next action: Execute 05-04-PLAN.md
