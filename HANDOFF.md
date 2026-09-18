# Handoff — Stand 18.09.2026, 23:20 Uhr

Übergabe aus einer langen Sitzung. Alles Genannte ist committet und gepusht;
das Arbeitsverzeichnis ist sauber.

---

## 1. Die offene Aufgabe: CI erzeugt bei jedem Lauf ein Zertifikat

**Das ist das zu lösende Problem.** Alles andere unten ist Kontext.

### Worum es geht

Der GitHub-Runner ist bei jedem Lauf eine frische Maschine ohne Zertifikat im
Schlüsselbund. Mit `-allowProvisioningUpdates` und automatischer Signierung
legt Xcode deshalb **bei jedem Build ein neues Development-Zertifikat** an.
Apple erlaubt zwei je Konto. Nach etwa zwei Release-Builds scheitert der
nächste mit:

```
error: Choose a certificate to revoke. Your account has reached the maximum number of…
error: No profiles for 'de.godsapp.statflow' were found
```

Die Meldung liest sich wie ein Profil-Problem, ist aber das Zertifikatslimit.

### Belege (gemessen, nicht vermutet)

| Zeitpunkt | Development-Zertifikate |
|---|---|
| 18.09. nachmittags | 11 → Build scheiterte |
| nach Widerruf von 9 | 2 |
| nach **einem** CI-Lauf | 3 |
| nach dem nächsten Lauf | **4** |

Konfi Quest und Plietsche Plünn nutzen dasselbe Muster, laufen aber seltener
und erzeugen ihr iOS-Projekt per `expo prebuild` — dort fiel es nie auf.

### Was bereits versucht wurde (und warum es scheiterte)

Commit `daa108c` stellte auf manuelle Signierung um und wurde mit `8e27cbe`
**zurückgenommen**. Der Ansatz war im Kern richtig — die Zertifikatszahl blieb
stehen —, scheiterte aber an einem Detail:

```
error: Provisioning profile "StatFlow AppStore 2026" has app ID "de.godsapp.statflow"
```

`PROVISIONING_PROFILE_SPECIFIER` wurde **global** gesetzt. Damit versucht Xcode,
auch das Widget mit dem App-Profil zu signieren; die Bundle-IDs passen nicht.

### Der richtige Weg

Die Profile müssen **pro Ziel** hinterlegt werden, nicht global — also in
`InsightFlow.xcodeproj/project.pbxproj` je Target:

| Target | Bundle-ID | Profil |
|---|---|---|
| `InsightFlow` | `de.godsapp.statflow` | `StatFlow AppStore 2026` |
| `InsightFlowWidgetExtension` | `de.godsapp.statflow.InsightFlowWidget` | `StatFlow Widget AppStore 2026` |

Beide Profile existieren bereits, sind `ACTIVE`, hängen am
Distribution-Zertifikat und tragen die richtigen Bundle-IDs — es muss nichts
Neues angelegt werden. UUIDs:
`8c65d623-7694-4ddf-ada1-79edd0d7cc64` (App),
`88103870-5a84-486c-bf58-fe760afeac9b` (Widget).

Im zurückgenommenen Commit steckt ein **funktionierendes** Skript
`.github/scripts/fetch-profiles.sh`, das beide Profile aus App Store Connect
lädt (JWT mit openssl, ohne Fremdbibliothek, lokal gegen die echte API
geprüft). Es lässt sich mit `git show daa108c -- .github/scripts/` wiederholen.

**Zusätzlich umzustellen:** Der Export-Schritt braucht `signingStyle: manual`
plus `provisioningProfiles`-Zuordnung je Bundle-ID in der ExportOptions-Plist.
Auch das steht im zurückgenommenen Commit.

### Achtung beim Arbeiten daran

- Es ist der **einzige** Release-Weg. Ein Fehler blockiert alle Store-Uploads.
- Nach jedem Versuch die Zertifikate zählen — steigt die Zahl, greift der
  Umbau nicht.
- Die Build-Nummer muss vor jedem Lauf erhöht werden, sonst lehnt Apple den
  Upload mit `ENTITY_ERROR.ATTRIBUTE.INVALID.DUPLICATE` ab.
- Lokale Builds sind wegen macOS-Beta nicht brauchbar (ITMS-90111), es muss
  über die CI gehen.

---

## 2. App-Stand: Version 2.2.0

### In TestFlight (alle VALID)

