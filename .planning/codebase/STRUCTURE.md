# Codebase Structure

**Analysis Date:** 2026-03-28

## Directory Layout

```
InsightFlow/
├── App/                          # App initialization, routing, deep linking
│   ├── InsightFlowApp.swift      # @main app entry, background tasks, deep links
│   ├── ContentView.swift         # Root router (LoginView vs MainTabView)
│   └── MainTabView.swift         # Tab navigation (Dashboard/Admin/Settings)
├── Services/                     # Business logic, API clients, managers
│   ├── AccountManager.swift      # Multi-account management, credential handling
│   ├── AnalyticsProvider.swift   # Provider protocol, unified models
│   ├── UmamiAPI.swift            # Umami API client (actor)
│   ├── PlausibleAPI.swift        # Plausible API client (actor)
│   ├── AnalyticsCacheService.swift # Data caching layer
│   ├── NotificationManager.swift # Push notification scheduling
│   ├── DashboardSettingsManager.swift # Dashboard UI persistence
│   ├── KeychainService.swift     # Credential storage abstraction
│   ├── SharedCredentials.swift   # Widget credential bridge
│   └── SupportManager.swift      # Support/feedback logic
├── Models/                       # Codable data structures
│   ├── Website.swift             # Website domain model
│   ├── Stats.swift               # Statistics and time-series data
│   ├── Events.swift              # Event tracking models
│   ├── Sessions.swift            # Session data models
│   ├── Admin.swift               # Admin/user management models
│   ├── Share.swift               # Share link models
│   ├── Reports.swift             # Report/retention models
│   ├── DateRange.swift           # Date range filtering abstraction
│   └── PlausibleGoal.swift       # Plausible-specific goal models
├── Views/                        # SwiftUI view hierarchy
│   ├── Auth/                     # Authentication flow
│   │   ├── LoginView.swift       # Multi-provider login UI
│   │   └── LoginViewModel.swift  # Login state & validation
│   ├── Dashboard/                # Website list & cards
│   │   ├── DashboardView.swift   # Grid with account/date filtering
│   │   ├── WebsiteCard.swift     # Individual website card component
│   │   ├── AddUmamiSiteView.swift # Umami site addition
│   │   └── AddPlausibleSiteView.swift # Plausible site addition
│   ├── Detail/                   # Website analytics details
│   │   ├── WebsiteDetailView.swift # Main detail scroll view
│   │   ├── WebsiteDetailViewModel.swift # Data loading & management
│   │   ├── WebsiteDetailChartSection.swift # Chart rendering
│   │   ├── WebsiteDetailMetricsSections.swift # Metric cards
│   │   ├── WebsiteDetailSupportingViews.swift # Helper views
│   │   ├── CompareView.swift     # Date range comparison view
│   │   ├── CompareViewModel.swift # Comparison logic
│   │   └── CompareHeroCard.swift # Comparison hero card
│   ├── Realtime/                 # Live visitor data
│   │   └── RealtimeView.swift    # Active visitors & live events
│   ├── Events/                   # Event details
│   │   ├── EventsView.swift      # Event list view
│   │   └── EventsViewModel.swift # Event data loading
│   ├── Reports/                  # Analytics reports & insights
│   │   ├── ReportsHubView.swift  # Report section overview
│   │   ├── ReportsViewModel.swift # Report data
│   │   ├── InsightsView.swift    # Insights section
│   │   ├── PagesView.swift       # Top pages report
│   │   ├── RetentionView.swift   # Retention/cohort report
│   │   └── ReportDetailViews.swift # Report detail cards
│   ├── Sessions/                 # Session browsing (if implemented)
│   │   └── SessionsView.swift    # Session list/details
│   ├── Admin/                    # Admin panel
│   │   ├── AdminView.swift       # Admin section overview
│   │   ├── AdminCards.swift      # Admin card components
│   │   └── AdminSheets.swift     # Admin modal sheets
│   ├── Settings/                 # App settings
│   │   ├── SettingsView.swift    # Main settings UI
│   │   ├── DashboardSettingsView.swift # Dashboard customization
│   │   ├── AnalyticsGlossaryView.swift # Term explanations
│   │   ├── SetupGuideView.swift  # Onboarding/setup
│   │   ├── SupportView.swift     # Support/feedback
│   │   └── SupportReminderView.swift # Periodic support prompt
│   ├── Onboarding/               # Initial setup
│   │   └── OnboardingView.swift  # First-launch flow
│   └── Components/               # Reusable UI components (empty dir)
├── Extensions/                   # SwiftUI & Foundation extensions
│   └── View+Extensions.swift     # glassBackground(), shimmer() modifiers
├── Resources/                    # Assets & localization
│   ├── Assets.xcassets/          # App icons, color assets
│   ├── en.lproj/                 # English strings (Localizable.strings)
│   └── de.lproj/                 # German strings (Localizable.strings)
└── Info.plist / entitlements     # App configuration
```

