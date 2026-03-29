---
phase: 14-code-cleanup
plan: 02
subsystem: views/offline-ui
tags: [offline, ui, viewmodel, localization]
dependency_graph:
  requires: []
  provides: [offline-banner-ui, isOffline-detection]
  affects: [WebsiteDetailView, EventsView, SessionsView, ReportsHubView]
tech_stack:
  added: []
  patterns: [Published-isOffline, URLError-detection, computed-banner-view]
key_files:
  created: []
  modified:
    - InsightFlow/Views/Detail/WebsiteDetailViewModel.swift
    - InsightFlow/Views/Detail/WebsiteDetailView.swift
    - InsightFlow/Views/Events/EventsViewModel.swift
    - InsightFlow/Views/Events/EventsView.swift
    - InsightFlow/Views/Sessions/SessionsView.swift
    - InsightFlow/Views/Reports/ReportsViewModel.swift
    - InsightFlow/Views/Reports/ReportsHubView.swift
    - InsightFlow/Resources/en.lproj/Localizable.strings
    - InsightFlow/Resources/de.lproj/Localizable.strings
decisions:
  - "SessionsViewModel ist in SessionsView.swift definiert (kein separates File) — isOffline dort eingebaut"
  - "ReportsHubView: LazyVGrid in LazyVStack eingebettet um Banner vor Grid zeigen zu koennen"
metrics:
  duration_minutes: 5
  completed_date: "2026-03-29"
  tasks_completed: 2
  files_modified: 9
---

# Phase 14 Plan 02: Offline-Banner in Detail-Views Summary

Offline-Indikator in 4 Views (WebsiteDetail, Events, Sessions, ReportsHub) analog zum Dashboard-Pattern — orangener Banner mit wifi.slash-Icon ohne Cache-Bezug.

## Tasks Completed

| Task | Description | Commit |
|------|-------------|--------|
| 1 | isOffline-Erkennung in ViewModels + Lokalisierung | bef492d |
| 2 | Offline-Banner UI in 4 Views eingebunden | d4b5c96 |

## What Was Built

- `@Published var isOffline = false` in WebsiteDetailViewModel, EventsViewModel, ReportsViewModel, SessionsViewModel
- URLError-Erkennung (notConnectedToInternet, networkConnectionLost, timedOut, cannotFindHost, cannotConnectToHost) in den jeweiligen Load-Methoden
- `isOffline = false` Reset am Anfang jedes Ladevorgangs
- Lokalisierungsschluessel `detail.offline` in EN ("Offline – data unavailable") und DE ("Offline – Daten nicht verfügbar") ohne Cache-Bezug
- `offlineBanner` computed property in allen 4 Views (identisches Design: orange, wifi.slash, RoundedRectangle)
- Banner-Einbindung in allen 4 Views mit `if viewModel.isOffline` Bedingung

## Verification

- BUILD SUCCEEDED (iPhone 17 Simulator)
- 4 Views: offlineBanner-Property vorhanden (grep bestaetigt)
- 3 dedizierte ViewModels + SessionsViewModel: isOffline vorhanden
- Lokalisierung: detail.offline in beiden .strings-Dateien, kein "gecachte" im Text

## Deviations from Plan

### Auto-fixed Issues

None.

### Architectural Notes

- SessionsViewModel ist in SessionsView.swift definiert, kein separates File. isOffline dort direkt hinzugefuegt (kein neues File noetig).
- ReportsHubView hatte nur LazyVGrid direkt im ScrollView. LazyVStack als Wrapper eingefuegt, um Banner darueber platzieren zu koennen.

## Known Stubs

None — alle Offline-Banner sind vollstaendig implementiert und an echte ViewModel-Properties gebunden.

## Self-Check: PASSED

Files exist:
- InsightFlow/Views/Detail/WebsiteDetailViewModel.swift: FOUND
- InsightFlow/Views/Detail/WebsiteDetailView.swift: FOUND
- InsightFlow/Views/Events/EventsViewModel.swift: FOUND
- InsightFlow/Views/Events/EventsView.swift: FOUND
- InsightFlow/Views/Sessions/SessionsView.swift: FOUND
- InsightFlow/Views/Reports/ReportsViewModel.swift: FOUND
- InsightFlow/Views/Reports/ReportsHubView.swift: FOUND

Commits exist:
- bef492d: feat(14-02): add isOffline detection to ViewModels + localization
- d4b5c96: feat(14-02): add offline banner UI to 4 detail views
