# Coding Conventions

**Last updated:** 2026-04-04

## Naming Patterns

**Files:**
- Views: PascalCase matching the struct name (`DashboardView.swift`, `WebsiteCard.swift`)
- ViewModels: PascalCase with `ViewModel` suffix (`WebsiteDetailViewModel.swift`, `ReportsViewModel.swift`)
- Models: PascalCase noun matching primary type (`Website.swift`, `Stats.swift`, `Reports.swift`)
- Services: PascalCase with purpose suffix (`KeychainService.swift`, `AnalyticsCacheService.swift`, `AccountManager.swift`)
- Extensions: `TypeName+Extensions.swift` (`View+Extensions.swift`)
- Tests: `{Feature}Tests.swift` (`DateRangeTests.swift`, `AccountManagerTests.swift`)

**Types:**
- Structs for data models: `Website`, `StatValue`, `MetricItem`, `AnalyticsWebsite`
- Classes for ViewModels: `WebsiteDetailViewModel`, `ReportsViewModel`, `LoginViewModel`
- Enums for fixed sets: `MetricType`, `DateRangePreset`, `APIError`, `AnalyticsProviderType`
- Actors for thread-safe API clients: `UmamiAPI`, `PlausibleAPI`
- Protocols: adjective/noun style (`AnalyticsProvider`)

**Functions:**
- camelCase verbs: `loadData()`, `getWebsites()`, `saveCredential()`
- Async data loaders prefixed `load`: `loadStats()`, `loadActiveVisitors()`, `loadTopPages()`
- API methods prefixed `get`: `getMetrics()`, `getStats()`, `getPageviews()`
- Boolean computed properties: `isPositiveChange`, `isPageview`, `isOffline`, `hasFunnelReports`

**Variables:**
- camelCase: `websiteId`, `dateRange`, `activeVisitors`
- Private stored properties in actors: underscore prefix (`_baseURL`, `_token`)
- Published properties: no prefix, descriptive names (`stats`, `isLoading`, `error`)
- Enum cases: lowerCamelCase (`.today`, `.last7Days`, `.selfHosted`)

**Localization Keys:**
- Dot-separated hierarchical: `"dashboard.visitors"`, `"button.cancel"`, `"daterange.today"`
- Category prefix matching feature area: `dashboard.`, `settings.`, `addSite.`, `login.`, `daterange.`

## Code Style

**Formatting:**
- No external formatter (SwiftLint/SwiftFormat not configured)
- 4-space indentation (Xcode default)
- Opening braces on same line (K&R style)
- One blank line between logical sections
- Consistent use of trailing closures for SwiftUI modifiers

**Linting:**
- No linting tools configured
- Conventions enforced by code review and consistency

## Section Organization (MARK Comments)

Use `// MARK: -` extensively to organize code sections. ~276 occurrences across 42 files.

**In API clients** (`InsightFlow/Services/UmamiAPI.swift`, `InsightFlow/Services/PlausibleAPI.swift`):
```swift
// MARK: - AnalyticsProvider Protocol
// MARK: - AnalyticsProvider - Authentication
// MARK: - AnalyticsProvider - Websites
// MARK: - AnalyticsProvider - Stats
// MARK: - Authentication
// MARK: - Websites
// MARK: - Stats
// MARK: - Events
// MARK: - Sessions
// MARK: - Reports
// MARK: - Private
```

**In ViewModels:**
```swift
// MARK: - Computed Properties
// MARK: - Init
// MARK: - Data Loading
```

**In Tests:**
```swift
// MARK: - Setup / Teardown
// MARK: - Helper
// MARK: - Tests
```

## Import Organization

**Order:**
1. `Foundation`
2. Apple frameworks (`SwiftUI`, `Security`, `WidgetKit`, `Combine`, `Charts`)
3. No third-party imports -- zero external dependencies for app target

**No path aliases.** All imports are framework-level. Tests use `@testable import InsightFlow`.

## Error Handling

**API Errors:**
- Dedicated `APIError` enum in `InsightFlow/Services/UmamiAPI.swift` (line 866)
- Cases: `.notConfigured`, `.invalidURL`, `.invalidResponse`, `.authenticationFailed`, `.unauthorized`, `.serverError(Int)`
- Conforms to `LocalizedError` with German error descriptions
- Keychain errors: `KeychainError` enum in `InsightFlow/Services/KeychainService.swift` (line 141)

**ViewModel Error Handling Pattern (reference):**
```swift
// Standard pattern used across all ViewModels:
do {
    let result = try await provider.someMethod()
    guard !Task.isCancelled else { return }
    self.property = result
} catch {
    guard !Task.isCancelled else { return }
    let isNetworkError = (error as? URLError)?.code == .notConnectedToInternet ||
                         (error as? URLError)?.code == .networkConnectionLost ||
                         (error as? URLError)?.code == .timedOut ||
                         (error as? URLError)?.code == .cannotFindHost ||
                         (error as? URLError)?.code == .cannotConnectToHost
    if isNetworkError {
        isOffline = true
    } else {
        self.error = error.localizedDescription
    }
}
```

**Non-critical load failures:** Silently caught with `#if DEBUG` print statements (87 total `#if DEBUG` blocks). Only the primary `loadStats()` sets the `error` property; individual metric loads fail silently.

**Task Cancellation:** Always check `guard !Task.isCancelled else { return }` after each `await` before updating UI state. See `InsightFlow/Views/Detail/WebsiteDetailViewModel.swift` for the canonical pattern.

## Logging

