# Coding Conventions

**Analysis Date:** 2026-03-27

## Naming Patterns

**Files:**
- Views use PascalCase matching the struct name: `DashboardView.swift`, `WebsiteCard.swift`, `LoginView.swift`
- ViewModels use the suffix `ViewModel`: `WebsiteDetailViewModel.swift`
- Services/Managers use descriptive PascalCase: `AuthManager.swift`, `AccountManager.swift`, `KeychainService.swift`
- Models use singular PascalCase: `Website.swift`, `Stats.swift`, `DateRange.swift`
- Extensions use `TypeName+Extensions.swift` pattern: `View+Extensions.swift`

**Types:**
- Structs for data models: `Website`, `WebsiteStats`, `StatValue`, `AnalyticsWebsite`
- Classes for stateful managers, always `@MainActor` and `ObservableObject`: `AuthManager`, `AccountManager`, `DashboardSettingsManager`
- Enums for fixed categories: `AnalyticsProviderType`, `DateRangePreset`, `MetricType`, `DashboardChartStyle`
- Protocols use descriptive names without prefix: `AnalyticsProvider`
- Error enums use the suffix `Error`: `APIError`, `KeychainError`, `PlausibleError`

**Functions:**
- camelCase for all functions
- Async functions use `async throws` pattern: `func getStats(websiteId:dateRange:) async throws -> WebsiteStats`
- Private loader functions prefixed with `load`: `loadStats()`, `loadActiveVisitors()`, `loadPageviews()`
- Boolean computed properties use `is` prefix: `isAuthenticated`, `isPlausible`, `isLoading`

**Properties:**
- camelCase for all properties
- Published properties use `@Published` without underscore prefix
- Private backing stores use underscore prefix in actors: `_baseURL`, `_token` (see `UmamiAPI.swift`)

## Code Style

**Formatting:**
- No external formatter configured (no SwiftFormat/SwiftLint config files detected)
- 4-space indentation (standard Xcode default)
- Opening braces on same line as declaration
- Generous use of blank lines between logical sections

**Comment Style:**
- `// MARK: -` sections heavily used to organize code within files (see `UmamiAPI.swift`, `DashboardView.swift`, `AccountManager.swift`)
- Inline comments in German and English mixed: `// Wenn Provider gewechselt werden muss`, `// Delete existing item first`
- `///` doc comments used sparingly, mostly for non-obvious methods: `/// Fills in missing time slots with zero values` in `WebsiteDetailViewModel.swift`
- `#if DEBUG` guards for debug-only print statements (see `WebsiteDetailViewModel.swift` lines 89-92)

**Import Organization:**
- System frameworks first: `import Foundation`, `import SwiftUI`
- Apple frameworks next: `import Charts`, `import StoreKit`, `import WidgetKit`, `import BackgroundTasks`
- No third-party dependencies -- the project uses only Apple frameworks
- No blank lines between imports

## SwiftUI Patterns

**View Composition:**
- Large views decompose into computed properties for sections: `headerSection`, `offlineBanner`, `dateRangePicker`, `emptyStateView` (see `DashboardView.swift`)
- Shared reusable views live in `InsightFlow/Views/Components/` (currently empty -- components are inlined)
- Custom Layout implementations used directly in view files: `FlowLayout` in `WebsiteCard.swift`
- `#Preview` macro used for previews: see `ContentView.swift` line 39

**State Management:**
- Singleton pattern with `static let shared` for all managers: `AccountManager.shared`, `AnalyticsManager.shared`, `DashboardSettingsManager.shared`, `SupportManager.shared`
- `@StateObject` for owned view models created in views: `@StateObject private var viewModel = DashboardViewModel()`
- `@ObservedObject` for shared singletons accessed in views: `@ObservedObject private var accountManager = AccountManager.shared`
- `@EnvironmentObject` for app-wide dependencies injected from root: `authManager`, `notificationManager`, `quickActionManager`
- `@State` for local view state: `@State private var selectedWebsite: Website?`
- `@AppStorage` for simple UserDefaults-backed preferences: `@AppStorage("colorScheme")`, `@AppStorage("hasSeenOnboarding")`
- `@Published` for all observable properties on manager classes
- `UserDefaults` for complex settings persistence (e.g., `DashboardSettingsManager`)
- `NotificationCenter` for cross-component communication: `.accountDidChange`, `.allAccountsRemoved`

