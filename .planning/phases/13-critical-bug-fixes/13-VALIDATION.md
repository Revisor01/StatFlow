---
phase: 13
slug: critical-bug-fixes
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-29
---

# Phase 13 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (Swift) |
| **Config file** | umami.xcodeproj |
| **Quick run command** | `xcodebuild test -project umami.xcodeproj -scheme umami -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:umamiTests 2>&1 \| tail -20` |
| **Full suite command** | `xcodebuild test -project umami.xcodeproj -scheme umami -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 \| tail -50` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick test command
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 13-00-01 | 00 | 0 | FIX-02, FIX-04 | build | build-for-testing | N/A (creates stubs) | pending |
| 13-01-01 | 01 | 1 | FIX-03 | unit (TDD) | AnalyticsCacheServiceTests | ✅ vorhanden | pending |
| 13-01-02 | 01 | 1 | FIX-03, FIX-04 | unit (TDD) | DashboardViewModelTests | ✅ Wave 0 | pending |
| 13-02-01 | 02 | 1 | FIX-01 | unit | AccountManagerTests | ✅ vorhanden | pending |
| 13-02-02 | 02 | 1 | FIX-02 | unit (TDD) | WebsiteDetailViewModelTests | ✅ Wave 0 | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

- [x] `InsightFlowTests/WebsiteDetailViewModelTests.swift` — Plan 13-00, Task 1
- [x] `InsightFlowTests/DashboardViewModelTests.swift` — Plan 13-00, Task 1

*Wave 0 covered by 13-00-PLAN.md (wave: 0, depends_on: []).*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Widget zeigt korrekte Daten nach Account-Wechsel | FIX-01 | WidgetKit-Timeline nicht automatisiert testbar | 1. App oeffnen 2. Account wechseln 3. Widget auf Homescreen pruefen |
| Account-Wechsel zeigt Loading statt Flash | FIX-04 | UI-State-Transition visuell | 1. Account wechseln 2. Pruefen ob Loading-Indikator vor Daten erscheint |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved
