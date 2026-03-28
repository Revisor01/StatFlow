# Roadmap: StatFlow

## Milestones

- ✅ **v2.0 Code Quality & Security Hardening** - 5 phases, 15 plans, 58 tests, completed 2026-03-28 ([archive](milestones/v2.0-ROADMAP.md))
- ✅ **v2.1 UX Polish & Features** - 3 phases, 3 plans, completed 2026-03-28 ([archive](milestones/v2.1-ROADMAP.md))
- ✅ **v2.2 Support & API Coverage** - 4 phases, 8 plans, completed 2026-03-28 ([archive](milestones/v2.2-ROADMAP.md))
- ✅ **v2.3 API Data Screens & Analytics Setup** - 4 phases, 8 plans, completed 2026-03-28 ([archive](milestones/v2.3-ROADMAP.md))
- ✅ **v2.4 Rename to StatFlow** - 1 phase, completed 2026-03-28
- 🚧 **v2.5 Pre-Release Polish** - 3 phases, active

## Phases

- [ ] **Phase 13: Critical Bug Fixes** — Widget Sync, Request Cancellation, Cache Cleanup, Loading State
- [ ] **Phase 14: Code Cleanup** — Orphaned API-Methoden entfernen, Offline-Mode UI
- [ ] **Phase 15: README & Repo** — README.md neu schreiben, GitHub Repo umbenennen

## Phase Details

### Phase 13: Critical Bug Fixes
**Goal**: Die 4 kritischsten Bugs fixen die das App Store Review oder die User Experience gefährden
**Depends on**: Nothing
**Requirements**: FIX-01, FIX-02, FIX-03, FIX-04
**Success Criteria** (what must be TRUE):
  1. Widget zeigt nach Account-Wechsel innerhalb von 5 Sekunden die korrekten Daten
  2. Navigiert der User weg, werden laufende API-Requests abgebrochen (kein Background-Battery-Drain)
  3. Cache wird beim App-Start bereinigt (Einträge >7 Tage gelöscht, Gesamtgröße <100MB)
  4. Account-Wechsel zeigt Loading-Indikator statt Flash alter Daten
**Plans**: TBD

### Phase 14: Code Cleanup
**Goal**: Toten Code entfernen und Offline-Erlebnis verbessern
**Depends on**: Phase 13
**Requirements**: CLEAN-01, CLEAN-02
**Success Criteria** (what must be TRUE):
  1. UmamiAPI.swift enthält keine ungenutzten Admin/Write-Methoden mehr (~20 Methoden weniger)
  2. Im Offline-Modus zeigt die App cached Daten mit sichtbarem "Offline"-Indikator
**Plans**: TBD

### Phase 15: README & Repo
**Goal**: Öffentliche Präsenz aufpolieren — README als Landing Page, Repo-Name aktuell
**Depends on**: Phase 14
**Requirements**: README-01, REPO-01
**Success Criteria** (what must be TRUE):
  1. README.md enthält Feature-Liste, Architektur-Überblick, Screenshots-Platzhalter und Setup-Anleitung
  2. GitHub Repo heißt Revisor01/StatFlow (Redirect von PrivacyFlow aktiv)
**Plans**: TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 13. Critical Bug Fixes | 0/? | Not started | - |
| 14. Code Cleanup | 0/? | Not started | - |
| 15. README & Repo | 0/? | Not started | - |