**Common View Modifiers:**
- `.environmentObject()` chaining at app root in `InsightFlowApp.swift`
- `.background(Color(.systemGroupedBackground).ignoresSafeArea())` for standard iOS backgrounds
- `.glassBackground()` custom modifier from `View+Extensions.swift` for glassmorphism effect
- `.shimmer()` custom modifier for loading skeleton animations
- `.animation(.smooth, value:)` and `.animation(.spring(duration:))` for transitions
- `.navigationTitle()` with localization keys directly: `.navigationTitle("dashboard.title")`
- `.accessibilityLabel()` used on interactive elements

**Navigation:**
- `NavigationStack` as the primary navigation container
- `NavigationLink` for drill-down navigation
- `.fullScreenCover` for modal presentations (onboarding)
- `.sheet` for secondary presentations (account switcher, add site)

## Concurrency Patterns

**Actor Isolation:**
- API service classes use Swift `actor` for thread safety: `actor UmamiAPI: AnalyticsProvider` in `UmamiAPI.swift`
- Manager classes use `@MainActor` annotation: `@MainActor class AuthManager`, `@MainActor class AccountManager`
- Protocol properties marked `nonisolated` where needed: `nonisolated var serverURL: String`

**Async/Await:**
- All API calls are `async throws`
- `Task {}` blocks for launching async work from synchronous contexts
- `withTaskGroup` for parallel data loading (see `WebsiteDetailViewModel.swift` line 43)
- `defer { isLoading = false }` pattern for cleanup after async operations

## Localization

**Mechanism:**
- `Localizable.strings` files in `.lproj` directories (NOT `.xcstrings` catalogs)
- `String(localized:)` initializer for programmatic localization in Swift code
- Direct string keys in SwiftUI views: `Text("button.done")`, `.navigationTitle("dashboard.title")`

**Supported Languages:**
- English: `InsightFlow/Resources/en.lproj/Localizable.strings`
- German: `InsightFlow/Resources/de.lproj/Localizable.strings`
- Widget also localized: `InsightFlowWidget/Resources/en.lproj/`, `InsightFlowWidget/Resources/de.lproj/`

**String Key Organization:**
- Hierarchical dot notation: `section.subsection.key`
- Organized by `// MARK: -` sections: General, Tabs, Dashboard, Settings, etc.
- Format strings use `%@` and `%lld` placeholders: `"admin.websites.delete.message %@"`, `"journeys.visitors %lld"`
- Keys match feature areas: `dashboard.*`, `settings.*`, `admin.*`, `login.*`, `error.*`

**When adding new strings:**
1. Add the key to BOTH `en.lproj/Localizable.strings` and `de.lproj/Localizable.strings`
2. Follow the `section.subsection.key` naming pattern
3. Place the key under the appropriate `// MARK: -` section
4. Use `String(localized:)` in Swift code or direct key in SwiftUI `Text()`

## Error Handling

**API Errors:**
- Custom `APIError` enum in `UmamiAPI.swift` with `LocalizedError` conformance
- Custom `PlausibleError` enum in `PlausibleAPI.swift`
- Custom `KeychainError` enum in `KeychainService.swift`
- Error descriptions are hardcoded in German for some errors: `"API ist nicht konfiguriert"`, `"Keychain Speicherfehler"`

**Error Handling Patterns:**
- `do/catch` with specific error type matching: `catch let error as APIError` (see `AuthManager.swift` line 152)
- Silent error swallowing with `#if DEBUG print()` for non-critical failures (metric loading in `WebsiteDetailViewModel.swift`)
- `@Published var error: String?` for surfacing errors to the UI
- `@Published var errorMessage: String?` on `AuthManager` for login errors
- `try?` used for non-critical operations: `try? KeychainService.save(...)` in `AccountManager.swift`

## Data Flow Architecture

**Provider Abstraction:**
- `AnalyticsProvider` protocol in `AnalyticsProvider.swift` defines the unified API interface
- `UmamiAPI` (actor) and `PlausibleAPI` (actor) both conform to `AnalyticsProvider`
- `AnalyticsManager` holds the current provider and manages switching
- ViewModels check `isPlausible` flag to branch between providers (see `WebsiteDetailViewModel.swift`)

**Persistence:**
- Keychain for secrets via `KeychainService` (tokens, API keys, server URLs)
- `UserDefaults` for preferences (settings, account list via JSON encoding)
- App Group shared container for widget data: `group.de.godsapp.PrivacyFlow`
- `SharedCredentials` for widget-app credential sharing via file in app group container

---

*Convention analysis: 2026-03-27*
