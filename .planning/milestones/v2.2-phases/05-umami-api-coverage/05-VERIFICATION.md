---
phase: 05-umami-api-coverage
verified: 2026-03-28T19:15:00Z
status: gaps_found
score: 1/3 must-haves verified
re_verification: false
gaps:
  - truth: "Nutzer sehen in der Detailansicht alle Metriken, die die Umami API bereitstellt"
    status: failed
    reason: "103 neue API-Methoden existieren in UmamiAPI.swift, aber keine wird aus einem View oder ViewModel aufgerufen. AnalyticsProvider-Protokoll wurde nicht erweitert. Die neuen Endpunkte sind in der API-Schicht vorhanden, aber komplett vom UI abgekoppelt."
    artifacts:
      - path: "InsightFlow/Services/UmamiAPI.swift"
        issue: "Methoden existieren (getExpandedMetrics, getEventsDetail, getSessionStats, getSessionsWeekly, getFunnelReport, getUTMReport, getGoalReport, getAttributionReport, getPerformanceReport, getBreakdownReport, getRevenueReport, getEventData, getSessionDataProperties etc.) aber keine davon wird in Views/ViewModels aufgerufen"
      - path: "InsightFlow/Services/AnalyticsProvider.swift"
        issue: "AnalyticsProvider-Protokoll hat keine neuen Methoden erhalten — nur die bestehenden ~15 Methoden sind sichtbar; alle neuen ~70 Methoden sind ausschliesslich intern in UmamiAPI"
      - path: "InsightFlow/Views/Detail/WebsiteDetailViewModel.swift"
        issue: "Verwendet ausschliesslich bestehende provider.*-Methoden (getPages, getMetrics, getStats etc.); keine der neuen API-Methoden wird aufgerufen"
    missing:
      - "AnalyticsProvider-Protokoll um relevante neue Methoden erweitern (z.B. getExpandedMetrics, getEventDataStats, getSessionStats, getSessionsWeekly)"
      - "WebsiteDetailViewModel um Aufrufe der neuen Methoden erweitern (oder dedizierte ViewModels fuer neue Metriken)"
      - "UI-Sektion in WebsiteDetailView (oder neue Views) um erweiterte Metriken anzuzeigen"
  - truth: "Keine relevanten Umami-Datenpunkte fehlen im Vergleich zur Umami-Weboberfläche"
    status: failed
    reason: "Gleiche Ursache wie Truth 2: Expanded Metrics, Event Details, Session Stats, Weekly Heatmap, Funnel, UTM, Goals, Attribution, Performance (Core Web Vitals), Revenue — alle sind in Umamis Weboberfläche sichtbar, aber in InsightFlow nicht dargestellt. Die API-Methoden dafür existieren, werden aber nicht aufgerufen."
    artifacts:
      - path: "InsightFlow/Views/Detail/WebsiteDetailView.swift"
        issue: "Zeigt nur Stats, Pageviews, Metrics (pages/referrers/browsers/OS/countries etc.) und Events-Zaehlung — keine Expanded Metrics, keine Session-Stats-Aggregate, keine Report-Daten"
      - path: "InsightFlow/Views/Reports/"
        issue: "Retention und Journey/Insights existieren bereits; Funnel, UTM, Goals, Attribution, Performance, Breakdown, Revenue fehlen als Views"
    missing:
      - "Views fuer mindestens die user-relevanten Report-Typen: Funnel, UTM, Goals, Revenue"
      - "Expanded Metrics in WebsiteDetailMetricsSections.swift integrieren"
      - "Session-Stats-Aggregate (SessionStatsResponse, WeeklySessionPoint) in SessionsView anzeigen"
      - "Event-Data-Statistiken (EventDataStats) in bestehende Events-Sektion integrieren"
human_verification:
  - test: "Umami-Weboberfläche mit InsightFlow vergleichen"
    expected: "Alle Metriken, die in der Umami-Weboberfläche sichtbar sind (Funnel, UTM, Goals, Attribution, Performance, Revenue, Expanded Metrics, Session-Aggregates), sollen auch in InsightFlow abrufbar sein"
    why_human: "Visueller Vergleich der Datendarstellung zwischen Web-UI und iOS-App — programmatisch nicht verifizierbar"
---

# Phase 05: Umami API Coverage — Verification Report

