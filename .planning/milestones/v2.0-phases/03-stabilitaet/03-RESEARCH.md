# Phase 3: Stabilität — Research

**Researched:** 2026-03-27
**Domain:** Swift Concurrency, Force-Unwrap-Elimination, Timing-Koordination
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
Keine — alle Implementierungsentscheidungen liegen im Ermessen von Claude.

### Claude's Discretion
All implementation choices are at Claude's discretion — pure stability/reliability phase. Key technical context:

- Phase 1 modifizierte AccountManager.swift (Keychain-basierte Credentials) und SharedCredentials.swift
- Phase 2 splitete Widget-Code in 9 Dateien — Force Unwraps im Widget liegen jetzt in WidgetNetworking.swift
- Force Unwraps in PlausibleAPI.swift: Lines 305, 447, 482, 516, 557, 583 — `URL(string:)!`
- Force Unwraps in UmamiAPI.swift: Line 528 — `URLComponents(...)!`
- Force Unwraps in Widget-Code (jetzt WidgetNetworking.swift): Lines 37, 182, 186, 189, 200, 206, 251, 258, 293, 380, 384, 388, 394, 395, 400, 401, 534, 595, 598
- Timing-Hacks in AccountManager.swift: `DispatchQueue.main.asyncAfter(deadline: .now() + 0.3)` (Zeile 295)
- Timing-Hacks in AuthManager.swift: `Task.sleep(nanoseconds: 100_000_000)` (Zeile 93) wartet auf PlausibleSitesManager

### Deferred Ideas (OUT OF SCOPE)
Keine — Infrastructure-Phase.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| STAB-01 | Alle Force Unwraps in Networking-Code durch guard-let mit Error Handling ersetzt | Vollständiger Code-Audit durchgeführt — alle Fundstellen dokumentiert, Ersetzungsmuster klar |
| STAB-02 | Timing-Hacks (asyncAfter, Task.sleep) durch async/await Koordination ersetzt | Race-Condition-Analyse abgeschlossen — zwei Fundstellen, beide lösbar ohne externe Dependencies |
</phase_requirements>

---

## Summary

Phase 3 beseitigt zwei Klassen von Stabilitätsproblemen: Force-Unwraps in URL-Konstruktion und zeitbasierte Koordinations-Hacks zwischen Managern.

**STAB-01 (Force Unwraps):** Der Code-Audit hat zwei distinkte Kategorien aufgedeckt. Kategorie A sind "echte" Force Unwraps, die abstürzen können, wenn der Keychain-Wert `serverURL` eine ungültige URL enthält — das betrifft `PlausibleAPI.swift` (6 Stellen) und `UmamiAPI.swift` (1 Stelle). Kategorie B sind `calendar.date(byAdding:)!`-Force-Unwraps im Widget (14+ Stellen) — diese sind faktisch sicher, da Calendar-Berechnungen mit `Date()`-Basis nie nil zurückgeben, gelten aber stilistisch als Force Unwrap. Die Anforderung in STAB-01 spricht explizit von "Networking-Code" und nennt `URL(string:)` und `URLComponents.url` — daher ist Kategorie B aus dem Scope.

**STAB-02 (Timing-Hacks):** Das `asyncAfter` in `AccountManager.applyAccountCredentials()` soll sicherstellen, dass alle `@Published`-Properties gesetzt sind, bevor `.accountDidChange` gefeuert wird. Das `Task.sleep` in `AuthManager.loadPlausibleCredentials()` wartet darauf, dass `PlausibleSitesManager` seine Sites aus UserDefaults geladen hat. Beide Hacks sind Symptome fehlender Koordination. Der bessere Ansatz: Bei AccountManager direkt nach Abschluss aller Operationen die Notification synchron posten; bei AuthManager die Sites direkt lesen ohne Delay (PlausibleSitesManager wird im App-Start vor AuthManager initialisiert).

**Primary recommendation:** STAB-01: 7 URL/URLComponents-Force-Unwraps mit `guard let` + spezifischem Fehlerwurf ersetzen; Widget-`calendar.date!` ebenfalls mit `guard let` + Fallback absichern. STAB-02: `asyncAfter` durch direktes Notification-Posting nach dem synchronen Credential-Apply ersetzen; `Task.sleep` durch direktes Lesen ohne Delay entfernen.

---

## Standard Stack

