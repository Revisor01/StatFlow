# Phase 3: Code-Organisation - Context

**Gathered:** 2026-04-04
**Status:** Ready for planning
**Mode:** Auto-generated (infrastructure phase — discuss skipped)

<domain>
## Phase Boundary

Dateien aufteilen, Dependency Injection einführen, Logging modernisieren. Umfasst:
- REFACTOR-03: ViewModels in eigene Dateien extrahieren (7 Dateien splitten)
- REFACTOR-04: Dependency Injection für ViewModels (init-Parameter mit Default)
- REFACTOR-06: `print()` → `os.Logger` mit Kategorien
- SEC-01: Force Unwraps in KeychainService entfernen

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — pure infrastructure/refactoring phase.

Important context from earlier phases:
- Phase 1 added loadingTask pattern to all ViewModels
- Phase 2 extracted Error+Network.swift and DateFormatters.swift
- ViewModels that were embedded in View files (SessionsView, AdminView, SettingsView, RetentionView, PagesView, InsightsView, RealtimeView) need extraction

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
