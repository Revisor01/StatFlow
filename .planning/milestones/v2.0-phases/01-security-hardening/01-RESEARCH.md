# Phase 1: Security Hardening - Research

**Researched:** 2026-03-27
**Domain:** iOS Keychain, AES-GCM Encryption, UserDefaults Migration, Widget Security
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
None — Infrastructure phase, all implementation choices at Claude's discretion.

### Claude's Discretion
All implementation choices. Key technical context from CONTEXT.md:
- KeychainService already exists mit per-key storage via `kSecAttrAccount` — erweitern auf account-ID-scoped Keys (z.B. `token_<accountId>`)
- AccountManager speichert vollstaendige `AnalyticsAccount`-Objekte (inkl. `AccountCredentials` mit `token`/`apiKey`) in UserDefaults unter `analytics_accounts` — Credentials muessen aus UserDefaults entfernt und nur in Keychain gespeichert werden
- SharedCredentials implementiert bereits AES-GCM-Verschluesselung fuer `widget_credentials.encrypted` — dieses Muster fuer `widget_accounts.json` wiederverwenden
- Widget-Code in `InsightFlowWidget.swift:98` loggt `acc.token.prefix(10)` via `widgetLog` — vollstaendig entfernen
- Migration muss transparent sein: bestehende Accounts in UserDefaults muessen beim ersten Start nach dem Update in die Keychain migriert werden, ohne Re-Login des Nutzers

### Deferred Ideas (OUT OF SCOPE)
Keine.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SEC-01 | Credentials werden ausschliesslich in Keychain gespeichert (per Account-ID), nicht in UserDefaults | KeychainService-Extension mit account-scoped Keys; saveAccounts() muss AccountCredentials vor dem Speichern strippen |
| SEC-02 | Widget-Account-Tokens werden mit AES-GCM verschluesselt in App Group geschrieben | SharedCredentials-Encryption-Pattern auf syncAccountsToWidget() anwenden; WidgetAccountsStorage.loadAccounts() muss entschluesseln |
| SEC-03 | Auth-Token-Logging ist aus Widget-Code entfernt | Zeile 98 in InsightFlowWidget.swift: `token=\(acc.token.prefix(10))...` entfernen |
| SEC-04 | Migration bestehender UserDefaults-Credentials beim App-Update | migrateFromLegacyCredentials() ist definiert aber wird nie aufgerufen — muss beim App-Start getriggert werden |
</phase_requirements>

---

## Summary

Phase 1 bearbeitet vier eng verwandte Sicherheitsprobleme in einer iOS-App mit Widget-Extension. Der Code-Befund zeigt: Credentials (`token`, `apiKey`) sind aktuell zweifach gespeichert — einmal in der Keychain (fuer den aktiven Account) und einmal als JSON-Blob in UserDefaults (fuer alle Accounts im `analytics_accounts`-Key). Das Widget liest Accounts aus einer unverschluesselten `widget_accounts.json` im App Group Container und loggt Token-Praefix ins System-Log.

Die gute Nachricht: Alle benoetigten Bausteine existieren bereits. `KeychainService` bietet generische Keychain-Operationen. `SharedCredentials` implementiert AES-GCM-Verschluesselung mit persistiertem Schluesseldatei-Pattern. `migrateFromLegacyCredentials()` ist sogar schon implementiert — sie wird jedoch nirgendwo aufgerufen. Das ist der kritischste Befund fuer SEC-04.

Die Implementierung folgt einem klaren Muster: (1) KeychainService um account-ID-scoped Speicherung erweitern, (2) AccountManager so aendern, dass `saveAccounts()` keine Credentials mehr serialisiert, (3) `syncAccountsToWidget()` verschluesselt schreiben, (4) Widget liest und entschluesselt, (5) Token-Log-Zeile entfernen, (6) Migration beim App-Start aufrufen.

