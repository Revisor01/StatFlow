# Phase 12: Rename to StatFlow - Context

**Gathered:** 2026-03-28
**Status:** Ready for planning
**Mode:** Auto-generated (infrastructure — rename operation)

<domain>
## Phase Boundary

Komplettes Rebranding: PrivacyFlow/InsightFlow → StatFlow überall im Code, in Strings, Bundle IDs, URL Scheme, Product IDs.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
Systematischer Rename in allen betroffenen Dateien. Reihenfolge:
1. Info.plist + InfoPlist.strings (Bundle Display Name, URL Scheme)
2. Localizable.strings (alle user-facing Texte)
3. Swift-Dateien (Bundle IDs, Keychain Service, App Group, Product IDs, Kommentare)
4. Widget-Dateien (gleiche Behandlung)
5. Build prüfen

### Mapping
- "PrivacyFlow" → "StatFlow" (Display Name, user-facing)
- "privacyflow" → "statflow" (URL Scheme)
- "de.godsapp.PrivacyFlow" → "de.godsapp.statflow" (Bundle ID)
- "de.godsapp.insightflow" → "de.godsapp.statflow" (Product IDs)
- "group.de.godsapp.PrivacyFlow" → "group.de.godsapp.statflow" (App Group)
- "InsightFlow" in Kommentaren → "StatFlow" (wo user-visible)

NICHT umbenennen:
- InsightFlow.xcodeproj (Projektname, zu riskant)
- InsightFlow/ Verzeichnisname (gleicher Grund)
- Swift struct/class Namen die "InsightFlow" enthalten (falls vorhanden)

</decisions>

<code_context>
## Existing Code Insights

### Betroffene Dateien (24)
**App:** InsightFlowApp.swift, Info.plist, InfoPlist.strings (de+en), Localizable.strings (de+en), AnalyticsCacheService.swift, KeychainService.swift, SharedCredentials.swift, SupportManager.swift, SettingsView.swift
**Widget:** WidgetCache.swift, InsightFlowWidget.swift, InsightFlowWidgetBundle.swift, InsightFlowWidgetLiveActivity.swift, WidgetIntents.swift, WidgetModels.swift, WidgetTimeRange.swift, WidgetNetworking.swift, WidgetStorage.swift, WidgetChartViews.swift, WidgetSizeViews.swift, Localizable.strings (de+en)
**Project:** project.pbxproj

</code_context>

<specifics>
## Specific Ideas

None.

</specifics>

<deferred>
## Deferred Ideas

None.

</deferred>
