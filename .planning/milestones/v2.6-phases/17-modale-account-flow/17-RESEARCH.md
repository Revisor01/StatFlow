# Phase 17: Modale & Account-Flow - Research

**Researched:** 2026-04-03
**Domain:** SwiftUI — UI-Fixes in Account-Flow und Modale
**Confidence:** HIGH

## Summary

Phase 17 behebt vier konkrete UI-Lücken im Account-hinzufügen-Flow und in den Admin-Modalen. Die Probleme sind durch direkten Codebase-Scan vollständig lokalisiert und verstanden. Alle vier Requirements sind reine SwiftUI-View-Änderungen ohne Model- oder API-Berührung.

**ACCT-01** betrifft einen inhaltlich fehlenden Onboarding-Schritt: Die `OnboardingView` ist eine reine Feature-Tour (5 statische Seiten), hat aber keinen Account-Setup-Schritt. Der `LoginView`-Flow (der direkt nach dem Onboarding kommt) bietet Cloud vs. Self-Hosted über `ServerType`-Enum und `ServerTypeButton`-Komponenten an. Die Anforderung "fehlender Self-Hosted-String" bezieht sich wahrscheinlich auf den `credentialsSection`-Badge in `LoginView.swift` Zeile 242: `Text(serverType == .cloud ? selectedProvider.cloudURL : "login.selfhosted.title")` — hier wird der String-Key direkt als Text ausgegeben statt `String(localized:)` zu verwenden. Das ist der Bug.

**ACCT-02** betrifft `AddAccountView` (in `DashboardView.swift` ab Zeile 497): Diese View bietet nur Provider-Auswahl (Umami vs. Plausible) und eine direkte URL-Eingabe. Es gibt keinen Cloud vs. Self-Hosted Selektor — im Gegensatz zu `LoginView`, die `ServerTypeButton`-Komponenten für diese Auswahl hat. Die Fix-Logik ist: einen `serverType`-State und die `ServerTypeButton`-Komponenten integrieren, analog zur `LoginView`.

**ACCT-03** betrifft denselben `AddAccountView`: Es gibt kein `.toolbar` in der View — kein Cancel/X-Button. Die View wird als Sheet mit `NavigationStack` gezeigt, hat aber nur `.navigationTitle` ohne Toolbar-Definition. Ein `ToolbarItem(placement: .cancellationAction)` mit `Button { dismiss() }` fehlt.

**MODAL-01** betrifft alle `AdminSheets.swift`-Strukturen: `CreateWebsiteSheet`, `CreateTeamSheet`, `CreateUserSheet`, `EditWebsiteSheet`, `TeamMemberSheet`, `ShareLinkSheet`, `TrackingCodeSheet`, `PlausibleTrackingCodeSheet`. Alle verwenden Text-Labels ("button.cancel", "button.create", "button.save", "button.done"). Diese müssen auf `Image(systemName:)` umgestellt werden: `xmark` für Cancel/Dismiss, `checkmark` für Confirm/Done.

**Primary recommendation:** Alle vier Fixes sind isoliert und unabhängig voneinander. Reihenfolge: ACCT-01 (kleinster Fix), ACCT-03 (ebenfalls minimal), ACCT-02 (mittel — Copy-Pattern aus LoginView), MODAL-01 (breitester Change — 8 Sheets betroffen).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
Keine gesperrten Entscheidungen — alle Implementation-Choices liegen im Ermessen von Claude.

### Claude's Discretion
All implementation choices are at Claude's discretion — UI fix phase. Use ROADMAP success criteria and codebase conventions to guide decisions.

### Deferred Ideas (OUT OF SCOPE)
None.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ACCT-01 | Fehlender String bei "Self-Hosted" im Onboarding-Flow ergänzen | Bug lokalisiert: `LoginView.swift` Zeile 242 — `"login.selfhosted.title"` wird ohne `String(localized:)` als roher Key ausgegeben |
| ACCT-02 | Account-hinzufügen-Flow braucht Auswahl "Self-Hosted" vs "Offiziell" außerhalb Onboarding | `AddAccountView` (DashboardView.swift:497) fehlt `serverType` State + `ServerTypeButton`-Komponenten; Vorlage liegt in `LoginView.swift` |
| ACCT-03 | Account-hinzufügen-Modal braucht einen X/Schließen-Button | `AddAccountView` hat kein `.toolbar` — `ToolbarItem(placement: .cancellationAction)` mit Dismiss-Button fehlt |
| MODAL-01 | Toolbar-Buttons in Modalen (Website, Teams, Benutzer, Webseite) sollen nur Icons sein | 8 Sheets in `AdminSheets.swift` verwenden Text-Buttons; alle auf `Image(systemName:)` umstellen |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ (bereits im Projekt) | Deklarative UI | Gesamtes Projekt in SwiftUI |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Keine externe Library nötig | — | Alle Fixes sind reine SwiftUI-Sprachkonstrukte | — |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `Image(systemName: "xmark")` in Toolbar | Text-Label "Abbrechen" | Icons sind kompakter, entsprechen iOS-Konventionen für modale Sheets |

