# Requirements: InsightFlow

**Defined:** 2026-03-27
**Core Value:** Nutzer können ihre Website-Analytics sicher und übersichtlich vom iPhone aus überwachen

## v2.0 Requirements

Requirements für Code Quality & Security Hardening. Jedes Requirement mappt auf eine Roadmap-Phase.

### Security

- [x] **SEC-01**: Credentials werden ausschließlich in Keychain gespeichert (per Account-ID), nicht in UserDefaults
- [x] **SEC-02**: Widget-Account-Tokens werden mit AES-GCM verschlüsselt in App Group geschrieben
- [x] **SEC-03**: Auth-Token-Logging ist aus Widget-Code entfernt
- [x] **SEC-04**: Migration bestehender UserDefaults-Credentials beim App-Update

### Architektur

- [x] **ARCH-01**: AccountManager ist einziger Auth-State-Manager (AuthManager und AnalyticsManager-Auth entfernt/reduziert)
- [x] **ARCH-02**: WebsiteDetailViewModel nutzt AnalyticsProvider-Protokoll statt direkter if-isPlausible-Prüfungen
- [x] **ARCH-03**: Beide API-Clients (Umami + Plausible) verwenden einheitliches Concurrency-Modell (actor)

### Stabilität

- [x] **STAB-01**: Alle Force Unwraps in Networking-Code durch guard-let mit Error Handling ersetzt
- [x] **STAB-02**: Timing-Hacks (asyncAfter, Task.sleep) durch async/await Koordination ersetzt
- [x] **STAB-03**: Print-Statements in #if DEBUG gewrappt oder entfernt

### Struktur

- [x] **STRUC-01**: Widget-Code in separate Dateien aufgeteilt (Models, Networking, Cache, Views, Intents)
- [x] **STRUC-02**: Große Views (WebsiteDetailView, AdminView, CompareView) in Subviews extrahiert

### Tests

- [x] **TEST-01**: Unit Tests für KeychainService, AccountManager, API-Response-Parsing, DateRange, Cache

## Future Requirements

### Performance

- **PERF-01**: Rate Limiting für parallele API-Requests (aktuell 15 gleichzeitig)
- **PERF-02**: Plausible Stats mit Compare-Parameter statt doppeltem API-Call
- **PERF-03**: Widget cacht Website-Listen statt bei jedem Refresh neu zu laden

### Struktur

- **STRUC-03**: Shared Framework Target für Code-Sharing zwischen App und Widget
- **STRUC-04**: Gemeinsame Networking-Schicht statt separater Implementierungen

## Out of Scope

| Feature | Reason |
|---------|--------|
| Neue App-Features (Views, Endpunkte) | Reines Qualitäts-Milestone |
| Externe Dependencies einführen | Bewusste Entscheidung, alles custom zu halten |
| UI-Redesign | Kein visueller Scope in v2.0 |
| iPad/macOS Support | Fokus auf bestehende iOS-App |
| Widget-Networking mit Shared Framework | Zu groß für dieses Milestone — Widget wird nur aufgeteilt, nicht refactored |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| SEC-01 | Phase 1 | Complete |
| SEC-02 | Phase 1 | Complete |
| SEC-03 | Phase 1 | Complete |
| SEC-04 | Phase 1 | Complete |
| STAB-03 | Phase 2 | Complete |
| STRUC-01 | Phase 2 | Complete |
| STRUC-02 | Phase 2 | Complete |
| STAB-01 | Phase 3 | Complete |
| STAB-02 | Phase 3 | Complete |
| ARCH-03 | Phase 4 | Complete |
| ARCH-02 | Phase 4 | Complete |
| ARCH-01 | Phase 4 | Complete |
| TEST-01 | Phase 5 | Complete |

**Coverage:**
- v2.0 requirements: 13 total
- Mapped to phases: 13
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-27*
*Last updated: 2026-03-27 after roadmap creation*
