# Coding Conventions

**Analysis Date:** 2026-03-28

## Naming Patterns

**Files:**
- View files: `{Feature}View.swift` (e.g., `DashboardView.swift`, `LoginView.swift`)
- ViewModel files: `{Feature}ViewModel.swift` (e.g., `LoginViewModel.swift`, `WebsiteDetailViewModel.swift`)
- Service/API files: `{Service}API.swift` or `{Service}Service.swift` (e.g., `UmamiAPI.swift`, `NotificationManager.swift`, `AccountManager.swift`)
- Model files: `{Entity}.swift` (e.g., `Website.swift`, `Stats.swift`, `DateRange.swift`)
- Extension files: `{Type}+Extensions.swift` (e.g., `View+Extensions.swift`)
- Test files: `{Feature}Tests.swift` (e.g., `DateRangeTests.swift`, `AccountManagerTests.swift`)

**Functions and Methods:**
- camelCase with descriptive action verbs
- Load/fetch operations: `load{Entity}()`, `fetch{Entity}()` (e.g., `loadStats()`, `getWebsites()`)
- Format/transform operations: `{verb}{Data}()` (e.g., `fillMissingTimeSlots()`, `formatDate()`)
- Private helper functions: prefixed with `private func` (e.g., `private func handleDeepLink()`)
- Async functions: `async` keyword required for concurrent operations (e.g., `async func loadData()`)
- Computed properties use lowercase naming matching their purpose

**Variables and Properties:**
- Published properties in ViewModels: `@Published var {noun}` (e.g., `@Published var isLoading = false`, `@Published var stats: WebsiteStats?`)
- State properties in Views: `@State private var {noun}` (e.g., `@State private var phase: CGFloat = 0`)
- Instance variables: camelCase (e.g., `activeVisitors`, `pageviewsData`)
- Constants in enums: `lowerCamelCase` (e.g., `.today`, `.last7Days`, `.umami`)

**Types and Enums:**
- Type names: PascalCase (e.g., `WebsiteStats`, `DateRange`, `LoginViewModel`)
- Enum names: PascalCase (e.g., `AnalyticsProviderType`, `DateRangePreset`)
- Enum cases: camelCase (e.g., `.cloud`, `.selfHosted`, `.plausible`)
- Protocol names: PascalCase with "Provider" or "Service" suffix (e.g., `AnalyticsProvider`)

## Code Style

**Formatting:**
- Xcode default indentation (4 spaces)
- Line length: No strict limit enforced, but aim for readability
- Brace style: Opening braces on same line (K&R style)
- Spacing: One blank line between logical sections

**Linting:**
- No explicit linter configured (SwiftLint not detected)
- Relying on Xcode warnings and manual code review

**Type Annotations:**
- Explicit return types required for all functions/methods
- Type inference used for local variables where obvious
- Generic type parameters clearly named (e.g., `<T>`, `<Provider>`)

## Import Organization

**Order:**
1. System frameworks: `import SwiftUI`, `import Foundation`, `import Charts`
2. System-specific: `import BackgroundTasks`, `import UserNotifications`, `import Security`
3. Third-party libraries: (Currently SwiftUI/Apple frameworks only)

**Path Aliases:**
- No path aliases detected; relative imports used
- @testable imports in tests: `@testable import InsightFlow`

**Example Pattern:**
```swift
import SwiftUI
import BackgroundTasks
import UserNotifications

@main
struct InsightFlowApp: App {
    // ...
}
```

## Error Handling

**Patterns:**
- Custom error enums: `APIError`, `PlausibleError`
- Catch blocks distinguish between error types using `error as ErrorType`
- Error messages: `errorMessage: String?` in ViewModels for UI display
- Guard statements for early returns on invalid state
- Deferred operations using `defer { isLoading = false }` for cleanup

**Example Pattern:**
```swift
do {
    let token = try await UmamiAPI.shared.login(baseURL: url, username: username, password: password)
    // Success path
} catch let error as APIError {
    errorMessage = error.errorDescription
} catch {
    errorMessage = error.localizedDescription
}
```

## Logging

**Framework:** `print()` in DEBUG mode only

**Patterns:**
```swift
#if DEBUG
print("Failed to load active visitors: \(error)")
#endif
```

