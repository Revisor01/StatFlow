# Codebase Concerns

**Analysis Date:** 2026-03-27

## Critical Issues

### Token Logging in Widget Code
- Issue: Auth tokens are partially logged in debug output via `widgetLog`
- Files: `InsightFlowWidget/InsightFlowWidget.swift` (line 98)
- Evidence: `widgetLog("  - \(acc.name): provider=\(acc.providerType), sites=\(acc.sites ?? []), token=\(acc.token.prefix(10))...")`
- Risk: Token prefixes appear in device console logs, accessible via Xcode or Console.app. Even partial tokens can aid credential theft.
- Fix approach: Remove token logging entirely. Log account ID or name only.

### Accounts Stored in UserDefaults (Unencrypted)
- Issue: `AccountManager` stores full account data including API tokens and keys in `UserDefaults` via `analytics_accounts` key. `AccountCredentials` contains `token` (Umami) and `apiKey` (Plausible) in plaintext JSON.
- Files: `InsightFlow/Services/AccountManager.swift` (lines 74, 170, 188)
- Risk: UserDefaults is a plist file on disk without encryption. Device backups may expose credentials. Keychain is used for the *active* account, but all account credentials are also persisted in UserDefaults.
- Fix approach: Store only account metadata (name, serverURL, providerType) in UserDefaults. Store credentials exclusively in Keychain, keyed by account ID.

### Widget Account Data Written Unencrypted to App Group
- Issue: `syncAccountsToWidget()` writes all account tokens to `widget_accounts.json` in the App Group container as plain JSON. This bypasses the encrypted `SharedCredentials` system.
- Files: `InsightFlow/Services/AccountManager.swift` (lines 259-301)
- Risk: Tokens stored in plaintext in App Group container file.
- Fix approach: Use the existing `SharedCredentials` AES-GCM encryption for the multi-account widget file too.

## Technical Debt

| Area | Issue | Severity | Effort |
|------|-------|----------|--------|
| Widget | Massive 2004-line single file duplicates all API networking logic from main app | High | L |
| ViewModel | `WebsiteDetailViewModel` has 15 nearly identical `loadX()` methods with `if isPlausible` branching | Med | M |
| API clients | `UmamiAPI` (actor) and `PlausibleAPI` (@MainActor class) use different concurrency models | Med | M |
| API clients | `PlausibleAPI` duplicates HTTP request/response handling instead of sharing with `UmamiAPI` | Med | M |
| Auth | Three overlapping auth systems: `AuthManager`, `AccountManager`, `AnalyticsManager` all track auth state | High | L |
| Singletons | Excessive use of `.shared` singletons (AccountManager, AnalyticsManager, PlausibleSitesManager, AnalyticsCacheService, QuickActionManager) | Med | L |
| Legacy | Widget still supports legacy single-account `WidgetCredentials` alongside new `WidgetAccountsStorage` | Low | S |
| Cache | `AnalyticsCacheService` marked `@unchecked Sendable` — thread safety not guaranteed | Med | M |
| Print statements | 66 `print()` calls scattered across 21 files, many not wrapped in `#if DEBUG` | Low | S |

## Code Smells

### Massive Files That Should Be Split
- `InsightFlowWidget/InsightFlowWidget.swift` (2004 lines): Contains widget models, credential storage, API networking, UI views, cache logic, and App Intents all in one file. Should be split into at least 5-6 files.
- `InsightFlow/Views/Detail/WebsiteDetailView.swift` (1611 lines): Monolithic view. Extract sections into subviews.
- `InsightFlow/Views/Admin/AdminView.swift` (1318 lines): Full admin panel in one view.
- `InsightFlow/Views/Detail/CompareView.swift` (1183 lines): Period comparison view is overly large.
- `InsightFlow/Views/Dashboard/DashboardView.swift` (1067 lines): Dashboard with inline ordering logic.

