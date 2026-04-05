# Phase 1: Aktive Bugs & Kritische Fixes - Context

**Gathered:** 2026-04-04
**Status:** Ready for planning
**Mode:** Auto-generated (infrastructure phase — discuss skipped)

<domain>
## Phase Boundary

Alle bekannten Bugs eliminieren, korrekte Datenflüsse garantieren. Umfasst:
- BUG-01: `@ObservedObject`-Audit — CompareChartSection + alle Child-Views
- BUG-02: Cache-Strategie komplett umbauen — nur Offline-Fallback, nie Vorschau
- BUG-03: Widget Account-Sync Race Condition fixen
- TASK-01: `Task.isCancelled`-Guards in allen 7+ ViewModels nachrüsten

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — pure infrastructure/bugfix phase. Use ROADMAP phase goal, success criteria, and codebase conventions to guide decisions.

Key constraint from STATE.md: Cache dient ausschließlich als Offline-Fallback. Wenn online → immer frische API-Daten.

</decisions>

<code_context>
## Existing Code Insights

Codebase context will be gathered during plan-phase research.

</code_context>

<specifics>
## Specific Ideas

No specific requirements — infrastructure phase. Refer to ROADMAP phase description and success criteria.

</specifics>

<deferred>
## Deferred Ideas

None — infrastructure phase.

</deferred>