### Core (bereits im Projekt vorhanden)
| Komponente | Version | Zweck | Warum Standard |
|-----------|---------|-------|----------------|
| Swift Concurrency | Swift 5.9+ (Xcode 15) | `async throws`, `actor`, `@MainActor` | Bereits im gesamten Codebase genutzt |
| Foundation `URL` | System | URL-Konstruktion | Einzige sinnvolle Option |
| NotificationCenter + Combine | System | Komponenten-Koordination | Bereits in AuthManager.setupNotifications() genutzt |

**Keine externen Dependencies.** Alle Fixes sind Pure-Swift mit System-Frameworks.

---

## Architecture Patterns

### Pattern 1: URL-Konstruktion mit guard let

**Was:** Force-Unwrap `URL(string:)!` → `guard let` mit spezifischem Error-Throw
**Wann:** Überall wo `serverURL` aus dem Keychain kommt (kann theoretisch korrupter String sein)

**Aktueller Code (PlausibleAPI.swift, Zeilen 447, 482, 516, 557, 583):**
```swift
// VORHER — stürzt ab wenn serverURL ungültig
let url = URL(string: "\(serverURL)/api/v1/sites")!
```

**Ziel-Pattern:**
```swift
// NACHHER — propagiert Fehler
guard let url = URL(string: "\(serverURL)/api/v1/sites") else {
    throw PlausibleError.invalidResponse
}
```

**Sonderfall: `components.url!` in PlausibleAPI.swift, Zeile 302+305 (`getActiveVisitors`):**
```swift
// VORHER
var components = URLComponents(url: baseURL.appendingPathComponent("..."), resolvingAgainstBaseURL: false)!
// ...
var request = URLRequest(url: components.url!)
```

```swift
// NACHHER — beide Stellen zusammen
guard var components = URLComponents(url: baseURL.appendingPathComponent("api/v1/stats/realtime/visitors"), resolvingAgainstBaseURL: false) else {
    throw PlausibleError.invalidResponse
}
components.queryItems = [URLQueryItem(name: "site_id", value: websiteId)]
guard let url = components.url else {
    throw PlausibleError.invalidResponse
}
var request = URLRequest(url: url)
```

### Pattern 2: URLComponents-Force-Unwrap in UmamiAPI.swift (Zeile 528)

**Aktueller Code:**
```swift
var components = URLComponents(url: baseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: true)!
```

Besonderheit: Der nachfolgende Code prüft bereits `guard let url = components.url` — die erste `!`-Stelle ist redundant, da `URLComponents(url:resolvingAgainstBaseURL:)` nur nil zurückgibt wenn `url` absolut ungültig ist. Trotzdem:

```swift
guard var components = URLComponents(url: baseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: true) else {
    throw APIError.invalidURL
}
```

### Pattern 3: Widget URLComponents + calendar.date Force-Unwraps

**Fundstellen in WidgetNetworking.swift:**
- Zeilen 200, 206: `URLComponents(...)!` und `statsURL.url!`
- Zeilen 251, 258: `URLComponents(...)!` und `pvURL.url!`
- Zeilen 595, 598: `URLComponents(...)!` und `realtimeComponents.url!`
- Zeile 37: `Calendar.current.date(byAdding:)!` (nextRefresh)
- Zeilen 182, 186, 189, 293, 380, 384, 388, 394, 395, 400, 401, 534: `calendar.date(byAdding:)!`

**URLComponents.url! Pattern (Widget):**
Das Widget hat keine `throws`-Methoden (async, kein throws). Force-Unwraps müssen durch guard-mit-Fallback ersetzt werden:
```swift
// VORHER
var statsURL = URLComponents(url: baseURL.appendingPathComponent("api/websites/\(website.id)/stats"), resolvingAgainstBaseURL: false)!
statsURL.queryItems = [...]
var statsReq = URLRequest(url: statsURL.url!)
```

```swift
// NACHHER
guard var statsURL = URLComponents(url: baseURL.appendingPathComponent("api/websites/\(website.id)/stats"), resolvingAgainstBaseURL: false),
      let statsURLBuilt = { statsURL.queryItems = [...]; return statsURL.url }() else {
    return .error(String(localized: "widget.error.invalidURL"))
}
var statsReq = URLRequest(url: statsURLBuilt)
```

