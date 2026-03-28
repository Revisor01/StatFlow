# Phase 4: Architektur - Research

**Researched:** 2026-03-27
**Domain:** Swift Concurrency (actor), SwiftUI EnvironmentObject Removal, Protocol-basierte Dispatch
**Confidence:** HIGH — vollständige Codebase-Analyse, keine externen Bibliotheken involviert

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
Keine gesperrten Entscheidungen — reine Architektur-Phase, alles liegt in Claudes Ermessen.

### Claude's Discretion
All implementation choices are at Claude's discretion — pure architecture phase. Key technical context:

- ARCH-03: PlausibleAPI ist aktuell `@MainActor class` — muss auf `actor` umgestellt werden (wie UmamiAPI)
- ARCH-02: WebsiteDetailViewModel hat 15+ `if isPlausible` Branches — soll nur noch `currentProvider.methodName()` nutzen
- ARCH-01: AuthManager, AccountManager und AnalyticsManager haben überlappenden Auth-State — AuthManager soll entfernt oder auf thin wrapper reduziert werden
- Phase 1 hat AccountManager bereits als primären Credential-Manager etabliert (Keychain-basiert)
- Phase 3 hat Timing-Hacks in AuthManager entfernt
- PlausibleAPI konformiert bereits zu `AnalyticsProvider` Protokoll
- AnalyticsManager hat `setProvider()` und `isAuthenticated` — könnte in AccountManager integriert werden
- AuthManager wird als EnvironmentObject in Views genutzt — Abhängigkeiten müssen sauber aufgelöst werden

### Deferred Ideas (OUT OF SCOPE)
Keine.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ARCH-03 | Beide API-Clients (Umami + Plausible) verwenden einheitliches Concurrency-Modell (actor) | PlausibleAPI ist `@MainActor class ObservableObject` — UmamiAPI ist `actor`. Umstellung erfordert Entfernung von `ObservableObject`, `objectWillChange.send()` und der `reconfigureFromKeychain()`-Implementierung muss angepasst werden |
| ARCH-02 | WebsiteDetailViewModel nutzt AnalyticsProvider-Protokoll statt direkter if-isPlausible-Prüfungen | 15 `if isPlausible` Branches identifiziert. AnalyticsProvider-Protokoll deckt alle genutzten Methoden bereits ab. Zwei Ausnahmen (pageTitles, languages, screens, events sind Plausible-Leerstellen) müssen als bewusste Protokoll-Extension oder leere Default-Implementierung behandelt werden |
| ARCH-01 | AccountManager ist einziger Auth-State-Manager (AuthManager und AnalyticsManager-Auth entfernt/reduziert) | AuthManager wird von 4 Views als EnvironmentObject genutzt. AccountManager.shared existiert bereits, hat aber keinen `isAuthenticated`-Published-State. AnalyticsManager hat eigenen `isAuthenticated`-State der AuthManager dupliziert |
</phase_requirements>

---

## Summary

Phase 4 ist die höchste Risikoänderung im Milestone v2.0. Die Codebase hat drei Auth-State-Manager (`AuthManager`, `AccountManager`, `AnalyticsManager`) die alle teilweise überlappende `isAuthenticated`-State führen — und einen `currentProvider`-State der an zwei Stellen synchronisiert werden muss. Gleichzeitig führt `WebsiteDetailViewModel` 15 manuelle `if isPlausible`-Verzweigungen, die das bereits vorhandene `AnalyticsProvider`-Protokoll ignorieren.

Die drei Requirements haben eine klare Ausführungsreihenfolge: ARCH-03 (PlausibleAPI → actor) ist isoliert und risikoarm. ARCH-02 (ViewModel-Branching entfernen) baut auf einem funktionierenden AnalyticsManager.currentProvider auf. ARCH-01 (AuthManager entfernen) ist die gefährlichste Änderung, da 4 Views direkt `authManager.isAuthenticated`, `authManager.logout()`, `authManager.login()`, `authManager.currentProvider` und `authManager.serverURL`/`authManager.username` referenzieren — jede dieser Referenzen muss auf AccountManager umgeleitet werden.

**Primary recommendation:** Implementiere die drei Requirements in der Reihenfolge ARCH-03 → ARCH-02 → ARCH-01. Jedes kann unabhängig verifiziert werden.

---

## Standard Stack

Keine externen Libraries. Reine Swift/SwiftUI-interne Patterns.

