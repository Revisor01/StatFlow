# Phase 5: Tests - Context

**Gathered:** 2026-03-28
**Status:** Ready for planning
**Mode:** Infrastructure phase — discuss skipped (pure test implementation)

<domain>
## Phase Boundary

Kritische Pfade sind mit Unit Tests abgedeckt. Zukünftige Refactorings haben ein Sicherheitsnetz.

Requirements: TEST-01

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — pure test implementation phase. Key technical context:

- Kein Test-Target existiert — muss in Xcode-Projekt angelegt werden (InsightFlowTests)
- XCTest als Framework (keine externen Dependencies)
- Phase 1-4 haben KeychainService, AccountManager, API-Clients, DateRange und Cache modifiziert
- KeychainService hat jetzt account-scoped Methoden (saveCredential, loadCredential, deleteCredentials)
- AccountManager ist jetzt einzige Auth-Autorität (AuthManager entfernt in Phase 4)
- PlausibleAPI ist jetzt ein actor (Phase 4), UmamiAPI war schon actor
- AnalyticsProvider-Protokoll hat Default-Implementierungen für Plausible-Lücken
- AnalyticsCacheService ist @unchecked Sendable — Tests sollten Thread-Safety prüfen
- Widget-Code (WidgetNetworking, WidgetStorage) könnte auch Tests bekommen, ist aber nicht im Scope

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- Keine bestehenden Tests — alles neu
- XCTest built-in Framework
- Keychain tests brauchen echten Keychain-Zugriff (Simulator)

### Established Patterns
- `async throws` Pattern bei allen API-Methoden
- `actor` für API-Clients — Tests müssen mit `await` arbeiten
- `@MainActor` für AccountManager — Tests müssen MainActor-Isolation beachten
- UserDefaults für Account-Persistenz (Credentials nur in Keychain)

### Integration Points
- Test-Target muss `InsightFlow` Module importieren
- Keychain-Tests brauchen Simulator (kein macOS Keychain)
- API-Response-Parsing kann mit statischen JSON-Daten getestet werden
- DateRange-Tests sind reine Logik (keine Dependencies)
- Cache-Tests brauchen temporäres Verzeichnis

</code_context>

<specifics>
## Specific Ideas

No specific requirements — infrastructure phase.

</specifics>

<deferred>
## Deferred Ideas

None — infrastructure phase.

</deferred>
