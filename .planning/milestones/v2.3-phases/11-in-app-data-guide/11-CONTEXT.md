# Phase 11: In-App Data Guide - Context

**Gathered:** 2026-03-28
**Status:** Ready for planning
**Mode:** Auto-generated (autonomous)

<domain>
## Phase Boundary

In-App Erklärungen zu Analytics-Begriffen. Nutzer ohne Vorwissen verstehen was Bounce Rate, Referrer, UTM-Parameter, Funnels etc. bedeuten. Erklärungen kontextsensitiv oder zentral erreichbar.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
- Zentraler "Analytics Glossar" View erreichbar aus Settings
- Optional: Info-Buttons (ℹ️) neben Metriken in der Detail-View die zum Glossar-Eintrag verlinken
- Erklärungen in einfacher Sprache, nicht technisch — für Nutzer ohne Analytics-Vorwissen
- Begriffe: Bounce Rate, Session Duration, Pageviews vs Visits vs Visitors, Referrer, UTM-Parameter (Source/Medium/Campaign), Funnels, Goals, Conversion Rate, Entry/Exit Pages, Events, Attribution
- DE + EN lokalisiert

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- SetupGuideView.swift Pattern (ScrollView mit Sektionen, GuideSectionHeader, GuideStep)
- SettingsView.swift für Navigation
- Bestehende Lokalisierungs-Infrastruktur

### Integration Points
- SettingsView → Glossar-Link
- Optional: WebsiteDetailView Metric-Labels → Info-Buttons

</code_context>

<specifics>
## Specific Ideas

No specific requirements beyond ROADMAP success criteria.

</specifics>

<deferred>
## Deferred Ideas

None.

</deferred>
