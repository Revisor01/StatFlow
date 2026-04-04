# Architecture

**Last updated:** 2026-04-04

## Pattern Overview

**Overall:** MVVM with Protocol-Oriented Provider Abstraction and Actor-Based API Clients

**Key Characteristics:**
- Dual analytics provider support (Umami + Plausible) via `AnalyticsProvider` protocol
- `@MainActor` ViewModels with `@Published` properties driving SwiftUI views
- Singleton service layer (`*.shared`) for API clients, account management, and settings
- Swift `actor` isolation for API clients (`UmamiAPI`, `PlausibleAPI`) ensuring thread-safe network access
- Multi-account support with Keychain-based credential storage (per-account-ID scoped)
- App Group shared container for widget data exchange (encrypted with AES-GCM)
- `Task.isCancelled` guards in all ViewModel async methods to prevent stale updates
- `VStack` used in child detail views, `LazyVStack` used in Dashboard scrollable list

## Layers

**Presentation (Views):**
- Purpose: SwiftUI views rendering analytics data
- Location: `InsightFlow/Views/`
- Contains: View structs organized by feature, view modifiers, UI components
- Depends on: ViewModels (via `@StateObject` / `@ObservedObject`), Models
- Used by: App entry point (`ContentView`, `MainTabView`)

**ViewModel Layer:**
- Purpose: Fetch data from providers, manage loading/error/offline state, expose `@Published` properties
- Location: Co-located with views in feature directories
- Contains: `@MainActor` ObservableObject classes
- Depends on: `AnalyticsManager.shared.currentProvider`, API singletons directly for provider-specific features
- Used by: Views via `@StateObject` (owning parent) or `@ObservedObject` (shared singletons)
- Key pattern: Parent view owns ViewModel via `@StateObject`, child views receive it as `@ObservedObject`
- **Important:** `DashboardViewModel` is embedded inside `InsightFlow/Views/Dashboard/DashboardView.swift` (line 791+), not in a separate file

**Service Layer:**
- Purpose: API communication, authentication, caching, credential management
- Location: `InsightFlow/Services/`
- Contains: Protocol definitions, API actors, manager singletons
- Depends on: Foundation, Security (Keychain), CryptoKit, WidgetKit
- Used by: ViewModels, App lifecycle

**Model Layer:**
- Purpose: Data structures for API responses, domain models, enums
- Location: `InsightFlow/Models/`
- Contains: Codable structs, enums, value types (all `Sendable`)
- Depends on: Foundation only
- Used by: Services, ViewModels, Views

**Widget Extension:**
- Purpose: iOS home screen widgets showing website stats
- Location: `InsightFlowWidget/`
- Contains: Own networking (`Networking/`), models (`Models/`), cache (`Cache/`), views (`Views/`), intents (`Intents/`), storage (`Storage/`)
- Depends on: App Group shared container for encrypted credentials
- Used by: iOS WidgetKit (small + medium sizes)
- Fully independent from main app -- does not import main target code

## Provider Abstraction (Core Pattern)

The `AnalyticsProvider` protocol (`InsightFlow/Services/AnalyticsProvider.swift`, line 130) defines the unified interface:

```swift
protocol AnalyticsProvider: Sendable {
    nonisolated var providerType: AnalyticsProviderType { get }
    nonisolated var serverURL: String { get }
    nonisolated var isAuthenticated: Bool { get }

    func authenticate(serverURL: String, credentials: AnalyticsCredentials) async throws
    func getAnalyticsWebsites() async throws -> [AnalyticsWebsite]
    func getAnalyticsStats(websiteId: String, dateRange: DateRange) async throws -> AnalyticsStats
    func getPageviewsData(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsChartPoint]
    func getVisitorsData(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsChartPoint]
    func getActiveVisitors(websiteId: String) async throws -> Int
    func getRealtimeData(websiteId: String) async throws -> AnalyticsRealtimeData
    func getPages(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem]
    func getReferrers(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem]
    func getCountries(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem]
    func getDevices(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem]
    func getBrowsers(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem]
    func getOS(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem]
    // ... plus getRegions, getCities, getPageTitles, getLanguages, getScreens, getEvents,
    //     getRealtimeTopPages, getRealtimeCountries, getRealtimePageviews
}
```

**Default implementations** (return empty arrays) exist for: `getPageTitles`, `getLanguages`, `getScreens`, `getEvents` -- line 170.

**Implementations:**
- `UmamiAPI` (`InsightFlow/Services/UmamiAPI.swift`) -- Swift `actor`, JWT token auth, REST endpoints at `/api/...`
- `PlausibleAPI` (`InsightFlow/Services/PlausibleAPI.swift`) -- Swift `actor`, Bearer API key, Plausible v2 Query API (`POST /api/v2/query`)

**Provider Selection:**
- `AnalyticsManager` (`InsightFlow/Services/AnalyticsProvider.swift`, line 192) -- `@MainActor` singleton holding `currentProvider: (any AnalyticsProvider)?`
- `AccountManager` (`InsightFlow/Services/AccountManager.swift`) -- manages multi-account storage, calls `AnalyticsManager.setProvider()` on account switch

