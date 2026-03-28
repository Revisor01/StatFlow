---
phase: 01-security-hardening
plan: 01
subsystem: auth
tags: [keychain, credentials, security, migration]
dependency_graph:
  requires: []
  provides: [account-scoped-keychain-credentials, credential-migration]
  affects: [AccountManager, KeychainService]
tech_stack:
  added: []
  patterns: [account-ID-scoped Keychain storage, credential stripping before persistence, Keychain hydration on load, one-time migration flag]
key_files:
  created: []
  modified:
    - InsightFlow/Services/KeychainService.swift
    - InsightFlow/Services/AccountManager.swift
decisions:
  - "Keychain per Account-ID statt Single-Slot: Format {type}_{accountId} als kSecAttrAccount-Key"
  - "Migration via UserDefaults-Flag credentials_migrated_v2 — läuft einmalig beim App-Start"
  - "Credential-Stripping in saveAccounts() vor Serialisierung — Keychain ist Single Source of Truth"
metrics:
  duration: ~15min
  completed: 2026-03-28
  tasks_completed: 2
  files_modified: 2
---

# Phase 01 Plan 01: Keychain-basierte Credential-Speicherung Summary

Account-ID-scoped Keychain-Speicherung mit automatischer Migration bestehender Accounts aus UserDefaults.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | KeychainService Account-Scoped Methoden | 5901706 | InsightFlow/Services/KeychainService.swift |
| 2 | AccountManager Credential-Stripping/Hydration/Migration | a42cc96 | InsightFlow/Services/AccountManager.swift |

## What Was Built

### Task 1 — KeychainService erweitert

`KeychainService.swift` erhielt einen neuen Abschnitt `// MARK: - Account-Scoped Credentials`:

- `enum CredentialType: String, CaseIterable` mit cases `token` und `apiKey`
- `saveCredential(_:type:accountId:) throws` — schreibt credential mit Key `{type}_{accountId}`
- `loadCredential(type:accountId:) -> String?` — liest credential per account-scoped Key
- `deleteCredentials(for:)` — löscht alle CredentialType-Einträge für eine Account-ID

Alle drei Methoden verwenden `kSecAttrAccessibleAfterFirstUnlock`. Bestehende `save/load/delete/deleteAll`-Methoden sind unverändert.

### Task 2 — AccountManager überarbeitet

**AnalyticsAccount.init():** Parameter `createdAt: Date = Date()` ergänzt, sodass beim Kopieren in Hilfsmethoden das Original-Datum beibehalten wird.

**Neue Hilfsmethoden:**
- `saveCredentialsToKeychain(for:)` — schreibt token/apiKey in Keychain (nur wenn nicht leer)
- `accountWithoutCredentials(_:)` — erstellt Account-Kopie ohne Credentials für UserDefaults
- `hydrateWithKeychainCredentials(_:)` — befüllt Account mit Credentials aus der Keychain
- `migrateCredentialsToKeychain()` — liest bestehende UserDefaults-Accounts, schreibt Credentials in Keychain, setzt Migration-Flag

**Geänderte Methoden:**
- `init()` — prüft `migrationV2Key`, ruft Migration vor `loadAccounts()` auf
- `addAccount(_:)` — ruft `saveCredentialsToKeychain(for:)` VOR `saveAccounts()` auf
- `removeAccount(_:)` — ruft `KeychainService.deleteCredentials(for:)` auf
- `loadAccounts()` — mappt decoded Accounts durch `hydrateWithKeychainCredentials(_:)`
- `saveAccounts()` — mappt accounts durch `accountWithoutCredentials(_:)` vor Serialisierung

`migrateFromLegacyCredentials()` (bestehende Methode) bleibt unverändert.

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Keychain per Account-ID statt Single-Slot | Häufiges Account-Switching erfordert isolierte Credentials ohne gegenseitige Überschreibung |
| Migration-Flag in UserDefaults | Einmalige Migration ohne Re-Login — transparentes Upgrade für bestehende Nutzer |
| Credential-Stripping vor JSONEncoder | UserDefaults enthält keine Credentials mehr — Keychain ist Single Source of Truth |

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — alle Credential-Pfade sind vollständig verdrahtet.

## Self-Check: PASSED

- KeychainService.swift vorhanden und enthält alle 4 neuen Elemente (CredentialType, saveCredential, loadCredential, deleteCredentials)
- AccountManager.swift enthält alle 5 Pflicht-Elemente (accountWithoutCredentials, hydrateWithKeychainCredentials, saveCredentialsToKeychain, migrateCredentialsToKeychain, migrationV2Key)
- Commits 5901706 und a42cc96 existieren in git log
