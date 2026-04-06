# Quick Task 260406-jli: Fix line chart X-axis labels showing time instead of dates

**Completed:** 2026-04-06

## Problem

Dashboard sparkline line chart X-axis labels were hardcoded to `.dateTime.hour().minute()`, always showing times like "1 Uhr" regardless of the selected time period. The bar chart correctly used `isHourlyData` to conditionally format labels.

## Fix

Added the same `isHourlyData` conditional to `lineSparkline` in `WebsiteCard.swift`:
- Hourly data → `.hour().minute()` (e.g., "1:00")
- Non-hourly data → `.day().month()` (e.g., "28. Feb")

## Files Changed

- `InsightFlow/Views/Dashboard/WebsiteCard.swift` (lines 329-338)
