---
phase: 04-architektur
plan: 03
subsystem: auth
tags: [swift, swiftui, authmanager, accountmanager, loginviewmodel, consolidation]

requires:
  - phase: 04-architektur-02
    provides: PlausibleAPI als actor, AnalyticsProvider-Protokoll genutzt
  - phase: 04-architektur-01
    provides: AccountManager als Basis fuer Account-Verwaltung

provides:
  - LoginViewModel als zentrale Login-Logik fuer Umami und Plausible
  - AuthManager vollstaendig entfernt
  - AccountManager ist einzige Auth-State-Quelle
  - Alle Views direkt auf AccountManager.shared oder LoginViewModel umgestellt

affects:
  - phase-05-tests
  - alle Views die Auth-State benoetigen

tech-stack:
  added: []
  patterns:
    - "ViewModel-Pattern: Login-Logik in LoginViewModel (ObservableObject) statt EnvironmentObject-Kette"
    - "Singleton-Pattern: AccountManager.shared als direkter @ObservedObject statt per EnvironmentObject"

key-files:
  created:
    - InsightFlow/Views/Auth/LoginViewModel.swift
  modified:
    - InsightFlow/Services/AccountManager.swift
    - InsightFlow/App/InsightFlowApp.swift
    - InsightFlow/App/ContentView.swift
    - InsightFlow/App/MainTabView.swift
    - InsightFlow/Views/Auth/LoginView.swift
    - InsightFlow/Views/Settings/SettingsView.swift
    - InsightFlow/Views/Dashboard/DashboardView.swift
  deleted:
    - InsightFlow/Services/AuthManager.swift

key-decisions:
  - "LoginViewModel haelt nur isLoading + errorMessage — AccountManager.setActiveAccount() uebernimmt alle Downstream-Effekte (Keychain, API-Config, Widget)"
  - "clearActiveAccount() erweitert um UmamiAPI.clearConfiguration() und PlausibleSitesManager.clearAll() (aus AuthManager.logout() migriert)"
  - "ContentView: accountManager.activeAccount != nil ersetzt authManager.isAuthenticated als Routing-Bedingung"
  - "SettingsView.currentAccountRow jetzt Funktion mit AnalyticsAccount-Parameter statt Property mit authManager-Zugriff"

patterns-established:
  - "AccountManager.shared direkt per @ObservedObject einbinden — kein EnvironmentObject mehr fuer Auth-State"
  - "LoginViewModel per @StateObject in LoginView — kein shared state, lokale Login-Logik"

requirements-completed: [ARCH-01]

duration: 10min
completed: 2026-03-28
---

# Phase 4 Plan 3: AuthManager-Konsolidierung Summary

**AuthManager.swift geloescht, LoginViewModel migriert Login-Logik, AccountManager ist einzige Auth-State-Quelle fuer alle 5 Views**

## Performance

- **Duration:** 10 min
- **Started:** 2026-03-28T03:40:00Z
- **Completed:** 2026-03-28T03:50:00Z
- **Tasks:** 2 of 3 (Task 3 ist manueller Smoke-Test — deferred to phase verification)
- **Files modified:** 8 (+ 1 geloescht, 1 erstellt)

## Accomplishments

- LoginViewModel erstellt mit `login()` (Umami) und `loginWithPlausible()` (Plausible) — exakte Logik aus AuthManager migriert
- AccountManager.clearActiveAccount() um UmamiAPI.clearConfiguration() und PlausibleSitesManager.clearAll() ergaenzt
- AuthManager.swift vollstaendig geloescht — keine Referenzen mehr in der Codebase
- ContentView, LoginView, SettingsView, DashboardView, MainTabView, InsightFlowApp auf AccountManager/LoginViewModel umgestellt

## Task Commits

1. **Task 1: LoginViewModel erstellen und AuthManager-Logik migrieren** - `717388f` (feat)
2. **Task 2: Alle Views von AuthManager auf AccountManager/LoginViewModel umstellen** - `51c9b6f` (feat)
3. **Task 3: Manueller Smoke-Test** - deferred (checkpoint:human-verify, nicht automatisierbar)

## Files Created/Modified

- `InsightFlow/Views/Auth/LoginViewModel.swift` - Neue Datei: Login-Logik fuer Umami und Plausible
- `InsightFlow/Services/AccountManager.swift` - clearActiveAccount() um API-Cleanup ergaenzt
- `InsightFlow/Services/AuthManager.swift` - GELOESCHT
- `InsightFlow/App/InsightFlowApp.swift` - authManager StateObject und environmentObject entfernt
- `InsightFlow/App/ContentView.swift` - isAuthenticated durch activeAccount != nil ersetzt
- `InsightFlow/App/MainTabView.swift` - Preview: AuthManager environmentObject entfernt
- `InsightFlow/Views/Auth/LoginView.swift` - authManager durch LoginViewModel ersetzt
- `InsightFlow/Views/Settings/SettingsView.swift` - authManager.logout() durch clearActiveAccount() ersetzt, currentAccountRow auf AnalyticsAccount umgestellt
- `InsightFlow/Views/Dashboard/DashboardView.swift` - authManager durch accountManager ersetzt

## Decisions Made

- LoginViewModel delegiert alle Post-Login-Effekte an AccountManager.addAccount() + setActiveAccount() — kein doppeltes Keychain-Schreiben
- SettingsView.currentAccountRow wurde zur Funktion mit AnalyticsAccount-Parameter umgebaut, da authManager.username/serverURL weggefallen sind
- AccountManager.clearActiveAccount() als Drop-in-Ersatz fuer authManager.logout() — erweitert um fehlende Cleanup-Schritte

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] MainTabView Preview hatte noch AuthManager-Referenz**
- **Found during:** Task 2 (AuthManager-Referenzen bereinigen)
- **Issue:** MainTabView war nicht in der Plan-Dateiliste, hatte aber `.environmentObject(AuthManager())` im Preview
- **Fix:** AuthManager-environmentObject aus Preview entfernt
- **Files modified:** InsightFlow/App/MainTabView.swift
- **Committed in:** 51c9b6f (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 2 — missing file in plan scope)
**Impact on plan:** Notwendig — AuthManager-Referenz waere Kompilierfehler nach Loeschen der Datei.

## Issues Encountered

None — Migration verlief planmaessig. AccountManager.applyAccountCredentials() deckt bereits alle Downstream-Effekte ab, die in AuthManager.login() manuell gemacht wurden.

## Known Stubs

None — keine Placeholder-Werte oder leere Datenquellen eingefuehrt.

## Next Phase Readiness

- Auth-Konsolidierung (ARCH-01) abgeschlossen: AuthManager entfernt, AccountManager als Single Source of Truth
- Task 3 (Smoke-Test) muss manuell verifiziert werden vor Phase 5
- Phase 5 (Tests) kann mit Auth-Pfaden beginnen: LoginViewModel ist jetzt isoliert testbar

---
*Phase: 04-architektur*
*Completed: 2026-03-28*
