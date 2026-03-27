# Codebase Structure

**Analysis Date:** 2026-03-27

## Directory Layout

```
InsightFlow/                          # Main app target
├── App/                              # App entry point and root navigation
│   ├── InsightFlowApp.swift          # @main, lifecycle, deep links, background tasks
│   ├── ContentView.swift             # Auth gate (Login vs MainTabView)
│   └── MainTabView.swift             # Tab bar (Dashboard, Admin, Settings)
├── Models/                           # Data models (Codable structs/enums)
│   ├── Website.swift                 # Website, WebsiteResponse
│   ├── Stats.swift                   # WebsiteStats, StatValue, PageviewsData, MetricItem, RealtimeData, Sessions, Retention
│   ├── DateRange.swift               # DateRangePreset, DateRange
│   └── Admin.swift                   # Team, TeamMember, UmamiUser, JourneyPath
├── Services/                         # Business logic, API clients, managers
│   ├── AnalyticsProvider.swift       # AnalyticsProvider protocol, AnalyticsProviderType, AnalyticsManager, unified models
│   ├── UmamiAPI.swift                # Umami REST API client (actor)
│   ├── PlausibleAPI.swift            # Plausible REST API client + PlausibleSitesManager
│   ├── AuthManager.swift             # Login/logout orchestration
│   ├── AccountManager.swift          # Multi-account management, AnalyticsAccount model
│   ├── KeychainService.swift         # iOS Keychain wrapper + StringUtils
│   ├── SharedCredentials.swift       # AES-GCM encrypted App Group file for widget
│   ├── AnalyticsCacheService.swift   # File-based JSON cache with TTL
│   ├── NotificationManager.swift     # Local notifications (daily/weekly stats)
│   ├── DashboardSettingsManager.swift # Dashboard UI preferences (metrics, chart style)
│   └── SupportManager.swift          # StoreKit 2 in-app purchases (tip jar)
├── Views/                            # SwiftUI views organized by feature
│   ├── Auth/
│   │   └── LoginView.swift           # Provider selection, server URL, credentials input
│   ├── Dashboard/
│   │   ├── DashboardView.swift       # Main dashboard with website list (1067 lines)
│   │   ├── WebsiteCard.swift         # Individual website stats card (647 lines)
│   │   ├── AddUmamiSiteView.swift    # Create Umami website form
│   │   └── AddPlausibleSiteView.swift # Add Plausible site form
│   ├── Detail/
│   │   ├── WebsiteDetailView.swift   # Full website analytics detail (1611 lines)
│   │   ├── WebsiteDetailViewModel.swift # ViewModel: parallel metric loading
│   │   └── CompareView.swift         # Side-by-side website comparison (1183 lines)
│   ├── Admin/
│   │   └── AdminView.swift           # Umami admin: websites, teams, users (1318 lines)
│   ├── Settings/
│   │   ├── SettingsView.swift        # App settings, accounts, notifications
│   │   ├── DashboardSettingsView.swift # Dashboard customization
│   │   ├── SupportView.swift         # Tip jar / in-app purchases
│   │   └── SupportReminderView.swift # Support prompt after N launches
│   ├── Realtime/
│   │   └── RealtimeView.swift        # Live visitor tracking (644 lines)
│   ├── Sessions/
│   │   └── SessionsView.swift        # Session browser with activity detail (668 lines)
│   ├── Reports/
│   │   ├── InsightsView.swift        # Journey/funnel reports
│   │   ├── PagesView.swift           # Page-level analytics
│   │   └── RetentionView.swift       # User retention heatmap
│   ├── Onboarding/
│   │   └── OnboardingView.swift      # First-launch walkthrough
│   └── Components/                   # Empty - reusable components (unused)
├── Extensions/
│   └── View+Extensions.swift         # glassBackground(), shimmer() modifiers, Color extensions
└── Resources/
    ├── Assets.xcassets/              # App icons (4 variants), accent color
    ├── de.lproj/
    │   ├── Localizable.strings       # German translations
    │   └── InfoPlist.strings         # German plist strings
    └── en.lproj/
        ├── Localizable.strings       # English translations
        └── InfoPlist.strings         # English plist strings

InsightFlowWidget/                    # Widget extension target
├── InsightFlowWidgetBundle.swift     # @main widget bundle
├── InsightFlowWidget.swift           # Timeline provider + widget views (2004 lines)
├── InsightFlowWidgetLiveActivity.swift # Live Activity definition
├── Assets.xcassets/                  # Widget-specific assets
└── Resources/
    ├── de.lproj/Localizable.strings  # German widget strings
    └── en.lproj/Localizable.strings  # English widget strings

InsightFlow.xcodeproj/               # Xcode project file
InsightFlowWidgetExtension.entitlements # Widget entitlements (App Group)
```

