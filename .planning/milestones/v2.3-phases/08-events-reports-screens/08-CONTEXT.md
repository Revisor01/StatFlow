# Phase 08: Events & Reports Screens - Context

**Gathered:** 2026-03-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Neue Views für Umami Events (Liste + Drill-Down Details) und Reports (Funnel, UTM, Goals, Attribution) als Hub mit Detail-Screens. Integration in bestehende WebsiteDetailView über erweiterte Quick Actions Section.

</domain>

<decisions>
## Implementation Decisions

### Events-Screen
- Liste + Drill-Down Pattern (wie bestehende SessionsView): Event-Liste → Tap → Event-Detail mit Statistiken, Properties, Timeseries-Chart
- Event-Liste zeigt Event-Name + Anzahl + Trend
- Event-Detail zeigt: Statistiken (Unique Users, Total Count), Properties-Liste, Timeseries-Chart
- Nur für Umami-Websites (Plausible hat keine Custom Events im gleichen Sinne)

### Reports-Hub
- Neuer "Reports"-Button als QuickActionCard in der Quick Actions Section der WebsiteDetailView
- Öffnet Reports-Übersicht mit 4 Karten: Funnel, UTM, Goals, Attribution
- Tap auf Karte → Report-Detail-View mit den jeweiligen Daten
- Nur für Umami-Websites (Reports-API ist Umami-spezifisch)

### Navigation/Integration
- Quick Actions Section erweitern: bestehende (Sessions, Compare) + neue (Events, Reports)
- Bestehende QuickActionCard UI-Pattern wiederverwenden
- Events und Reports sind nur bei Umami-Provider sichtbar (isPlausible-Check)

### Claude's Discretion
- Exaktes Layout der Report-Detail-Views (Funnel als Steps, UTM als Tabelle, Goals als Liste, Attribution als Chart)
- Empty States Design für Events ohne Daten / Reports ohne konfigurierte Reports
- Ob Reports-Hub als Sheet oder NavigationLink aufgeht
- Chart-Stil für Event-Timeseries (Line vs. Bar — bestehendes Chart-System nutzen)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- WebsiteDetailSupportingViews.swift: QuickActionCard, SectionHeader, GlassCard, HeroStatCard
- WebsiteDetailChartSection.swift: Line/Bar Charts mit Gradient, Point Selection, Axis Labels
- WebsiteDetailViewModel.swift: Paralleles Data Loading mit TaskGroup
- SessionsView.swift: Liste + Drill-Down Pattern (Referenz für Events)
- UmamiAPI.swift: Alle Event-Endpoints (getEvents, getEventsDetail, getEventData*, getEventStats) + Report-Endpoints (getFunnelReport, getUTMReport, getGoalReport, getAttributionReport)

### Established Patterns
- Provider-Check: `AnalyticsManager.shared.providerType == .plausible` für bedingte UI
- @Binding selectedDateRange propagiert durch alle Chart/Metric-Komponenten
- AnalyticsCacheService für API-Response-Caching
- NavigationLink für Drill-Down (Sessions, Pages, Retention)

### Integration Points
- WebsiteDetailView Quick Actions Section (nach Sessions + Compare)
- WebsiteDetailViewModel für Data Loading (neue Published properties)
- Navigation: Von Quick Actions → EventsView / ReportsHubView

</code_context>

<specifics>
## Specific Ideas

- Events-Screen soll sich anfühlen wie SessionsView (Liste → Detail Drill-Down)
- Reports-Hub mit 4 Karten als Einstiegspunkt (visuell ansprechend, nicht nur Liste)
- Quick Actions bleiben horizontal scrollbar wenn zu viele (Umami hat dann 4: Sessions, Compare, Events, Reports)

</specifics>

<deferred>
## Deferred Ideas

- Plausible Custom Events (event:name Dimension) — könnte in Phase 09 mit Plausible Filters kommen
- Report-Erstellung direkt aus der App (API existiert, aber UI-Komplexität zu hoch für v2.3)

</deferred>
