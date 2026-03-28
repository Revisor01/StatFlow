# Phase 1: Security Hardening - Context

**Gathered:** 2026-03-27
**Status:** Ready for planning
**Mode:** Infrastructure phase — discuss skipped (pure security/infrastructure)

<domain>
## Phase Boundary

Alle Account-Credentials sind ausschließlich in der Keychain gespeichert — UserDefaults enthält keine Tokens oder API-Keys mehr. Bestehende Accounts werden beim Update migriert. Widget-Tokens sind verschlüsselt und Token-Logging ist entfernt.

Requirements: SEC-01, SEC-02, SEC-03, SEC-04

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — pure infrastructure/security phase. Key technical context:

- KeychainService already exists with per-key storage using `kSecAttrAccount` — extend to support account-ID-scoped keys (e.g., `token_<accountId>`)
- AccountManager stores full `AnalyticsAccount` objects (including `AccountCredentials` with `token`/`apiKey`) in UserDefaults under `analytics_accounts` key — credentials must be stripped from UserDefaults and stored only in Keychain
- SharedCredentials already implements AES-GCM encryption for `widget_credentials.encrypted` — reuse this encryption pattern for `widget_accounts.json`
- Widget code at `InsightFlowWidget.swift:98` logs `acc.token.prefix(10)` via `widgetLog` — must be completely removed
- Migration must be transparent: existing accounts in UserDefaults must be migrated to Keychain on first launch after update without user re-login

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `KeychainService` (InsightFlow/Services/KeychainService.swift): Generic save/load/delete for strings using `kSecClassGenericPassword` with service `de.godsapp.PrivacyFlow`
- `SharedCredentials` (InsightFlow/Services/SharedCredentials.swift): AES-GCM encryption with 256-bit SymmetricKey for widget credential sharing
- `AccountManager.syncAccountsToWidget()`: Current plaintext widget sync — needs to use SharedCredentials encryption

### Established Patterns
- Keychain accessibility: `kSecAttrAccessibleAfterFirstUnlock`
- App Group identifier: `group.de.godsapp.PrivacyFlow`
- Account model: `AnalyticsAccount` with `AccountCredentials` (token: String?, apiKey: String?)
- Provider types: `.umami` (uses token), `.plausible` (uses apiKey)
- Account switching: `applyAccountCredentials()` writes active account to Keychain, `reconfigureFromKeychain()` reads back

### Integration Points
- `AccountManager.addAccount()` / `loadAccounts()` — credential storage path
- `AccountManager.setActiveAccount()` → `applyAccountCredentials()` → Keychain write
- `AuthManager.login()` / `loginPlausible()` — creates AnalyticsAccount with credentials
- Widget: `WidgetAccountsStorage.loadAccounts()` reads `widget_accounts.json`
- `UmamiAPI.reconfigureFromKeychain()` / `PlausibleAPI.reconfigureFromKeychain()` — reads active credentials

</code_context>

<specifics>
## Specific Ideas

No specific requirements — infrastructure phase. Refer to ROADMAP phase description and success criteria.

</specifics>

<deferred>
## Deferred Ideas

None — infrastructure phase.

</deferred>
