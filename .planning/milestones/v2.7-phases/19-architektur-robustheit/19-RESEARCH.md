# Phase 19: Architektur-Robustheit - Research

**Researched:** 2026-04-04
**Domain:** Swift/SwiftUI architecture refactoring (iOS)
**Confidence:** HIGH

## Summary

This phase addresses four concrete code quality issues: residual global account state switching, duplicated network error detection, wasteful DateFormatter allocations, and inappropriate LazyVStack usage with conditional content. All four issues are well-defined, localized in the codebase, and can be resolved with straightforward refactoring.

Phase 1 (Plan 03) already fixed the primary TASK-02 problem -- `loadAllAccountsData` no longer calls `setActiveAccount` in its loop. The remaining `setActiveAccount` calls are legitimate user-initiated actions (login, account picker, settings). TASK-02 appears fully resolved.

**Primary recommendation:** Extract `isNetworkError` as an `Error` extension, create a shared `DateFormatters` enum with static lets, and convert 3 LazyVStack usages to VStack.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
None -- all implementation choices are at Claude's discretion (infrastructure/refactoring phase).

Note: TASK-02 (Account-Switch) wurde teilweise in Phase 1 adressiert -- Plan 03 hat `configureProviderForAccount()` eingefuehrt. Phase 2 soll pruefen ob noch weitere Stellen betroffen sind.

### Claude's Discretion
All implementation choices are at Claude's discretion -- pure infrastructure/refactoring phase. Use ROADMAP phase goal, success criteria, and codebase conventions to guide decisions.

### Deferred Ideas (OUT OF SCOPE)
None -- infrastructure phase.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TASK-02 | Account-Switch ohne globalen Singleton-State | Verified: Phase 1 Plan 03 already resolved. All remaining setActiveAccount calls are user-initiated. No further work needed. |
| REFACTOR-01 | Network-Error-Detection deduplizieren | Found 5 identical isNetworkError blocks across 5 files. Extension on Error is the standard approach. |
| REFACTOR-02 | DateFormatter-Instanzen wiederverwenden | Found 30+ formatter allocations, ~15 in hot paths (computed properties, .map closures). Static let formatters needed. |
| REFACTOR-05 | LazyVStack-Audit | Found 8 LazyVStack usages. 3 should change to VStack (conditional content, small lists). 5 can stay. |
</phase_requirements>

## TASK-02: Account-Switch Analysis (FULLY RESOLVED)

### What Phase 1 Plan 03 Did
- Added `configureProviderForAccount()` to AccountManager (line 265) -- configures API without changing `activeAccount`, posting notifications, or reloading widgets
- Rewrote `loadAllAccountsData()` (line 868) to use `configureProviderForAccount` in both loops
- `setActiveAccount` called only once at end to restore original account

### Remaining setActiveAccount Calls (ALL LEGITIMATE)
| File | Line | Context | Legitimate? |
|------|------|---------|-------------|
| `LoginViewModel.swift` | 29, 60 | After successful login | YES -- user action |
| `SettingsView.swift` | 111, 741 | User picks account in settings | YES -- user action |
| `DashboardView.swift` | 66 | User taps website in all-accounts view | YES -- user action |
| `DashboardView.swift` | 284 | User switches account via picker | YES -- user action |
| `DashboardView.swift` | 723, 736 | Inline login flow | YES -- user action |
| `DashboardView.swift` | 921 | Restore original after loadAllAccountsData | YES -- single call at end |
| `InsightFlowApp.swift` | 55 | Deep link account switch | YES -- user action |
| `AccountManager.swift` | 114, 128 | Init: set first account | YES -- startup |
| `AccountManager.swift` | 490 | addAccount sets active | YES -- user action |

**Conclusion:** No remaining global state switches during iteration. TASK-02 is complete. No additional work needed in Phase 2.

## REFACTOR-01: isNetworkError Duplication

### All Occurrences (5 files, identical 5-line block)

| # | File | Line | Context |
|---|------|------|---------|
| 1 | `Views/Reports/ReportsViewModel.swift` | 63-67 | loadReports catch |
| 2 | `Views/Events/EventsViewModel.swift` | 49-53 | loadEvents catch (inside MainActor.run) |
| 3 | `Views/Sessions/SessionsView.swift` | 522-526 | loadSessions catch |
| 4 | `Views/Detail/WebsiteDetailViewModel.swift` | 91-95 | loadStats catch |
| 5 | `Views/Dashboard/DashboardView.swift` | 975-979 | loadData catch |

