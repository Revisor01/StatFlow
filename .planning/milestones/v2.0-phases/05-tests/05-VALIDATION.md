---
phase: 5
slug: tests
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-28
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (built-in) |
| **Config file** | InsightFlowTests target in project.pbxproj |
| **Quick run command** | `xcodebuild test -project InsightFlow.xcodeproj -scheme InsightFlow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing InsightFlowTests 2>&1 \| tail -20` |
| **Full suite command** | `xcodebuild test -project InsightFlow.xcodeproj -scheme InsightFlow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing InsightFlowTests` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run test suite
- **After every plan wave:** Full test suite
- **Max feedback latency:** 15 seconds

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-03-28