| Build | Inhalt |
|---|---|
| 23 | Umami-3.4-Routen mit Versionsweiche, Vermerke-Liste |
| 24 | + Anmeldung per API-Schlüssel bei eigenen Instanzen |
| 25 | + Vermerke als Marken im Diagramm |
| 26 | + Marke rastet auf den richtigen Datenpunkt ein |
| 27 | + Symbol sichtbar, Uhrzeit frei wählbar, Notiz → Liste |
| **28** | + Knopfgröße an den Diagramm-Umschalter angeglichen |

**Build 28 ist der aktuelle Teststand.** 126 Tests, keine Fehlschläge.

### Was in 2.2.0 steckt

- **Umami 3.4**: Ziele, Trichter, Wiederkehr, Pfade, Zuordnung und Ladezeiten
  laufen über die neuen GET-Routen. Die App erkennt selbst, was der Server
  kann (Prüfpunkt `performance/stats`: 200 = neu, 404 = alt). Ältere Server
  werden unverändert bedient.
- **Vermerke** (Annotations): Marken im Diagramm, Notiz beim Antippen, Knopf
  zum Anlegen, eigene Liste unter den Auswertungen.
- **API-Schlüssel** für eigene Instanzen — umgeht 2FA, läuft nicht ab. Das
  Widget arbeitet damit ebenfalls (gemessen).
- **Behoben**: hängender Ladekreis beim Verlassen der Website-Ansicht;
  grauer Anmeldeknopf bei Umami Cloud trotz eingetragenem Schlüssel.

### Noch offen bei der App

- **2.1.0 steht auf `WAITING_FOR_REVIEW`.** 2.2.0 kann erst eingereicht
  werden, wenn das durch ist.
- Beim Testen von Build 28 prüfen, ob Diagramm-Marken und Plus-Knopf so
  sitzen, wie gedacht.

---

## 3. Weitere offene Punkte

### Dringend: Distribution-Zertifikat läuft ab

**28.11.2026** — das sind noch rund 70 Tage. Daran hängen CI und alle
Store-Uploads. Die Provisioning-Profile laufen am selben Tag ab. Rechtzeitig
erneuern, sonst steht die Auslieferung.

### Secrets erneuern

Im Chat-Verlauf stehen und sollten ersetzt werden:
- API-Schlüssel der Umami-Instanz (`umami_BVGZ…`)
- TOTP-Secret für die 2FA von t.godsapp.de (liegt in `secrets.env` unter
  `UMAMI_TOTP_SECRET`)

### Umami-Patch verloren

`t.godsapp.de` läuft seit 18.09. auf offiziellem **3.4.0**. Der selbstgebaute
`unit`-Patch (PR umami-software/umami#4455, weiterhin offen) ging dabei
verloren. Folge: `unit` wird an `/api/websites/charts` ignoriert, die App lädt
die Verläufe einzeln — nichts bricht, das Dashboard baut sich nur langsamer
auf (laut PR-Messung 5,6 s statt 0,6 s bei 18 Websites). Gepatchter Quellcode
liegt unter `/opt/stacks/umami-patch/src` und müsste auf 3.4.0 portiert
werden.

Backup vor dem Upgrade:
`/opt/backups/umami-vor-3.4.0-20260918-1659.sql.gz` (7,6 MB).

### Wartungscheck erweitert

Neues Modul `~/.claude/skills/maintenance-check/references/apple-dev.md`,
auslösbar über „check apple". Zählt Zertifikate, warnt vor Ablauf, sieht nach
hängenden Builds. Committet in `~/claude-config`.

---

## 4. Nützliche Befehle

```bash
# Zertifikate zählen (nach jedem CI-Lauf sinnvoll)
source ~/.claude/secrets.env
~/.claude/secrets/asc-jwt.sh get \
  "/v1/certificates?limit=100&fields%5Bcertificates%5D=certificateType" \
  | python3 -c 'import sys,json;from collections import Counter;print(Counter(r["attributes"]["certificateType"] for r in json.load(sys.stdin)["data"]))'

# Builds bei Apple
~/.claude/secrets/asc-jwt.sh get \
  "/v1/builds?filter%5Bapp%5D=6761671122&limit=3&sort=-uploadedDate&fields%5Bbuilds%5D=version,processingState"

# CI starten (Build-Nummer vorher erhöhen!)
gh workflow run ios-release.yml --ref main
```

**Fallstrick:** Eckige Klammern in Query-Parametern müssen als `%5B`/`%5D`
kodiert werden, sonst bricht curl mit „bad range in URL" ab.