## Directory Purposes

**`InsightFlow/App/`:**
- Purpose: Application lifecycle and root-level navigation
- Contains: 3 files - app entry, auth gate, tab bar
- Key files: `InsightFlowApp.swift` (165 lines - background tasks, deep links, QuickActionManager)

**`InsightFlow/Models/`:**
- Purpose: Pure data structures, no business logic
- Contains: Codable structs for all API response types + domain enums
- Key files: `Stats.swift` (351 lines - most models live here including realtime, sessions, retention)

**`InsightFlow/Services/`:**
- Purpose: All business logic, API communication, state management, persistence
- Contains: 11 service files, all using singleton pattern
- Key files: `AnalyticsProvider.swift` (237 lines - protocol + unified models + AnalyticsManager), `UmamiAPI.swift` (642 lines), `PlausibleAPI.swift` (854 lines), `AccountManager.swift` (351 lines)

**`InsightFlow/Views/`:**
- Purpose: All UI code organized by feature area
- Contains: 9 subdirectories, 17 view files total
- Key files: `WebsiteDetailView.swift` (1611 lines - largest view), `DashboardView.swift` (1067 lines), `AdminView.swift` (1318 lines)

**`InsightFlowWidget/`:**
- Purpose: iOS home screen widget extension
- Contains: Timeline provider, widget views, Live Activity
- Key files: `InsightFlowWidget.swift` (2004 lines - self-contained with own API logic)

## Key File Locations

**Entry Points:**
- `InsightFlow/App/InsightFlowApp.swift`: Main app entry, struct `PrivacyFlowApp`
- `InsightFlowWidget/InsightFlowWidgetBundle.swift`: Widget entry, struct `PrivacyFlowWidgetBundle`

**Configuration:**
- `InsightFlow.xcodeproj/project.pbxproj`: Xcode project configuration
- `InsightFlowWidgetExtension.entitlements`: Widget App Group entitlement
- `.gitignore`: Standard Xcode gitignore

**Core Logic:**
- `InsightFlow/Services/AnalyticsProvider.swift`: The central protocol that all analytics operations go through
- `InsightFlow/Services/UmamiAPI.swift`: Complete Umami v2 REST API client
- `InsightFlow/Services/PlausibleAPI.swift`: Plausible Stats API v2 client + Sites Manager
- `InsightFlow/Services/AuthManager.swift`: Authentication orchestration for both providers
- `InsightFlow/Services/AccountManager.swift`: Multi-account persistence and switching

**Credential Storage:**
- `InsightFlow/Services/KeychainService.swift`: iOS Keychain CRUD wrapper
- `InsightFlow/Services/SharedCredentials.swift`: AES-GCM encrypted file in App Group for widget

**Testing:**
- No test files exist in the project

## Naming Conventions

**Files:**
- Views: `{Feature}View.swift` (e.g., `DashboardView.swift`, `LoginView.swift`)
- ViewModels: `{Feature}ViewModel.swift` (only `WebsiteDetailViewModel.swift` exists)
- Services/Managers: `{Purpose}Manager.swift` or `{Provider}API.swift`
- Models: Named by domain concept (e.g., `Website.swift`, `Stats.swift`, `Admin.swift`)