**When to Log:**
- Non-critical failures (e.g., background refresh failures)
- Conditional on DEBUG build flag
- Never log sensitive data (tokens, credentials, user identifiers beyond IDs)

## Comments

**When to Comment:**
- Section headers using `// MARK: - SectionName` (e.g., `// MARK: - Notification Handling`)
- Complex logic requiring explanation (e.g., date calculations, retry logic)
- Subheadings within classes (e.g., `// MARK: - Setup / Teardown` in tests)
- German comments acceptable for domain-specific explanations (e.g., `// Wenn Provider gewechselt werden muss`)

**JSDoc/TSDoc:**
- Inline documentation using triple-slash comments (`///`) for public APIs
- Example from codebase: `/// Reconfigure from Keychain - called when switching accounts`
- Parameters documented: `func load(for key: KeychainKey) -> String?`

**MARK Comments Pattern:**
- Used extensively to organize code into logical sections
- Format: `// MARK: - SectionName` for primary sections
- Common sections: `- Setup / Teardown`, `- Tests`, `- Helpers`, `- Authentication`, `- API Methods`

## Function Design

**Size:**
- Most functions 20-40 lines
- API request methods: 10-30 lines with clear request setup
- Complex logic decomposed into private helper functions
- Example: `loadData()` method delegates to individual `load{Entity}()` functions

**Parameters:**
- Explicit parameter names required
- Default parameters used for optional configuration (e.g., `cornerRadius: CGFloat = 20`)
- OrderBy clarity: more important parameters first, defaults last
- Async methods use `async` keyword consistently

**Return Values:**
- Explicit return type annotations required
- Optionals used for fallible operations: `String?`, `[Website]?`
- Void return used when side effects sufficient (e.g., `func clearSelection()`)
- Published properties used instead of return values in ViewModels for UI updates

**Example Pattern:**
```swift
@MainActor
class WebsiteDetailViewModel: ObservableObject {
    func loadData(dateRange: DateRange) async {
        isLoading = true
        defer { isLoading = false }

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadStats(dateRange: dateRange) }
            // ...
        }
    }

    private func loadStats(dateRange: DateRange) async {
        guard let provider = AnalyticsManager.shared.currentProvider else { return }
        do {
            let stats = try await provider.getAnalyticsStats(websiteId: websiteId, dateRange: dateRange)
            self.stats = stats
        } catch {
            self.error = error.localizedDescription
        }
    }
}
```

## Module Design

**Exports:**
- Public structs/classes explicitly declared when needed
- Internal modifier used for implementation details
- Private used for helpers and internal state
- No barrel files (index.ts equivalent) detected

**Organization by Layer:**
- `Models/`: Data structures, enums, codable types
- `Services/`: API clients, managers, business logic (UmamiAPI, PlausibleAPI, AccountManager)
- `Views/`: SwiftUI components organized by feature subdirectory
- `Extensions/`: Convenience extensions on system types (View, Color)
- `App/`: Entry point and app-level configuration

**Concurrency Patterns:**
- `@MainActor` applied to ViewModels ensuring UI updates on main thread
- `actor` keyword used for API clients isolating state (UmamiAPI, PlausibleAPI)
- `Sendable` conformance required for types crossing actor boundaries
- `async/await` throughout for sequential operations

## Architecture Patterns

**State Management:**
- MVVM pattern: ViewModel owns @Published properties
- ViewModels decorated with `@MainActor` for thread safety
- Shared singleton managers (AccountManager, AnalyticsManager) use `static let shared`
- @EnvironmentObject used for passing managers through view hierarchy

**Dependency Injection:**
- Constructor injection in ViewModels (e.g., `init(websiteId: String, domain: String = "")`)
- Singleton pattern for services (AnalyticsManager, AccountManager)
- Protocol abstraction for multi-provider support (AnalyticsProvider protocol)

**Async Patterns:**
- `withTaskGroup` for concurrent data loads
- `Task.sleep(nanoseconds:)` for testing delays (not production polling)
- Error propagation via `throw` in functions, caught in ViewModels
- Deferred cleanup using `defer` blocks

---

*Convention analysis: 2026-03-28*
