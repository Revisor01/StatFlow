# Phase 4: Architektur - Context

**Gathered:** 2026-03-28
**Status:** Ready for planning
**Mode:** Infrastructure phase — discuss skipped (pure architecture refactoring)

<domain>
## Phase Boundary

Die Codebase hat ein einziges Auth-System, API-Clients mit konsistenter Concurrency, und das ViewModel nutzt das AnalyticsProvider-Protokoll ohne `isPlausible`-Branching.

Requirements: ARCH-03, ARCH-02, ARCH-01

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — pure architecture phase. Key technical context:

- ARCH-03: PlausibleAPI ist aktuell `@MainActor class` — muss auf `actor` umgestellt werden (wie UmamiAPI)
- ARCH-02: WebsiteDetailViewModel hat 15+ `if isPlausible` Branches — soll nur noch `currentProvider.methodName()` nutzen
- ARCH-01: AuthManager, AccountManager und AnalyticsManager haben überlappenden Auth-State — AuthManager soll entfernt oder auf thin wrapper reduziert werden
- Phase 1 hat AccountManager bereits als primären Credential-Manager etabliert (Keychain-basiert)
- Phase 3 hat Timing-Hacks in AuthManager entfernt
- PlausibleAPI konformiert bereits zu `AnalyticsProvider` Protokoll
- AnalyticsManager hat `setProvider()` und `isAuthenticated` — könnte in AccountManager integriert werden
- AuthManager wird als EnvironmentObject in Views genutzt — Abhängigkeiten müssen sauber aufgelöst werden

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `AnalyticsProvider` Protokoll definiert die uniforme API-Schnittstelle
- `UmamiAPI` als actor ist das Referenz-Concurrency-Modell
- `AccountManager` hat bereits Credential-Management und Account-Switching

### Established Patterns
- `actor` für API-Services (UmamiAPI)
- `@MainActor class ObservableObject` für UI-nahe Manager
- `nonisolated var` für Protocol-Properties die ohne async gelesen werden müssen
- `AnalyticsManager.shared.setProvider()` für Provider-Wechsel

### Integration Points
- AuthManager als EnvironmentObject in InsightFlowApp.swift
- LoginView, SettingsView, ContentView nutzen authManager
- WebsiteDetailViewModel referenziert UmamiAPI.shared und PlausibleAPI.shared direkt
- AnalyticsManager.shared.currentProvider für Provider-Zugriff

</code_context>

<specifics>
## Specific Ideas

No specific requirements — infrastructure phase.

</specifics>

<deferred>
## Deferred Ideas

None — infrastructure phase.

</deferred>
