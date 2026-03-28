# Phase 5: Tests - Research

**Researched:** 2026-03-27
**Domain:** XCTest / Swift Concurrency Testing / Xcode Test Target Setup
**Confidence:** HIGH

## Summary

Phase 5 fuegt dem Projekt ein neues XCTest-Target hinzu und implementiert Unit Tests fuer die fuenf kritischen Dienste: KeychainService, AccountManager, UmamiAPI- und PlausibleAPI-Response-Parsing sowie DateRange-Berechnungen und AnalyticsCacheService.

Das Projekt hat bisher keine Tests. Das Test-Target muss manuell in project.pbxproj angelegt werden — der PBXFileSystemSynchronizedRootGroup-Mechanismus des Projekts bedeutet, dass Swift-Testdateien nach dem Anlegen des Targets automatisch entdeckt werden, sobald sie in das korrekte Verzeichnis geschrieben werden. Das Hauptrisiko ist die korrekte pbxproj-Bearbeitung fuer das neue Target.

Alle fuenf Test-Bereiche sind technisch gut abgrenzbar: KeychainService ist ein statisches Enum, AccountManager ist @MainActor-gebunden und nutzt UserDefaults, die API-Clients sind Swift actors, DateRange ist pure Logik, und AnalyticsCacheService schreibt in eine App Group (erfordert temporaeres Verzeichnis im Test).

**Primary recommendation:** Test-Target `InsightFlowTests` in project.pbxproj anlegen, dann fuenf Test-Klassen erstellen die jeweils einen Dienst isoliert testen — mit Teardown fuer Keychain und UserDefaults.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Kein Test-Target existiert — muss in Xcode-Projekt angelegt werden (InsightFlowTests)
- XCTest als Framework (keine externen Dependencies)
- Phase 1-4 haben KeychainService, AccountManager, API-Clients, DateRange und Cache modifiziert
- KeychainService hat jetzt account-scoped Methoden (saveCredential, loadCredential, deleteCredentials)
- AccountManager ist jetzt einzige Auth-Autorität (AuthManager entfernt in Phase 4)
- PlausibleAPI ist jetzt ein actor (Phase 4), UmamiAPI war schon actor
- AnalyticsProvider-Protokoll hat Default-Implementierungen fuer Plausible-Luecken
- AnalyticsCacheService ist @unchecked Sendable — Tests sollten Thread-Safety pruefen
- Widget-Code (WidgetNetworking, WidgetStorage) koennte auch Tests bekommen, ist aber nicht im Scope

### Claude's Discretion
All implementation choices are at Claude's discretion — pure test implementation phase.

### Deferred Ideas (OUT OF SCOPE)
None — infrastructure phase.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TEST-01 | Unit Tests fuer KeychainService, AccountManager, API-Response-Parsing, DateRange, Cache | Alle fuenf Test-Bereiche sind isolierbar; konkrete Teststrategien pro Dienst unten dokumentiert |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| XCTest | Built-in (Xcode 16+) | Test-Framework | Apple-Standard fuer Swift/iOS, keine externen Dependencies noetig |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Foundation | Built-in | UserDefaults, FileManager, URL | Benoetigt fuer Cache- und AccountManager-Tests |
| Security | Built-in | SecItemAdd/Delete/Copy | Benoetigt fuer echte Keychain-Tests im Simulator |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| XCTest | Swift Testing (swift-testing) | Swift Testing ist moderner, aber XCTest ist fuer diesen Scope ausreichend und benoetigt keine Projekt-Aenderungen ausser dem Target |

**Installation:** Kein `npm install` — reines Xcode-Projekt. Test-Target wird in project.pbxproj angelegt.

## Architecture Patterns

### Recommended Project Structure
```
InsightFlowTests/
├── KeychainServiceTests.swift      # save/load/delete + account-scoped
├── AccountManagerTests.swift       # CRUD, Migration, Credential-Anwendung
├── UmamiAPIParsingTests.swift      # JSON-Decoding mit Mock-Daten
├── PlausibleAPIParsingTests.swift  # JSON-Decoding mit Mock-Daten
├── DateRangeTests.swift            # Preset-Berechnungen, Custom, unit-Logik
└── AnalyticsCacheServiceTests.swift # save/load, TTL-Expiry
```

### Pattern 1: Test-Target als PBXNativeTarget in project.pbxproj

