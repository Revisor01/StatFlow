---
phase: 1
slug: security-hardening
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-27
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (built-in) |
| **Config file** | none — no test target exists yet (TEST-01 is Phase 5) |
| **Quick run command** | `xcodebuild build -project InsightFlow.xcodeproj -scheme InsightFlow -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5` |
| **Full suite command** | `xcodebuild build -project InsightFlow.xcodeproj -scheme InsightFlow -destination 'platform=iOS Simulator,name=iPhone 16'` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run build command (no tests exist yet — Phase 5)
- **After every plan wave:** Full build verification
- **Before `/gsd:verify-work`:** Full build must succeed
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 1-01-01 | 01 | 1 | SEC-01 | build | `xcodebuild build ...` | N/A | ⬜ pending |
| 1-01-02 | 01 | 1 | SEC-04 | build | `xcodebuild build ...` | N/A | ⬜ pending |
| 1-02-01 | 02 | 1 | SEC-02 | build | `xcodebuild build ...` | N/A | ⬜ pending |
| 1-03-01 | 03 | 1 | SEC-03 | build | `xcodebuild build ...` | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No test framework needed (Phase 5 scope).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Migration preserves login state | SEC-04 | Requires app update scenario on device | 1. Install old version, 2. Add accounts, 3. Install new build, 4. Verify accounts work without re-login |
| Widget shows data after encryption | SEC-02 | Requires widget refresh on device | 1. Add account, 2. Check widget displays data, 3. Verify widget_accounts.json is encrypted |
| No token in Console.app | SEC-03 | Requires Console.app log inspection | 1. Trigger widget refresh, 2. Filter Console for "[Widget]", 3. Verify no token fragments |
| Keychain scoped per account-ID | SEC-01 | Requires Keychain inspection | 1. Add 2 accounts, 2. Switch between them, 3. Verify both have separate Keychain entries |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