**Installation:** Keine — keine neuen Abhängigkeiten.

## Architecture Patterns

### Bestehendes Muster: Toolbar-Icons in SwiftUI
```swift
.toolbar {
    ToolbarItem(placement: .cancellationAction) {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
        }
    }
    ToolbarItem(placement: .confirmationAction) {
        Button { /* confirm */ } label: {
            Image(systemName: "checkmark")
        }
        .disabled(/* validation */)
    }
}
```

### Bestehendes Muster: ServerType-Selektor in AddAccountView
Die `LoginView.swift` enthält bereits alle benötigten Komponenten:
- `ServerType` enum (Zeile 54–78): `.cloud` und `.selfHosted` mit `displayName`, `icon`, `description`
- `ServerTypeButton` Komponente (Zeile 451–495): vollständige SwiftUI-Komponente
- `providerSelectionSection` in `LoginView` (Zeile 182–208): zeigt wie Server-Typ integriert wird

`AddAccountView` muss dieselben Muster übernehmen:
1. `@State private var serverType: ServerType = .cloud` hinzufügen
2. `ServerTypeButton`-Sektion in den ScrollView-VStack einfügen
3. URL-Feld nur für `.selfHosted` anzeigen (analog LoginView Zeile 253)
4. `isFormValid` anpassen: `serverType == .cloud || !serverURL.isEmpty`

### Bestehendes Muster: Localized String korrekt verwenden
Bug in LoginView Zeile 242:
```swift
// BUG: String-Key wird direkt ausgegeben
Text(serverType == .cloud ? selectedProvider.cloudURL : "login.selfhosted.title")

// FIX: Mit String(localized:)
Text(serverType == .cloud ? selectedProvider.cloudURL : String(localized: "login.selfhosted.title"))
```

### Anti-Patterns to Avoid
- **Neue Komponenten erstellen:** `ServerTypeButton` existiert bereits in `LoginView.swift` — nicht duplizieren, stattdessen in gemeinsame Datei extrahieren oder in-place wiederverwenden
- **NavigationStack in Sheet doppelt verschachteln:** `AddAccountView` wird bereits in `NavigationStack` eingebettet präsentiert (SettingsView.swift Zeile 53) — kein weiterer `NavigationStack` in der View selbst nötig

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Server-Typ-Auswahl | Eigene neue Picker-Komponente | `ServerTypeButton` (LoginView.swift:451) | Identische Komponente bereits vorhanden |
| Cancel-Button in Sheet | Eigene Dismiss-Logic | `@Environment(\.dismiss)` + Toolbar ToolbarItem | Standard SwiftUI-Pattern, bereits im Projekt verwendet |

## Datei-Übersicht: Was wo geändert wird

| Requirement | Datei | Zeilen-Bereich | Art der Änderung |
|-------------|-------|----------------|------------------|
| ACCT-01 | `InsightFlow/Views/Auth/LoginView.swift` | ~242 | `"login.selfhosted.title"` → `String(localized: "login.selfhosted.title")` |
| ACCT-02 | `InsightFlow/Views/Dashboard/DashboardView.swift` | 497–701 | `serverType` State hinzufügen, `ServerTypeButton`-Sektion, URL-Logik anpassen |
| ACCT-03 | `InsightFlow/Views/Dashboard/DashboardView.swift` | 638–640 | `.toolbar` mit `ToolbarItem(placement: .cancellationAction)` hinzufügen |
| MODAL-01 | `InsightFlow/Views/Admin/AdminSheets.swift` | alle toolbar-Stellen | Text-Labels durch `Image(systemName:)` ersetzen |

## Common Pitfalls

### Pitfall 1: ServerTypeButton vs. ProviderSelectionButton
**What goes wrong:** `AddAccountView` hat eine ähnliche Auswahl-Komponente `ProviderSelectionButton` (DashboardView.swift:705) — beim Kopieren des `ServerType`-Patterns könnte man versehentlich die falsche Komponente referenzieren.
**Why it happens:** Beide sind ähnlich aufgebaut; `ProviderSelectionButton` wählt Provider (Umami/Plausible), `ServerTypeButton` wählt Cloud/Self-Hosted.
**How to avoid:** Klar trennen: Provider-Auswahl bleibt `ProviderSelectionButton`, Server-Typ-Auswahl verwendet `ServerTypeButton`.