**Was:** Manuelles Hinzufuegen eines `com.apple.product-type.unit-test-bundle`-Targets.
**Wann verwenden:** Immer wenn kein Test-Target existiert und keines ueber Xcode-UI angelegt werden kann (CLI-Workflow).

Das neue Target braucht in project.pbxproj:
1. `PBXNativeTarget`-Eintrag mit `productType = "com.apple.product-type.unit-test-bundle"`
2. `PBXFileSystemSynchronizedRootGroup` fuer das `InsightFlowTests/`-Verzeichnis
3. `PBXBuildFile` + `XCTest.framework` als Dependency
4. `PBXTargetDependency` auf das `InsightFlow`-Target
5. `XCBuildConfiguration` (Debug + Release) mit:
   - `BUNDLE_LOADER = "$(TEST_HOST)"`
   - `TEST_HOST = "$(BUILT_PRODUCTS_DIR)/InsightFlow.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/InsightFlow"`
   - `PRODUCT_BUNDLE_IDENTIFIER = de.godsapp.PrivacyFlow.InsightFlowTests`
   - `SWIFT_VERSION = 6.0`
   - `IPHONEOS_DEPLOYMENT_TARGET = 18.0`
   - `DEVELOPMENT_TEAM = J459G9CJT5`
6. Eintrag in der `targets`-Liste des `PBXProject`

**Wichtig:** `BUNDLE_LOADER` und `TEST_HOST` erlauben dem Test-Bundle, den App-Code direkt zu importieren (`@testable import InsightFlow`). Ohne diese Einstellung laesst sich `InsightFlow` im Test-Bundle nicht importieren.

### Pattern 2: @MainActor Tests fuer AccountManager

**Was:** AccountManager ist `@MainActor`-deklariert. Tests muessen entweder `await MainActor.run { }` oder `@MainActor` auf der Testmethode verwenden.
**Wann verwenden:** Fuer alle AccountManager-Tests.

```swift
// Source: Apple XCTest + Swift Concurrency Dokumentation
@MainActor
func testAddAccount() async throws {
    let sut = AccountManager.shared
    // Test-Setup: UserDefaults fuer Tests leeren
    UserDefaults.standard.removeObject(forKey: "analytics_accounts")
    // ...
}
```

**Achtung:** AccountManager hat einen `private init()`. Tests muessen `AccountManager.shared` verwenden — kein separates Testexemplar moeglich ohne Refactoring. Testtrennnung erfolgt ueber explizites Bereinigen von UserDefaults und Keychain im `tearDown`.

### Pattern 3: actor-Tests mit await

**Was:** UmamiAPI und PlausibleAPI sind Swift `actor`. Auf actor-Methoden muss mit `await` zugegriffen werden.
**Wann verwenden:** Fuer alle API-Parsing-Tests.

Fuer Parsing-Tests gehen wir nicht ueber die echten actor-Methoden (die Netzwerk benoetigen), sondern testen die JSON-Decodierung direkt auf den privaten Response-Typen. Da diese privat sind, muessen die Tests entweder:
- a) `@testable import InsightFlow` nutzen und die privaten Typen intern testen, ODER
- b) Oeffentliche AnalyticsProvider-Methoden mit Mock-URLSession aufrufen

Empfehlung: Option (b) ist robuster. URLSession kann fuer Tests durch `URLProtocol`-Subklasse oder `URLSession(configuration:)` mit einem Mock-Protocol ersetzt werden.

```swift
// Mock URLProtocol fuer API-Tests
class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else { return }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}
```

### Pattern 4: AnalyticsCacheService mit temporaerem Verzeichnis

**Was:** AnalyticsCacheService verwendet `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)`. Im Test-Kontext (kein App-Group-Entitlement im Test-Bundle) gibt diese `nil` zurueck. Der Cache-Service prueft auf `nil` und tut nichts — Tests fuer save/load wuerden dann stumm fehlschlagen.

**Loesung:** Die private `cacheDirectory`-Property kann nicht injiziert werden ohne Refactoring. Optionen:
- a) Test im Simulator ausfuehren mit App-Group-Entitlement fuer Tests (aufwaendig)
- b) AnalyticsCacheService leicht refactorn: `cacheDirectory` als injizierbare Dependency (`init(cacheDirectory: URL? = nil)`) — aber `private init()` muss zu `init(cacheDirectory: URL? = nil)` werden
- c) Tests nutzen `FileManager.default.temporaryDirectory` und testen die interne save/load-Logik durch temporaere Dateien direkt (Whitebox-Test ohne App-Group)

