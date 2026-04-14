---
phase: 23-screenshots-assets-submission-en-fr-de
plan: 03
status: complete
completed: 2026-04-14
tasks_completed: 2
commits:
  - ae9857d feat(23-03): add French App Store localization to description.md
  - 398a4d3 feat(23-03): populate screenshot COPY for DE/EN/FR × 8 slides
---

# Plan 23-03 Summary — Copy Deliverables

## What was built

Zwei Copy-Deliverables für Phase 23: FR-Lokalisierung für App Store Connect
und screenshot COPY-Map (24 Claim/Subline-Paare) für den Generator.

## Key files created

- `app-store/screenshots/generator/src/app/copy.ts` (138 Zeilen) — 8 Slides × 3 Locales = 24 Copy-Slots, idiomatisch

## Files modified

- `app-store/description.md` — vollständiger FR-Block hinzugefügt (Subtitle, Keywords, Description, Promo, What's New)
- `app-store/screenshots/generator/src/app/page.tsx` — Placeholder-COPY-Block entfernt, Import aus `./copy`

## FR Char Counts (ASC limits)

| Field | Chars | Limit | Status |
|-------|-------|-------|--------|
| Subtitle | 25 | 30 | ✓ |
| Keywords | 97 | 100 | ✓ |
| Promotional Text | 145 | 170 | ✓ |
| Description | 2420 | 4000 | ✓ |

## Deviations from plan

- **FR-Keywords ursprünglich 101 Zeichen** (Plan sah 100 vor). `site web` zu `site` gekürzt → 97 Zeichen. `confidentialité` nutzt `é` (1 Zeichen in UTF-8-Chars, aber 2 Bytes — ASC zählt Zeichen).
- **page.tsx Import:** Nur `COPY` importiert (nicht zusätzlich `type Copy`, weil der Typ in page.tsx nicht direkt referenziert wird). copy.ts exportiert den Typ trotzdem, falls andere Module ihn brauchen.

## Copywriting Notes

- Slides 1-3 haben stärkste Hooks (D-07): "Deine Website. Immer im Blick.", "Tiefer graben. In Sekunden.", "Live dabei."
- Hybrid-Struktur durchgehalten: Claim behauptet, Subline liefert Substanz — keine Wiederholung
- FR: "tu"-Form durchgängig, FR-Vokabeln aus D-14: tableau de bord, statistiques, suivi

## Verification

```
$ npx tsc --noEmit        # exit 0
$ grep headline: copy.ts  # 27 matches (24 slots + 3 local in page.tsx layouts)
$ description.md FR: all 4 fields within ASC limits
```

## Self-Check

- [x] FR-Block vollständig in description.md
- [x] Alle FR-Felder innerhalb ASC-Limits
- [x] FR-What's-New zusätzlich zu dediziertem Block in "## What's New" ergänzt
- [x] copy.ts mit 24 Claim/Subline-Paaren
- [x] page.tsx importiert COPY aus ./copy
- [x] TypeScript kompiliert ohne Fehler
- [x] Keine 1:1-Übersetzungen (D-12) — jedes Locale idiomatisch

## Ready for next wave

Wave 1 ist komplett. Wave 2 kann starten:
- **Plan 23-04** (Wave 2, **checkpoint**): Source-Screenshots aus Simulator ziehen → Export-PNGs generieren
- **Plan 23-05** (Wave 2, autonom): ASC-Submission-Library (jwt.ts, asc-api.ts, config.ts)
