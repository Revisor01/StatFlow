---
phase: 3
slug: stabilitaet
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-28
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (no tests yet — Phase 5) |
| **Config file** | none |
| **Quick run command** | `xcodebuild build -project InsightFlow.xcodeproj -scheme InsightFlow -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 \| tail -5` |
| **Full suite command** | `xcodebuild build -project InsightFlow.xcodeproj -scheme InsightFlow -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run build command + grep checks
- **After every plan wave:** Full build verification
- **Before `/gsd:verify-work`:** Full build must succeed
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 3-01-01 | 01 | 1 | STAB-01 | grep | `grep -n '\.url!' PlausibleAPI.swift UmamiAPI.swift` | N/A | ⬜ pending |
| 3-01-02 | 01 | 1 | STAB-01 | grep | `grep -n 'URL(string:' WidgetNetworking.swift \| grep '!'` | N/A | ⬜ pending |
| 3-02-01 | 02 | 1 | STAB-02 | grep | `grep -n 'asyncAfter\|Task.sleep' AccountManager.swift AuthManager.swift` | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. Build verification via xcodebuild.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Account switching works without race conditions | STAB-02 | Requires rapid switching on device | 1. Add 2+ accounts, 2. Rapidly switch between them, 3. Verify consistent state |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-03-28