### Core Patterns in diesem Projekt

| Pattern | Aktueller Stand | Ziel-Stand |
|---------|----------------|------------|
| `actor` | UmamiAPI | UmamiAPI + PlausibleAPI |
| `@MainActor class ObservableObject` | AuthManager, AccountManager, AnalyticsManager, PlausibleAPI | AuthManager entfernt; AccountManager + AnalyticsManager behalten |
| `nonisolated var` | In UmamiAPI für Protocol-Properties | Gleiches Muster in PlausibleAPI nach actor-Umstellung |
| EnvironmentObject | authManager in 4 Views | Entfernt aus allen Views |

---

## Architecture Patterns

### Pattern 1: actor mit nonisolated Protocol-Properties (UmamiAPI als Referenz)

**Was:** Swift `actor` isoliert mutable State auf einem seriellen Execution Context. Protocol-Properties die `nonisolated` sind können synchron von außen gelesen werden, indem sie Keychain lesen statt actor-State.

**Anwendung für PlausibleAPI:**
```swift
// VORHER
@MainActor
class PlausibleAPI: ObservableObject, AnalyticsProvider {
    static let shared = PlausibleAPI()
    var apiKey: String? { KeychainService.load(for: .apiKey) }
    func reconfigureFromKeychain() {
        PlausibleSitesManager.shared.objectWillChange.send()
        objectWillChange.send()  // <-- nur für ObservableObject, entfällt
    }
}

// NACHHER — exakt wie UmamiAPI
actor PlausibleAPI: AnalyticsProvider {
    static let shared = PlausibleAPI()
    nonisolated var apiKey: String? { KeychainService.load(for: .apiKey) }
    nonisolated var serverURL: String { KeychainService.load(for: .serverURL) ?? "https://plausible.io" }
    nonisolated var isAuthenticated: Bool { KeychainService.load(for: .apiKey) != nil }
    nonisolated var providerType: AnalyticsProviderType { .plausible }

    func reconfigureFromKeychain() {
        // PlausibleAPI liest bereits alles aus Keychain — keine actor-State
        // PlausibleSitesManager.shared.objectWillChange.send() bleibt, aber
        // muss von außen (AccountManager) auf MainActor aufgerufen werden
    }
}
```

**Wichtig:** `private let decoder` ist kein Problem — `let` Konstanten sind threadsafe und brauchen keine actor-Isolation.

**Kritischer Punkt:** `PlausibleSitesManager.shared.objectWillChange.send()` in `reconfigureFromKeychain()` — das ist ein `@MainActor`-Call aus einem `actor`. Nach der Umstellung muss der AccountManager diesen Call selbst machen (er ruft bereits `reconfigureFromKeychain()` auf).

### Pattern 2: Protocol-Dispatch im ViewModel (ARCH-02)

**Was:** Statt `if isPlausible { plausibleAPI.X() } else { umamiAPI.Y() }` wird `currentProvider.X()` aufgerufen.

**Voraussetzung:** `AnalyticsProvider`-Protokoll deckt alle verwendeten Methoden ab. Geprüft:

| ViewModel-Methode | Protokoll-Methode | Status |
|-------------------|------------------|--------|
| `getStats` / `getAnalyticsStats` | `getAnalyticsStats(websiteId:dateRange:)` | ✓ vorhanden |
| `getActiveVisitors` | `getActiveVisitors(websiteId:)` | ✓ vorhanden |
| `getPageviews`/`getPageviewsData`+`getVisitorsData` | `getPageviewsData` + `getVisitorsData` | ✓ vorhanden |
| `getMetrics(.path)` / `getPages` | `getPages(websiteId:dateRange:)` | ✓ vorhanden |
| `getMetrics(.referrer)` / `getReferrers` | `getReferrers(websiteId:dateRange:)` | ✓ vorhanden |
| `getMetrics(.country)` / `getCountries` | `getCountries(websiteId:dateRange:)` | ✓ vorhanden |
| `getMetrics(.device)` / `getDevices` | `getDevices(websiteId:dateRange:)` | ✓ vorhanden |
| `getMetrics(.browser)` / `getBrowsers` | `getBrowsers(websiteId:dateRange:)` | ✓ vorhanden |
| `getMetrics(.os)` / `getOS` | `getOS(websiteId:dateRange:)` | ✓ vorhanden |

