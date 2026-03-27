# Testing Patterns

**Analysis Date:** 2026-03-27

## Test Infrastructure

**Test Targets:**
- No test targets exist in the Xcode project (`InsightFlow.xcodeproj`)
- No `XCTest` imports found anywhere in the codebase
- No test files (`*Test*.swift`, `*Spec*.swift`) detected
- No UI test target configured

**Testing Frameworks:**
- None configured. No XCTest, Quick, Nimble, or any third-party testing framework is in use.
- No `Package.swift` or SPM test dependencies
- No third-party dependencies at all -- the project uses only Apple frameworks

**Test Coverage:**
- 0% -- no automated tests of any kind exist

**Run Commands:**
```bash
# No test commands available
# Standard Xcode test command would be:
xcodebuild test -scheme InsightFlow -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Test Types

**Unit Tests:**
- Absent. No unit tests exist for any component.

**UI Tests:**
- Absent. No UI test target or UI test files exist.

**Integration Tests:**
- Absent. No integration tests for API communication.

**Snapshot Tests:**
- Absent. No snapshot testing framework configured.

## Preview-Based Testing

The only form of "testing" is SwiftUI `#Preview` macros:
- `ContentView.swift` has a `#Preview` block (line 39)
- No other preview declarations found in the codebase

## Gaps

**Critical areas lacking test coverage:**

1. **API Layer** (`UmamiAPI.swift`, `PlausibleAPI.swift`)
   - No tests for request construction, response parsing, or error handling
   - The `AnalyticsProvider` protocol would be straightforward to mock
   - JSON decoding with custom date strategies in `UmamiAPI.swift` is particularly fragile without tests

2. **Authentication Flow** (`AuthManager.swift`, `KeychainService.swift`)
   - Login, logout, credential persistence, multi-account switching untested
   - Keychain operations have no test coverage

3. **Data Models** (`Stats.swift`, `Website.swift`, `DateRange.swift`)
   - `DateRange.dates` computed property with complex calendar logic (lines 71-134) has no tests
   - `StatValue.changePercentage` division logic untested
   - `WebsiteStats` initializers untested

4. **Account Management** (`AccountManager.swift`)
   - Multi-account add/remove/switch logic untested
   - Migration from legacy credentials untested
   - Widget sync logic untested

5. **Dashboard Settings** (`DashboardSettingsManager.swift`)
   - Metric toggle logic (preventing last metric disable) untested
   - UserDefaults persistence untested

6. **Caching** (`AnalyticsCacheService.swift`)
   - Cache read/write/expiry logic untested

7. **Notifications** (`NotificationManager.swift`)
   - Scheduled notification logic untested
   - Background task handling untested

## Recommended Testing Improvements

**Priority 1 -- Add unit test target and test data models:**
1. Create `InsightFlowTests` test target in Xcode
2. Test `DateRange.dates` for all presets -- this has the most complex logic and highest breakage risk
3. Test `StatValue.changePercentage` edge cases (division by zero)
4. Test `WebsiteStats` initializers and computed properties (`bounceRate`, `averageTime`)

**Priority 2 -- Test API response parsing:**
1. Create mock JSON fixtures for Umami and Plausible API responses
2. Test `JSONDecoder` configuration in `UmamiAPI` (custom date decoding)
3. Test `AnalyticsProvider` protocol conformance of both implementations
4. Test error mapping (`APIError`, `PlausibleError`)

**Priority 3 -- Test manager logic:**
1. Test `AccountManager` add/remove/switch/migrate flows
2. Test `DashboardSettingsManager` toggle and persistence logic
3. Test `KeychainService` save/load/delete operations
4. Mock `URLSession` for API integration tests

**Priority 4 -- Add UI tests:**
1. Test login flow for both Umami and Plausible
2. Test account switching
3. Test dashboard navigation to website detail

**Testability Notes:**
- The singleton pattern (`static let shared`) used throughout makes dependency injection difficult. Consider adding protocol-based injection for testability.
- The `actor` type for `UmamiAPI`/`PlausibleAPI` supports the `AnalyticsProvider` protocol, which is a good seam for mocking.
- ViewModels directly reference singletons (`UmamiAPI.shared`, `PlausibleAPI.shared`) instead of accepting injected dependencies, making view model testing harder.

---

*Testing analysis: 2026-03-27*
