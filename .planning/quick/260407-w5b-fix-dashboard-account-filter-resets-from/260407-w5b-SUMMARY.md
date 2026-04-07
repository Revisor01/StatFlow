# Quick Task 260407-w5b: Fix Dashboard account filter resets from "Alle" to single provider

**Completed:** 2026-04-07

## Problem

When viewing "Alle" (all accounts) on the Dashboard and tapping a website to open its detail view, the `showAllAccounts` flag was set to `false` in the tap gesture. Returning from the detail view showed only the single provider's websites instead of all accounts.

## Fix

Removed `showAllAccounts = false` from the `onTapGesture` in `DashboardView.swift` (line 67). The active account is still set for API context, but the Dashboard filter state is now preserved.

## Files Changed

- `InsightFlow/Views/Dashboard/DashboardView.swift` (line 67 removed)
