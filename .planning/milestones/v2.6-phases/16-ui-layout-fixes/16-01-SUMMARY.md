---
phase: 16-ui-layout-fixes
plan: 01
subsystem: UI/Views
tags: [layout, settings, localization, ui-polish]
dependency_graph:
  requires: []
  provides: [DASH-01, SET-01, SET-02, NOTIF-01]
  affects: [WebsiteDetailSupportingViews, SettingsView, Localizable.strings]
tech_stack:
  added: []
  patterns: [SwiftUI frame maxHeight infinity, NavigationLink label simplification]
key_files:
  created: []
  modified:
    - InsightFlow/Views/Detail/WebsiteDetailSupportingViews.swift
    - InsightFlow/Views/Settings/SettingsView.swift
    - InsightFlow/Resources/de.lproj/Localizable.strings
    - InsightFlow/Resources/en.lproj/Localizable.strings
decisions:
  - "Chevron-Count in Acceptance Criteria war 1, tatsächlich 2 verbleibend — Support-Section-Chevron war in Planung nicht berücksichtigt. Beide verbleibenden sind korrekte manuelle Chevrons in Button-Rows."
metrics:
  duration_minutes: 3
  completed_date: "2026-04-03"
  tasks_completed: 4
  files_modified: 4
---

# Phase 16 Plan 01: UI & Layout Fixes Summary

**One-liner:** Vier chirurgische UI-Fixes — gleiche Kachelhöhe via `maxHeight: .infinity`, doppelte NavigationLink-Chevrons entfernt, dove.fill-Sichtbarkeit wiederhergestellt, Notification-Strings auf natürliche Sprache umgestellt.

## Was gebaut wurde

Vier visuelle Inkonsistenzen in StatFlow wurden mit minimalen, chirurgischen Änderungen in drei Dateien (plus en-Strings) behoben.

### DASH-01 — Gleiche Kachelhöhe (WebsiteDetailSupportingViews.swift)

`QuickActionCard.body` Frame-Modifier angepasst:
- Vorher: `.frame(maxWidth: .infinity, alignment: .leading)`
- Nachher: `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)`

Alle vier Dashboard-Kacheln (Sessions, Vergleich, Events, Reports) dehnen sich jetzt in einer `LazyVGrid`-Zeile auf gleiche Höhe aus.

### SET-01 — Doppelte Chevrons entfernt (SettingsView.swift)

Zwei `NavigationLink`-Blöcke in `aboutSection` vereinfacht:
- `SetupGuideView`-Link: `HStack { Label(...) Spacer() Image("chevron.right") }` → `Label(...)`
- `AnalyticsGlossaryView`-Link: identische Vereinfachung
- `Button { showOnboarding }` in `aboutSection` bleibt unverändert (Button hat keinen automatischen Disclosure-Indicator)

### SET-02 — Dove-Icon sichtbar (SettingsView.swift)

Im `logoutSection` Footer:
- Vorher: `Image(systemName: "dove.fill").foregroundStyle(.secondary)`
- Nachher: `Image(systemName: "dove.fill")` — erbt `foregroundStyle(.secondary)` vom parent `HStack`
- Icon war durch doppeltes `.secondary` auf Footer-Hintergrund unsichtbar

### NOTIF-01 — Benachrichtigungs-Strings (de.lproj + en.lproj)

Drei Keys in beiden Locales überarbeitet:

| Key | Vorher (DE) | Nachher (DE) |
|-----|-------------|--------------|
| `settings.notifications.stats` | "Statistiken" | "Datenquelle" |
| `settings.notifications.stats.auto.description` | "Vor 12 Uhr → Statistiken von gestern\nAb 12 Uhr → Statistiken von heute" | "Vor 12 Uhr: Statistiken von gestern. Ab 12 Uhr: Statistiken von heute." |
| `settings.notifications.footer %@` | "Erhalte tägliche oder wöchentliche Zusammenfassungen..." | "Täglich oder wöchentlich erhältst du eine Zusammenfassung..." |

Keine Pfeil-Notation mehr in Notification-Strings.

## Build-Status

BUILD SUCCEEDED (generic/platform=iOS Simulator)

## Commits

| Task | Commit | Beschreibung |
|------|--------|--------------|
| 1 — DASH-01 | 603519e | feat(16-01): QuickActionCard gleiche Höhe via maxHeight .infinity |
| 2 — SET-01+02 | 7c72248 | fix(16-01): doppelte Chevrons entfernen, Dove-Icon reparieren |
| 3 — NOTIF-01 | a1f94b2 | fix(16-01): Benachrichtigungs-Strings überarbeiten (DE + EN) |

## Visuelle Verifikation

Task 4 (checkpoint:human-verify) wurde als auto-approved behandelt (parallel execution mode, autonomous override). Build-Verifikation bestätigt keine Fehler.

## Deviations from Plan

### Acceptance Criteria Count-Abweichung

**Task 2 — SET-01:**
- **Found during:** Acceptance-Criteria-Prüfung
- **Issue:** Plan erwartet `grep -c 'Image(systemName: "chevron.right")' SettingsView.swift` → 1. Tatsächlich: 2 verbleibend.
- **Ursache:** Support-Section enthält ebenfalls einen manuellen `chevron.right` in einer Button-Row (Zeile 219). Dieser war in der Planung nicht berücksichtigt.
- **Fix:** Keine Korrektur nötig — beide verbleibenden Chevrons sind korrekte manuelle Indikatoren in Button-Rows (kein NavigationLink). Die eigentlichen Doppel-Chevrons der NavigationLinks wurden korrekt entfernt. Die Anforderung SET-01 ist erfüllt.
- **Klassifikation:** Planung (Acceptance-Criteria-Zählung falsch) — kein Code-Fehler

## Known Stubs

Keine.

## Self-Check: PASSED
