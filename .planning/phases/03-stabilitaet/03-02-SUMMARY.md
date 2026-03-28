---
phase: 03-stabilitaet
plan: 02
subsystem: auth
tags: [swift, concurrency, mainactor, notificationcenter, timing]

# Dependency graph
requires:
  - phase: 03-stabilitaet-01
    provides: Research-Analyse der Timing-Hacks
provides:
  - Synchrones Notification-Posting in AccountManager.applyAccountCredentials()
  - Delay-freies Lesen von PlausibleSitesManager in AuthManager.loadPlausibleCredentials()
affects: [04-architektur, 05-tests]

# Tech tracking
tech-stack:
  added: []
  patterns: [Synchrones @MainActor Notification-Posting statt asyncAfter-Delay]

key-files:
  created: []
  modified:
    - InsightFlow/Services/AccountManager.swift
    - InsightFlow/Services/AuthManager.swift

key-decisions:
  - "asyncAfter(0.3s) durch direktes NotificationCenter.post() ersetzt — Methode ist @MainActor, alle Zuweisungen sind vor dem Post abgeschlossen"
  - "Task.sleep(0.1s) entfernt — PlausibleSitesManager ist lazy Singleton, bereits bei App-Start initialisiert, getSites() gibt synchron zurück"

patterns-established:
  - "Timing-Hacks als Code-Smell: asyncAfter/Task.sleep sind Symptome fehlender Synchronisation, nicht Lösungen"

requirements-completed: [STAB-02]

# Metrics
duration: 5min
completed: 2026-03-27
---

# Phase 03 Plan 02: Timing-Hacks entfernen Summary

**asyncAfter(0.3s) und Task.sleep(0.1s) aus AccountManager und AuthManager entfernt — Notification wird synchron auf @MainActor gepostet, PlausibleSitesManager direkt ohne Delay gelesen**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-03-27T00:00:00Z
- **Completed:** 2026-03-27T00:05:00Z
- **Tasks:** 1 of 2 (Task 2 ist manueller Checkpoint — deferred to phase verification)
- **Files modified:** 2

## Accomplishments
- `DispatchQueue.main.asyncAfter(deadline: .now() + 0.3)` in `AccountManager.applyAccountCredentials()` entfernt — Notification `.accountDidChange` wird jetzt synchron gepostet
- `try? await Task.sleep(nanoseconds: 100_000_000)` in `AuthManager.loadPlausibleCredentials()` entfernt — `PlausibleSitesManager.shared.getSites()` wird direkt aufgerufen
- Race-Condition-Fenster (0.3s und 0.1s) eliminiert, Komponenten-Koordination ist jetzt deterministisch

## Task Commits

Each task was committed atomically:

1. **Task 1: asyncAfter in AccountManager und Task.sleep in AuthManager entfernen** - `ddc93f7` (fix)
2. **Task 2: Account-Switch manuell verifizieren** - Checkpoint: deferred to phase verification (kein Code-Commit)

**Plan metadata:** (nach state update)

## Files Created/Modified
- `InsightFlow/Services/AccountManager.swift` - asyncAfter-Block durch direkten NotificationCenter.post()-Aufruf ersetzt
- `InsightFlow/Services/AuthManager.swift` - Task.sleep-Zeile entfernt, getSites() wird direkt aufgerufen

## Decisions Made
- asyncAfter durch synchrones Post ersetzt, weil `applyAccountCredentials()` bereits `@MainActor` ist — alle Property-Zuweisungen (Keychain, setSitesWithoutPersist, reconfigureFromKeychain, setProvider) sind vor dem Post garantiert abgeschlossen
- Task.sleep entfernt, weil `PlausibleSitesManager` ein lazy Singleton ist, das beim App-Start bereits initialisiert wurde — kein Warten nötig

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Checkpoint: Task 2 (Manuelles Verifizieren)

Task 2 ist ein `checkpoint:human-verify` und wurde als deferred markiert. Der User muss:

1. App in Xcode bauen und auf Gerät/Simulator starten
2. Falls mehrere Accounts vorhanden: zwischen Accounts wechseln und prüfen:
   - UI zeigt sofort die Daten des neuen Accounts (keine alten Daten sichtbar)
   - Kein kurzes Flackern oder leerer Zustand nach dem Wechsel
3. Falls Plausible-Account vorhanden: prüfen dass nach App-Neustart die Widget-Credentials korrekt geschrieben werden (Widget zeigt Daten)
4. Falls nur ein Account: App starten, Dashboard laden, prüfen dass alles normal funktioniert

## Next Phase Readiness
- Timing-Hacks eliminiert, deterministische Koordination hergestellt
- Kein Code-Safety-Net — manuelle Verifikation bei nächstem Build empfohlen
- Phase 04 (Architektur) kann beginnen

---
*Phase: 03-stabilitaet*
*Completed: 2026-03-27*
