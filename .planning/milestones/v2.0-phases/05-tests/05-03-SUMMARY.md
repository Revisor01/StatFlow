---
phase: 05-tests
plan: 03
subsystem: tests
tags: [unit-tests, AccountManager, AnalyticsCacheService, MainActor, TDD]
dependency_graph:
  requires: [05-01]
  provides: [AccountManager-tests, AnalyticsCacheService-tests]
  affects: [InsightFlowTests]
tech_stack:
  added: []
  patterns: [TDD, MainActor-async-tests, cacheDirectoryOverride-injection]
key_files:
  created:
    - InsightFlowTests/AccountManagerTests.swift
    - InsightFlowTests/AnalyticsCacheServiceTests.swift
  modified: []
decisions:
  - "@MainActor class mit async setUp/tearDown fuer Singleton-State-Cleanup"
  - "cacheDirectoryOverride mit UUID-tempDir pro Test fuer vollstaendige Isolation"
metrics:
  duration: 13min
  completed_date: "2026-03-28"
  tasks_completed: 2
  files_changed: 2
---

# Phase 05 Plan 03: AccountManager & AnalyticsCacheService Tests Summary

**One-liner:** AccountManager (8 Tests, @MainActor, Keychain/UserDefaults-Cleanup) und AnalyticsCacheService (8 Tests, tempDir-Injektion, TTL/clear-Coverage) — 53 Tests in Gesamtsuite gruen.

## What Was Built

### Task 1: AccountManagerTests

8 Unit-Tests fuer den Singleton `AccountManager.shared` (@MainActor):

| Test | Was wird geprueft |
|------|------------------|
| testAddAccount | accounts.count == 1 nach addAccount |
| testAddDuplicateServerURLUpdatesExisting | gleiche URL/Provider => update statt append |
| testRemoveAccount | accounts.count == 0 nach remove |
| testRemoveAccountClearsKeychain | loadCredential == nil nach remove |
| testSetActiveAccount | activeAccount.id korrekt gesetzt |
| testClearActiveAccount | activeAccount == nil nach clearActiveAccount |
| testAccountsPersistInUserDefaults | UserDefaults.standard.data(forKey: "analytics_accounts") != nil |
| testActiveAccountIdPersistsInUserDefaults | UserDefaults.standard.string(forKey: "active_account_id") != nil |

Setup/TearDown raeumt Singleton-State (accounts-Array, UserDefaults-Keys) vor und nach jedem Test.

### Task 2: AnalyticsCacheServiceTests

8 Unit-Tests fuer `AnalyticsCacheService` mit `cacheDirectoryOverride`:

| Test | Was wird geprueft |
|------|------------------|
| testSaveAndLoadWebsites | data.count == 1, domain == "test.com" |
| testLoadWebsitesNotExpired | isExpired == false direkt nach save |
| testSaveAndLoadStats | data.visitors.value == expected |
| testLoadNonExistentKeyReturnsNil | loadWebsites("nonexistent") == nil |
| testClearAllCache | load == nil nach clearAllCache |
| testClearCacheForAccount | acc-1 nil, acc-2 noch vorhanden |
| testClearCacheForWebsite | web-1 nil, web-2 noch vorhanden |
| testCacheSizeReturnsNonZeroAfterSave | cacheSize() > 0 nach save |

Jeder Test bekommt ein eigenes UUID-tempDir, das in tearDown geloescht wird.

## Decisions Made

- `@MainActor class AccountManagerTests` mit `async` setUp/tearDown fuer korrekte Actor-Isolation beim Singleton-Cleanup
- `AnalyticsCacheService(cacheDirectoryOverride: tempDir)` mit UUID pro Test — vollstaendige File-System-Isolation ohne App-Group-Entitlement
- HTTP-Verbindungsfehler in AccountManager-Tests sind erwartet (applyAccountCredentials startet echte API-Calls) — kein Einfluss auf Test-Ergebnis

## Test Results

```
Test Suite 'InsightFlowTests.xctest' passed
   Executed 53 tests, with 0 failures (0 unexpected) in 1.874 seconds
```

- AccountManagerTests: 8/8 passed
- AnalyticsCacheServiceTests: 8/8 passed
- Gesamtsuite (alle 6 Klassen): 53/53 passed

## Deviations from Plan

None - Plan ausgefuehrt wie geschrieben. Test-Code compiliert und laeuft beim ersten Versuch.

## Known Stubs

None.

## Self-Check: PASSED

- AccountManagerTests.swift: FOUND
- AnalyticsCacheServiceTests.swift: FOUND
- Commit a70c5ee (AccountManager tests): FOUND
- Commit 7792343 (AnalyticsCacheService tests): FOUND
