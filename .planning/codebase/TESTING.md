# Testing Patterns

**Last updated:** 2026-04-04

## Test Framework

**Runner:**
- XCTest (Apple's native testing framework)
- Configuration: Xcode project setup (no separate config file)

**Assertion Library:**
- XCTest assertions (`XCTAssertEqual`, `XCTAssertTrue`, `XCTAssertNotNil`, `XCTAssertThrowsError`, `XCTAssertLessThanOrEqual`, `XCTSkipIf`)

**Run Commands:**
```bash
xcodebuild test -scheme InsightFlow -configuration Debug  # Run all tests
# Watch mode: Xcode Product -> Test (Cmd+U)
# Coverage: Enable "Code Coverage" in Test scheme settings -> Options tab
```

## Test File Organization

**Location:**
- Separate test target: `InsightFlowTests/` at project root
- Not co-located with source files

**Naming:**
- Test files: `{EntityOrFeature}Tests.swift`
- Test classes: `final class {Feature}Tests: XCTestCase` (or `class` for `@MainActor` tests)
- Test methods: `func test{Scenario}()` describing the scenario

**Structure:**
```
InsightFlowTests/
├── DateRangeTests.swift                 # DateRange model logic (10 tests)
├── AccountManagerTests.swift            # Multi-account CRUD + migration (11 tests)
├── UmamiAPIParsingTests.swift           # Umami JSON decoding (10 tests)
├── PlausibleAPIParsingTests.swift       # Plausible JSON decoding (10 tests)
├── KeychainServiceTests.swift           # Keychain CRUD + isolation (6 tests)
├── AnalyticsCacheServiceTests.swift     # File-based cache ops (14 tests)
├── DashboardViewModelTests.swift        # Dashboard clearFirst behavior (3 tests)
└── WebsiteDetailViewModelTests.swift    # Task cancellation stability (2 tests)
```

**Total: 8 test files, ~66 test methods.**

## Test Structure

**Suite Organization:**
```swift
final class DateRangeTests: XCTestCase {

    func testTodayStartBeforeOrEqualEnd() {
        let dates = DateRange.today.dates
        XCTAssertLessThanOrEqual(dates.start, dates.end)
    }

    func testTodayUnitIsHour() {
        XCTAssertEqual(DateRange.today.unit, "hour")
    }
}
```

**Patterns:**
- Arrange-Act-Assert (setup, execute, verify)
- Single logical assertion per test (multiple XCTAssert calls for related properties allowed)
- No shared mutable state between tests
- German assertion messages for domain-specific expectations: `"thisWeek muss am Montag beginnen (weekday=2)"`

**Setup/Teardown Pattern (for singleton-dependent tests):**
```swift
@MainActor
class AccountManagerTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        let manager = AccountManager.shared
        for account in manager.accounts {
            manager.removeAccount(account)
        }
        UserDefaults.standard.removeObject(forKey: "analytics_accounts")
        UserDefaults.standard.removeObject(forKey: "active_account_id")
    }

    override func tearDown() async throws {
        // Mirror setUp cleanup
        let manager = AccountManager.shared
        for account in manager.accounts {
            manager.removeAccount(account)
        }
        UserDefaults.standard.removeObject(forKey: "analytics_accounts")
        UserDefaults.standard.removeObject(forKey: "active_account_id")
        try await super.tearDown()
    }
}
```

**Key Points:**
- Async setUp/tearDown when testing @MainActor classes
- Reset shared state (UserDefaults, singleton managers) in BOTH setUp and tearDown
- `addTeardownBlock` used for Keychain cleanup specific to individual tests

## Mocking

**Framework:** None -- no external mocking library used.

**Approach:**
- Manual factory helper methods for test data creation
- No mock objects for API clients (tests do NOT test network calls)
- Protocol-based abstraction (`AnalyticsProvider`) enables mock injection but mocks are not yet implemented
- Constructor injection with override params for file system (`cacheDirectoryOverride:`)

**Factory Pattern:**
```swift
// In AccountManagerTests
private func makeTestAccount(
    name: String = "Test",
    serverURL: String = "https://test.example.com",
    providerType: AnalyticsProviderType = .umami
) -> AnalyticsAccount {
    AnalyticsAccount(
        name: name,
        serverURL: serverURL,
        providerType: providerType,
        credentials: AccountCredentials(token: "test-token", apiKey: nil)
    )
}

// In AnalyticsCacheServiceTests
private func makeCachedWebsite(id: String = "1", domain: String = "test.com") -> CachedWebsite {
    CachedWebsite(from: AnalyticsWebsite(
        id: id, name: "Test Site", domain: domain, shareId: nil, provider: .umami
    ))
}

// In DashboardViewModelTests
private func makeTestStats() -> WebsiteStats {
    WebsiteStats(
        pageviews: StatValue(value: 200, change: 20),
        visitors: StatValue(value: 100, change: 10),
        visits: StatValue(value: 150, change: 15),
        bounces: StatValue(value: 50, change: -5),
        totaltime: StatValue(value: 3000, change: 300)
    )
}
```

**What to Mock:**
- File system: Use temporary directories (`FileManager.default.temporaryDirectory`)
- Keychain: Conditional skip if unavailable (`XCTSkipIf`)

**What NOT to Mock:**
- Business logic: DateRange calculations tested directly
- Codable models: Real JSON decoding with literal JSON strings
- Computed properties: Test real implementations

## Fixtures and Factories

**Location:** Defined as `private` helper methods within test classes, under `// MARK: - Helpers`.

**No separate fixture files** -- all test data is inline or in factory functions.

**JSON fixtures for parsing tests** are inline multiline strings:
```swift
let json = """
{
    "pageviews": 200,
    "visitors": 100,
    "visits": 120,
    "bounces": 40,
    "totaltime": 3600,
    "comparison": { ... }
}
""".data(using: .utf8)!
```

## Coverage

**Requirements:** Not enforced -- no CI coverage gates.

**View Coverage:**
```bash
# In Xcode: Product -> Scheme -> Edit Scheme -> Test -> Options -> Code Coverage
```

## Test Types

**Unit Tests:**
- Scope: Single model/struct behavior
- Files: `DateRangeTests.swift`, `UmamiAPIParsingTests.swift`, `PlausibleAPIParsingTests.swift`
- Pattern: Pure function/computed property tests, JSON decoding validation

**Integration Tests:**
- Scope: Multiple components (manager + keychain, cache + file system)
- Files: `AccountManagerTests.swift`, `AnalyticsCacheServiceTests.swift`, `KeychainServiceTests.swift`
- Pattern: Real dependencies, verify data flow and persistence

**ViewModel Tests:**
- Scope: ViewModel state management and task lifecycle
- Files: `DashboardViewModelTests.swift`, `WebsiteDetailViewModelTests.swift`
- Pattern: Verify state transitions (`clearFirst` resets, cancellation behavior) without live API calls
- Limitation: Cannot fully test data loading without mock providers

**E2E / UI Tests:**
- Not implemented (no XCUITest target)

## Common Patterns

**Async Testing:**
```swift
func testMigrateFromLegacyCredentials_Umami() async throws {
    let manager = AccountManager.shared
    try KeychainService.save("https://umami.test.com", for: .serverURL)
    try KeychainService.save("umami", for: .providerType)
    try KeychainService.save("legacy-token-123", for: .token)

    manager.migrateFromLegacyCredentials()

    XCTAssertEqual(manager.accounts.count, 1)
    // setActiveAccount runs in a Task -- give it time to complete
    try await Task.sleep(nanoseconds: 100_000_000)
    XCTAssertNotNil(manager.activeAccount)
}
```

**Error Testing:**
```swift
func testInvalidJSONThrowsDecodingError() {
    let invalidData = "not valid json at all".data(using: .utf8)!
    XCTAssertThrowsError(
        try JSONDecoder().decode(WebsiteStatsResponse.self, from: invalidData)
    ) { error in
        XCTAssertTrue(error is DecodingError)
    }
}
```

**Keychain Testing (skip-if-unavailable):**
```swift
func testSaveAndLoadCredential() throws {
    try XCTSkipIf(
        { do {
            try KeychainService.saveCredential("probe", type: .token, accountId: "probe")
            KeychainService.deleteCredentials(for: "probe")
            return false
        } catch { return true } }(),
        "Keychain nicht verfuegbar (kein Entitlement im Simulator)"
    )
    try KeychainService.saveCredential(testToken, type: .token, accountId: testAccountId)
    let loaded = KeychainService.loadCredential(type: .token, accountId: testAccountId)
    XCTAssertEqual(loaded, testToken)
}
```

**File System Testing:**
```swift
var tempDir: URL!
var sut: AnalyticsCacheService!

override func setUp() {
    super.setUp()
    tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    sut = AnalyticsCacheService(cacheDirectoryOverride: tempDir)
}

override func tearDown() {
    try? FileManager.default.removeItem(at: tempDir)
    sut = nil
    tempDir = nil
    super.tearDown()
}
```

**Data Validation (floating point):**
```swift
func testStatValueChangePercentage() {
    // value=110, change=10 -> baseValue = 110 - 10 = 100 -> 10/100*100 = 10.0
    let stat = StatValue(value: 110, change: 10)
    XCTAssertEqual(stat.changePercentage, 10.0, accuracy: 0.001)
    XCTAssertTrue(stat.isPositiveChange)
}
```

**ViewModel State Transition Testing:**
```swift
func testLoadDataWithClearFirstResetsWebsites() async {
    let viewModel = DashboardViewModel()
    viewModel.websites = [makeTestWebsite()]

    let task = Task {
        await viewModel.loadData(dateRange: .today, clearFirst: true)
    }
    try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s

    XCTAssertTrue(viewModel.websites.isEmpty, "websites muss nach clearFirst leer sein")
    task.cancel()
}
```

## What Is Tested vs. Untested

**Well-tested areas:**
- JSON decoding for both Umami and Plausible API responses (`UmamiAPIParsingTests.swift`, `PlausibleAPIParsingTests.swift`)
- DateRange computation logic: all presets, units, custom ranges (`DateRangeTests.swift`)
- Account management: CRUD, deduplication, migration, keychain sync (`AccountManagerTests.swift`)
- Keychain service: save/load/delete, account scoping, isolation (`KeychainServiceTests.swift`)
- Cache service: save/load, expiry, stale cleanup, LRU eviction, per-account/per-website clearing (`AnalyticsCacheServiceTests.swift`)
- StatValue computed properties (change percentage, edge cases)

**Partially tested:**
- DashboardViewModel: only `clearFirst` state reset behavior, not full data loading
- WebsiteDetailViewModel: only task cancellation stability, not data population

**Not tested (gaps):**
- All SwiftUI Views (no snapshot or UI tests)
- `UmamiAPI` network requests (only JSON parsing is tested, not actual HTTP calls)
- `PlausibleAPI` network requests (same)
- `AnalyticsManager` provider switching logic
- `LoginViewModel` login flows
- `ReportsViewModel` report loading
- `EventsViewModel` event loading
- `CompareViewModel` comparison logic
- Widget extension code (`InsightFlowWidget/`)
- `NotificationManager` background refresh
- `DashboardSettingsManager` persistence
- `SharedCredentials` cross-target sharing
- `SupportManager` tip jar / StoreKit

---

*Testing analysis: 2026-04-04*
