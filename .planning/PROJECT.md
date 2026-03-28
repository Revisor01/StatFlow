# InsightFlow

## What This Is

InsightFlow ist eine iOS-App (SwiftUI), die als Dashboard für Umami und Plausible Analytics dient. Nutzer können mehrere Analytics-Accounts verwalten, Website-Statistiken einsehen, Zeiträume vergleichen und Echtzeit-Daten anzeigen. Die App enthält ein Widget für den Homescreen.

## Core Value

Nutzer können ihre Website-Analytics sicher und übersichtlich von ihrem iPhone aus überwachen — über mehrere Accounts und Analytics-Anbieter hinweg.

## Current Milestone: v2.0 Code Quality & Security Hardening

**Goal:** Alle identifizierten Concerns (Sicherheit, Architektur, Stabilität, Code-Qualität, Tests) systematisch beheben.

**Target features:**
- Credentials aus UserDefaults in Keychain migrieren + Widget-Tokens verschlüsseln
- Auth-System konsolidieren (AuthManager/AccountManager/AnalyticsManager → einer)
- AnalyticsProvider-Protokoll tatsächlich nutzen statt if-isPlausible-Branching
- Force Unwraps durch sichere Unwrapping ersetzen
- Widget-Datei (2004 Zeilen) aufteilen
- Timing-Hacks durch Combine/async-await Koordination ersetzen
- Print-Statements aufräumen
- Unit Tests für kritische Pfade ergänzen

## Requirements

### Validated

<!-- Shipped and confirmed valuable. -->

- ✓ Multi-Account-Unterstützung (Umami + Plausible) — v1.0
- ✓ Dashboard mit Website-Übersicht und Sparkline-Charts — v1.0
- ✓ Detailansicht mit Statistiken, Seiten, Referrer, Geräte — v1.0
- ✓ Zeitraumvergleich (Compare View) — v1.0
- ✓ Echtzeit-Ansicht (Realtime View) — v1.0
- ✓ iOS Widget mit Account-Auswahl — v1.0
- ✓ Lokalisierung (Deutsch/Englisch) — v1.0
- ✓ Dashboard-Anpassungsmodus (Reihenfolge, Metriken, Chart-Stil) — v1.2
- ✓ Optionale Datumsauswahl und Graph-Auto-Hide — v1.3

### Active

<!-- Current scope. Building toward these. -->

- [x] Credentials sicher in Keychain statt UserDefaults speichern — Validated in Phase 1: Security Hardening
- [x] Widget-Account-Tokens verschlüsseln (AES-GCM) — Validated in Phase 1: Security Hardening
- [x] Token-Logging aus Widget entfernen — Validated in Phase 1: Security Hardening
- [x] Auth-System auf einen Manager konsolidieren — Validated in Phase 4: Architektur
- [x] AnalyticsProvider-Protokoll in ViewModel nutzen — Validated in Phase 4: Architektur
- [x] Force Unwraps durch safe unwrapping ersetzen — Validated in Phase 3: Stabilität
- [x] Widget-Code in mehrere Dateien aufteilen — Validated in Phase 2: Quick Wins & Widget Split
- [x] Timing-Hacks durch async/await Koordination ersetzen — Validated in Phase 3: Stabilität
- [x] Print-Statements aufräumen (#if DEBUG) — Validated in Phase 2: Quick Wins & Widget Split
- [ ] Unit Tests für kritische Pfade ergänzen

### Out of Scope

<!-- Explicit boundaries. Includes reasoning to prevent re-adding. -->

- Neue Features (neue Views, neue API-Endpunkte) — reines Qualitäts-Milestone
- Externe Dependencies einführen — bewusste Entscheidung, alles custom zu halten
- UI-Redesign — kein visueller Scope in diesem Milestone
- iPad/macOS Support — Fokus auf bestehende iOS-App

## Context

- iOS 17+ Deployment Target, reine SwiftUI App
- Keine externen Dependencies (kein SPM, CocoaPods, Carthage)
- Null Tests vorhanden — jedes Refactoring ohne Safety Net
- Widget ist 2004-Zeilen Monolith mit duplizierter API-Logik
- Drei Auth-Systeme: AuthManager, AccountManager, AnalyticsManager
- UmamiAPI (actor) vs PlausibleAPI (@MainActor class) — inkonsistente Concurrency
- App bereits released bis v1.3 auf GitHub (Revisor01/PrivacyFlow)

## Constraints

- **Tech Stack**: Swift/SwiftUI only — keine externen Dependencies
- **Kompatibilität**: Alle Änderungen müssen bestehende Account-Daten migrieren (UserDefaults → Keychain)
- **Widget**: Widget Extension teilt Code über App Group — Shared Framework oder duplizierter Code
- **Regressions**: Ohne Tests muss jede Phase manuell verifiziert werden bis Tests existieren

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| AccountManager als Single Source of Truth für Auth | Drei überlappende Systeme verursachen State-Sync-Probleme | — Pending |
| Keychain per Account-ID statt Single-Slot | Häufiges Account-Switching verursacht unnötige Keychain-Writes | — Pending |
| actor-Pattern für beide API-Clients | Inkonsistenz zwischen UmamiAPI (actor) und PlausibleAPI (@MainActor) | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-03-28 after Phase 4 (Architektur) completion*
