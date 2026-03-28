---
phase: 05-umami-api-coverage
plan: "02"
subsystem: api-client
tags: [swift, umami-api, actor, async-await, api-methods]
dependency_graph:
  requires: [05-01]
  provides: [getMe, getMyWebsites, getWebsite, getDateRange, getEventsSeries, getExpandedMetrics, getEventsDetail, getEventsStats, getSessionStats, getSessionsWeekly, getSession, getSessionProperties, getSessionDataProperties, getSessionDataValues, getEventData, getEventDataById, getEventDataEvents, getEventDataFields, getEventDataProperties, getEventDataValues, getEventDataStats]
  affects: [InsightFlow/Services/UmamiAPI.swift]
tech_stack:
  added: []
  patterns: [actor-async-await, URLQueryItem-GET-params, decoder-decode-pattern]
key_files:
  created: []
  modified:
    - InsightFlow/Services/UmamiAPI.swift
decisions:
  - "Event-Data-Endpunkte in eigene MARK: Event Data Section — trennt event-data/* von website-events/* fuer Klarheit"
  - "Events-Section vor Sessions eingefuegt um logische API-Gruppierung widerzuspiegeln"
  - "Me-Section direkt vor Authentication platziert da sie user-identity Endpunkte gruppiert"
metrics:
  duration: "~3min"
  completed: "2026-03-28"
  tasks_completed: 2
  files_changed: 1
---

# Phase 05 Plan 02: High-Priority API-Endpunkte in UmamiAPI Summary

One-liner: 22 neue async-throws Methoden in UmamiAPI.swift fuer Me, Website-Stats-Erweiterungen, Events, Event-Data und Session-Details.

## What Was Built

Alle high-priority Umami API-Endpunkte wurden als Actor-Methoden in UmamiAPI.swift implementiert. Beide Tasks zusammen liefern vollstaendige Abdeckung der nutzer-sichtbaren Daten-Endpunkte.

### Task 1 — Me, Website, Stats, Events, Sessions (15 Methoden)

**MARK: Me (3 neue Methoden):**
- `getMe()` — GET /api/me
- `getMyTeams()` — GET /api/me/teams
- `getMyWebsites(includeTeams:)` — GET /api/me/websites

**MARK: Websites (1 neue Methode):**
- `getWebsite(websiteId:)` — GET /api/websites/:id (Einzelabfrage)

**MARK: Stats (3 neue Methoden):**
- `getDateRange(websiteId:)` — GET /api/websites/:id/daterange
- `getEventsSeries(websiteId:dateRange:timezone:)` — GET /api/websites/:id/events/series
- `getExpandedMetrics(websiteId:dateRange:type:limit:)` — GET /api/websites/:id/metrics/expanded

**MARK: Events (2 neue Methoden, neue Section):**
- `getEventsDetail(websiteId:dateRange:page:pageSize:)` — GET /api/websites/:id/events
- `getEventsStats(websiteId:dateRange:)` — GET /api/websites/:id/events/stats

**MARK: Sessions (6 neue Methoden):**
- `getSessionStats(websiteId:dateRange:)` — GET /api/websites/:id/sessions/stats
- `getSessionsWeekly(websiteId:dateRange:timezone:)` — GET /api/websites/:id/sessions/weekly
- `getSession(websiteId:sessionId:)` — GET /api/websites/:id/sessions/:id
- `getSessionProperties(websiteId:sessionId:)` — GET /api/websites/:id/sessions/:id/properties
- `getSessionDataProperties(websiteId:dateRange:)` — GET /api/websites/:id/session-data/properties
- `getSessionDataValues(websiteId:dateRange:propertyName:)` — GET /api/websites/:id/session-data/values

### Task 2 — Event Data Endpunkte (7 Methoden)

**MARK: Event Data (7 neue Methoden, neue Section):**
- `getEventData(websiteId:dateRange:page:pageSize:)` — GET /api/websites/:id/event-data
- `getEventDataById(websiteId:eventId:)` — GET /api/websites/:id/event-data/:id
- `getEventDataEvents(websiteId:dateRange:)` — GET /api/websites/:id/event-data/events
- `getEventDataFields(websiteId:dateRange:)` — GET /api/websites/:id/event-data/fields
- `getEventDataProperties(websiteId:dateRange:)` — GET /api/websites/:id/event-data/properties
- `getEventDataValues(websiteId:dateRange:eventName:propertyName:)` — GET /api/websites/:id/event-data/values
- `getEventDataStats(websiteId:dateRange:)` — GET /api/websites/:id/event-data/stats

## Verification

- Xcode Build Task 1: BUILD SUCCEEDED (iPhone 17 Simulator, iOS 26.4)
- Xcode Build Task 2: BUILD SUCCEEDED (iPhone 17 Simulator, iOS 26.4)
- 14 acceptance criteria methods verified (Task 1 grep checks all pass)
- 7 Event Data methods verified (Task 2 grep checks all pass)
- Total: 22 neue Methoden in UmamiAPI.swift

## Deviations from Plan

None — Plan executed exactly as written.

## Known Stubs

None — alle Methoden sind vollstaendig implementiert und koennen von ViewModels verwendet werden. Kein hardcoded leerer Return-Wert.

## Self-Check: PASSED

- FOUND: InsightFlow/Services/UmamiAPI.swift (modified)
- FOUND: commit 284b7f6 (Task 1)
- FOUND: commit 288506b (Task 2)
