# Phase 16: UI & Layout Fixes - Research

**Researched:** 2026-03-28
**Domain:** SwiftUI Layout, SF Symbols, Localization
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
None — all implementation choices are at Claude's discretion.

### Claude's Discretion
All implementation choices are at Claude's discretion — UI fix phase. Use ROADMAP success criteria and codebase conventions to guide decisions.

### Deferred Ideas (OUT OF SCOPE)
None.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DASH-01 | Die 4 Dashboard-Kacheln (Sessions, Vergleich, Events, Reports) sollen exakt gleich groß sein — Events-Kachel ist aktuell zu hoch | QuickActionCard has no fixed height; LazyVGrid rows auto-size to tallest cell. Fix: add `.frame(maxHeight: .infinity)` on cards + `alignment: .top` on grid |
| SET-01 | Doppelte Chevrons bei "Analytics einrichten" und "Analytics Glossar" entfernen (nur ein Chevron) | Root cause confirmed: NavigationLink in List auto-adds disclosure indicator; code also manually appends `Image(systemName: "chevron.right")` inside the label — duplicate |
| SET-02 | Taube/Dove-Icon wird nicht angezeigt — Ursache finden und beheben | `dove.fill` used in logoutSection footer. Likely a rendering issue: symbol is valid but may be invisible due to `.foregroundStyle(.secondary)` stacking with the footer's own secondary style, OR the symbol name is incorrect for the deployment target |
| NOTIF-01 | Beschreibungstexte bei den Benachrichtigungs-Einstellungen klarer und verständlicher formulieren | Current DE strings identified: footer, stats picker label, auto-description. Need rewording for clarity |
</phase_requirements>

## Summary

Phase 16 fixes four visual inconsistencies in the StatFlow iOS app (iOS 18.0+ deployment target). All issues are pure UI/layout/string edits — no new screens, no API changes, no architecture decisions needed.

The four bugs are all well-understood after code inspection: (1) `QuickActionCard` components in a `LazyVGrid` do not share equal heights because no height alignment is enforced — the Events card's German subtitle "Benutzerdefinierte Events" may or may not wrap, but the real fix is using `alignment: .topLeading` and `.frame(maxHeight: .infinity)` so cells stretch uniformly; (2) `NavigationLink` inside a `List` automatically renders a trailing disclosure chevron — the SettingsView code for "Analytics einrichten" and "Analytics Glossar" additionally includes an explicit `Image(systemName: "chevron.right")` inside the label, producing two chevrons; (3) the dove icon (`Image(systemName: "dove.fill")`) in the logout footer has double `.foregroundStyle(.secondary)` applied (from the parent VStack and from the symbol itself) making it nearly invisible on certain backgrounds; (4) several notification description strings in German are technically correct but verbose or cryptic.

**Primary recommendation:** All four fixes are surgical edits to existing views/strings — no new files needed.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 18+ | Declarative UI layout | Project uses SwiftUI throughout |
| SF Symbols | 6.x (iOS 18) | System icons | Used for all iconography in the app |

No additional packages required for this phase.

## Architecture Patterns

### Existing Project Structure (relevant files)
```
InsightFlow/Views/Detail/
├── WebsiteDetailView.swift        # Contains quickActionsSection with LazyVGrid + QuickActionCard
├── WebsiteDetailSupportingViews.swift  # Contains QuickActionCard struct definition
Settings/
├── SettingsView.swift             # Contains aboutSection (double chevron), logoutSection (dove)
Resources/de.lproj/
├── Localizable.strings            # German notification strings (NOTIF-01)
Resources/en.lproj/
├── Localizable.strings            # English notification strings (NOTIF-01)
```

### Pattern: Equal-height grid cells in LazyVGrid
**What:** SwiftUI's `LazyVGrid` sizes each row to the tallest cell in that row. If cells in the same row have different content heights, the shorter cell does not expand to match.
**Fix pattern:**
```swift
// In QuickActionCard:
.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
// On the NavigationLink (cell wrapper), keep .buttonStyle(.plain) but also ensure
// the grid itself uses GridItem with alignment .top
LazyVGrid(columns: [GridItem(.flexible(), alignment: .top), GridItem(.flexible(), alignment: .top)], spacing: 12)
```

