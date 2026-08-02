# Changelog

Alle nennenswerten Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

Das Format basiert auf [Keep a Changelog 1.1.0](https://keepachangelog.com/de/1.1.0/),
und dieses Projekt folgt [Semantic Versioning 2.0.0](https://semver.org/lang/de/).

Die App hieß in ihrer Entwicklungsgeschichte zunächst *InsightFlow*, dann *PrivacyFlow*
und trägt seit März 2026 den Namen **StatFlow**. Der Xcode-Zielname `InsightFlow` ist
aus dieser Historie erhalten geblieben.

## [Unreleased]

### Entfernt

- App-Store-Grafiken und Screenshot-Generator aus dem Repository entfernt. Die Grafik-Erstellung
  läuft jetzt zentral über `~/Documents/social-posts-studio` (Projekt `statflow`); Secrets liegen
  in `~/.claude/secrets/`.
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

## [1.0.4] – 2026-05-27

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

## [1.0.0] – 2026-04-24

Erstes App-Store-Release als **StatFlow** (Build 1).

### Hinzugefügt

- Filter für Umami: Quelle, Browser, Betriebssystem, Gerät, Land und Seite.
- Onboarding zeigt Feature-Übersicht statt Anbietervergleich.

### Geändert

- iPad-Unterstützung entfernt — die App erscheint als reine iPhone-App.
- App-Store-Metadaten, Screenshots und Einreichungsskripte für DE und EN erstellt.

### Behoben

- Umami-Login sendet Benutzername und E-Mail gemeinsam.
- Filter-Sheet zeigt einen Ladeindikator statt einer leeren Vollbildansicht.

## [2.7] – 2026-04-04

Interner Meilenstein: Stabilität & Architektur.

### Geändert

- Architektur- und Stabilitätsarbeiten abgeschlossen (Cache-Lebenszyklus, Widget-Race-Conditions,
  Abbruch laufender Requests, modaler Account-Flow).

## [2.6] – 2026-04-03

Interner Meilenstein: Design Polish.

## [2.5] – 2026-03-29

Interner Meilenstein: Pre-Release Polish. README und Repository-Struktur überarbeitet.

## [2.4] – 2026-03-28

Interner Meilenstein: Umbenennung zu **StatFlow** — Bundle-IDs, URL-Schema, Anzeigename und
Lokalisierungs-Strings angepasst.

## [2.3] – 2026-03-28

Interner Meilenstein: API-Datenscreens & Analytics-Setup (Events, Reports, Sessions).

## [2.2] – 2026-03-28

Interner Meilenstein: Support & API-Abdeckung.

### Hinzugefügt

- Vollständige Umami- und Plausible-API-Abdeckung.
- Push-Benachrichtigungen mit täglicher oder wöchentlicher Zusammenfassung.
- Support-Bereich und Branding.

## [2.1] – 2026-03-28

Interner Meilenstein: UX-Politur & Features.

### Hinzugefügt

- Ansicht über alle Accounts hinweg.

### Behoben

- Widget-Deep-Links.

## [2.0] – 2026-03-28

Interner Meilenstein: Code-Qualität & Security-Hardening.

### Hinzugefügt

- Unit-Test-Target (`InsightFlowTests`) mit Tests für Keychain, DateRange, API-Parsing,
  Cache-Service und ViewModels.

### Geändert

- Zugangsdaten werden pro Account-ID in der iOS-Keychain isoliert.
- Widget-Extension aufgeteilt und Architektur nach Schichten getrennt.

## [1.3.0] – 2026-01-10

Als *PrivacyFlow* veröffentlicht.

### Hinzugefügt

- Verbesserungen an den Dashboard-Einstellungen.

## [1.2.0] – 2026-01-10

### Hinzugefügt

- Anpassungsmodus für das Dashboard.

## [1.0.0-privacyflow] – 2026-01-09

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
[1.0.2]: https://github.com/Revisor01/StatFlow/compare/v1.0.0-statflow...v1.0.2
[1.0.0]: https://github.com/Revisor01/StatFlow/releases/tag/v1.0.0-statflow
[2.7]: https://github.com/Revisor01/StatFlow/compare/v2.6...v2.7
[2.6]: https://github.com/Revisor01/StatFlow/compare/v2.5...v2.6
[2.5]: https://github.com/Revisor01/StatFlow/compare/v2.4...v2.5
[2.4]: https://github.com/Revisor01/StatFlow/compare/v2.3...v2.4
[2.3]: https://github.com/Revisor01/StatFlow/compare/v2.2...v2.3
[2.2]: https://github.com/Revisor01/StatFlow/compare/v2.1...v2.2
[2.1]: https://github.com/Revisor01/StatFlow/compare/v2.0...v2.1
[2.0]: https://github.com/Revisor01/StatFlow/compare/v1.3.0...v2.0
[1.3.0]: https://github.com/Revisor01/StatFlow/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/Revisor01/StatFlow/compare/v1.0.0...v1.2.0
[1.0.0-privacyflow]: https://github.com/Revisor01/StatFlow/releases/tag/v1.0.0
[0.1.0]: https://github.com/Revisor01/StatFlow/releases/tag/v1.0.0
