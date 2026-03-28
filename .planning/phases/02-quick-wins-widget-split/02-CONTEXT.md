# Phase 2: Quick Wins & Widget Split - Context

**Gathered:** 2026-03-28
**Status:** Ready for planning
**Mode:** Infrastructure phase — discuss skipped (pure refactoring/code structure)

<domain>
## Phase Boundary

Der Code ist aufgeräumt und besser navigierbar. Print-Statements sind auf Debug-Builds beschränkt, der 2004-Zeilen Widget-Monolith ist in separate Dateien aufgeteilt, und die größten Views haben ausgelagerte Subviews.

Requirements: STAB-03, STRUC-01, STRUC-02

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — pure infrastructure/refactoring phase. Key technical context:

- Phase 1 (Security Hardening) hat AccountManager und SharedCredentials modifiziert — Widget-Code liest jetzt encrypted `widget_accounts.encrypted` statt plaintext JSON
- Print-Statements: 66 `print()` calls über 21 Dateien — alle in `#if DEBUG` wrappen oder entfernen
- Widget-Monolith: `InsightFlowWidget/InsightFlowWidget.swift` (2004 Zeilen) enthält Models, Credential Storage, API Networking, UI Views, Cache Logic und App Intents — in separate Dateien aufteilen
- Große Views: `WebsiteDetailView.swift` (1611), `AdminView.swift` (1318), `CompareView.swift` (1183) — Subviews extrahieren
- Widget verwendet Swift 5.0, Main App Swift 6.0 — beim Split beachten
- Xcode 16+ mit `PBXFileSystemSynchronizedRootGroup` — neue Dateien werden automatisch erkannt

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `// MARK: -` sections in Widget-Datei geben natürliche Trennlinien vor
- Existierende View-Komposition via computed properties (headerSection, dateRangePicker, etc.)
- `FlowLayout` in WebsiteCard.swift als Beispiel für ausgelagerte Layout-Komponenten

### Established Patterns
- Views dekomponieren in computed properties für Sections
- Services/Managers als separate Dateien in InsightFlow/Services/
- Widget-Resources in InsightFlowWidget/Resources/

### Integration Points
- Widget Extension teilt Code über App Group
- `InsightFlowWidget.swift` enthält `WidgetAccountsStorage` (gerade in Phase 1 modifiziert für Encryption)
- Xcode project.pbxproj muss neue Dateien nicht manuell registrieren (PBXFileSystemSynchronizedRootGroup)

</code_context>

<specifics>
## Specific Ideas

No specific requirements — infrastructure phase. Refer to ROADMAP phase description and success criteria.

</specifics>

<deferred>
## Deferred Ideas

None — infrastructure phase.

</deferred>
