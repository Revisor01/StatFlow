# Requirements: StatFlow

**Defined:** 2026-03-28
**Core Value:** Nutzer können ihre Website-Analytics sicher und übersichtlich vom iPhone aus überwachen

## v2.5 Requirements

Pre-Release Polish: Kritische Bugs fixen, toten Code aufräumen, README neu, Repo umbenennen.

### Bug Fixes

- [ ] **FIX-01**: Widget Sync Race Condition — Widget zeigt nach Account-Wechsel zuverlässig aktuelle Daten
- [ ] **FIX-02**: Request Cancellation — Offene API-Requests abbrechen wenn User von View weg-navigiert
- [ ] **FIX-03**: Cache Cleanup — LRU Eviction bei >100MB + Expired-Entry Cleanup beim App-Start
- [ ] **FIX-04**: Account Switch Loading State — Expliziter Loading-State, keine Flash alter Daten

### Code Cleanup

- [ ] **CLEAN-01**: ~20 ungenutzte Admin/Write API-Methoden aus UmamiAPI.swift entfernen
- [ ] **CLEAN-02**: Offline-Mode UI — Cached Daten mit "Offline"-Indikator anzeigen statt Fehler-Screen

### Dokumentation & Repo

- [ ] **README-01**: README.md neu schreiben — Feature-Liste, Architektur-Überblick, Screenshots-Platzhalter, Setup-Anleitung
- [ ] **REPO-01**: GitHub Repo von Revisor01/PrivacyFlow zu Revisor01/StatFlow umbenennen

## Out of Scope

| Feature | Reason |
|---------|--------|
| View-Dateien aufteilen (DashboardView 1139 Zeilen) | Funktioniert, rein kosmetisch |
| JSON Decoder konsolidieren | Funktioniert, geringe Priorität |
| Retry-Logik für API-Requests | Nice-to-have, nicht blockernd |
| Performance-Optimierung Dashboard | Erst relevant bei 20+ Websites |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| FIX-01 | Phase 13 | Pending |
| FIX-02 | Phase 13 | Pending |
| FIX-03 | Phase 13 | Pending |
| FIX-04 | Phase 13 | Pending |
| CLEAN-01 | Phase 14 | Pending |
| CLEAN-02 | Phase 14 | Pending |
| README-01 | Phase 15 | Pending |
| REPO-01 | Phase 15 | Pending |

**Coverage:**
- v2.5 requirements: 8 total
- Mapped to phases: 8
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-28*