**Primary recommendation:** Credentials-Stripping in `saveAccounts()` ist der Kern — alles andere baut darauf auf. Zuerst die Keychain-Scoping-Erweiterung, dann Stripping, dann Widget-Verschluesselung, dann Migration verdrahten.

---

## Standard Stack

### Core (bereits vorhanden, kein npm install noetig)

| Komponente | Version | Zweck | Bemerkung |
|------------|---------|-------|-----------|
| Security.framework | iOS-Standard | Keychain-Operationen (`SecItem*`) | Bereits importiert in KeychainService.swift |
| CryptoKit | iOS 13+ | AES-GCM Verschluesselung | Bereits in SharedCredentials + Widget genutzt |
| Foundation | iOS-Standard | UserDefaults, JSON-Coding | Bereits durchgaengig genutzt |

### Keine neuen Abhaengigkeiten erforderlich

Das Projekt hat sich bewusst gegen externe Dependencies entschieden (REQUIREMENTS.md: "Externe Dependencies einführen — Out of Scope"). Alle benoetigen Kryptographie-Primitiven sind ueber CryptoKit verfuegbar.

---

## Architecture Patterns

### Pattern 1: Account-ID-Scoped Keychain Keys

**Was:** Statt globaler Keys (`token`, `apiKey`) werden Keys pro Account-ID generiert: `token_<uuid>`, `apiKey_<uuid>`.

**Wann:** Immer wenn Credentials eines Accounts gespeichert, geladen oder geloescht werden.

**Bestehendes Problem:** `KeychainService.Key` ist ein `enum` mit fixen Faellen. Fuer account-scoped Keys brauchen wir dynamische Strings als `kSecAttrAccount`.

**Empfehlung:** Neue statische Methoden neben den bestehenden, die einen `accountId: String`-Parameter nehmen und den Key dynamisch als String bilden. Kein Breaking Change am bestehenden `Key`-Enum.

```swift
// Neues Pattern — account-scoped Keychain-Zugriff
extension KeychainService {
    static func saveCredential(_ value: String, type: CredentialType, accountId: String) throws {
        let accountKey = "\(type.rawValue)_\(accountId)"
        // ... identische SecItem-Logik wie bestehende save()
    }

    static func loadCredential(type: CredentialType, accountId: String) -> String? {
        let accountKey = "\(type.rawValue)_\(accountId)"
        // ... identische SecItem-Logik wie bestehende load()
    }

    static func deleteCredentials(for accountId: String) {
        for type in CredentialType.allCases {
            let accountKey = "\(type.rawValue)_\(accountId)"
            // ... delete
        }
    }

    enum CredentialType: String, CaseIterable {
        case token = "token"
        case apiKey = "apiKey"
    }
}
```

**Accessibility:** `kSecAttrAccessibleAfterFirstUnlock` beibehalten — ermoeglicht Widget-Zugriff nach erstem Unlock, auch wenn App noch nicht geoeffnet wurde. Widgets laufen im App-Prozess-Kontext der Extension, nicht der App selbst — daher ist Widget-Keychain-Zugriff nur moeglich wenn Keychain Sharing aktiviert ist (App Group Keychain). Achtung: Aktuell nutzt `syncAccountsToWidget()` eine Datei-basierte Loesung, nicht Keychain direkt — das beibehalten, aber die Datei verschluesseln (SEC-02).

### Pattern 2: Credentials-Stripping in UserDefaults

**Was:** `AnalyticsAccount` in UserDefaults serialisieren, aber `AccountCredentials` durch leeres Stub-Objekt ersetzen.

**Wann:** In `saveAccounts()` in AccountManager.

```swift
// Credentials-freie Kopie fuer UserDefaults
private func accountWithoutCredentials(_ account: AnalyticsAccount) -> AnalyticsAccount {
    AnalyticsAccount(
        id: account.id,
        name: account.name,
        serverURL: account.serverURL,
        providerType: account.providerType,
        credentials: AccountCredentials(token: nil, apiKey: nil), // leer
        sites: account.sites
    )
}

private func saveAccounts() {
    let stripped = accounts.map { accountWithoutCredentials($0) }
    if let encoded = try? JSONEncoder().encode(stripped) {
        UserDefaults.standard.set(encoded, forKey: accountsKey)
    }
}
```

