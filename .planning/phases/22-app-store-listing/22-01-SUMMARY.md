---
phase: "22"
plan: "01"
subsystem: documentation
tags: [app-store, review, readme]
dependency_graph:
  requires: []
  provides: [app-store-description, review-notes, readme-update]
  affects: [app-store-connect]
key_files:
  created:
    - app-store/description.md
    - app-store/review-notes.md
  modified:
    - README.md
decisions:
  - "Subtitle identisch DE/EN: 'Analytics Dashboard for iPhone' (29 Zeichen, universell)"
  - "Category: Utilities (Primary), Productivity (Secondary)"
  - "InsightFlow.xcodeproj -> StatFlow.xcodeproj im README korrigiert"
  - "Swift Badge 5.10 -> 6.0 aktualisiert"
metrics:
  duration: "93s"
  completed: "2026-04-05"
  tasks: 3
  files: 3
---

# Phase 22 Plan 01: App Store Listing & Review Summary

App Store Beschreibung (DE+EN) mit Keywords, Review Notes mit Testaccounts, README-Aktualisierung (Swift 6.0, Events-Feature, Privacy-Link)

## Tasks Completed

### Task 1: App Store Beschreibung (STORE-01)
- Created `app-store/description.md` with complete App Store Connect copy
- DE + EN descriptions covering all features, privacy angle, tech details
- Keywords optimized for both languages (100 chars each)
- Subtitle, promotional text, What's New, category, URLs
- Commit: 480f187

### Task 2: App Review Notes (REVIEW-01)
- Created `app-store/review-notes.md` with two test accounts
- Umami test account (t.godsapp.de) with step-by-step instructions
- Plausible test account (plausible.godsapp.de) with step-by-step instructions
- Reviewer context: self-hosted requirement, no registration, no data collection
- Commit: 480f187

### Task 3: README Update (README-01)
- Updated Swift badge from 5.10 to 6.0 (matches iOS 18+ / Swift 6.0 in PROJECT.md)
- Added Events & Reports to feature list
- Improved Periodenvergleich and Offline-Modus descriptions
- Added Privacy Policy web link above Datenschutzerklaerung section
- Fixed stale project reference: InsightFlow.xcodeproj -> StatFlow.xcodeproj
- Commit: 480f187

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed stale InsightFlow.xcodeproj reference in README**
- **Found during:** Task 3
- **Issue:** README still referenced `InsightFlow.xcodeproj` (old project name before v2.4 rename)
- **Fix:** Changed to `StatFlow.xcodeproj`
- **Files modified:** README.md
- **Commit:** 480f187

**2. [Rule 1 - Bug] Swift version badge outdated**
- **Found during:** Task 3
- **Issue:** Badge showed Swift 5.10, but PROJECT.md states Swift 6.0 / iOS 18+
- **Fix:** Updated badge to Swift 6.0
- **Files modified:** README.md
- **Commit:** 480f187

## Known Stubs

None - all content is final copy ready for App Store Connect.

## Self-Check: PASSED

- app-store/description.md: FOUND
- app-store/review-notes.md: FOUND
- README.md: FOUND
- Commit 480f187: FOUND