### The Duplicated Pattern
```swift
let isNetworkError = (error as? URLError)?.code == .notConnectedToInternet ||
                     (error as? URLError)?.code == .networkConnectionLost ||
                     (error as? URLError)?.code == .timedOut ||
                     (error as? URLError)?.code == .cannotFindHost ||
                     (error as? URLError)?.code == .cannotConnectToHost
if isNetworkError {
    self.isOffline = true
} else {
    self.error = error.localizedDescription
}
```

### Recommended Solution
Create `InsightFlow/Extensions/Error+Network.swift`:
```swift
extension Error {
    var isNetworkError: Bool {
        guard let urlError = self as? URLError else { return false }
        return [
            .notConnectedToInternet,
            .networkConnectionLost,
            .timedOut,
            .cannotFindHost,
            .cannotConnectToHost
        ].contains(urlError.code)
    }
}
```

Then each catch site becomes:
```swift
if error.isNetworkError {
    self.isOffline = true
} else {
    self.error = error.localizedDescription
}
```

**Confidence: HIGH** -- standard Swift pattern, no behavioral change.

## REFACTOR-02: DateFormatter Allocations

### Hot-Path Allocations (MUST FIX -- called per data point)

These computed properties create a new formatter on EVERY access:

| # | File | Line | Property/Context | Severity |
|---|------|------|------------------|----------|
| 1 | `Models/Stats.swift` | 107 | `TimeSeriesPoint.date` computed property | CRITICAL -- called per chart point (up to 365x) |
| 2 | `Models/Stats.swift` | 224 | `RealtimeEvent.createdDate` computed property | HIGH -- called per realtime event |
| 3 | `Models/Stats.swift` | 284 | `Session.firstDate` computed property | HIGH -- called per session |
| 4 | `Models/Stats.swift` | 291 | `Session.lastDate` computed property | HIGH -- called per session |
| 5 | `Models/Stats.swift` | 321 | `SessionEvent.createdDate` computed property | HIGH -- called per event |
| 6 | `Models/Stats.swift` | 342 | `RetentionRow.formattedDate` computed property | MEDIUM |
| 7 | `Models/Stats.swift` | 445 | `EventDetail.createdDate` computed property | HIGH -- called per event detail |

### Map/Closure Allocations (SHOULD FIX -- called once but in data-mapping context)

| # | File | Line | Context |
|---|------|------|---------|
| 8 | `Views/Detail/WebsiteDetailViewModel.swift` | 120 | loadPageviews `.map` |
| 9 | `Views/Detail/WebsiteDetailViewModel.swift` | 179 | fillMissingTimeSlots |
| 10 | `Views/Detail/CompareViewModel.swift` | 74 | loadData `.map` (4 arrays) |
| 11 | `Views/Detail/CompareChartSection.swift` | 420 | padDataToExpectedCount |
| 12 | `Views/Detail/CompareChartSection.swift` | 483 | padDataToExpectedCountB |
| 13 | `Views/Dashboard/DashboardView.swift` | 1021 | loadFromCache sparkline |
| 14 | `Views/Dashboard/DashboardView.swift` | 1129 | loadSparklineForWebsite |
| 15 | `Views/Dashboard/DashboardView.swift` | 1167 | fillMissingTimeSlots |

### One-Shot Allocations (LOW PRIORITY -- called once per action)

| # | File | Line | Context |
|---|------|------|---------|
| 16 | `Services/UmamiAPI.swift` | 28-30 | JSONDecoder dateDecodingStrategy (once per init) |
| 17 | `Services/UmamiAPI.swift` | 495 | parseTeam (once per parse) |
| 18 | `Services/UmamiAPI.swift` | 575 | isoDate helper |
| 19 | `Services/PlausibleAPI.swift` | 177, 204 | plausibleDateRange/previousDateRange |
| 20 | `Services/PlausibleAPI.swift` | 278, 281 | getTimeseries parsers |
| 21 | `Services/NotificationManager.swift` | 58 | notification formatting |
| 22 | `Models/DateRange.swift` | 64 | displayName |
| 23 | `Views/Sessions/SessionsView.swift` | 445 | session detail display |
| 24 | `Views/Reports/RetentionView.swift` | 278, 282, 288 | retention display |
| 25 | `Views/Realtime/RealtimeView.swift` | 575 | realtime display |
| 26 | `Views/Detail/CompareChartSection.swift` | 558 | monthName |
| 27 | `Views/Detail/CompareView.swift` | 217 | display |

