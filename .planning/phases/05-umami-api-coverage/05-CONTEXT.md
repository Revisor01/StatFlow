# Phase 05: Umami API Coverage - Context

**Gathered:** 2026-03-28
**Status:** Ready for planning
**Mode:** Auto-generated (infrastructure phase — API endpoint implementation)

<domain>
## Phase Boundary

Vollständige Abdeckung aller Umami Self-Hosted API-Endpunkte. Audit der bestehenden UmamiAPI.swift gegen die offizielle Umami REST API Dokumentation, dann fehlende Endpunkte implementieren.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — infrastructure phase (API endpoint implementation). Use existing UmamiAPI actor pattern, follow established conventions from the codebase. Key guidelines:
- UmamiAPI is an actor — maintain this pattern
- Follow existing endpoint implementation style (URL construction, response parsing, error handling)
- Add new response model structs as needed in the Models/ directory
- Prioritize endpoints that provide user-visible data (events, funnels, UTM, goals, session aggregates)
- Lower priority: admin-only endpoints (users CRUD, teams management) that aren't needed for a read-only analytics viewer

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- UmamiAPI.swift — actor with ~30 implemented endpoints
- Existing response models for websites, stats, pageviews, metrics, sessions, realtime
- DateRange utilities for API date parameters
- CacheManager for response caching

### Established Patterns
- actor-based API client with async/await
- URLSession for networking
- JSONDecoder with custom date strategies
- Error handling via custom APIError enum

### Integration Points
- AnalyticsProvider protocol — new endpoints may need protocol additions
- WebsiteDetailViewModel — consumes API data for detail views
- DashboardViewModel — consumes API data for dashboard

</code_context>

<specifics>
## Specific Ideas

No specific requirements — audit existing implementation against Umami API docs and fill gaps.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>
