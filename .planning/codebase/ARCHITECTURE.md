# Architecture

**Analysis Date:** 2026-03-28

## Pattern Overview

**Overall:** Multi-provider analytics dashboard using MVVM with dependency injection and layer separation.

**Key Characteristics:**
- Unified provider abstraction supporting Umami and Plausible analytics
- Account-based multi-provider switching with keychain credential isolation
- Observable-based reactive UI state management (ObservableObject/Published)
- Actor-based API clients for thread-safety and concurrency isolation
- Deep linking and notification-driven navigation

## Layers

**Presentation Layer:**
- Purpose: SwiftUI views and view models handling user interaction
- Location: `InsightFlow/Views/`
- Contains: View hierarchies organized by feature (Dashboard, Detail, Admin, Settings, etc.), ViewModels with @Published properties
- Depends on: Models, Services, Extensions
- Used by: SwiftUI runtime

**Service Layer:**
- Purpose: Core business logic, API communication, state management, and credential handling
- Location: `InsightFlow/Services/`
- Contains: API clients (UmamiAPI, PlausibleAPI), managers (AccountManager, AnalyticsManager, NotificationManager, DashboardSettingsManager)
- Depends on: Models, Keychain framework
- Used by: ViewModels and Views via dependency injection

**Model Layer:**
- Purpose: Data structures representing API responses and domain models
- Location: `InsightFlow/Models/`
- Contains: Codable structs for API responses (Website, Stats, Events, Sessions, etc.) and domain models (DateRange, Reports, Share)
- Depends on: Foundation
- Used by: Services and ViewModels

**Infrastructure Layer:**
- Purpose: Security, encryption, and system integration
- Location: `InsightFlow/Services/` (KeychainService) and App delegate in `InsightFlow/App/`
- Contains: Keychain credential management, notification handling, background task scheduling, deep linking
- Depends on: Security framework, UserNotifications, BackgroundTasks
- Used by: AccountManager, AppDelegate

## Data Flow

**Authentication & Account Management:**

1. User enters credentials in LoginView → LoginViewModel.login()
2. LoginViewModel calls UmamiAPI.shared.authenticate() or PlausibleAPI.shared.authenticate()
3. API client validates credentials and stores token/apiKey in Keychain
4. LoginViewModel creates AnalyticsAccount and calls AccountManager.shared.addAccount()
5. AccountManager saves account metadata to UserDefaults (credentials stripped)
6. AccountManager calls applyAccountCredentials() to configure API services
7. AccountManager updates widget via SharedCredentials
8. AnalyticsManager.setProvider() activates the appropriate API client

**Dashboard Data Loading:**

1. DashboardView loads websites from active account
2. DashboardViewModel queries currentProvider.getAnalyticsWebsites()
3. UmamiAPI/PlausibleAPI fetch from respective backends
4. Websites displayed as WebsiteCard with stats and sparkline data
5. Stats fetched lazily per website: activeVisitors (realtime), stats (comparison), sparklines

**Detail View Data Flow:**

1. User taps WebsiteCard → navigates to WebsiteDetailView
2. WebsiteDetailView instantiates WebsiteDetailViewModel(websiteId, domain)
3. ViewModel uses withTaskGroup() to load data concurrently:
   - loadStats() → provider.getAnalyticsStats()
   - loadPageviews() → provider.getPageviewsData() + provider.getVisitorsData()
   - loadMetrics() → provider.getPages/Referrers/Countries/etc.
   - fillMissingTimeSlots() fills chart gaps based on DateRange
4. Published @Published properties trigger view redraws
5. Chart selection (date range, metric type) reloads data via onChange

**State Management:**

- **AppState:** AccountManager.activeAccount controls root routing (LoginView vs MainTabView)
- **Notification State:** NotificationManager (@Published notificationSettings, notificationTime) persists to UserDefaults
- **Dashboard Settings:** DashboardSettingsManager (@Published showDateRangePicker, cardOrder) persists ordering
- **Deep Links:** QuickActionManager stores pendingDeepLink, selectedWebsiteId; processed after account switch completes