**Methoden ohne Protokoll-Äquivalent (Plausible hat keine Daten):**
- `loadPageTitles` — `getMetrics(.title)` — Plausible gibt `[]` zurück
- `loadLanguages` — `getMetrics(.language)` — Plausible gibt `[]` zurück
- `loadScreens` — `getMetrics(.screen)` — Plausible gibt `[]` zurück
- `loadEvents` — `getMetrics(.event)` — Plausible gibt `[]` zurück
- `loadRegions` / `loadCities` — Plausible hat diese, Umami auch

**Lösung für Nicht-Protokoll-Methoden:** Diese gehören NICHT ins `AnalyticsProvider`-Protokoll (sie sind Umami-spezifisch). Das ViewModel ruft sie weiterhin direkt via `umamiAPI`-Cast oder — bevorzugt — als neue optionale Protokoll-Methoden mit Default-Implementierung:

```swift
// Option A: Optionale Protokoll-Extension (empfohlen)
extension AnalyticsProvider {
    func getRegions(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem] { [] }
    func getCities(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem] { [] }
    func getPageTitles(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem] { [] }
    func getLanguages(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem] { [] }
    func getScreens(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem] { [] }
    func getEvents(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsMetricItem] { [] }
}
```

UmamiAPI überschreibt diese mit echten Implementierungen, PlausibleAPI erbt die `[]`-Defaults.

**loadPageviews ist ein Sonderfall** — UmamiAPI gibt `PageviewsData` (mit `.pageviews` und `.sessions` Arrays), PlausibleAPI gibt `[AnalyticsChartPoint]` zurück. Nach der Vereinheitlichung muss das ViewModel beide über `getPageviewsData` und `getVisitorsData` aus dem Protokoll abrufen:

```swift
// NACHHER — kein if isPlausible mehr
private func loadPageviews(dateRange: DateRange) async {
    do {
        guard let provider = AnalyticsManager.shared.currentProvider else { return }
        let formatter = ISO8601DateFormatter()
        let pageviewData = try await provider.getPageviewsData(websiteId: websiteId, dateRange: dateRange)
        let visitorData = try await provider.getVisitorsData(websiteId: websiteId, dateRange: dateRange)
        pageviewsData = fillMissingTimeSlots(
            data: pageviewData.map { TimeSeriesPoint(x: formatter.string(from: $0.date), y: $0.value) },
            dateRange: dateRange
        )
        sessionsData = fillMissingTimeSlots(
            data: visitorData.map { TimeSeriesPoint(x: formatter.string(from: $0.date), y: $0.value) },
            dateRange: dateRange
        )
    } catch { ... }
}
```

**loadStats Sonderfall:** UmamiAPI.getStats gibt `WebsiteStats` zurück, nicht `AnalyticsStats`. Das ViewModel ruft aktuell direkt `umamiAPI.getStats()` auf. Nach der Vereinheitlichung ruft alles `provider.getAnalyticsStats()` auf — UmamiAPI hat diese bereits implementiert.

### Pattern 3: AuthManager entfernen — EnvironmentObject Migration (ARCH-01)

**Betroffene Views und ihre authManager-Referenzen:**

| View | Referenz | Ersatz |
|------|----------|--------|
| `ContentView` | `authManager.isAuthenticated` | `accountManager.activeAccount != nil` |
| `DashboardView` | `authManager.currentProvider == .plausible` | `accountManager.activeAccount?.providerType == .plausible` |
| `SettingsView` | `authManager.logout()` | `accountManager.clearActiveAccount()` + aufräumen |
| `SettingsView` | `authManager.currentProvider` | `accountManager.activeAccount?.providerType` |
| `SettingsView` | `authManager.username` | `accountManager.activeAccount?.name` oder neue Property |
| `SettingsView` | `authManager.serverURL` | `accountManager.activeAccount?.serverURL` |
| `LoginView` | `authManager.isLoading` | eigener `@State var isLoading` im ViewModel |
| `LoginView` | `authManager.errorMessage` | eigener `@State var errorMessage` im ViewModel |
| `LoginView` | `authManager.login(...)` | direkter AccountManager + API-Call |
| `LoginView` | `authManager.loginWithPlausible(...)` | direkter AccountManager + API-Call |

**AccountManager braucht `isAuthenticated`:** Aktuell fehlt ein `@Published var isAuthenticated` in AccountManager. ContentView braucht einen reaktiven Boolean. Optionen:

