# Phase 04: Support & Branding - Context

**Gathered:** 2026-03-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Einheitliche Support-Option ("Buy me a Coffee"-Stil) mit Redesign der bestehenden SupportView. Kohärentes Branding mit dezenter Herkunftsangabe. Design soll konsistent über ValetudiOS und PrivacyFlow sein (als Vorlage, kein shared Package).

</domain>

<decisions>
## Implementation Decisions

### Support-UI Design
- Bestehende SupportView.swift komplett überarbeiten (Redesign, nicht nur Anpassung)
- Keine Emojis (☕️🍕🎉) mehr — cleanes, reduziertes Design für Tip-Optionen
- Design-Vorlage in PrivacyFlow erstellen, ValetudiOS folgt gleicher Struktur (kein shared Swift Package)
- 5-Launch-Schwelle für Support-Reminder beibehalten (bewährt, nicht aufdringlich)

### Branding
- "Mit Liebe in Hennstedt gemacht" beibehalten im Settings-Footer
- Dezenter Untertitel unter Hennstedt-Zeile (z.B. "Ein Pastorenprojekt") — kein Easter Egg, keine Animation
- Ton: warmherzig-informell, passend zum Free-App-Charakter

### Claude's Discretion
- Konkretes Layout der redesigned SupportView (Cards, Liste, o.a. — Hauptsache clean ohne Emojis)
- Formulierung des Untertitels — Vorschlag wird dem User zur Anpassung präsentiert
- Lokalisierung DE + EN für neue/geänderte Strings

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- SupportManager.swift (113 Zeilen) — StoreKit 2 Integration, Product Loading, Purchase Handling
- SupportReminderView.swift (125 Zeilen) — Modal mit Gradient-Heart, Spring-Animation
- SupportView.swift (127 Zeilen) — Aktuelle Support-UI mit Emoji-Buttons
- SettingsView.swift (624 Zeilen) — Enthält Support-Section (Zeilen 186-228) und Footer-Branding (Zeilen 378-392)

### Established Patterns
- StoreKit 2 Product IDs: de.godsapp.insightflow.support.{small,medium,large}
- AppStorage für Reminder-Tracking: supportReminderShown, hasSupported, appLaunchCount
- Lokalisierung: de.lproj/Localizable.strings + en.lproj/Localizable.strings
- ContentView wendet .supportReminder() Modifier auf MainTabView an

### Integration Points
- SettingsView → SupportView Navigation
- ContentView → SupportReminderOverlay Modifier
- SupportManager als @Observable Service

</code_context>

<specifics>
## Specific Ideas

- User will cleanes Design ohne Emojis für die Tip-Buttons
- Untertitel soll "unaufdringlich" sein — keine Animation, kein Easter Egg
- Design muss als Vorlage für ValetudiOS dienen (gleiche Struktur)

</specifics>

<deferred>
## Deferred Ideas

- App-Name-Problem: Weder "PrivacyFlow" noch "InsightFlow" im englischen App Store verfügbar — Namensfindung ist separates Thema, nicht in Phase 04
- ValetudiOS-Implementierung: Nur Vorlage in PrivacyFlow, Umsetzung in ValetudiOS ist separates Projekt

</deferred>