**Beim Laden:** `loadAccounts()` laedt Accounts aus UserDefaults (ohne Credentials) und hydratisiert sie sofort aus der Keychain:

```swift
private func loadAccounts() {
    if let data = UserDefaults.standard.data(forKey: accountsKey),
       let decoded = try? JSONDecoder().decode([AnalyticsAccount].self, from: data) {
        // Credentials aus Keychain nachladen
        accounts = decoded.map { hydrateWithKeychainCredentials($0) }
    }
    // ... active account logic unveraendert
}

private func hydrateWithKeychainCredentials(_ account: AnalyticsAccount) -> AnalyticsAccount {
    let token = KeychainService.loadCredential(type: .token, accountId: account.id.uuidString)
    let apiKey = KeychainService.loadCredential(type: .apiKey, accountId: account.id.uuidString)
    return AnalyticsAccount(
        id: account.id,
        name: account.name,
        serverURL: account.serverURL,
        providerType: account.providerType,
        credentials: AccountCredentials(token: token, apiKey: apiKey),
        sites: account.sites
    )
}
```

### Pattern 3: Verschluesselte widget_accounts.json

**Was:** `syncAccountsToWidget()` schreibt aktuell Plaintext-JSON. Umstellen auf AES-GCM identisch zu SharedCredentials.

**Problem:** Der Encryption-Key liegt in `widget_credentials.key` im App Group Container. Dieser Schluesseldatei-Ansatz kann fuer `widget_accounts.json` wiederverwendet werden — entweder denselben Schluessel verwenden oder einen separaten Schluessel `widget_accounts.key` einfuehren.

**Empfehlung:** Denselben Schluessel (`widget_credentials.key`) fuer beide Dateien verwenden. Das vereinfacht das Widget: ein Schluessel, ein Decrypt-Aufruf. SharedCredentials besitzt bereits die Key-Lade/Generier-Logik.

**Implementierung:** `syncAccountsToWidget()` delegiert an einen neuen `WidgetAccountsEncryptedStorage`-Helfer oder erweitert `SharedCredentials` um eine `saveAccounts([WidgetAccount])` Methode. Die einfachere Option: SharedCredentials um eine Multi-Account-Methode erweitern.

```swift
// In SharedCredentials erweitern
static func saveAccounts(_ accounts: [WidgetAccount]) -> Bool {
    guard let url = containerURL?.appendingPathComponent("widget_accounts.json.enc") else { return false }
    do {
        let data = try JSONEncoder().encode(accounts)
        let encrypted = try encrypt(data)
        try encrypted.write(to: url, options: [.atomic, .completeFileProtection])
        return true
    } catch { return false }
}

static func loadAccounts() -> [WidgetAccount]? {
    guard let url = containerURL?.appendingPathComponent("widget_accounts.json.enc"),
          FileManager.default.fileExists(atPath: url.path),
          let encrypted = try? Data(contentsOf: url),
          let data = try? decrypt(encrypted) else { return nil }
    return try? JSONDecoder().decode([WidgetAccount].self, from: data)
}
```

**Widget-Seite:** `WidgetAccountsStorage.loadAccounts()` muss um Entschluesselung erweitert werden. Da das Widget kein SharedCredentials importiert (anderes Target), muss die Decrypt-Logik im Widget selbst oder in einem Shared-File sein. Aktuell ist die Decrypt-Logik in `WidgetCredentials` bereits vorhanden — sie kann fuer `widget_accounts` wiederverwendet werden.