## Directory Purposes

**`InsightFlow/App/`:**
- Purpose: App lifecycle, window setup, routing
- Contains: @main struct, root ContentView, MainTabView
- Key files: `InsightFlowApp.swift` (entry point), `ContentView.swift` (auth router)

**`InsightFlow/Services/`:**
- Purpose: Singleton managers and API clients
- Contains: AccountManager (multi-account), AnalyticsManager (provider selection), API clients (Umami/Plausible), NotificationManager, KeychainService
- Key files: `AccountManager.swift` (auth state), `AnalyticsProvider.swift` (protocol), `UmamiAPI.swift` & `PlausibleAPI.swift` (implementations)

**`InsightFlow/Models/`:**
- Purpose: Data structures and domain models
- Contains: Codable structs mirroring API schemas, value types for computed properties
- Key files: `Website.swift` (website domain model), `Stats.swift` (statistics aggregates), `DateRange.swift` (filtering enum)

**`InsightFlow/Views/`:**
- Purpose: Feature-organized SwiftUI view hierarchy
- Contains: View structs (UI layout) paired with ViewModels (state/logic)
- Organization: Subdirectories by feature area (Auth, Dashboard, Detail, etc.)

**`InsightFlow/Views/Detail/`:**
- Purpose: Deep analytics exploration for individual websites
- Contains: Primary view (WebsiteDetailView), view model, chart sections, metric sections
- Key files: `WebsiteDetailView.swift` (layout), `WebsiteDetailViewModel.swift` (concurrent data loading), `WebsiteDetailChartSection.swift` (Charts rendering)

**`InsightFlow/Views/Reports/`:**
- Purpose: Advanced analytics reports (retention, insights, pages breakdown)
- Contains: Report type views, shared detail components
- Key files: `ReportsHubView.swift` (hub), `RetentionView.swift` (cohort analysis), `ReportsViewModel.swift` (data)

**`InsightFlow/Extensions/`:**
- Purpose: Reusable modifiers and helper methods
- Contains: View+Extensions for UI chrome (glassBackground, shimmer)

**`InsightFlow/Resources/`:**
- Purpose: Localizable strings, app icons, color assets
- Contains: `en.lproj/Localizable.strings`, `de.lproj/Localizable.strings`, Assets.xcassets
- Key: Uses String(localized: "key") for i18n

## Key File Locations

**Entry Points:**
- `InsightFlow/App/InsightFlowApp.swift`: Application @main; registers background tasks, initializes AppDelegate
- `InsightFlow/App/ContentView.swift`: Root view controller; routes based on AccountManager.activeAccount
- `InsightFlow/App/MainTabView.swift`: Tab-based navigation for authenticated users