### Duplicated Code
- **Provider branching in ViewModel**: Every method in `WebsiteDetailViewModel` (`InsightFlow/Views/Detail/WebsiteDetailViewModel.swift`) follows the pattern `if isPlausible { ... } else { ... }`. The `AnalyticsProvider` protocol exists but isn't leveraged — the ViewModel directly references `UmamiAPI.shared` and `PlausibleAPI.shared` instead of using the protocol.
- **Widget API code**: The widget (`InsightFlowWidget/InsightFlowWidget.swift`) re-implements Umami and Plausible API calls with raw `JSONSerialization` instead of sharing code with the main app targets.
- **URL normalization**: Domain/URL normalization logic is duplicated in `PlausibleAPI.normalizeServerURL()`, `PlausibleAPI.normalizeDomain()`, `PlausibleSitesManager.addSite()`, and `AnalyticsWebsite.displayDomain`.
- **Date range calculations**: Date range to API parameter conversion is duplicated between widget and main app.

### Missing Abstractions
- No shared networking layer — each API class builds `URLRequest` manually with repeated boilerplate (headers, timeout, response validation).
- No error mapping layer — `APIError` (Umami) and `PlausibleError` (Plausible) are separate enums with no unified error type.
- `AnalyticsProvider` protocol exists but is bypassed in `WebsiteDetailViewModel` which directly checks `isPlausible` and calls specific API instances.

## Performance Concerns

### Parallel API Calls Without Rate Limiting
- Problem: `WebsiteDetailViewModel.loadData()` fires 15 parallel API requests simultaneously via `TaskGroup`.
- Files: `InsightFlow/Views/Detail/WebsiteDetailViewModel.swift` (lines 43-59)
- Risk: Server rate limiting may cause failures. No retry logic exists.
- Improvement: Add request batching or throttling. Implement retry with exponential backoff.

### Plausible Stats Require Double API Call
- Problem: `PlausibleAPI.getAnalyticsStats()` makes two sequential API calls (current + previous period) for every stats fetch.
- Files: `InsightFlow/Services/PlausibleAPI.swift` (lines 210-250)
- Risk: Doubles latency for every stats request. Dashboard with 10 sites = 20 requests just for stats.
- Improvement: Use Plausible's `compare` parameter if available, or cache previous period data more aggressively.

### Widget Fetches All Websites for Each Account
- Problem: `WebsiteQuery.fetchAllWebsites()` in the widget makes network requests to fetch website lists from all accounts on every widget refresh.
- Files: `InsightFlowWidget/InsightFlowWidget.swift` (around line 398)
- Risk: Slow widget loading, especially with multiple accounts.
- Improvement: Cache website lists in App Group storage and refresh lazily.

## Maintainability

### Overlapping Auth State Management
- Problem: Auth state is tracked in three places: `AuthManager.isAuthenticated`, `AnalyticsManager.isAuthenticated`, and `AccountManager.activeAccount != nil`. These can go out of sync.
- Files: `InsightFlow/Services/AuthManager.swift`, `InsightFlow/Services/AnalyticsProvider.swift` (AnalyticsManager), `InsightFlow/Services/AccountManager.swift`
- Evidence: `AccountManager.setActiveAccount()` has an empty Task block (lines 147-151) with a comment about not being able to access EnvironmentObject.
- Fix approach: Consolidate to a single source of truth. `AccountManager` should be the sole authority on auth state, with `AuthManager` either removed or reduced to a thin wrapper.

### Timing-Dependent Code
- Problem: Multiple `DispatchQueue.main.asyncAfter` and `Task.sleep` calls used to work around race conditions.
- Files:
  - `InsightFlow/Services/AccountManager.swift` (line 230): 0.3s delay before posting notification
  - `InsightFlow/Services/AuthManager.swift` (line 93): 0.1s sleep waiting for PlausibleSitesManager
- Risk: Fragile timing assumptions. May fail on slower devices or change behavior with OS updates.
- Fix approach: Use proper Combine publishers or async/await coordination instead of arbitrary delays.