**Framework:** `print()` wrapped in `#if DEBUG` guards -- no production logging.

**Pattern:**
```swift
#if DEBUG
print("ClassName.methodName: description \(variable)")
#endif
```

**When to log:**
- API response bodies (truncated to 500 chars): `print("UmamiAPI.getMetrics(\(type.rawValue)): \(jsonString.prefix(500))")`
- Error descriptions in non-critical catch blocks
- Cache operations (save/load/clear)

## Localization

**Approach:** Apple `String(localized:)` API with `.strings` files. ~346 usages across 32 files.

**Languages:** English (`en.lproj`) and German (`de.lproj`), ~600 keys each.

**Files:**
- `InsightFlow/Resources/en.lproj/Localizable.strings`
- `InsightFlow/Resources/de.lproj/Localizable.strings`
- Widget: `InsightFlowWidget/Resources/en.lproj/Localizable.strings` and `de.lproj/`

**Usage pattern:**
```swift
// Standard:
String(localized: "dashboard.visitors")
String(localized: "error.invalidURL")

// With default value:
String(localized: "daterange.lastYear", defaultValue: "Last Year")
```

**Known inconsistency:** Some strings are hardcoded German instead of localized:
- `APIError.errorDescription` values in `InsightFlow/Services/UmamiAPI.swift`
- `MetricType.displayName` values in `InsightFlow/Models/Stats.swift`
- `RealtimeEvent.timeAgo` in `InsightFlow/Models/Stats.swift` (uses "jetzt", "Min")

**Key naming convention:** `"category.subcategory"` or `"category.subcategory.detail"`.

## Concurrency Model

**Actors for API clients:** `UmamiAPI` and `PlausibleAPI` are Swift actors with `static let shared` singletons.

**@MainActor for ViewModels and managers:**
```swift
@MainActor
class WebsiteDetailViewModel: ObservableObject { ... }

@MainActor
class AnalyticsManager: ObservableObject { ... }
```

**Task cancellation pattern (canonical, from `WebsiteDetailViewModel`):**
```swift
private var loadingTask: Task<Void, Never>?

func loadData(dateRange: DateRange) async {
    loadingTask?.cancel()
    let task = Task {
        isLoading = true
        defer { if !Task.isCancelled { isLoading = false } }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadSomething() }
            // ...parallel loads
        }
    }
    loadingTask = task
    await task.value
}

func cancelLoading() {
    loadingTask?.cancel()
    loadingTask = nil
}
```

**Sendable conformance:** All model structs conform to `Sendable`. The cache service uses `@unchecked Sendable`.

## Singleton Pattern

Use `static let shared` for service singletons:
- `UmamiAPI.shared` -- `InsightFlow/Services/UmamiAPI.swift` (actor)
- `PlausibleAPI.shared` -- `InsightFlow/Services/PlausibleAPI.swift` (actor)
- `AnalyticsManager.shared` -- `InsightFlow/Services/AnalyticsProvider.swift` (@MainActor class)
- `AccountManager.shared` -- `InsightFlow/Services/AccountManager.swift` (@MainActor class)
- `AnalyticsCacheService.shared` -- `InsightFlow/Services/AnalyticsCacheService.swift`
- `DashboardSettingsManager.shared` -- `InsightFlow/Services/DashboardSettingsManager.swift`

## SwiftUI View Pattern

**State management in Views:**
```swift
struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @ObservedObject private var accountManager = AccountManager.shared
    @EnvironmentObject private var quickActionManager: QuickActionManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedWebsite: Website?
}
```

**View decomposition:** Large views split into computed properties and dedicated supporting files:
- `InsightFlow/Views/Detail/WebsiteDetailView.swift` (main view)
- `InsightFlow/Views/Detail/WebsiteDetailSupportingViews.swift` (sub-components)
- `InsightFlow/Views/Detail/WebsiteDetailMetricsSections.swift` (metric sections)
- `InsightFlow/Views/Detail/WebsiteDetailChartSection.swift` (chart section)

**Custom View Modifiers** in `InsightFlow/Extensions/View+Extensions.swift`:
- `.glassBackground(cornerRadius:)` -- glassmorphism card style
- `.shimmer()` -- loading skeleton animation

## Model Design

**Codable structs with computed accessors for wire-format fields:**
```swift
struct MetricItem: Codable, Identifiable, Sendable {
    let x: String?
    let y: Int

    var id: String { x ?? "unknown" }
    var name: String { x ?? String(localized: "metrics.unknown") }
    var value: Int { y }
}
```

**Provider abstraction pattern:**
- Protocol: `AnalyticsProvider` in `InsightFlow/Services/AnalyticsProvider.swift`
- Implementations: `UmamiAPI`, `PlausibleAPI`
- Unified types: `AnalyticsWebsite`, `AnalyticsStats`, `AnalyticsChartPoint`, `AnalyticsMetricItem`
- Default implementations via protocol extensions for optional features
- API response models stay close to wire format (`x`/`y` fields), domain models wrap them

## Comments

**When to Comment:**
- Doc comments (`///`) for non-obvious methods: `/// Reconfigure from Keychain - called when switching accounts`
- Inline comments for workarounds: `// API returns array with [Team, TeamMembership] - parse manually`
- FIX references: `// Cancel vorherigen Load -- verhindert Background-Battery-Drain (FIX-02)`
- German comments acceptable for domain-specific explanations

**No TODO/FIXME/HACK/XXX comments exist in the codebase** (zero found).

---

*Convention analysis: 2026-04-04*