## Key Abstractions

**AnalyticsProvider Protocol:**
- Purpose: Unified interface abstracting Umami and Plausible differences
- Examples: `UmamiAPI`, `PlausibleAPI` (both actor-based)
- Pattern: Each provider implements getAnalyticsWebsites(), getAnalyticsStats(), getPages(), etc., returning unified AnalyticsWebsite, AnalyticsStats, AnalyticsMetricItem types

**Account/Credential Separation:**
- Purpose: Support multiple accounts with isolated credentials
- Examples: `AnalyticsAccount` (metadata + empty credentials), `AccountCredentials` (token/apiKey scoped by account UUID)
- Pattern: Credentials stored in Keychain per account ID; UserDefaults stores account metadata only; loadAccounts() hydrates credentials on app start

**DateRange:**
- Purpose: Abstract date filtering across providers
- Location: `InsightFlow/Models/DateRange.swift`
- Pattern: Enum with associated values (today, yesterday, last7Days, custom(start, end)); converted to provider-specific query params

**AnalyticsChartPoint / AnalyticsStats / AnalyticsMetricItem:**
- Purpose: Unified response models allowing ViewModels to work with either provider
- Pattern: ViewModels receive unified types; conversion happens in API client (UmamiAPI/PlausibleAPI map provider responses)

## Entry Points

**App Launch:**
- Location: `InsightFlow/App/InsightFlowApp.swift` (PrivacyFlowApp @main struct)
- Triggers: SwiftUI app initialization
- Responsibilities: Registers background tasks, initializes AppDelegate for notification handling, environment setup for NotificationManager and QuickActionManager

**Root Navigation:**
- Location: `InsightFlow/App/ContentView.swift`
- Triggers: Observes AccountManager.activeAccount
- Responsibilities: Routes to LoginView (no account) or MainTabView (authenticated)

**Main Dashboard:**
- Location: `InsightFlow/App/MainTabView.swift` (TabView with Dashboard/Admin/Settings)
- Triggers: User authenticated
- Responsibilities: Tab selection state, integration point for three main sections

**Deep Linking:**
- Location: `InsightFlow/App/InsightFlowApp.swift` (handleDeepLink method)
- Triggers: `statflow://website?id=xxx&provider=umami` URL scheme
- Responsibilities: Account switching (if provider differs), website selection via QuickActionManager

## Error Handling

**Strategy:** Provider-specific error enums with fallback to localized descriptions

**Patterns:**
- LoginViewModel catches `APIError` (Umami) and `PlausibleError` (Plausible), displays errorMessage
- Detail ViewModels log errors to console in DEBUG builds; guard nil gracefully in production
- Account switching handles missing accounts/credentials by clearing active state (clearActiveAccount)
- Network timeouts default to offline state (isOffline flag in Dashboard)

## Cross-Cutting Concerns

**Logging:** Console output in DEBUG builds only (`#if DEBUG print()`)

**Validation:**
- LoginView validates server URLs via UmamiAPI/PlausibleAPI.authenticate()
- DateRange bounds validated at query time
- Credential emptiness checked via AccountCredentials.isEmpty

**Authentication:**
- Stored in Keychain per account (KSecAttrAccessibleAfterFirstUnlock)
- Migrated from UserDefaults to Keychain on first app launch (migrateCredentialsToKeychain)
- Cleared on logout via clearActiveAccount() → KeychainService.deleteAll()

**Multi-Provider Support:**
- AnalyticsManager.setProvider() switches active provider
- ViewModels check AnalyticsManager.providerType to conditionally show Plausible-specific features
- Account switching via AccountManager.setActiveAccount() reconfigures API clients

**Notifications:**
- Background task scheduled via BGTaskScheduler (15-minute minimum interval)
- NotificationManager loads websites from current account, fetches stats, sends UNUserNotifications
- Time configuration persisted to UserDefaults, reconfigured on app launch

---

*Architecture analysis: 2026-03-28*
