# App Store Screenshots — Best-Practice-Playbook

Reproduzierbares Rezept für produktionsreife App-Store-Screenshots mit manueller Kontrolle über Layout und Copy. Erprobt an ValetudiOS (Robot-Steuerung) — das visuelle Design für StatFlow wird anders, aber das Gerüst, die Rotation, die Anti-Pattern und die Copy-Regeln übertragen 1:1.

**Referenz-Code:** `reference/page.tsx` und `reference/layout.tsx` aus dem ValetudiOS-Projekt — bloß die markierten Stellen (THEME, COPY, LAYOUT_ROTATION, SCREEN_IDS) anpassen, den Rest unverändert lassen.

---

## Grund-Entscheidungen (nicht neu diskutieren)

- **Tooling:** ParthJadhav/app-store-screenshots Kit + selbstgebauter `page.tsx`-Generator. Kein Figma, kein SwiftUI.
- **Design-Kanvas:** 1320×2868 (iPhone 6.9"). Apple skaliert auf kleinere Größen runter.
- **Source-Screenshots:** nativ aus iPhone 16 Pro Max Simulator (1320×2868). **NICHT** aus 6.1"-Device. Das Kit-README empfiehlt 6.1" um Doppelskalierung zu vermeiden — aber wenn du die Shots **direkt im Mockup** platzierst (wie im Reference-Template), ist nativ 6.9" besser.
- **Rendering:** html-to-image via Chrome. Firefox nicht (Font-Bugs).
- **Nur drei Layouts, sauber rotierend:** `headline-top` / `mock-left` / `mock-right`. Keine Podest-Spielerei, kein Querformat, kein Triple-Mock.

## Setup (einmalig, ~10 Min)

```bash
# 1. Skill-Installation (global für Claude Code)
npx -y skills add ParthJadhav/app-store-screenshots -a claude-code -y -g

# 2. Next.js-Projekt scaffolden (im Ziel-Ordner, z.B. StatFlow/AppStore/screenshots)
mkdir -p StatFlow/AppStore/screenshots
cd StatFlow/AppStore/screenshots
bunx --bun create-next-app@latest . --typescript --tailwind --app --src-dir --no-eslint --import-alias "@/*" --yes

# 3. html-to-image addieren, Kit-Mockup kopieren, Ordnerstruktur
bun add html-to-image
cp ~/.claude/skills/app-store-screenshots/mockup.png public/mockup.png
mkdir -p public/screenshots/de public/screenshots/en export/de export/en

# 4. Dev-Server starten (Port anpassen falls 3000 belegt)
bun dev --port 3333
```

Dann `src/app/layout.tsx` und `src/app/page.tsx` mit den Reference-Files überschreiben, danach THEME + COPY anpassen.

## Simulator vorbereiten

```bash
UDID=54C3BF3E-51E9-4EAA-8F11-B2AEC75BC2E9   # iPhone 16 Pro Max

xcrun simctl boot $UDID 2>/dev/null
open -a Simulator
xcrun simctl status_bar $UDID override \
  --time "9:41" \
  --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 \
  --batteryState charged --batteryLevel 100
```

UDID variiert pro Maschine — mit `xcrun simctl list devices available | grep "iPhone 16 Pro Max"` den aktuellen finden.

Statusbar-Override bleibt bis zum Simulator-Shutdown aktiv. Für EN-Shots App-Sprache wechseln über:
- Xcode-Scheme-Edit → Run → Options → App Language: English
- oder via `xcrun simctl launch $UDID <bundle-id> -AppleLanguages "(en)" -AppleLocale "en_US"`

Screenshot ziehen:
```bash
xcrun simctl io booted screenshot ~/Desktop/01-feature-de.png
```

## Gelernte Anti-Pattern (NICHT wiederholen)

1. **Export-Bug ignorieren** — html-to-image macht Unsinn wenn der DOM-Knoten unter `transform:scale` liegt (kleines Bild oben links in großem Canvas). **Fix:** Hidden full-size nodes (offscreen bei `left:-100000px`) rendern den Slide nativ, Export greift darauf zu. Preview ist eine zweite Scaled-Kopie nur zum Anschauen. Im Reference-Template so umgesetzt.

2. **Auto-Wrap vertrauen** — Browser bricht Headlines ungeplant ("Roboter\nfährt\nhin" statt "Roboter fährt hin."). **Fix:** `MultilineText`-Component das `\n` im String zu `<br/>` macht, **plus** `whiteSpace: "nowrap"` pro Zeile damit innerhalb einer Zeile nie gebrochen wird.

3. **Podest-Layout / Edge-Querformat** — Optisch wirken beide doof. Podest macht den Text zu tief, Edge kippt nur ein ohnehin portraitlastiges Device quer ohne Mehrwert. Weglassen.

4. **Skill-CLI interaktiv** — `npx skills add` hängt an Prompt ("Installation scope"). **Fix:** `-y -g` Flags immer setzen.

5. **Mock-Continuation über 3 Slides** — Die Idee "ein Device wandert durch drei App-Store-Slides" funktioniert nicht: User swipen unterschiedlich, Apple zeigt Padding zwischen Slides, A/B-Tests rotieren Reihenfolge.

6. **Source-Screenshots in falscher Auflösung** — Wenn du das Kit-Template ungecustomized nutzt, nimm 6.1" (1125×2436). Wenn du das Mockup selbst platzierst (wie im Reference-Template), nimm 6.9" nativ (1320×2868). Mischen ist die Hölle.

7. **Subline als Wurst** — "Meldung wenn fertig, wenn Hilfe gebraucht wird, wenn Material knapp wird." liest sich schlecht. **Besser:** 3 Satz-Fragmente, jeweils einzeln mit Punkt auf eigener Zeile:
   > Meldung, wenn fertig.
   > Wenn Hilfe gebraucht wird.
   > Wenn Material knapp wird.

8. **Mock-left/right Textbox zu schmal** — Bei 780px bricht "Roboter fährt hin." in vier Zeilen. **Fix:** Textbox mindestens 1050px breit. Erst dann reichen die `\n`-Umbrüche.

9. **Layout-Komplexität** — Drei Layouts reichen, mehr verwässert. Rotation so setzen dass alle drei Slides ein zentraler `headline-top`-Moment kommt.

10. **Ohne echte Screenshots zu committen** — Mit Placeholder ist das Layout-Tuning unvollständig. Du siehst Proportionen, aber nicht den finalen Eindruck. Trotzdem: Placeholder-Runde ist pflichtig, sonst verlierst du dich in Copy-Änderungen die später mit echten Shots sowieso revisited werden.

## Layout-Prinzipien (konkret)

- **`headline-top`** (zentraler Wow-Moment): Headline zentriert oben bei `top:220`, Mock zentriert unten bei `top:880` (ragt unten raus). Für das wichtigste Feature + regelmäßig alle 3 Slides als Rhythmus-Anker.
- **`mock-left`**: Mock 145% scaled, bei `left:-360, top:900`, leicht rotiert `-8deg`. Textbox rechts oben, 1050px breit, rechtsbündig.
- **`mock-right`**: Spiegelung von `mock-left`, Rotation `+8deg`. Textbox links oben, linksbündig.
- **Rotation:** `top, left, right, top, left, right, top, left, right` — alle drei Slides ein zentraler Moment, nie zwei identische Layouts hintereinander.
- **Background-Variante** (3 Blob-Positionen) rotiert `idx % 3` — gleiche Palette, unterschiedliche Dynamik pro Slide, scrollt lebendig statt monoton.
- **Headline-Größen:** 150px für multi-line Claims (headline-top), 140px für mock-left/right (weniger Platz).
- **Subline-Größen:** 76px im headline-top, 68px im mock-left/right.

## Copywriting-Regeln

- **Hybrid-Struktur:** Claim groß, Subline kleiner. Claim = 1-Sekunden-Botschaft, Subline = kurze Substanz.
- **Manuelle Umbrüche per `\n` im Source**, niemals Auto-Wrap vertrauen.
- **Sprachspezifisch, nicht 1:1 übersetzt** — EN darf anders klingen als DE. Beispiel aus ValetudiOS:
  - DE: "Einmal tippen. Roboter fährt hin."
  - EN: "Tap a spot. He's there." (nicht "Tap once. Robot goes there.")
- **Tonalität in einem Screen-Set konsistent** — entweder durchgehend Du, oder durchgehend Sie/neutral. Nicht mischen.
- **Pro Feature-Aufzählung max. 3 Items** — "Filter, Bürsten, Mop — sehen, was bald dran ist." funktioniert, 5 Items überfordern.
- **Claim + Subline dürfen sich nicht wiederholen** — Claim behauptet, Subline liefert Substanz. "Live dabei." / "Karte in Echtzeit — du siehst jeden Meter." gut. "Karte in Echtzeit." / "Echtzeit-Karte." schlecht.
- **Nicht lügen** — Features die (noch) buggy oder halbgar sind, nicht vermarkten. Bei ValetudiOS haben wir Manual Control, Siri und Widget bewusst ausgelassen.

## Design-Tokens

Pro Projekt aus Logo extrahieren (PIL pixel-sampling oder manuell mit Digital-Color-Meter):

```typescript
const THEME = {
  bgFrom: "#XXXXXX",     // heller Gradient-Pol
  bgTo: "#XXXXXX",       // dunkler Gradient-Pol
  blobLight: "#XXXXXX",  // Highlight-Blob (heller als bgFrom)
  blobMid: "#XXXXXX",    // meist == bgFrom
  blobDark: "#XXXXXX",   // meist == bgTo
  textPrimary: "#FFFFFF",
  textSecondary: "rgba(255,255,255,0.88)",
} as const
```

ValetudiOS-Werte zur Referenz (NICHT übernehmen für StatFlow):
- bgFrom `#56BDE3` (türkis)
- bgTo `#3B87F6` (blau)
- blobLight `#CEE7F6` (hellblau)

## Workflow

1. Scaffold + Simulator vorbereiten
2. `page.tsx` mit N Screens definieren (Copy-Dictionary DE+EN, Layout-Rotation, BG-Varianten-Index)
3. Placeholder-Screenshots in `public/screenshots/{de,en}/` (irgendein PNG als Dummy)
4. Dev-Server hochfahren, alle Slides ansehen, Copy + Layout iterieren bis es sitzt
5. Echte Source-Shots aus Simulator nachziehen, Dummy überschreiben
6. Chrome öffnen, pro Slide "Export PNG" klicken
7. Alle PNGs in `export/{de,en}/` sammeln, Auflösung mit `sips -g pixelWidth -g pixelHeight` validieren
8. App Store Connect Upload

## Was am Reference-Template anpassen

Nur vier Stellen:

1. **`THEME`** — Projekt-Farben aus Logo
2. **`COPY`** — Screen-IDs, Claims, Sublines in DE+EN
3. **`SCREEN_IDS`** — Reihenfolge und Anzahl der Screens (Apple erlaubt max. 10)
4. **`LAYOUT_ROTATION`** — welches Layout pro Screen (Mantra: `top, left, right`)

Der Rest (`MultilineText`, `Background`, `DeviceMockup`, `SlideCanvas`, Export-Logic, Hidden-full-size-Nodes-Pattern) ist projekt-agnostisch und funktioniert unverändert.

## Hinweis für den StatFlow-Agent

StatFlow ist eine Analytics-App (Umami-basierte Statistiken) — nicht Robot-Steuerung. Der visuelle Stil sollte **anders** sein als ValetudiOS:

- Möglicherweise dunkler Hintergrund (Dashboards wirken auf Dark Bases professioneller)
- Weniger verspielte Blobs, mehr geometrische Klarheit
- Zahlen und Charts als visueller Hook
- Typografie kann präziser/enger wirken
- Anderer Tonfall (analytisch, nicht kumpelhaft-warm)

Diese Entscheidungen gehören in die Discuss-Phase des StatFlow-Agents. Das Playbook hier gibt dir den **Prozess** und die **technische Basis**, nicht das Design.
