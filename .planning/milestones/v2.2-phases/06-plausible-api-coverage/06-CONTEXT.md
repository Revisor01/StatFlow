# Phase 06: Plausible API Coverage - Context

**Gathered:** 2026-03-28
**Status:** Ready for planning
**Mode:** Auto-generated (infrastructure phase — API endpoint implementation)

<domain>
## Phase Boundary

Vollständige Abdeckung aller Plausible CE Self-Hosted API-Endpunkte. Audit der bestehenden PlausibleAPI.swift gegen die offizielle Plausible CE REST API Dokumentation, dann fehlende Endpunkte und Filter implementieren.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — infrastructure phase (API endpoint implementation). Use existing PlausibleAPI actor pattern, follow established conventions. Key guidelines:
- PlausibleAPI is an actor — maintain this pattern
- Follow existing v2 Query API pattern for new dimensions/metrics
- Implement missing filter support in v2 Query API
- Add Sites list endpoint (GET /api/v1/sites)
- Add Goals API endpoints
- Add missing dimensions: UTM (source, medium, campaign), entry/exit pages
- Add missing metrics: scroll_depth, time_on_page, views_per_visit, conversion_rate
- Plausible CE is privacy-first — no session-level data (by design, not a gap)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- PlausibleAPI.swift — actor with v1 (sites, realtime) and v2 (flexible query) endpoints
- Existing response models for stats, timeseries, breakdown
- DateRange utilities shared with UmamiAPI

### Established Patterns
- actor-based API client with async/await
- v2 Query API uses single flexible endpoint with metrics/dimensions paradigm
- Codable structs for responses

### Integration Points
- AnalyticsProvider protocol
- WebsiteDetailViewModel
- DashboardViewModel

</code_context>

<specifics>
## Specific Ideas

No specific requirements — audit existing implementation against Plausible CE API docs and fill gaps.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>