### Pattern: NavigationLink in List — no manual chevron
**What:** SwiftUI `List` automatically renders a trailing disclosure indicator for `NavigationLink` rows. Adding a manual `Image(systemName: "chevron.right")` inside the label produces a duplicate.
**Fix pattern:**
```swift
// BEFORE (double chevron):
NavigationLink {
    AnalyticsGlossaryView()
} label: {
    HStack {
        Label(...)
        Spacer()
        Image(systemName: "chevron.right")   // <-- REMOVE THIS
            .font(.caption)
            .foregroundStyle(.tertiary)
    }
}

// AFTER (single chevron — automatic from List):
NavigationLink {
    AnalyticsGlossaryView()
} label: {
    Label(...)
}
```

Note: The "Analytics einrichten" (SetupGuideView) link is in `aboutSection` at line 302. The "Analytics Glossar" (AnalyticsGlossaryView) link is at line 314. Both have the manual chevron inside HStack — both need fixing.

### Pattern: SF Symbol foreground color in footer
**What:** The logout footer VStack has `.foregroundStyle(.secondary)` applied to the whole container. The dove image additionally has no explicit foreground style (it inherits `.secondary`). In a `Section` footer inside a `List`, SwiftUI already renders footer text in tertiary/secondary color — stacking another secondary modifier may make the symbol invisible.
**Fix pattern:**
```swift
// BEFORE:
Image(systemName: "dove.fill")
    .foregroundStyle(.secondary)   // stacks on parent secondary

// AFTER option A — explicit color:
Image(systemName: "dove.fill")
    .foregroundStyle(.primary)

// AFTER option B — confirm symbol name, use tint:
Image(systemName: "dove.fill")
    .foregroundStyle(Color.accentColor)
```

If `dove.fill` renders as blank/nil (symbol not found), the fallback is `bird.fill` (available since SF Symbols 4 / iOS 16) or `leaf.fill`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Equal grid heights | Custom height-matching logic or GeometryReader hacks | `.frame(maxHeight: .infinity)` + GridItem alignment | Native SwiftUI grid alignment handles this cleanly |
| Chevron indicator | Custom trailing accessory view | Remove manual chevron, let List handle it | List's automatic disclosure indicator is platform-correct |

## Common Pitfalls

### Pitfall 1: LazyVGrid height alignment
**What goes wrong:** Adding `.frame(maxHeight: .infinity)` to the card without setting the background to fill the full frame — the card body grows but the background doesn't, creating visual gaps.
**How to avoid:** Ensure `.background(...)` and `.clipShape(...)` modifiers come AFTER `.frame(maxWidth: .infinity, maxHeight: .infinity)`.

### Pitfall 2: Button wrapping NavigationLink loses chevron
**What goes wrong:** Some rows in `aboutSection` are `Button` (for `showOnboarding`) — those correctly add a manual chevron since `Button` doesn't auto-add one. Only `NavigationLink` auto-adds. Don't accidentally remove chevrons from Button rows.
**Warning signs:** "Einführung anzeigen" row uses `Button { showOnboarding = true }` — it MUST keep the manual chevron. Only the `NavigationLink` rows for SetupGuideView and AnalyticsGlossaryView need the manual chevron removed.

### Pitfall 3: Localizable.strings must be updated in both locales
**What goes wrong:** Updating only `de.lproj/Localizable.strings` and forgetting `en.lproj/Localizable.strings`.
**How to avoid:** Always edit both files simultaneously for any string key change.

### Pitfall 4: dove.fill symbol name
**What goes wrong:** Assuming `dove.fill` is invalid when the symbol might exist but just not render visibly.
**How to avoid:** Fix the foreground color first. If the image still doesn't show, test `Image(systemName: "dove.fill")` in isolation in a Preview. If nil, use `bird.fill` (available iOS 16+, within deployment target iOS 18).

## Code Examples

