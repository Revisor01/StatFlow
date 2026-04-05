# StatFlow

## What This Is

StatFlow ist eine iOS-App (SwiftUI), die als Dashboard für Umami und Plausible Analytics dient. Nutzer können mehrere Analytics-Accounts verwalten, Website-Statistiken einsehen, Zeiträume vergleichen und Echtzeit-Daten anzeigen. Die App enthält ein Widget für den Homescreen.

## Core Value

Nutzer können ihre Website-Analytics sicher und übersichtlich von ihrem iPhone aus überwachen — über mehrere Accounts und Analytics-Anbieter hinweg.

## Current State

**Latest shipped:** v2.7 Stability & Architecture (completed 2026-04-04)
**Current:** v2.8 App Store Release (started 2026-04-05)
**GitHub:** Revisor01/StatFlow

### v2.7 Accomplishments
- Alle 3 aktiven Bugs gefixt (CompareChart @ObservedObject, Cache Offline-Only, Widget Race Condition)
- Task-Cancellation flächendeckend in 14 ViewModels (loadingTask + isCancelled Guards)
- Cache nur noch Offline-Fallback (50MB Limit, 24h TTL, Offline-Banner mit Zeitstempel)
- isNetworkError Extension dedupliziert, 16 DateFormatter Hot-Paths durch shared static lets ersetzt
- 8 ViewModels in eigene Dateien extrahiert, Dependency Injection für 15 ViewModels
- 88 print() durch strukturiertes os.Logger ersetzt (4 Kategorien: api, cache, auth, ui)
- Force Unwraps in KeychainService eliminiert (guard let + throw)

### v2.6 Accomplishments
- Dashboard-Kacheln gleich hoch (QuickActionCard maxHeight fix)
- Doppelte Chevrons bei Analytics-NavigationLinks entfernt
- Dove-Icon in Settings sichtbar gemacht
- Notification-Strings klarer formuliert (DE+EN)
- Self-Hosted String im Onboarding lokalisiert
- ServerType-Selektor + X-Button in AddAccountView
- Icon-only Toolbar-Buttons in allen 8 Admin-Sheets

### v2.5 Accomplishments
- 4 kritische Bugs gefixt: Widget-Sync, Request-Cancellation, Cache-Cleanup, Loading-State
- 43 ungenutzte API-Methoden entfernt (448 LOC weniger)
- Offline-Banner in 4 Views mit URLError-Erkennung
- README.md als StatFlow Landing Page neu geschrieben
- GitHub Repo von PrivacyFlow zu StatFlow umbenannt

### v2.4 Accomplishments
- App umbenannt zu "StatFlow" — Display Name, Bundle IDs, URL Scheme, Product IDs, alle Strings

### v2.3 Accomplishments
- EventsView + ReportsHub (Funnel, UTM, Goals, Attribution) als neue Screens
- Entry/Exit Pages + Plausible Filter-Chip-Bar (6 Dimensionen)
- In-App Setup Guide (Umami/Plausible Tracking + Goals)
- Analytics Glossar (12 Begriffe, DE+EN)

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
- ✓ Widget Sync Race Condition behoben (FIX-01) — v2.5
- ✓ Request Cancellation bei Navigation (FIX-02) — v2.5
- ✓ Cache Cleanup beim App-Start (FIX-03) — v2.5
- ✓ Account Switch Loading State (FIX-04) — v2.5
- ✓ 43 ungenutzte API-Methoden entfernt (CLEAN-01) — v2.5
- ✓ Offline-Mode UI mit Banner (CLEAN-02) — v2.5
- ✓ README als Landing Page (README-01) — v2.5
- ✓ GitHub Repo umbenannt zu StatFlow (REPO-01) — v2.5
- ✓ CompareChartSection @ObservedObject Fix (BUG-01) — v2.7
- ✓ Cache nur für Offline mit 50MB/24h Limits (BUG-02) — v2.7
- ✓ Widget Account-Sync Race Condition behoben (BUG-03) — v2.7
- ✓ Task-Cancellation in 14 ViewModels (TASK-01) — v2.7
- ✓ Account-Switch ohne globalen Singleton-State (TASK-02) — v2.7
- ✓ isNetworkError Extension dedupliziert (REFACTOR-01) — v2.7
- ✓ DateFormatter shared static lets (REFACTOR-02) — v2.7
- ✓ 8 ViewModels in eigene Dateien extrahiert (REFACTOR-03) — v2.7
- ✓ Dependency Injection für 15 ViewModels (REFACTOR-04) — v2.7
- ✓ LazyVStack-Audit (REFACTOR-05) — v2.7
- ✓ 88 print() durch os.Logger ersetzt (REFACTOR-06) — v2.7
- ✓ KeychainService Force Unwraps eliminiert (SEC-01) — v2.7

