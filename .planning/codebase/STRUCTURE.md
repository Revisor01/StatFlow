# Codebase Structure

**Last updated:** 2026-04-04

## Directory Layout

```
InsightFlow/                           # Main app target
├── App/                               # App lifecycle, routing, deep linking
│   ├── InsightFlowApp.swift           # @main entry (struct PrivacyFlowApp), BGTask, deep links
│   ├── ContentView.swift              # Auth gate: LoginView vs MainTabView
│   └── MainTabView.swift              # TabView: Dashboard / Admin / Settings
├── Services/                          # Business logic, API clients, managers
│   ├── AccountManager.swift           # Multi-account CRUD, credential hydration, widget sync
│   ├── AnalyticsProvider.swift        # Provider protocol + AnalyticsManager + unified models
│   ├── UmamiAPI.swift                 # Umami REST client (actor), admin/reports/sessions
│   ├── PlausibleAPI.swift             # Plausible v2 Query API client (actor)
│   ├── AnalyticsCacheService.swift    # File-based JSON cache with TTL in App Group
│   ├── NotificationManager.swift      # Push notification scheduling & stats fetching
│   ├── DashboardSettingsManager.swift # Dashboard UI preferences (metrics, chart style)
│   ├── KeychainService.swift          # Keychain wrapper (global + account-scoped)
│   ├── SharedCredentials.swift        # AES-GCM encrypted widget credential bridge
│   └── SupportManager.swift           # StoreKit 2 tip jar
├── Models/                            # Codable data structures
│   ├── Website.swift                  # Website, WebsiteResponse
│   ├── Stats.swift                    # WebsiteStats, StatValue, TimeSeriesPoint, MetricItem,
│   │                                  # MetricType, RealtimeData, Session, RetentionRow, Events
│   ├── Events.swift                   # EventData models (fields, values, properties)
│   ├── Reports.swift                  # Report, FunnelStep, UTMReportItem, GoalReportResult,
│   │                                  # AttributionResponse, AttributionItem
│   ├── Admin.swift                    # Team, UmamiUser, JourneyPath
│   ├── Share.swift                    # Share link models
│   ├── DateRange.swift                # DateRangePreset enum + DateRange struct
│   └── PlausibleGoal.swift            # PlausibleGoal, GoalConversion, PlausibleQueryFilter
├── Views/                             # SwiftUI views organized by feature
│   ├── Auth/
│   │   ├── LoginView.swift            # Multi-provider login UI (Umami + Plausible)
│   │   └── LoginViewModel.swift       # Login orchestration -> AccountManager
│   ├── Dashboard/
│   │   ├── DashboardView.swift        # Website list + DashboardViewModel (embedded, line 791)
│   │   ├── WebsiteCard.swift          # Card component with stats, sparkline, active visitors
│   │   ├── AddUmamiSiteView.swift     # Create Umami website sheet
│   │   └── AddPlausibleSiteView.swift # Add Plausible site domain sheet
│   ├── Detail/
│   │   ├── WebsiteDetailView.swift    # Full analytics detail (786 lines)
│   │   ├── WebsiteDetailViewModel.swift # 18 parallel data loads via TaskGroup
│   │   ├── WebsiteDetailChartSection.swift  # Swift Charts rendering
│   │   ├── WebsiteDetailMetricsSections.swift # Metric card grids
│   │   ├── WebsiteDetailSupportingViews.swift # Helper views (stat cards, etc.)
│   │   ├── CompareView.swift          # Date range A/B comparison
│   │   ├── CompareViewModel.swift     # Dual-range data fetching
│   │   └── CompareHeroCard.swift      # Comparison stat card
│   │   └── CompareChartSection.swift  # Comparison chart overlay
│   ├── Realtime/
│   │   └── RealtimeView.swift         # Live visitors, pageviews, events (650 lines)
│   ├── Events/
│   │   ├── EventsView.swift           # Event list + detail (Umami only)
│   │   └── EventsViewModel.swift      # Event + event-data loading
│   ├── Reports/
│   │   ├── ReportsHubView.swift       # Report type selector
│   │   ├── ReportsViewModel.swift     # Funnel, UTM, goals, attribution loading
│   │   ├── InsightsView.swift         # Insights/journey report
│   │   ├── PagesView.swift            # Top pages breakdown
│   │   ├── RetentionView.swift        # Cohort retention heatmap
│   │   └── ReportDetailViews.swift    # Shared report detail components
│   ├── Sessions/
│   │   └── SessionsView.swift         # Session browsing + activity (Umami only)
│   ├── Admin/
│   │   ├── AdminView.swift            # Admin section: websites, teams, users (Umami only)
│   │   ├── AdminCards.swift           # Admin card components
│   │   └── AdminSheets.swift          # Create/edit sheets for admin entities
│   ├── Settings/
│   │   ├── SettingsView.swift         # Main settings: accounts, notifications, cache, about
│   │   ├── DashboardSettingsView.swift # Metric toggles, chart style, date picker toggle
│   │   ├── AnalyticsGlossaryView.swift # Term definitions
│   │   ├── SetupGuideView.swift       # Umami/Plausible setup instructions
│   │   ├── SupportView.swift          # Tip jar UI
│   │   └── SupportReminderView.swift  # Periodic support prompt sheet
│   ├── Onboarding/
│   │   └── OnboardingView.swift       # First-launch walkthrough (fullScreenCover)
│   └── Components/                    # Reserved for reusable components (currently empty)
├── Extensions/
│   └── View+Extensions.swift          # .glassBackground(), .shimmer() modifiers, Color extensions
└── Resources/
    ├── Assets.xcassets/               # App icons (3 variants), accent color
    ├── en.lproj/                      # English localization
    └── de.lproj/                      # German localization (primary)

InsightFlowWidget/                     # Widget extension target (fully independent)
├── InsightFlowWidget.swift            # Widget definition (PrivacyFlowWidget)
├── InsightFlowWidgetBundle.swift      # Widget bundle registration
├── InsightFlowWidgetLiveActivity.swift # Live Activity (stub/future)
├── Cache/
│   └── WidgetCache.swift              # Widget-specific cache
├── Intents/
│   └── WidgetIntents.swift            # AppIntent configuration for widget
├── Models/
│   ├── WidgetModels.swift             # Widget data models (StatsEntry, etc.)
│   └── WidgetTimeRange.swift          # Widget time range options
├── Networking/
│   └── WidgetNetworking.swift         # Standalone API calls for widget timeline
├── Storage/
│   └── WidgetStorage.swift            # Reads SharedCredentials from App Group
├── Views/
│   ├── WidgetChartViews.swift         # Mini chart rendering for widgets
│   └── WidgetSizeViews.swift          # Layout per widget family (small/medium)
├── Resources/
│   ├── en.lproj/                      # Widget English strings
│   └── de.lproj/                      # Widget German strings
└── Assets.xcassets/                   # Widget-specific assets

InsightFlowTests/                      # Unit test target
├── AccountManagerTests.swift          # Multi-account CRUD, credential hydration
├── AnalyticsCacheServiceTests.swift   # Cache save/load/TTL/eviction
├── DashboardViewModelTests.swift      # Dashboard data loading
├── DateRangeTests.swift               # DateRange preset computation
├── KeychainServiceTests.swift         # Keychain save/load/delete
├── PlausibleAPIParsingTests.swift     # Plausible JSON response parsing
├── UmamiAPIParsingTests.swift         # Umami JSON response parsing
└── WebsiteDetailViewModelTests.swift  # Detail view data loading

Root files:
├── InsightFlow.xcodeproj/             # Xcode project
├── InsightFlowWidgetExtension.entitlements # Widget App Group entitlement
├── .planning/                         # GSD planning documents
├── .gitignore
├── LICENSE
└── README.md
```