### DASH-01: QuickActionCard equal height fix
```swift
// Source: WebsiteDetailSupportingViews.swift — QuickActionCard body
var body: some View {
    VStack(alignment: .leading, spacing: 8) {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
        Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)  // KEY: maxHeight
    .background(Color(.secondarySystemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: 16))
}

// In WebsiteDetailView quickActionsSection:
LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
    // ... NavigationLinks with .buttonStyle(.plain)
}
// Note: GridItem alignment defaults to .center — may need to verify
// if cards still differ, wrap each NavigationLink in a view with .frame(maxHeight: .infinity)
```

### SET-01: Remove duplicate chevron
```swift
// Source: SettingsView.swift — aboutSection, lines 302-324

// SetupGuideView link — REMOVE the HStack + Spacer + chevron:
NavigationLink {
    SetupGuideView()
} label: {
    Label(String(localized: "setupGuide.settings.link"), systemImage: "doc.text.magnifyingglass")
}

// AnalyticsGlossaryView link — same fix:
NavigationLink {
    AnalyticsGlossaryView()
} label: {
    Label(String(localized: "glossary.settings.link"), systemImage: "book.closed")
}
```

### SET-02: Dove icon visibility fix
```swift
// Source: SettingsView.swift — logoutSection footer, line 399
// Current (invisible due to secondary-on-secondary):
Image(systemName: "dove.fill")
    .foregroundStyle(.secondary)

// Fix — remove inherited secondary, use explicit foreground:
Image(systemName: "dove.fill")
// No explicit foregroundStyle needed if parent VStack already has .secondary
// OR make it accent color for visibility:
    .foregroundStyle(.accent)
```

### NOTIF-01: Current German notification strings
```
// Current strings (de.lproj/Localizable.strings):
"settings.notifications.time" = "Uhrzeit";
"settings.notifications.stats" = "Statistiken";
"settings.notifications.stats.auto" = "Automatisch";
"settings.notifications.stats.auto.description" = "Vor 12 Uhr → Statistiken von gestern\nAb 12 Uhr → Statistiken von heute";
"settings.notifications.frequency" = "Häufigkeit";
"settings.notifications.footer %@" = "Erhalte tägliche oder wöchentliche Zusammenfassungen deiner Website-Statistiken um %@.";
```

Issues to address:
- `"settings.notifications.stats"` label ("Statistiken") is ambiguous — it's a picker for the date source, not which stats to show
- `"settings.notifications.stats.auto.description"` uses arrow notation (`→`) that reads awkwardly on small text
- `"settings.notifications.footer %@"` is wordy — could be more concise
- `"settings.notifications.frequency"` ("Häufigkeit") is correct but the label could be more descriptive in context

