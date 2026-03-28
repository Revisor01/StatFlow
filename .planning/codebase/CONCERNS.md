# Codebase Concerns

**Analysis Date:** 2026-03-28

## Tech Debt

**Oversized View Files - High Complexity:**
- Issue: Multiple views exceed 600+ lines, combining state management, layout, and logic in single file
- Files:
  - `InsightFlow/Views/Dashboard/DashboardView.swift` (1139 lines)
  - `InsightFlow/Views/Detail/WebsiteDetailView.swift` (766 lines)
  - `InsightFlow/Views/Settings/SettingsView.swift` (755 lines)
  - `InsightFlow/Views/Dashboard/WebsiteCard.swift` (669 lines)
  - `InsightFlow/Views/Sessions/SessionsView.swift` (676 lines)
- Impact: Difficult to test, maintain, and refactor. Hard to isolate state changes. Increases cognitive load when debugging UI issues.
- Fix approach: Extract reusable view components into separate files (e.g., `AccountSwitcherView.swift`, `StatsGridView.swift`, `DateRangePickerSection.swift`). Move view model logic to dedicated ViewModels. Use @ViewBuilder to break large body hierarchies into logical sections.

**Mixed State Management Patterns:**
- Issue: Uses mix of `@StateObject`, `@ObservedObject`, `@Published`, `UserDefaults`, `Keychain`, and `AppGroup` containers for state synchronization across views and widget
- Files:
  - `InsightFlow/Services/AccountManager.swift` (multi-account state + Keychain + UserDefaults + widget sync)
  - `InsightFlow/Services/PlausibleSitesManager.swift` (state sync via flag + UserDefaults + Keychain)
  - `InsightFlow/Views/Dashboard/DashboardView.swift` (local state + external managers)
- Impact: State inconsistency between app and widget; difficult to reason about source of truth; potential race conditions during account switching or site management
- Fix approach: Establish single source of truth per domain: Consider extracting state into a dedicated state container with explicit sync points. Use a state machine pattern for account switching (pending → loading → active). Make widget sync explicit and atomic.

**Duplicate Decoder/Encoder Setup:**
- Issue: Custom JSONDecoder/JSONEncoder instances are defined in multiple service classes with different strategies
- Files:
  - `InsightFlow/Services/UmamiAPI.swift` (custom date formatting with ISO8601 fallback)
  - `InsightFlow/Services/PlausibleAPI.swift` (snake_case conversion)
  - `InsightFlow/Services/AnalyticsCacheService.swift` (ISO8601 date strategy)
- Impact: Inconsistent JSON handling; maintenance burden if API format changes; encoding/decoding errors not consistent across providers
- Fix approach: Create shared `JSON.Configuration` service that provides pre-configured codecs. Use dependency injection to pass decoders to services.

**String-Based Enum Serialization in Cache:**
- Issue: AnalyticsProviderType stored as string in CachedWebsite, requires fallback decoding with default value
- Files: `InsightFlow/Services/AnalyticsCacheService.swift` (line 294)
- Impact: Silent data loss if provider type string is invalid; no warning to developer
- Fix approach: Add explicit validation that throws error on invalid provider type during cache load. Add debug assertion to catch misconfigurations early.

**Actor/MainActor Isolation Boundary Issues:**
- Issue: UmamiAPI and PlausibleAPI use `actor` with `nonisolated` properties that read from Keychain (non-thread-safe), while AccountManager is `@MainActor` and calls async actor methods
- Files:
  - `InsightFlow/Services/UmamiAPI.swift` (actor with nonisolated Keychain reads)
  - `InsightFlow/Services/PlausibleAPI.swift` (actor with nonisolated Keychain reads)
  - `InsightFlow/Services/AccountManager.swift` (MainActor calling actor methods)
- Impact: Potential data race warnings from Swift compiler; actual race condition possible if Keychain is updated while nonisolated property is read
- Fix approach: Use actor-isolated stored properties instead of computed nonisolated properties. Synchronize actor initialization with AccountManager credential application. Consider using a single atomic credential store that the actors can safely read.

## Known Bugs

**Account Switcher Widget Sync Race Condition:**
- Symptoms: Widget sometimes shows old account's data after switching accounts
- Files: `InsightFlow/Services/AccountManager.swift` (line 327), `InsightFlow/Services/PlausibleSitesManager.swift` (line 1046)
- Trigger: Rapid account switching or adding account immediately after login
- Cause: `syncAccountsToWidget()` and `WidgetCenter.shared.reloadAllTimelines()` fire without waiting for credential application to complete. Widget may read stale credentials from SharedCredentials.
- Workaround: Force close and reopen app or manually refresh widget from widget settings

