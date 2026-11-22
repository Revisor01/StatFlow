# Was bei welchem Server geht

Stand: November 2026. Die Angaben unter „zuletzt geprüft" bezeichnen die
Versionen, gegen deren laufende Instanzen sämtliche Abfragen der App zuletzt
durchgespielt wurden. Gegen 3.5.0 sind am 17.11.2026 Anmeldung (mit und ohne
Bestätigung in zwei Schritten), Konto, Website-Liste und Kennzahlen geprüft,
noch nicht alle Auswertungen.

| Anbieter | Nötig | Zuletzt geprüft |
|----------|-------|-----------------|
| **Umami** | ab 3.0, selbst betrieben oder Cloud | 3.3.0, 3.4.0, 3.4.1; 3.5.0 teilweise |
| **Plausible** | ab CE 2.1 oder Cloud | CE 3.2.1 |

## Umami

Ab Version 3 liefert `/api/websites/{id}/stats` flache Werte plus `comparison`.
Umami 2.x antwortet in einem anderen Format und wird nicht unterstützt.
Segmente, Ladezeiten (Web Vitals), Besuchszeiten und Umsatz gibt es ebenfalls
erst ab 3.0, die Anmeldung mit Bestätigung in zwei Schritten ab 3.3.

### Was sich mit 3.4 geändert hat

Ziele, Trichter, Wiederkehr, Pfade, Zuordnung und Ladezeiten sind auf
`GET /api/websites/{id}/…` umgestellt. Die früheren `POST /api/reports/…`
bleiben über eine Kompatibilitätsschicht erreichbar.

Die App fragt einmal `performance/stats` ab: Antwort 200 heißt neue Adressen,
404 heißt alte. Die angezeigten Zahlen sind in beiden Fällen dieselben. Einzige
Abweichung: die Wiederkehr-Auswertung richtet die Tagesgrenzen ab 3.4 nach der
Zeitzone des Geräts statt nach UTC.

**Vermerke** (`/api/websites/{id}/annotations`) gibt es erst ab 3.4. Auf
älteren Servern zeigt die App dort einen Hinweis statt einer leeren Liste.
Anlegen, Ändern und Löschen verlangen serverseitig das Bearbeitungsrecht an der
Website; mit reinem Leserecht bleiben Vermerke sichtbar, aber unveränderlich.

**Anmeldung per API-Schlüssel** (Umami → Einstellungen → API-Schlüssel) ist
ebenfalls ab 3.4 möglich. Der Schlüssel geht wie ein Anmelde-Token als
`Authorization: Bearer …` mit, umgeht die Bestätigung in zwei Schritten und
läuft nicht ab. Die Admin-Routen (`/api/admin/…`) sind für Schlüssel gesperrt;
die App ruft sie nicht auf.

### Was sich mit 3.5 ändert

Die Datenrouten antworten unverändert. Drei Dinge fängt die App ab:

- **Pflicht zur Bestätigung in zwei Schritten.** Verlangt der Server sie, ist
  sie für das Konto aber noch nicht eingerichtet, gibt der Login ein Token aus,
  mit dem jede andere Route `403` mit `two-factor-error-setup-required`
  liefert. Die App prüft das direkt nach dem Login an `/api/me` und verweist
  auf die Einrichtung in der Weboberfläche. API-Schlüssel sind davon nicht
  betroffen.
- **Standardpasswort.** `passwordChangeRequired` im Login-Ergebnis führt zu
  einem Hinweis im Dashboard. Ältere Server senden das Feld nicht.
- **Cohorts mit abgeschaffter Aktion** (weder Seite noch Ereignis) lassen jede
  Abfrage mit `500` scheitern. Die App meldet das und bietet an, ohne Cohort
  weiterzuarbeiten.

Den neuen Parameter `period` nutzt die App nicht: Server vor 3.5 verlangen
`startAt`/`endAt`, und eine Versionsabfrage gibt es nicht. Zudem rechnet der
Server anders: Die Woche beginnt nach `en-US` am Sonntag, `7d` zählt rollend
ab jetzt. Die App beginnt die Woche am Montag und zählt ganze Kalendertage.

### Umami Cloud

Cloud kennt `POST /api/auth/login` nicht — der Endpunkt antwortet dort mit 404.
Stattdessen wird der Schlüssel aus den Kontoeinstellungen (Einstellungen → API
keys) gegen die Basisadresse `https://api.umami.is/v1` gesendet. Jeder Schlüssel
ist auf 50 Aufrufe je 15 Sekunden begrenzt.

### Bekannte Stolperstelle

Umami 3.3 bricht den Login, wenn für das Konto die Bestätigung in zwei
Schritten aktiv ist. Wer davon betroffen ist, kommt über einen API-Schlüssel
hinein (ab 3.4).

## Plausible

Erst ab CE 2.1 gibt es die Query-API `POST /api/v2/query`. Für Echtzeitdaten
kommt zusätzlich `GET /api/v1/stats/realtime/visitors` dazu. Die Stats-API v1
ist als „legacy" markiert, in CE 3.2 aber weiterhin da; ein Abschalttermin ist
nicht angekündigt.

### Was die Community Edition nicht kann

- **Websites anlegen und löschen, Ziele verwalten, Share-Links erzeugen** laufen
  über `/api/v1/sites…`. Diese Routen sind Cloud und Enterprise vorbehalten; auf
  CE-Servern meldet die App sie als nicht verfügbar. Übersicht, Diagramme und
  alle Statistiken funktionieren dort uneingeschränkt.
- **Umsatzkennzahlen** (`total_revenue`, `average_revenue`) lehnt die Community
  Edition als unbekannte Metrik ab.
- **Trichter und Segmente** sind über die API gar nicht erreichbar — sie laufen
  ausschließlich über interne Routen mit Cookie-Anmeldung, nicht über den
  API-Schlüssel.

## Was es nur bei Umami gibt

Trichter, Ziele, Zuordnung, Sitzungen und Journeys existieren bei Plausible
nicht. Die App blendet diese Bereiche dort aus, statt leere Listen zu zeigen.
Umgekehrt kennt Plausible die Scrolltiefe und Verhaltensfilter, die Umami nicht
hat.
