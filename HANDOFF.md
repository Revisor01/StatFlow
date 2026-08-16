# Handoff — Stand 16. August 2026, abends

**StatsFlow 2.0.0 ist bei Apple in der Review** (abgesendet 20:50 Uhr, Build 17).
Veröffentlichung erfolgt automatisch nach der Freigabe.

---

## 1. Was als Nächstes ansteht

**Auf die Freigabe warten.** Danach:

1. GitHub-Release zu `v2.0.0` anlegen (Tag ist gesetzt, Release fehlt noch).
2. Prüfen, ob die Veröffentlichung durchgelaufen ist.

Wird die Version **abgelehnt**, sind die wahrscheinlichsten Gründe:

- Das Demokonto funktioniert nicht (siehe Abschnitt 4) — dann Zugang prüfen.
- Leere Diagramme werden als Fehler gewertet. In den Review-Hinweisen steht
  bereits, dass die Demo-Website noch keine Messdaten hat.

---

## 2. Was in dieser Sitzung entstanden ist

| Commit | Inhalt |
|---|---|
| `8755019` | Zweiter Faktor auch beim Hinzufügen weiterer Konten |
| `c7747db` | Websites aus Umami-Teams (die Hauptneuerung) |
| `486a313` | Fünf Fehler aus einer unabhängigen Prüfung |
| `6ec9ff0` | Build-Nummer 17 |

### Teams — warum es nötig war

Die App las nur `api/websites`, also die persönlichen Websites. Wer seine
Websites in Umami-Teams organisiert, sah in der App nichts davon, obwohl
Umamis Oberfläche sie zeigt.

**Die Falle dabei:** `api/me/websites?includeTeams=1` sieht nach dem richtigen
Weg aus, filtert Team-Websites aber auf Eigentümer und Verwalter. Mitglieder
und Nur-Lesen sehen dort nichts. Richtig ist der Weg über `api/me/teams` und
`api/teams/{teamId}/websites` — genau den nimmt auch Umamis Oberfläche.

Für Zugriff genügt **jede** Team-Mitgliedschaft, auch „nur lesen": Sowohl die
Website-Liste als auch alle Zahlen (`stats`, `pageviews`, `charts`) prüfen nur,
ob eine Mitgliedschaft existiert.

### Die Prüfung hat fünf Fehler gefunden

Am wichtigsten: **`api/websites` lieferte ohne `pageSize` nur 20 Einträge.**
Team-Listen wurden vollständig geladen, die eigenen gekappt — ausgerechnet die
Fehlerklasse, die der Teams-Commit beheben sollte. Betraf App und Widget.

Außerdem: fehlendes `orderBy` beim Blättern (Team-Listen haben serverseitig
keine Standardsortierung, Einträge konnten doppelt oder gar nicht ankommen),
stumm verschluckte Fehler samt Cache-Überschreiben, doppelte Kennungen im
Alle-Konten-Modus, und sequentielle Team-Abrufe im Widget.

---

## 3. Offener Punkt für 2.1

**Reentrancy am geteilten Actor.** `UmamiAPI` ist ein Singleton-Actor, der pro
Konto umkonfiguriert wird (`configureProviderForAccount` → Keychain →
`reconfigureFromKeychain`). Laufen Dashboard und Benachrichtigungen gleichzeitig,
kann ein Abruf mitten im Ladevorgang die Zugangsdaten eines anderen Kontos
erwischen.

Das Muster wurde experimentell bestätigt (Swift-Nachbau: der Effekt tritt
reproduzierbar auf). **Aber:** Es müssen vier Bedingungen zusammentreffen —
mindestens zwei Umami-Konten, aktive Benachrichtigungen (sonst bricht
`scheduleAllNotifications` vorher ab), ein gleichzeitiger Ladevorgang und eine
zeitliche Überschneidung im Millisekundenbereich. Der Alle-Konten-Modus ist
zudem `@State` ohne Persistenz und beim Start immer aus.

Folge wäre eine Website-Liste mit Einträgen des falschen Kontos, unter falscher
Kennung zwischengespeichert. Kein Datenverlust, heilt sich beim nächsten Laden.

**Saubere Lösung:** Zugangsdaten pro Anfrage mitgeben statt im Actor halten.
Berührt jede Methode des API-Dienstes — eigene Version, ordentlicher Test.

---

## 4. Server (t.godsapp.de)

**Achtung: Dort läuft ein selbstgebautes Image**, nicht das offizielle:
`umami-patched:charts-unit` statt `ghcr.io/umami-software/umami:3.3.0`.
Gewollt, damit die Stundenwerte getestet werden können.

**Zurück auf offiziell:** Im Portainer-Stack `umami` (ID 237, Environment 1) das
Image ändern und neu deployen. Datenbank bleibt unberührt, Backup-Config liegt
als `/opt/stacks/umami/docker-compose.yml.bak-3.3.0`.