```swift
// Option A: Computed property mit @Published activeAccount (bereits vorhanden)
// ContentView liest: accountManager.activeAccount != nil
// Vorteil: kein neues Published-Feld nötig — activeAccount ist bereits @Published

// Option B: Explizites @Published var isAuthenticated = false
// Nachteil: muss bei setActiveAccount/clearActiveAccount synchronisiert werden
```

Option A wird empfohlen — `activeAccount != nil` ist semantisch korrekt und braucht kein neues Feld.

**AccountManager braucht `logout()`-Fähigkeit für SettingsView:**
`clearActiveAccount()` macht bereits das Richtige (löscht Keychain, SharedCredentials, sendet allAccountsRemoved). Aber SettingsView ruft aktuell auch `authManager.logout()` auf, was zusätzlich `umamiAPI.clearConfiguration()` und `PlausibleSitesManager.shared.clearAll()` auslöst. AccountManager's `clearActiveAccount()` muss diese Aufräum-Schritte auch übernehmen.

**LoginView-Migration:** LoginView enthält heute keine eigene Login-Logik — sie delegiert alles an AuthManager. Nach der Migration muss LoginView entweder:
- Direkt mit AccountManager + API-Services interagieren (kein separater ViewModel nötig, da die Logik von AuthManager übernommen wird), oder
- Ein `LoginViewModel` bekommt, das die Login-Flows kapselt

Empfehlung: `LoginViewModel` erstellen, das die `login()` und `loginWithPlausible()` Methoden aus AuthManager übernimmt. Das ist ein sauberer Schnitt und vermeidet, dass eine View direkt mit mehreren Services interagiert.

**InsightFlowApp.swift:** `@StateObject private var authManager = AuthManager()` und `.environmentObject(authManager)` werden entfernt. AccountManager.shared ist bereits ein Singleton — kein EnvironmentObject nötig.

**AnalyticsManager — was bleibt:** AnalyticsManager hat `currentProvider`, `providerType`, `isAuthenticated`. Sein `isAuthenticated` ist ein Duplikat von AccountManager. Nach ARCH-01:
- `AnalyticsManager.isAuthenticated` kann entfernt werden (nicht von Views genutzt)
- `AnalyticsManager.currentProvider` bleibt — WebsiteDetailViewModel nutzt es
- `AnalyticsManager.setProvider()` bleibt — AccountManager ruft es in `applyAccountCredentials()` auf
- `AnalyticsManager.logout()` bleibt — AccountManager ruft es in `clearActiveAccount()` auf

### Anti-Patterns to Avoid

- **actor ruft @MainActor-Methoden direkt auf:** `PlausibleSitesManager.shared.objectWillChange.send()` aus einem actor heraus ist ein Concurrency-Fehler. Der Aufrufer (AccountManager, @MainActor) muss das übernehmen.
- **ObservableObject auf actor:** Swift actors können kein `ObservableObject` konformieren. PlausibleAPI verliert `@Published` und `objectWillChange` vollständig.
- **isAuthenticated duplizieren:** Nach der Migration darf nur eine Quelle der Wahrheit für Auth-State existieren. `AccountManager.activeAccount != nil` ist diese Quelle.
- **EnvironmentObject durch anderen EnvironmentObject ersetzen:** AccountManager soll KEIN EnvironmentObject werden — es ist ein Singleton, Views lesen ihn direkt via `@ObservedObject private var accountManager = AccountManager.shared`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Protocol Default-Implementierungen | Eigene Wrapper-Klassen | Swift Protocol Extensions | Swift-native, kein Overhead |
| actor-Thread-Safety | Manuelle Locks | Swift actor | Compiler-enforced isolation |
| Reaktiver Auth-State ohne ObservableObject | NotificationCenter-Kette | `@Published var activeAccount` auf AccountManager | Bereits vorhanden, funktioniert |

---

## Common Pitfalls

### Pitfall 1: actor kann kein ObservableObject sein
**Was schiefläuft:** `actor PlausibleAPI: ObservableObject` kompiliert nicht. Actor-Isolation ist nicht kompatibel mit `@Published` (braucht MainActor) und `objectWillChange`.
**Warum:** Swift actors haben eigene Isolation, `@Published` erfordert `@MainActor`.
**Vermeidung:** PlausibleAPI wird reiner `actor`, verliert `ObservableObject`-Konformanz. Alle `objectWillChange.send()`-Aufrufe aus `reconfigureFromKeychain()` werden entfernt.
**Warnsignal:** Compiler-Fehler "type 'PlausibleAPI' cannot conform to protocol 'ObservableObject' in non-isolation context"