### Pitfall 2: Cloud-URL für Self-Hosted nicht voreinstellen
**What goes wrong:** In `LoginView` setzt ein Tap auf Cloud automatisch die `serverURL` auf `selectedProvider.cloudURL`, ein Tap auf Self-Hosted setzt sie auf `""`.
**Why it happens:** `AddAccountView` hat keine Provider-abhängige cloudURL-Logik.
**How to avoid:** Bei Integration von `serverType` in `AddAccountView` dieselbe Logik übernehmen: bei `.cloud` die URL automatisch befüllen (für Umami: `"https://cloud.umami.is"`, für Plausible: `"https://plausible.io"`), bei `.selfHosted` leeren.

### Pitfall 3: Sheet-Presentation mit und ohne eigenen NavigationStack
**What goes wrong:** `AddAccountView` wird in SettingsView bereits in `NavigationStack` eingebettet. Wenn die View selbst auch einen `NavigationStack` hätte, entsteht Doppel-Navigation.
**Why it happens:** AdminSheets verwenden eigene `NavigationStack` (sie werden direkt als Sheet ohne externen NavStack präsentiert). `AddAccountView` nicht.
**How to avoid:** Für das Toolbar-Item in `AddAccountView` keinen zusätzlichen `NavigationStack` einbauen — der externe reicht.

### Pitfall 4: MODAL-01 — Zwei Sheet-Gruppen haben unterschiedliche Toolbar-Semantik
**What goes wrong:** Sheets mit Cancel+Confirm brauchen zwei Icons, Sheets mit nur Done brauchen nur ein Icon.
**How to avoid:**
- Cancel+Confirm Sheets: `xmark` (cancellationAction) + `checkmark` (confirmationAction)
- Done-only Sheets: `checkmark` (confirmationAction) — kein `xmark` nötig, da kein destruktiver Abbruch

## Code Examples

### ACCT-01: Lokalisierter String (Fix)
```swift
// Source: LoginView.swift:242 — Bug
Text(serverType == .cloud ? selectedProvider.cloudURL : "login.selfhosted.title")

// Fix
Text(serverType == .cloud ? selectedProvider.cloudURL : String(localized: "login.selfhosted.title"))
```

### ACCT-03: Cancel-Button in AddAccountView
```swift
// Hinzufügen in AddAccountView.body nach .navigationBarTitleDisplayMode(.inline)
.toolbar {
    ToolbarItem(placement: .cancellationAction) {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
        }
    }
}
```

### MODAL-01: Toolbar-Icon statt Text (Beispiel CreateWebsiteSheet)
```swift
// Vorher
ToolbarItem(placement: .cancellationAction) {
    Button("button.cancel") { dismiss() }
}
ToolbarItem(placement: .confirmationAction) {
    Button("button.create") { /* ... */ }
    .disabled(!isValid)
}

// Nachher
ToolbarItem(placement: .cancellationAction) {
    Button { dismiss() } label: {
        Image(systemName: "xmark")
    }
}
ToolbarItem(placement: .confirmationAction) {
    Button {
        Task {
            await viewModel.createWebsite(name: name, domain: domain)
            dismiss()
        }
    } label: {
        Image(systemName: "checkmark")
    }
    .disabled(!isValid)
}
```

### ACCT-02: serverType-Integration in AddAccountView (Muster aus LoginView)
```swift
// State hinzufügen
@State private var serverType: ServerType = .cloud

// Sektion im body (nach Provider-Auswahl)
VStack(alignment: .leading, spacing: 12) {
    Text("login.serverType")
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)

    HStack(spacing: 12) {
        ForEach(ServerType.allCases, id: \.self) { type in
            ServerTypeButton(
                type: type,
                isSelected: serverType == type,
                providerColor: selectedProvider == .umami ? Color.orange : Color.blue
            ) {
                withAnimation(.spring(duration: 0.3)) {
                    serverType = type
                    if type == .cloud {
                        serverURL = selectedProvider == .umami
                            ? "https://cloud.umami.is"
                            : "https://plausible.io"
                    } else {
                        serverURL = ""
                    }
                }
            }
        }
    }
}

// URL-Feld nur für selfHosted anzeigen
if serverType == .selfHosted {
    TextField("account.add.serverURL", text: $serverURL)
        // ...
}

// isFormValid anpassen
private var isFormValid: Bool {
    let hasValidServer = serverType == .cloud || !serverURL.isEmpty
    if selectedProvider == .umami {
        return hasValidServer && !username.isEmpty && !password.isEmpty
    } else {
        return hasValidServer && !apiKey.isEmpty
    }
}

// addAccount()-Methode: URL für Cloud-Auswahl aus Provider ableiten
var normalizedURL = serverType == .cloud
    ? (selectedProvider == .umami ? "https://cloud.umami.is" : "https://plausible.io")
    : serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
```