Empfehlung: Option (b) — minimales Refactoring von `AnalyticsCacheService`, neuer `internal init(cacheDirectory: URL)` neben dem bestehenden `private init()`. Tests erstellen eine temporaere URL.

```swift
// In AnalyticsCacheService:
private let overrideCacheDirectory: URL?

init() {
    self.overrideCacheDirectory = nil
}

// Fuer Tests:
init(cacheDirectoryOverride: URL) {
    self.overrideCacheDirectory = cacheDirectoryOverride
}

private var cacheDirectory: URL? {
    if let override = overrideCacheDirectory { return override }
    // ... bestehende App-Group-Logik
}
```

### Anti-Patterns to Avoid

- **Singleton-State nicht bereinigen:** AccountManager.shared, KeychainService und AnalyticsCacheService halten State. Tests MUESSEN in `setUp()`/`tearDown()` den State zuruecksetzen, sonst beeinflussen sich Tests gegenseitig.
- **Netzwerk in Unit-Tests:** API-Tests duerfen nie echte Netzwerkanfragen machen. Immer MockURLProtocol oder statische JSON-Daten verwenden.
- **@testable import vergessen:** Ohne `@testable import InsightFlow` sind interne Typen nicht sichtbar. Das Test-Target muss `BUNDLE_LOADER`/`TEST_HOST` korrekt gesetzt haben.
- **Swift 6 Concurrency-Fehler ignorieren:** Swift 6 (`SWIFT_VERSION = 6.0`) ist streng bei Sendability. Tests, die actor-Typen falsch aufrufen, werden nicht kompilieren. Alle actor-Calls muessen `await`ed sein.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTTP-Mock fuer API-Tests | Eigenes Fake-Server-System | `URLProtocol`-Subklasse (eingebaut) | URLProtocol ist der Apple-Standard-Mechanismus fuer URLSession-Mocking |
| Test-Daten generieren | Komplexe Factories | Inline-JSON-Strings als `Data` | Response-Parsing-Tests brauchen nur statische JSON-Strings |
| Async-Test-Infrastruktur | Eigene Semaphore/DispatchGroup | `async throws` Test-Methoden (XCTest 12+) | Native async/await Tests werden direkt von XCTest unterstuetzt |

**Key insight:** XCTest unterstuetzt `async throws` Testmethoden nativ seit iOS 15 / Xcode 13. Kein XCTestExpectation fuer async-Code noetig.

## Common Pitfalls

### Pitfall 1: BUNDLE_LOADER nicht gesetzt
**What goes wrong:** `@testable import InsightFlow` schlaegt mit "No such module" fehl.
**Why it happens:** Ohne BUNDLE_LOADER/TEST_HOST ladet das Test-Bundle den App-Code nicht.
**How to avoid:** In den Test-Target-Build-Settings `BUNDLE_LOADER = "$(TEST_HOST)"` und `TEST_HOST = "$(BUILT_PRODUCTS_DIR)/InsightFlow.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/InsightFlow"` setzen.
**Warning signs:** Build-Fehler "No such module 'InsightFlow'" beim Kompilieren der Tests.

### Pitfall 2: AccountManager Singleton-State zwischen Tests
**What goes wrong:** Tests beeinflussen sich gegenseitig, da AccountManager.shared persistent ist.
**Why it happens:** AccountManager laedt beim Init aus UserDefaults. State aus Test A bleibt fuer Test B sichtbar.
**How to avoid:** In `tearDown()` UserDefaults-Keys leeren: `UserDefaults.standard.removeObject(forKey: "analytics_accounts")` und `UserDefaults.standard.removeObject(forKey: "active_account_id")`. Zusaetzlich Keychain-Items loeschen.
**Warning signs:** Tests schlagen nicht-deterministisch fehl, je nach Ausfuehrungsreihenfolge.

### Pitfall 3: Keychain-Tests auf macOS-Simulator
**What goes wrong:** Keychain-Operationen koennen im Simulator mit `-34018 (errSecMissingEntitlement)` fehlschlagen.
**Why it happens:** Test-Bundles haben kein Keychain-Sharing-Entitlement.
**How to avoid:** In den Test-Target-Entitlements `keychain-access-groups` hinzufuegen. Alternativ: Tests so schreiben, dass sie Keychain-Fehler graceful behandeln und nur testen ob der Wert zurueckgelesen werden kann (round-trip).
**Warning signs:** `KeychainError.saveFailed(-34018)` in Tests.