Suggested rewrites (for planner to finalize):
- `"settings.notifications.stats"` → `"Datenquelle"` (more accurate — it's about where the data comes from)
- `"settings.notifications.stats.auto.description"` → `"Vor 12 Uhr: Statistiken von gestern. Ab 12 Uhr: Statistiken von heute."` (cleaner punctuation)
- `"settings.notifications.footer %@"` → `"Täglich oder wöchentlich erhältst du eine Zusammenfassung deiner Website-Statistiken um %@."` (natural German word order)

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| Manual chevron in NavigationLink label | Remove manual chevron, rely on List disclosure indicator | Platform-correct behavior, single source of truth |
| Variable-height grid cells | `.frame(maxHeight: .infinity)` on card | Uniform card height without GeometryReader |

## Open Questions

1. **Exact cause of dove.fill rendering failure**
   - What we know: `Image(systemName: "dove.fill")` is at line 399 of SettingsView; it has `.foregroundStyle(.secondary)` inherited from parent; deployment target is iOS 18
   - What's unclear: Whether the symbol name itself is valid and the symbol simply isn't visible, or whether the name resolves to nil on this SDK
   - Recommendation: Fix the foreground style first (remove redundant `.secondary`). If the icon still doesn't appear in a Preview, replace with `bird.fill` or `leaf.fill` (both confirmed available iOS 16+). Since the project targets iOS 18 and builds with SDK 26.4, both alternatives are within range.

2. **Which exact cells cause DASH-01 height mismatch**
   - What we know: German subtitle "Benutzerdefinierte Events" (21 chars) vs "User Journey" (12 chars) vs "Zeitraum" (8 chars) — longer text may wrap on smaller device widths
   - What's unclear: Whether the issue occurs on all devices or only compact-width iPhones
   - Recommendation: Fix with `maxHeight: .infinity` on the card frame — this makes all cards equal height regardless of content.

## Environment Availability

Step 2.6: SKIPPED — phase is purely code/string edits with no external dependencies.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (Swift) |
| Config file | InsightFlow.xcodeproj (scheme: InsightFlow) |
| Quick run command | `xcodebuild test -project InsightFlow.xcodeproj -scheme InsightFlow -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` |
| Full suite command | Same — all tests are in `InsightFlowTests/` target |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DASH-01 | Cards render at equal height | Manual visual — no unit test applicable | — | N/A |
| SET-01 | Only one chevron visible on NavigationLink rows | Manual visual — no unit test applicable | — | N/A |
| SET-02 | Dove icon visible in footer | Manual visual — no unit test applicable | — | N/A |
| NOTIF-01 | Notification strings are clear and correct | Manual review + string file inspection | — | N/A |

All four requirements are visual/UI changes that cannot be meaningfully covered by XCTest unit tests. Verification is via simulator visual inspection.

### Sampling Rate
- **Per task commit:** Build succeeds without warnings (`xcodebuild build`)
- **Per wave merge:** All existing unit tests pass
- **Phase gate:** Visual inspection on iPhone simulator before `/gsd:verify-work`

### Wave 0 Gaps
None — no new test files required for this phase.

## Project Constraints (from CLAUDE.md)

No project `CLAUDE.md` found in `/Users/simonluthe/Documents/umami/`. No project-level directives to enforce.

Global `CLAUDE.md` directives relevant to this phase:
- Do not create documentation files unless explicitly requested
- Do not create files unless absolutely necessary — prefer editing existing files
- ALWAYS prefer editing an existing file to creating a new one

This phase requires editing exactly 3 existing files:
1. `InsightFlow/Views/Detail/WebsiteDetailSupportingViews.swift` (DASH-01)
2. `InsightFlow/Views/Settings/SettingsView.swift` (SET-01, SET-02)
3. `InsightFlow/Resources/de.lproj/Localizable.strings` + `en.lproj/Localizable.strings` (NOTIF-01)

## Sources

### Primary (HIGH confidence)
- Direct code inspection: `InsightFlow/Views/Detail/WebsiteDetailSupportingViews.swift` — `QuickActionCard` struct confirmed
- Direct code inspection: `InsightFlow/Views/Settings/SettingsView.swift` — double chevron pattern and dove icon location confirmed
- Direct code inspection: `InsightFlow/Resources/de.lproj/Localizable.strings` — current notification strings confirmed
- SwiftUI documentation (training knowledge, verified by code pattern): `NavigationLink` in `List` auto-adds disclosure indicator

### Secondary (MEDIUM confidence)
- [SF Symbols - Apple Developer](https://developer.apple.com/sf-symbols/) — general availability guidance
- [SF Symbols Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/sf-symbols) — usage patterns

### Tertiary (LOW confidence)
- `dove.fill` symbol validity: Could not definitively verify availability for iOS 18 deployment target via web search. Symbol name is used in existing compiled code (implies it was valid when last built), but may render invisibly due to color stacking. Fallback `bird.fill` is available iOS 16+.

## Metadata

**Confidence breakdown:**
- DASH-01 (card heights): HIGH — root cause confirmed in code, standard SwiftUI fix
- SET-01 (double chevron): HIGH — root cause confirmed in code, fix is trivial removal
- SET-02 (dove icon): MEDIUM — most likely a color stacking issue; symbol name may also need verification
- NOTIF-01 (string rewrites): HIGH — current strings confirmed, rewrites are editorial decisions

**Research date:** 2026-03-28
**Valid until:** 2026-04-28 (stable iOS/SwiftUI APIs)
