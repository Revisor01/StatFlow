# Roadmap: InsightFlow

## Milestones

- ✅ **v2.0 Code Quality & Security Hardening** - 5 phases, 15 plans, 58 tests, completed 2026-03-28 ([archive](milestones/v2.0-ROADMAP.md))
- 📋 **v2.1 UX Polish & Features** - Phases 1-3 (planned)

## Phases

### v2.1 UX Polish & Features

**Milestone Goal:** Dashboard-UX verbessern (kompakter Account-Switcher, Modal-Cleanup), Widget-Deep-Link fixen, und eine kombinierte "Alle Accounts"-Ansicht als neues Feature hinzufügen.

- [ ] **Phase 1: Dashboard UX Polish** - Account-Switcher kompakter machen, Modal-Cleanup
- [ ] **Phase 2: Widget Deep Link Fix** - Widget-Tap öffnet Website-Details
- [ ] **Phase 3: Alle-Accounts-Ansicht** - Kombinierte Stats über alle Analytics-Accounts

## Phase Details

### Phase 1: Dashboard UX Polish
**Goal**: Der Account-Switcher im Dashboard ist ein kompakter Button in der Header-Zeile (neben + und Graph-Switcher) statt eines großen separaten Bereichs. Der "Abbrechen"-Button im Account-Hinzufügen-Modal ist entfernt wenn vom Switcher geöffnet.
**Depends on**: Nothing (first phase)
**Requirements**: UX-01, UX-02
**Success Criteria** (what must be TRUE):
  1. Der Account-Switcher ist ein Button/Icon in der gleichen Zeile wie der + Button und der Graph-Switcher
  2. Der große Account-Switcher-Bereich im Dashboard ist entfernt
  3. Das Account-Hinzufügen-Modal zeigt keinen "Abbrechen"-Button wenn es vom Account-Switcher geöffnet wurde
  4. Account-Switching funktioniert weiterhin korrekt (alle Daten laden nach Switch)
**Plans:** 1 plan
Plans:
- [ ] 01-01-PLAN.md — Account-Switcher zu Toolbar-Menu umbauen + Cancel-Button entfernen
**UI hint**: yes

### Phase 2: Widget Deep Link Fix
**Goal**: Ein Tap auf das Widget öffnet die App und navigiert direkt zur Detail-Ansicht der im Widget konfigurierten Website.
**Depends on**: Nothing (independent)
**Requirements**: BUG-01
**Success Criteria** (what must be TRUE):
  1. Tap auf ein Widget mit konfigurierter Website (z.B. hmgutmann bei Umami) öffnet direkt die WebsiteDetailView für diese Website
  2. Wenn der aktive Account nicht zum Widget-Account passt, wird automatisch zum richtigen Account gewechselt
  3. Der Deep Link funktioniert für Umami- und Plausible-Widgets
**Plans**: TBD

### Phase 3: Alle-Accounts-Ansicht
**Goal**: Im Account-Switcher gibt es eine "Alle"-Option, die eine kombinierte Ansicht aller Stats über alle Analytics-Accounts zeigt.
**Depends on**: Phase 1 (neuer Account-Switcher)
**Requirements**: FEAT-01
**Success Criteria** (what must be TRUE):
  1. Im Account-Switcher gibt es eine "Alle"-Option neben den einzelnen Accounts
  2. Bei Auswahl von "Alle" zeigt das Dashboard alle Websites von allen Accounts in einer Liste
  3. Jede Website-Card zeigt den zugehörigen Account/Provider als Badge
  4. Tap auf eine Website navigiert wie gewohnt zur Detail-Ansicht (mit automatischem Account-Switch falls nötig)
**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in order: 1 → 2 → 3 (Phase 2 könnte parallel zu Phase 1)

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Dashboard UX Polish | 0/1 | Planning done | - |
| 2. Widget Deep Link Fix | 0/? | Not started | - |
| 3. Alle-Accounts-Ansicht | 0/? | Not started | - |
