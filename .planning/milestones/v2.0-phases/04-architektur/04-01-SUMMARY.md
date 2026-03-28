---
phase: 04-architektur
plan: 01
subsystem: api
tags: [swift, actor, concurrency, plausible, async-await]

# Dependency graph
requires:
  - phase: 03-stabilitaet
    provides: Timing-Hacks entfernt, async/await Koordination eingerichtet
provides:
  - PlausibleAPI als Swift actor mit nonisolated Keychain-Properties
  - Einheitliches actor-Concurrency-Pattern fuer beide API-Clients (Umami + Plausible)
affects: [05-tests, AccountManager, AdminView, DashboardView, NotificationManager]

# Tech tracking
tech-stack:
  added: []
  patterns: [Swift actor statt @MainActor class fuer API-Clients, await MainActor.run fuer @MainActor-Aufrufe aus actor, nonisolated fuer Keychain-Properties]

key-files:
  created: []
  modified:
    - InsightFlow/Services/PlausibleAPI.swift
    - InsightFlow/Services/AccountManager.swift
    - InsightFlow/Services/NotificationManager.swift
    - InsightFlow/Views/Admin/AdminView.swift
    - InsightFlow/Views/Dashboard/DashboardView.swift

key-decisions:
  - "actor-Pattern fuer beide API-Clients (UmamiAPI + PlausibleAPI): Einheitliches Swift Concurrency Modell, kein @MainActor fuer API-Logik"
  - "await MainActor.run statt Task-Wrapping fuer @MainActor-Aufrufe aus actor-Methoden: Saubere async-Kette statt Fire-and-Forget"
  - "reconfigureFromKeychain() als No-Op: PlausibleAPI hat keinen internen State, liest alles aus Keychain via nonisolated computed properties"

patterns-established:
  - "Actor-Isolation-Pattern: @MainActor-Klassen aus actor immer via await MainActor.run aufrufen"
  - "nonisolated fuer Funktionen die nur nonisolated Properties lesen (z.B. getTrackingCode)"
  - "PlausibleSitesManager.objectWillChange.send() im Aufrufer (AccountManager), nicht in PlausibleAPI selbst"

requirements-completed: [ARCH-03]

# Metrics
duration: 15min
completed: 2026-03-28
---

# Phase 4 Plan 01: PlausibleAPI actor-Umstellung Summary

**PlausibleAPI von @MainActor class auf Swift actor umgestellt — einheitliches Concurrency-Modell mit UmamiAPI, alle @MainActor-Aufrufe via await MainActor.run abgesichert**

## Performance

- **Duration:** 15 min
- **Started:** 2026-03-28T03:32:00Z
- **Completed:** 2026-03-28T03:37:36Z
- **Tasks:** 2 (+ 1 Deviation-Fix)
- **Files modified:** 5

## Accomplishments
- PlausibleAPI ist jetzt ein Swift actor (nicht mehr @MainActor class, kein ObservableObject)
- Alle Protocol-Properties (serverURL, isAuthenticated, apiKey) sind nonisolated und lesen aus Keychain
- AccountManager ruft reconfigureFromKeychain() korrekt mit await auf (in Task-Block)
- PlausibleSitesManager.objectWillChange.send() liegt jetzt im AccountManager

## Task Commits

Jeder Task wurde atomar committed:

1. **Task 1: PlausibleAPI von @MainActor class auf actor umstellen** - `9e21987` (feat)
2. **Task 2: AccountManager fuer actor-basierte PlausibleAPI anpassen** - `186786c` (feat)
3. **Deviation: Actor-Isolation Fehler beheben** - `38e75c7` (fix)

## Files Created/Modified
- `InsightFlow/Services/PlausibleAPI.swift` - actor statt @MainActor class, nonisolated Properties, @MainActor-Aufrufe via await MainActor.run
- `InsightFlow/Services/AccountManager.swift` - await-Aufruf fuer reconfigureFromKeychain(), PlausibleSitesManager-Notification hierher verschoben
- `InsightFlow/Services/NotificationManager.swift` - reconfigureFromKeychain mit await
- `InsightFlow/Views/Admin/AdminView.swift` - removeSite mit await
- `InsightFlow/Views/Dashboard/DashboardView.swift` - removeSite mit await

## Decisions Made
- `await MainActor.run { }` statt `Task { await MainActor.run { } }` fuer synchrone @MainActor-Aufrufe aus async-Methoden im actor — sauberere Kette ohne Fire-and-Forget
- `removeSite()` zu `async func` gemacht statt synchrones Task-Wrapping — ermoeglicht `await`-Aufrufe aus bestehenden `async`-Methoden in AdminView und DashboardView
- `getTrackingCode()` als `nonisolated` markiert — liest nur `serverURL` (selbst nonisolated), kein actor-State involviert

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Actor-Isolation Compiler-Fehler nach Umstellung**
- **Found during:** Verification Build nach Task 1 und 2
- **Issue:** Mehrere Aufrufstellen von PlausibleAPI und AnalyticsManager (@MainActor) wurden nicht angepasst: AnalyticsManager.saveProviderType, PlausibleSitesManager.addSite/removeSite/sites, getTrackingCode in NotificationManager, AdminView, DashboardView
- **Fix:** @MainActor-Aufrufe in async-Methoden mit `await MainActor.run { }` gewrappt; removeSite() zu async func; getTrackingCode() als nonisolated markiert; alle Aufrufer angepasst
- **Files modified:** PlausibleAPI.swift, NotificationManager.swift, AdminView.swift, DashboardView.swift
- **Verification:** xcodebuild BUILD SUCCEEDED
- **Committed in:** `38e75c7`

---

**Total deviations:** 1 auto-fixed (Rule 1 - Bug)
**Impact on plan:** Notwendig fuer Build-Erfolg. Plan beschreibt nur PlausibleAPI und AccountManager — alle anderen betroffenen Aufrufer mussten ebenfalls angepasst werden. Kein Scope-Creep.

## Issues Encountered
- Build schlug nach den geplanten Aenderungen fehl, weil mehrere Aufrufer in anderen Dateien nicht im Plan aufgefuehrt waren. Alle Fehler waren direkte Konsequenz der actor-Umstellung (Rule 1 - direkter Kausalbezug) und wurden automatisch behoben.

## Next Phase Readiness
- PlausibleAPI und UmamiAPI nutzen jetzt beide das gleiche actor-Concurrency-Pattern
- Vorbereitung fuer 04-02 (Auth-Konsolidierung): beide API-Clients haben saubere async-Interfaces
- Kein manuelles Testing erforderlich fuer diese strukturelle Aenderung (keine Logik geaendert, nur Isolation)

---
*Phase: 04-architektur*
*Completed: 2026-03-28*