### Für die App-Review angelegt — nicht löschen

- **Team „App Review"** (`1b0f1224-1cbf-4a0c-bf64-e6022fec2930`)
- **Website „App Review Demo"** (`demo.statsflow.app`) in diesem Team
- **Konto `appreview`** / `ReviewVgwEMLE7NL`, Rolle `team-view-only`, **ohne 2FA**

Das ist das Demokonto in den Review-Hinweisen. Es hat bewusst keine eigenen
Websites — seine einzige Website kommt über das Team. Nach der Freigabe kann
alles bleiben (für künftige Reviews) oder weg.

### 2FA-Schlüssel — nicht verlieren

Umami 3.3 braucht `TWO_FACTOR_ENCRYPTION_KEY` (64 Hex-Zeichen), sonst schlägt
das Einrichten von 2FA fehl. Der Schlüssel steht in der Stack-Config und als
`UMAMI_TWO_FACTOR_KEY` in `~/.claude/secrets.env`. **Geht er verloren, sind alle
eingerichteten zweiten Faktoren unbrauchbar** — auch Simons eigener.

Das Konto `admin` hat 2FA aktiv (seit 16.08.). Für API-Zugriffe braucht es also
einen TOTP-Code; `appreview` kommt ohne aus.

### Offener Sicherheitspunkt

Auf der Instanz existiert ein **zweites Admin-Konto `fnxnxnc`** (angelegt
13.12.2025, keine eigene Website, kein 2FA). Herkunft ungeklärt. Falls nicht
selbst angelegt: prüfen und ggf. löschen.

---

## 5. Upstream-PR bei Umami

**https://github.com/umami-software/umami/pull/4455** — offen, `MERGEABLE`,
Ziel-Branch `dev`. Fügt `/api/websites/charts` einen `unit`-Parameter hinzu.

**Wichtig: Der Commit läuft auf `Revisor01 <mail@simonluthe.de>` und enthält
bewusst keinerlei Hinweise auf KI-Unterstützung.** Bei künftigen Änderungen
beibehalten.

Review-Bot Greptile: 4/5, ein berechtigter Punkt (stilles Kappen bei zu großen
Zeiträumen) wurde behoben. Von menschlichen Maintainern noch keine Reaktion.
Wahrscheinlichste Rückfrage: den PR aufteilen (ein Feature + drei Bugfixes).

---

## 6. Erkenntnisse, die Zeit sparen

**Export nach TestFlight scheitert an Homebrews rsync.** Xcode ruft rsync mit
`-E` auf, das die Homebrew-Version nicht kennt. Fehlermeldung ist nur
„Copy failed". Deshalb mit Apples Variante bauen:

```bash
set -a && source ~/.claude/secrets.env && set +a
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

**`secrets.env` exportiert nicht.** Die Variablen stehen ohne `export`, sind
also nur Shell-Variablen und erreichen Python nicht. Immer
`set -a && source ~/.claude/secrets.env && set +a` nutzen.

**Die ASC-API schluckt Parameter still.** `sort` bei `/v1/apps/{id}/builds`
liefert eine leere Liste, `fields[builds]=…` ebenfalls, und `include=` bei
Builds auch. Ohne diese Parameter abfragen und in Python filtern.

**Neue Builds brauchen 1–2 Minuten**, bis sie in der API auftauchen. Vorher
liefert die Abfrage schlicht nichts — kein Fehler, keine Meldung.

**Version umbenennen statt neu anlegen:** Solange eine Version in ASC noch
`PREPARE_FOR_SUBMISSION` ist, lässt sich `versionString` per PATCH ändern. So
bleiben die eingetragenen Texte erhalten (1.1.0 → 2.0.0 lief so).

**Die Nullen-Falle bei `/api/websites/charts`** (unverändertes Umami 3.3.0):
HTTP 200 und lauter Nullen in `values`, während `total` korrekt bleibt — wenn
`timezone` oder `unit` fehlt oder `startAt` nicht auf einer Bucket-Grenze liegt.

**Umami schließt `event_type` 2 und 5 aus** (customEvent und performance), nicht
2 und 3. Bei SQL-Gegenproben beachten.

**Metrik-Typen heißen in Umami 3 anders:** `path` statt `url`, `hostname` statt
`host`. UTM-Typen sind camelCase (`utmSource`), Rohfelder snake_case.

**`docker compose` gibt es auf dem Server nicht** — nur das eigenständige
`docker-compose`, das teilweise mit der neuen Docker-Version kollidiert
(`KeyError: 'ContainerConfig'`). Im Zweifel `docker run` oder Portainer.

**Bot-Traffic:** Plausible zählt Besucher, die Umami herausfiltert (Chrome auf
Desktop-Linux, nur Startseite, keine Folgeklicks). Beide zählen korrekt, sie
beantworten nur leicht unterschiedliche Fragen. Bei kleinen Zahlen fällt der
Unterschied stark auf.
