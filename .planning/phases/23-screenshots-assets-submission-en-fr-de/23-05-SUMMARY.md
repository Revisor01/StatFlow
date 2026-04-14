---
phase: 23-screenshots-assets-submission-en-fr-de
plan: 05
status: complete
completed: 2026-04-14
tasks_completed: 2
commits:
  - 4338b60 feat(23-05): add ASC submission library (JWT + API client)
  - c34cfc1 chore(23): drop French localization from scope (includes lib/config.ts)
---

# Plan 23-05 Summary — ASC Submission Library

## What was built

Typsichere, von Plan 06 importierbare Submission-Library. Drei Module:
JWT-Generator mit Token-Cache, ASC-API-Client mit Retry-Logik, und
Config-Modul mit allen Metadaten (DE + EN).

## Key files created

- `app-store/submission/package.json` + `package-lock.json` — npm-Projekt mit typescript, ts-node, jsonwebtoken
- `app-store/submission/tsconfig.json` — strict mode, ES2022, commonjs
- `app-store/submission/lib/jwt.ts` (51 Zeilen) — ES256 JWT mit Token-Cache (refresh < 2min Restlaufzeit)
- `app-store/submission/lib/asc-api.ts` (67 Zeilen) — ascFetch() + withRetry() für 429
- `app-store/submission/lib/config.ts` (172 Zeilen) — LOCALES, METADATA, SLIDE_IDS, screenshotPath(), REVIEW_NOTES, URLs

## Configuration

- **Token-Lifetime:** 20 Minuten (Apple-Maximum)
- **Refresh-Schwelle:** 2 Minuten Restlaufzeit — pretige regeneriert
- **Retry-Strategie:** Exponential-Backoff nur bei 429, max 5 Versuche
- **Screenshot-Display-Type:** APP_IPHONE_67 (69 nicht im OpenAPI-Spec, per RESEARCH.md)
- **Locales:** de → de-DE, en → en-US (BCP-47 laut Pitfall 5)
- **Secrets via Env-Vars:** APP_STORE_CONNECT_KEY_ID, _ISSUER_ID, _KEY_PATH — keine hardcoded

## Deviations from plan

- **Ursprünglich 3 Locales (de, en, fr) geplant** — FR wurde während der Ausführung aus Scope gestrichen (siehe commit c34cfc1). config.ts enthält nur DE + EN METADATA, LOCALES-Konstante entsprechend reduziert. Der Scope-Change wurde in STATE.md unter Decisions dokumentiert.
- **REVIEW_NOTES:** Passwörter/API-Keys aus review-notes.md wurden NICHT 1:1 kopiert — stattdessen Platzhalter `(see credentials provided via secure channel)`, weil die Original-Credentials in app-store/secrets.md (gitignored) liegen. Plan 06 kann hier die tatsächlichen Credentials zur Laufzeit einbauen oder über Env-Vars nachladen.

## Verification

```
$ cd app-store/submission && npx tsc --noEmit
# exit 0, no errors

$ grep-Checks:
OK: APP_BUNDLE_ID=de.godsapp.statflow
OK: de-DE + en-US Locale-Codes
OK: APP_IPHONE_67 Display-Type
OK: generateASCToken, withRetry, withRetry 429
```

## Self-Check

- [x] package.json mit jsonwebtoken + ts-node
- [x] tsconfig.json strict + ES2022
- [x] jwt.ts: Token-Cache + Refresh < 2min
- [x] asc-api.ts: ascFetch() + withRetry() mit Exponential-Backoff
- [x] config.ts: alle Metadaten DE + EN
- [x] TypeScript kompiliert ohne Fehler
- [x] Keine Secrets im Code — nur Env-Vars
- [x] APP_IPHONE_67 mit 422-Fallback-Erwartung dokumentiert

## Ready for next wave

Wave 3 kann starten:
- **Plan 23-06** (Wave 3, autonom): submit.ts — Haupt-Submission-Script, importiert aus lib/

Plan 23-04 (Screenshots export) wurde vom User deferred — Screenshots werden später nachgezogen. submit.ts wird also zunächst ohne finale PNGs geschrieben und mit --dry-run getestet.