Oder einfacher — den `url`-Check nach dem queryItems-Setzen:
```swift
guard var statsURL = URLComponents(url: baseURL.appendingPathComponent("..."), resolvingAgainstBaseURL: false) else {
    return .error(String(localized: "widget.error.invalidURL"))
}
statsURL.queryItems = [...]
guard let statsURLBuilt = statsURL.url else {
    return .error(String(localized: "widget.error.invalidURL"))
}
var statsReq = URLRequest(url: statsURLBuilt)
```

**calendar.date(byAdding:)! Pattern (Widget):**
`Calendar.date(byAdding:)` gibt faktisch nie nil zurück für normale Integer-Offsets auf `Date()`. Stilistisch richtig ist trotzdem `guard let` mit Fallback-Date:
```swift
// VORHER
let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!

// NACHHER — nil-safe mit sicherem Fallback
let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
```
Das ist ein akzeptabler Fallback: falls Calendar nil zurückgibt (praktisch unmöglich), wird `now` als Fallback benutzt, was zu falschen Daten aber keinem Absturz führt.

**nextRefresh-Force-Unwrap (Zeile 37):**
```swift
// VORHER
let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: now)!

// NACHHER
let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(15 * 60)
```

### Pattern 4: asyncAfter-Entfernung in AccountManager.swift (Zeile 295)

**Problem:** Der 0.3-Sekunden-Delay in `applyAccountCredentials` soll sicherstellen, dass alle `@Published`-Properties gesetzt sind bevor die Notification abgefeuert wird.

**Analyse:** Da `applyAccountCredentials` auf `@MainActor` läuft und alle vorherigen Operationen synchron sind (Keychain-Schreibvorgänge, `setSitesWithoutPersist`, `reconfigureFromKeychain`, `setProvider`), sind alle Properties bereits gesetzt wenn die Funktion auf die Notification-Zeile trifft. Das `asyncAfter` ist unnötig.

```swift
// VORHER
DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
    NotificationCenter.default.post(name: .accountDidChange, object: nil)
}

// NACHHER — synchron, kein Delay nötig
NotificationCenter.default.post(name: .accountDidChange, object: nil)
```

**Vorsicht:** Prüfen ob UI-Code der `accountDidChange`-Notification einen Synchronisations-Erwartung hat (z.B. ein View der sich neu lädt und darauf angewiesen ist, dass AnalyticsManager schon konfiguriert ist). Die Notification wird weiterhin auf dem MainActor dispatched, da `applyAccountCredentials` selbst `@MainActor` ist.

### Pattern 5: Task.sleep-Entfernung in AuthManager.swift (Zeile 93)

**Problem:** `loadPlausibleCredentials()` wartet 0.1 Sekunden auf `PlausibleSitesManager.shared.getSites()`.

**Analyse:** `AuthManager.init()` ruft `loadStoredCredentials()` → `loadPlausibleCredentials()` auf. `PlausibleSitesManager` ist ein `@MainActor`-Singleton und lädt Sites in `init()` aus UserDefaults — diese `init()` wurde bereits beim App-Start aufgerufen bevor `AuthManager.init()` läuft (Swift lazy singletons: first access bestimmt Reihenfolge, aber `PlausibleSitesManager.shared` wird typischerweise früher im Code referenziert).

**Echter Fix:** Das `Task.sleep` + Block kann vollständig entfernt werden, da:
1. `PlausibleSitesManager.shared` bei Zugriff bereits initialisiert ist
2. `getSites()` ist synchron und gibt sofort zurück
3. Beim App-Start läuft `AuthManager.init()` auf dem MainActor — zu diesem Zeitpunkt ist `PlausibleSitesManager.shared` bereits initialisiert (wird in `AccountManager.applyAccountCredentials` und `PlausibleAPI` referenziert, die beide früher im Stack aktiv werden)

```swift
// VORHER
private func loadPlausibleCredentials() {
    guard let serverURLString = KeychainService.load(for: .serverURL),
          let apiKey = KeychainService.load(for: .apiKey) else { return }

    serverURL = serverURLString
    currentProvider = .plausible

    Task { @MainActor in
        try? await Task.sleep(nanoseconds: 100_000_000)  // <- entfernen
        let sites = PlausibleSitesManager.shared.getSites()
        SharedCredentials.save(
            serverURL: serverURLString, token: apiKey,
            providerType: .plausible, sites: sites
        )
        WidgetCenter.shared.reloadAllTimelines()
    }
    // ...
}
```

