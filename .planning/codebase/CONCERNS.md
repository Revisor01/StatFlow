# Codebase Concerns

**Analysis Date:** 2026-04-04

## Tech Debt

**`let viewModel` in CompareChartSection — Missing @ObservedObject (ACTIVE BUG):**
- Issue: `CompareChartSection` declares `let viewModel: CompareViewModel` instead of `@ObservedObject var viewModel: CompareViewModel`. This is the exact pattern that caused 11 bugs fixed on 2026-04-04 where data loaded but never displayed.
- Files: `InsightFlow/Views/Detail/CompareChartSection.swift` (line 5)
- Impact: CompareChartSection will NOT re-render when `CompareViewModel` publishes changes. Chart data may appear stale or empty after initial load.
- Fix approach: Change `let viewModel: CompareViewModel` to `@ObservedObject var viewModel: CompareViewModel`. Audit all child views that receive an `ObservableObject` to ensure they use `@ObservedObject`, never `let`.

**Oversized View Files — High Complexity:**
- Issue: Multiple files exceed 600+ lines, combining state management, layout, networking, and logic in single files
- Files:
  - `InsightFlow/Views/Dashboard/DashboardView.swift` (1189 lines — includes DashboardViewModel, DashboardView, add-account sheet, all data loading)
  - `InsightFlow/Services/PlausibleAPI.swift` (1048 lines)
  - `InsightFlow/Services/UmamiAPI.swift` (890 lines)
  - `InsightFlow/Views/Detail/WebsiteDetailView.swift` (786 lines)
  - `InsightFlow/Views/Settings/SettingsView.swift` (742 lines — includes SettingsViewModel embedded)
  - `InsightFlow/Views/Sessions/SessionsView.swift` (706 lines — includes SessionsViewModel, SessionDetailViewModel, JourneyViewModel all in one file)
  - `InsightFlow/Views/Realtime/RealtimeView.swift` (650 lines — includes RealtimeViewModel, LiveEventDetailViewModel)
- Impact: Difficult to test, maintain, and isolate changes. ViewModels embedded in view files cannot be tested independently. Increases cognitive load when debugging.
- Fix approach: Extract each ViewModel into its own file. Break large views into focused sub-views. `DashboardView.swift` should be split into at least `DashboardView.swift`, `DashboardViewModel.swift`, and `AddAccountSheet.swift`.

**Duplicated Network Error Detection (5 identical blocks):**
- Issue: The same 5-line network error detection pattern (`isNetworkError = (error as? URLError)?.code == .notConnectedToInternet || ...`) is copy-pasted in 5 different ViewModels
- Files:
  - `InsightFlow/Views/Reports/ReportsViewModel.swift` (lines 57-62)
  - `InsightFlow/Views/Events/EventsViewModel.swift` (lines 43-48)
  - `InsightFlow/Views/Dashboard/DashboardView.swift` (lines 961-965)
  - `InsightFlow/Views/Sessions/SessionsView.swift` (lines 516-520)
  - `InsightFlow/Views/Detail/WebsiteDetailViewModel.swift` (lines 91-95)
- Impact: If a new error code needs handling (e.g., `.dataNotAllowed` for cellular restrictions), it must be updated in 5 places. Easy to miss one.
- Fix approach: Extract to a shared utility: `extension Error { var isNetworkError: Bool { ... } }` in `InsightFlow/Extensions/`.

**Duplicate Decoder/Encoder Setup:**
- Issue: Custom JSONDecoder/JSONEncoder instances defined in multiple service classes with different strategies
- Files:
  - `InsightFlow/Services/UmamiAPI.swift` (custom date formatting with ISO8601 fallback, lines 21-48)
  - `InsightFlow/Services/PlausibleAPI.swift` (snake_case conversion, line 23-27)
  - `InsightFlow/Services/AnalyticsCacheService.swift` (ISO8601 date strategy)
- Impact: Inconsistent JSON handling; maintenance burden if API format changes
- Fix approach: Create shared `JSON.Configuration` service. Use dependency injection to pass decoders to services.