**Phase Goal:** InsightFlow deckt alle verfügbaren Umami Self-Hosted API-Endpunkte ab, sodass keine Daten verloren gehen
**Verified:** 2026-03-28T19:15:00Z
**Status:** gaps_found
**Re-verification:** Nein — erste Verifikation

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Alle dokumentierten Umami Self-Hosted API-Endpunkte sind auditiert und fehlende implementiert | VERIFIED | UmamiAPI.swift hat 103 func-Deklarationen; alle Endpunkt-Gruppen aus den Plans bestätigt (Me, DateRange, ExpandedMetrics, Events, EventData, Sessions, Reports CRUD + 7 Typen, Teams, Users, Share, Admin) |
| 2 | Nutzer sehen in der Detailansicht alle Metriken, die die Umami API bereitstellt | FAILED | Kein View und kein ViewModel ruft auch nur eine der ~70 neuen API-Methoden auf; AnalyticsProvider-Protokoll unverändert |
| 3 | Keine relevanten Umami-Datenpunkte fehlen im Vergleich zur Umami-Weboberfläche | FAILED | Funnel, UTM, Goals, Attribution, Performance (Core Web Vitals), Revenue, Expanded Metrics, Session Stats Aggregate sind in keinem View dargestellt |

**Score:** 1/3 Truths verifiziert

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `InsightFlow/Models/Events.swift` | 7 Structs: EventDataResponse, EventDataItem, EventDataEvent, EventDataField, EventDataProperty, EventDataValue, EventDataStats | VERIFIED | Alle 7 Structs vorhanden, Codable+Sendable |
| `InsightFlow/Models/Reports.swift` | 10 Structs: ReportListResponse, Report, FunnelStep, UTMReportItem, GoalReportItem, AttributionItem, PerformanceItem, BreakdownItem, RevenueItem, RevenueComparison | VERIFIED | Alle 10 Structs vorhanden |
| `InsightFlow/Models/Share.swift` | 3 Structs: SharePage, ShareListResponse, MeResponse | VERIFIED | Alle 3 Structs vorhanden |
| `InsightFlow/Models/Stats.swift` | +11 neue Structs (DateRangeResponse, ExpandedMetricItem, SessionStatsResponse, WeeklySessionPoint, SessionPropertyItem, SessionDataProperty, SessionDataValue, EventsResponse, EventDetail, EventStatsResponse, EventStatsComparison) | VERIFIED | 29 Structs total; alle geforderten vorhanden |
| `InsightFlow/Models/Admin.swift` | +3 Structs: TeamWebsitesResponse, UserWebsitesResponse, UserTeamsResponse | VERIFIED | Alle 3 Structs vorhanden |
| `InsightFlow/Services/UmamiAPI.swift` | 103 Methoden; alle geplanten Endpunkte implementiert | VERIFIED | 103 func-Deklarationen bestätigt; alle Plan-Acceptance-Criteria-Methoden gefunden |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| UmamiAPI.swift | Stats.swift (DateRangeResponse) | decoder.decode(DateRangeResponse.self) | WIRED | Zeile 360 |
| UmamiAPI.swift | Events.swift (EventDataResponse) | decoder.decode(EventDataResponse.self) | WIRED | Zeile 447 |
| UmamiAPI.swift | Reports.swift (FunnelStep) | decoder.decode([FunnelStep].self) | WIRED | Zeile 1034 |
| UmamiAPI.swift | Share.swift (SharePage) | decoder.decode(SharePage.self) | WIRED | Zeilen 879, 884, 894, 912 |
| UmamiAPI.swift | Admin.swift (TeamWebsitesResponse) | decoder.decode(TeamWebsitesResponse.self) | WIRED | Zeile 800 |
| UmamiAPI.swift | Views/ViewModels | Aufruf der neuen API-Methoden | NOT_WIRED | Keine View oder ViewModel ruft getExpandedMetrics, getEventsDetail, getSessionStats, getFunnelReport, getRevenueReport o.ä. auf |
| AnalyticsProvider.swift | UmamiAPI.swift | Protokoll-Erweiterung um neue Methoden | NOT_WIRED | AnalyticsProvider-Protokoll unverändert — nur die ~15 Originalmethoden; neue ~70 Methoden nicht im Protokoll |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| WebsiteDetailView | expandedMetrics | — | Nein — kein Aufruf | DISCONNECTED |
| WebsiteDetailView | eventDetails | — | Nein — kein Aufruf | DISCONNECTED |
| WebsiteDetailView | sessionStats | — | Nein — kein Aufruf | DISCONNECTED |
| Views/Reports/ | funnelSteps | — | Nein — kein FunnelView | DISCONNECTED |
| Views/Reports/ | revenueItems | — | Nein — kein RevenueView | DISCONNECTED |

Die neuen API-Methoden in UmamiAPI.swift sind als Infrastructure vorhanden (Level 1+2 passed), aber kein Datenfluss bis zur UI existiert (Level 3+4 failed).

