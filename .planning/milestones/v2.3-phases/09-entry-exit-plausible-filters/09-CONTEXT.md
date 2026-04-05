# Phase 09: Entry/Exit Pages + Plausible Filters - Context

**Gathered:** 2026-03-28
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped via autonomous)

<domain>
## Phase Boundary

Entry/Exit Pages in der Website-Detailansicht für beide Provider. Plausible-Daten per Dimension filterbar. Plausible Goals mit Conversion-Rate angezeigt.

</domain>

<decisions>
## Implementation Decisions

### Entry/Exit Pages
- In WebsiteDetailMetricsSections als neue Section "Traffic Flow" oder ähnlich einfügen
- Entry Pages (woher kommen Besucher) und Exit Pages (wo gehen sie hin)
- Umami: getEntryPages via getMetrics (type=entry) — ggf. neue Methode nötig
- Plausible: getEntryPages/getExitPages (bereits in v2.2 implementiert)

### Plausible Filter-UI
- Filter-Button/Chip in der Plausible-Detailansicht
- Dimensionen zum Filtern: UTM Source/Medium/Campaign, Country, Device, Browser
- Filter-Auswahl als Sheet oder Popover mit Picker
- Gefilterte Ergebnisse aktualisieren alle Sections der Detail-View live

### Plausible Goals
- In WebsiteDetailView für Plausible: Goals-Section mit Conversion-Rate
- getGoals() API-Methode bereits implementiert
- Darstellung: Goal-Name + Anzahl Conversions + Conversion-Rate als %

### Claude's Discretion
- Exaktes UI-Layout für Filter-Auswahl
- Ob Entry/Exit Pages als eigene Section oder in bestehende Top Pages Section integriert
- Platzierung der Goals-Section in der Detail-View

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- WebsiteDetailMetricsSections.swift: Bestehende Metric-Sections (Location, Tech, Events)
- PlausibleAPI.swift: getEntryPages, getExitPages, getGoals, PlausibleQueryFilter, buildQueryBody
- UmamiAPI.swift: Metrics-Endpunkt unterstützt type=entry/exit
- WebsiteDetailViewModel.swift: Paralleles Data Loading mit TaskGroup

### Established Patterns
- isPlausible-Check für Provider-spezifische UI
- AnalyticsMetricItem für Metric-Listen
- DateRange-Binding durch alle Sections

### Integration Points
- WebsiteDetailMetricsSections für Entry/Exit Pages
- WebsiteDetailView für Filter-UI und Goals-Section
- WebsiteDetailViewModel für neue Data-Loading Properties

</code_context>

<specifics>
## Specific Ideas

No specific requirements beyond ROADMAP success criteria.

</specifics>

<deferred>
## Deferred Ideas

None.

</deferred>