### Pitfall 4: AnalyticsCacheService gibt nil zurueck ohne App-Group
**What goes wrong:** `cacheDirectory` ist `nil` im Test, alle save/load-Operationen sind No-Ops.
**Why it happens:** `containerURL(forSecurityApplicationGroupIdentifier:)` gibt im Test-Bundle `nil` zurueck.
**How to avoid:** Minimales Refactoring: `init(cacheDirectoryOverride:)` hinzufuegen (siehe Architecture Pattern 4).
**Warning signs:** Tests schlagen nicht fehl, aber Assertions pruefen `nil`-Ergebnis statt tatsaechliche Daten.

### Pitfall 5: DateRange.dates ist time-sensitiv
**What goes wrong:** Tests fuer `.today`, `.thisWeek` etc. schlagen fehl weil das Datum sich aendert.
**Why it happens:** `DateRange.dates` ruft intern `Date()` auf — Ergebnis haengt vom aktuellen Zeitpunkt ab.
**How to avoid:** Keine exakten Datumswerte pruefen, stattdessen Invarianten: `start <= end`, Differenz in erwarteten Grenzen, `.today` ergibt Differenz < 1 Tag etc.

### Pitfall 6: Swift 6 Concurrency in Tests
**What goes wrong:** Compiler-Fehler "Sending 'x' risks causing data races" bei actor-Zugriffen in Tests.
**Why it happens:** Swift 6 erfordert explizite Isolation.
**How to avoid:** Test-Klassen die auf actors zugreifen als `@MainActor` markieren oder Methoden als `async` deklarieren. Bei actor-Tests direkt `await actor.method()` verwenden.

## Code Examples

Verified patterns aus Apple XCTest Dokumentation und Swift Concurrency:

### KeychainService Round-Trip Test
```swift
// @testable import InsightFlow noetig
import XCTest
@testable import InsightFlow

final class KeychainServiceTests: XCTestCase {
    let testAccountId = "test-account-\(UUID().uuidString)"

    override func tearDown() {
        super.tearDown()
        KeychainService.deleteCredentials(for: testAccountId)
        KeychainService.deleteAll()
    }

    func testSaveAndLoadCredential() throws {
        let testToken = "test-token-123"
        try KeychainService.saveCredential(testToken, type: .token, accountId: testAccountId)
        let loaded = KeychainService.loadCredential(type: .token, accountId: testAccountId)
        XCTAssertEqual(loaded, testToken)
    }

    func testDeleteCredentials() throws {
        try KeychainService.saveCredential("token", type: .token, accountId: testAccountId)
        KeychainService.deleteCredentials(for: testAccountId)
        let loaded = KeychainService.loadCredential(type: .token, accountId: testAccountId)
        XCTAssertNil(loaded)
    }

    func testAccountScopingIsolation() throws {
        let idA = "account-A"
        let idB = "account-B"
        defer {
            KeychainService.deleteCredentials(for: idA)
            KeychainService.deleteCredentials(for: idB)
        }
        try KeychainService.saveCredential("tokenA", type: .token, accountId: idA)
        let loadedFromB = KeychainService.loadCredential(type: .token, accountId: idB)
        XCTAssertNil(loadedFromB, "Account B sollte Token von Account A nicht sehen")
    }
}
```

### DateRange Invarianten-Test
```swift
final class DateRangeTests: XCTestCase {
    func testTodayStartBeforeEnd() {
        let range = DateRange.today
        let dates = range.dates
        XCTAssertLessThanOrEqual(dates.start, dates.end)
    }

    func testLast7DaysSpan() {
        let range = DateRange.last7Days
        let dates = range.dates
        let diff = Calendar.current.dateComponents([.day], from: dates.start, to: dates.end).day ?? 0
        XCTAssertEqual(diff, 6, "Last 7 days sollte 6 Tage Differenz haben (heute - 6)")
    }

    func testCustomRange() {
        let start = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        let end = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 31))!
        let range = DateRange.custom(start: start, end: end)
        XCTAssertEqual(range.dates.start, start)
        XCTAssertEqual(range.dates.end, end)
    }

    func testUnitForShortRange() {
        let range = DateRange.today
        XCTAssertEqual(range.unit, "hour")
    }

    func testUnitForMediumRange() {
        let range = DateRange.last30Days
        XCTAssertEqual(range.unit, "day")
    }
}
```

