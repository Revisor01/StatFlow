---
phase: 23-screenshots-assets-submission-en-fr-de
plan: 06
status: complete
completed: 2026-04-14
tasks_completed: 1
commits:
  - ca205b4 feat(23-06): add submit.ts ASC submission script
---

# Plan 23-06 Summary — ASC Submission Script (submit.ts)

## What was built

Das Haupt-Submission-Script: `app-store/submission/submit.ts` (~490 Zeilen
TypeScript). Implementiert den vollständigen ASC API Flow in 7 Steps, mit
Dry-Run-Modus, optionalem `--skip-screenshots`, und dokumentierten manuellen
Fallbacks für bekannte API-Grenzen (APP_IPHONE_67 mit 422, Submit-for-Review).

## Script-Steps

| Step | Funktion | API-Call |
|------|----------|----------|
| 0 | Preflight | — (nur fs.existsSync) |
| 1 | getAppId | `GET /v1/apps?filter[bundleId]=...` |
| 2 | getOrCreateVersion | `GET/POST /v1/appStoreVersions` |
| 3 | getAppInfoId | `GET /v1/apps/{id}/appInfos` |
| 4 | setVersionMetadata | `POST/PATCH /v1/appStoreVersionLocalizations` + `appInfoLocalizations` |
| 5 | uploadScreenshots | `POST /v1/appScreenshotSets` + 3-Schritt-Upload |
| 6 | setReviewNotes | `POST /v1/appStoreReviewDetails` |
| 7 | submitForReview | `POST /v1/reviewSubmissions` + `confirm` |

## CLI-Modi

- `npx ts-node submit.ts --dry-run` — gibt alle Steps aus, keine API-Calls
- `npx ts-node submit.ts --skip-screenshots` — überspringt Upload, nur Metadaten
- `npx ts-node submit.ts` — echter Lauf (braucht ENV-Vars geladen)

## Deviations from plan

- **Bug gefunden und gefixt:** `lib/config.ts` `REPO_ROOT` ging **eins zu weit hoch** (`../../../..`). Richtig: `../../..` (lib/config.ts liegt in `app-store/submission/lib/`, also 3x hochgehen für Repo-Root). Ohne Fix hätte Step 0 PNGs in `/Users/simonluthe/Documents/app-store/...` gesucht — Verzeichnis existiert nicht.
- **Demo-Credentials via ENV-Vars** statt hardcoded: `ASC_DEMO_ACCOUNT_NAME` und `ASC_DEMO_ACCOUNT_PASSWORD`. Plan hatte sie aus review-notes.md hardcoded vorgeschlagen — aber das committet die Credentials in git. Besser: user sourced vor Ausführung `source ~/.claude/secrets.env` und setzt die Env-Vars dort.
- **DE/EN statt DE/EN/FR** (Scope-Change per commit c34cfc1). Script iteriert automatisch über `LOCALES` aus config.ts — keine Code-Anpassung nötig.

## Verification

```
$ cd app-store/submission && npx tsc --noEmit
# exit 0

$ npx ts-node submit.ts --dry-run --skip-screenshots
=== StatFlow ASC Submission Script ===
MODE: DRY-RUN
Step 0: Preflight — FEHLER: Fehlende PNGs (erwartet, Plan 04 noch offen)
Step 1: App-ID für Bundle-ID de.godsapp.statflow holen...
  [DRY-RUN] GET /v1/apps?filter[bundleId]=de.godsapp.statflow&fields[apps]=bundleId&limit=1
Step 2..7: alle Steps mit [DRY-RUN] POST/PATCH-Ausgaben
=== Submission abgeschlossen ===
```

Alle 7 Steps laufen durch ohne Crash.

## Self-Check

- [x] TypeScript kompiliert ohne Fehler
- [x] DRY_RUN Flag implementiert
- [x] SKIP_SCREENSHOTS Flag für Metadaten-Only-Lauf
- [x] APP_IPHONE_67 mit 422-Fallback + Manual-Upload-Anleitung
- [x] Subtitle via appInfoLocalizations (Pitfall 2)
- [x] 3-Schritt-Screenshot-Upload (reserve → S3 → commit+MD5)
- [x] Submit-for-Review mit Manual-Fallback (LOW-confidence)
- [x] Sparse fieldsets bei GET-Calls (`fields[apps]=bundleId`)
- [x] REVIEW_NOTES mit Credentials via Env-Vars (keine Hardcodes)
- [x] config.ts REPO_ROOT-Bug gefixt

## Ready for next

- **Plan 23-07 (Wave 4, checkpoint):** Dry-Run + echter Lauf + ASC-UI-Gates. Braucht aber die 16 Export-PNGs aus Plan 23-04.

**Aktueller Blocker:** Plan 23-04 (Screenshot-Export) wurde vom User deferred. Plan 23-07 kann erst laufen, wenn die PNGs existieren. Alternativ: `--skip-screenshots` für Metadaten-Only-Submission, dann Screenshots später nachziehen.