```swift
// NACHHER — synchroner Task ohne Sleep
private func loadPlausibleCredentials() {
    guard let serverURLString = KeychainService.load(for: .serverURL),
          let apiKey = KeychainService.load(for: .apiKey) else { return }

    serverURL = serverURLString
    currentProvider = .plausible

    Task { @MainActor in
        let sites = PlausibleSitesManager.shared.getSites()
        SharedCredentials.save(
            serverURL: serverURLString, token: apiKey,
            providerType: .plausible, sites: sites
        )
        WidgetCenter.shared.reloadAllTimelines()
    }
    // ...
}
```

Alternativ (noch sauberer): Da alles `@MainActor` ist, den Block direkt ohne Task wrapen:
```swift
let sites = PlausibleSitesManager.shared.getSites()
SharedCredentials.save(serverURL: serverURLString, token: apiKey, providerType: .plausible, sites: sites)
WidgetCenter.shared.reloadAllTimelines()
```

### Anti-Patterns to Avoid

- **`try! URL(string:)`:** Kein Fortschritt — immer noch Force-Unwrap.
- **`guard ... else { fatalError() }`:** Produziert ebenfalls Absturz — nicht akzeptabel.
- **Fehler still schlucken (`guard ... else { return }` ohne throw):** In `async throws`-Methoden muss ein passender Error geworfen werden, nicht lautlos abgebrochen.
- **`Task.sleep` durch `asyncAfter` ersetzen:** Kein Fix — tauscht einen Hack gegen den anderen.
- **`Continuation` für Notification-Warten:** Over-Engineering für diesen Fall.

---

## Don't Hand-Roll

| Problem | Nicht bauen | Stattdessen | Warum |
|---------|-------------|-------------|-------|
| URL-Validierung | Custom URL-Validator-Klasse | `URL(string:)` + guard let | Foundation reicht, serverURL kommt bereits normalisiert aus dem Keychain |
| Koordinations-Mechanismus | Observer-Pattern oder Async-Stream | Direktes synchrones Posting auf @MainActor | Komplexität unnötig — alle Beteiligten sind bereits @MainActor |
| Retry-Logik für Keychain | Custom Retry-Wrapper | Kein Retry — einmaliger guard let | Keychain-Wert ist stabil, Retry ändert nichts |

---

## Common Pitfalls

### Pitfall 1: URLComponents.url gibt nil nach queryItems-Setzen
**Was läuft schief:** Man ersetzt `URLComponents(...)!` korrekt, aber `components.url` ist noch hinter einem Force-Unwrap.
**Warum es passiert:** Die two-step Konstruktion wird als eine Einheit betrachtet.
**Prävention:** Beide Stellen (`URLComponents(url:)` und `.url`) gemeinsam auf guard let umstellen.
**Warnsignal:** `!` auf `.url` Property nach dem queryItems-Setzen.

### Pitfall 2: asyncAfter-Entfernung bricht Account-Switching-UI
**Was läuft schief:** Notification wird gefeuert, bevor SwiftUI-Views auf den neuen State reagieren können.
**Warum es passiert:** Der Delay kaschiert potentielle View-Update-Timing-Probleme.
**Prävention:** Nach Entfernung den Account-Switch-Flow manuell durchspielen. Da `applyAccountCredentials` `@MainActor` ist, ist die Notification garantiert auf dem MainActor — SwiftUI-Observables werden danach korrekt aktualisiert.
**Warnsignal:** UI zeigt kurzzeitig alten State nach Account-Wechsel.

### Pitfall 3: Task.sleep-Entfernung macht PlausibleSitesManager-Timing-Annahme explizit
**Was läuft schief:** Sites sind tatsächlich leer weil `PlausibleSitesManager.shared` noch nicht aus UserDefaults geladen hat.
**Warum es passiert:** Swift Singletons sind lazy — if `AuthManager` vor `PlausibleSitesManager` zum ersten Mal instanziiert wird, ist `getSites()` leer.
**Prävention:** Die App-Startup-Reihenfolge überprüfen. In der aktuellen Codebasis referenziert `AccountManager.init()` bereits `PlausibleSitesManager.shared` (über `migrateFromLegacyCredentials()`), und `AccountManager.shared` wird vor `AuthManager` erstellt (da AuthManager auf AccountManager.shared zugreift). Die Initialisierungsreihenfolge ist: AccountManager → PlausibleSitesManager (lazy) → AuthManager. Das Sleep ist unnötig.
**Warnsignal:** Nach Fix: Widget-Credentials nach App-Neustart leer.

