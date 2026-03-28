---
phase: 4
slug: architektur
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-28
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (no tests yet — Phase 5) |
| **Quick run command** | `xcodebuild build -project InsightFlow.xcodeproj -scheme InsightFlow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 \| tail -5` |
| **Full suite command** | `xcodebuild build -project InsightFlow.xcodeproj -scheme InsightFlow -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run build command + grep checks
- **After every plan wave:** Full build verification
- **Max feedback latency:** 30 seconds

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Login works for Umami accounts | ARCH-01 | Requires live server | 1. Login with Umami credentials, 2. Verify dashboard loads |
| Login works for Plausible accounts | ARCH-01 | Requires live server | 1. Login with Plausible credentials, 2. Verify sites load |
| Account switching works | ARCH-01 | Requires multiple accounts | 1. Switch accounts, 2. Verify data updates |
| Logout clears all state | ARCH-01 | Requires state inspection | 1. Logout, 2. Verify login screen shows |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-03-28
