# Handoff — Stand 16. August 2026

Arbeitsstand nach einer langen Sitzung zu Umami 3.3.0. Vier Stränge: App,
Server, Homepages, Upstream-PR.

---

## 1. Was als Nächstes ansteht

**Simon testet Build 13 in TestFlight.** 2FA ist eingerichtet und der Login
damit erfolgreich durchgespielt — der Punkt ist erledigt.

Danach: **StatsFlow 1.1.0 in den App Store einreichen.** Alle Texte sind
fertig, Screenshots werden bewusst nicht erneuert.

### Zuerst: Build 14 bauen

Nach Build 13 kam noch ein Fix am Abmelden (`e94d263`), der **in keinem
TestFlight-Build enthalten ist**. Vor dem Einreichen also:

1. `CURRENT_PROJECT_VERSION` in `InsightFlow.xcodeproj/project.pbxproj`
   auf `14` setzen (4 Stellen).
2. Archivieren, exportieren, hochladen. **Wichtig:** Der Export scheitert
   sonst an Homebrews rsync — deshalb mit Apples Variante bauen:
   ```bash
   PATH="/usr/bin:/bin:/usr/sbin:/sbin" xcodebuild -exportArchive …
   ```
   Vollständiger Ablauf siehe Abschnitt 6.
3. Abmelden einmal am Gerät prüfen: abmelden → App beenden → neu starten.
   Es darf **kein** Konto mehr da sein.

### Dann einreichen

1. `CHANGELOG.md`: `## [Unreleased] - 1.1.0` → `## [1.1.0] - <Datum>`.
2. Tag `v1.1.0` setzen.
3. Version 1.1.0 in App Store Connect anlegen, Texte setzen, Build 14
   zuordnen, absenden. Ablauf siehe Skill `mobile-store-apis`.
4. **7 Commits im StatFlow-Repo sind noch nicht gepusht**
   (`git log origin/main..HEAD`).

### Release-Texte

Fertig auf Deutsch und Englisch, je ~1750 Zeichen:
`/private/tmp/claude-501/-Users-simonluthe-Documents-statflow/27eb3d5c-1374-4938-849a-072b051fd685/scratchpad/release-notes-1.1.0.md`

Liegt im Scratchpad und ist damit vergänglich — bei Bedarf neu schreiben, die
Inhalte stehen alle im CHANGELOG unter 1.1.0.

Einreichen heißt: Version 1.1.0 in App Store Connect anlegen, Texte setzen,
Build 13 zuordnen, absenden. Ablauf siehe Skill `mobile-store-apis`.

---

## 2. StatsFlow (dieses Repo)

**Build 13 liegt in TestFlight, Status VALID.** Version 1.1.0, gebaut aus
`fbdfc72`. In App Store Connect ist aktuell 1.0.6 live; eine 1.1.0 existiert
dort noch nicht.

Vier Änderungen dieser Sitzung:

| Commit | Inhalt |
|---|---|
| `3155699` | Umami-3.3-Login mit Bestätigung in zwei Schritten |
| `79a263e` | Verlaufsdaten aller Websites in einer Anfrage |
| `fbdfc72` | Batch auch für Heute/Gestern, Rechenfehler entfernt |
| `452db93` | Build-Nummer 13 |
| `e94d263` | Abmelden entfernt die Konten jetzt tatsächlich (**noch in keinem Build**) |

### Warum der 2FA-Teil nötig war

Umami 3.3 antwortet bei aktivem 2FA weiterhin mit **HTTP 200**, liefert aber
`{requiresTwoFactor, partialToken}` statt `{token, user}`. Der alte Client
dekodierte stur auf `token` und meldete fälschlich „Anmeldung fehlgeschlagen".
Einlösung über `POST /api/2fa/verify`.

### Wie der Batch-Abruf funktioniert

Die App schickt `unit` immer mit und erkennt **an der Anzahl der zurückkommenden
Werte**, ob der Server ihn auswertet:

- Server ohne Patch → 2 Werte für „Heute" → App fällt auf Einzelabrufe zurück
- Server mit Patch → 24 Werte → App nutzt den Batch

Damit läuft die App gegen jede 3.3.0-Instanz, und sobald der Upstream-PR
angenommen ist, greift die schnellere Variante **automatisch** — ohne
App-Update.