**Configuration:**
- `InsightFlow/Services/AccountManager.swift`: Credentials, account persistence (UserDefaults + Keychain)
- `InsightFlow/Services/DashboardSettingsManager.swift`: Dashboard ordering, date range visibility
- `InsightFlow/Resources/Info.plist`: URL schemes (statflow://), app metadata

**Core Logic:**
- `InsightFlow/Services/AnalyticsProvider.swift`: Protocol defining unified API, provider types
- `InsightFlow/Services/UmamiAPI.swift`: Umami API client (actor-based, thread-safe)
- `InsightFlow/Services/PlausibleAPI.swift`: Plausible API client (actor-based, thread-safe)
- `InsightFlow/Services/NotificationManager.swift`: Background notification scheduling

**Testing:**
- No dedicated test directory; test targets would live in separate Xcode build phases
- View previews use #Preview in-file

## Naming Conventions

**Files:**
- Views: `FeatureNameView.swift` (e.g., DashboardView, WebsiteDetailView)
- ViewModels: `FeatureNameViewModel.swift` (e.g., LoginViewModel, WebsiteDetailViewModel)
- Services: `ServiceNameManager.swift` or `ServiceNameAPI.swift` (e.g., AccountManager, UmamiAPI)
- Models: Domain name only (e.g., Website.swift, Stats.swift)
- Extensions: `BaseType+Purpose.swift` (e.g., View+Extensions.swift)

**Types (Classes/Structs):**
- Views: PascalCase + "View" suffix (DashboardView, WebsiteCard)
- ViewModels: PascalCase + "ViewModel" suffix (@MainActor class)
- Services: PascalCase + "Manager" or "API" suffix (@MainActor class, actor)
- Models: PascalCase struct (Website, WebsiteStats)
- Enums: PascalCase (DateRange, AnalyticsProviderType, ChartMetric)

**Functions/Methods:**
- camelCase, verb-first: loadData(), refreshWebsites(), updateAccountSites()
- Initializers: init(explicit param names, no abbreviations)

**Properties:**
- camelCase: @Published var websites, let serverURL
- Private: _prefixed for underscore-exposed actor properties (e.g., _baseURL, _token in UmamiAPI)
- Boolean: isPrefixed or hasPrefixed (isLoading, hasMultipleAccounts)

**Constants:**
- UPPER_SNAKE_CASE for config constants (not used extensively; most stored in UserDefaults/Keychain)
- String keys: lowercase with dot notation for Keychain (e.g., "analytics_accounts")

## Where to Add New Code

**New Feature View:**
- Primary code: `InsightFlow/Views/{FeatureName}/{FeatureName}View.swift`
- ViewModel: `InsightFlow/Views/{FeatureName}/{FeatureName}ViewModel.swift`
- Models: Add structs to `InsightFlow/Models/` if new API response types needed

**New Feature Service:**
- Implementation: `InsightFlow/Services/{ServiceName}Manager.swift` or `{ServiceName}API.swift`
- If multi-provider: implement AnalyticsProvider protocol in both UmamiAPI and PlausibleAPI

**New Utility/Extension:**
- Shared helpers: `InsightFlow/Extensions/Type+Purpose.swift`
- Swift extensions (string formatters, date helpers): `View+Extensions.swift` or create new `String+Extensions.swift`

**Localized Strings:**
- Add keys to `InsightFlow/Resources/en.lproj/Localizable.strings` and German equivalent
- Usage: `String(localized: "key")`

**New Provider Integration:**
- Create new `InsightFlow/Services/NewProviderAPI.swift` conforming to AnalyticsProvider
- Update AccountManager to handle new AnalyticsProviderType case
- Update LoginView with provider-specific auth flow

## Special Directories

**`InsightFlow/Resources/`:**
- Purpose: Static assets and localization
- Generated: No (manually maintained)
- Committed: Yes (part of source control)

**`InsightFlow/Views/Components/`:**
- Purpose: Reserved for reusable component library (currently empty)
- Generated: No
- Committed: Yes

**Asset Catalog (`Assets.xcassets`):**
- Purpose: App icons, color sets, images
- Generated: Partially (Xcode generates derived data)
- Committed: Yes (source files, not derived)

---

*Structure analysis: 2026-03-28*