### Pitfall 2: nonisolated auf actor darf keinen mutable actor-State lesen
**Was schiefläuft:** `nonisolated var apiKey: String? { self._apiKey }` — wenn `_apiKey` actor-isoliertes Feld ist, compiliert das nicht.
**Warum:** nonisolated Properties können nicht auf actor-isolierten Feldern basieren.
**Vermeidung:** nonisolated Properties lesen aus Keychain (extern, threadsafe) statt aus actor-Feldern. Exakt das Muster von UmamiAPI.
**Warnsignal:** Compiler-Fehler "actor-isolated property '_apiKey' can not be referenced from a non-isolated context"

### Pitfall 3: PlausibleAPI.shared wird von @MainActor-Klassen aufgerufen
**Was schiefläuft:** AccountManager (`@MainActor`) ruft `await PlausibleAPI.shared.reconfigureFromKeychain()` — nach der actor-Umstellung ist das ein async-Aufruf der explizit awaited werden muss.
**Warum:** Calls auf actor-Methoden von außen erfordern `await`.
**Vermeidung:** `AccountManager.applyAccountCredentials()` ist bereits `@MainActor`, kann `Task { await PlausibleAPI.shared.reconfigureFromKeychain() }` spawnen oder `async` werden.
**Warnsignal:** Compiler-Fehler "expression is 'async' but is not marked with 'await'"

### Pitfall 4: ContentView verliert Reaktivität wenn AuthManager entfernt wird
**Was schiefläuft:** ContentView switcht zwischen LoginView und MainTabView anhand `authManager.isAuthenticated`. Wenn AuthManager entfernt wird und kein reaktiver Ersatz vorhanden ist, aktualisiert sich die View nicht mehr beim Login/Logout.
**Warum:** SwiftUI-Reaktivität erfordert `@Published` + `ObservableObject` oder `@State`.
**Vermeidung:** ContentView observiert `AccountManager.shared` via `@ObservedObject` und nutzt `accountManager.activeAccount != nil`. AccountManager ist `@MainActor class ObservableObject` mit `@Published var activeAccount` — das ist bereits reaktiv.

### Pitfall 5: SettingsView zeigt "leeren" Account-Row wenn AccountManager.accounts leer ist
**Was schiefläuft:** `currentAccountRow` zeigt `authManager.currentProvider`, `authManager.username`, `authManager.serverURL`. Nach der Migration ist der Fallback (wenn accounts leer) ungetestet.
**Warum:** AccountManager kann `accounts.isEmpty == true` haben wenn jemand direkt über den alten Login-Flow authentifiziert ist ohne addAccount zu rufen (Legacy-Path existiert noch als `migrateFromLegacyCredentials`).
**Vermeidung:** `currentAccountRow` auf `accountManager.activeAccount` umstellen. Falls `activeAccount` nil, Row verstecken.

### Pitfall 6: AnalyticsManager.shared.currentProvider ist nil nach App-Start
**Was schiefläuft:** WebsiteDetailViewModel nutzt `AnalyticsManager.shared.currentProvider` für alle Calls. Wenn AccountManager `applyAccountCredentials()` aufruft, setzt er `AnalyticsManager.shared.setProvider()` — aber nur wenn ein activeAccount existiert. Falls das ViewModel zu früh geladen wird, ist currentProvider nil.
**Warum:** Race-Condition zwischen AccountManager.init() und View-Erscheinen.
**Vermeidung:** `guard let provider = AnalyticsManager.shared.currentProvider else { return }` in jeder loadX()-Methode. ViewModel zeigt Ladeindikator statt Fehler.

---

## Code Examples

### ARCH-03: PlausibleAPI als actor (Minimaländerung)