## Directory Purposes

**`InsightFlow/App/`:**
- Purpose: App lifecycle, window setup, auth routing
- Contains: `@main` struct, root `ContentView`, `MainTabView`
- Key files: `InsightFlowApp.swift` (entry, BGTask, deep links), `ContentView.swift` (auth gate)

**`InsightFlow/Services/`:**
- Purpose: All business logic -- API clients, auth, caching, notifications, settings
- Contains: 10 files covering all non-UI logic
- Key files: `AnalyticsProvider.swift` (protocol + manager + unified models), `AccountManager.swift` (multi-account), `UmamiAPI.swift` + `PlausibleAPI.swift` (API actors)
- Note: `AnalyticsProvider.swift` contains the protocol, unified model structs (`AnalyticsWebsite`, `AnalyticsStats`, etc.), `AnalyticsManager` class, and credential enum -- all in one file

**`InsightFlow/Models/`:**
- Purpose: Codable data structures mirroring API responses + domain value types
- Contains: 8 model files, all structs are `Sendable`
- Key files: `Stats.swift` (largest -- contains stats, time series, metrics, realtime, sessions, retention, events), `Reports.swift` (report types), `DateRange.swift` (date filtering)
- Note: `Stats.swift` is a large file containing many different model types (stats, realtime, sessions, events, retention)

