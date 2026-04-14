---
phase: 23-screenshots-assets-submission-en-fr-de
plan: 02
status: complete
completed: 2026-04-14
tasks_completed: 2
commits:
  - 7354d25 feat(23-02): scaffold Next.js screenshot generator + html-to-image
  - c63e5e3 feat(23-02): apply StatFlow theme + 8 screens × 3 locales to generator
---

# Plan 23-02 Summary — Next.js Screenshot Generator Scaffold

## What was built

Lauffähiger Next.js-16-Generator mit StatFlow-Branding, bereit für Source-Screenshots
und 24 Export-Slots (8 Screens × 3 Locales). Folgt 1:1 dem Playbook-Rezept,
mit StatFlow-spezifischen THEME/COPY/LAYOUT-Anpassungen.

## Key files created

- `app-store/screenshots/generator/` — Next.js 16 + Tailwind 4 + TypeScript Projekt (47 packages)
- `app-store/screenshots/generator/src/app/page.tsx` (~500 Zeilen) — Generator mit 8 Screens × 3 Locales, 3 Layouts, StatFlow THEME
- `app-store/screenshots/generator/src/app/layout.tsx` — SF Pro Display Font-Stack, StatFlow-Titel
- `app-store/screenshots/generator/public/mockup.png` — iPhone 16 Pro Max Kit-Mockup (95 KB, aus ~/.claude/skills/app-store-screenshots/)
- `app-store/screenshots/generator/public/screenshots/{de,en,fr}/` — Runtime-Verzeichnisse (gitignored)

## Configuration

- **THEME:** `bgFrom=#FAFAF7`, `bgTo=#F0F0EC`, `textPrimary=#000000` — Off-White mit Schwarz (D-01/D-03)
- **SCREEN_IDS:** 01-dashboard, 02-details, 03-realtime, 04-vergleich, 05-events, 06-widget, 07-account-switcher, 08-start (D-04)
- **LAYOUT_ROTATION:** [headline-top, mock-left, mock-right, headline-top, mock-left, mock-right, headline-top, mock-left] (D-06)
- **Blob-Opazitäten:** Max 0.15 (reduziert von 0.55 im Reference) — Anti-Pattern-Fix für hellen Hintergrund
- **Dev-Port:** 3334 (Ports 3000 + 3333 lokal belegt)
- **Export-Button-Farbe:** Schwarz (war #3B87F6 im Reference — passt nicht zum StatFlow-Monochrom)

## Files modified

- `.gitignore` — Zusätzliche Regel für `app-store/screenshots/generator/public/screenshots/` (Runtime-Mirror)
- `app-store/screenshots/generator/package.json` — dev/start Scripts auf Port 3334 angepasst

## Deviations from plan

- **Plan erwartete Port 3333**, aber der war lokal belegt. Port 3334 genommen. STATE.md sollte das reflektieren; andere Pläne müssen den Port nicht kennen (nur zum Entwickeln relevant).
- **`public/screenshots/{de,en,fr}/` ist zusätzlich gitignored**, weil das ein Runtime-Spiegel der `app-store/screenshots/source/`-Shots ist (die auch gitignored sind per D-22). Der Plan hatte das nicht explizit, ergibt sich aber aus D-22.
- **mock-podest und mock-edge Layout-Branches komplett entfernt** (Playbook Anti-Pattern #3) — Layout-Typ nur noch `"headline-top" | "mock-left" | "mock-right"`.

## Verification

```
$ cd app-store/screenshots/generator && npx tsc --noEmit
# exit 0, no errors

$ grep-Checks:
OK: bgFrom=#FAFAF7, textPrimary=#000000, 01-dashboard, 08-start, "fr"
OK: 12 Layout-Vorkommen, 0 podest/edge

$ python3 opacity-check:
OK: 9 opacity values, max=0.15 (≤ 0.20 Schwelle)

$ bun dev (Port 3334):
✓ Ready in 354ms
HTTP 200 auf /
```

## Self-Check

- [x] Next.js 16 scaffold erzeugt (47 packages)
- [x] html-to-image installiert
- [x] mockup.png in public/ kopiert
- [x] public/screenshots/{de,en,fr}/ angelegt
- [x] TypeScript kompiliert ohne Fehler
- [x] THEME auf StatFlow-Off-White
- [x] 8 SCREEN_IDS + 3 Locales = 24 SLIDES
- [x] Blob-Opazitäten ≤ 0.20
- [x] mock-podest/mock-edge entfernt
- [x] Dev-Server startet auf Port 3334

## Ready for next

- **Plan 23-03:** COPY-Platzhalter mit echten DE/EN/FR-Texten befüllen
- **Plan 23-04:** Source-Screenshots vom Simulator → `public/screenshots/de/` → Export-Button klicken → 24 PNGs