**Plausible "Realtime" Metric Gaps:**
- Symptoms: Realtime top pages/countries show only last 24 hours instead of true realtime data
- Files: `InsightFlow/Services/PlausibleAPI.swift` (lines 344-381)
- Cause: Plausible API does not support dimensions in realtime endpoint; implementation uses "day" breakdown as workaround
- Impact: Users expect rolling 30-minute window but get full daily data; confusing when daily total is 0
- Workaround: None; by design limitation of Plausible API

**Cache Expiration Silent Failure:**
- Symptoms: Expired cache entries may continue to display if network is unavailable
- Files: `InsightFlow/Services/AnalyticsCacheService.swift` (lines 172-196)
- Cause: `clearExpiredCache()` is called but not awaited; entries may be checked after read but before deletion completes
- Impact: Stale data shown to user with no visible indicator that data is expired
- Workaround: Manual "Refresh" button or force data reload by switching date range

**Team Response Parsing Fragility:**
- Symptoms: Team creation may fail or return malformed data
- Files: `InsightFlow/Services/UmamiAPI.swift` (lines 685-726)
- Cause: Tries to decode as array first, then single object. If API changes response format, the try/catch silently fails and throws generic `invalidResponse` error without logging actual response
- Impact: Difficult to debug API issues; team management features become unreliable
- Fix: Log actual response data when parsing fails (currently only in DEBUG); improve error messages

## Security Considerations

**Keychain Data Not Isolated by Account:**
- Risk: Credentials stored with account UUID scoped keys, but fallback lookups use legacy non-scoped keys
- Files: `InsightFlow/Services/AccountManager.swift` (lines 220-257), `InsightFlow/Services/KeychainService.swift`
- Current mitigation: Credentials are stripped from UserDefaults before saving (only in Keychain). Migration validates all stored data.
- Recommendations:
  - Add explicit Keychain query filtering by account UUID during all reads
  - Audit legacy key lookups — ensure they only occur during migration
  - Add test case that verifies credentials are completely isolated between accounts

**Widget Credentials Stored in UserDefaults via AppGroup:**
- Risk: Encrypted JSON stored in UserDefaults but encryption key may be accessible to other apps sharing the group
- Files: `InsightFlow/Services/AccountManager.swift` (line 363-373), `InsightFlow/Services/SharedCredentials.swift`
- Current mitigation: Data is encoded as JSON (not encrypted at application level)
- Recommendations:
  - Document that app group access is limited to same developer team
  - Consider using Keychain with AppGroup access control instead of SharedCredentials
  - Review if encryption is needed at application level (depends on sensitivity of multi-account tokens)

**API Token in Memory During String Operations:**
- Risk: Token passed as String parameter to URLRequest methods; could be logged or captured in memory dumps
- Files: `InsightFlow/Services/UmamiAPI.swift` (line 1190), `InsightFlow/Services/PlausibleAPI.swift` (line 313)
- Current mitigation: None; tokens are nonisolated computed properties reading from Keychain
- Recommendations:
  - Consider using SecureString or similar wrapper that zeros memory after use
  - Audit all places where token appears in log output (currently protected by `#if DEBUG`)
  - Add policy that tokens should never be logged even in DEBUG builds

## Performance Bottlenecks

**LazyVStack in DashboardView with Async Data Binding:**
- Problem: LazyVStack renders WebsiteCard for all websites simultaneously; each card awaits stats loading independently
- Files: `InsightFlow/Views/Dashboard/DashboardView.swift` (lines 39-73)
- Cause: No loading state coordination; all cards fetch data in parallel, creating network spike
- Impact: Slow initial load with many websites (10+); network congestion; battery drain on poor connections
- Improvement path:
  - Implement priority-based loading: fetch visible cards first, defer off-screen cards
  - Add `withThrottling` to batch API requests (max 3 concurrent requests)
  - Cache sparkline data more aggressively (currently 15-min TTL, could be 1 hour for stable data)