**`InsightFlow/Views/`:**
- Purpose: Feature-organized SwiftUI view hierarchy
- Contains: 10 subdirectories, views co-located with their ViewModels
- Organization: One directory per feature area

**`InsightFlow/Views/Dashboard/`:**
- Purpose: Main website overview with stats cards
- Key files: `DashboardView.swift` (1189 lines -- contains both view AND `DashboardViewModel`)
- Note: `DashboardViewModel` is embedded in DashboardView.swift starting at line 791

**`InsightFlow/Views/Detail/`:**
- Purpose: Deep analytics for a single website
- Key files: `WebsiteDetailView.swift` (786 lines), `WebsiteDetailViewModel.swift` (443 lines -- 18 parallel data loads)
- Contains: Chart sections, metric grids, compare feature (A/B date range)

**`InsightFlow/Views/Reports/`:**
- Purpose: Advanced Umami reports (funnel, UTM, goals, attribution, retention, journey)
- Key files: `ReportsViewModel.swift` (report data loading), `ReportsHubView.swift` (navigation hub)

**`InsightFlowWidget/`:**
- Purpose: Fully independent widget extension
- Architecture: Own networking, models, cache, views -- does NOT import main app code
- Reads credentials from App Group via `WidgetStorage` -> `SharedCredentials`
- Supports: `.systemSmall` and `.systemMedium` widget families

**`InsightFlowTests/`:**
- Purpose: Unit tests for services, models, and ViewModels
- Contains: 8 test files covering core logic
- Pattern: XCTest-based, mock-free parsing tests for API responses

## Key File Locations

**Entry Points:**
- `InsightFlow/App/InsightFlowApp.swift`: `@main` app struct (`PrivacyFlowApp`), BGTask registration, deep link handling
- `InsightFlow/App/ContentView.swift`: Root view, auth gate, onboarding
- `InsightFlow/App/MainTabView.swift`: Tab navigation (Dashboard/Admin/Settings)

**Configuration:**
- `InsightFlow/Services/AccountManager.swift`: Account persistence (UserDefaults metadata + Keychain credentials)
- `InsightFlow/Services/DashboardSettingsManager.swift`: Dashboard UI preferences
- `InsightFlow/Services/SharedCredentials.swift`: Widget credential bridge (encrypted)
- `InsightFlowWidgetExtension.entitlements`: Widget App Group entitlement

**Core Logic:**
- `InsightFlow/Services/AnalyticsProvider.swift`: Protocol + AnalyticsManager + unified models
- `InsightFlow/Services/UmamiAPI.swift`: Umami REST client (891 lines, full API surface)
- `InsightFlow/Services/PlausibleAPI.swift`: Plausible v2 Query API client
- `InsightFlow/Services/AnalyticsCacheService.swift`: File cache with TTL (464 lines)

**Testing:**
- `InsightFlowTests/`: 8 test files
- No test fixtures directory -- test data is inline

## Naming Conventions