**DateFormatter Created Repeatedly in Hot Paths:**
- Issue: `ISO8601DateFormatter()` and `DateFormatter()` are instantiated repeatedly inside loops and data-mapping closures instead of being reused as static properties
- Files:
  - `InsightFlow/Views/Dashboard/DashboardView.swift` (lines 995, 1104, 1142 — inside data loading loops)
  - `InsightFlow/Views/Detail/WebsiteDetailViewModel.swift` (lines 120, 179)
  - `InsightFlow/Views/Detail/CompareChartSection.swift` (lines 420, 483, 558)
  - `InsightFlow/Views/Detail/CompareViewModel.swift` (line 68)
  - `InsightFlow/Models/Stats.swift` (lines 107, 224, 284, 291, 321, 342, 445 — 7 separate formatter allocations)
  - `InsightFlow/Views/Reports/RetentionView.swift` (lines 277-291)
- Impact: `DateFormatter` is expensive to allocate. Creating one per data point in a chart with 365 points wastes memory and CPU.
- Fix approach: Create `static let` formatters as properties on a shared `DateFormatting` utility or as file-level constants.

**ViewModels Hardwired to Singletons (No Dependency Injection):**
- Issue: Every ViewModel directly references `UmamiAPI.shared`, `PlausibleAPI.shared`, `AnalyticsCacheService.shared` — making unit testing require global state manipulation
- Files:
  - `InsightFlow/Views/Reports/ReportsViewModel.swift` (line 17: `private let api = UmamiAPI.shared`)
  - `InsightFlow/Views/Events/EventsViewModel.swift` (line 17: `private let api = UmamiAPI.shared`)
  - `InsightFlow/Views/Sessions/SessionsView.swift` (lines 491, 566, 599 — three ViewModels all with `private let api = UmamiAPI.shared`)
  - `InsightFlow/Views/Detail/WebsiteDetailViewModel.swift`
  - `InsightFlow/Views/Dashboard/DashboardView.swift` (DashboardViewModel, lines 805-807)
- Impact: Cannot mock API in tests without swizzling. Tests depend on Keychain state and network.
- Fix approach: Accept `AnalyticsProvider` protocol via init parameter with default value: `init(api: AnalyticsProvider = UmamiAPI.shared)`.

**Actor/MainActor Isolation Boundary Issues:**
- Issue: UmamiAPI and PlausibleAPI use `actor` with `nonisolated` properties that read from Keychain (non-thread-safe), while AccountManager is `@MainActor`
- Files:
  - `InsightFlow/Services/UmamiAPI.swift` (nonisolated `serverURL`, `isAuthenticated` read Keychain)
  - `InsightFlow/Services/PlausibleAPI.swift` (nonisolated `serverURL`, `apiKey`, `isAuthenticated`)
  - `InsightFlow/Services/AnalyticsCacheService.swift` (line 5: `@unchecked Sendable` on class with mutable file I/O)
- Impact: Potential data races if Keychain is updated while nonisolated property is read. `@unchecked Sendable` suppresses compiler warnings but does not fix thread safety.
- Fix approach: Use actor-isolated stored properties instead of computed nonisolated properties. Replace `@unchecked Sendable` with proper actor isolation or `OSAllocatedUnfairLock`.

## Known Bugs

**CompareChartSection Not Reactive (CONFIRMED):**
- Symptoms: Chart in CompareView may not update when ViewModel publishes new data
- Files: `InsightFlow/Views/Detail/CompareChartSection.swift` (line 5)
- Trigger: Navigate to Compare view, change comparison parameters
- Workaround: Navigate back and re-enter the view
- Fix: Change `let viewModel` to `@ObservedObject var viewModel`

**Account Switcher Widget Sync Race Condition:**
- Symptoms: Widget sometimes shows old account's data after switching accounts
- Files: `InsightFlow/Services/AccountManager.swift` (line 327)
- Trigger: Rapid account switching or adding account immediately after login
- Cause: `syncAccountsToWidget()` and `WidgetCenter.shared.reloadAllTimelines()` fire without waiting for credential application to complete
- Workaround: Force close and reopen app or manually refresh widget

