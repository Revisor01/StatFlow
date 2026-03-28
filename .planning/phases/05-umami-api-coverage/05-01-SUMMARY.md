---
phase: 05-umami-api-coverage
plan: "01"
subsystem: models
tags: [swift, codable, umami-api, response-models]
dependency_graph:
  requires: []
  provides: [EventDataResponse, FunnelStep, SharePage, DateRangeResponse, ExpandedMetricItem, SessionStatsResponse, WeeklySessionPoint, MeResponse]
  affects: [InsightFlow/Services/UmamiAPI.swift]
tech_stack:
  added: []
  patterns: [Codable+Sendable, Identifiable-for-SwiftUI-lists]
key_files:
  created:
    - InsightFlow/Models/Events.swift
    - InsightFlow/Models/Reports.swift
    - InsightFlow/Models/Share.swift
  modified:
    - InsightFlow/Models/Stats.swift
decisions:
  - "Alle neuen Modelle als Codable+Sendable definiert (actor-Pattern der API-Clients erfordert Sendable)"
  - "Identifiable nur wo SwiftUI-Listen-Verwendung sinnvoll (nicht bei reinen Wrapper-Responses)"
  - "PerformanceItem.id via UUID() als Fallback da path optional — akzeptabel fuer read-only Darstellung"
metrics:
  duration: "155s"
  completed: "2026-03-28"
  tasks_completed: 2
  files_changed: 4
---

# Phase 05 Plan 01: Response-Modelle fuer Umami API Summary

One-liner: Alle fehlenden Umami-API-Response-Modelle als Codable+Sendable Structs in 3 neuen Dateien + Stats.swift-Erweiterung.

## What Was Built

Alle Response-Modelle fuer die ~50 fehlenden Umami-API-Endpunkte wurden als compilierbare Swift Structs angelegt. Diese bilden die Grundlage fuer Plan 02-04 (API-Methoden-Implementierung).

### Stats.swift (erweitert — +11 Structs)

- `DateRangeResponse` — GET /api/websites/:id/daterange
- `ExpandedMetricItem` — GET /api/websites/:id/metrics/expanded (inkl. bounceRate/avgTime computed)
- `SessionStatsResponse` — GET /api/websites/:id/sessions/stats
- `WeeklySessionPoint` — GET /api/websites/:id/sessions/weekly
- `SessionPropertyItem` — GET /api/websites/:id/sessions/:id/properties
- `SessionDataProperty` / `SessionDataValue` — session-data Endpoints
- `EventsResponse` / `EventDetail` — GET /api/websites/:id/events
- `EventStatsResponse` / `EventStatsComparison` — Event-Statistiken

### Events.swift (neu — 7 Structs)

- `EventDataResponse` / `EventDataItem` — GET /api/event-data/... (paginiert)
- `EventDataEvent` / `EventDataField` / `EventDataProperty` / `EventDataValue` — Event-Data-Aggregationen
- `EventDataStats` — Gesamtstatistiken fuer Event-Data

### Reports.swift (neu — 10 Structs)

- `ReportListResponse` / `Report` — Report CRUD
- `FunnelStep` — Funnel-Report (mit dropoffRate computed)
- `UTMReportItem` — UTM-Kampagnen-Auswertung
- `GoalReportItem` — Zielverfolgung (mit completionRate computed)
- `AttributionItem` — Attributions-Report
- `PerformanceItem` — Core Web Vitals (LCP, INP, CLS, FCP, TTFB)
- `BreakdownItem` — Breakdown-Report
- `RevenueItem` / `RevenueComparison` — Revenue-Tracking

### Share.swift (neu — 3 Structs)

- `SharePage` — Share-Page-Entitaet
- `ShareListResponse` — Liste der Share-Pages
- `MeResponse` — GET /api/me (aktueller Benutzer)

## Verification

- Xcode Build: BUILD SUCCEEDED (iPhone 17 Simulator, iOS 26.4)
- Stats.swift struct count: 29 (>= 18 gefordert)
- Events.swift struct count: 7 (>= 6 gefordert)
- Reports.swift struct count: 10 (>= 10 gefordert)
- Share.swift struct count: 3 (>= 3 gefordert)

## Deviations from Plan

None — Plan executed exactly as written.

## Known Stubs

None — diese Modelle sind reine Datenstrukturen ohne UI-Anbindung. Die Verwendung erfolgt in Plan 02-04.

## Self-Check: PASSED

- FOUND: InsightFlow/Models/Events.swift
- FOUND: InsightFlow/Models/Reports.swift
- FOUND: InsightFlow/Models/Share.swift
- FOUND: commit a2e4d0a (Task 1)
- FOUND: commit b869a57 (Task 2)
