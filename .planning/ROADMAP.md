# Roadmap: InsightFlow

## Milestones

- ✅ **v2.0 Code Quality & Security Hardening** - 5 phases, 15 plans, 58 tests, completed 2026-03-28 ([archive](milestones/v2.0-ROADMAP.md))
- ✅ **v2.1 UX Polish & Features** - 3 phases, 3 plans, completed 2026-03-28 ([archive](milestones/v2.1-ROADMAP.md))
- ✅ **v2.2 Support & API Coverage** - 4 phases, 8 plans, completed 2026-03-28 ([archive](milestones/v2.2-ROADMAP.md))
- **v2.3 API Data Screens & Analytics Setup** - 4 phases, active

## Phases

- [x] **Phase 08: Events & Reports Screens** - Umami Events- und Reports-Views als neue Screens in der App (completed 2026-03-28)
- [ ] **Phase 09: Entry/Exit Pages + Plausible Filters** - Herkunfts-/Absprung-Daten und Plausible Goals mit Filter-UI
- [ ] **Phase 10: Analytics Setup** - Tracking-Code auf echten Websites aktivieren, Goals definieren, Datenfluss sicherstellen
- [ ] **Phase 11: In-App Data Guide** - Erklärungen zu Analytics-Begriffen direkt in der App

## Phase Details

### Phase 08: Events & Reports Screens
**Goal**: Nutzer können Umami-Events und Reports-Daten direkt in der App einsehen
**Depends on**: Nothing (first phase of v2.3, API-Infrastruktur aus v2.2 vorhanden)
**Requirements**: SCREEN-01, SCREEN-02
**Success Criteria** (what must be TRUE):
  1. Nutzer kann eine Liste aller Events einer Umami-Website öffnen und einzelne Events mit ihren Statistiken (Anzahl, einzigartige Nutzer) einsehen
  2. Nutzer kann Reports zu Funnels, UTM-Kampagnen, Goal-Tracking und Attribution für eine Umami-Website aufrufen
  3. Events- und Reports-Screens sind über die bestehende Website-Detailansicht erreichbar
  4. Leere States (keine Events, keine Reports) werden sauber angezeigt
**Plans**: 3 plans
Plans:
- [x] 08-01-PLAN.md — Events-Screen (Liste + Detail Drill-Down) mit ViewModel
- [x] 08-02-PLAN.md — Reports-Hub (4 Karten) und Detail-Views (Funnel, UTM, Goals, Attribution)
- [x] 08-03-PLAN.md — Integration in WebsiteDetailView Quick Actions + visuelle Verifikation
**UI hint**: yes

### Phase 09: Entry/Exit Pages + Plausible Filters
**Goal**: Nutzer sehen Einstiegs- und Absprungseiten sowie gefilterte Plausible-Daten
**Depends on**: Phase 08
**Requirements**: SCREEN-03, SCREEN-04
**Success Criteria** (what must be TRUE):
  1. Nutzer kann in der Website-Detailansicht sehen, über welche Seiten Besucher einsteigen und die Website verlassen
  2. Nutzer kann Plausible-Daten nach Dimensionen (UTM, Gerät, Browser, Land) filtern und das Ergebnis live in der bestehenden Ansicht sehen
  3. Plausible Goals werden in der Website-Detailansicht angezeigt mit Conversion-Rate und absoluten Werten
**Plans**: TBD
**UI hint**: yes

### Phase 10: Analytics Setup
**Goal**: Eigenes Analytics-Tracking auf mindestens einer Website ist aktiv und liefert echte Daten in die App
**Depends on**: Phase 09
**Requirements**: SETUP-01
**Success Criteria** (what must be TRUE):
  1. Tracking-Code (Umami oder Plausible) ist auf mindestens einer eigenen Website eingebunden und sendet echte Pageviews
  2. Mindestens ein Goal ist definiert und erscheint in der App unter Phase-09-Screens
  3. Die App zeigt echte Daten (nicht Mock/Demo) für die eingerichtete Website
**Plans**: TBD

### Phase 11: In-App Data Guide
**Goal**: Nutzer verstehen, was die angezeigten Analytics-Metriken bedeuten und wie sie sie nutzen können
**Depends on**: Phase 10
**Requirements**: GUIDE-01
**Success Criteria** (what must be TRUE):
  1. Zu den wichtigsten Metriken (Bounce Rate, Session Duration, Referrer, UTM-Parameter, Funnels) gibt es in der App erreichbare Erklärungen
  2. Ein Nutzer ohne Analytics-Vorwissen kann anhand der Erklärungen verstehen, was ein Funnel ist und warum eine hohe Bounce Rate problematisch sein kann
  3. Die Erklärungen sind von den jeweiligen Screens aus erreichbar (kontextsensitiv oder zentral)
**Plans**: TBD
**UI hint**: yes

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 08. Events & Reports Screens | 3/3 | Complete   | 2026-03-28 |
| 09. Entry/Exit Pages + Plausible Filters | 0/? | Not started | - |
| 10. Analytics Setup | 0/? | Not started | - |
| 11. In-App Data Guide | 0/? | Not started | - |
