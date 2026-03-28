# Phase 3: Alle-Accounts-Ansicht - Context

**Gathered:** 2026-03-28
**Status:** Ready for planning

<domain>
## Phase Boundary

"Alle"-Option im Account-Switcher-Menu. Bei Auswahl zeigt das Dashboard alle Websites von allen Accounts in einer gemeinsamen Liste mit Provider-Badge pro Card.

Requirements: FEAT-01

</domain>

<decisions>
## Implementation Decisions

### Layout-Entscheidung
- Einfache flache Liste aller Websites (KEINE Gruppierung nach Account)
- Jede WebsiteCard bekommt ein Provider-Badge (z.B. kleines "Umami" oder "Plausible" Label)
- Keine Aggregation der Stats — jede Website zeigt ihre eigenen Daten

### Account-Switcher Menu
- "Alle" als erste Option im Dropdown-Menu (vor den einzelnen Accounts)
- Icon: z.B. `rectangle.stack` oder `square.grid.2x2` für "Alle"
- Wenn "Alle" aktiv: Menu-Icon wechselt zum "Alle"-Icon (nicht Provider-spezifisch)

### Daten-Laden
- Bei "Alle"-Modus: Alle Accounts durchiterieren, pro Account die Websites laden
- DashboardViewModel braucht einen "Alle"-Modus der über alle Provider Websites sammelt
- Tap auf eine Website: automatisch zum richtigen Account wechseln, dann Detail-View öffnen

### Claude's Discretion
- Badge-Design (Größe, Farbe, Position auf der Card)
- Lade-Reihenfolge der Accounts
- Handling von Lade-Fehlern einzelner Accounts im "Alle"-Modus

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `accountSwitcherMenu` in DashboardView.swift (Phase 1) — erweitern um "Alle"-Option
- `WebsiteCard` — bestehendes Card-Design, Badge hinzufügen
- `DashboardViewModel` — `loadData()` erweitern für Multi-Account
- `AccountManager.shared.accounts` — Liste aller Accounts

### Integration Points
- DashboardView.swift: accountSwitcherMenu (Zeilen 201-236)
- DashboardView.swift: Picker binding für Account-Wechsel
- DashboardViewModel: loadData() muss Multi-Account-Modus unterstützen
- WebsiteCard: Provider-Badge als neues UI-Element

</code_context>

<specifics>
## Specific Ideas

- Provider-Badge: Kleines farbiges Label (Orange "Umami", Blau "Plausible") oben rechts oder unter dem Website-Namen
- "Alle"-Option im Menu mit eigenem Icon

</specifics>

<deferred>
## Deferred Ideas

- Aggregierte Gesamt-Stats über alle Accounts (Summe aller Visitors etc.)
- Filterung nach Provider im "Alle"-Modus

</deferred>
