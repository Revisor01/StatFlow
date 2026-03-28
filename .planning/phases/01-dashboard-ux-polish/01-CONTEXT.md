# Phase 1: Dashboard UX Polish - Context

**Gathered:** 2026-03-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Der Account-Switcher im Dashboard ist ein kompakter Button in der Header-Zeile mit Provider-Icon, der ein Dropdown-Menu öffnet. Der "Abbrechen"-Button im Account-Hinzufügen-Modal ist entfernt.

Requirements: UX-01, UX-02

</domain>

<decisions>
## Implementation Decisions

### Account-Switcher Design (UX-01)
- Button zeigt das Provider-Icon des aktiven Accounts (Umami-Logo oder Plausible-Logo)
- Button sitzt in der Toolbar-Zeile neben + und Graph-Switcher
- Tap öffnet ein SwiftUI `.menu {}` Dropdown (NICHT Sheet, NICHT NavigationLink)
- Dropdown zeigt alle Accounts mit Icon + Name, aktiver Account markiert
- Dropdown hat "Konto hinzufügen" Option am Ende
- Der große Account-Switcher-Bereich (Zeilen 344-381 in DashboardView.swift) wird komplett entfernt
- Button wird nur angezeigt wenn `accountManager.hasMultipleAccounts == true` (wie bisher)

### Cancel-Button (UX-02)
- Cancel-Button im AddAccountView (Zeile 627) komplett entfernen
- NavigationStack Back-Button reicht

### Claude's Discretion
- Genaue Icon-Größe und Positionierung in der Toolbar
- Dropdown-Styling (Standard SwiftUI Menu)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `accountSwitcherButton` (DashboardView.swift:344-381) — zu ersetzen
- `AccountSwitcherSheet` (DashboardView.swift:386-438) — wird durch Menu ersetzt
- `AccountRow` (DashboardView.swift:440-478) — Kann als Basis für Menu-Items dienen
- `AddAccountView` (DashboardView.swift:482-632) — Cancel-Button entfernen
- Provider-Icons: `providerType.icon` gibt SF Symbol Name

### Established Patterns
- Toolbar-Buttons verwenden `ToolbarItem(placement:)` mit SF Symbols
- `@ObservedObject private var accountManager = AccountManager.shared`
- `.sheet()` Modifier für Modals

### Integration Points
- DashboardView.swift Toolbar (Zeilen 73-127)
- accountSwitcherButton (Zeilen 344-381) — entfernen
- AccountSwitcherSheet (Zeilen 386-438) — entfernen
- AddAccountView Cancel-Button (Zeile 627) — entfernen

</code_context>

<specifics>
## Specific Ideas

- Provider-Icon im Toolbar-Button (Umami/Plausible Logo)
- SwiftUI Menu {} für Dropdown statt Sheet
- Aktiver Account mit Checkmark im Menu

</specifics>

<deferred>
## Deferred Ideas

None.

</deferred>
