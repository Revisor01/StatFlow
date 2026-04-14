---
phase: 23
slug: screenshots-assets-submission-en-fr-de
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-14
---

# Phase 23 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Shell-based assertions (ls/file/imagemagick-identify) + TypeScript type-check (tsc --noEmit) |
| **Config file** | `app-store/screenshots/generator/tsconfig.json`, `app-store/submission/tsconfig.json` |
| **Quick run command** | `bash app-store/validate.sh quick` (Wave 0 erstellt) |
| **Full suite command** | `bash app-store/validate.sh full` (Wave 0 erstellt) |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash app-store/validate.sh quick`
- **After every plan wave:** Run `bash app-store/validate.sh full`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

> Populated by planner during PLAN.md creation. Every task gets a row with automated verify OR Wave 0 dependency.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `app-store/validate.sh` — validation runner (quick + full modes)
- [ ] Assertion-Helpers:
  - `assert_file_exists <path>` (z.B. für 24 Export-PNGs)
  - `assert_image_dim <path> 1320 2868` (via `sips -g pixelWidth -g pixelHeight` oder `magick identify`)
  - `assert_json_field <file> <jq-path> <expected>` (für submission-Responses)
- [ ] TypeScript-Type-Check-Commands (`npx tsc --noEmit` in generator + submission)
- [ ] Lint-Command (optional, `npx next lint` im Generator)

*If none: "Existing infrastructure covers all phase requirements."*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Visuelle Qualität Screenshots (Hybrid hell-mit-Tinte, Lesbarkeit, Typografie) | SHOT-02, SHOT-03 | Kein Ground-Truth — Designentscheidung | Alle 24 PNGs aus `app-store/screenshots/export/{de,en,fr}/` sichten, gegen Playbook-Anti-Patterns checken |
| Copy-Qualität pro Locale (Claim-Stärke, Idiomatik) | SHOT-04 | Sprachqualität subjektiv | User liest alle 3×8 Claims/Sublines, prüft FR auf Native-Feel |
| ASC-UI: Pricing, Availability, Age Rating, Encryption Declaration, Content Rights | SUBMIT-01 | Nicht vollständig API-abdeckbar (manche Felder nur UI) | Vor "Submit for Review" in ASC-UI gegenchecken |
| Binary-Upload (IPA) | SUBMIT-01 | Out-of-scope für Script (D-18) | User lädt IPA via Xcode Organizer hoch |
| Submit-for-Review Trigger falls API-Pfad scheitert | SUBMIT-01 | LOW-confidence im Research — Manual-Fallback dokumentiert | User klickt "Submit" in ASC-UI falls Script dort blockiert |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
