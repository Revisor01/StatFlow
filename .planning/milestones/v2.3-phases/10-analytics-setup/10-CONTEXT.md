# Phase 10: Analytics Setup - Context

**Gathered:** 2026-03-28
**Status:** Ready for planning
**Mode:** Auto-generated (infrastructure — server/website work)

<domain>
## Phase Boundary

Analytics-Tracking auf eigenen Websites einrichten. Umami oder Plausible Tracking-Code einbauen, Goals definieren, echte Daten zum Fließen bringen. Ergebnis: Die App zeigt echte Website-Daten statt leerer Screens.

Dies ist KEINE App-Entwicklung — dies ist Server/Website-Infrastruktur-Arbeit.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
Diese Phase erfordert Zugriff auf:
- Umami Self-Hosted Instance (server.godsapp.de oder ähnlich)
- Plausible CE Instance (falls vorhanden)
- Websites des Users (z.B. simonluthe.de, godsapp.de etc.)

Da wir keinen direkten Zugriff auf die Websites haben, wird diese Phase als **Dokumentations-/Anweisungs-Phase** umgesetzt:
- Erstelle eine Schritt-für-Schritt-Anleitung zum Einrichten von Umami/Plausible Tracking
- Beschreibe wie man Goals definiert
- Beschreibe wie man Tracking-Code in verschiedene Website-Typen einbaut (WordPress, statische HTML, Next.js etc.)
- Die Anleitung wird als In-App "Setup Guide" oder als Markdown-Dokumentation bereitgestellt

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- Bestehende Onboarding/Settings-Infrastruktur in der App
- AccountManager für Server-Konfiguration

### Integration Points
- Kein App-Code nötig — nur Dokumentation/Anleitung

</code_context>

<specifics>
## Specific Ideas

Phase 10 ist eher ein "Setup Guide" als App-Code. Der User braucht Anleitung, wie er Analytics auf seinen Websites einrichtet.

</specifics>

<deferred>
## Deferred Ideas

None.

</deferred>
