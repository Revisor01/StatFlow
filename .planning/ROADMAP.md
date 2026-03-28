# Roadmap: InsightFlow

## Milestones

- 📋 **v2.0 Code Quality & Security Hardening** - Phases 1-5 (planned)

## Phases

### v2.0 Code Quality & Security Hardening

**Milestone Goal:** Alle identifizierten Security-, Architektur-, Stabilitäts- und Qualitätsprobleme systematisch beheben. Die App speichert Credentials sicher in der Keychain, hat ein konsolidiertes Auth-System, nutzt das AnalyticsProvider-Protokoll korrekt und ist mit Unit Tests gegen Regressionen abgesichert.

- [x] **Phase 1: Security Hardening** - Credentials in Keychain migrieren, Widget-Tokens verschlüsseln, Token-Logging entfernen (completed 2026-03-28)
- [ ] **Phase 2: Quick Wins & Widget Split** - Print-Statements bereinigen, Widget-Monolith aufteilen, große Views extrahieren
- [ ] **Phase 3: Stabilität** - Force Unwraps durch safe unwrapping ersetzen, Timing-Hacks durch async/await ablösen
- [ ] **Phase 4: Architektur** - Concurrency vereinheitlichen, AnalyticsProvider-Protokoll im ViewModel nutzen, Auth-System konsolidieren
- [ ] **Phase 5: Tests** - Unit Tests für kritische Pfade ergänzen

## Phase Details

### Phase 1: Security Hardening
**Goal**: Alle Account-Credentials sind ausschließlich in der Keychain gespeichert — UserDefaults enthält keine Tokens oder API-Keys mehr. Bestehende Accounts werden beim Update migriert. Widget-Tokens sind verschlüsselt und Token-Logging ist entfernt.
**Depends on**: Nothing (first phase)
**Requirements**: SEC-01, SEC-02, SEC-03, SEC-04
**Success Criteria** (what must be TRUE):
  1. Ein bestehendes App-Update migriert vorhandene UserDefaults-Credentials automatisch in die Keychain, ohne dass der Nutzer sich neu einloggen muss
  2. Die Datei `analytics_accounts` in UserDefaults enthält nach der Migration keine Token- oder API-Key-Felder mehr
  3. Die Datei `widget_accounts.json` im App Group Container ist mit AES-GCM verschlüsselt (identisches Schema wie `widget_credentials.encrypted`)
  4. Die Widget-Logs in Console.app zeigen keine Token-Präfixe oder Credential-Fragmente mehr
  5. Ein neu hinzugefügter Account schreibt Credentials ausschließlich in die Keychain (per Account-ID gescoped)
**Plans:** 2/2 plans complete
Plans:
- [x] 01-01-PLAN.md — Keychain-basierte Credential-Speicherung mit Account-ID-Scoping und Migration (SEC-01, SEC-04)
- [x] 01-02-PLAN.md — Widget-Account-Verschluesselung und Token-Log-Entfernung (SEC-02, SEC-03)

### Phase 2: Quick Wins & Widget Split
**Goal**: Der Code ist aufgeräumt und besser navigierbar. Print-Statements sind auf Debug-Builds beschränkt, der 2004-Zeilen Widget-Monolith ist in separate Dateien aufgeteilt, und die größten Views haben ausgelagerte Subviews.
**Depends on**: Phase 1
**Requirements**: STAB-03, STRUC-01, STRUC-02
**Success Criteria** (what must be TRUE):
  1. Ein Release-Build enthält keine `print()`-Ausgaben mehr — alle Logging-Calls sind in `#if DEBUG` gewrappt oder entfernt
  2. Die Datei `InsightFlowWidget/InsightFlowWidget.swift` ist auf unter 400 Zeilen reduziert; Widget-Models, Networking, Cache, Views und Intents liegen in separaten Dateien
  3. `WebsiteDetailView.swift`, `AdminView.swift` und `CompareView.swift` sind jeweils unter 600 Zeilen durch Extraktion von Subviews
  4. Das Widget verhält sich nach dem Split funktional identisch (alle Widget-Größen zeigen Daten korrekt)