**Dateinamen-Strategie:** Die aktuelle Plaintext-Datei heisst `widget_accounts.json`. Optionen:
1. Dieselbe URL, anderes Format (rueckwaerts-inkompatibel, kein graceful fallback)
2. Neue verschluesselte Datei + Legacy-Fallback (wie bei widget_credentials)

**Empfehlung:** Option 2 — neue Datei `widget_accounts.encrypted`, Legacy-Fallback auf alte `.json` mit einmaliger Migration (Datei loeschen nach erstem Lesen). Identisches Muster wie SharedCredentials' `loadLegacyCredentials()`.

### Pattern 4: Migration beim App-Start (SEC-04)

**Kritischer Befund:** `migrateFromLegacyCredentials()` ist in AccountManager definiert (Zeile 305) aber wird **nirgendwo** aufgerufen. Sie migriert nur den Keychain-zu-multi-Account-Fall (wenn Accounts leer sind), behandelt aber NICHT den Fall, bei dem bestehende Accounts in UserDefaults bereits `AccountCredentials` mit Tokens enthalten.

**Was die Migration leisten muss:**
1. Bestehende `analytics_accounts` aus UserDefaults laden (noch mit eingebetteten Credentials)
2. Credentials jedes Accounts in die Keychain schreiben (account-ID-scoped)
3. Accounts-JSON ohne Credentials zurueck in UserDefaults schreiben
4. Migration-Flag setzen (damit sie nur einmal laeuft)

**Wo aufrufen:** `AccountManager.init()` vor `loadAccounts()`, oder als separate Methode die aus `InsightFlowApp.init()` aufgerufen wird. Da `AccountManager.shared` ein Singleton ist, eignet sich der `init()`.

```swift
// Migration-Flag
private let migrationV2Key = "credentials_migrated_v2"

private init() {
    if !UserDefaults.standard.bool(forKey: migrationV2Key) {
        migrateCredentialsToKeychain()
    }
    loadAccounts()
}

private func migrateCredentialsToKeychain() {
    // Lese bestehende Accounts (noch mit Credentials in UserDefaults)
    guard let data = UserDefaults.standard.data(forKey: accountsKey),
          let existingAccounts = try? JSONDecoder().decode([AnalyticsAccount].self, from: data) else {
        // Kein UserDefaults-Eintrag: entweder Neuinstallation oder schon migriert
        UserDefaults.standard.set(true, forKey: migrationV2Key)
        return
    }

    // Credentials in Keychain schreiben
    for account in existingAccounts {
        if let token = account.credentials.token {
            try? KeychainService.saveCredential(token, type: .token, accountId: account.id.uuidString)
        }
        if let apiKey = account.credentials.apiKey {
            try? KeychainService.saveCredential(apiKey, type: .apiKey, accountId: account.id.uuidString)
        }
    }

    // Migration-Flag setzen (saveAccounts() wird danach stripped schreiben)
    UserDefaults.standard.set(true, forKey: migrationV2Key)
}
```

**Reihenfolge in `init()`:** Migration VOR `loadAccounts()` — so werden beim ersten Start Credentials in Keychain geschrieben, und `loadAccounts()` hydratisiert dann korrekt aus der Keychain.

### Anti-Patterns zu vermeiden

- **Keychain Sharing ohne App Group aktiviert:** Der Widget-Zugriff auf Keychain erfordert eine Keychain Access Group. Aktuell nutzt der Code kein `kSecAttrAccessGroup` — wenn Keychain Sharing in Xcode aktiviert ist, funktioniert das automatisch. Nicht aendern.
- **Credentials im Widget direkt aus Keychain lesen:** Widgets haben eingeschraenkten Keychain-Zugriff. Der bestehende Datei-basierte Ansatz (App Group Container) ist der korrekte Weg fuer App-zu-Widget-Credential-Sharing.
- **Token-Logging hinter `#if DEBUG` verstecken statt entfernen:** SEC-03 verlangt vollstaendige Entfernung, nicht nur Abschwaechen. Das Widget-Log `acc.token.prefix(10)` muss geloescht werden (nicht kommentiert, nicht in DEBUG gewrappt).

