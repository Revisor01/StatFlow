# Phase 3: Stabilität - Context

**Gathered:** 2026-03-28
**Status:** Ready for planning
**Mode:** Infrastructure phase — discuss skipped (pure stability/reliability fixes)

<domain>
## Phase Boundary

Networking-Code und kritische Pfade stürzen nicht mehr durch Force Unwraps ab. Timing-abhängige Koordination zwischen Komponenten ist durch deterministisches async/await ersetzt.

Requirements: STAB-01, STAB-02

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — pure stability/reliability phase. Key technical context:

- Phase 1 modifizierte AccountManager.swift (Keychain-basierte Credentials) und SharedCredentials.swift
- Phase 2 splitete Widget-Code in 9 Dateien — Force Unwraps im Widget liegen jetzt in WidgetNetworking.swift
- Force Unwraps in PlausibleAPI.swift: Lines 305, 447, 482, 516, 557, 583 — `URL(string:)!`
- Force Unwraps in UmamiAPI.swift: Line 526 — `URLComponents(...)!`
- Force Unwraps in Widget-Code (jetzt WidgetNetworking.swift): vormals Lines 959, 1011, 1351 — `.url!`
- Timing-Hacks in AccountManager.swift: `DispatchQueue.main.asyncAfter(deadline: .now() + 0.3)` (Zeile ~281)
- Timing-Hacks in AuthManager.swift: `Task.sleep` (Zeile ~93) wartet auf PlausibleSitesManager

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `async throws` Pattern bereits durchgängig in API-Clients
- `guard let` Pattern in KeychainService als Referenz
- Combine-Subscriptions bereits in AuthManager (setupNotifications)

### Established Patterns
- API-Methoden: `func methodName() async throws -> ReturnType`
- Error-Enums: `APIError`, `PlausibleError`, `KeychainError`
- `@Published` Properties auf @MainActor Managers

### Integration Points
- PlausibleAPI.swift: alle Force Unwraps in API-Request-Methoden
- UmamiAPI.swift: Force Unwrap in URL construction
- WidgetNetworking.swift: Force Unwraps bei URLComponents
- AccountManager.swift: asyncAfter für Notification-Delay
- AuthManager.swift: Task.sleep für PlausibleSitesManager-Koordination

</code_context>

<specifics>
## Specific Ideas

No specific requirements — infrastructure phase.

</specifics>

<deferred>
## Deferred Ideas

None — infrastructure phase.

</deferred>