### Widget Code (Separate Target)

| # | File | Line | Context |
|---|------|------|---------|
| 28 | `InsightFlowWidget/Views/WidgetChartViews.swift` | 34, 188 | chart formatting |
| 29 | `InsightFlowWidget/Networking/WidgetNetworking.swift` | 295, 379 | API parsing |

### Recommended Solution
Create `InsightFlow/Extensions/DateFormatters.swift`:
```swift
enum DateFormatters {
    /// ISO8601 with fractional seconds -- for Umami API dates
    static let iso8601WithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// ISO8601 standard -- fallback
    static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// yyyy-MM-dd for Plausible API
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// Short date style for UI display
    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        return f
    }()

    /// yyyy-MM-dd HH:mm:ss for Plausible hourly data
    static let yyyyMMddHHmmss: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
```

**Priority:** Fix items 1-7 first (computed properties -- called per data point). Items 8-15 second. Items 16-27 are nice-to-have. Items 28-29 are in a separate target and can be addressed later.

**Note on thread safety:** `ISO8601DateFormatter` is thread-safe. `DateFormatter` is thread-safe on iOS 7+ when used as read-only (which static lets are). This is safe.

**Confidence: HIGH** -- Apple documentation confirms DateFormatter allocation is expensive, static let is the standard pattern.

## REFACTOR-05: LazyVStack Audit

### All LazyVStack Usages

| # | File | Line | Content Type | Item Count | Conditional Content Inside? | Recommendation |
|---|------|------|-------------|------------|----------------------------|----------------|
| 1 | `DashboardView.swift` | 39 | WebsiteCard list | Variable (1-20+) | NO (conditional is OUTSIDE the LazyVStack) | **KEEP** -- homogeneous ForEach, can grow large with many websites |
| 2 | `AdminView.swift` | 111 | Website admin cards | Variable | NO (conditional is OUTSIDE in Group) | **KEEP** -- pure ForEach list |
| 3 | `AdminView.swift` | 134 | Plausible site cards | Variable | NO (conditional is OUTSIDE) | **KEEP** -- pure ForEach list |
| 4 | `AdminView.swift` | 173 | Team cards | Typically < 10 | NO (conditional is OUTSIDE) | **CHANGE to VStack** -- teams list is always small |
| 5 | `AdminView.swift` | 213 | User cards | Typically < 20 | NO (conditional is OUTSIDE) | **CHANGE to VStack** -- users list is always small |
| 6 | `SessionsView.swift` | 153 | Session/Journey list | Can be 50+ | NO | **KEEP** -- sessions can be a large paginated list |
| 7 | `EventsView.swift` | 41 | Event list + stats header | Variable | YES -- `if let stats` conditional inside | **CHANGE to VStack** -- has conditional content, risk of stale rendering |
| 8 | `ReportsHubView.swift` | 36 | Offline banner + LazyVGrid | Fixed ~6 items | YES -- `if viewModel.isOffline` conditional inside | **CHANGE to VStack** -- has conditional content, very few items |

### Classification Summary

| Action | Files | Count |
|--------|-------|-------|
| **CHANGE to VStack** | AdminView (teams, users), EventsView, ReportsHubView | 4 |
| **KEEP LazyVStack** | DashboardView, AdminView (websites, sites), SessionsView | 4 |

### Why Change Matters
LazyVStack defers view creation for off-screen items. When conditional content (if/else on ViewModel state) is inside a LazyVStack, the view may not re-render when state changes if the conditional view is off-screen. This was the root cause of a previously fixed bug. VStack eagerly evaluates all children, ensuring conditional content always reflects current state.

**Confidence: HIGH** -- documented SwiftUI behavior, verified against previous bug in this codebase.

## Architecture Patterns

### Recommended File Structure for New Files
```
InsightFlow/
  Extensions/
    View+Extensions.swift     (existing)
    Error+Network.swift        (NEW -- isNetworkError extension)
    DateFormatters.swift       (NEW -- shared static formatters)
```

### Pattern: Error Extension for Network Detection
**What:** Extend `Error` with a computed property for common checks
**When to use:** Any repeated error classification logic across ViewModels
**Source:** Standard Swift pattern