---

## Don't Hand-Roll

| Problem | Nicht selbst bauen | Stattdessen nutzen | Warum |
|---------|-------------------|-------------------|-------|
| AES-GCM Verschluesselung | Eigene Cipher-Implementierung | `CryptoKit.AES.GCM` | Bereits im Codebase, NIST-zertifiziert |
| Schluessel-Generierung | Random bytes manuell | `SymmetricKey(size: .bits256)` | Kryptographisch sicherer RNG |
| Keychain-Zugriff | Direkte `SecItem`-Calls ueberall | `KeychainService` (erweitert) | Zentralisiert, getestet |
| JSON ohne Credentials | Custom Encoder | `accountWithoutCredentials()` + Standard-Encoder | Einfacher, weniger fehleranfaellig |

---

## Runtime State Inventory

| Kategorie | Gefundene Items | Erforderliche Aktion |
|-----------|----------------|----------------------|
| Gespeicherte Daten | `analytics_accounts` in UserDefaults: JSON-Array von `AnalyticsAccount` inkl. `AccountCredentials` (token/apiKey) | Data Migration: Credentials aus UserDefaults-JSON in Keychain verschieben; Migrationslogik in AccountManager.init() |
| Gespeicherte Daten | `widget_accounts.json` im App Group Container: Plaintext-JSON mit Token-Feldern | Data Migration: Datei ersetzen durch `widget_accounts.encrypted`; Legacy-Datei nach erstem Lesen loeschen |
| Gespeicherte Daten | `active_account_id` in UserDefaults: UUID-String ohne Credentials | Keine Aktion — kein Sicherheitsrisiko |
| Gespeicherte Daten | `widget_credentials.encrypted` + `widget_credentials.key` im App Group Container | Keine Aktion — bereits verschluesselt, unveraendert |
| Live-Service-Config | Keine externen Dienste mit eingebetteten Credentials | Keine Aktion |
| OS-Registrierungen | Background Task `de.godsapp.PrivacyFlow.refresh` | Keine Aktion — kein Credential-Bezug |
| Secrets/Env Vars | Keine `.env`-Dateien oder CI-Secrets fuer App-Credentials | Keine Aktion |
| Build-Artefakte | Xcode DerivedData — wird bei Build neu generiert | Keine Aktion |

---

## Common Pitfalls

### Pitfall 1: Migration laeuft auf Neuinstallationen ins Leere
**Was schieflaeuft:** `migrateCredentialsToKeychain()` wird bei Neuinstallation aufgerufen, findet nichts in UserDefaults, setzt aber das Flag. Kein Problem — aber muss beruecksichtigt werden, dass die Migration korrekt "Kein Eintrag vorhanden" von "Eintrag vorhanden aber leer" unterscheidet.
**Ursache:** `guard accounts.isEmpty else { return }` in der bestehenden `migrateFromLegacyCredentials()` — diese Logik ist falsch fuer den neuen Fall (Accounts existieren, aber Credentials sollen migriert werden).
**Vermeidung:** Migrations-Check auf `migrationV2Key`-Flag basieren, nicht auf `accounts.isEmpty`.

### Pitfall 2: Widget-Entschluesselung schlaegt fehl wenn Schluessel fehlt
**Was schieflaeuft:** `widget_accounts.encrypted` existiert, aber `widget_credentials.key` wurde nie generiert (z.B. nach Re-Install). Widget bekommt leere Account-Liste.
**Ursache:** Key-Generierung findet nur in der App statt (SharedCredentials.encryptionKey), nicht im Widget.
**Vermeidung:** Widget-seitig graceful fallback: wenn Entschluesselung fehlschlaegt, auf Legacy `widget_accounts.json` zurueckfallen (falls noch vorhanden). Nach ersten erfolgreichen Sync von der App ist der Key immer vorhanden.