**DashboardView Layout Recalculation on Every State Change:**
- Problem: Large VStack hierarchy recalculates on any state change (activeVisitors, sparklineData, stats dict updates)
- Files: `InsightFlow/Views/Dashboard/DashboardView.swift` (body property)
- Cause: No view memoization; body is fully recomputed even when only one website's stats changed
- Impact: Frame drops when scrolling with loading activity; jank during data refresh
- Improvement path:
  - Wrap WebsiteCard in `.id(website.id)` to stabilize SwiftUI diffing
  - Use `EquatableView` wrapper to prevent parent redraws
  - Consider moving sparklineData and activeVisitors into individual WebsiteCard ViewModels

**Account Switching Loads All Data Sequentially:**
- Problem: `loadAllAccountsData()` awaits each account's websites sequentially
- Files: `InsightFlow/Views/Dashboard/DashboardViewModel.swift`
- Impact: Noticeable delay when viewing "All Accounts" mode with multiple Umami/Plausible instances
- Improvement path: Use `async let` to fetch in parallel: `async let umamiSites = account1.getWebsites()` then `let results = try await (umamiSites, plausibleSites)`

**AnalyticsCacheService File I/O Not Async:**
- Problem: Cache save/load operations block the calling thread (file I/O is synchronous)
- Files: `InsightFlow/Services/AnalyticsCacheService.swift` (lines 57-111)
- Impact: Potential UI thread blocking if multiple cache writes happen during data refresh
- Improvement path: Use `FileManager.default.openFile()` async API or dispatch cache I/O to background queue

## Fragile Areas

**Account Switch/Login State Machine Has Multiple Race Conditions:**
- Files: `InsightFlow/Services/AccountManager.swift` (applyAccountCredentials method)
- Why fragile:
  - `setActiveAccount()` updates @Published property before async credential application completes
  - Views can navigate based on activeAccount before API is actually configured
  - Plausible site restoration happens in sequence: widget sync → account update → PlausibleSitesManager notification
  - If any async operation fails (Keychain save, PlausibleAPI reconfiguration), state becomes inconsistent
- Safe modification:
  - Create explicit loading state: `enum AccountState { case loading, active, error }`
  - Don't update activeAccount until ALL async operations complete
  - Add error boundary that reverts account on any configuration failure
  - Test with both Umami and Plausible account switches

**WebsiteCard Dependency on Global KeychainService:**
- Files: `InsightFlow/Views/Dashboard/WebsiteCard.swift` (line 74)
- Why fragile: Card reads serverURL directly from Keychain inside view body, no dependency injection
  - If Keychain state changes, view doesn't refresh (computed property isn't observed)
  - Switching accounts doesn't trigger card re-render with new serverURL
- Safe modification: Pass serverURL as explicit @State or environment value from DashboardView

**PlausibleSitesManager State Flag Workaround:**
- Files: `InsightFlow/Services/PlausibleAPI.swift` (lines 972-976)
- Why fragile: `skipSaveOnSet` flag prevents didSet from saving; multiple concurrent calls could race
  - If `setSitesWithoutPersist()` is called twice rapidly, second call sets flag to true while first is still executing
  - Concurrent updates to sites array bypass persistence entirely
- Safe modification:
  - Use explicit methods instead of flags: `loadSites()`, `setSites()`, `addSite()` with clear persistence semantics
  - Lock access to sites array or use serial dispatch queue
  - Add assertions that document which methods persist vs. don't

**Error Handling in Realtime Data Loading:**
- Files: All metric fetch methods in both UmamiAPI and PlausibleAPI (e.g., line 221-238)
- Why fragile: No retry logic; single network error stops entire metric load
  - If getReferrers() fails, entire detail view shows error
  - No progressive loading (load pages first, then referrers in background)
- Safe modification:
  - Implement exponential backoff retry for transient errors
  - Return partial results: allow detail view to show available metrics even if some fail
  - Add timeout per metric instead of single 30-second timeout for all

## Scaling Limits

**Keychain Storage Limit:**
- Current capacity: ~50 accounts with credentials stored (before Keychain performance degrades)
- Limit: Keychain is not optimized for bulk storage; every credential lookup iterates through all items
- Scaling path: Implement credential cache in memory with Keychain as source of truth. Lazy-load credentials only when account becomes active.

**Cache Directory Unbounded Growth:**
- Current capacity: No cleanup policy; cache grows indefinitely
- Files: `InsightFlow/Services/AnalyticsCacheService.swift`
- Limit: App group container has limited space; could consume GB with many websites/metrics
- Scaling path:
  - Implement LRU eviction: delete oldest cache files when cache exceeds 100MB
  - Add cleanup task on app launch that removes entries older than 7 days
  - Implement per-website cache size limits

