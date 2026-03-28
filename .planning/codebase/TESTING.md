# Testing Patterns

**Analysis Date:** 2026-03-28

## Test Framework

**Runner:**
- XCTest (Apple's native testing framework)
- Configuration: Xcode project setup (no separate config file)

**Assertion Library:**
- XCTest assertions (XCTAssertEqual, XCTAssertTrue, XCTAssertNotNil, XCTAssertThrowsError)

**Run Commands:**
```bash
xcodebuild test -scheme InsightFlow -configuration Debug
# Watch mode via Xcode: Product → Test
# Coverage: Enable "Code Coverage" in Test scheme settings
```

## Test File Organization

**Location:**
- Co-located in separate test target: `/Users/simonluthe/Documents/umami/InsightFlowTests/`
- Separated from main source (`InsightFlow/`) at project structure level
- Not embedded in source files

**Naming:**
- Test files: `{EntityOrFeature}Tests.swift` (e.g., `DateRangeTests.swift`, `AccountManagerTests.swift`)
- Test classes: `final class {Feature}Tests: XCTestCase`
- Test methods: `func test{Scenario}()` describing the scenario being tested

**Structure:**
```
InsightFlowTests/
├── DateRangeTests.swift
├── AccountManagerTests.swift
├── UmamiAPIParsingTests.swift
├── PlausibleAPIParsingTests.swift
├── KeychainServiceTests.swift
└── AnalyticsCacheServiceTests.swift
```

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

    // More test methods grouped by feature
}
```

**Patterns:**
- Single responsibility per test method (test one assertion or related assertions)
- Arrange-Act-Assert pattern (setup, execute, verify)
- Clear method names describing the test scenario
- No shared state between tests

**Setup/Teardown Pattern:**

```swift
override func setUp() async throws {
    try await super.setUp()
    let manager = AccountManager.shared
    for account in manager.accounts {
        manager.removeAccount(account)
    }
    UserDefaults.standard.removeObject(forKey: "analytics_accounts")
}

override func tearDown() async throws {
    let manager = AccountManager.shared
    for account in manager.accounts {
        manager.removeAccount(account)
    }
    UserDefaults.standard.removeObject(forKey: "analytics_accounts")
    try await super.tearDown()
}
```

**Key Points:**
- `async` tearDown for cleaning up async state
- Reset shared state (UserDefaults, singleton managers) in both setUp and tearDown
- Explicit cleanup of Keychain credentials using `KeychainService.deleteCredentials(for:)`

## Mocking

**Framework:**
- No external mocking library (Mockito, etc.)
- Manual test data creation using factory helper methods
- Protocol-based abstraction for injectable dependencies

**Patterns:**

```swift
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
```

**Factory Pattern Usage:**
- Centralized factory functions in test classes
- Parameterized with sensible defaults
- Used to create consistent test data across multiple tests

**What to Mock:**
- External dependencies: Network calls wrapped in protocol-based API clients
- File system: Use temporary directories (`FileManager.default.temporaryDirectory`)
- Time: Fixed date values in tests (no `Date()` calls expecting current time)
- Keychain: Conditional skip if unavailable (`XCTSkipIf`)

**What NOT to Mock:**
- Business logic: DateRange calculations tested directly
- Codable models: Real JSON decoding tested with actual JSON strings
- Validators and formatters: Test with real values
- Simple computed properties: Test real implementations

## Fixtures and Factories

**Test Data Creation:**

```swift
private func makeCachedWebsite(id: String = "1", domain: String = "test.com") -> CachedWebsite {
    CachedWebsite(from: AnalyticsWebsite(
        id: id,
        name: "Test Site",
        domain: domain,
        shareId: nil,
        provider: .umami
    ))
}

private func makeCachedStats(visitors: Int = 100) -> CachedStats {
    CachedStats(from: AnalyticsStats(
        visitors: StatValue(value: visitors, change: 10),
        pageviews: StatValue(value: 200, change: 20),
        visits: StatValue(value: 150, change: 15),
        bounces: StatValue(value: 50, change: -5),
        totaltime: StatValue(value: 3000, change: 300)
    ))
}
```

**Location:**
- Defined as private helper methods within test classes
- Grouped under `// MARK: - Helpers` section
- No separate fixture files

**Approach:**
- Parameterized with most common values as defaults
- Each parameter customizable for specific test scenarios
- Reused across multiple test methods

## JSON Decoding Tests

**Pattern:**

```swift
func testWebsiteResponseDecoding() throws {
    let json = """
    {
        "data": [
            {
                "id": "abc123",
                "name": "Test Website",
                "domain": "test.com"
            }
        ],
        "count": 1
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let response = try decoder.decode(WebsiteResponse.self, from: json)

    XCTAssertEqual(response.websites.count, 1)
    XCTAssertEqual(response.websites[0].id, "abc123")
}
```

**Key Points:**
- Literal JSON strings for readability and maintainability
- Test both valid and invalid inputs
- Configure decoder with required strategies (date formats, key mappings)
- Test transformation logic (e.g., `WebsiteStats` computed fields)

