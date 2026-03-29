<p align="center">
  <img src="app-icon.png" alt="StatFlow" width="128" height="128">
</p>

<h1 align="center">StatFlow</h1>

<p align="center">
  Native iOS-App für <a href="https://umami.is">Umami</a> und <a href="https://plausible.io">Plausible</a> Analytics.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-iOS%2018%2B-blue?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-5.10-orange?style=flat-square&logo=swift" alt="Swift">
  <img src="https://img.shields.io/badge/Xcode-16%2B-blue?style=flat-square&logo=xcode" alt="Xcode">
  <img src="https://img.shields.io/github/license/Revisor01/StatFlow?style=flat-square" alt="License">
  <img src="https://img.shields.io/github/v/tag/Revisor01/StatFlow?style=flat-square&label=Version" alt="Version">
</p>

## Features

- **Multi-Account-Unterstützung**: Verwalte mehrere Analytics-Konten verschiedener Anbieter in einer App
- **Echtzeit-Dashboard**: Besucher, Seitenaufrufe, Absprungrate und Sitzungsdauer auf einen Blick
- **Detaillierte Analysen**: Top-Seiten, Referrer, Geografie, Geräte und Browser
- **Periodenvergleich**: Woche, Monat oder Jahr vergleichen
- **Home-Screen-Widgets**: Schneller Blick auf die wichtigsten Statistiken direkt vom Home Screen
- **Push-Benachrichtigungen**: Tägliche oder wöchentliche Zusammenfassungen
- **Offline-Modus**: Gecachte Daten auch ohne Netzwerk verfügbar
- **Dark Mode**: Vollständige Unterstützung für den Dunkelmodus
- **Lokalisierung**: Deutsch und Englisch

## Unterstützte Anbieter

| Anbieter | API | Funktionen |
|----------|-----|------------|
| **Umami** | REST API | Alle Funktionen inkl. Sessions, Journeys, Share-Links |
| **Plausible** | Stats API v2 | Dashboard, Diagramme, Metriken (keine Einzelsitzungen) |

## Architektur

StatFlow verwendet MVVM mit klarer Schichttrennung und einem einheitlichen Provider-Protokoll, das Umami und Plausible abstrahiert.

```
┌─────────────────────────────────────────┐
│         Presentation Layer              │
│   SwiftUI Views + ViewModels            │
│   (Dashboard, Detail, Reports, Events)  │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│           Service Layer                 │
│   UmamiAPI · PlausibleAPI (actors)      │
│   AccountManager · AnalyticsManager     │
│   NotificationManager                   │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│            Model Layer                  │
│   Codable structs für API-Responses     │
│   AnalyticsWebsite · AnalyticsStats     │
│   AnalyticsMetricItem · DateRange       │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│         Infrastructure Layer            │
│   KeychainService · AppDelegate         │
│   AnalyticsCacheService                 │
│   BackgroundTasks · UserNotifications   │
└─────────────────────────────────────────┘
```

**Kernprinzipien:**
- **AnalyticsProvider-Protokoll**: Einheitliche Schnittstelle für Umami und Plausible — ViewModels arbeiten provider-agnostisch
- **Actor-based Concurrency**: `UmamiAPI` und `PlausibleAPI` sind Swift Actors für thread-sichere API-Kommunikation
- **Credential-Isolation**: Zugangsdaten in der Keychain pro Account-ID gespeichert (nicht in UserDefaults)
- **Keine externen Dependencies**: Ausschließlich Apple Frameworks (SwiftUI, Foundation, WidgetKit, Security, UserNotifications, BackgroundTasks)

## Screenshots

*Screenshots werden nach dem ersten App Store Release ergänzt.*

| Dashboard | Website-Detail | Widgets | Einstellungen |
|-----------|---------------|---------|---------------|
| *folgt* | *folgt* | *folgt* | *folgt* |

## Voraussetzungen

- iOS 18.0+
- Eigene Umami-Instanz (Self-Hosted oder Cloud) **oder** eigene Plausible-Instanz (Self-Hosted oder Cloud)

## Installation

### App Store

Demnächst verfügbar.

### Selbst kompilieren

1. Repository klonen:
   ```bash
   git clone https://github.com/Revisor01/StatFlow.git
   ```
2. `InsightFlow.xcodeproj` in Xcode 16+ öffnen
3. Bundle ID in den Signing-Einstellungen auf die eigene Team-ID anpassen
4. Auf Gerät oder Simulator bauen und ausführen

## Konfiguration

1. App starten
2. Analytics-Konto mit Server-URL und API-Zugangsdaten hinzufügen
3. Websites auswählen und Statistiken anzeigen
4. Optional: Widgets auf dem Home Screen hinzufügen und Benachrichtigungen aktivieren

## Mitwirken

Beiträge sind willkommen! Pull Requests können gerne eingereicht werden.

## Lizenz

Dieses Projekt steht unter der GNU General Public License v3.0 — siehe [LICENSE](LICENSE) für Details.

## Danksagung

- [Umami Analytics](https://umami.is) — Open-Source, datenschutzfreundliche Web-Analytik
- [Plausible Analytics](https://plausible.io) — Einfache, datenschutzfreundliche Analytik

## Hinweis

Dies ist eine inoffizielle Companion-App. StatFlow ist nicht mit Umami Software, Inc. oder Plausible Insights OU verbunden oder von diesen unterstützt.

## Datenschutzerklärung

**Verantwortlicher**

Simon Luthe
Suderstrasse 18
25779 Hennstedt
Deutschland

E-Mail: mail@simonluthe.de
Telefon: +49 151 21563194
Web: simonluthe.de

**Datenverarbeitung**

StatFlow speichert und verarbeitet folgende Daten ausschließlich lokal auf deinem Gerät:

- URLs deiner Umami- oder Plausible-Instanzen
- API-Zugangsdaten (Token, Benutzername/Passwort) für die Authentifizierung
- App-Einstellungen und Präferenzen
- Gecachte Analytics-Daten für den Offline-Modus

Es werden keine Daten an externe Server übertragen. Die gesamte Kommunikation erfolgt ausschließlich zwischen deinem iOS-Gerät und deinen konfigurierten Analytics-Instanzen.

**Keine Tracking- oder Analysedienste**

StatFlow verwendet:

- Keine Analytics oder Tracking-Tools
- Keine Werbung
- Keine Cloud-Dienste
- Keine Drittanbieter-SDKs, die Daten sammeln

**Netzwerkverbindungen**

Die App stellt ausschließlich Verbindungen zu den von dir konfigurierten Analytics-Instanzen (Umami oder Plausible) her.

**Datenspeicherung**

Alle Daten werden lokal in der iOS-Keychain (für Zugangsdaten) bzw. in den App-Einstellungen gespeichert. Bei Deinstallation der App werden alle Daten vollständig entfernt.

**Deine Rechte (DSGVO)**

Da alle Daten ausschließlich lokal auf deinem Gerät gespeichert werden und keine Übertragung an den Entwickler oder Dritte erfolgt, hast du die volle Kontrolle über deine Daten. Du kannst diese jederzeit durch Löschen der App vollständig entfernen.

Bei Fragen zum Datenschutz kannst du dich jederzeit an die oben genannte Kontaktadresse wenden.

**Änderungen**

Diese Datenschutzerklärung kann bei Bedarf aktualisiert werden. Die aktuelle Version ist stets in diesem Repository verfügbar.

Stand: März 2026