**Plausible "Realtime" Metric Gaps:**
- Symptoms: Realtime top pages/countries show only last 24 hours instead of true realtime data
- Files: `InsightFlow/Services/PlausibleAPI.swift` (lines 344-381)
- Cause: Plausible API does not support dimensions in realtime endpoint; implementation uses "day" breakdown as workaround
- Workaround: None; by design limitation of Plausible API

**Cache Websites Loaded Without TTL Check:**
- Symptoms: Stale website list shown from cache even when data is hours old
- Files: `InsightFlow/Views/Dashboard/DashboardView.swift` (lines 981-982)
- Trigger: App goes offline, then cache is read without checking `isExpired`
- Note: Sparkline cache correctly checks `!cachedSparkline.isExpired` (line 993), but the website list load on line 981-982 does NOT check `cachedWebsites.isExpired`. This is inconsistent.
- Fix: Add `!cachedWebsites.isExpired` guard, or at minimum flag expired cache visually

## Security Considerations

**Keychain Data Not Isolated by Account:**
- Risk: Credentials stored with account UUID scoped keys, but fallback lookups use legacy non-scoped keys
- Files: `InsightFlow/Services/AccountManager.swift` (lines 220-257), `InsightFlow/Services/KeychainService.swift`
- Current mitigation: Credentials are stripped from UserDefaults before saving. Migration validates stored data.
- Recommendations:
  - Audit legacy key lookups — ensure they only occur during migration
  - Add test that verifies credentials are completely isolated between accounts

**Force Unwrap in KeychainService:**
- Risk: `value.data(using: .utf8)!` on line 18 and 89 of `InsightFlow/Services/KeychainService.swift` will crash if non-UTF-8 string is passed
- Files: `InsightFlow/Services/KeychainService.swift` (lines 18, 89)
- Current mitigation: All callers pass known-good strings (tokens, URLs)
- Recommendations: Replace with `guard let data = value.data(using: .utf8) else { throw ... }` for safety

**Widget Credentials Stored in UserDefaults via AppGroup:**
- Risk: Encrypted JSON stored in UserDefaults but encryption key stored alongside data in the same container
- Files: `InsightFlow/Services/SharedCredentials.swift`, `InsightFlow/Services/AccountManager.swift` (lines 363-373)
- Recommendations: Consider using Keychain with AppGroup access control instead of file-based encryption

## Performance Bottlenecks

**LazyVStack Usage With Conditional Content (Risk Pattern):**
- Problem: LazyVStack used in several views that also contain conditional content and state-dependent rendering. This was the root cause of a recently-fixed bug where LazyVStack prevented conditional view updates.
- Files:
  - `InsightFlow/Views/Dashboard/DashboardView.swift` (line 39)
  - `InsightFlow/Views/Reports/ReportsHubView.swift` (line 36)
  - `InsightFlow/Views/Events/EventsView.swift` (line 41)
  - `InsightFlow/Views/Sessions/SessionsView.swift` (line 153)
  - `InsightFlow/Views/Admin/AdminView.swift` (lines 111, 134, 173, 213)
- Impact: LazyVStack defers view creation and may not trigger updates for off-screen items when state changes. If conditional content (if/else on ViewModel state) is inside LazyVStack, the view may show stale content.
- Improvement: For views with < 50 items, prefer `VStack` over `LazyVStack`. Only use `LazyVStack` for truly large, homogeneous lists (e.g., sessions list, event list).

**DashboardView Layout Recalculation on Every State Change:**
- Problem: Large VStack hierarchy recalculates on any state change (activeVisitors, sparklineData, stats dict updates)
- Files: `InsightFlow/Views/Dashboard/DashboardView.swift` (body property)
- Cause: No view memoization; body is fully recomputed even when only one website's stats changed
- Improvement: Move sparklineData and activeVisitors into individual WebsiteCard ViewModels. Use `EquatableView` wrapper.