```swift
// Vorher: @MainActor class PlausibleAPI: ObservableObject, AnalyticsProvider
// Nachher:
actor PlausibleAPI: AnalyticsProvider {
    static let shared = PlausibleAPI()

    nonisolated let providerType: AnalyticsProviderType = .plausible

    nonisolated var serverURL: String {
        KeychainService.load(for: .serverURL) ?? "https://plausible.io"
    }

    nonisolated var isAuthenticated: Bool {
        KeychainService.load(for: .apiKey) != nil
    }

    nonisolated var apiKey: String? {
        KeychainService.load(for: .apiKey)
    }

    private let decoder: JSONDecoder = { ... }()  // unverändert

    private init() {}

    func reconfigureFromKeychain() {
        // PlausibleAPI hat keinen mutable actor state — nur Keychain-basierte Properties
        // Kein objectWillChange.send() mehr
        // PlausibleSitesManager-Notification muss AccountManager übernehmen
    }
    // ... alle anderen Methoden unverändert (nur self. bleibt, da actor-isoliert)
}
```

### ARCH-02: ViewModel loadStats ohne Branching

```swift
// Vorher
private func loadStats(dateRange: DateRange) async {
    do {
        if isPlausible {
            let analyticsStats = try await plausibleAPI.getAnalyticsStats(...)
            stats = WebsiteStats(pageviews: ..., ...)
        } else {
            stats = try await umamiAPI.getStats(...)
        }
    } catch { ... }
}

// Nachher
private func loadStats(dateRange: DateRange) async {
    guard let provider = AnalyticsManager.shared.currentProvider else { return }
    do {
        let analyticsStats = try await provider.getAnalyticsStats(websiteId: websiteId, dateRange: dateRange)
        stats = analyticsStats.toWebsiteStats()
    } catch {
        self.error = error.localizedDescription
    }
}
```

(`AnalyticsStats.toWebsiteStats()` existiert bereits in AnalyticsProvider.swift Zeile 84.)

### ARCH-01: ContentView ohne AuthManager

```swift
// Vorher
struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    var body: some View {
        Group {
            if authManager.isAuthenticated { MainTabView() } else { LoginView() }
        }
        .animation(.smooth, value: authManager.isAuthenticated)
    }
}

// Nachher
struct ContentView: View {
    @ObservedObject private var accountManager = AccountManager.shared
    var body: some View {
        Group {
            if accountManager.activeAccount != nil { MainTabView() } else { LoginView() }
        }
        .animation(.smooth, value: accountManager.activeAccount != nil)
    }
}
```

### ARCH-01: AccountManager clearActiveAccount erweitern

```swift
// AccountManager.clearActiveAccount() — zusätzliche Aufräum-Schritte hinzufügen
func clearActiveAccount() {
    activeAccount = nil
    UserDefaults.standard.removeObject(forKey: activeAccountKey)

    KeychainService.deleteAll()
    SharedCredentials.delete()
    AnalyticsManager.shared.logout()

    // NEU: API-Services aufräumen
    Task { @MainActor in
        await UmamiAPI.shared.clearConfiguration()
        PlausibleSitesManager.shared.clearAll()
    }

    NotificationCenter.default.post(name: .allAccountsRemoved, object: nil)
    WidgetCenter.shared.reloadAllTimelines()
}
```

---

## State of the Art

| Alter Ansatz | Aktueller Ansatz | Relevanz |
|--------------|-----------------|----------|
| `@MainActor class` für Services | `actor` für Services | ARCH-03 genau das |
| Duplikate Auth-State | Single Source of Truth | ARCH-01 |
| Direkte API-Auswahl im ViewModel | Protocol Dispatch | ARCH-02 |

---

## Open Questions

1. **AnalyticsManager nach ARCH-01 — behalten oder entfernen?**
   - Was wir wissen: AnalyticsManager hält `currentProvider` und `setProvider()` — WebsiteDetailViewModel liest daraus
   - Was unklar ist: Soll AnalyticsManager in AccountManager integriert werden oder als schlanker Provider-Container bestehen bleiben?
   - Empfehlung: AnalyticsManager behalten, aber `isAuthenticated`-Property entfernen (da Duplikat). AccountManager ruft `setProvider()` schon auf — das Zusammenspiel funktioniert bereits. Eine vollständige Integration in AccountManager würde den Scope von ARCH-01 deutlich erweitern.

2. **LoginView-Migration — separates LoginViewModel oder direkter AccountManager-Aufruf?**
   - Was wir wissen: LoginView hat heute @State für isLoading, errorMessage implizit via authManager
   - Empfehlung: `LoginViewModel` (@MainActor class ObservableObject) mit `login()` und `loginWithPlausible()` — übernimmt Code 1:1 aus AuthManager. LoginView wird reines UI-Element ohne direkte Service-Abhängigkeit.