**Plans:** 2/4 plans executed
Plans:
- [x] 02-01-PLAN.md — Widget-Monolith in 9 Dateien aufteilen (STRUC-01, STAB-03)
- [x] 02-02-PLAN.md — Print-Statement-Cleanup in 14 Main-App-Dateien (STAB-03)
- [x] 02-03-PLAN.md — View-Extraktion WebsiteDetailView, AdminView, CompareView (STRUC-02, STAB-03)
- [ ] 02-04-PLAN.md — Automatisierte und visuelle Verifikation (STAB-03, STRUC-01, STRUC-02)
**UI hint**: yes

### Phase 3: Stabilität
**Goal**: Networking-Code und kritische Pfade stürzen nicht mehr durch Force Unwraps ab. Timing-abhängige Koordination zwischen Komponenten ist durch deterministisches async/await ersetzt.
**Depends on**: Phase 2
**Requirements**: STAB-01, STAB-02
**Success Criteria** (what must be TRUE):
  1. Kein `!`-Force-Unwrap auf `URL(string:)` oder `URLComponents.url` in `PlausibleAPI.swift`, `UmamiAPI.swift` und Widget-Code — alle Stellen nutzen `guard let` mit Fehlerweiterleitung
  2. Kein `DispatchQueue.main.asyncAfter` oder `Task.sleep` mehr in `AccountManager.swift` und `AuthManager.swift` — Koordination läuft über async/await oder Combine
  3. Account-Switching löst keinen Race Condition aus, der zu inkonsistentem Auth-State führen kann
**Plans:** 2 plans
Plans:
- [ ] 03-01-PLAN.md — Force Unwraps in API-Clients und Widget-Networking eliminieren (STAB-01)
- [ ] 03-02-PLAN.md — Timing-Hacks in AccountManager und AuthManager entfernen (STAB-02)

### Phase 4: Architektur
**Goal**: Die Codebase hat ein einziges Auth-System, API-Clients mit konsistenter Concurrency, und das ViewModel nutzt das AnalyticsProvider-Protokoll ohne `isPlausible`-Branching.
**Depends on**: Phase 3
**Requirements**: ARCH-03, ARCH-02, ARCH-01
**Success Criteria** (what must be TRUE):
  1. `PlausibleAPI` ist ein `actor` (nicht mehr `@MainActor class`) — beide API-Clients verwenden dasselbe Concurrency-Modell
  2. `WebsiteDetailViewModel` enthält kein `if isPlausible`-Branching mehr — alle `loadX()`-Methoden rufen ausschließlich `currentProvider.methodName()` auf
  3. `AuthManager` ist entfernt oder auf einen dünnen Wrapper reduziert — `AccountManager` ist die einzige Autorität über den Auth-State
  4. Login, Account-Switching und Logout funktionieren für Umami- und Plausible-Accounts nach der Konsolidierung korrekt
**Plans**: TBD

### Phase 5: Tests
**Goal**: Kritische Pfade sind mit Unit Tests abgedeckt. Zukünftige Refactorings haben ein Sicherheitsnetz.
**Depends on**: Phase 4
**Requirements**: TEST-01
**Success Criteria** (what must be TRUE):
  1. Unit Tests für `KeychainService` (save, load, delete, per-Account-ID-Scoping) laufen grün
  2. Unit Tests für `AccountManager` (CRUD, Migration, Credential-Anwendung) laufen grün
  3. Unit Tests für API-Response-Parsing von `UmamiAPI` und `PlausibleAPI` mit Mock-Daten laufen grün
  4. Unit Tests für `DateRange`-Berechnungen (Presets, Custom, Provider-Formatierung) laufen grün
  5. Unit Tests für `AnalyticsCacheService` (save/load, TTL-Expiry) laufen grün
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Security Hardening | 2/2 | Complete   | 2026-03-28 |
| 2. Quick Wins & Widget Split | 2/4 | In Progress|  |
| 3. Stabilität | 0/2 | Not started | - |
| 4. Architektur | 0/? | Not started | - |
| 5. Tests | 0/? | Not started | - |