**Widget Account Limit (Implicit):**
- Current capacity: Up to ~100 accounts can be serialized to AppGroup UserDefaults
- Limit: JSON serialization of 100 accounts creates 10-50KB payload; widget refresh must decode and iterate all
- Scaling path: Store only active account in SharedCredentials; fetch other accounts on-demand from app container

**Concurrent Request Limit:**
- Current capacity: URLSession.shared uses default configuration (up to 6 concurrent requests per host)
- Limit: DashboardView with 20+ websites creates 20+ concurrent stats requests; may hit rate limits on server
- Scaling path: Implement request queue with max 3 concurrent requests per account. Batch metric requests.

## Dependencies at Risk

**No Network Retry Logic:**
- Risk: Single network glitch causes entire data load to fail
- Impact: User sees error screen instead of cached data
- Migration plan: Add `URLSession` wrapper with exponential backoff. Start with: 1s, 2s, 4s retries on transient errors only.

**Hardcoded Timeout Intervals:**
- Risk: 30-second timeout for all requests; too long for poor connections, too short for large metric queries
- Files: `InsightFlow/Services/UmamiAPI.swift` (line 1192, 1222, 1252), `InsightFlow/Services/PlausibleAPI.swift` (line 314)
- Impact: Unpredictable request failures depending on network condition
- Migration plan: Make timeout configurable per endpoint type. Stats: 20s, realtime: 10s, team: 30s.

## Missing Critical Features

**No Request Cancellation:**
- Problem: If user navigates away from WebsiteDetailView while metrics are loading, requests continue in background
- Impact: Battery drain, network waste, memory pressure from accumulating tasks
- Solution: Implement `withTaskCancellation` or store task handles in ViewModel to cancel on deinit

**No Loading State Transitions:**
- Problem: Switching accounts shows brief flash of old account data before loading new data
- Impact: Perceived lag; user may think action didn't complete
- Solution: Add explicit `isLoading` state to AccountManager that prevents navigation while credentials are being applied

**No Offline Mode UI:**
- Problem: Offline banner shown but no fallback UI or actions for offline state
- Impact: Users can't browse cached data when offline
- Solution: When offline, show cached metrics with visual indicator; allow browsing older date ranges from cache

**No API Change Detection:**
- Problem: If Umami/Plausible API changes response format, app fails silently with generic error
- Impact: No way to debug without examining server logs
- Solution: Log actual response on decode failure. Add optional telemetry to report decode errors.

## Test Coverage Gaps

**No Integration Tests for Multi-Account Switching:**
- What's not tested: Account switch flow with credential persistence → API reconfiguration → widget update
- Files: `InsightFlow/Services/AccountManager.swift`, related ViewModels
- Risk: Critical user flow (switching between Umami and Plausible accounts) could break unnoticed
- Priority: **High** — this is core functionality used by multi-account users

**No Error Path Testing for API Services:**
- What's not tested: 401 unauthorized, 500 server errors, network timeouts, malformed JSON responses
- Files: `InsightFlow/Services/UmamiAPI.swift`, `InsightFlow/Services/PlausibleAPI.swift`
- Risk: Error states propagate with incorrect error messages; no guarantee error recovery works
- Priority: **High** — these are realistic failure scenarios in production

**No Cache Expiration Tests:**
- What's not tested: Cache TTL enforcement, expired entry cleanup, cache load with mixed expired/valid data
- Files: `InsightFlow/Services/AnalyticsCacheService.swift`
- Risk: Cache may serve stale data indefinitely; offline mode may show outdated numbers
- Priority: **Medium** — cache is fallback feature, but affects offline experience

**No Widget Sync Tests:**
- What's not tested: AppGroup credential sync, widget data freshness, multi-account widget updates
- Files: `InsightFlow/Services/AccountManager.swift` (syncAccountsToWidget method), Widget extension code
- Risk: Widget could show stale or incorrect account data
- Priority: **Medium** — widget is secondary feature but is first thing users see

**No Concurrent Operation Tests:**
- What's not tested: Rapid API calls (e.g., switching date range while loading), concurrent account switches, cache write during read
- Risk: Race conditions in actor/MainActor boundary could cause crashes in production
- Priority: **High** — concurrency issues are hard to reproduce and debug

---

*Concerns audit: 2026-03-28*