**Account Switching Loads All Data Sequentially:**
- Problem: `loadAllAccountsData()` iterates accounts with `for account in accounts` (sequential), calling `await AccountManager.shared.setActiveAccount(account)` for each
- Files: `InsightFlow/Views/Dashboard/DashboardView.swift` (lines 856-914)
- Impact: N accounts = N sequential credential switches + N sequential website loads
- Improvement: Restructure to load data per-account in parallel without switching global active account state

**AnalyticsCacheService File I/O Not Async:**
- Problem: Cache save/load operations block the calling thread (synchronous file I/O)
- Files: `InsightFlow/Services/AnalyticsCacheService.swift` (lines 57-111)
- Impact: Potential MainActor blocking if multiple cache writes happen during data refresh
- Improvement: Dispatch cache I/O to background queue or use async file APIs

## Fragile Areas

**Task Cancellation Handling Inconsistency:**
- Files:
  - `InsightFlow/Views/Detail/WebsiteDetailViewModel.swift` — Properly cancels previous task (line 41: `loadingTask?.cancel()`) and checks `Task.isCancelled` before every state write
  - `InsightFlow/Views/Dashboard/DashboardView.swift` — NO task cancellation on `loadData()`. Rapid date range changes or account switches can cause multiple concurrent loads that overwrite each other
  - `InsightFlow/Views/Events/EventsViewModel.swift` — No task cancellation at all. Changing date range while loading creates parallel loads.
  - `InsightFlow/Views/Reports/ReportsViewModel.swift` — No task cancellation. No `Task.isCancelled` checks.
  - `InsightFlow/Views/Sessions/SessionsView.swift` — SessionsViewModel, SessionDetailViewModel, JourneyViewModel all lack task cancellation.
  - `InsightFlow/Views/Reports/RetentionView.swift` — RetentionViewModel has no cancellation.
  - `InsightFlow/Views/Reports/PagesView.swift` — PagesViewModel has no cancellation.
  - `InsightFlow/Views/Reports/InsightsView.swift` — ComparisonViewModel has no cancellation.
- Why fragile: Without cancellation, navigating away from a view while data loads wastes network/battery and can overwrite fresh data with stale results from a previous request that completes later.
- Safe modification: Follow the `WebsiteDetailViewModel` pattern: store a `loadingTask` reference, cancel it before starting new loads, and check `Task.isCancelled` before writing results.
- Priority: **High** — this was the root cause of a recently-fixed bug where task cancellation overwrote valid data with empty arrays.

**EventsViewModel Has No Cancellation-Aware Error Handling:**
- Files: `InsightFlow/Views/Events/EventsViewModel.swift` (lines 22-75)
- Why fragile: `loadEvents()` uses `withTaskGroup` but if the enclosing `.task {}` is cancelled (user navigates away), the TaskGroup child tasks throw `CancellationError`, which is caught and may set `isOffline = true` or `error = ...` incorrectly.
- Safe modification: Add `guard !Task.isCancelled else { return }` after the TaskGroup completes, before setting `isLoading = false`.

**Account Switch Modifies Global Singleton State:**
- Files: `InsightFlow/Services/AccountManager.swift` (line 166: `setActiveAccount`)
- Why fragile: `loadAllAccountsData()` in DashboardViewModel (line 866-900) temporarily switches the active account for EACH account to load data, then restores the original. If user interacts during this operation, the active account is wrong.
- Safe modification: Pass credentials directly to API calls instead of switching global active account state.

**PlausibleSitesManager State Flag Workaround:**
- Files: `InsightFlow/Services/PlausibleAPI.swift` (lines 972-976)
- Why fragile: `skipSaveOnSet` flag prevents didSet from saving; multiple concurrent calls can race
- Safe modification: Use explicit methods instead of flag-based didSet suppression.

## Scaling Limits