### Pitfall 4: Widget-Methoden sind nicht `throws` — anderer Fehler-Rückgabeweg
**Was läuft schief:** In `fetchUmamiStats` / `fetchPlausibleStats` kann man nicht einfach `throw` benutzen.
**Warum es passiert:** Widget-Provider-Methoden sind `async` aber nicht `throws`.
**Prävention:** Im Widget `return .error(...)` statt `throw` benutzen. Bereits im Code so gehandhabt — muss konsistent bleiben.

---

## Vollständiger Force-Unwrap-Audit (aktueller Stand)

### PlausibleAPI.swift — STAB-01 relevant
| Zeile | Code | Kategorie | Fix |
|-------|------|-----------|-----|
| 302 | `URLComponents(...)!` | URL-Konstruktion | guard let + throw PlausibleError.invalidResponse |
| 305 | `components.url!` | URLComponents.url | guard let + throw PlausibleError.invalidResponse |
| 447 | `URL(string: "\(serverURL)/...")!` | URL-Konstruktion | guard let + throw PlausibleError.invalidResponse |
| 482 | `URL(string: "\(serverURL)/...")!` | URL-Konstruktion | guard let + throw PlausibleError.invalidResponse |
| 516 | `URL(string: "\(serverURL)/...")!` | URL-Konstruktion | guard let + throw PlausibleError.invalidResponse |
| 557 | `URL(string: "\(serverURL)/...")!` | URL-Konstruktion (private `request`) | guard let + throw PlausibleError.invalidResponse |
| 583 | `URL(string: "\(serverURL)/...")!` | URL-Konstruktion (private `postRequest`) | guard let + throw PlausibleError.invalidResponse |

### UmamiAPI.swift — STAB-01 relevant
| Zeile | Code | Kategorie | Fix |
|-------|------|-----------|-----|
| 528 | `URLComponents(url:...)!` | URLComponents | guard let + throw APIError.invalidURL |

### WidgetNetworking.swift — STAB-01 relevant
| Zeile | Code | Kategorie | Fix |
|-------|------|-----------|-----|
| 37 | `Calendar.current.date(byAdding:)!` | nextRefresh | `?? now.addingTimeInterval(15 * 60)` |
| 182 | `calendar.date(byAdding:)!` | startDate | `?? now` |
| 184 | `.addingTimeInterval(-1)` | endDate | Kein Force-Unwrap, bleibt |
| 186 | `calendar.date(byAdding:)!` | startDate | `?? now` |
| 189 | `calendar.date(byAdding:)!` | startDate | `?? now` |
| 200 | `URLComponents(...)!` | URL-Konstruktion | guard let + return .error |
| 206 | `statsURL.url!` | URLComponents.url | guard let + return .error |
| 251 | `URLComponents(...)!` | URL-Konstruktion | guard let + return .error |
| 258 | `pvURL.url!` | URLComponents.url | guard let + return .error |
| 293 | `calendar.date(byAdding:)!` | baseDate | `?? now` |
| 380 | `calendar.date(byAdding:)!` | yesterday | `?? now` |
| 384 | `calendar.date(byAdding:)!` | yesterday (Plausible) | `?? now` |
| 388 | `calendar.date(byAdding:)!` | dayBefore | `?? now` |
| 394 | `calendar.date(byAdding:)!` | start | `?? now` |
| 395 | `calendar.date(byAdding:)!` | end | `?? now` |
| 400 | `calendar.date(byAdding:)!` | start | `?? now` |
| 401 | `calendar.date(byAdding:)!` | end | `?? now` |
| 534 | `calendar.date(byAdding:)!` | baseDate (Plausible) | `?? now` |
| 595 | `URLComponents(...)!` | URL-Konstruktion | guard let + return .error |
| 598 | `realtimeComponents.url!` | URLComponents.url | guard let + return .error |

