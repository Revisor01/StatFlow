# Changelog

Alle nennenswerten Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

Das Format basiert auf [Keep a Changelog 1.1.0](https://keepachangelog.com/de/1.1.0/),
und dieses Projekt folgt [Semantic Versioning 2.0.0](https://semver.org/lang/de/).

Die App hieß in ihrer Entwicklungsgeschichte zunächst *InsightFlow*, dann *PrivacyFlow*
und trägt seit März 2026 den Namen **StatFlow** — im App Store als *StatsFlow*, da der
kürzere Name dort bereits vergeben war. Der Xcode-Zielname `InsightFlow` ist aus dieser
Historie erhalten geblieben.

Die Versionen 1.0 bis 1.0.6 sind die im App Store ausgelieferten Releases. Die Versionen
0.1.0 bis 1.3.0 stammen aus der Vorgeschichte als InsightFlow bzw. PrivacyFlow, vor der
ersten Store-Veröffentlichung.

## [Unreleased] - 1.0.7

### Hinzugefügt

- Screenshots im README (`docs/screenshots/`).
- Übersicht der unterstützten Server-Versionen von Umami und Plausible samt bekannter
  Einschränkungen in der Dokumentation.

### Behoben

- Widgets zeigten bei Umami dauerhaft null aktive Besucher an.
- Widgets und App konnten für denselben Zeitraum unterschiedliche Zahlen anzeigen, weil die
  Zeitzone des Geräts nicht überall berücksichtigt wurde.
- Funktionen, die es auf selbst gehosteten Plausible-Servern nicht gibt (Websites anlegen,
  Ziele verwalten, Share-Links), melden das jetzt verständlich statt mit einem Serverfehler.

### Entfernt

- App-Store-Grafiken und Screenshot-Generator aus dem Repository entfernt. Die Grafik-Erstellung
  läuft jetzt zentral über `~/Documents/social-posts-studio` (Projekt `statflow`); Secrets liegen
  in `~/.claude/secrets/`.
- Ordner `app-store-screenshots-playbook/` entfernt — durch die zentrale Grafik-Werkstatt ersetzt.
- Duplizierte App-Icon-Dateien (`AppIcon1.png`, `AppIcon2.png`, `AppIcon3.png`) aus dem
  Repository-Root entfernt — identische Originale liegen unter `InsightFlow/Resources/`.

## [1.0.6] – 2026-07-21

Bugfix-Release auf Basis von Nutzerrückmeldungen (Build 7).

### Behoben

- Löschen einer Umami-Website erfordert jetzt die Eingabe des Website-Namens als Bestätigung.
- Report-Attribution zeigt alle Quellen an und dedupliziert UTM-Parameter korrekt.
- Ausgewählter Zeitraum bleibt beim erneuten Öffnen einer Ansicht erhalten.
- Texte der Zusammenfassungs-Benachrichtigungen werden lokalisiert statt fest auf Deutsch ausgegeben.
- Leere Event-Properties auf dem Umami-Detailscreen behoben.

## [1.0.5] – 2026-06-10

Build 5 und 6.

### Hinzugefügt

- Detail-Diagramm lädt cache-first mit Lade-Skeleton statt leerer Ansicht.

### Behoben

- Absturz (`EXC_BREAKPOINT`) durch Nebenläufigkeitsfehler im täglichen Background-Task behoben.
- Alle Benachrichtigungen werden beim Wechsel in den Vordergrund neu geplant.

## [1.0.4] – 2026-06-08

Build 4.

### Behoben

- Umami-API-Filter werden vor der Hintergrundaktualisierung zurückgesetzt — Push-Benachrichtigungen
  zeigten dadurch teilweise Nullwerte an.

## [1.0.3] – 2026-05-23

Build 3.

### Hinzugefügt

- Dashboard aktualisiert nach dem Prinzip *stale-while-revalidate* beim Tab-Wechsel.
- Detailansicht aktualisiert Tagesstatistiken periodisch im Hintergrund, solange sie geöffnet ist.

### Behoben

- Eingefrorener Statistik-Tab beim Neuladen: Account-Kontext der Detailansicht korrigiert,
  Dashboard lädt nur noch einmalig.

## [1.0.2] – 2026-05-21

Build 2.

### Behoben

- Stunden-Balken der Tagesansicht verloren durch UTC-Verschiebung einzelne Datenpunkte.
- Benachrichtigungstexte werden über den Background-Task-Handler aktualisiert.

## [1.0.1] – 2026-04-24

### Hinzugefügt

- Filter für Umami: Quelle, Browser, Betriebssystem, Gerät, Land und Seite.

### Geändert

- iPad-Unterstützung entfernt — die App erscheint als reine iPhone-App.
- Onboarding zeigt eine Feature-Übersicht statt eines Anbietervergleichs.
- App im Store zu *StatsFlow* umbenannt.

### Behoben

- Umami-Login sendet Benutzername und E-Mail gemeinsam.
- Filter-Sheet zeigt einen Ladeindikator statt einer leeren Vollbildansicht.
- Darstellung der Filter-Chips und des Logout-Buttons korrigiert.

## [1.0] – 2026-04-04

Erstes App-Store-Release (Build 1).

Native iOS-App für Umami und Plausible Analytics mit Multi-Account-Unterstützung,
Echtzeit-Dashboard, Detailanalysen, Periodenvergleich, Events und Reports,
Home-Screen-Widgets, Push-Benachrichtigungen, Offline-Modus, Dark Mode sowie
deutscher und englischer Lokalisierung.

Der Entwicklung ging eine umfangreiche Überarbeitung voraus: Security-Hardening
(Zugangsdaten pro Account isoliert in der iOS-Keychain), Aufbau der Unit-Test-Suite,
vollständige Umami- und Plausible-API-Abdeckung sowie die Umbenennung von PrivacyFlow
zu StatFlow.

## [1.3.0] – 2026-01-10

Als *PrivacyFlow* veröffentlicht.

### Hinzugefügt

- Verbesserungen an den Dashboard-Einstellungen.

## [1.2.0] – 2026-01-10

### Hinzugefügt

- Anpassungsmodus für das Dashboard.

## [1.0.0] – 2026-01-09

### Geändert

- App umbenannt zu *PrivacyFlow*.

### Hinzugefügt

- Umsortieren der Websites auf dem Dashboard.

## [0.1.0] – 2025-12-18

Erste Fassung als *InsightFlow*.

### Hinzugefügt

- Native iOS-App für Umami-Analytics mit Dashboard, Detailansichten und Diagrammen.
- Offline-Caching und verbesserte Diagrammskalierung.
- Datenschutzerklärung im README.

[Unreleased]: https://github.com/Revisor01/StatFlow/compare/v1.0.6...HEAD
[1.0.6]: https://github.com/Revisor01/StatFlow/compare/v1.0.5...v1.0.6
[1.0.5]: https://github.com/Revisor01/StatFlow/compare/v1.0.4...v1.0.5
[1.0.4]: https://github.com/Revisor01/StatFlow/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/Revisor01/StatFlow/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/Revisor01/StatFlow/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/Revisor01/StatFlow/compare/v1.0...v1.0.1
[1.0]: https://github.com/Revisor01/StatFlow/compare/v1.3.0...v1.0
[1.3.0]: https://github.com/Revisor01/StatFlow/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/Revisor01/StatFlow/compare/v1.0.0...v1.2.0
[1.0.0]: https://github.com/Revisor01/StatFlow/commit/4a74e96
[0.1.0]: https://github.com/Revisor01/StatFlow/commit/49bcf4c
