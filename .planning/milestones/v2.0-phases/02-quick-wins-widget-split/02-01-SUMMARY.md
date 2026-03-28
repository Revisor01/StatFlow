---
phase: 02-quick-wins-widget-split
plan: "01"
subsystem: InsightFlowWidget
tags: [refactor, widget, split, architecture]
dependency_graph:
  requires: []
  provides: [widget-modular-structure]
  affects: [InsightFlowWidget]
tech_stack:
  added: []
  patterns: [PBXFileSystemSynchronizedRootGroup, modular-swift-files]
key_files:
  created:
    - InsightFlowWidget/Models/WidgetModels.swift
    - InsightFlowWidget/Models/WidgetTimeRange.swift
    - InsightFlowWidget/Storage/WidgetStorage.swift
    - InsightFlowWidget/Cache/WidgetCache.swift
    - InsightFlowWidget/Intents/WidgetIntents.swift
    - InsightFlowWidget/Networking/WidgetNetworking.swift
    - InsightFlowWidget/Views/WidgetChartViews.swift
    - InsightFlowWidget/Views/WidgetSizeViews.swift
  modified:
    - InsightFlowWidget/InsightFlowWidget.swift
decisions:
  - "widgetLog() mit #if DEBUG guard — keine Ausgabe in Release-Builds"
  - "AppIntents import in WidgetTimeRange.swift benoetigt fuer TypeDisplayRepresentation/DisplayRepresentation"
metrics:
  duration: 7min
  completed: 2026-03-28
  tasks: 2
  files: 9
---

# Phase 02 Plan 01: Widget Split Summary

**One-liner:** 2034-Zeilen Widget-Monolith in 9 Dateien nach Verantwortlichkeit aufgeteilt, widgetLog mit #if DEBUG abgesichert.

## What Was Built

Der InsightFlowWidget-Monolith (2034 Zeilen) wurde in 9 separate Swift-Dateien aufgeteilt, organisiert in Subdirectories:

- **Models/WidgetModels.swift** — WidgetAccount, WidgetData, StatsEntry, WidgetProviderType, widgetLog
- **Models/WidgetTimeRange.swift** — WidgetTimeRange, WidgetChartStyle (beide AppEnum)
- **Storage/WidgetStorage.swift** — WidgetAccountsStorage mit AES-GCM encrypted storage, WidgetCredentials
- **Cache/WidgetCache.swift** — WidgetCache mit App Group Persistenz
- **Intents/WidgetIntents.swift** — AccountEntity, WebsiteEntity, ConfigureWidgetIntent, FilteredWebsiteOptionsProvider
- **Networking/WidgetNetworking.swift** — Provider mit getTimeline, fetchUmamiStats, fetchPlausibleStats
- **Views/WidgetChartViews.swift** — BarChartView, LineChartView
- **Views/WidgetSizeViews.swift** — PrivacyFlowWidgetEntryView, SmallWidgetView, MediumWidgetView
- **InsightFlowWidget.swift** — auf 41 Zeilen reduziert (nur PrivacyFlowWidget + #Preview)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fehlender AppIntents import in WidgetTimeRange.swift**
- **Found during:** Task 2 — xcodebuild Kompilierung
- **Issue:** `TypeDisplayRepresentation` und `DisplayRepresentation` sind in `AppIntents` definiert, nicht in `SwiftUI`. WidgetTimeRange.swift hatte nur `import SwiftUI`
- **Fix:** `import AppIntents` zu WidgetTimeRange.swift hinzugefuegt
- **Files modified:** InsightFlowWidget/Models/WidgetTimeRange.swift
- **Commit:** b89d5a9

### Out-of-Scope Discoveries

Pre-existing Build-Fehler im InsightFlow Haupttarget (`AdminCards.swift` — invalid redeclaration von `WebsiteAdminCard`, `TeamCard`, `UserCard`, `PlausibleSiteAdminCard`) wurden nicht durch diese Aenderungen verursacht und werden zu deferred-items.md hinzugefuegt.

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| widgetLog() als internal (nicht private) | Fuer sichtbarkeit aus allen Widget-Dateien im selben Target |
| AppIntents import in WidgetTimeRange.swift | TypeDisplayRepresentation/DisplayRepresentation benoetigen AppIntents |

## Commits

- `e20065d` — feat(02-01): extract widget models, storage, cache and time range
- `b89d5a9` — feat(02-01): extract widget intents, networking, views and reduce main file

## Verification Results

- InsightFlowWidget.swift: 41 Zeilen (< 100 Zeilen)
- 8 neue Dateien in 6 Subdirectories
- widgetLog() wrapped mit `#if DEBUG`
- Kein `@unchecked Sendable` in Widget-Dateien
- `xcodebuild build -target InsightFlowWidgetExtension` — BUILD SUCCEEDED

## Self-Check: PASSED

Files exist:
- InsightFlowWidget/Models/WidgetModels.swift — FOUND
- InsightFlowWidget/Models/WidgetTimeRange.swift — FOUND
- InsightFlowWidget/Storage/WidgetStorage.swift — FOUND
- InsightFlowWidget/Cache/WidgetCache.swift — FOUND
- InsightFlowWidget/Intents/WidgetIntents.swift — FOUND
- InsightFlowWidget/Networking/WidgetNetworking.swift — FOUND
- InsightFlowWidget/Views/WidgetChartViews.swift — FOUND
- InsightFlowWidget/Views/WidgetSizeViews.swift — FOUND

Commits exist:
- e20065d — FOUND
- b89d5a9 — FOUND