### Timing-Hacks
| Datei | Zeile | Code | Fix |
|-------|-------|------|-----|
| AccountManager.swift | 295 | `DispatchQueue.main.asyncAfter(deadline: .now() + 0.3)` | Synchrones Notification-Posting auf @MainActor |
| AuthManager.swift | 93 | `try? await Task.sleep(nanoseconds: 100_000_000)` | Zeile entfernen |

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Keine Testsuite vorhanden (Phase 5: TEST-01) |
| Config file | — |
| Quick run command | — |
| Full suite command | — |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| STAB-01 | Kein Absturz bei ungültiger serverURL | manual-only | — | — |
| STAB-01 | Korrekte Error-Propagation statt Crash | manual-only | — | — |
| STAB-02 | Account-Switch erzeugt keinen inkonsistenten Auth-State | manual-only | — | — |

**Begründung manual-only:** Es gibt keine Testsuite (TEST-01 ist Phase 5). Tests für Concurrency-Bugs (Race Conditions) erfordern eine XCTest-Infrastruktur mit async-Unterstützung. Diese Phase liefert den stabilen Code, der in Phase 5 getestet wird.

### Verification Strategy (ohne automatisierte Tests)
Da keine Testsuite vorhanden ist, erfolgt Verifikation durch:
1. **Compiler-Check:** Xcode Build muss ohne Warnings kompilieren
2. **Account-Switch-Test:** In der App zwischen zwei Accounts wechseln und prüfen, dass der UI-State konsistent ist
3. **Fehler-Propagation:** Manueller Test mit korrupter serverURL in der Keychain nicht nötig — guard-let-Pattern selbst ist korrekt durch Compiler verifiziert

### Wave 0 Gaps
- [ ] Keine Testdateien vorhanden — Phase 5 (TEST-01) adressiert dies

---

## Environment Availability

Step 2.6: SKIPPED — Phase ist rein code/config-seitig, keine externen Dependencies.

---

## State of the Art

| Alter Ansatz | Aktueller Ansatz | Geändert | Impact |
|-------------|-----------------|---------|--------|
| Force-Unwrap für "kann nicht fehlschlagen" | guard let + throw | Gute Swift-Praxis seit Swift 2 | Kein Absturz bei unerwarteten nil-Werten |
| Timing-Hacks mit asyncAfter/sleep | Explizite async/await Koordination | Swift Concurrency (iOS 15+) | Deterministisches Verhalten, keine Race Windows |

---

## Open Questions

1. **Notification-Timing nach asyncAfter-Entfernung**
   - Was wir wissen: Der 0.3s Delay kaschiert möglicherweise ein UI-Problem, das unabhängig vom Delay existiert.
   - Was unklar ist: Ob Views, die `accountDidChange` beobachten, eine Frame-Pause benötigen um ihren State zu resetten bevor sie neu laden.
   - Empfehlung: Nach Entfernung den Account-Switch-Flow in der App manuell testen. Falls UI-Artefakte auftreten, `await Task.yield()` als Ersatz einsetzen — das gibt dem Run Loop einen Durchlauf ohne feste Zeit-Annahme.

2. **Widget Force-Unwraps Scope**
   - Was wir wissen: Die Anforderung STAB-01 nennt "Networking-Code" mit explizitem Verweis auf `URL(string:)` und `URLComponents.url`.
   - Was unklar ist: Ob `calendar.date(byAdding:)!`-Stellen als Networking-Code gelten.
   - Empfehlung: Alle Force-Unwraps im Widget reparieren, da sie im selben Networking-File liegen. `calendar.date!` mit `?? now` absichern ist trivial und schadet nicht.

---

## Sources

### Primary (HIGH confidence)
- Direkte Code-Analyse der Quelldateien — alle Fundstellen manuell verifiziert
- Swift Language Reference: `guard let`, `throws`, `async/await` — fundamentale Sprachfeatures

### Secondary (MEDIUM confidence)
- Beobachtete Ausführungsreihenfolge im Code: AccountManager.init() → PlausibleSitesManager (lazy) → AuthManager

---

## Metadata

**Confidence breakdown:**
- Force-Unwrap-Inventar: HIGH — direkte Code-Analyse, alle Zeilen gezählt
- Fix-Pattern für URL/URLComponents: HIGH — Standardmuster in Swift
- asyncAfter-Entfernung: HIGH — @MainActor-Garantien klar
- Task.sleep-Entfernung: MEDIUM — Initialisierungsreihenfolge aus Code abgeleitet, nicht durch Laufzeit-Profiling verifiziert

**Research date:** 2026-03-27
**Valid until:** Stabil — keine zeitkritischen Dependencies
