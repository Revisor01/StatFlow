# Architecture

**Analysis Date:** 2026-03-27

## Pattern Overview

**Overall:** MVVM (Model-View-ViewModel) with Service Layer and Provider Protocol Abstraction

**Key Characteristics:**
- Protocol-based analytics provider abstraction (`AnalyticsProvider`) unifies Umami and Plausible backends
- Singleton service managers (`AnalyticsManager.shared`, `AccountManager.shared`, `PlausibleSitesManager.shared`, etc.)
- `@MainActor` isolation for all ObservableObject classes
- Multi-account support with account switching at runtime
- App Group container for sharing data between main app and widget extension
- SwiftUI `@EnvironmentObject` for dependency injection of `AuthManager` and `NotificationManager`

## Layer Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    App Entry Point                       │
│  InsightFlowApp.swift → ContentView → MainTabView       │
│  (Auth gate, deep links, background tasks)              │
└──────────────┬──────────────────────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────────┐
│                     Views Layer                          │
│  Dashboard │ Detail │ Admin │ Settings │ Realtime │ etc. │
│  (SwiftUI Views + ViewModels where needed)              │
└──────────────┬──────────────────────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────────┐
│                   Services Layer                         │
│  AuthManager │ AccountManager │ AnalyticsManager         │
│  NotificationManager │ DashboardSettingsManager          │
│  SupportManager │ AnalyticsCacheService                  │
└──────────────┬──────────────────────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────────┐
│              Analytics Provider Protocol                  │
│  ┌──────────────────┐  ┌──────────────────────┐         │
│  │    UmamiAPI       │  │    PlausibleAPI       │        │
│  │  (actor, shared)  │  │  (@MainActor, shared) │        │
│  └──────────────────┘  └──────────────────────┘         │
└──────────────┬──────────────────────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────────┐
│                Infrastructure Layer                      │
│  KeychainService │ SharedCredentials │ UserDefaults       │
│  URLSession (networking) │ App Group file I/O            │
└─────────────────────────────────────────────────────────┘
```

## Layers

**App Layer:**
- Purpose: Application lifecycle, entry point, deep link handling, background task registration
- Location: `InsightFlow/App/`
- Contains: `InsightFlowApp.swift`, `ContentView.swift`, `MainTabView.swift`
- Depends on: AuthManager, NotificationManager, QuickActionManager
- Used by: iOS system (app launch)

**Views Layer:**
- Purpose: UI presentation and user interaction
- Location: `InsightFlow/Views/`
- Contains: SwiftUI views organized by feature (Dashboard, Detail, Admin, Settings, Auth, Realtime, Sessions, Reports, Onboarding)
- Depends on: Services layer, Models
- Used by: App layer (navigation)

**Services Layer:**
- Purpose: Business logic, state management, API communication, persistence
- Location: `InsightFlow/Services/`
- Contains: Manager classes (singletons), API clients, caching, credential storage
- Depends on: Models, Infrastructure (Keychain, URLSession)
- Used by: Views layer

**Models Layer:**
- Purpose: Data structures for API responses and domain objects
- Location: `InsightFlow/Models/`
- Contains: Codable structs for websites, stats, sessions, admin entities, date ranges
- Depends on: Foundation only
- Used by: Services and Views layers

**Widget Extension:**
- Purpose: Home screen widgets showing analytics data
- Location: `InsightFlowWidget/`
- Contains: Widget timeline provider, widget views, Live Activity
- Depends on: SharedCredentials (via App Group), URLSession
- Note: Shares code concepts but NOT source files with main app; duplicates some API logic

## Data Flow

**Primary Flow - Dashboard Load:**

1. `ContentView` checks `authManager.isAuthenticated` to show `LoginView` or `MainTabView`
2. `DashboardView` reads active account from `AccountManager.shared`
3. Uses `AnalyticsManager.shared.currentProvider` (which conforms to `AnalyticsProvider` protocol) to fetch websites
4. For each website, `WebsiteCard` fetches stats via the provider protocol
5. Provider (`UmamiAPI` or `PlausibleAPI`) makes HTTP requests to the analytics backend
6. Results are mapped from provider-specific models to unified `AnalyticsStats`/`AnalyticsWebsite` models
7. `AnalyticsCacheService` stores results in App Group container for offline access

**Account Switching Flow:**

1. User selects account in Settings
2. `AccountManager.shared.setActiveAccount()` is called
3. Credentials are written to Keychain via `KeychainService`
4. Provider API (`UmamiAPI` or `PlausibleAPI`) is reconfigured from Keychain
5. `AnalyticsManager.shared.setProvider()` updates the active provider
6. `NotificationCenter.default.post(name: .accountDidChange)` triggers view refresh
7. Widget credentials are synced via `SharedCredentials` and `widget_accounts.json`

**Authentication Flow (Umami):**

1. `LoginView` collects serverURL, username, password
2. `AuthManager.login()` calls `UmamiAPI.shared.login()` which POSTs to `{serverURL}/api/auth/login`
3. JWT token is returned and saved to Keychain (`KeychainService.save()`)
4. Token is also saved to `SharedCredentials` (encrypted AES-GCM) for widget access
5. `AnalyticsAccount` is created and stored in `AccountManager`
6. `authManager.isAuthenticated = true` triggers UI transition

**Authentication Flow (Plausible):**

1. `LoginView` collects serverURL and API key
2. `AuthManager.loginWithPlausible()` calls `PlausibleAPI.authenticate()` which validates the key by POSTing to `{serverURL}/api/v2/query`
3. API key is saved to Keychain
4. Sites are stored locally via `PlausibleSitesManager` (Plausible has no list-sites API in v2)
5. Account created in `AccountManager`

**State Management:**
- `@StateObject` / `@EnvironmentObject` for `AuthManager`, `NotificationManager` at app root
- Singleton `@Published` properties for `AccountManager`, `AnalyticsManager`, `DashboardSettingsManager`
- `UserDefaults` for settings (dashboard metrics, chart style, notification preferences, accounts list)
- `Keychain` for secrets (tokens, API keys, server URLs)
- `App Group file container` for widget-shared data (encrypted credentials, cache, multi-account JSON)

## Key Abstractions

**AnalyticsProvider Protocol:**
- Purpose: Unifies Umami and Plausible APIs behind a single interface
- Defined in: `InsightFlow/Services/AnalyticsProvider.swift`
- Implementations: `InsightFlow/Services/UmamiAPI.swift` (actor), `InsightFlow/Services/PlausibleAPI.swift` (@MainActor class)
- Pattern: Strategy pattern - the active provider is selected at runtime via `AnalyticsManager.currentProvider`
- Methods: `authenticate()`, `getAnalyticsWebsites()`, `getAnalyticsStats()`, `getPageviewsData()`, `getActiveVisitors()`, `getRealtimeData()`, `getPages()`, `getReferrers()`, `getCountries()`, `getDevices()`, `getBrowsers()`, `getOS()`

**AnalyticsAccount:**
- Purpose: Represents a saved analytics account (supports multiple accounts)
- Defined in: `InsightFlow/Services/AccountManager.swift`
- Contains: UUID, name, serverURL, providerType, credentials, optional Plausible sites
- Persisted via: `UserDefaults` (JSON-encoded array)

**DateRange:**
- Purpose: Encapsulates date range presets and custom ranges for API queries
- Defined in: `InsightFlow/Models/DateRange.swift`
- Converts to provider-specific formats (Umami: millisecond timestamps, Plausible: string shortcuts like "7d")

**WebsiteDetailViewModel:**
- Purpose: Only dedicated ViewModel in the codebase; loads all detail metrics in parallel
- Defined in: `InsightFlow/Views/Detail/WebsiteDetailViewModel.swift`
- Uses `withTaskGroup` to fetch 15 data types concurrently
- Checks `isPlausible` flag to route to correct API

## Entry Points

**App Entry (`@main`):**
- Location: `InsightFlow/App/InsightFlowApp.swift`
- Struct name: `PrivacyFlowApp` (bundle ID: `de.godsapp.PrivacyFlow`)
- Triggers: iOS app launch
- Responsibilities: Creates `AuthManager`, `NotificationManager`, `QuickActionManager`; registers background tasks; handles deep links (`privacyflow://website?id=xxx&provider=umami`)

