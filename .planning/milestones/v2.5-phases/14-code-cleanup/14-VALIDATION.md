---
phase: 14
slug: code-cleanup
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-29
---

# Phase 14 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (Swift) + xcodebuild |
| **Config file** | InsightFlow.xcodeproj |
| **Quick run command** | `xcodebuild build -project InsightFlow.xcodeproj -scheme InsightFlow -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 \| tail -20` |
| **Full suite command** | `xcodebuild test -project InsightFlow.xcodeproj -scheme InsightFlow -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 \| tail -50` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick build command
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 14-01-01 | 01 | 1 | CLEAN-01 | build | xcodebuild build (compile after deletion) | N/A | pending |
| 14-02-01 | 02 | 1 | CLEAN-02 | manual + build | Offline-Indikator visuell + build | N/A | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

*Existing XCTest infrastructure covers all phase requirements. No new test stubs needed — CLEAN-01 is verified by successful compilation after deletions, CLEAN-02 by visual inspection of offline banners.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Offline-Indikator sichtbar in Detail/Events/Sessions/Reports Views | CLEAN-02 | UI-Rendering nicht automatisiert testbar | 1. Flugmodus aktivieren 2. Jede View öffnen 3. Prüfen ob Offline-Banner erscheint |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved
