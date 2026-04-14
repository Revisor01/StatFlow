# Phase 23: Screenshots, Assets & App Store Submission (DE/EN/FR) - Context

**Gathered:** 2026-04-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Produktionsreife App-Store-Screenshots für StatFlow in drei Sprachen (DE/EN/FR) erstellen und Submission via App Store Connect API (Metadaten, Screenshots, Submit-for-Review) automatisieren. Binary-Upload (IPA) bleibt manuell über Xcode Organizer, da API-seitig nicht verfügbar. App-Preview-Video ist out of scope.

</domain>

<decisions>
## Implementation Decisions

### Visual Theme (Screenshots)
- **D-01:** Hybrid hell-mit-Tinte — Off-White Hintergrund, schwarze Pinselstrich-Akzente (greifen das StatFlow-Logo auf: weißer BG + drei schwarze pinselstrichartige Balken als aufsteigendes Diagramm). Schwarze Typo. Mock-Screens bringen die Farbe durch die App-UI selbst (Umami-Türkis, Plausible-Indigo).
- **D-02:** Logo-DNA als Hintergrund-Motiv: Pinselstrich-Balken können als dezentes Hintergrund-Element zitiert werden, aber nicht so prominent, dass sie die Screens stören (siehe Playbook Anti-Pattern #9: "Layout-Komplexität").
- **D-03:** Design-Tokens werden in SHOT-02 aus dem Logo extrahiert. Pre-Entscheidung: `bgFrom` = reines Weiß (#FFFFFF) oder warmes Off-White (#FAFAF7), `textPrimary` = #000000 (Logo-treu), Akzent = schwarze Pinselstrich-Grafik (PNG/SVG).

### Screen-Auswahl & Reihenfolge (8 Slides)
- **D-04:** 8 Slides in fester Reihenfolge:
  1. **Dashboard** (headline-top) — Hook: "Alle Zahlen auf einen Blick"
  2. **Details** (mock-left) — Tiefere Insights
  3. **Realtime** (mock-right) — "Live dabei"
  4. **Vergleich** (headline-top) — Zeitraumvergleich
  5. **Events** (mock-left) — Advanced-Feature
  6. **Widget** (mock-right) — Homescreen-USP
  7. **Account Switcher** (headline-top) — Multi-Account/Multi-Provider
  8. **Start Screen / Accounts-Liste** (mock-left) — Setup-Moment
- **D-05:** `5b Vergleich.png` wird nicht verwendet (Duplikat von Slide 4).
- **D-06:** Layout-Rotation folgt Playbook-Mantra `top, left, right, top, left, right` — zentraler headline-top-Moment auf Slides 1, 4, 7.
- **D-07:** Die ersten 3 Slides (Dashboard, Details, Realtime) sind entscheidend — Apple zeigt diese in der Suche. Dort die stärksten Claims platzieren.

### Copy-Tonalität
- **D-08:** Du-Ansprache (DE), you-direct (EN), tu (FR, informell) — konsistent mit bestehender App-Store-Description.
- **D-09:** 2-3 kurze Fragmente pro Slide, jeweils mit Punkt auf eigener Zeile (Playbook Anti-Pattern #7 vermeiden). Beispiel-Struktur:
  > "Live dabei."
  > "Jeden Klick. Jeden Besucher."
  > "In Echtzeit."
- **D-10:** Manuelle Umbrüche per `\n` im Source-Code (Playbook Anti-Pattern #2 — Browser-Auto-Wrap nicht vertrauen).
- **D-11:** Hybrid-Struktur: Claim groß (150px headline-top / 140px mock-*), Subline kleiner (76px / 68px). Claim behauptet, Subline liefert Substanz — dürfen sich nicht wiederholen.
- **D-12:** Sprachspezifisch, nicht 1:1 übersetzt — EN und FR dürfen anders klingen als DE. Idiomatische Wendungen bevorzugt.

### Französische Übersetzung
- **D-13:** Claude übersetzt FR direkt aus DE, idiomatisch (kein Native-Review-Gate vor Submission). User übernimmt Verantwortung für FR-Qualität.
- **D-14:** FR-Vokabel-Richtlinie: etablierter franz. Tech-Jargon ("tableau de bord" für Dashboard, "statistiques" für Statistik, "suivi" statt Anglizismus "tracking", "analytics" akzeptabel da im franz. Kontext üblich).
- **D-15:** FR-Localization umfasst: Screenshot-Claims, App Store Description, Subtitle, Keywords, Promotional Text, What's New. **Privacy Policy bleibt Englisch für alle Locales** (keine FR-Privacy-Policy-Variante).

### App-Preview-Video
- **D-16:** Kein Video. Submission erfolgt nur mit Screenshots. Kein Video-Recording, kein Schnitt, kein Overlay-Tooling.

### Submission-Scope via ASC API
- **D-17:** Volle Automatisierung über App Store Connect API. Script übernimmt:
  - App-Version anlegen/prüfen
  - Screenshots-Upload pro Locale (DE/EN/FR × 8 Slides)
  - Metadaten-Setting (Description, Keywords, Subtitle, Promotional Text, What's New)
  - FR-Localization-Anlage in ASC
  - Review-Notes anhängen
  - "Submit for Review" triggern
- **D-18:** Binary-Upload (IPA) bleibt manuell via Xcode Organizer (oder optional `xcrun altool --upload-app`). API-seitig nicht im Scope dieses Scripts.
- **D-19:** ASC API-Key liegt bereits in `~/.claude/secrets.env` (siehe `app-store/secrets.md` für Details). JWT-Auth-Logik muss im Submission-Script implementiert werden.

### Projekt-Struktur
- **D-20:** Generator + Submission leben unter existierendem `app-store/`-Ordner:
  ```
  app-store/
  ├── description.md           (existiert, DE+EN — FR wird in D-15 ergänzt)
  ├── review-notes.md          (existiert)
  ├── secrets.md               (existiert)
  ├── screenshots/
  │   ├── generator/           (Next.js-Projekt, html-to-image)
  │   ├── source/{de,en,fr}/   (Simulator-Source-Shots)
  │   └── export/{de,en,fr}/   (finale PNGs)
  └── submission/              (ASC-API-Script, TypeScript)
  ```
- **D-21:** .gitignore-Ergänzungen:
  ```
  app-store/screenshots/generator/node_modules/
  app-store/screenshots/generator/.next/
  app-store/screenshots/generator/out/
  app-store/submission/node_modules/
  ```
- **D-22:** Export-PNGs werden committet (reproduzierbar, klein). Source-PNGs aus Simulator werden NICHT committet (können regeneriert werden; User zieht ohnehin kurz vor Submission nochmal frisch).

### Content-Daten in Screenshots
- **D-23:** Echte Daten aus den aktuellen Test-/Produktiv-Accounts — kein Seed-Script, keine Fake-Zahlen, kein Traffic-Aufblasen. User zieht kurz vor Submission frische Simulator-Shots aus dem jeweils aktuellen Datenstand.
- **D-24:** Source-Shots auf `~/Desktop/{1-8} *.png` sind Platzhalter zum Layout-Bauen. Finale Shots werden am Submission-Tag erneut aus dem iPhone 16 Pro Max Simulator gezogen (1320×2868, Statusbar via `xcrun simctl status_bar override` auf 9:41/WiFi/Akku-voll).
- **D-25:** Statusbar-Override-Kommandos aus Playbook übernehmen (siehe `app-store-screenshots-playbook/PLAYBOOK.md` §Simulator vorbereiten).

### Claude's Discretion
- Exakte Farbwerte für `bgFrom`/`bgTo`/Akzent (ableiten aus Logo-Analyse in SHOT-02)
- Konkrete Copy-Formulierungen pro Slide × Sprache (Claude entwirft, User reviewt)
- Background-Blob-Varianten-Index (`idx % 3` Rotation laut Playbook)
- Schriftart (Playbook empfiehlt Chrome-kompatible Fonts — konkrete Wahl bei Implementation)
- Technische Details des ASC-API-Scripts: Retry-Logik, Rate-Limit-Handling, Error-Recovery
- Reihenfolge der API-Calls im Submission-Script (was passiert wenn ein Screenshot-Upload fehlschlägt)

</decisions>

<specifics>
## Specific Ideas

- **Logo-Aufgreifen:** Drei Pinselstrich-Balken aus dem Logo sind der visuelle Fingerabdruck. Können als dezentes Hintergrund-Motiv, als Rahmen-Element oder Slide-Separator genutzt werden — aber zurückhaltend, nicht dominant.
- **Copy-Referenzstil aus Playbook (ValetudiOS-Beispiel):**
  > "Live dabei." / "Karte in Echtzeit — du siehst jeden Meter."
- **Konsistenz mit App-Store-Description:** Die bereits existierende Description in `app-store/description.md` (DE+EN) nutzt "Du"-Ansprache und Sätze wie "Deine Website-Zahlen. Immer dabei." — Screenshot-Claims sollten im selben Tonfall stehen, aber kürzer/pointierter.
- **Analytics-App-Charakter:** Keine verspielten Blobs wie ValetudiOS — mehr geometrische Klarheit, Zahlen/Charts als visueller Hook. Analytisch, nicht kumpelhaft-warm.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Screenshot-Workflow (MANDATORY)
- `app-store-screenshots-playbook/PLAYBOOK.md` — Kompletter Workflow, Anti-Pattern, Layout-Prinzipien, Copy-Regeln, Simulator-Setup, Design-Tokens-Struktur. **Wird 1:1 gefolgt**, nur THEME/COPY/LAYOUT_ROTATION/SCREEN_IDS werden projektspezifisch angepasst.
- `app-store-screenshots-playbook/reference/page.tsx` — Generator-Template (React/Next.js, html-to-image). Projekt-agnostische Teile (MultilineText, Background, DeviceMockup, SlideCanvas, Export-Logic, Hidden-full-size-Nodes-Pattern) bleiben unverändert.
- `app-store-screenshots-playbook/reference/layout.tsx` — Layout-Root für Next.js-App.

### App Store Listing (bereits erstellt in Phase 22)
- `app-store/description.md` — DE+EN App Store Copy (Title, Subtitle, Keywords, Description, Promotional Text, What's New). **FR wird in Phase 23 ergänzt** (D-15).
- `app-store/review-notes.md` — App Review Notes mit Testaccount-Daten (Umami + Plausible).
- `app-store/secrets.md` — ASC API-Key-Referenz, Submission-Credentials.

### Source-Material
- `~/Desktop/1 Start Screen.png` bis `~/Desktop/8 Widget.png` — deutsche Platzhalter-Screenshots aus dem iPhone-Simulator. Werden vor Submission durch frische Shots ersetzt (D-24).

### Project Docs
- `.planning/PROJECT.md` — App-Charakter, Zielgruppe, Core Value.
- `.planning/milestones/v2.8-ROADMAP.md` — Phase 23 Requirements (SHOT-01..05, VIDEO-01 [out of scope], SUBMIT-01).
- `.planning/STATE.md` — Projekt-Entscheidungen (StatFlow-Name, Bundle ID, Testaccounts, Logo-Beschreibung).

### Apple / External
- Apple App Store Connect API: https://developer.apple.com/documentation/appstoreconnectapi — für Submission-Script-Implementierung (JWT-Auth, Screenshot-Upload, Metadata-Set, Submit-for-Review).
- Apple Human Interface Guidelines für Screenshots: Device-Frames optional, max 10 Slides pro Locale, 1320×2868 für 6.9" iPhones.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `app-store/description.md` — bestehende DE+EN Copy dient als Tonalitäts-Referenz für Screenshot-Claims und als Quelle für FR-Übersetzung.
- `app-store/review-notes.md` — Review-Notes werden via ASC API angehängt (SUBMIT-01).
- Playbook-Referenz-Code (`reference/page.tsx` + `layout.tsx`) — projekt-agnostisches Template, nur vier Stellen werden angepasst (THEME, COPY, LAYOUT_ROTATION, SCREEN_IDS).

### Established Patterns
- Projekt nutzt keine Next.js-App im Hauptrepo — der Screenshot-Generator ist ein isolierter Subfolder, der eigenes `package.json` + `node_modules` hat. Keine Vermischung mit dem iOS-Projekt.
- Existierende `app-store/`-Struktur folgt Markdown-Konvention — Submission-Script als TypeScript bricht das nicht, da es in eigenem Subfolder lebt.
- Secrets-Pattern: API-Keys liegen zentral in `~/.claude/secrets.env`, werden nicht im Repo gespeichert. ASC-API-Key folgt diesem Muster (siehe `app-store/secrets.md` für Konkretes).

### Integration Points
- ASC-API-Submission-Script liest Keys aus `~/.claude/secrets.env` (oder via Env-Var zur Runtime).
- Screenshot-Export-Ordner (`app-store/screenshots/export/{de,en,fr}/`) ist der Input für das Submission-Script — klare Schnittstelle.
- Keine Änderungen am iOS-Projekt (InsightFlow.xcodeproj) nötig — Phase 23 ist reine Marketing-Asset-Produktion.

</code_context>

<deferred>
## Deferred Ideas

- **App-Preview-Video** — Entschieden als out-of-scope für Phase 23 (D-16). Kann in späterem Release (v2.9 oder v3.0) nachgereicht werden, falls Screenshot-Performance im Store ausbaufähig erscheint.
- **Binary-Upload-Automatisierung** — `xcrun altool --upload-app` oder Fastlane-Integration könnte Binary-Upload automatisieren, ist aber out-of-scope (ASC API kann das nicht direkt).
- **FR-Native-Review vor Submission** — Explizit verworfen (D-13). Könnte in späterem Release nachgezogen werden, wenn FR-Performance schwach ist.
- **Weitere Sprachen (ES, IT, etc.)** — Nur DE/EN/FR für diesen Release. Weitere Locales in Backlog.
- **Seed-Script für schönere Daten** — Explizit verworfen (D-23). Echte Daten werden verwendet.
- **A/B-Testing von Screenshot-Varianten** (Apple Product Page Optimization) — Nicht für Launch. Kandidat für v2.9+.

</deferred>

---

*Phase: 23-screenshots-assets-submission-en-fr-de*
*Context gathered: 2026-04-14*
