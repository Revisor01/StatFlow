---
phase: 05-tests
plan: "04"
subsystem: tests
tags: [tests, account-manager, cache, gap-closure]
dependency_graph:
  requires: [05-03]
  provides: [SC2-complete, SC5-complete]
  affects: [InsightFlowTests]
tech_stack:
  added: []
  patterns: [manual-JSON-fixture, addTeardownBlock-keychain-cleanup]
key_files:
  created: []
  modified:
    - InsightFlowTests/AccountManagerTests.swift
    - InsightFlowTests/AnalyticsCacheServiceTests.swift
decisions:
  - "addTeardownBlock statt tearDown-Erweiterung fuer Keychain-Cleanup - lokaler scope pro Test"
  - "Manuelles JSON-Literal als Fixture fuer abgelaufenen Cache - kein CacheWrapper-Refactoring noetig"
metrics:
  duration: 10min
  completed: "2026-03-28"
  tasks: 2
  files: 2
---

# Phase 05 Plan 04: Gap Closure (AccountManager Migration + Cache TTL-Expiry) Summary

**One-liner:** 5 neue Tests schliessen Verifikations-Gaps SC2 (AccountManager Migration) und SC5 (Cache TTL-Expiry) — 58 Tests laufen gruen.

## What Was Built

### Task 1: AccountManager Migration- und Credential-Tests

Drei neue Tests in `InsightFlowTests/AccountManagerTests.swift` (jetzt 11 Tests):

- **testMigrateFromLegacyCredentials_Umami**: Befuellt Legacy-Keychain-Keys (serverURL, providerType, token), ruft `migrateFromLegacyCredentials()` auf, prueft dass Account erstellt und als aktiv gesetzt wurde.
- **testMigrateFromLegacyCredentials_SkipsWhenAccountsExist**: Bestaetigt den `guard accounts.isEmpty`-Schutz — bei vorhandenem Account wird Migration uebersprungen.
- **testSetActiveAccountAppliesCredentialsToKeychain**: Prueft `applyAccountCredentials` indirekt ueber `setActiveAccount()` — verifiziert serverURL, providerType und token in Legacy-Keychain.

Jeder Test raeumt Keychain-Eintraege per `addTeardownBlock` auf.

### Task 2: AnalyticsCacheService TTL-Expiry und clearExpiredCache-Tests

Zwei neue Tests in `InsightFlowTests/AnalyticsCacheServiceTests.swift` (jetzt 10 Tests):

- **testLoadExpiredWebsitesReturnsIsExpiredTrue**: Schreibt manuell ein JSON mit `expiresAt` in der Vergangenheit (2020) in das tempDir, laedt via `loadWebsites()` und prueft `isExpired == true`.
- **testClearExpiredCacheRemovesExpiredEntries**: Kombiniert frischen Cache (via API) mit abgelaufenem manuellen JSON, ruft `clearExpiredCache()` auf, prueft dass abgelaufener Eintrag geloescht und frischer Eintrag erhalten bleibt.

## Deviations from Plan

None — plan executed exactly as written.

## Test Results

| Suite | Tests | Failures |
|-------|-------|---------|
| AccountManagerTests | 11 (8 + 3 new) | 0 |
| AnalyticsCacheServiceTests | 10 (8 + 2 new) | 0 |
| InsightFlowTests (total) | 58 | 0 |

## Self-Check: PASSED

- `InsightFlowTests/AccountManagerTests.swift` — modified, 11 tests
- `InsightFlowTests/AnalyticsCacheServiceTests.swift` — modified, 10 tests
- Commits: f951813, e45601f