### API-Parsing-Test mit statischen Daten (UmamiAPI)
```swift
// Testet JSON-Decoding direkt ohne Netzwerk
// UmamiAPI's interne Response-Typen sind @testable zugaenglich

func testUmamiStatsDecoding() throws {
    let json = """
    {
        "visitors": {"value": 100, "change": 10},
        "pageviews": {"value": 200, "change": 20},
        "visits": {"value": 150, "change": 15},
        "bounces": {"value": 50, "change": -5},
        "totaltime": {"value": 3000, "change": 300}
    }
    """.data(using: .utf8)!

    // UmamiStatsResponse ist intern — @testable import macht ihn zugaenglich
    let response = try JSONDecoder().decode(UmamiStatsResponse.self, from: json)
    XCTAssertEqual(response.visitors.value, 100)
    XCTAssertEqual(response.visitors.change, 10)
}
```

### AnalyticsCacheService mit temporaerem Verzeichnis
```swift
// Nach dem Refactoring (init mit cacheDirectoryOverride)
final class AnalyticsCacheServiceTests: XCTestCase {
    var tempDir: URL!
    var sut: AnalyticsCacheService!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        sut = AnalyticsCacheService(cacheDirectoryOverride: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testSaveAndLoadWebsites() {
        let website = CachedWebsite(from: AnalyticsWebsite(id: "1", name: "Test", domain: "test.com", shareId: nil, provider: .umami))
        sut.saveWebsites([website], accountId: "acc-1")
        let result = sut.loadWebsites(accountId: "acc-1")
        XCTAssertNotNil(result)
        XCTAssertFalse(result!.isExpired)
        XCTAssertEqual(result!.data.count, 1)
        XCTAssertEqual(result!.data[0].domain, "test.com")
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| XCTestExpectation fuer async | `async throws` Testmethoden | Xcode 13 / iOS 15 | Kein Boilerplate fuer async Tests mehr |
| Objc-Runtime Swizzling fuer Mocks | URLProtocol / Protocol-basiertes Mocking | Swift era | Typ-sicher, Swift-kompatibel |

**Deprecated/outdated:**
- `XCTestExpectation` fuer einfache async Calls: Wird ersetzt durch `async throws` Testmethoden. XCTestExpectation bleibt noetig nur fuer Callback-basierte APIs.

## Open Questions

1. **UmamiAPI interne Response-Typen als @testable sichtbar?**
   - What we know: `@testable import InsightFlow` macht alle `internal` Typen zugaenglich
   - What's unclear: `UmamiStatsResponse` und aequivalente Plausible-Typen muessen `internal` sein (nicht `private`)
   - Recommendation: Vor dem Test-Schreiben pruefen ob die Response-Structs `private struct` oder `internal struct` sind. Falls `private`: Option (b) mit MockURLProtocol verwenden.

2. **Keychain-Entitlement fuer Test-Target**
   - What we know: Test-Bundle braucht Keychain-Access-Group im Entitlements-File
   - What's unclear: Ob der Simulator ohne Entitlement trotzdem Keychain-Operationen erlaubt (oft tut er das im Debug-Build)
   - Recommendation: Tests ohne Entitlement versuchen; falls `-34018` auftritt, ein `InsightFlowTests.entitlements`-File anlegen mit der gleichen Keychain-Group wie die App (`de.godsapp.PrivacyFlow`).

## Environment Availability

Step 2.6: SKIPPED (keine externen Dependencies — reines XCTest/Xcode-Projekt ohne Drittanbieter-Tools)

## Validation Architecture

> `nyquist_validation` ist nicht in config.json gesetzt — wird als aktiviert behandelt.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (built-in, Xcode 16) |
| Config file | Kein separates config file — Target in project.pbxproj |
| Quick run command | `xcodebuild test -project InsightFlow.xcodeproj -scheme InsightFlow -destination 'platform=iOS Simulator,name=iPhone 16'` |
| Full suite command | Identisch — alle Unit Tests laufen in einem Durchgang |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TEST-01 | KeychainService save/load/delete + account-scoping | unit | `xcodebuild test ... -only-testing:InsightFlowTests/KeychainServiceTests` | Nein — Wave 0 |
| TEST-01 | AccountManager CRUD, Migration, Credential-Anwendung | unit | `xcodebuild test ... -only-testing:InsightFlowTests/AccountManagerTests` | Nein — Wave 0 |
| TEST-01 | UmamiAPI JSON-Response-Parsing | unit | `xcodebuild test ... -only-testing:InsightFlowTests/UmamiAPIParsingTests` | Nein — Wave 0 |
| TEST-01 | PlausibleAPI JSON-Response-Parsing | unit | `xcodebuild test ... -only-testing:InsightFlowTests/PlausibleAPIParsingTests` | Nein — Wave 0 |
| TEST-01 | DateRange Presets, Custom, unit-Logik | unit | `xcodebuild test ... -only-testing:InsightFlowTests/DateRangeTests` | Nein — Wave 0 |
| TEST-01 | AnalyticsCacheService save/load, TTL-Expiry | unit | `xcodebuild test ... -only-testing:InsightFlowTests/AnalyticsCacheServiceTests` | Nein — Wave 0 |

### Sampling Rate
- **Per task commit:** Betroffene Test-Klasse ausfuehren
- **Per wave merge:** Vollstaendige Test-Suite
- **Phase gate:** Alle Tests gruen vor Verification

### Wave 0 Gaps
- [ ] `InsightFlowTests/` Verzeichnis anlegen
- [ ] Test-Target in project.pbxproj eintragen
- [ ] `InsightFlowTests/KeychainServiceTests.swift` — deckt TEST-01 (Keychain)
- [ ] `InsightFlowTests/AccountManagerTests.swift` — deckt TEST-01 (AccountManager)
- [ ] `InsightFlowTests/UmamiAPIParsingTests.swift` — deckt TEST-01 (UmamiAPI-Parsing)
- [ ] `InsightFlowTests/PlausibleAPIParsingTests.swift` — deckt TEST-01 (PlausibleAPI-Parsing)
- [ ] `InsightFlowTests/DateRangeTests.swift` — deckt TEST-01 (DateRange)
- [ ] `InsightFlowTests/AnalyticsCacheServiceTests.swift` — deckt TEST-01 (Cache)
- [ ] Minimales Refactoring: `AnalyticsCacheService.init(cacheDirectoryOverride:)` hinzufuegen

## Project Constraints (from CLAUDE.md)

Keine direkten iOS/Xcode-Direktiven in CLAUDE.md. Allgemeine Direktiven:
- Keine externen Dependencies einzufuehren (konsistent mit REQUIREMENTS.md Out-of-Scope-Liste)
- Keine Dokumentationsdateien anlegen ausser wenn explizit angefragt
- Minimal invasiv: bevorzuge Bearbeitung bestehender Dateien gegenueber neuen

## Sources

### Primary (HIGH confidence)
- Apple XCTest Dokumentation (built-in framework, kein externer Check noetig)
- Direktes Code-Lesen der Service-Dateien (KeychainService.swift, AccountManager.swift, AnalyticsCacheService.swift, DateRange.swift, UmamiAPI.swift, PlausibleAPI.swift)
- project.pbxproj gelesen — bestaetigt: kein Test-Target vorhanden, ENABLE_TESTABILITY=YES bereits gesetzt, SWIFT_VERSION=6.0, IPHONEOS_DEPLOYMENT_TARGET=18.0, DEVELOPMENT_TEAM=J459G9CJT5

### Secondary (MEDIUM confidence)
- Swift 6 Concurrency + actor Testing: Bekanntes Pattern aus Swift-Dokumentation
- URLProtocol Mocking: Etabliertes iOS-Pattern seit iOS 7

### Tertiary (LOW confidence)
- Keychain-Entitlement-Verhalten im Simulator: Heuristisch — muss beim ersten Test-Run bestaetigt werden

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH — XCTest ist der einzige relevante Stack, built-in
- Architecture: HIGH — Code direkt gelesen, konkrete Interfaces bekannt
- Pitfalls: HIGH fuer Singleton-State + BUNDLE_LOADER; MEDIUM fuer Keychain-Entitlement-Verhalten

**Research date:** 2026-03-27
**Valid until:** Stabil — XCTest aendert sich selten
