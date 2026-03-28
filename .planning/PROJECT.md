# InsightFlow

## What This Is

InsightFlow ist eine iOS-App (SwiftUI), die als Dashboard für Umami und Plausible Analytics dient. Nutzer können mehrere Analytics-Accounts verwalten, Website-Statistiken einsehen, Zeiträume vergleichen und Echtzeit-Daten anzeigen. Die App enthält ein Widget für den Homescreen.

## Core Value

Nutzer können ihre Website-Analytics sicher und übersichtlich von ihrem iPhone aus überwachen — über mehrere Accounts und Analytics-Anbieter hinweg.

## Current State

**Latest shipped:** v2.2 Support & API Coverage (completed 2026-03-28)
**Current milestone:** v2.3 API Data Screens & Analytics Setup

### v2.2 Accomplishments
- SupportView redesigned: SF Symbols statt Emojis, dezentes Branding "Ein Pastorenprojekt"
- UmamiAPI: 103 Methoden, 30 neue Response-Models (vollständige Self-Hosted API)
- PlausibleAPI: Sites-Liste, Goals CRUD, Filter-Infrastruktur, UTM/Entry/Exit-Dimensionen
- Push-Notifications: Account-gruppiert mit threadIdentifier, Summary bei 5+ Sites

### v2.1 Accomplishments
- Account-Switcher als kompakter Provider-Icon Menu-Button in der Toolbar
- Widget-Tap öffnet Website-Details (Deep Link Fix)
- "Alle Accounts"-Ansicht mit kombinierter Website-Liste und Provider-Badges

### v2.0 Accomplishments
- Credentials sicher in Keychain gespeichert (per Account-ID), Widget-Tokens AES-GCM-verschlüsselt
- AuthManager entfernt, AccountManager als einzige Auth-Quelle konsolidiert
- AnalyticsProvider-Protokoll im ViewModel (0 isPlausible-Branches)
- PlausibleAPI + UmamiAPI beide als actor (einheitliches Concurrency-Modell)
- Widget-Monolith von 2034 auf 41 Zeilen reduziert (9 separate Dateien)
- 58 Unit Tests für KeychainService, AccountManager, API-Parsing, DateRange, Cache

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
- ✓ Credentials sicher in Keychain (per Account-ID) — v2.0
- ✓ Widget-Tokens AES-GCM-verschlüsselt — v2.0
- ✓ Auth-System konsolidiert (AccountManager als Single Source) — v2.0
- ✓ AnalyticsProvider-Protokoll im ViewModel — v2.0
- ✓ Widget-Code aufgeteilt (9 Dateien) — v2.0
- ✓ Force Unwraps + Timing-Hacks eliminiert — v2.0
- ✓ 58 Unit Tests für kritische Pfade — v2.0
- ✓ Account-Switcher als Provider-Icon Menu-Button — v2.1
- ✓ Widget Deep Link Fix — v2.1
- ✓ Alle-Accounts-Ansicht mit Provider-Badges — v2.1
- ✓ Support-Option mit SF Symbols statt Emojis (SUP-01) — v2.2
- ✓ Branding-Untertitel "Ein Pastorenprojekt" (SUP-02) — v2.2

### Active

<!-- Current scope. Building toward these. -->

- [ ] SCREEN-01: Events-View (Event-Liste, Details, Statistiken) für Umami
- [ ] SCREEN-02: Reports-View (Funnel, UTM, Goals, Attribution) für Umami
- [ ] SCREEN-03: Entry/Exit Pages und erweiterte Session-Details
- [ ] SCREEN-04: Plausible Goals + Filter in bestehenden Views nutzen
- [ ] SETUP-01: Analytics-Tracking auf eigenen Websites einrichten (Umami/Plausible)
- [ ] GUIDE-01: In-App Erklärungen was die Daten bedeuten

### Out of Scope

<!-- Explicit boundaries. Includes reasoning to prevent re-adding. -->

- Externe Dependencies einführen — bewusste Entscheidung, alles custom zu halten
- iPad/macOS Support — Fokus auf bestehende iOS-App
- Komplett neues UI-Design — v2.1 war UX-Polish, kein Redesign
- Externe Payment-Provider (Stripe etc.) — Apple In-App Purchase reicht
- Abo-Modell — Einmal-Tip reicht, kein recurring
- Cloud/SaaS API-Endpunkte — Nur Self-Hosted Varianten

## Context

- iOS 18+ Deployment Target, reine SwiftUI App (Swift 6.0)
- Keine externen Dependencies (kein SPM, CocoaPods, Carthage)
- 58 Unit Tests als Sicherheitsnetz (KeychainService, AccountManager, API-Parsing, DateRange, Cache)
- Widget in 9 Dateien aufgeteilt, beide API-Clients als actors
- AccountManager ist einzige Auth-Autorität
- App released als v2.0 auf GitHub (Revisor01/PrivacyFlow)

## Constraints

- **Tech Stack**: Swift/SwiftUI only — keine externen Dependencies
- **Kompatibilität**: Account-Daten in Keychain, Widget-Daten verschlüsselt in App Group
- **Widget**: Widget Extension teilt Code über App Group
- **Tests**: 58 Unit Tests vorhanden — neue Features sollten Tests haben

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| AccountManager als Single Source of Truth für Auth | Drei überlappende Systeme verursachen State-Sync-Probleme | Shipped v2.0 |
| Keychain per Account-ID statt Single-Slot | Häufiges Account-Switching verursacht unnötige Keychain-Writes | Shipped v2.0 |
| actor-Pattern für beide API-Clients | Inkonsistenz zwischen UmamiAPI (actor) und PlausibleAPI (@MainActor) | Shipped v2.0 |

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
*Last updated: 2026-03-28 — v2.3 milestone started*