### Pitfall 3: addAccount() schreibt Credentials nicht in Keychain
**Was schieflaeuft:** `addAccount()` ruft `saveAccounts()` auf. Nach dem Stripping werden Credentials in UserDefaults nicht mehr gespeichert — aber wenn vor dem Speichern kein `KeychainService.saveCredential()` aufgerufen wird, gehen Credentials verloren.
**Ursache:** `addAccount()` hat keinen expliziten Keychain-Write-Schritt (nur `applyAccountCredentials()` bei `setActiveAccount()` schreibt in Keychain, und das nur fuer den aktiven Account).
**Vermeidung:** In `addAccount()` explizit Credentials aller Accounts in Keychain schreiben, nicht nur den aktiven. Alternative: `saveAccounts()` hydratisiert implizit — aber die Keychain-Writes muessen vor dem ersten `loadAccounts()`-Aufruf nach Stripped-Saving erfolgen.

### Pitfall 4: AnalyticsAccount.init() erstellt immer neue createdAt
**Was schieflaeuft:** `accountWithoutCredentials()` muss alle Felder 1:1 kopieren, inkl. `createdAt`. Wenn `AnalyticsAccount.init()` `createdAt = Date()` setzt, aendert sich der Zeitstempel bei jedem Save.
**Ursache:** Aktueller Init in AccountManager.swift:22: `self.createdAt = Date()`.
**Vermeidung:** Einen `init()` mit explizitem `createdAt`-Parameter nutzen oder `AnalyticsAccount` als `struct` mit mutierbaren Feldern direkt kopieren (struct copy + credential-replace).

### Pitfall 5: Token-Log-Entfernung muss vollstaendig sein
**Was schieflaeuft:** Es gibt genau eine Log-Zeile in InsightFlowWidget.swift:98. Wird sie entfernt, kann sich der umgebende Loop anders verhalten wenn weitere Log-Calls folgen.
**Ursache:** `widgetLog("  - \(acc.name): provider=\(acc.providerType), sites=\(acc.sites ?? []), token=\(acc.token.prefix(10))...")` — dieser gesamte String muss angepasst werden, nicht nur der Token-Teil.
**Vermeidung:** Den Log-String behalten aber Token-Teil entfernen: `widgetLog("  - \(acc.name): provider=\(acc.providerType), sites=\(acc.sites ?? [])")` — kein Token, kein Praefix.

---

## Code Examples

### Bestehende KeychainService.save() (Referenz)
```swift
// Source: InsightFlow/Services/KeychainService.swift
static func save(_ value: String, for key: Key) throws {
    let data = value.data(using: .utf8)!
    let deleteQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: key.rawValue
    ]
    SecItemDelete(deleteQuery as CFDictionary)
    let attributes: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: key.rawValue,
        kSecValueData as String: data,
        kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
    ]
    let status = SecItemAdd(attributes as CFDictionary, nil)
    guard status == errSecSuccess else {
        throw KeychainError.saveFailed(status)
    }
}
```

### Bestehende AES-GCM Encrypt/Decrypt in SharedCredentials (Referenz)
```swift
// Source: InsightFlow/Services/SharedCredentials.swift
private static func encrypt(_ data: Data) throws -> Data {
    let sealedBox = try AES.GCM.seal(data, using: encryptionKey)
    guard let combined = sealedBox.combined else {
        throw EncryptionError.encryptionFailed
    }
    return combined
}

private static func decrypt(_ data: Data) throws -> Data {
    let sealedBox = try AES.GCM.SealedBox(combined: data)
    return try AES.GCM.open(sealedBox, using: encryptionKey)
}
```

### Bestehende syncAccountsToWidget() — Ziel der Verschluesselung
```swift
// Source: InsightFlow/Services/AccountManager.swift:259
// Aktuell: Plaintext-JSON
let data = try JSONEncoder().encode(widgetAccounts)
try data.write(to: fileURL) // <- hier muss Verschluesselung rein
```

