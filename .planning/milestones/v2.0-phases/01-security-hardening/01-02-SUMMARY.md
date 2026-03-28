---
phase: 01-security-hardening
plan: 02
subsystem: widget-security
tags: [widget, encryption, aes-gcm, token-logging, security]
dependency_graph:
  requires: [account-scoped-keychain-credentials]
  provides: [encrypted-widget-accounts, token-log-free-widget]
  affects: [SharedCredentials, AccountManager, InsightFlowWidget]
tech_stack:
  added: []
  patterns: [AES-GCM widget account encryption, encrypted App Group file, legacy plaintext fallback, read-only widget pattern]
key_files:
  created: []
  modified:
    - InsightFlow/Services/SharedCredentials.swift
    - InsightFlow/Services/AccountManager.swift
    - InsightFlowWidget/InsightFlowWidget.swift
decisions:
  - "widget_accounts.encrypted statt widget_accounts.json — gleicher AES-GCM Key (widget_credentials.key) wie für Credentials"
  - "Widget ist read-only für Accounts — saveAccounts() plaintext entfernt, App schreibt verschluesselt"
  - "Legacy-Fallback auf widget_accounts.json in beiden App und Widget fuer Uebergangszeit"
metrics:
  duration: ~20min
  completed: 2026-03-28
  tasks_completed: 2
  files_modified: 3
---

# Phase 01 Plan 02: Widget-Account-Verschluesselung und Token-Log-Entfernung Summary

AES-GCM-verschluesselte widget_accounts.encrypted Datei im App Group Container mit Legacy-Fallback; Token-Logging vollstaendig aus Widget entfernt.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | SharedCredentials Widget-Account-Verschluesselung + AccountManager umstellen | c592531 | InsightFlow/Services/SharedCredentials.swift, InsightFlow/Services/AccountManager.swift |
| 2 | Widget-seitige Entschluesselung und Token-Log-Entfernung | 3c9497a | InsightFlowWidget/InsightFlowWidget.swift |

## What Was Built

### Task 1 — SharedCredentials und AccountManager

**SharedCredentials.swift** erhielt einen neuen Abschnitt `// MARK: - Widget Accounts (Encrypted)`:

- `private static let widgetAccountsFileName = "widget_accounts.encrypted"` — verschluesselte Zieldatei
- `private static let legacyWidgetAccountsFileName = "widget_accounts.json"` — Legacy-Referenz fuer Migration
- `saveWidgetAccounts(_ accountsData: Data) -> Bool` — verschluesselt via `encrypt()` (AES-GCM), schreibt mit `.completeFileProtection`, loescht Legacy-Datei nach Erfolg
- `loadWidgetAccounts() -> Data?` — laedt und entschluesselt; faellt auf Plaintext-Legacy zurueck wenn `.encrypted` nicht existiert

**AccountManager.swift** — `syncAccountsToWidget()` umgestellt:

- Entfernt: direktes `data.write(to: fileURL)` mit Plaintext und ungeschuetztes `print()`
- Eingefuegt: `SharedCredentials.saveWidgetAccounts(data)` mit `#if DEBUG`-geschuetztem Log
- Container-URL-Handling entfernt — vollstaendig an SharedCredentials delegiert

### Task 2 — WidgetAccountsStorage im Widget

**WidgetAccountsStorage** komplett ueberarbeitet:

- `private static let fileName = "widget_accounts.encrypted"` — liest jetzt verschluesselte Datei
- `private static let keyFileName = "widget_credentials.key"` — gleicher Key wie widget_credentials.encrypted
- `loadEncryptionKey() -> SymmetricKey?` — liest Key-Datei, prueft 32-Byte-Laenge
- `loadAccounts()` — versucht AES.GCM.SealedBox + AES.GCM.open; faellt bei Fehler auf Legacy zurueck
- `loadLegacyAccounts(containerURL:)` — separierte Hilfsmethode fuer Plaintext-Fallback und WidgetCredentials-Fallback
- `saveAccounts()` plaintext-Methode entfernt — Widget ist read-only

**Token-Logging entfernt (SEC-03):**
- `token=\(acc.token.prefix(10))...` vollstaendig geloescht
- Alle verbleibenden Account-Logs enthalten nur `acc.name`, `acc.providerType`, `acc.sites`

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Gleicher Key (widget_credentials.key) fuer beide verschluesselte Dateien | Minimale Key-Komplexitaet — App generiert Key einmalig, beide Dateien profitieren |
| Widget ist read-only | App schreibt immer verschluesselt; Widget-seitiges Schreiben von Plaintext ist ein Sicherheitsrisiko |
| Legacy-Fallback bleibt vorhanden | Nahtloses Update fuer bestehende Nutzer ohne Re-Login nach App-Update |

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — alle Schreib- und Lesepfade sind vollstaendig verdrahtet.

## Self-Check: PASSED

- SharedCredentials.swift enthaelt `widget_accounts.encrypted`, `saveWidgetAccounts`, `loadWidgetAccounts`
- AccountManager.swift enthaelt `SharedCredentials.saveWidgetAccounts`, kein `widget_accounts.json`
- InsightFlowWidget.swift enthaelt `widget_accounts.encrypted`, `AES.GCM.SealedBox`, kein `token.prefix`, kein `acc.token`
- `xcodebuild build` → BUILD SUCCEEDED
- Commits c592531 und 3c9497a existieren in git log