**Provider-specific features** (not in protocol, accessed via cast):
- **Plausible only:** entry/exit pages, goal conversions (`GoalConversion`), query filters (`PlausibleQueryFilter`), `PlausibleSitesManager`
- **Umami only:** admin API (teams, users, website CRUD), event detail/stats, session browsing, reports (funnel, UTM, goals, attribution, retention, journey)
- ViewModels cast to concrete type: `guard let plausible = provider as? PlausibleAPI else { return }`

## Data Flow

**Authentication Flow:**

1. `LoginView` shows provider picker (Umami/Plausible) and credentials form
2. `LoginViewModel.login()` or `loginWithPlausible()` calls API actor's `authenticate()`
3. API actor validates credentials, saves token/apiKey to Keychain
4. `LoginViewModel` creates `AnalyticsAccount` and calls `AccountManager.shared.addAccount()`
5. `AccountManager` saves credentials to Keychain (account-scoped), metadata to UserDefaults (credentials stripped)
6. `AccountManager.setActiveAccount()` calls `applyAccountCredentials()`:
   - Writes global Keychain entries for active provider
   - Reconfigures API actor: `UmamiAPI.shared.reconfigureFromKeychain()` or `PlausibleAPI.shared.reconfigureFromKeychain()`
   - Sets `AnalyticsManager.shared.setProvider()`
   - Posts `NotificationCenter(.accountDidChange)`
   - Syncs encrypted widget credentials via `SharedCredentials`
   - Calls `WidgetCenter.shared.reloadAllTimelines()`

**Dashboard Load Flow:**

1. `ContentView` checks `AccountManager.shared.activeAccount` -- shows `LoginView` or `MainTabView`
2. `DashboardView` creates `@StateObject DashboardViewModel` (embedded in same file, line 791)
3. ViewModel calls `AnalyticsManager.shared.currentProvider.getAnalyticsWebsites()`
4. For each website, parallel tasks fetch stats, active visitors, sparkline data
5. Results stored in `@Published` dictionaries keyed by website ID: `stats[websiteId]`, `activeVisitors[websiteId]`, `sparklineData[websiteId]`
6. `WebsiteCard` views bind to these dictionaries
7. `LazyVStack` used for the website list in Dashboard

**Website Detail Load Flow:**

1. User taps `WebsiteCard` -> navigation pushes `WebsiteDetailView`
2. `WebsiteDetailView` creates `@StateObject WebsiteDetailViewModel(websiteId, domain)`
3. ViewModel's `loadData(dateRange:)` cancels previous `loadingTask`, then uses `withTaskGroup` to fire 18 parallel API calls
4. Each sub-task has `guard !Task.isCancelled else { return }` before updating `@Published` properties
5. `fillMissingTimeSlots()` fills chart gaps based on DateRange unit (hour/day)
6. `VStack` (not LazyVStack) used in detail views for stable layout

**State Management:**
- `@StateObject` for ViewModel ownership in parent views (DashboardView, WebsiteDetailView, EventsView)
- `@ObservedObject` for shared singletons in views (`AccountManager.shared`, `DashboardSettingsManager.shared`, `QuickActionManager.shared`)
- `@EnvironmentObject` for cross-cutting concerns injected from App level (`NotificationManager`, `QuickActionManager`)
- `@AppStorage` for simple UserDefaults-backed settings (`colorScheme`, `hasSeenOnboarding`)
- `NotificationCenter` for cross-layer events (`.accountDidChange`, `.allAccountsRemoved`)

## Key Abstractions

**AnalyticsWebsite:**
- Purpose: Unified website model across providers (id, name, domain, shareId, provider type)
- Defined in: `InsightFlow/Services/AnalyticsProvider.swift` (line 61)
- Conversion: `UmamiAPI` maps `Website` -> `AnalyticsWebsite`, `PlausibleAPI` maps site domains

**AnalyticsStats / WebsiteStats:**
- Purpose: Normalized stats with value + change delta for period comparison
- Defined in: `InsightFlow/Services/AnalyticsProvider.swift` (line 76), `InsightFlow/Models/Stats.swift`
- Pattern: `AnalyticsStats` (provider-agnostic) has `toWebsiteStats()` conversion

**DateRange:**
- Purpose: Date range presets + custom ranges with computed `start`/`end`/`unit` properties
- Defined in: `InsightFlow/Models/DateRange.swift`
- Presets: today, yesterday, thisWeek, last7Days, last30Days, thisMonth, lastMonth, thisYear, lastYear, custom
- Unit logic: <=1 day = "hour", <=90 days = "day", >90 days = "month"

**CachedData<T> / AnalyticsCacheService:**
- Purpose: File-based JSON cache with TTL, stored in App Group container
- Defined in: `InsightFlow/Services/AnalyticsCacheService.swift`
- TTL: 1 hour default, 15 minutes for sparklines
- Cacheable variants: `CachedWebsite`, `CachedStats`, `CachedChartPoint`, `CachedMetricItem`
- Startup cleanup in `InsightFlowApp.init()`: stale entries >7 days, size cap 100MB