### Token-Logging im Widget — zu entfernen
```swift
// Source: InsightFlowWidget/InsightFlowWidget.swift:98
// ENTFERNEN:
widgetLog("  - \(acc.name): provider=\(acc.providerType), sites=\(acc.sites ?? []), token=\(acc.token.prefix(10))...")
// ERSETZEN MIT:
widgetLog("  - \(acc.name): provider=\(acc.providerType), sites=\(acc.sites ?? [])")
```

---

## State of the Art

| Alter Ansatz | Aktueller Ansatz | Relevant fuer Phase |
|--------------|-----------------|---------------------|
| Plaintext JSON in App Group | AES-GCM verschluesselt (widget_credentials) | SEC-02: widget_accounts muss gleich behandelt werden |
| Globale Keychain-Keys (token, apiKey) | Account-ID-scoped Keys (token_uuid) | SEC-01: neues Pattern implementieren |
| Credentials in UserDefaults | Credentials nur in Keychain | SEC-01 + SEC-04 |
| Kein Migration-Trigger | `migrateFromLegacyCredentials()` definiert aber nie aufgerufen | SEC-04: verdrahten |

---

## Open Questions

1. **Schluessel-Sharing zwischen widget_credentials und widget_accounts**
   - Was wir wissen: SharedCredentials generiert einen SymmetricKey und speichert ihn als `widget_credentials.key`
   - Was unklar ist: Soll `widget_accounts.encrypted` denselben Schluessel verwenden oder einen separaten?
   - Empfehlung: Denselben Schluessel — einfacher fuer Widget-Seite (ein Lade-Aufruf), kein Sicherheitsnachteil bei identischer Access Control

2. **AnalyticsAccount.createdAt bei Stripping**
   - Was wir wissen: `init()` setzt `createdAt = Date()` immer auf jetzt
   - Was unklar ist: Gibt es einen Init-Pfad der `createdAt` als Parameter akzeptiert?
   - Empfehlung: Struct-Copy-Pattern nutzen: `var copy = account; copy.credentials = AccountCredentials(token: nil, apiKey: nil)` — aber `AnalyticsAccount` ist ein `struct` mit `let` properties, also braucht es entweder einen vollstaendigen Init mit `createdAt`-Parameter oder eine separate `stripped()`-Methode auf dem Struct

3. **Widget liest Keychain direkt oder nur Datei?**
   - Was wir wissen: Widget nutzt `WidgetAccountsStorage.loadAccounts()` aus Datei, nicht Keychain
   - Was unklar ist: Kein Handlungsbedarf fuer SEC-02 — Datei-basierter Ansatz bleibt, wird nur verschluesselt
   - Empfehlung: Datei-Ansatz beibehalten, Keychain-Zugriff aus Widget heraushalten

---

## Environment Availability

Step 2.6: Keine externen Tool-Abhaengigkeiten fuer diese Phase. Alle Aenderungen sind reine Swift-Code-Aenderungen ohne neue CLI-Tools, Datenbanken oder externe Services.

| Abhaengigkeit | Benoetigt von | Verfuegbar | Version | Fallback |
|--------------|--------------|-----------|---------|---------|
| Xcode | Build + Test | Angenommen ja | macOS-Projekt | — |
| CryptoKit | AES-GCM Verschluesselung | iOS 13+ / macOS 10.15+ | In-SDK | — |
| Security.framework | Keychain | Alle iOS-Versionen | In-SDK | — |

---

## Validation Architecture

Kein Test-Verzeichnis im Projekt vorhanden. TEST-01 ist erst Phase 5. Die Phase muss **manuell** verifiziert werden — kein automatisiertes Test-Framework verfuegbar.

### Phase Requirements -> Test Map