Gemessen: 18 Websites, einzeln 5,58 s → gebündelt 0,59 s.

### Verifiziert gegen beide Servervarianten

Unverändertes 3.3.0 und gepatchte Instanz parallel auf derselben Datenbank,
identische Zahlen: Heute liefern beide Wege 4 Sitzungen.

### Widget und Vergleichsansicht

Bewusst **nicht** geändert. Beide laden nur *eine* Website; der Batch bündelt
Websites, nicht Zeiträume. Beide nutzen bereits `/pageviews` mit korrektem
`unit` und waren vom Rechenfehler nie betroffen.

---

## 3. Server (t.godsapp.de)

**Achtung: Dort läuft aktuell ein selbstgebautes Image**, nicht das offizielle.

```
umami: umami-patched:charts-unit    (statt ghcr.io/umami-software/umami:3.3.0)
```

Das ist gewollt, damit die Stundenwerte in StatsFlow getestet werden können.

**Zurück auf offiziell:** Im Portainer-Stack `umami` (ID 237, Environment 1)
das Image auf `ghcr.io/umami-software/umami:3.3.0` ändern und neu deployen. Die
Datenbank bleibt unberührt; eine Backup-Config liegt als
`/opt/stacks/umami/docker-compose.yml.bak-3.3.0`.

Der gepatchte Quellcode liegt auf dem Server unter `/opt/stacks/umami-patch/src`,
das Image heißt `umami-patched:charts-unit` (953 MB).

**Zugangsdaten** stehen in `~/.claude/secrets.env` (`UMAMI_URL`, `UMAMI_USER`,
`UMAMI_PASS`). Self-hosted Umami kennt keine API-Token — es sind dieselben
Zugangsdaten wie im Browser.

### 2FA-Schlüssel — nicht verlieren

Umami 3.3 braucht `TWO_FACTOR_ENCRYPTION_KEY` (64 Hex-Zeichen), sonst schlägt
das Einrichten von 2FA mit „error" fehl, ohne QR-Code. Der Schlüssel steht in
der Stack-Config und als `UMAMI_TWO_FACTOR_KEY` in `~/.claude/secrets.env`.

**Geht er verloren, sind alle eingerichteten zweiten Faktoren unbrauchbar** —
auch Simons eigener. Bei einem Serverumzug unbedingt mitnehmen.

Nebenbefund: 2FA ist auf der Instanz **global erzwungen**
(`isRequired: true, requiredReason: "global"`). Das betrifft auch das
ungeklärte Konto `fnxnxnc`.

### Offener Sicherheitspunkt

Auf der Instanz existiert ein **zweites Admin-Konto `fnxnxnc`** (angelegt
13.12.2025, keine eigene Website, kein 2FA). Herkunft ungeklärt. Falls nicht
selbst angelegt: prüfen und ggf. löschen.

---

## 4. Homepages — erledigt

Heatmap-Messung aktiv auf **simonluthe.de** und **juliansengelmann.de**.
Beide Repos gepusht, deployed, Tags gesetzt (`v1.3.1` bzw. `v1.1.0`).

Serverseitig: nur `heatmapEnabled`, **Session-Replay bewusst aus**,
`maskLevel: strict`. Es werden ausschließlich Klick- und Scroll-Positionen
erfasst, keine Sitzungsvideos. 2 von 18 Websites betroffen; Konfi-Quest wurde
bewusst ausgelassen (Nutzer sind Jugendliche).

Daten entstehen erst ab Einbau — rückwirkend gibt es nichts. Nach ein paar
Tagen sollte auf simonluthe.de etwas zu sehen sein.

---

## 5. Upstream-PR bei Umami

**https://github.com/umami-software/umami/pull/4455** — offen, kein Entwurf,
`MERGEABLE`, Ziel-Branch `dev`.

Fügt `/api/websites/charts` einen `unit`-Parameter hinzu und behebt drei Bugs,
die beim Bauen aufgefallen sind. Ohne `unit` bleibt das Verhalten unverändert.

Fork: `github.com/Revisor01/umami`, Branch `feat/website-charts-unit`,
Commit `9b2e1f6`. Lokal unter
`…/27eb3d5c-…/scratchpad/umami-fork` (Scratchpad, vergänglich — bei Bedarf neu
klonen).

