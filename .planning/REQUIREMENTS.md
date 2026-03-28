# Requirements: InsightFlow

**Defined:** 2026-03-28
**Core Value:** Nutzer können ihre Website-Analytics sicher und übersichtlich vom iPhone aus überwachen

## v2.1 Requirements

Requirements für UX Polish & Features. Aus User-Feedback nach v2.0.

### UI Polish

- [x] **UX-01**: Account-Switcher im Dashboard als kompakter Button in der Header-Zeile (neben + und Graph-Switcher) statt als großer Bereich
- [x] **UX-02**: "Abbrechen"-Button im Account-Hinzufügen-Modal entfernen wenn vom Account-Switcher geöffnet

### Bug Fixes

- [ ] **BUG-01**: Widget-Tap öffnet die Detail-Ansicht der konfigurierten Website (Deep Link)

### Features

- [ ] **FEAT-01**: "Alle"-Option im Account-Switcher — kombinierte Ansicht aller Stats über alle Analytics-Accounts hinweg

## Out of Scope

| Feature | Reason |
|---------|--------|
| Externe Dependencies | Bewusste Entscheidung, alles custom zu halten |
| iPad/macOS Support | Fokus auf bestehende iOS-App |
| Komplett neues UI-Design | v2.1 ist UX-Polish, kein Redesign |
| Neue Analytics-Provider (Matomo etc.) | Umami + Plausible reichen aktuell |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| UX-01 | Phase 1 | Complete |
| UX-02 | Phase 1 | Complete |
| BUG-01 | Phase 2 | Pending |
| FEAT-01 | Phase 3 | Pending |

**Coverage:**
- v2.1 requirements: 4 total
- Mapped to phases: 4
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-28*
