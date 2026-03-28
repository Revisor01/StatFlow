---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: Code Quality & Security Hardening
status: executing
stopped_at: Completed 04-architektur-02-PLAN.md
last_updated: "2026-03-28T03:45:08.491Z"
last_activity: 2026-03-28
progress:
  total_phases: 5
  completed_phases: 3
  total_plans: 11
  completed_plans: 10
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-27)

**Core value:** Nutzer können ihre Website-Analytics sicher und übersichtlich vom iPhone aus überwachen
**Current focus:** Phase 04 — Architektur

## Current Position

Phase: 04 (Architektur) — EXECUTING
Plan: 3 of 3
Status: Ready to execute
Last activity: 2026-03-28

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**

- Total plans completed: 0
- Average duration: —
- Total execution time: —

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

*Updated after each plan completion*
| Phase 01-security-hardening P01 | 15min | 2 tasks | 2 files |
| Phase 01-security-hardening P02 | 20min | 2 tasks | 3 files |
| Phase 02-quick-wins-widget-split P02 | 6min | 2 tasks | 16 files |
| Phase 02-quick-wins-widget-split P01 | 7min | 2 tasks | 9 files |
| Phase 02-quick-wins-widget-split P03 | 45min | 2 tasks | 11 files |
| Phase 03-stabilitaet P02 | 5min | 1 tasks | 2 files |
| Phase 03-stabilitaet P01 | 3min | 2 tasks | 3 files |
| Phase 04-architektur P01 | 15min | 2 tasks | 5 files |
| Phase 04-architektur P02 | 15min | 2 tasks | 3 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Pending: AccountManager als Single Source of Truth für Auth
- Pending: Keychain per Account-ID statt Single-Slot
- Pending: actor-Pattern für beide API-Clients
- [Phase 01-security-hardening]: Keychain per Account-ID statt Single-Slot: Format {type}_{accountId} als kSecAttrAccount-Key
- [Phase 01-security-hardening]: Migration via credentials_migrated_v2 Flag — einmalig beim App-Start, transparent fuer bestehende Nutzer
- [Phase 01-security-hardening]: widget_accounts.encrypted statt widget_accounts.json — gleicher AES-GCM Key (widget_credentials.key) wie fuer Credentials
- [Phase 01-security-hardening]: Widget ist read-only fuer Accounts — saveAccounts() plaintext entfernt, App schreibt verschluesselt
- [Phase 02-quick-wins-widget-split]: #if DEBUG wrapping fuer alle print()-Calls in Swift — kein Logger-Utility eingefuehrt, reines mechanisches Wrapping
- [Phase 02-quick-wins-widget-split]: widgetLog() als internal fuer Sichtbarkeit aus allen Widget-Dateien im selben Target
- [Phase 02-quick-wins-widget-split]: AppIntents import in WidgetTimeRange.swift benoetigt fuer TypeDisplayRepresentation/DisplayRepresentation
- [Phase 02-quick-wins-widget-split]: View extraction pattern: mutable state via @Binding, read-only ViewModel as let parameter
- [Phase 03-stabilitaet]: asyncAfter durch synchrones @MainActor-Post ersetzt: applyAccountCredentials garantiert alle Zuweisungen vor Notification
- [Phase 03-stabilitaet]: Task.sleep entfernt: PlausibleSitesManager ist lazy Singleton, bereits initialisiert — getSites() gibt synchron zurück
- [Phase 03-stabilitaet]: guard-let + throw fuer API-Clients, ?? Fallback fuer calendar.date im Widget — keine neuen Error-Cases eingefuehrt
- [Phase 04-architektur]: actor-Pattern fuer beide API-Clients: PlausibleAPI wie UmamiAPI als Swift actor — kein @MainActor fuer API-Logik
- [Phase 04-architektur]: await MainActor.run statt Task-Wrapping fuer @MainActor-Aufrufe aus actor-Methoden
- [Phase 04-architektur]: Protocol Extension fuer Plausible-Luecken: getPageTitles/getLanguages/getScreens/getEvents geben [] zurueck via extension AnalyticsProvider
- [Phase 04-architektur]: AnalyticsManager.isAuthenticated entfernt: redundant zu currentProvider != nil, nicht von Views direkt gelesen

### Pending Todos

None yet.

### Blockers/Concerns

- ARCH-01 (Auth-Konsolidierung) ist die riskanteste Änderung im Milestone — erst in Phase 4, nachdem Stabilität (Phase 3) abgesichert ist
- Kein Test-Safety-Net bis Phase 5 — jede Phase muss manuell verifiziert werden

## Session Continuity

Last session: 2026-03-28T03:45:08.488Z
Stopped at: Completed 04-architektur-02-PLAN.md
Resume file: None