**Wichtig: Der Commit läuft auf `Revisor01 <mail@simonluthe.de>` und enthält
bewusst keinerlei Hinweise auf KI-Unterstützung.** Das bitte bei künftigen
Änderungen beibehalten.

### Bisherige Reaktionen

Ein Review-Bot (Greptile) hat mit **4/5** bewertet und einen berechtigten
Punkt gefunden: Bei zu großen Zeiträumen wurde still gekappt, wodurch `values`
und `total` sich widersprachen. Behoben — die Route lehnt jetzt mit 400 ab,
statt zu kappen. Antwort ist im PR gepostet.

Von menschlichen Maintainern noch keine Reaktion.

### Falls Änderungen verlangt werden

Wahrscheinlichste Rückfrage: **den PR aufteilen** (ein Feature + drei Bugfixes
in einem PR). Das Angebot dazu steht bereits im PR-Text.

Zweiter Diskussionspunkt: der interne `'default'`-Sentinel. Ein Reviewer könnte
einen expliziten `bucketHours`-Parameter bevorzugen — dagegen spricht nichts.

19 Tests, jeder mit Gegenprobe abgesichert (Fix zurückdrehen → Test wird rot).

---

## 6. Erkenntnisse, die Zeit sparen

**Export nach TestFlight scheitert an Homebrews rsync.** Xcode ruft rsync mit
`-E` auf, das die Homebrew-Version 3.5.0 nicht kennt. Fehlermeldung ist nur
„Copy failed", was in die Irre führt. Der vollständige Ablauf, der
funktioniert hat:

```bash
source ~/.claude/secrets.env
xcodebuild -project InsightFlow.xcodeproj -scheme InsightFlow \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath /tmp/statflow.xcarchive archive

# ExportOptions.plist: method=app-store-connect, uploadSymbols=true,
# manageAppVersionAndBuildNumber=false
PATH="/usr/bin:/bin:/usr/sbin:/sbin" xcodebuild -exportArchive \
  -archivePath /tmp/statflow.xcarchive \
  -exportOptionsPlist /tmp/ExportOptions.plist \
  -exportPath /tmp/statflow-export \
  -authenticationKeyPath "$APP_STORE_CONNECT_KEY_PATH" \
  -authenticationKeyID "$APP_STORE_CONNECT_KEY_ID" \
  -authenticationKeyIssuerID "$APP_STORE_CONNECT_ISSUER_ID"

PATH="/usr/bin:/bin:/usr/sbin:/sbin" xcrun altool --upload-app \
  -f /tmp/statflow-export/InsightFlow.ipa -t ios \
  --apiKey "$APP_STORE_CONNECT_KEY_ID" \
  --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"
```

Der `sort`-Parameter der ASC-API liefert bei `/v1/apps/{id}/builds` still eine
leere Liste — ohne `sort` abfragen und in Python sortieren.

**Die Nullen-Falle bei `/api/websites/charts`** (im unveränderten Umami 3.3.0):
Der Endpunkt liefert HTTP 200 und lauter Nullen in `values`, während `total`
korrekt bleibt — wenn `timezone` oder `unit` fehlt oder `startAt` nicht auf
einer Bucket-Grenze liegt. Kein Fehlercode, nichts im Log.

**Umami schließt `event_type` 2 und 5 aus** (customEvent und performance),
nicht 2 und 3. Bei SQL-Gegenproben beachten, sonst zählt man falsch.

**Metrik-Typen heißen in Umami 3 anders:** `path` statt `url`, `hostname` statt
`host`. UTM-Typen sind camelCase (`utmSource`), obwohl die Rohfelder
snake_case heißen.

**`docker compose` gibt es auf dem Server nicht** — nur das eigenständige
`docker-compose`, und das kollidiert teilweise mit der neuen Docker-Version
(`KeyError: 'ContainerConfig'`). Im Zweifel `docker run` direkt nutzen oder
über Portainer gehen.

Eine ausführliche API-Übersicht (40+ Endpunkte, live geprüft) liegt als
Artefakt vor: https://claude.ai/code/artifact/0f43fd85-3278-49fb-a06c-5957e32203dc
