---
phase: 05-tests
plan: 01
subsystem: testing
tags: [xctest, xcode-26, keychain, daterange, unit-tests, tdd]

# Dependency graph
requires:
  - phase: 04-architektur
    provides: KeychainService account-scoped Methoden, DateRange Modell, AnalyticsCacheService

provides:
  - InsightFlowTests XCTest-Target (com.apple.product-type.bundle.unit-test, Xcode 26)
  - KeychainServiceTests: 6 Tests fuer save/load/delete/scoping/overwrite/apiKey
  - DateRangeTests: 10 Tests fuer Preset-Invarianten, Spans, Units, Custom, thisWeek-Montag
  - AnalyticsCacheService testbarer init(cacheDirectoryOverride:)

affects:
  - 05-tests-02
  - 05-tests-03

# Tech tracking
tech-stack:
  added: [XCTest (built-in, Xcode 26)]
  patterns:
    - XCTest unit-test-bundle mit BUNDLE_LOADER/TEST_HOST fuer @testable import
    - PBXFileSystemSynchronizedRootGroup fuer Auto-Discovery von Test-Dateien
    - TearDown-Pattern fuer Keychain-Cleanup (deleteCredentials + deleteAll)
    - Invarianten-Tests statt exakter Datumswerte fuer zeitunabhaengige DateRange-Tests

key-files:
  created:
    - InsightFlowTests/KeychainServiceTests.swift
    - InsightFlowTests/DateRangeTests.swift
  modified:
    - InsightFlow.xcodeproj/project.pbxproj
    - InsightFlow.xcodeproj/xcshareddata/xcschemes/InsightFlow.xcscheme
    - InsightFlow/Services/AnalyticsCacheService.swift

key-decisions:
  - "productType = com.apple.product-type.bundle.unit-test statt com.apple.product-type.unit-test-bundle (Xcode 26 umbenennt den Identifier)"
  - "init(cacheDirectoryOverride:) als internal init neben private init() — minimales Refactoring ohne shared-Singleton zu brechen"
  - "XCTSkipIf fuer Keychain-Tests: Entitlement-Fehler werden graceful uebersprungen, aber im Simulator laufen alle Tests durch"
  - "shouldAutocreateTestPlan entfernt aus Schema: kollidiert mit manuell gesetzten Testables"

patterns-established:
  - "Pattern 1: TDD mit PBXFileSystemSynchronizedRootGroup — Test-Dateien im Verzeichnis werden automatisch entdeckt ohne pbxproj-Einzeleintraege"
  - "Pattern 2: Keychain-Tests mit tearDown-Cleanup — deleteCredentials + deleteAll sichert Test-Isolation"
  - "Pattern 3: DateRange-Invarianten statt absoluter Daten — start <= end, Span-Differenz, Unit-String sind zeitunabhaengig pruefbar"

requirements-completed: [TEST-01]

# Metrics
duration: 25min
completed: 2026-03-28
---

# Phase 05 Plan 01: Test-Infrastruktur und erste Unit Tests Summary

**XCTest-Target InsightFlowTests mit 16 gruenen Tests (10 DateRange + 6 Keychain) via PBXFileSystemSynchronizedRootGroup und BUNDLE_LOADER/TEST_HOST auf Xcode 26**

## Performance

- **Duration:** 25 min
- **Started:** 2026-03-28T05:00:00Z
- **Completed:** 2026-03-28T05:25:00Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- InsightFlowTests-Target in project.pbxproj angelegt mit allen notwendigen Abschnitten (PBXNativeTarget, PBXBuildFile, PBXTargetDependency, XCBuildConfiguration, XCConfigurationList)
- 16 Unit-Tests laufen gruen im iPhone 17 Simulator (10 DateRange-Invarianten, 6 Keychain-Round-Trip/Scoping/Cleanup)
- AnalyticsCacheService um testbaren init(cacheDirectoryOverride:) erweitert ohne bestehende API zu brechen

## Task Commits

Jeder Task wurde atomar committed:

1. **Task 1: Test-Target anlegen und CacheService refactorn** - `fe597e6` (feat)
2. **Task 2: KeychainService und DateRange Unit Tests schreiben** - `a2a4da5` (feat)