| Req ID | Verhalten | Test-Typ | Verifikationsmethode | Test-Datei |
|--------|-----------|---------|----------------------|------------|
| SEC-01 | Neuer Account schreibt keine Credentials in UserDefaults | Manuell | Nach Login: `UserDefaults.standard.data(forKey: "analytics_accounts")` decodieren und pruefen dass token/apiKey nil sind | Wave 0 fehlt |
| SEC-01 | Credentials per Account-ID in Keychain gespeichert | Manuell | Keychain-Eintrag `token_<uuid>` via Xcode Debugger oder SecItem-Query pruefen | Wave 0 fehlt |
| SEC-02 | widget_accounts.encrypted existiert nach Account-Sync | Manuell | App Group Container-Datei pruefen — kein lesbares JSON | Wave 0 fehlt |
| SEC-03 | Console.app zeigt keine Token-Praefix-Logs | Manuell | Widget triggern, Console.app filtern nach "[Widget]" | — |
| SEC-04 | Update-Migration: kein Re-Login erforderlich | Manuell | Vorhandene Installation simulieren (UserDefaults mit Credentials praeparieren), App neu starten, Account prufen | Wave 0 fehlt |

### Sampling Rate
- **Pro Task-Commit:** Manueller Build + Simulation des betroffenen Flows
- **Pro Wave:** Vollstaendiger manueller Test aller 5 Success Criteria aus Phase-Beschreibung
- **Phase Gate:** Alle 5 Success Criteria manuell bestaetig vor `/gsd:verify-work`

### Wave 0 Gaps
Da kein Test-Framework existiert (TEST-01 ist Phase 5), sind keine automatisierten Test-Dateien erstellbar. Manuelle Verifikations-Checkliste wird in PLAN.md definiert.

---

## Sources

### Primary (HIGH confidence)
- Direkter Code-Befund: `InsightFlow/Services/KeychainService.swift` — vollstaendige Implementierung gelesen
- Direkter Code-Befund: `InsightFlow/Services/SharedCredentials.swift` — AES-GCM Pattern verifiziert
- Direkter Code-Befund: `InsightFlow/Services/AccountManager.swift` — saveAccounts(), loadAccounts(), syncAccountsToWidget() vollstaendig analysiert
- Direkter Code-Befund: `InsightFlowWidget/InsightFlowWidget.swift:98` — Token-Log-Zeile verifiziert
- Direkter Code-Befund: `InsightFlow/Services/AccountManager.swift:305` — migrateFromLegacyCredentials() definiert aber nicht aufgerufen (Grep-Verifikation)
- Direkter Code-Befund: `InsightFlow/App/InsightFlowApp.swift` — kein Migrations-Aufruf in App-Start-Sequenz

### Secondary (MEDIUM confidence)
- Apple CryptoKit-Dokumentation (aus Trainingsdaten): AES.GCM.seal/open API — durch bestehenden Code im Projekt verifiziert
- Apple Security-Framework (aus Trainingsdaten): SecItem* API mit kSecAttrAccessibleAfterFirstUnlock — durch bestehenden Code im Projekt verifiziert

---

## Metadata

**Confidence Breakdown:**
- Standard Stack: HIGH — alle Komponenten direkt im Code verifiziert
- Architecture Patterns: HIGH — basiert auf bestehendem Code, nicht auf externen Quellen
- Pitfalls: HIGH — direkt aus Code-Analyse abgeleitet
- Migration-Befund (migrateFromLegacyCredentials nicht aufgerufen): HIGH — durch Grep verifiziert

**Research date:** 2026-03-27
**Valid until:** 2026-04-27 (stabiler iOS-Stack)

## Project Constraints (from CLAUDE.md)

Kein `CLAUDE.md` im Projektverzeichnis gefunden. Es gelten keine projektspezifischen Override-Direktiven ausser den globalen User-Instruktionen:
- Keine Dokumentationsdateien erstellen ausser wenn explizit angefordert
- Keine neuen externen Dependencies einführen (aus REQUIREMENTS.md: Out of Scope)
- Keine UI-Aenderungen (Phase ist reine Sicherheits-/Infrastruktur-Arbeit)