3. **`currentAccountRow` in SettingsView bei leerem AccountManager**
   - Was wir wissen: `if accountManager.accounts.isEmpty { currentAccountRow }` — dieser Row zeigt authManager-Daten
   - Was unklar ist: Kann dieser Zustand nach Phase 1 noch auftreten?
   - Empfehlung: Row auf `accountManager.activeAccount` umstellen. Wenn nil, Row ausblenden.

---

## Environment Availability

Step 2.6: SKIPPED — Phase ist reine Code/Architektur-Änderung, keine externen Dependencies.

---

## Validation Architecture

> `workflow.nyquist_validation` ist nicht explizit auf false gesetzt — Sektion wird einbezogen.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Keines — kein Test-Target existiert (Phase 5 bringt Tests) |
| Config file | Nicht vorhanden |
| Quick run command | Build im Simulator (cmd+B) — kein automatisierter Test |
| Full suite command | Manueller Smoke-Test |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | Datei vorhanden? |
|--------|----------|-----------|-------------------|-----------------|
| ARCH-03 | PlausibleAPI.shared kann von einem non-MainActor await'd werden ohne Compiler-Fehler | compile | `xcodebuild -scheme InsightFlow build` | ❌ kein Test-Target |
| ARCH-02 | WebsiteDetailViewModel enthält kein `if isPlausible` mehr | compile + manual | grep-Prüfung: `grep -r "isPlausible" InsightFlow/` | ❌ kein Test-Target |
| ARCH-01 | Login, Account-Switch, Logout funktionieren für beide Provider | manual smoke | Manueller Test auf Simulator | ❌ kein Test-Target |

### Sampling Rate
- **Per task commit:** `xcodebuild -scheme InsightFlow build -destination 'platform=iOS Simulator,name=iPhone 16'` — Build muss clean sein
- **Per wave merge:** Manueller Smoke-Test: Login (Umami), Login (Plausible), Account-Switch, Logout
- **Phase gate:** Clean Build + Smoke-Test bestanden vor `/gsd:verify-work`

### Wave 0 Gaps
- Kein Test-Target — Compiler-Build ist einziger automatisierter Check. Phase 5 bringt Unit Tests.
- `grep -r "isPlausible" InsightFlow/` nach ARCH-02 muss leer sein — als post-task check verwendbar.
- `grep -r "AuthManager" InsightFlow/ --include="*.swift" | grep -v "//\|AuthManager.swift"` nach ARCH-01 muss leer sein.

---

## Sources

### Primary (HIGH confidence)
- Direkte Codebase-Analyse — alle genannten Dateien vollständig gelesen:
  - `InsightFlow/Services/AuthManager.swift`
  - `InsightFlow/Services/AccountManager.swift`
  - `InsightFlow/Services/AnalyticsProvider.swift`
  - `InsightFlow/Services/PlausibleAPI.swift`
  - `InsightFlow/Services/UmamiAPI.swift`
  - `InsightFlow/Views/Detail/WebsiteDetailViewModel.swift`
  - `InsightFlow/App/InsightFlowApp.swift`
  - `InsightFlow/App/ContentView.swift`
  - `InsightFlow/Views/Settings/SettingsView.swift`
  - `InsightFlow/Views/Auth/LoginView.swift`
  - `InsightFlow/Views/Dashboard/DashboardView.swift`
- Swift Language Reference: actor isolation, nonisolated, @MainActor

### Secondary (MEDIUM confidence)
- Swift Evolution Proposal SE-0306 (Actors) — Compiler-Verhalten für actor + nonisolated gut dokumentiert

---

## Metadata

**Confidence breakdown:**
- ARCH-03 (actor-Umstellung): HIGH — klares Muster aus UmamiAPI vorhanden, Unterschiede zu PlausibleAPI vollständig analysiert
- ARCH-02 (ViewModel-Branching): HIGH — alle 15 Branches identifiziert, Protokoll-Coverage geprüft, Sonderfälle dokumentiert
- ARCH-01 (AuthManager entfernen): HIGH — alle 4 View-Abhängigkeiten kartiert, Ersatz-Properties identifiziert, offene Fragen transparent gemacht

**Research date:** 2026-03-27
**Valid until:** 2026-04-27 (stabiler Swift-Stack, keine externen Dependencies)
