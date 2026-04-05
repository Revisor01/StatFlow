# Phase 2: Architektur-Robustheit - Context

**Gathered:** 2026-04-04
**Status:** Ready for planning
**Mode:** Auto-generated (infrastructure phase — discuss skipped)

<domain>
## Phase Boundary

Race Conditions eliminieren, Code-Duplikation reduzieren, Performance verbessern. Umfasst:
- TASK-02: Account-Switch ohne globalen Singleton-State
- REFACTOR-01: `isNetworkError` Extension deduplizieren
- REFACTOR-02: DateFormatter-Instanzen als static Properties
- REFACTOR-05: LazyVStack-Audit — VStack wo conditional Content

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — pure infrastructure/refactoring phase. Use ROADMAP phase goal, success criteria, and codebase conventions to guide decisions.

Note: TASK-02 (Account-Switch) wurde teilweise in Phase 1 adressiert — Plan 03 hat `configureProviderForAccount()` eingeführt. Phase 2 soll prüfen ob noch weitere Stellen betroffen sind.

</decisions>

<code_context>
## Existing Code Insights

Codebase context will be gathered during plan-phase research.

</code_context>

<specifics>
## Specific Ideas

No specific requirements — infrastructure phase.

</specifics>

<deferred>
## Deferred Ideas

None — infrastructure phase.

</deferred>
