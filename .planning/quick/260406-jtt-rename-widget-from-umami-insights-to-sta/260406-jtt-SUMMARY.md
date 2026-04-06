# Quick Task 260406-jtt: Rename Widget from Umami Insights to StatFlow

**Completed:** 2026-04-06

## Problem

The widget still showed "Umami Insights" as its display name in the widget gallery and header, instead of the new app name "StatFlow".

## Fix

Renamed `widget.displayName` from "Umami Insights" to "StatFlow" in both EN and DE Localizable.strings for the widget target. Also updated file header comments in all 4 localization files.

## Files Changed

- `InsightFlowWidget/Resources/en.lproj/Localizable.strings`
- `InsightFlowWidget/Resources/de.lproj/Localizable.strings`
- `InsightFlow/Resources/en.lproj/InfoPlist.strings`
- `InsightFlow/Resources/en.lproj/Localizable.strings`
- `InsightFlow/Resources/de.lproj/InfoPlist.strings`
- `InsightFlow/Resources/de.lproj/Localizable.strings`
