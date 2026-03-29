# Roadmap: StatFlow

## Milestones

- ✅ **v2.0 Code Quality & Security Hardening** - 5 phases, 15 plans, 58 tests, completed 2026-03-28 ([archive](milestones/v2.0-ROADMAP.md))
- ✅ **v2.1 UX Polish & Features** - 3 phases, 3 plans, completed 2026-03-28 ([archive](milestones/v2.1-ROADMAP.md))
- ✅ **v2.2 Support & API Coverage** - 4 phases, 8 plans, completed 2026-03-28 ([archive](milestones/v2.2-ROADMAP.md))
- ✅ **v2.3 API Data Screens & Analytics Setup** - 4 phases, 8 plans, completed 2026-03-28 ([archive](milestones/v2.3-ROADMAP.md))
- ✅ **v2.4 Rename to StatFlow** - 1 phase, completed 2026-03-28
- ✅ **v2.5 Pre-Release Polish** - 3 phases, 7 plans, completed 2026-03-29 ([archive](milestones/v2.5-ROADMAP.md))
- 🔄 **v2.6 Design Polish** - 2 phases, active

---

## v2.6 Design Polish

### Phases

- [ ] **Phase 16: UI & Layout Fixes** - Dashboard-Kacheln egalisieren, Settings-Chevrons bereinigen, Dove-Icon reparieren, Notification-Texte schärfen
- [ ] **Phase 17: Modale & Account-Flow** - Account-hinzufügen-Flow vervollständigen, Modal-Toolbar auf Icons vereinheitlichen

### Phase Details

### Phase 16: UI & Layout Fixes
**Goal**: Visuelle Inkonsistenzen in Dashboard, Settings und Benachrichtigungen sind behoben
**Depends on**: Phase 15 (v2.5 abgeschlossen)
**Requirements**: DASH-01, SET-01, SET-02, NOTIF-01
**Success Criteria** (what must be TRUE):
  1. Alle 4 Dashboard-Kacheln (Sessions, Vergleich, Events, Reports) sind gleich hoch
  2. Bei "Analytics einrichten" und "Analytics Glossar" erscheint nur ein Chevron statt zwei
  3. Das Dove-Icon wird in der Settings-View korrekt angezeigt
  4. Die Beschreibungstexte der Benachrichtigungs-Einstellungen sind klar und verständlich formuliert
**Plans**: 1 plan
Plans:
- [ ] 16-01-PLAN.md — Alle vier UI-Fixes: Kachelhöhe, Chevrons, Dove-Icon, Notification-Strings
**UI hint**: yes

### Phase 17: Modale & Account-Flow
**Goal**: Account-hinzufügen-Flow und Modale sind vollständig und konsistent bedienbar
**Depends on**: Phase 16
**Requirements**: ACCT-01, ACCT-02, ACCT-03, MODAL-01
**Success Criteria** (what must be TRUE):
  1. Im Onboarding erscheint der fehlende "Self-Hosted"-String korrekt
  2. Beim Hinzufügen eines Accounts außerhalb des Onboardings ist die Auswahl "Self-Hosted vs. Offiziell" vorhanden
  3. Das Account-hinzufügen-Modal hat einen X/Schließen-Button
  4. In den Modalen (Website, Teams, Benutzer, Webseite) zeigen die Toolbar-Buttons nur Icons (X und Häkchen) statt Text
**Plans**: 1 plan
Plans:
- [ ] 16-01-PLAN.md — Alle vier UI-Fixes: Kachelhöhe, Chevrons, Dove-Icon, Notification-Strings
**UI hint**: yes

### Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 16. UI & Layout Fixes | 0/? | Not started | - |
| 17. Modale & Account-Flow | 0/? | Not started | - |