## Files Created/Modified
- `InsightFlowTests/KeychainServiceTests.swift` - 6 Keychain-Tests: save/load, delete, account-scoping, overwrite, deleteAll, apiKey
- `InsightFlowTests/DateRangeTests.swift` - 10 DateRange-Tests: Preset-Invarianten, Spans, Units, Custom, thisWeek-Montag
- `InsightFlow.xcodeproj/project.pbxproj` - InsightFlowTests-Target, XCTest.framework, Build-Konfigurationen, Schema-Referenzen
- `InsightFlow.xcodeproj/xcshareddata/xcschemes/InsightFlow.xcscheme` - InsightFlowTests in BuildActionEntries und Testables eingetragen
- `InsightFlow/Services/AnalyticsCacheService.swift` - init(cacheDirectoryOverride:) fuer Testbarkeit hinzugefuegt

## Decisions Made
- **productType Xcode 26:** In Xcode 26 (Build 17E192) heisst der Identifier fuer Unit-Test-Targets `com.apple.product-type.bundle.unit-test` statt dem frueheren `com.apple.product-type.unit-test-bundle`. Der Plan spezifizierte den alten Identifier — Xcode 26-Kompatibilitaet erforderte Anpassung.
- **shouldAutocreateTestPlan entfernt:** Kollidiert mit manuell gesetzten `<Testables>` im Schema und verhinderte das Finden des Test-Targets.
- **SDKROOT + SUPPORTED_PLATFORMS:** Mussten explizit gesetzt werden — ohne diese konnte Xcode den `unit-test-bundle` Produkttyp nicht aufloesen.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] productType-Identifier fuer Xcode 26 korrigiert**
- **Found during:** Task 1 (Build-Verifikation)
- **Issue:** `com.apple.product-type.unit-test-bundle` ist in Xcode 26 nicht mehr gueltiger Identifier fuer iOS Test-Targets. Fehler: "unable to resolve product type"
- **Fix:** productType auf `com.apple.product-type.bundle.unit-test` geaendert (neuer Xcode 26 Identifier), SDKROOT und SUPPORTED_PLATFORMS ergaenzt
- **Files modified:** InsightFlow.xcodeproj/project.pbxproj
- **Verification:** `xcodebuild build-for-testing` baut das Test-Target fehlerfrei
- **Committed in:** a2a4da5 (Task 2 Commit)

**2. [Rule 1 - Bug] Schema fuer Tests konfiguriert**
- **Found during:** Task 2 (Test-Ausfuehrung)
- **Issue:** Schema hatte `shouldAutocreateTestPlan = "YES"` ohne Testables — fuehrte zu "There are no test bundles available to test"
- **Fix:** `shouldAutocreateTestPlan` entfernt, InsightFlowTests in `<Testables>` und `BuildActionEntries` eingetragen
- **Files modified:** InsightFlow.xcodeproj/xcshareddata/xcschemes/InsightFlow.xcscheme
- **Verification:** `xcodebuild test` findet und fuehrt alle 16 Tests aus
- **Committed in:** a2a4da5 (Task 2 Commit)

---

**Total deviations:** 2 auto-fixed (beide Rule 1 - Bug, beide Xcode 26 Kompatibilitaet)
**Impact on plan:** Beide Auto-Fixes notwendig fuer Korrektheit. Kein Scope Creep.

## Issues Encountered
- Xcode 26 Beta verwendet einen anderen productType-Identifier fuer Unit-Test-Targets. Der Plan spezifizierte den alten Identifier aus der Forschung (die auf Xcode 16 basierte). Auto-Fix via Rule 1.
- `shouldAutocreateTestPlan` im Schema verhinderte das Finden des manuell konfigurierten Test-Targets. Auto-Fix via Rule 1.

## Known Stubs
Keine. Alle Tests sind vollstaendig implementiert und laufen gruen.

## Next Phase Readiness
- InsightFlowTests-Target ist funktionsfaehig — Phase 05 Plan 02 (AccountManager, API-Parsing-Tests) kann direkt beginnen
- PBXFileSystemSynchronizedRootGroup ist gesetzt — neue Test-Dateien in InsightFlowTests/ werden automatisch entdeckt
- BUNDLE_LOADER/TEST_HOST korrekt gesetzt — @testable import InsightFlow funktioniert

---
*Phase: 05-tests*
*Completed: 2026-03-28*