### Force Unwraps in Production Code
- Problem: Multiple force unwraps (`!`) in networking code that can crash the app.
- Files:
  - `InsightFlow/Services/PlausibleAPI.swift`: Lines 305, 447, 482, 516, 557, 583 — `URL(string:)!` force unwraps
  - `InsightFlowWidget/InsightFlowWidget.swift`: Lines 959, 1011, 1351 — `.url!` force unwraps on URLComponents
  - `InsightFlow/App/InsightFlowApp.swift`: Line 65 — `task as! BGAppRefreshTask`
  - `InsightFlow/Services/UmamiAPI.swift`: Line 526 — `URLComponents(...)!`
- Fix approach: Replace with `guard let` + proper error handling.

### Inconsistent Concurrency Models
- Problem: `UmamiAPI` is an `actor`, `PlausibleAPI` is `@MainActor class`, and `AnalyticsCacheService` is `@unchecked Sendable`. These different concurrency strategies create confusion about thread safety guarantees.
- Files: `InsightFlow/Services/UmamiAPI.swift`, `InsightFlow/Services/PlausibleAPI.swift`, `InsightFlow/Services/AnalyticsCacheService.swift`
- Fix approach: Standardize on one concurrency pattern. Prefer `actor` for API services and ensure cache service is properly thread-safe.

## Test Coverage Gaps

### No Tests Exist
- What's not tested: The entire codebase has zero test files. No unit tests, no UI tests, no integration tests.
- Files: No test directories or test files found anywhere in the project.
- Risk: Any refactoring (especially the auth consolidation or API abstraction improvements listed above) has no safety net. Regressions are only caught manually.
- Priority: High. At minimum, add tests for:
  1. `KeychainService` — save/load/delete operations
  2. `AccountManager` — account CRUD, credential application, migration
  3. `PlausibleAPI` / `UmamiAPI` — response parsing with mock data
  4. `DateRange` — date calculation correctness
  5. `AnalyticsCacheService` — cache expiry, save/load cycle

## Scaling Limits

### Single Keychain Slot Per Credential Type
- Current: Only one set of credentials (serverURL, token, apiKey) stored in Keychain at a time. Multi-account works by overwriting Keychain on account switch.
- Files: `InsightFlow/Services/KeychainService.swift`, `InsightFlow/Services/AccountManager.swift`
- Limit: Frequent account switching causes repeated Keychain writes. Credentials in UserDefaults act as the real multi-account store (which is the security concern above).
- Fix: Use account-ID-scoped Keychain entries (e.g., `token_<accountId>`).

## Dependencies at Risk

### No External Dependencies
- The project uses zero third-party packages (no SPM, CocoaPods, or Carthage dependencies). This is a strength for maintenance but means all networking, caching, and UI code is custom.

## Recommendations

1. **[Security] Move account credentials from UserDefaults to Keychain** — Store only metadata in UserDefaults, credentials in Keychain keyed by account ID. Encrypt the widget accounts JSON file. Remove token logging.

2. **[Architecture] Consolidate auth management** — Merge `AuthManager`, `AccountManager`, and `AnalyticsManager` into a single `AccountManager` that owns auth state, provider selection, and credential management.

3. **[Architecture] Use AnalyticsProvider protocol properly** — Refactor `WebsiteDetailViewModel` to use `AnalyticsProvider` instead of direct `if isPlausible` branching. This eliminates 15 duplicated methods.

4. **[Quality] Add unit tests** — Start with API response parsing, date range calculations, and account management. These are the most critical paths with the highest regression risk.

5. **[Maintainability] Split widget into multiple files** — Extract models, networking, cache, and views from the 2004-line widget file into a shared framework target.

6. **[Reliability] Replace force unwraps with safe unwrapping** — All `URL(string:)!` and `.url!` calls in `PlausibleAPI` and widget code should use `guard let` with proper error propagation.

7. **[Reliability] Replace timing hacks with proper coordination** — Use Combine publishers or `AsyncStream` instead of `DispatchQueue.main.asyncAfter` and `Task.sleep` for cross-component coordination.

---

*Concerns audit: 2026-03-27*