## Vollständige Übersicht: Alle Sheets in AdminSheets.swift

| Sheet | Cancel-Button | Confirm/Done-Button | Umstellung |
|-------|--------------|---------------------|------------|
| `CreateWebsiteSheet` | "button.cancel" | "button.create" | `xmark` + `checkmark` |
| `CreateTeamSheet` | "button.cancel" | "button.create" | `xmark` + `checkmark` |
| `CreateUserSheet` | "button.cancel" | "button.create" | `xmark` + `checkmark` |
| `PlausibleTrackingCodeSheet` | keiner | "button.done" | nur `checkmark` |
| `TrackingCodeSheet` | keiner | "button.done" | nur `checkmark` |
| `ShareLinkSheet` | keiner | "button.done" | nur `checkmark` |
| `EditWebsiteSheet` | "button.cancel" | "button.save" | `xmark` + `checkmark` |
| `TeamMemberSheet` | keiner | "button.done" | nur `checkmark` |

## Environment Availability

Step 2.6: SKIPPED (keine externen Dependencies — reine SwiftUI-Code-Änderungen)

## Validation Architecture

> `nyquist_validation` nicht explizit auf false gesetzt — Section wird eingeschlossen.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (Xcode built-in) |
| Config file | InsightFlow.xcodeproj (Scheme: InsightFlowTests) |
| Quick run command | `xcodebuild test -scheme InsightFlow -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:InsightFlowTests` |
| Full suite command | `xcodebuild test -scheme InsightFlow -destination 'platform=iOS Simulator,name=iPhone 16'` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ACCT-01 | Lokalisierter String wird korrekt angezeigt | manual-only | — | N/A |
| ACCT-02 | AddAccountView zeigt Self-Hosted/Cloud-Auswahl | manual-only | — | N/A |
| ACCT-03 | AddAccountView hat X-Button zum Schließen | manual-only | — | N/A |
| MODAL-01 | Admin-Sheet-Toolbar-Buttons zeigen Icons | manual-only | — | N/A |

**Begründung manual-only:** Alle Requirements betreffen SwiftUI View-Rendering und UI-Interaktion. XCTest-Tests im Projekt sind ausschließlich Unit-Tests für Model/ViewModel/Service-Layer (`AccountManagerTests`, `DashboardViewModelTests` etc.) — keine UI-Tests. Das Projekt hat keine `XCUITest`-Target-Konfiguration. View-Fix-Korrektheit wird durch Simulator-Build-and-Run verifiziert.

### Sampling Rate
- **Per task commit:** Build-Kompilierung: `xcodebuild build -scheme InsightFlow -destination 'platform=iOS Simulator,name=iPhone 16'`
- **Per wave merge:** Volles Test-Suite: `xcodebuild test -scheme InsightFlow -destination 'platform=iOS Simulator,name=iPhone 16'`
- **Phase gate:** Alle 4 Requirements manuell im Simulator verifiziert

### Wave 0 Gaps
Keine — existierende Testinfrastruktur deckt Phase-Requirements ausreichend ab (Unit-Tests für untangierte Schichten, manuelle Verifikation für View-Fixes ist ausreichend und projektüblich).

## Sources

### Primary (HIGH confidence)
- Direkte Codebase-Analyse: `InsightFlow/Views/Auth/LoginView.swift` — `ServerType` enum, `ServerTypeButton` Komponente, Bug auf Zeile 242
- Direkte Codebase-Analyse: `InsightFlow/Views/Dashboard/DashboardView.swift` — `AddAccountView` (Zeile 497–701), fehlendes Toolbar und fehlender serverType-Selector
- Direkte Codebase-Analyse: `InsightFlow/Views/Admin/AdminSheets.swift` — alle 8 Sheets mit Text-Toolbar-Buttons
- Direkte Codebase-Analyse: `InsightFlow/Resources/de.lproj/Localizable.strings` + `en.lproj/Localizable.strings` — vorhandene Strings verifiziert

### Secondary (MEDIUM confidence)
Keine externen Quellen nötig — alle Befunde basieren auf direkter Codebase-Analyse.

## Metadata

**Confidence breakdown:**
- Bug-Lokalisierung (ACCT-01–03): HIGH — direkter Code-Scan, klare Ursachen
- Modale (MODAL-01): HIGH — alle 8 Sheets analysiert, Pattern eindeutig
- Implementierungs-Muster: HIGH — Vorlage liegt in derselben Codebase

**Research date:** 2026-04-03
**Valid until:** 2026-05-03 (stabile SwiftUI-Patterns, kein fast-moving ecosystem)