---

### Behavioral Spot-Checks

Step 7b: SKIPPED — iOS-App, kein CLI/API-Server direkt ausführbar ohne Simulator.

Build-Status (aus SUMMARY.md bestätigt, da Build-Erfolg in Aufgabenbeschreibung angegeben): BUILD SUCCEEDED mit 103 Methoden in UmamiAPI.swift.

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| API-01 | 05-01, 05-02, 05-03, 05-04 | Vollständige Abdeckung aller Umami Self-Hosted API-Endpunkte (Audit + fehlende implementieren) | PARTIAL | API-Schicht vollständig implementiert (103 Methoden, 30 neue Response-Modelle, Build erfolgreich). Aber die Phase-Formulierung "sodass keine Daten verloren gehen" und Success Criteria 2+3 verlangen auch UI-Präsentation — diese fehlt. |

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| InsightFlow/Services/UmamiAPI.swift | 749–918 | ~70 neue Methoden (Teams, Users, Share, Admin, Reports, EventData, Sessions, Stats) ohne jeden Aufrufer ausserhalb UmamiAPI.swift | Warning | Alle neuen Methoden sind toter Code bis UI-Anbindung erfolgt |
| InsightFlow/Services/AnalyticsProvider.swift | 130–168 | Protokoll nicht um neue Methoden erweitert; ViewModel-Schicht kann UmamiAPI-spezifische Methoden nicht typsicher verwenden | Warning | Architekturbruch: direkte UmamiAPI.shared-Zugriffe in Views umgehen das Provider-Pattern |

Keine der gefundenen Patterns ist ein echter Stub (leeres return [], TODO etc.) — die Implementierungen sind substanziell. Das Problem ist fehlendes Wiring auf der UI-Seite.

---

### Human Verification Required

#### 1. Umami-Weboberfläche vs. InsightFlow Metrik-Vergleich

**Test:** Umami-Weboberfläche mit einer Testseite öffnen und alle verfügbaren Metriken/Reports notieren (Funnel, UTM, Goals, Attribution, Core Web Vitals, Revenue, Expanded Metrics, Session Heatmap). Dann InsightFlow öffnen und prüfen, welche dieser Metriken in der Detailansicht oder Report-Views vorhanden sind.
**Expected:** Alle Metriken, die Umami in der Weboberfläche zeigt, sollen in InsightFlow mindestens abrufbar sein.
**Why human:** Visueller Vergleich zweier UIs, abhängig von einem laufenden Umami-Server mit Testdaten.

---

### Gaps Summary

Die Phase hat ihre **technische Infrastruktur vollständig geliefert**: 30 neue Response-Modelle (Events.swift, Reports.swift, Share.swift, Stats.swift-Erweiterung, Admin.swift-Erweiterung) und ~70 neue API-Methoden in UmamiAPI.swift compilieren fehlerfrei.

**Das Phase-Ziel wurde jedoch nicht erreicht**, weil der zweite und dritte Success Criterion — "Nutzer sehen in der Detailansicht alle Metriken" und "Keine relevanten Datenpunkte fehlen" — eine UI-Anbindung voraussetzen, die nie implementiert wurde.

Die neuen API-Methoden sind **vollständig orphaned**: kein View, kein ViewModel, keine AnalyticsProvider-Protokoll-Extension verbindet sie mit der Benutzeroberfläche. Insbesondere fehlen:

1. **Views für neue Report-Typen** (Funnel, UTM, Goals, Attribution, Performance/Core Web Vitals, Revenue, Breakdown) — RetentionView und InsightsView/CompareView existieren, aber die 7 neuen Report-Methoden haben keine entsprechenden Views.
2. **Expanded Metrics Integration** in WebsiteDetailMetricsSections — `getExpandedMetrics` liefert mehr Daten als `getMetrics`, wird aber nie aufgerufen.
3. **Session-Stats-Aggregation** — `getSessionStats` und `getSessionsWeekly` bieten Aggregat-Daten und Wochentag/Stunden-Heatmap, aber SessionsView kennt diese Methoden nicht.
4. **Event-Data-Details** — die 7 `getEventData*`-Methoden sind vollständig ungenutzt.

**Wurzelursache:** Die Plans 01–04 wurden als "API infrastructure only" konzipiert, ohne UI-Anbindungstasks. Der Phase-Goal und die Success Criteria gehen aber über reine API-Implementierung hinaus.

---

_Verified: 2026-03-28T19:15:00Z_
_Verifier: Claude (gsd-verifier)_