**Coverage:**
- Valid/happy path decoding
- Edge cases: empty arrays, null values, missing optional fields
- Error cases: invalid JSON, missing required fields

## Coverage

**Requirements:**
- Not enforced in CI/build
- Pragmatic approach: test public APIs, critical logic, error paths
- Coverage reporting available but not mandatory

**View Coverage:**
```bash
# In Xcode: Product → Scheme → Edit Scheme → Test → Code Coverage → Enable
# Results visible in Xcode Report Navigator
```

## Test Types

**Unit Tests:**
- **Scope:** Single class or function in isolation
- **Approach:** Test behavior, not implementation
- Examples: `DateRangeTests`, `StatValueTests` for computed fields
- Files: `{Entity}Tests.swift`

**Integration Tests:**
- **Scope:** Multiple components working together
- **Approach:** Test interactions between layers
- Examples: `AccountManagerTests` (Manager + Keychain), `AnalyticsCacheServiceTests` (Cache + FileSystem)
- Characteristics: Set up real dependencies, verify data flow between components

**API Parsing Tests:**
- **Scope:** JSON decoding and transformation
- **Approach:** Test with real JSON payloads
- Examples: `UmamiAPIParsingTests.swift`, `PlausibleAPIParsingTests.swift`
- Pattern: Inline JSON, decode, verify structure and computed properties

**E2E Tests:**
- **Status:** Not detected in codebase
- **Would test:** Full user flows (login → fetch data → display → navigate)
- **Current gap:** No UI automation tests (would use XCUITest if added)

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
    // setActiveAccount runs in a Task — give it time to complete
    try await Task.sleep(nanoseconds: 100_000_000)
    XCTAssertNotNil(manager.activeAccount)
}
```

**Key Points:**
- Mark test method as `async throws`
- Call `await super.setUp()` and `tearDown()` when using async setup
- Use `Task.sleep(nanoseconds:)` for waiting on background operations
- Comment explaining why delays are necessary

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

**Pattern:**
- `XCTAssertThrowsError` for expected exceptions
- Optional closure to verify error type or properties
- Test both that error occurs AND error type is correct

**Keychain Testing:**

```swift
func testSaveAndLoadCredential() throws {
    let testToken = "test-token-123"
    try XCTSkipIf(
        { do { try KeychainService.saveCredential("probe", type: .token, accountId: "probe"); KeychainService.deleteCredentials(for: "probe"); return false } catch { return true } }(),
        "Keychain nicht verfuegbar (kein Entitlement im Simulator)"
    )
    try KeychainService.saveCredential(testToken, type: .token, accountId: testAccountId)
    let loaded = KeychainService.loadCredential(type: .token, accountId: testAccountId)
    XCTAssertEqual(loaded, testToken)
}
```

**Pattern:**
- Skip tests if Keychain unavailable (common in CI/simulator without entitlements)
- Use `XCTSkipIf` with availability probe
- Clean up in tearDown using both `deleteCredentials` and `deleteAll()`
- Test account scoping isolation: credentials saved for one account don't leak to another

**File System Testing:**

```swift
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

**Pattern:**
- Use temporary directories for isolation
- Create unique paths using UUID to avoid conflicts
- Pass override parameter to class under test
- Clean up in tearDown using try? (ignore errors)

## Data Validation Tests

**Pattern:**

```swift
func testStatValueChangePercentage() {
    // value=110, change=10 -> baseValue = 110 - 10 = 100 -> 10/100*100 = 10.0
    let stat = StatValue(value: 110, change: 10)
    XCTAssertEqual(stat.changePercentage, 10.0, accuracy: 0.001)
    XCTAssertTrue(stat.isPositiveChange)
}

func testStatValueChangePercentageZeroBase() {
    // value - change == 0 -> guard returns 0
    let stat = StatValue(value: 10, change: 10)
    XCTAssertEqual(stat.changePercentage, 0.0, accuracy: 0.001)
}
```

**Key Points:**
- Test edge cases: zero values, negative changes, division by zero
- Document calculations in comments showing expected values
- Use `accuracy:` parameter for floating-point comparisons
- Test both normal and boundary conditions

## Best Practices Observed

1. **Clear Test Names:** Test method names describe scenario and expected behavior
2. **One Assertion Focus:** Each test verifies one logical behavior (though multiple assertions allowed for related checks)
3. **Setup/Teardown Symmetry:** Every setup in setUp() has corresponding cleanup in tearDown()
4. **No Test Interdependence:** Tests run in any order, clean up after themselves
5. **Meaningful Error Messages:** German comments in test names and setup when relevant to domain
6. **Skip Unavailable Tests:** Gracefully skip tests requiring unavailable resources (Keychain, simulator entitlements)
7. **Factory Pattern:** Test data created via helper functions with sensible defaults
8. **Real Data in Tests:** Use actual JSON payloads and real decoder configurations, not mocks

---

*Testing analysis: 2026-03-28*