**AnalyticsAccount:**
- Purpose: Multi-account model with provider type, server URL, credentials reference
- Defined in: `InsightFlow/Services/AccountManager.swift` (line 13)
- Credentials stored in Keychain (account-ID-scoped via `KeychainService.saveCredential()`), metadata in UserDefaults (stripped of secrets)
- Hydration: `loadAccounts()` reads UserDefaults then `hydrateWithKeychainCredentials()` restores tokens

## Entry Points

**App Entry (`InsightFlowApp.swift`):**
- Location: `InsightFlow/App/InsightFlowApp.swift`
- Struct name: `PrivacyFlowApp` (historical name)
- Triggers: App launch
- Responsibilities: Register `BGAppRefreshTask`, cache cleanup (`Task.detached`), inject `NotificationManager`/`QuickActionManager` as environment objects, handle deep links, `AppDelegate` for notification delegation

**ContentView:**
- Location: `InsightFlow/App/ContentView.swift`
- Triggers: Root view
- Responsibilities: Auth gate (`activeAccount != nil` -> `MainTabView`, else `LoginView`), color scheme, onboarding full-screen cover

**MainTabView:**
- Location: `InsightFlow/App/MainTabView.swift`
- Triggers: Authenticated state
- Tabs: Dashboard (index 0), Admin (index 1), Settings (index 2)

**Widget Entry:**
- Location: `InsightFlowWidget/InsightFlowWidget.swift`
- Struct name: `PrivacyFlowWidget`
- Uses `AppIntentConfiguration` with `ConfigureWidgetIntent`
- Supported sizes: `.systemSmall`, `.systemMedium`

## Error Handling

**Strategy:** Per-call try/catch in ViewModels with `@Published` error string and offline boolean

**Patterns:**
- Network errors detected by URLError code matching (`.notConnectedToInternet`, `.networkConnectionLost`, `.timedOut`, `.cannotFindHost`, `.cannotConnectToHost`) -> set `isOffline = true`
- Other errors -> set `error: String?` for UI alert/display
- All async loads use `guard !Task.isCancelled else { return }` after every await before updating `@Published` state
- Previous loading tasks cancelled on new load: `loadingTask?.cancel()` (prevents battery drain from background requests)
- API errors: `APIError` enum (`InsightFlow/Services/UmamiAPI.swift`, line 866) and `PlausibleError` enum (`InsightFlow/Services/PlausibleAPI.swift`)
- `#if DEBUG print()` for non-critical sub-load failures

## Cross-Cutting Concerns

**Authentication:**
- Keychain-based (`InsightFlow/Services/KeychainService.swift`) with both global keys (`Key` enum) and account-scoped credentials (`CredentialType` + accountId)
- `kSecAttrAccessibleAfterFirstUnlock` for all items
- Widget auth via AES-GCM encrypted file in App Group (`InsightFlow/Services/SharedCredentials.swift`)
- Migration: legacy single-account to multi-account (`AccountManager.migrateCredentialsToKeychain()`, `migrateFromLegacyCredentials()`)

**Caching:**
- File-based JSON in App Group container (`InsightFlow/Services/AnalyticsCacheService.swift`)
- App Group ID: `group.de.godsapp.statflow`
- Generic cache: `save<T: Codable>()` / `load<T: Codable>()` with `CacheWrapper` (data + cachedAt + expiresAt)
- Cache keys: `websites_{accountId}`, `stats_{websiteId}_{dateRangeId}`, `sparkline_{websiteId}_{dateRangeId}`, `metrics_{websiteId}_{dateRangeId}_{metricType}`

**Localization:**
- German (primary) + English
- String catalogs: `InsightFlow/Resources/de.lproj/`, `InsightFlow/Resources/en.lproj/`
- Widget has own localization: `InsightFlowWidget/Resources/de.lproj/`, `InsightFlowWidget/Resources/en.lproj/`
- Pattern: `String(localized: "key")` and SwiftUI `Text("key")`

**Deep Links:**
- URL scheme: `statflow://website?id=xxx&provider=umami`
- Handled in `InsightFlowApp.handleDeepLink()` -> `QuickActionManager`
- Supports cross-provider deep linking (switches active account if needed)

**Background Refresh:**
- `BGAppRefreshTask` identifier: `de.godsapp.statflow.refresh`
- Triggers `NotificationManager.sendScheduledNotifications()` at configured time (default 9:00)
- Configurable via `notificationTime` in `NotificationManager`

**In-App Purchases:**
- `SupportManager` (`InsightFlow/Services/SupportManager.swift`) -- StoreKit 2 consumable tips
- Product IDs: `de.godsapp.statflow.support.{small,medium,large}`

**Dashboard Customization:**
- `DashboardSettingsManager` (`InsightFlow/Services/DashboardSettingsManager.swift`)
- Configurable: enabled metrics (visitors/pageviews/visits/bounceRate/duration), chart style (line/bar), graph visibility, date range picker visibility
- Persisted to UserDefaults

---

*Architecture analysis: 2026-04-04*