### Active

<!-- Current scope. Building toward these. -->

- STORE-01: App Store Beschreibung (DE + EN) — Titel, Untertitel, Keywords, Text — v2.8
- WEB-01: "Apps"-Rubrik auf simonluthe.de mit Unterseiten für alle Apps — v2.8
- WEB-02: StatFlow Projektseite (Beschreibung, Features) — v2.8
- WEB-03: StatFlow Privacy Policy auf simonluthe.de — v2.8
- WEB-04: CookMy + Valetudios Platzhalter-Seiten + Privacy Policies — v2.8
- WEB-05: "Guck mal!" von /guckmal/ in Apps-Rubrik verschieben — v2.8
- REVIEW-01: App Review Notes mit Testaccount-Daten — v2.8
- README-01: README.md aktualisieren falls nötig — v2.8

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
- 58+ Unit Tests als Sicherheitsnetz (KeychainService, AccountManager, API-Parsing, DateRange, Cache, AnalyticsCacheService, DashboardViewModel, WebsiteDetailViewModel)
- Widget in 9 Dateien aufgeteilt, beide API-Clients als actors
- AccountManager ist einzige Auth-Autorität
- App released als v2.5 auf GitHub (Revisor01/StatFlow)
- Alle ViewModels in eigenen Dateien, DI-fähig via init-Parameter
- Strukturiertes Logging via os.Logger (Subsystem: de.godsapp.statflow, 4 Kategorien)
- Cache nur Offline-Fallback (50MB Limit, 24h Display-TTL)

## Constraints

- **Tech Stack**: Swift/SwiftUI only — keine externen Dependencies
- **Kompatibilität**: Account-Daten in Keychain, Widget-Daten verschlüsselt in App Group
- **Widget**: Widget Extension teilt Code über App Group
- **Tests**: 58+ Unit Tests vorhanden — neue Features sollten Tests haben

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| AccountManager als Single Source of Truth für Auth | Drei überlappende Systeme verursachen State-Sync-Probleme | Shipped v2.0 |
| Keychain per Account-ID statt Single-Slot | Häufiges Account-Switching verursacht unnötige Keychain-Writes | Shipped v2.0 |
| actor-Pattern für beide API-Clients | Inkonsistenz zwischen UmamiAPI (actor) und PlausibleAPI (@MainActor) | Shipped v2.0 |
| Task-Cancellation mit loadingTask Handle | .task allein cancelt nicht bei Date-Range-Wechsel | Shipped v2.5 |
| Offline-Banner differenziert nach View-Typ | Dashboard hat Cache-Fallback, Detail-Views nicht | Shipped v2.5 |
| Cache nur Offline-Fallback, nie Preview | Dashboard zeigte stale Daten (147 statt 213) weil Cache vor API geladen | Shipped v2.7 |
| configureProviderForAccount statt setActiveAccount-Loop | Widget Race Condition durch globalen Account-Switch in Schleife | Shipped v2.7 |
| DI via init-Parameter mit .shared Default | ViewModels direkt testbar ohne Singleton-Abhängigkeit | Shipped v2.7 |
| os.Logger statt print() | 88 unstrukturierte prints, keine Filterbarkeit in Console.app | Shipped v2.7 |

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
*Last updated: 2026-04-05 — v2.8 App Store Release started*
