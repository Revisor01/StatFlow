---
phase: 13
slug: critical-bug-fixes
status: draft
nyquist_compliant: false
wave_0_complete: false
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
| 13-01-01 | 01 | 1 | FIX-01 | manual | Widget nach Account-Wechsel prüfen | N/A | ⬜ pending |
| 13-02-01 | 02 | 1 | FIX-02 | unit | Task-Cancellation Test | ❌ W0 | ⬜ pending |
| 13-03-01 | 03 | 1 | FIX-03 | unit | Cache-Cleanup Test | ❌ W0 | ⬜ pending |
| 13-04-01 | 04 | 1 | FIX-04 | unit | Loading-State Test | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Test stubs for FIX-02 (Request-Cancellation)
- [ ] Test stubs for FIX-03 (Cache-Cleanup)
- [ ] Test stubs for FIX-04 (Loading-State)

*Existing XCTest infrastructure covers framework needs.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Widget zeigt korrekte Daten nach Account-Wechsel | FIX-01 | WidgetKit-Timeline nicht automatisiert testbar | 1. App öffnen 2. Account wechseln 3. Widget auf Homescreen prüfen |
| Account-Wechsel zeigt Loading statt Flash | FIX-04 | UI-State-Transition visuell | 1. Account wechseln 2. Prüfen ob Loading-Indikator vor Daten erscheint |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