**Widget Entry (`@main`):**
- Location: `InsightFlowWidget/InsightFlowWidgetBundle.swift`
- Struct name: `PrivacyFlowWidgetBundle`
- Contains: `PrivacyFlowWidget` (timeline widget) + `PrivacyFlowWidgetLiveActivity`

**Navigation Root:**
- Location: `InsightFlow/App/MainTabView.swift`
- 3 tabs: Dashboard (index 0), Admin (index 1), Settings (index 2)

## Error Handling

**Strategy:** Per-method try/catch with `@Published var error: String?` on ViewModels; errors displayed in views.

**Patterns:**
- API errors use typed enums: `APIError` (Umami, in `InsightFlow/Services/UmamiAPI.swift`) and `PlausibleError` (in `InsightFlow/Services/PlausibleAPI.swift`)
- Both conform to `LocalizedError` with German and localized error descriptions
- Network errors silently caught in detail views (print in DEBUG only), preventing UI crash on partial data load failure
- `WebsiteDetailViewModel.loadData()` uses `TaskGroup` - individual metric load failures don't block other metrics

## Cross-Cutting Concerns

**Logging:** `print()` statements throughout, many wrapped in `#if DEBUG`. No structured logging framework.

**Validation:** URL validation in `AuthManager` and `PlausibleAPI` (scheme normalization, trailing slash removal). Domain normalization in `PlausibleAPI.normalizeDomain()`.

**Authentication:** Keychain-based token/API-key storage via `InsightFlow/Services/KeychainService.swift`. Shared with widget via AES-GCM encrypted file in App Group container (`InsightFlow/Services/SharedCredentials.swift`).

**Caching:** File-based JSON cache in App Group container with configurable TTL (1h default, 15min for sparklines). Implemented in `InsightFlow/Services/AnalyticsCacheService.swift`.

**Localization:** German (primary) and English. String catalogs at `InsightFlow/Resources/{de,en}.lproj/Localizable.strings`. Uses `String(localized:)` API.

**Notifications:** Local push notifications for daily/weekly stats summaries. Background refresh via `BGAppRefreshTask`. Managed by `InsightFlow/Services/NotificationManager.swift`.

**In-App Purchases:** Tip jar support via StoreKit 2 in `InsightFlow/Services/SupportManager.swift`. Three tiers (small/medium/large).

---

*Architecture analysis: 2026-03-27*