**Directories:**
- Feature-based grouping under `Views/` (e.g., `Dashboard/`, `Detail/`, `Admin/`)
- Flat structure for `Models/`, `Services/`, `Extensions/`

## Where to Add New Code

**New View / Screen:**
- Create file in `InsightFlow/Views/{FeatureName}/{FeatureName}View.swift`
- If complex state needed, add `InsightFlow/Views/{FeatureName}/{FeatureName}ViewModel.swift`
- Wire into `MainTabView.swift` (new tab) or existing navigation (push from existing view)

**New Analytics Feature (works for both providers):**
- Add method to `AnalyticsProvider` protocol in `InsightFlow/Services/AnalyticsProvider.swift`
- Implement in `InsightFlow/Services/UmamiAPI.swift` and `InsightFlow/Services/PlausibleAPI.swift`
- Add unified model structs in `InsightFlow/Services/AnalyticsProvider.swift` (unified models section)

**New API Endpoint (provider-specific):**
- Umami: Add method to `InsightFlow/Services/UmamiAPI.swift`
- Plausible: Add method to `InsightFlow/Services/PlausibleAPI.swift`
- Response models go in `InsightFlow/Models/Stats.swift` (Umami) or inline in PlausibleAPI.swift (Plausible)

**New Model:**
- Add to existing file in `InsightFlow/Models/` if related (Stats.swift for analytics data, Admin.swift for admin entities)
- Create new file in `InsightFlow/Models/` only for distinctly new domain concepts

**New Service/Manager:**
- Create `InsightFlow/Services/{Name}Manager.swift`
- Follow singleton pattern: `static let shared = {Name}Manager()`
- Mark class `@MainActor` if it has `@Published` properties

**New Reusable UI Component:**
- `InsightFlow/Views/Components/` exists but is empty - use it for shared components
- View modifiers go in `InsightFlow/Extensions/View+Extensions.swift`

**New Widget Feature:**
- All widget code is in `InsightFlowWidget/InsightFlowWidget.swift` (monolithic)
- Widget reads credentials from `SharedCredentials` and `widget_accounts.json` in App Group

**New Localization Strings:**
- German: `InsightFlow/Resources/de.lproj/Localizable.strings`
- English: `InsightFlow/Resources/en.lproj/Localizable.strings`
- Widget strings: `InsightFlowWidget/Resources/{lang}.lproj/Localizable.strings`

## Special Directories

**`InsightFlow/Resources/Assets.xcassets/`:**
- Purpose: App icons (4 alternate icons), accent color
- Generated: No (manually managed)
- Committed: Yes

**`InsightFlow.xcodeproj/`:**
- Purpose: Xcode project configuration (build settings, targets, schemes)
- Generated: Partially (Xcode manages it)
- Committed: Yes

**`.planning/`:**
- Purpose: GSD planning and codebase analysis documents
- Generated: By analysis tools
- Committed: Yes

**`InsightFlow/Views/Components/`:**
- Purpose: Intended for reusable UI components
- Status: Empty directory - components are currently inlined in feature views
- Committed: Directory exists but has no files

## App Group & Shared Data

The app and widget share data via App Group `group.de.godsapp.PrivacyFlow`:

| File | Written By | Read By | Purpose |
|------|-----------|---------|---------|
| `widget_credentials.encrypted` | Main app (`SharedCredentials`) | Widget | Encrypted API credentials |
| `widget_credentials.key` | Main app (`SharedCredentials`) | Widget | AES-GCM encryption key |
| `widget_accounts.json` | Main app (`AccountManager`) | Widget | All accounts for multi-account widget |
| `analytics_cache/*.json` | Main app (`AnalyticsCacheService`) | Widget (potentially) | Cached analytics data with TTL |

---

*Structure analysis: 2026-03-27*