**Files:**
- Views: `{Feature}View.swift` (e.g., `DashboardView.swift`, `WebsiteDetailView.swift`)
- ViewModels: `{Feature}ViewModel.swift` (e.g., `LoginViewModel.swift`, `WebsiteDetailViewModel.swift`)
- Services: `{Name}Manager.swift` or `{Name}API.swift` (e.g., `AccountManager.swift`, `UmamiAPI.swift`)
- Models: Domain noun (e.g., `Website.swift`, `Stats.swift`, `Reports.swift`)
- Extensions: `{BaseType}+{Purpose}.swift` (e.g., `View+Extensions.swift`)
- Supporting views: `{Feature}{Purpose}.swift` (e.g., `WebsiteDetailChartSection.swift`, `AdminCards.swift`)

**Directories:**
- Feature directories: PascalCase singular noun (e.g., `Dashboard/`, `Detail/`, `Auth/`)
- Infrastructure directories: PascalCase (e.g., `Services/`, `Models/`, `Extensions/`)

## Where to Add New Code

**New Feature (full screen):**
- Create directory: `InsightFlow/Views/{FeatureName}/`
- View: `InsightFlow/Views/{FeatureName}/{FeatureName}View.swift`
- ViewModel: `InsightFlow/Views/{FeatureName}/{FeatureName}ViewModel.swift`
- Add tab or navigation link in `MainTabView.swift` or appropriate parent view
- Add new models to `InsightFlow/Models/` if new API response types needed

**New API Endpoint (provider-agnostic):**
- Add method to `AnalyticsProvider` protocol in `InsightFlow/Services/AnalyticsProvider.swift`
- Implement in both `InsightFlow/Services/UmamiAPI.swift` and `InsightFlow/Services/PlausibleAPI.swift`
- Add default implementation in protocol extension if one provider doesn't support it

**New API Endpoint (provider-specific):**
- Add method directly to the specific API actor (`UmamiAPI` or `PlausibleAPI`)
- Cast to concrete type in ViewModel: `guard let umami = provider as? UmamiAPI else { return }`

**New Model:**
- Add to existing file if related (e.g., new event type -> `InsightFlow/Models/Events.swift`)
- Create new file in `InsightFlow/Models/` for unrelated domain concepts
- Ensure `Codable, Sendable` conformance
- Add `Identifiable` with computed `id` for use in SwiftUI `ForEach`

**New Reusable Component:**
- Place in `InsightFlow/Views/Components/` (currently empty, reserved for this purpose)
- Or create `InsightFlow/Views/{Feature}/{Feature}{ComponentName}.swift` if feature-specific

**New Extension:**
- Add to `InsightFlow/Extensions/View+Extensions.swift` for View modifiers
- Create `InsightFlow/Extensions/{Type}+{Purpose}.swift` for other types

**New Test:**
- Add to `InsightFlowTests/{ClassName}Tests.swift`
- Follow pattern: XCTest class, inline test data, no external fixtures

**New Localized String:**
- Add key to both `InsightFlow/Resources/en.lproj/Localizable.strings` and `de.lproj/Localizable.strings`
- Use `String(localized: "key")` in code or `Text("key")` in SwiftUI
- For widget strings, use `InsightFlowWidget/Resources/{lang}.lproj/`

**New Widget Feature:**
- All widget code goes in `InsightFlowWidget/` -- do NOT import from main app target
- Models: `InsightFlowWidget/Models/`
- Networking: `InsightFlowWidget/Networking/WidgetNetworking.swift`
- Views: `InsightFlowWidget/Views/`

## Special Directories

**`InsightFlow/Views/Components/`:**
- Purpose: Reserved for shared reusable UI components
- Status: Currently empty
- Committed: Yes

**`InsightFlow/Resources/Assets.xcassets/`:**
- Purpose: App icons (3 icon variants: AppIcon, AppIcon1, AppIcon2, AppIcon3), accent color
- Generated: Partially (Xcode derives from source images)
- Committed: Yes

**`.planning/`:**
- Purpose: GSD planning documents (architecture, phases, milestones)
- Contains: `codebase/` (this file), `phases/`, `milestones/`, project config
- Generated: By GSD tooling
- Committed: Yes

**`build/`:**
- Purpose: Build artifacts
- Generated: Yes
- Committed: No (in .gitignore)

---

*Structure analysis: 2026-04-04*
