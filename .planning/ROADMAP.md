# Roadmap: InsightFlow

## Milestones

- ✅ **v2.0 Code Quality & Security Hardening** - 5 phases, 15 plans, 58 tests, completed 2026-03-28 ([archive](milestones/v2.0-ROADMAP.md))
- ✅ **v2.1 UX Polish & Features** - 3 phases, 3 plans, completed 2026-03-28 ([archive](milestones/v2.1-ROADMAP.md))
- 🚧 **v2.2 Support & API Coverage** - Phases 04-07 (in progress)

## Phases

### 🚧 v2.2 Support & API Coverage (In Progress)

**Milestone Goal:** App unterstützt vollständige Umami- und Plausible-API-Abdeckung, bietet eine einheitliche Support-Option und verbesserte Push-Benachrichtigungs-Strukturierung.

- [x] **Phase 04: Support & Branding** - Einheitliche Support-Option und Branding über alle Apps (completed 2026-03-28)
- [ ] **Phase 05: Umami API Coverage** - Vollständige Abdeckung aller Umami Self-Hosted API-Endpunkte
- [ ] **Phase 06: Plausible API Coverage** - Vollständige Abdeckung aller Plausible CE Self-Hosted API-Endpunkte
- [ ] **Phase 07: Push-Benachrichtigungen** - Strukturierte Gruppierung der Benachrichtigungs-Logik

## Phase Details

### Phase 04: Support & Branding
**Goal**: Nutzer können die App über eine einheitliche Support-Option unterstützen, und die App präsentiert ein kohärentes Branding
**Depends on**: Phase 03 (v2.1)
**Requirements**: SUP-01, SUP-02
**Success Criteria** (what must be TRUE):
  1. Nutzer sehen in den Einstellungen eine "Support"-Option mit einheitlichem Design (konsistent mit ValetudiOS / PrivacyFlow)
  2. Nutzer können via Tap einen Einmal-Tip (z.B. "Buy me a Coffee") abschließen
  3. App zeigt im Info-/About-Bereich den Claim "Mit Liebe in Hennstedt gemacht"
  4. Easter-Egg mit Segens-Bezug ist für Nutzer mit Pastor-Kontext auffindbar (aber nicht aufdringlich)
**Plans**: 1 plan
Plans:
- [x] 04-01-PLAN.md — SupportView Redesign (SF Symbols, clean design) + Branding-Untertitel im Footer
**UI hint**: yes

### Phase 05: Umami API Coverage
**Goal**: InsightFlow deckt alle verfügbaren Umami Self-Hosted API-Endpunkte ab, sodass keine Daten verloren gehen
**Depends on**: Phase 04
**Requirements**: API-01
**Success Criteria** (what must be TRUE):
  1. Alle dokumentierten Umami Self-Hosted API-Endpunkte sind auditiert und fehlende implementiert
  2. Nutzer sehen in der Detailansicht alle Metriken, die die Umami API bereitstellt
  3. Keine relevanten Umami-Datenpunkte fehlen im Vergleich zur Umami-Weboberfläche
**Plans**: 4 plans
Plans:
- [x] 05-01-PLAN.md — Response-Modelle fuer alle fehlenden Umami-API-Endpunkte
- [x] 05-02-PLAN.md — High-Priority Endpunkte: Stats, Sessions, Events, Me
- [ ] 05-03-PLAN.md — Report-Endpunkte: CRUD + 7 spezialisierte Reports
- [ ] 05-04-PLAN.md — Teams, Users, Share, Admin Vervollstaendigung

### Phase 06: Plausible API Coverage
**Goal**: InsightFlow deckt alle verfügbaren Plausible CE Self-Hosted API-Endpunkte ab
**Depends on**: Phase 05
**Requirements**: API-02
**Success Criteria** (what must be TRUE):
  1. Alle dokumentierten Plausible CE Self-Hosted API-Endpunkte sind auditiert und fehlende implementiert
  2. Nutzer sehen in der Detailansicht alle Metriken, die die Plausible API bereitstellt
  3. Keine relevanten Plausible-Datenpunkte fehlen im Vergleich zur Plausible-Weboberfläche
**Plans**: TBD

### Phase 07: Push-Benachrichtigungen
**Goal**: Push-Benachrichtigungen sind strukturiert gruppiert und skalieren auch bei vielen überwachten Websites
**Depends on**: Phase 06
**Requirements**: NOTIF-01
**Success Criteria** (what must be TRUE):
  1. Benachrichtigungen erscheinen in der Notification Center strukturiert gruppiert (z.B. nach Website oder Provider)
  2. Bei 10+ überwachten Websites entsteht kein unübersichtlicher Benachrichtigungs-Flood
  3. Nutzer können Benachrichtigungs-Gruppen in den Einstellungen nachvollziehen
**Plans**: TBD

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 04. Support & Branding | v2.2 | 1/1 | Complete    | 2026-03-28 |
| 05. Umami API Coverage | v2.2 | 0/4 | In progress | - |
| 06. Plausible API Coverage | v2.2 | 0/TBD | Not started | - |
| 07. Push-Benachrichtigungen | v2.2 | 0/TBD | Not started | - |
