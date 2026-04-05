---
phase: "21"
plan: "01"
subsystem: "website"
tags: [hugo, privacy-policy, apps-section, simonluthe-de]
key-files:
  created:
    - content/apps/statflow/_index.md
    - content/apps/statflow/datenschutz.md
    - content/apps/konfiquest/_index.md
    - content/apps/konfiquest/datenschutz.md
  modified:
    - content/apps/guckmal/_index.md
    - content/apps/guckmal/datenschutz.md
    - content/apps/guckmal/support.md
    - hugo.toml
    - APPS-INSTRUCTIONS.md
decisions:
  - "StatFlow privacy policy covers Keychain, AES-GCM widget encryption, offline cache, os.Logger details"
  - "Konfi Quest gets minimal placeholder since app not yet released"
  - "Valetudios pages left as-is for separate agent"
metrics:
  duration: "~3 minutes"
  completed: "2026-04-05"
  tasks: 8
  files: 9
---

# Phase 21 Plan 01: Web-Praesenz auf simonluthe.de Summary

Apps-Sektion auf simonluthe.de mit StatFlow-Projektseite, Privacy Policies, Konfi Quest-Platzhalter und Guck mal!-Redirects via Hugo Aliases.

## Completed Tasks

| Task | Description | Status |
|------|-------------|--------|
| 1 | StatFlow Projektseite | Done |
| 2 | StatFlow Privacy Policy (DSGVO + Apple) | Done |
| 3 | Konfi Quest Platzhalter | Done |
| 4 | Konfi Quest Privacy Policy (minimal) | Done |
| 5 | Valetudios — Skip (eigener Agent) | Skipped |
| 6 | hugo.toml Menu update (Guck mal! -> Apps) | Done |
| 7 | Guck mal! Hugo Aliases (3 Dateien) | Done |
| 8 | APPS-INSTRUCTIONS.md DONE-Markierungen | Done |

## Commits

| Hash | Message | Repo |
|------|---------|------|
| e5052fe | feat: apps section with StatFlow, Guck mal!, Konfi Quest pages + privacy policies | simon-luthe-website |

## Key Changes

### StatFlow Projektseite
- Emotionaler Einstieg: "Deine Website-Zahlen. Immer dabei."
- Feature-Highlights: Multi-Account, Sparklines, Realtime, Compare, Events/Reports, Widget, Offline
- Privacy-Kurzfassung: Keine SDKs, Keychain, keine Werbung
- Technik: SwiftUI, iOS 18+, keine Dependencies, 58+ Tests
- Download-Platzhalter fuer App Store Link

### StatFlow Privacy Policy
- DSGVO-konform mit allen relevanten Artikeln (15-21, 77)
- Apple App Store kompatibel
- Abschnitte: Server-Verbindung (nur eigene Server), Keychain, AES-GCM Widget-Encryption, Offline-Cache (50MB/24h), os.Logger, Berechtigungen
- Aufsichtsbehoerde: ULD Schleswig-Holstein
- Stand: April 2026

### Navigation
- Menu-Eintrag von "Guck mal!" (/guckmal/) zu "Apps" (/apps/)
- Hugo Aliases fuer alle 3 Guck mal!-Seiten (Redirect von alten URLs)

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

- `content/apps/statflow/_index.md`: App Store Download-Link ist Platzhalter (TODO-Kommentar) — wird nach App Store Release ergaenzt
- `content/apps/valetudios/_index.md`: Unveraendert, wird vom Valetudios-Agent gefuellt
- `content/apps/valetudios/datenschutz.md`: Unveraendert, wird vom Valetudios-Agent gefuellt

## Self-Check: PASSED

All 9 files verified present. Commit e5052fe verified in git log.