### Pattern: Static Let for Expensive Object Reuse
**What:** Use `static let` on an enum/struct for formatter instances
**When to use:** Any object expensive to construct that's used repeatedly with same configuration
**Source:** Apple Developer Documentation -- DateFormatter best practices

### Anti-Patterns to Avoid
- **Formatter in computed property:** Creating DateFormatter inside a computed property called per data point. Use static let instead.
- **Copy-paste error handling:** Identical catch blocks across files. Extract to extension.
- **LazyVStack with conditional content:** Use VStack when the content includes if/else/switch on state.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Network error classification | Inline URLError code checks | `Error.isNetworkError` extension | Single source of truth, easy to add new codes |
| Date parsing from ISO8601 | `let formatter = ISO8601DateFormatter()` per call | `DateFormatters.iso8601WithFractional` | Allocation cost multiplied by data points |

## Common Pitfalls

### Pitfall 1: DateFormatter Locale Sensitivity
**What goes wrong:** DateFormatter with dateFormat uses device locale by default, causing parsing failures on devices with non-Gregorian calendars
**Why it happens:** Missing `.locale = Locale(identifier: "en_US_POSIX")` on formatters with custom dateFormat
**How to avoid:** Always set locale to `en_US_POSIX` on formatters used for API date parsing (not display)
**Warning signs:** Dates parse as nil on certain device locales

### Pitfall 2: Thread Safety of Shared Formatters
**What goes wrong:** Crash when shared DateFormatter is mutated concurrently
**Why it happens:** Changing properties (dateFormat, locale) on a shared instance
**How to avoid:** Create separate static instances for each format. Never mutate after creation.
**Warning signs:** Intermittent crashes in date formatting

### Pitfall 3: VStack Performance with Large Lists
**What goes wrong:** Slow initial render when VStack has 100+ items
**Why it happens:** VStack evaluates all children eagerly
**How to avoid:** Only change to VStack for lists known to be small (< 50 items). Keep LazyVStack for sessions, websites.
**Warning signs:** Slow tab switches, high memory on list views

## Code Examples

### Error Extension Usage
```swift
// Before (duplicated 5x):
let isNetworkError = (error as? URLError)?.code == .notConnectedToInternet ||
                     (error as? URLError)?.code == .networkConnectionLost ||
                     (error as? URLError)?.code == .timedOut ||
                     (error as? URLError)?.code == .cannotFindHost ||
                     (error as? URLError)?.code == .cannotConnectToHost

// After:
if error.isNetworkError {
    self.isOffline = true
} else {
    self.error = error.localizedDescription
}
```

### DateFormatter Reuse
```swift
// Before (in Stats.swift computed properties):
var date: Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: x) ?? Date()
}

// After:
var date: Date {
    DateFormatters.iso8601WithFractional.date(from: x)
        ?? DateFormatters.iso8601.date(from: x)
        ?? Date()
}
```

### LazyVStack to VStack
```swift
// Before (EventsView.swift):
LazyVStack(spacing: 0) {
    if let stats = viewModel.eventStats {
        statsHeader(stats: stats)  // conditional content -- risk!
    }
    ForEach(viewModel.events) { ... }
}

// After:
VStack(spacing: 0) {
    if let stats = viewModel.eventStats {
        statsHeader(stats: stats)
    }
    ForEach(viewModel.events) { ... }
}
```

## Sources

### Primary (HIGH confidence)
- Codebase grep: all isNetworkError, DateFormatter, LazyVStack occurrences verified
- Phase 18 Plan 03 Summary: confirmed configureProviderForAccount implementation
- AccountManager.swift line 265: verified configureProviderForAccount exists and is used

### Secondary (MEDIUM confidence)
- Apple DateFormatter docs: allocation cost and thread safety
- SwiftUI LazyVStack documentation: deferred evaluation behavior

## Metadata

**Confidence breakdown:**
- TASK-02 status: HIGH -- verified all setActiveAccount call sites, all legitimate
- REFACTOR-01 (isNetworkError): HIGH -- exact line numbers for all 5 occurrences
- REFACTOR-02 (DateFormatter): HIGH -- all allocations catalogued with severity
- REFACTOR-05 (LazyVStack): HIGH -- all 8 usages classified with rationale

**Research date:** 2026-04-04
**Valid until:** 2026-05-04 (stable codebase patterns, unlikely to change)