**Cache Directory Unbounded Growth:**
- Current capacity: No automatic cleanup on app launch
- Files: `InsightFlow/Services/AnalyticsCacheService.swift`
- Note: `clearExpiredCache()` and `clearStaleEntries()` methods exist but are never called automatically. The `evictOldestEntries()` method exists but is also never called.
- Scaling path: Call `clearStaleEntries(olderThan: 7)` and `evictOldestEntries(maxSize: 100_000_000)` on app launch in `InsightFlowApp.swift`.

**Concurrent Request Limit:**
- Current capacity: URLSession.shared default config (6 concurrent per host)
- Limit: DashboardView with 20+ websites creates 60+ concurrent requests (3 per website: stats, active visitors, sparkline)
- Scaling path: Implement request queue with max 3 concurrent requests per account.

## Dependencies at Risk

**No Network Retry Logic:**
- Risk: Single network glitch causes entire data load to fail
- Impact: User sees error screen instead of cached data
- Migration plan: Add `URLSession` wrapper with exponential backoff for transient errors.

**Hardcoded Timeout Intervals:**
- Risk: 30-second default timeout for all requests
- Files: `InsightFlow/Services/UmamiAPI.swift`, `InsightFlow/Services/PlausibleAPI.swift`
- Migration plan: Make timeout configurable per endpoint type.

## Missing Critical Features

**No Request Cancellation in Most ViewModels:**
- Problem: Only `WebsiteDetailViewModel` properly cancels previous loads. All other ViewModels allow concurrent loads to race.
- Blocks: Reliable data display when user rapidly changes date ranges or navigates between views
- Solution: Implement `loadingTask?.cancel()` pattern in ALL ViewModels that have async load methods.

**No Loading State for Account Switching:**
- Problem: Switching accounts shows brief flash of old account data
- Impact: User may think action did not complete
- Solution: Add `isLoading` state to AccountManager that prevents navigation while credentials are being applied.

## Test Coverage Gaps

**No Tests for Child View @ObservedObject Reactivity:**
- What's not tested: Whether child views with ViewModel parameters correctly re-render when ViewModel publishes changes
- Files: `InsightFlow/Views/Detail/CompareChartSection.swift` (KNOWN BUG — uses `let` instead of `@ObservedObject`)
- Risk: More views could silently stop updating without visual indication
- Priority: **High** — this class of bug is invisible in code review and only caught by user testing

**No Integration Tests for Multi-Account Switching:**
- What's not tested: Account switch flow with credential persistence, API reconfiguration, widget update
- Files: `InsightFlow/Services/AccountManager.swift`, related ViewModels
- Risk: Critical user flow could break unnoticed
- Priority: **High**

**No Error Path Testing for API Services:**
- What's not tested: 401 unauthorized, 500 server errors, network timeouts, malformed JSON responses
- Files: `InsightFlow/Services/UmamiAPI.swift`, `InsightFlow/Services/PlausibleAPI.swift`
- Risk: Error states propagate with incorrect error messages
- Priority: **High**

**No Task Cancellation Tests:**
- What's not tested: Whether ViewModels correctly handle task cancellation when user navigates away during data load
- Files: All ViewModels in `InsightFlow/Views/`
- Risk: Cancelled tasks may overwrite valid data, set incorrect error states, or leak resources
- Priority: **High** — this was the root cause of multiple recently-fixed bugs

**No Cache Expiration Tests:**
- What's not tested: Cache TTL enforcement, expired entry cleanup, cache load with mixed expired/valid data
- Files: `InsightFlow/Services/AnalyticsCacheService.swift`
- Risk: Cache may serve stale data indefinitely
- Priority: **Medium**

**88 print() Statements Across 23 Files:**
- What's the concern: While guarded by `#if DEBUG`, the sheer volume makes log output noisy and hard to filter
- Files: Throughout `InsightFlow/Services/` and `InsightFlow/Views/`
- Risk: Important errors get lost in noise; no structured logging for production diagnostics
- Priority: **Low** — functional but makes debugging harder

---

*Concerns audit: 2026-04-04*
