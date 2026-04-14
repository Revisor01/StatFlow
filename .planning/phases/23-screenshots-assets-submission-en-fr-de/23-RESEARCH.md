# Phase 23: Screenshots, Assets & App Store Submission (DE/EN/FR) — Research

**Researched:** 2026-04-14
**Domain:** App Store Marketing Assets + ASC API Submission
**Confidence:** HIGH (ASC API via offizielles OpenAPI-Spec verifiziert; Generator-Muster via Playbook-Analyse)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Hybrid hell-mit-Tinte — Off-White Hintergrund, schwarze Pinselstrich-Akzente (Logo-DNA). Schwarze Typo.
- **D-02:** Logo-Pinselstrich-Balken als dezentes Hintergrund-Motiv (nicht dominant — Anti-Pattern #9 beachten).
- **D-03:** Design-Tokens in SHOT-02 aus Logo extrahieren. Pre-Entscheidung: `bgFrom` = #FFFFFF oder #FAFAF7, `textPrimary` = #000000.
- **D-04:** 8 Slides in fester Reihenfolge: Dashboard / Details / Realtime / Vergleich / Events / Widget / Account Switcher / Start Screen.
- **D-05:** `5b Vergleich.png` wird NICHT verwendet.
- **D-06:** Layout-Rotation: top / left / right / top / left / right / top / left.
- **D-07:** Erste 3 Slides tragen stärkste Claims (Apple zeigt diese in der Suche).
- **D-08:** Du-Ansprache (DE), you-direct (EN), tu (FR, informell).
- **D-09:** 2-3 kurze Fragmente pro Slide, jeweils mit Punkt auf eigener Zeile.
- **D-10:** Manuelle Umbrüche per `\n` im Source-Code.
- **D-11:** Hybrid-Struktur: Claim 150px (headline-top) / 140px (mock-*), Subline 76px / 68px.
- **D-12:** Sprachspezifisch, nicht 1:1 übersetzt.
- **D-13:** Claude übersetzt FR direkt, kein Native-Review-Gate.
- **D-14:** FR-Vokabel: "tableau de bord", "statistiques", "suivi", "analytics" akzeptabel.
- **D-15:** FR-Localization umfasst: Screenshot-Claims, Description, Subtitle, Keywords, Promotional Text, What's New. Privacy Policy bleibt EN für alle Locales.
- **D-16:** Kein App-Preview-Video (out of scope).
- **D-17:** Volle Automatisierung über ASC API: Version prüfen/anlegen, Screenshots-Upload (DE/EN/FR × 8), Metadaten, FR-Localization anlegen, Review-Notes, Submit-for-Review.
- **D-18:** Binary-Upload (IPA) bleibt manuell via Xcode Organizer.
- **D-19:** ASC API-Key liegt in `~/.claude/secrets.env`.
- **D-20:** Projektstruktur unter `app-store/`: `screenshots/generator/`, `screenshots/source/{de,en,fr}/`, `screenshots/export/{de,en,fr}/`, `submission/`.
- **D-21:** .gitignore-Ergänzungen für node_modules, .next, out, submission/node_modules.
- **D-22:** Export-PNGs werden committet; Source-PNGs nicht.
- **D-23:** Echte Daten aus Test-/Produktiv-Accounts, keine Fake-Zahlen.
- **D-24:** Finale Source-Shots am Submission-Tag frisch aus iPhone 16 Pro Max Simulator (1320×2868, Statusbar-Override).
- **D-25:** Statusbar-Override-Kommandos aus Playbook.

### Claude's Discretion
- Exakte Farbwerte für bgFrom/bgTo/Akzent (aus Logo-Analyse in SHOT-02)
- Konkrete Copy-Formulierungen pro Slide × Sprache
- Background-Blob-Varianten-Index (idx % 3 Rotation)
- Schriftart (Chrome-kompatibel)
- Technische Details des ASC-API-Scripts: Retry-Logik, Rate-Limit-Handling, Error-Recovery
- Reihenfolge der API-Calls im Submission-Script

### Deferred Ideas (OUT OF SCOPE)
- App-Preview-Video
- Binary-Upload-Automatisierung (xcrun altool / Fastlane)
- FR-Native-Review vor Submission
- Weitere Sprachen (ES, IT etc.)
- Seed-Script für schönere Daten
- A/B-Testing (Apple Product Page Optimization)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SHOT-01 | Screenshot-Generator-Projekt scaffolden (Next.js + html-to-image) | Next.js + bun verfügbar; Playbook-Template vollständig analysiert |
| SHOT-02 | THEME + Design-Tokens aus StatFlow-Logo ableiten | Token-Struktur aus reference/page.tsx bekannt; Off-White/schwarz vorgewählt |
| SHOT-03 | Source-Screenshots aus iPhone 16 Pro Max Simulator (1320×2868, Statusbar-Override) | Simulator mit UDID 54C3BF3E läuft bereits (Booted); Desktop-Shots bereits 1320×2868 |
| SHOT-04 | COPY + LAYOUT_ROTATION für DE/EN/FR — 8 Slides | COPY-Map-Typ aus reference/page.tsx; FR-Vokabeln aus D-14; Slide-Reihenfolge aus D-04 |
| SHOT-05 | Export pro Sprache als PNG in export/{de,en,fr}/ | html-to-image-Pattern aus Playbook; Export-Flow aus reference/page.tsx |
| SUBMIT-01 | ASC API-Upload (Screenshots + Metadaten DE/EN/FR) | Vollständig aus OpenAPI-Spec verifiziert; ASC Key existiert in secrets.env |
</phase_requirements>

---

## Summary

Phase 23 hat zwei klar getrennte Produktionsstränge: (1) den **Screenshot-Generator** (Next.js + html-to-image nach Playbook-Rezept) und (2) das **Submission-Script** (TypeScript, ASC API). Beide leben unter `app-store/` als isolierte Subprojekte.

Der Generator folgt zu 95% dem bestehenden `reference/page.tsx`-Template — angepasst werden nur THEME (Off-White + schwarz statt Türkis-Blau), COPY (3 Sprachen statt 2), SCREEN_IDS (8 Slides) und LAYOUT_ROTATION. Der bestehende `generate.sh` (ImageMagick-basiert) ist ein Vorgänger-Ansatz und wird nicht wiederverwendet — das Next.js-Pattern liefert qualitativ bessere Ergebnisse.

Das Submission-Script muss die ASC API korrekt navigieren. Kritischer Fund aus dem offiziellen OpenAPI-Spec: Es gibt **keinen** `APP_IPHONE_69`-Wert im `ScreenshotDisplayType`-Enum — der aktuell höchste iPhone-Wert ist `APP_IPHONE_67`. Da die Ziel-Auflösung 1320×2868 offiziell für 6.9"-Geräte gilt, muss das Script beim API-Call `APP_IPHONE_67` verwenden, bis Apple die Spec aktualisiert. Alternativ kann der Screenshot-Upload manuell über ASC-UI erfolgen und nur die Metadaten-Teile automatisiert werden — das ist die sicherere Fallback-Strategie.

**Primary recommendation:** Generator zuerst, dann Submission-Script. Script-Scope auf sichere API-Calls beschränken (Metadaten + Localizations); Screenshot-Upload kann manuell als Fallback bleiben, wenn der `APP_IPHONE_67`-Workaround nicht funktioniert.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Next.js | 15.x (latest) | Generator-Framework | Playbook-vorgeschrieben; html-to-image braucht Client-Rendering |
| html-to-image | 1.11.x | PNG-Export aus DOM-Nodes | Einzige zuverlässige Browser-basierte Canvas-Alternative |
| TypeScript | 5.x | Generator + Submission-Script | Typsicherheit für ASC-API-Payloads |
| jsonwebtoken | 9.0.3 | JWT-Generierung für ASC API | Etabliert, Node.js-native, unterstützt ES256 + .p8-Key |
| bun | 1.3.12 | Package-Manager + Dev-Server | Im Playbook vorgeschrieben; auf dieser Maschine installiert |

[VERIFIED: npm registry — jsonwebtoken 9.0.3, jose 6.2.2, bun 1.3.12]
[VERIFIED: Playbook PLAYBOOK.md — bun vorgeschrieben für Scaffold und Dev]

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| jose | 6.2.2 | Alternative JWT-Lib | Wenn jsonwebtoken Probleme mit .p8 macht; PKCS8 import built-in |
| sips | macOS built-in | Pixel-Dimensionen validieren | Vor dem ASC-Upload: `sips -g pixelWidth -g pixelHeight` |
| xcrun simctl | Xcode built-in | Simulator-Statusbar-Override + Screenshot-Export | SHOT-03 |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| jsonwebtoken | jose | jose hat modernere Promise-API; jsonwebtoken synchroner — beide OK für JWT ES256 |
| html-to-image | Playwright headless | Playwright verlässlicher bei Webfonts, aber deutlich mehr Setup; html-to-image reicht für diesen Use Case |
| Next.js Generator | Figma Export | Figma nicht im Stack; Next.js gibt volle Kontrolle über Layout-Pixel |

**Installation:**
```bash
# Generator
bunx create-next-app@latest app-store/screenshots/generator --typescript --tailwind --app --src-dir --no-eslint --import-alias "@/*" --yes
cd app-store/screenshots/generator && bun add html-to-image

# Submission Script
mkdir -p app-store/submission
cd app-store/submission && npm init -y && npm install typescript @types/node jsonwebtoken @types/jsonwebtoken ts-node
```

---

## Architecture Patterns

### Recommended Project Structure
```
app-store/
├── description.md                    (DE+EN existiert; FR wird ergänzt)
├── review-notes.md                   (existiert)
├── secrets.md                        (existiert — KEIN Commit)
├── screenshots/
│   ├── generate.sh                   (VERALTET — nicht mehr verwenden)
│   ├── generator/                    (NEU: Next.js + html-to-image)
│   │   ├── package.json
│   │   ├── src/app/
│   │   │   ├── page.tsx              (angepasstes reference/page.tsx)
│   │   │   └── layout.tsx            (reference/layout.tsx — unverändert)
│   │   └── public/
│   │       ├── mockup.png            (Kit-Asset)
│   │       └── screenshots/
│   │           ├── de/               (Source-Shots für Generator-Preview)
│   │           ├── en/
│   │           └── fr/
│   ├── source/                       (Simulator-Raw-Shots — NICHT commiten)
│   │   ├── de/
│   │   ├── en/
│   │   └── fr/
│   └── export/                       (finale PNGs — commiten)
│       ├── de/  (01-dashboard-de.png … 08-start-de.png)
│       ├── en/  (01-dashboard-en.png … 08-start-en.png)
│       └── fr/  (01-dashboard-fr.png … 08-start-fr.png)
└── submission/
    ├── package.json
    ├── tsconfig.json
    ├── submit.ts                     (Haupt-Script)
    └── lib/
        ├── jwt.ts                    (Token-Generierung)
        ├── asc-api.ts                (API-Client mit Retry)
        └── config.ts                 (Locale-Map, Screenshot-Pfade)
```

### Pattern 1: COPY-Map-Erweiterung auf 3 Sprachen

Das `reference/page.tsx` definiert `type Copy = { de: ...; en: ... }`. Für Phase 23 wird dieser Typ auf FR erweitert:

```typescript
// Source: app-store-screenshots-playbook/reference/page.tsx (angepasst)
type Copy = {
  de: { headline: string; subline: string };
  en: { headline: string; subline: string };
  fr: { headline: string; subline: string };
};

type Locale = "de" | "en" | "fr";

const SCREEN_IDS = [
  "01-dashboard",
  "02-details",
  "03-realtime",
  "04-vergleich",
  "05-events",
  "06-widget",
  "07-account-switcher",
  "08-start",
] as const;

const LAYOUT_ROTATION: Layout[] = [
  "headline-top", // 01 Dashboard
  "mock-left",    // 02 Details
  "mock-right",   // 03 Realtime
  "headline-top", // 04 Vergleich
  "mock-left",    // 05 Events
  "mock-right",   // 06 Widget
  "headline-top", // 07 Account Switcher
  "mock-left",    // 08 Start Screen
];
```

### Pattern 2: THEME für "Hybrid hell-mit-Tinte"

Abweichend vom ValetudiOS-Template (dunkler Verlauf) verwendet StatFlow Off-White-Basis mit schwarzer Typo. Das BG_VARIANTS-Objekt wird entsprechend umgestellt:

```typescript
// Konkreter THEME für Hybrid hell-mit-Tinte
const THEME = {
  bgFrom: "#FAFAF7",          // warmes Off-White (Claude's Discretion — exakter Wert)
  bgTo: "#F0F0EC",            // leicht gebrochenes Weiß für Gradient-Tiefe
  blobLight: "#FFFFFF",       // reine Weiß-Highlights
  blobMid: "#F5F5F0",         // neutrales Midtone
  blobDark: "#E8E8E2",        // dezenter Schatten
  textPrimary: "#000000",     // Logo-treu: reines Schwarz
  textSecondary: "rgba(0,0,0,0.65)",  // abgeschwächter Kontrast für Subline
} as const;
```

**Achtung:** Die `BG_VARIANTS`-Blobs aus dem Reference-Template wirken auf hellem Hintergrund anders als auf dunklem. Blobs müssen deutlich transparenter eingestellt werden (opacity: 0.15-0.25 statt 0.35-0.55). Bei Bedarf durch statischen Pinselstrich-SVG als Hintergrund-Dekor ersetzen (D-02).

### Pattern 3: ASC API JWT-Generierung

```typescript
// Source: Verifiziert gegen Apple ASC OpenAPI-Spec + community examples
import * as fs from "fs";
import * as jwt from "jsonwebtoken";

function generateASCToken(): string {
  const privateKey = fs.readFileSync(process.env.APP_STORE_CONNECT_KEY_PATH!);
  return jwt.sign(
    {
      iss: process.env.APP_STORE_CONNECT_ISSUER_ID,
      aud: "appstoreconnect-v1",
      exp: Math.floor(Date.now() / 1000) + 20 * 60, // max 20 Minuten
    },
    privateKey,
    {
      algorithm: "ES256",
      header: {
        alg: "ES256",
        kid: process.env.APP_STORE_CONNECT_KEY_ID,
        typ: "JWT",
      },
    }
  );
}
```

[VERIFIED: Apple Developer Docs — JWT muss ES256, max 20 min, aud "appstoreconnect-v1", kid = Key-ID]
[VERIFIED: secrets.env — KEY_ID=6JGT8ZLHRJ, ISSUER_ID=408ad2bb-..., Key-File existiert]

### Pattern 4: ASC API Screenshot-Upload (3-Schritt-Flow)

```typescript
// Schritt 1: Reservation POST /v1/appScreenshots
const reservation = await ascApi.post("/v1/appScreenshots", {
  data: {
    type: "appScreenshots",
    attributes: { fileName: "01-dashboard-de.png", fileSize: fileBytes.length },
    relationships: {
      appScreenshotSet: { data: { type: "appScreenshotSets", id: screenshotSetId } }
    }
  }
});
// Response enthält: id, uploadOperations[] mit { method, url, offset, length, requestHeaders }

// Schritt 2: Upload-Parts (KEIN Auth-Header nötig — direkt zu S3)
for (const op of reservation.data.attributes.uploadOperations) {
  const chunk = fileBytes.slice(op.offset, op.offset + op.length);
  await fetch(op.url, {
    method: op.method,
    headers: Object.fromEntries(op.requestHeaders.map(h => [h.name, h.value])),
    body: chunk,
  });
}

// Schritt 3: Commit PATCH /v1/appScreenshots/{id}
import * as crypto from "crypto";
const md5 = crypto.createHash("md5").update(fileBytes).digest("hex");
await ascApi.patch(`/v1/appScreenshots/${reservation.data.id}`, {
  data: {
    type: "appScreenshots",
    id: reservation.data.id,
    attributes: { sourceFileChecksum: md5, uploaded: true }
  }
});
```

[VERIFIED: ASC OpenAPI-Spec — AppScreenshotCreateRequest, UploadOperation, AppScreenshotUpdateRequest Schemas]

### Pattern 5: FR-Localization anlegen

```typescript
// POST /v1/appStoreVersionLocalizations — neue Locale anlegen
await ascApi.post("/v1/appStoreVersionLocalizations", {
  data: {
    type: "appStoreVersionLocalizations",
    attributes: {
      locale: "fr-FR",          // VERIFIED: "fr-FR" ist der korrekte Locale-Code
      description: frDescription,
      keywords: frKeywords,
      promotionalText: frPromoText,
      whatsNew: frWhatsNew,
      // ACHTUNG: subtitle fehlt hier — kommt über AppInfoLocalizations!
    },
    relationships: {
      appStoreVersion: { data: { type: "appStoreVersions", id: versionId } }
    }
  }
});

// Subtitle liegt bei AppInfoLocalizations (app-level, nicht version-level)!
await ascApi.post("/v1/appInfoLocalizations", {
  data: {
    type: "appInfoLocalizations",
    attributes: { locale: "fr-FR", name: "StatFlow", subtitle: frSubtitle },
    relationships: { appInfo: { data: { type: "appInfos", id: appInfoId } } }
  }
});
```

[VERIFIED: ASC OpenAPI-Spec — AppStoreVersionLocalizationCreateRequest hat KEIN subtitle-Feld; subtitle liegt in AppInfoLocalizationCreateRequest (app-level)]

### Pattern 6: Submit for Review

```typescript
// 1. ReviewSubmission anlegen
const submission = await ascApi.post("/v1/reviewSubmissions", {
  data: {
    type: "reviewSubmissions",
    attributes: { platform: "IOS" },
    relationships: { app: { data: { type: "apps", id: appId } } }
  }
});

// 2. ReviewSubmissionItem anlegen (Version verknüpfen)
await ascApi.post("/v1/reviewSubmissionItems", {
  data: {
    type: "reviewSubmissionItems",
    relationships: {
      reviewSubmission: { data: { type: "reviewSubmissions", id: submission.data.id } },
      appStoreVersion: { data: { type: "appStoreVersions", id: versionId } }
    }
  }
});

// 3. Submission einreichen (isSubmitted: true via PATCH nicht direkt verfügbar —
//    ReviewSubmissionItemUpdateRequest hat nur "resolved" und "removed")
// ACHTUNG: Submit-for-Review erfolgt über den "Submit"-Button in ASC UI oder
// via reviewSubmission PATCH mit confirmReleaseType (verifizieren in Script)
```

[VERIFIED: ASC OpenAPI-Spec — ReviewSubmissionItemUpdateRequest hat nur `resolved` und `removed`; der eigentliche Submit-Trigger muss noch verifiziert werden (LOW confidence)]

### Anti-Patterns zu vermeiden
- **Dunkles Theme aus Reference übernehmen:** THEME muss komplett überschrieben werden — Blob-Opazitäten für hellen Hintergrund anpassen
- **Screenshot-Upload mit APP_IPHONE_69 versuchen:** Enum-Wert existiert NICHT im aktuellen OpenAPI-Spec (siehe kritischer Fund unten)
- **subtitle in AppStoreVersionLocalization setzen:** Subtitle ist ein app-level Feld (AppInfoLocalization), nicht version-level
- **Source-Shots aus 6.1" Simulator:** Playbook explizit: für das Mock-Mockup-Pattern immer 6.9" nativ nehmen (1320×2868)
- **Blobs für hellen Hintergrund unangepasst:** Blob-Opazitäten 0.35-0.55 (ValetudiOS) machen auf weiß sichtbare Kreise sichtbar — auf 0.12-0.20 reduzieren

---

## Don't Hand-Roll

| Problem | Nicht selbst bauen | Verwenden | Warum |
|---------|-------------------|-----------|-------|
| JWT ES256 Signierung | Custom Crypto-Code | jsonwebtoken oder jose | Korrekte .p8 PKCS8-Handhabung, Header-Format |
| Screenshot-Export aus Browser | Canvas.toBlob() | html-to-image (toPng) | Korrekte Font-Rendering, Transform-Bug-Fix bereits enthalten |
| MD5-Checksum für Upload-Commit | Custom Hash | Node.js crypto.createHash('md5') | Built-in, keine Dependency |
| Retry mit Exponential Backoff | Sleep-Loop | Utility-Funktion (3-5 Zeilen) | Einfach genug; kein Extra-Package nötig |
| Pixel-Dimensionen validieren | Eigener Parser | `sips -g pixelWidth -g pixelHeight` | macOS built-in, zuverlässig |

---

## Kritischer Fund: ScreenshotDisplayType APP_IPHONE_69 existiert NICHT

**[VERIFIED: ASC OpenAPI-Spec heruntergeladen und analysiert]**

Das offizielle Apple OpenAPI-Spec (Stand: April 2026) enthält folgende iPhone-Werte im `ScreenshotDisplayType`-Enum:

```
APP_IPHONE_35, APP_IPHONE_40, APP_IPHONE_47, APP_IPHONE_55,
APP_IPHONE_58, APP_IPHONE_61, APP_IPHONE_65, APP_IPHONE_67
```

`APP_IPHONE_69` ist **nicht** vorhanden. Das Apple Developer Forum bestätigt (September 2024), dass Apple den API-Spec noch nicht aktualisiert hat, obwohl die 6.9"-Anforderung für Screenshots bereits eingeführt wurde. [CITED: developer.apple.com/forums/thread/763908]

**Konsequenz für das Submission-Script:**
- Primär-Strategie: `APP_IPHONE_67` verwenden (deckt alle "großen iPhones" in der API ab) und beim Upload testen ob Apple 1320×2868 akzeptiert
- Fallback: Screenshot-Upload erfolgt manuell über ASC-UI; Submission-Script automatisiert nur Metadaten + Localizations + Submit-Trigger
- Der Planner MUSS diese Weichenstellung als explizite Aufgabe im Script vorsehen (try `APP_IPHONE_67` → bei 422-Fehler: Anleitung für manuellen Upload ausgeben)

**Für ScreenshotDisplayType gilt:** Apple skaliert 1320×2868 auf kleinere Geräte. Es genügt, nur diesen einen Set hochzuladen.

---

## Common Pitfalls

### Pitfall 1: APP_IPHONE_67 vs APP_IPHONE_69 — API-Spec-Lag
**Was schiefläuft:** Script schlägt beim Screenshot-Set-Anlegen mit 422 fehl, weil der Enum-Wert nicht akzeptiert wird.
**Warum:** Apple hat API-Spec nach Einführung der 6.9"-Anforderung nicht zeitnah aktualisiert.
**Vermeiden:** Zuerst `APP_IPHONE_67` versuchen. Bei 422: manuellen Upload anleiten. Vor Submission den Spec-Status prüfen (Apple aktualisiert regelmäßig).
**Warnsignal:** 422 Unprocessable Entity bei POST /v1/appScreenshotSets.

### Pitfall 2: Subtitle in AppStoreVersionLocalizations setzen
**Was schiefläuft:** `PATCH /v1/appStoreVersionLocalizations/{id}` ignoriert `subtitle` — es wird nicht gespeichert, keine Fehlermeldung.
**Warum:** Subtitle ist ein app-level Feld, liegt in `AppInfoLocalizations` (verwaltet App-Name + Subtitle), nicht in der version-spezifischen Localization.
**Vermeiden:** Subtitle immer über `POST/PATCH /v1/appInfoLocalizations` setzen; dafür `appInfoId` vorher mit `GET /v1/apps/{id}/appInfos` holen.
**Warnsignal:** FR-Subtitle erscheint nach Script-Lauf nicht in ASC.

### Pitfall 3: Token-Ablauf während langem Upload
**Was schiefläuft:** 24 Screenshots uploaden dauert 2-5 Minuten — JWT-Token läuft nach 20 Minuten ab.
**Warum:** Token-Lifetime ist von Apple hart auf 20 Minuten begrenzt; Token wird zu Beginn generiert.
**Vermeiden:** Token kurz vor jedem API-Call regenerieren (Timestamp prüfen, bei < 2 Minuten Rest neu generieren). Upload-Parts selbst brauchen keinen Auth-Header — nur die ASC-API-Calls.
**Warnsignal:** 401 Unauthorized mitten im Upload-Loop.

### Pitfall 4: Blob-Rendering auf hellem Hintergrund
**Was schiefläuft:** Blobs sind als sichtbare farbige Kreise im Screenshot erkennbar (Playbook Anti-Pattern #9).
**Warum:** Reference-Template hat Blob-Opazität 0.35-0.55 für dunkle Hintergründe — auf weiß zu stark.
**Vermeiden:** Opazität auf 0.12-0.20 reduzieren. Alternativ: Pinselstrich-SVG als statisches Hintergrund-Element (logo-DNA, D-02).
**Warnsignal:** Previews zeigen kreisförmige Halo-Effekte auf dem hellen Hintergrund.

### Pitfall 5: FR-Locale-Code falsch
**Was schiefläuft:** Localization wird mit `"fr"` statt `"fr-FR"` angelegt → ASC akzeptiert nicht oder erstellt falsche Localization.
**Warum:** ASC verwendet BCP-47-Codes mit Bindestrich-Region.
**Vermeiden:** Konsistent `"fr-FR"` (für Frankreich), `"de-DE"`, `"en-US"` verwenden.
**Warnsignal:** GET /v1/appStoreVersions/{id}/appStoreVersionLocalizations zeigt nach POST keine fr-FR-Localization.

### Pitfall 6: html-to-image Export-Bug (Transform)
**Was schiefläuft:** PNG-Export zeigt kleines Bild oben links, Rest ist transparent/leer.
**Warum:** html-to-image greift auf transform:scale-Nodes falsch zu.
**Vermeiden:** Hidden Full-Size-Nodes-Pattern aus Reference-Template verwenden (offscreen bei `left:-100000px`). Preview ist separater scaled-Clone nur zum Anschauen. Niemals direkt auf den scaled Preview-Node exportieren.
**Warnsignal:** Exported PNG hat korrekten Canvas, aber Bildinhalt ist klein oder verzerrt.

### Pitfall 7: REQUIREMENTS.md zeigt SHOT-* nicht
**Was beachten:** Das zentrale `REQUIREMENTS.md` wurde für v2.8 vor Phase 23 geschrieben und enthält SHOT-01..05 / SUBMIT-01 NICHT — diese Requirements sind nur im `v2.8-ROADMAP.md` und `CONTEXT.md` definiert. Das ist dokumentarische Lücke, kein Blocker.

---

## Code Examples

### Simulator Statusbar-Override (SHOT-03)
```bash
# [VERIFIED: PLAYBOOK.md]
UDID=54C3BF3E-51E9-4EAA-8F11-B2AEC75BC2E9  # iPhone 16 Pro Max — bereits Booted!

xcrun simctl status_bar $UDID override \
  --time "9:41" \
  --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 \
  --batteryState charged --batteryLevel 100

# Screenshot ziehen (pro Locale: App-Sprache wechseln vor Shot)
xcrun simctl io booted screenshot ~/Desktop/01-dashboard-de.png

# App in anderer Sprache starten (für EN/FR Shots)
xcrun simctl launch $UDID de.godsapp.statflow -AppleLanguages "(en)" -AppleLocale "en_US"
xcrun simctl launch $UDID de.godsapp.statflow -AppleLanguages "(fr)" -AppleLocale "fr_FR"
```

### Pixel-Validierung nach Export (SHOT-05)
```bash
# [VERIFIED: macOS sips built-in]
for f in app-store/screenshots/export/de/*.png; do
  sips -g pixelWidth -g pixelHeight "$f"
done
# Erwartung: pixelWidth: 1320, pixelHeight: 2868 für alle 24 PNGs
```

### ASC API App-ID holen
```typescript
// GET /v1/apps?filter[bundleId]=de.godsapp.statflow
const appsRes = await ascFetch("/v1/apps?filter[bundleId]=de.godsapp.statflow");
const appId = appsRes.data[0].id;
```

### Retry-Utility für ASC API (Rate-Limit 429)
```typescript
// [ASSUMED] — basiert auf allgemeinem Exponential-Backoff-Muster
async function withRetry<T>(fn: () => Promise<T>, maxAttempts = 5): Promise<T> {
  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (err: any) {
      if (err.status !== 429 || attempt === maxAttempts - 1) throw err;
      const delay = Math.pow(2, attempt) * 1000 + Math.random() * 500;
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
  throw new Error("Max retries exceeded");
}
```

---

## State of the Art

| Alter Ansatz | Aktueller Ansatz | Geändert | Bedeutung |
|--------------|-----------------|----------|-----------|
| generate.sh (ImageMagick) | Next.js + html-to-image | Phase 23 | ImageMagick-Script existiert, wird NICHT wiederverwendet — Next.js gibt Pixel-genaue Layout-Kontrolle |
| appStoreVersionSubmissions (legacy) | reviewSubmissions | ~2022 | Neues API für Submit-for-Review; Legacy funktioniert noch aber deprecated |
| 6.5" Pflicht-Screenshots | 6.9" als Primary, 6.5" optional | 2024 | 1320×2868 genügt allein; Apple skaliert für kleinere Geräte |

**Deprecated/outdated:**
- `generate.sh` in `app-store/screenshots/`: funktioniert noch, aber Layout-Qualität deutlich schlechter als html-to-image; NICHT für diese Phase verwenden
- `POST /v1/appStoreVersionSubmissions`: legacy Submit-Endpoint, durch reviewSubmissions ersetzt

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| bun | Generator-Scaffold + Dev-Server | ✓ | 1.3.12 | npm/node direkt |
| node | Submission-Script (ts-node) | ✓ | v25.9.0 | — |
| npm | Submission-Script Packages | ✓ | 11.12.1 | bun |
| sips | PNG-Dimensionen validieren | ✓ | macOS built-in | imagemagick identify |
| Xcode / xcrun simctl | Simulator-Statusbar + Screenshots | ✓ | system | — |
| iPhone 16 Pro Max Simulator | SHOT-03 Source-Shots | ✓ | UDID 54C3BF3E — bereits Booted | — |
| ASC API Key (.p8) | SUBMIT-01 Submission | ✓ | KEY_ID: 6JGT8ZLHRJ existiert | Manueller Upload |
| Chrome Browser | html-to-image Export (PNG) | [ASSUMED] | macOS-Standard | Firefox NICHT (Font-Bugs laut Playbook) |

**Missing dependencies:** Keine blockierenden Fehlstellen. Alle kritischen Tools verfügbar.

**Hinweis Chrome:** Playbook schreibt explizit Chrome vor für html-to-image Export (Firefox hat Font-Rendering-Bugs). Chrome-Verfügbarkeit nicht maschinell geprüft — wird als gegeben angenommen. [ASSUMED]

---

## Lokalisierungs-Architektur

### Deux Ebenen der ASC-Localization

| Ebene | Endpoint | Felder | Wichtig für FR |
|-------|----------|--------|----------------|
| App-Level | `/v1/appInfoLocalizations` | name, subtitle | FR-Subtitle hier! |
| Version-Level | `/v1/appStoreVersionLocalizations` | description, keywords, promotionalText, whatsNew | Bulk der Copy |

**FR-Locale-Code:** `fr-FR` [VERIFIED: Web-Recherche, ASC Lokalisierungs-Referenz]
**DE-Locale-Code:** `de-DE` [ASSUMED — analog zu fr-FR; ASC-Spec zeigt freien String]
**EN-Locale-Code:** `en-US` [ASSUMED — Standard-English für US App Store]

### COPY-Map-Typ für 8 Slides × 3 Sprachen

```typescript
type LocaleCopy = { headline: string; subline: string };
type Copy = { de: LocaleCopy; en: LocaleCopy; fr: LocaleCopy };
const COPY: Record<string, Copy> = {
  "01-dashboard": {
    de: { headline: "Alle Zahlen.\nAuf einen Blick.", subline: "Dashboard für Umami\nund Plausible Analytics." },
    en: { headline: "All your stats.\nAt a glance.", subline: "Dashboard for Umami\nand Plausible Analytics." },
    fr: { headline: "Toutes vos stats.\nD'un coup d'œil.", subline: "Tableau de bord pour Umami\net Plausible Analytics." },
  },
  // … 7 weitere Screens
};
```

[ASSUMED: Konkrete Copy-Formulierungen — Claude entwirft in SHOT-04, User reviewt]

### FR-Vokabular-Referenz (D-14)

| Konzept | Deutsch | English | Français |
|---------|---------|---------|----------|
| Dashboard | Dashboard | Dashboard | tableau de bord |
| Analytics | Analytics | Analytics | analytics (akzeptiert) |
| Statistiken | Statistiken | Statistics | statistiques |
| Tracking | Tracking | Tracking | suivi |
| Echtzeit | Echtzeit | Realtime | en temps réel |
| Vergleich | Vergleich | Comparison | comparaison |
| Ereignisse | Events | Events | événements |
| Widget | Widget | Widget | widget (akzeptiert) |
| Accounts | Accounts | Accounts | comptes |
| Website | Website | Website | site web |

---

## Validation Architecture

> nyquist_validation nicht explizit auf false gesetzt → Section included.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Keine automatisierten Tests im iOS-Projekt für Marketing-Assets — Validierung via Shell-Checks + manuelle Sichtprüfung |
| Config file | Kein Framework; Validierung via Bash-Einzeiler |
| Quick run command | `sips -g pixelWidth -g pixelHeight app-store/screenshots/export/de/*.png` |
| Full suite command | `find app-store/screenshots/export -name "*.png" | wc -l` (Erwartung: 24) + Dimensionen-Check |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SHOT-01 | Next.js-Generator scaffoldet korrekt | smoke | `ls app-store/screenshots/generator/package.json` | ❌ Wave 0 |
| SHOT-02 | THEME in page.tsx enthält Off-White Werte | manual | Visuelle Prüfung im Browser (9:41 Statusbar) | ❌ Wave 0 |
| SHOT-03 | Source-Shots 1320×2868 für alle 3 Locales | automated | `sips -g pixelWidth -g pixelHeight app-store/screenshots/source/**/*.png \| grep -v 1320` | ❌ nach SHOT-03 |
| SHOT-04 | 8 COPY-Einträge vorhanden (DE/EN/FR) | automated | `node -e "const c=require('./generator/src/app/page'); console.log(Object.keys(c.COPY).length === 8)"` | ❌ nach SHOT-04 |
| SHOT-05 | Genau 24 PNGs in export/ (8×3 Locales) | automated | `find app-store/screenshots/export -name "*.png" \| wc -l` = 24 | ❌ nach SHOT-05 |
| SHOT-05 | Alle PNGs 1320×2868 | automated | `sips -g pixelWidth -g pixelHeight app-store/screenshots/export/**/*.png \| grep -v "1320\|2868"` = leer | ❌ nach SHOT-05 |
| SUBMIT-01 | ASC API-Verbindung erfolgreich | automated | `ts-node app-store/submission/submit.ts --dry-run` → HTTP 200 auf GET /v1/apps | ❌ nach Submission-Setup |
| SUBMIT-01 | FR-Localization in ASC angelegt | manual | ASC-UI: App Store Connect → StatFlow → Localizations → Französisch vorhanden | manuell |
| SUBMIT-01 | Status "Ready for Review" in ASC | manual | ASC-UI-Prüfung nach Script-Durchlauf | manuell |

### Sampling Rate
- **Pro Task-Commit:** Nur direkter Artefakt-Check (z.B. `ls export/de/ | wc -l` nach SHOT-05)
- **Per Wave merge:** Vollständiger Dimensionen-Check aller 24 PNGs
- **Phase gate:** 24 PNGs vorhanden + korrekte Dimensionen + ASC Status "Waiting for Review" bestätigt

### Wave 0 Gaps
- [ ] `app-store/screenshots/generator/` — Next.js-Projekt muss scaffoldet werden (SHOT-01)
- [ ] `app-store/submission/` — TypeScript-Projekt muss angelegt werden (SUBMIT-01)
- [ ] `app-store/screenshots/source/{de,en,fr}/` — Verzeichnisse anlegen für Source-Shots
- [ ] `app-store/screenshots/export/{de,en,fr}/` — Verzeichnisse anlegen für fertige PNGs

---

## Security Domain

> security_enforcement nicht auf false gesetzt → Section included.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | ja (ASC JWT) | jsonwebtoken ES256; .p8 nicht im Repo |
| V3 Session Management | nein | Submission-Script ist one-shot, kein Session-State |
| V4 Access Control | nein | Lokales Script, kein Multi-User-Kontext |
| V5 Input Validation | gering | Locale-Codes, Datei-Pfade — keine User-Inputs |
| V6 Cryptography | ja | MD5 für Upload-Checksum (Apple-vorgegeben); JWT ES256 (via Library) |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| .p8 Key-Datei committed | Information Disclosure | `secrets.md` in .gitignore; Key-Path via Env-Var |
| Test-Account-Credentials in review-notes.md | Information Disclosure | review-notes.md ist bereits im Repo — Credentials sind Test-only, kein Produktiv-Schaden |
| JWT Token-Logging | Information Disclosure | Token nie in Console.log ausgeben; nur HTTP-Status loggen |
| ASC API-Key über .env-File im Repo | Information Disclosure | Key liegt in `~/.claude/secrets.env` (ausserhalb Repo) |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Chrome ist auf dieser Maschine verfügbar für html-to-image Export | Environment Availability | Export funktioniert nicht mit Firefox; Safari hat andere Font-Rendering-Abweichungen |
| A2 | `de-DE` und `en-US` sind die korrekten Locale-Codes für DE/EN in ASC | Localisierungs-Architektur | Localization-API gibt 422 zurück; DE könnte `de` sein |
| A3 | `APP_IPHONE_67` wird von ASC für 1320×2868-Screenshots akzeptiert | Kritischer Fund | Screenshot-Set-Anlage schlägt fehl → manueller Upload nötig |
| A4 | ReviewSubmission Submit-Trigger erfolgt über PATCH mit spezifischem Feld | Pattern 6: Submit for Review | Submit-for-Review funktioniert nicht automatisch → manuell in ASC-UI nötig |
| A5 | Konkrete Copy-Formulierungen (Slide-Claims) klingen idiomatisch auf FR | COPY-Architektur | FR-Copy klingt unnatürlich → user-seitiges Review vor Submission (D-13 akzeptiert dieses Risiko) |

---

## Open Questions

1. **APP_IPHONE_67 für 1320×2868 akzeptiert?**
   - Was wir wissen: Der Enum-Wert `APP_IPHONE_69` existiert nicht im OpenAPI-Spec; `APP_IPHONE_67` ist der höchste verfügbare iPhone-Wert
   - Was unklar ist: Ob Apple den 1320×2868-Upload mit `APP_IPHONE_67` stillschweigend akzeptiert oder 422 zurückgibt
   - Empfehlung: Im Submission-Script einen Test-Upload vor dem Haupt-Upload einbauen; bei Fehler: manuellen Upload-Fallback ausgeben

2. **Submit-for-Review exakter API-Trigger**
   - Was wir wissen: reviewSubmissionItems haben nur `resolved` und `removed` als PATCH-Felder (OpenAPI-Spec)
   - Was unklar ist: Wie der eigentliche "Submit"-Trigger ausgelöst wird (möglicherweise über PATCH /v1/reviewSubmissions/{id} mit `submitted: true`)
   - Empfehlung: Submission-Script soll Metadaten + Localizations + Screenshots automatisieren; Submit-for-Review kann manuell in ASC-UI erfolgen als letzter Schritt

3. **Keywords sind version-level oder app-level?**
   - Was wir wissen: `AppStoreVersionLocalizationCreateRequest` hat keywords-Feld; `AppInfoLocalizationCreateRequest` hat es nicht
   - Was klar ist: Keywords gehören in AppStoreVersionLocalizations (version-level) ✓

---

## Sources

### Primary (HIGH confidence)
- `app-store-screenshots-playbook/PLAYBOOK.md` — vollständiger Playbook-Text, analysiert
- `app-store-screenshots-playbook/reference/page.tsx` — Generator-Template, vollständig gelesen
- `app-store-screenshots-playbook/reference/layout.tsx` — Layout-Root, gelesen
- Apple ASC OpenAPI-Spec (`developer.apple.com/sample-code/app-store-connect/app-store-connect-openapi-specification.zip`) — lokal heruntergeladen, Schemas direkt extrahiert:
  - `ScreenshotDisplayType` enum (vollständig)
  - `AppScreenshotCreateRequest`, `UploadOperation`, `AppScreenshotUpdateRequest`
  - `AppStoreVersionLocalizationCreateRequest`, `AppStoreVersionLocalizationUpdateRequest`
  - `AppInfoLocalizationCreateRequest`, `AppInfoLocalizationUpdateRequest`
  - `ReviewSubmissionCreateRequest`, `ReviewSubmissionItemCreateRequest`, `ReviewSubmissionItemUpdateRequest`
  - `AppScreenshotSetCreateRequest`, `AppStoreVersionCreateRequest`
- `~/.claude/secrets.env` — ASC API Key-Daten verifiziert (KEY_ID, ISSUER_ID, Key-File-Pfad)
- `xcrun simctl list devices` — iPhone 16 Pro Max UDID 54C3BF3E bestätigt, bereits Booted

### Secondary (MEDIUM confidence)
- [Runway Blog: How to upload assets using the App Store Connect API](https://www.runway.team/blog/how-to-upload-assets-using-the-app-store-connect-api) — Upload-Flow Schritt-für-Schritt bestätigt (Swift)
- [Apple Help: Screenshot Specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/) — 6.9" = 1320×2868 Pflicht, 6.5" optional
- [Apple Dev Forums Thread 763908](https://developer.apple.com/forums/thread/763908) — APP_IPHONE_69 fehlt in API-Spec, bestätigt Sept. 2024
- [ASC CLI Docs](https://docs.asccli.sh/guides/screenshots) — locale-Format `fr-FR` bestätigt

### Tertiary (LOW confidence)
- WebSearch zu Rate-Limits: Limit ~300 req/Minute, Exponential Backoff empfohlen (nicht offiziell dokumentiert)
- Submit-for-Review Trigger: Runway Blog erwähnt `isSubmitted: true` in Swift-Beispiel, aber OpenAPI-Spec zeigt das Feld nicht im ReviewSubmissionItem

---

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH — bun/node/sips lokal verifiziert, Playbook gibt Next.js/html-to-image vor
- Generator-Architektur: HIGH — reference/page.tsx vollständig gelesen; Änderungen minimal
- ASC API Upload-Flow: HIGH — OpenAPI-Spec lokal analysiert
- ScreenshotDisplayType-Problem: HIGH — direkt aus Spec extrahiert, Forum-Post bestätigt
- FR-Locale-Code: MEDIUM — aus mehreren Quellen, aber kein direktes API-Test-Ergebnis
- Submit-for-Review Flow: LOW — OpenAPI-Spec zeigt Schemas, aber exakter Trigger unklar
- Copy-Formulierungen: LOW — Entwurfs-Phase, Claude-Discretion

**Research date:** 2026-04-14
**Valid until:** 2026-05-14 (ASC OpenAPI-Spec könnte bis dann APP_IPHONE_69 hinzufügen)
