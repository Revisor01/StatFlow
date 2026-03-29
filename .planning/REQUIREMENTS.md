# Requirements: StatFlow

**Defined:** 2026-03-29
**Core Value:** Nutzer können ihre Website-Analytics sicher und übersichtlich vom iPhone aus überwachen

## v2.6 Requirements

Design Polish: UI-Inkonsistenzen beheben, Modale vereinheitlichen, fehlende Strings ergänzen.

### Dashboard

- [ ] **DASH-01**: Die 4 Dashboard-Kacheln (Sessions, Vergleich, Events, Reports) sollen exakt gleich groß sein — Events-Kachel ist aktuell zu hoch

### Onboarding & Account

- [ ] **ACCT-01**: Fehlender String bei "Self-Hosted" im Onboarding-Flow ergänzen
- [ ] **ACCT-02**: Account-hinzufügen-Flow braucht Auswahl "Self-Hosted" vs "Offiziell" (fehlt aktuell außerhalb Onboarding)
- [ ] **ACCT-03**: Account-hinzufügen-Modal braucht einen X/Schließen-Button

### Modale

- [ ] **MODAL-01**: In den Modalen (Website, Teams, Benutzer, Webseite) sollen die Toolbar-Buttons oben nur Icons sein (X zum Schließen, Häkchen zum Bestätigen) statt Text

### Benachrichtigungen

- [ ] **NOTIF-01**: Beschreibungstexte bei den Benachrichtigungs-Einstellungen klarer und verständlicher formulieren

### Settings

- [ ] **SET-01**: Doppelte Chevrons bei "Analytics einrichten" und "Analytics Glossar" entfernen (nur ein Chevron)
- [ ] **SET-02**: Taube/Dove-Icon wird nicht angezeigt — Ursache finden und beheben

## Out of Scope

| Feature | Reason |
|---------|--------|
| Neue Features oder Screens | Fokus auf UI-Polish |
| Performance-Optimierung | Kein akutes Problem |
| Neue API-Endpunkte | Keine neuen Datenquellen nötig |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DASH-01 | Phase 16 | Pending |
| SET-01 | Phase 16 | Pending |
| SET-02 | Phase 16 | Pending |
| NOTIF-01 | Phase 16 | Pending |
| ACCT-01 | Phase 17 | Pending |
| ACCT-02 | Phase 17 | Pending |
| ACCT-03 | Phase 17 | Pending |
| MODAL-01 | Phase 17 | Pending |

**Coverage:**
- v2.6 requirements: 8 total
- Mapped to phases: 8
- Unmapped: 0

---
*Requirements defined: 2026-03-29*
