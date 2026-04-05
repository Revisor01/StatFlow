# Phase 3: Code-Organisation - Research

**Researched:** 2026-04-04
**Domain:** Swift/SwiftUI code refactoring (ViewModel extraction, DI, structured logging, safety)
**Confidence:** HIGH

## Summary

This phase covers four refactoring requirements across the InsightFlow iOS app. The codebase has 8 files with embedded ViewModels (classes defined inside View files), 88 `print()` statements (all already wrapped in `#if DEBUG`), direct `UmamiAPI.shared`/`PlausibleAPI.shared` references in all ViewModels, and 2 force unwraps in KeychainService.swift.

The `AnalyticsProvider` protocol already exists and is well-defined. Five ViewModels already live in their own files (LoginViewModel, WebsiteDetailViewModel, CompareViewModel, EventsViewModel, ReportsViewModel). The remaining 8 embedded ViewModels need extraction. The DI pattern is straightforward: add an `api` init parameter with default `.shared` value.

**Primary recommendation:** Extract ViewModels first (REFACTOR-03), then add DI (REFACTOR-04), then logging (REFACTOR-06), then fix force unwraps (SEC-01). This order minimizes merge conflicts between tasks.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
None explicitly locked -- all implementation choices at Claude's discretion (infrastructure phase).

### Claude's Discretion
All implementation choices. Important context:
- Phase 1 added loadingTask pattern to all ViewModels
- Phase 2 extracted Error+Network.swift and DateFormatters.swift
- ViewModels embedded in View files need extraction

### Deferred Ideas (OUT OF SCOPE)
None.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REFACTOR-03 | ViewModels in eigene Dateien extrahieren | Exact ViewModel locations, line ranges, and LOC counts documented below |
| REFACTOR-04 | Dependency Injection fuer ViewModels | AnalyticsProvider protocol exists; all ViewModel API references catalogued |
| REFACTOR-06 | Strukturiertes Logging (print -> os.Logger) | All 88 print() statements catalogued by file and category |
| SEC-01 | Force Unwraps in KeychainService entfernen | Exact lines 18 and 89 identified with fix pattern |
</phase_requirements>

## REFACTOR-03: ViewModel Extraction - Detailed Analysis

### Current File Sizes (main repo, post Phase 1+2)

| File | Current LOC | Embedded ViewModels | ViewModel Line Range | Est. View-only LOC |
|------|-------------|--------------------|-----------------------|---------------------|
| DashboardView.swift | 1205 | DashboardViewModel | 796-1205 (410 LOC) | ~795 |
| SettingsView.swift | 753 | SettingsViewModel | 592-753 (162 LOC) | ~591 |
| SessionsView.swift | 724 | SessionsViewModel, SessionDetailViewModel, JourneyViewModel | 480-724 (245 LOC) | ~479 |
| RealtimeView.swift | 668 | RealtimeViewModel, LiveEventDetailViewModel | 306-668 (363 LOC) | ~305 |
| AdminView.swift | 522 | AdminViewModel | 252-522 (271 LOC) | ~251 |
| RetentionView.swift | 451 | RetentionViewModel | 363-451 (89 LOC) | ~362 |
| InsightsView.swift | 358 | ComparisonViewModel | 287-358 (72 LOC) | ~286 |
| PagesView.swift | 290 | PagesViewModel | 142-290 (149 LOC) | ~141 |

### Files Already with Separate ViewModels (NO extraction needed)

| File | LOC | ViewModel File |
|------|-----|----------------|
| WebsiteDetailViewModel.swift | 435 | Already separate |
| CompareViewModel.swift | 402* | Already separate (in Views/Detail/) |
| EventsViewModel.swift | 366* | Already separate (in Views/Events/) |
| ReportsViewModel.swift | varies | Already separate (in Views/Reports/) |
| LoginViewModel.swift | varies | Already separate (in Views/Auth/) |

*LOC includes only the ViewModel file itself

### Extraction Plan: New Files to Create

| New File | Source | Classes to Move | Destination Directory |
|----------|--------|----------------|----------------------|
| DashboardViewModel.swift | DashboardView.swift | DashboardViewModel | Views/Dashboard/ |
| SettingsViewModel.swift | SettingsView.swift | SettingsViewModel | Views/Settings/ |
| SessionsViewModel.swift | SessionsView.swift | SessionsViewModel, SessionDetailViewModel, JourneyViewModel | Views/Sessions/ |
| RealtimeViewModel.swift | RealtimeView.swift | RealtimeViewModel, LiveEventDetailViewModel | Views/Realtime/ |
| AdminViewModel.swift | AdminView.swift | AdminViewModel | Views/Admin/ |
| RetentionViewModel.swift | RetentionView.swift | RetentionViewModel | Views/Reports/ |
| ComparisonViewModel.swift | InsightsView.swift | ComparisonViewModel | Views/Reports/ |
| PagesViewModel.swift | PagesView.swift | PagesViewModel | Views/Reports/ |

### Post-Extraction LOC Compliance Check

| File | Post-extraction LOC | Under 500? |
|------|---------------------|------------|
| DashboardView.swift | ~795 | NO -- needs further splitting or is acceptable as pure View |
| SettingsView.swift | ~591 | NO -- slightly over |
| SessionsView.swift | ~479 | YES |
| RealtimeView.swift | ~305 | YES |
| AdminView.swift | ~251 | YES |
| RetentionView.swift | ~362 | YES |
| InsightsView.swift | ~286 | YES |
| PagesView.swift | ~141 | YES |

**Note:** DashboardView.swift (795 LOC) and SettingsView.swift (591 LOC) will still exceed 500 LOC after ViewModel extraction. DashboardView contains substantial View helper structs (WebsiteCardView etc.) and the add-account sheet logic. SettingsView similarly contains many sub-sections. The requirement says "except API services" -- the planner should decide whether large View files also get an exception or need further splitting.

## REFACTOR-04: Dependency Injection Analysis

### AnalyticsProvider Protocol

Already exists at `InsightFlow/Services/AnalyticsProvider.swift` (line 130). Well-defined with 20+ methods covering auth, websites, stats, realtime, pages, metrics.

### Current API Access Pattern in ViewModels

All ViewModels use direct singleton access:

| ViewModel | API References |
|-----------|---------------|
| DashboardViewModel | `umamiAPI = UmamiAPI.shared`, `plausibleAPI = PlausibleAPI.shared` |
| SessionsViewModel | `api = UmamiAPI.shared` |
| SessionDetailViewModel | `api = UmamiAPI.shared` |
| JourneyViewModel | `api = UmamiAPI.shared` |
| RealtimeViewModel | `umamiAPI = UmamiAPI.shared`, `plausibleAPI = PlausibleAPI.shared` |
| LiveEventDetailViewModel | `api = UmamiAPI.shared` |
| SettingsViewModel | `umamiAPI = UmamiAPI.shared`, `plausibleAPI = PlausibleAPI.shared` |
| AdminViewModel | `umamiAPI = UmamiAPI.shared`, `plausibleAPI = PlausibleAPI.shared` |
| RetentionViewModel | `api = UmamiAPI.shared` |
| PagesViewModel | `api = UmamiAPI.shared` |
| ComparisonViewModel | `api = UmamiAPI.shared` |
| WebsiteDetailViewModel | (already separate -- needs DI too) |
| CompareViewModel | `umamiAPI = UmamiAPI.shared`, `plausibleAPI = PlausibleAPI.shared` |
| EventsViewModel | `api = UmamiAPI.shared` |
| ReportsViewModel | `api = UmamiAPI.shared` |
| LoginViewModel | Direct `UmamiAPI.shared.login()`, `PlausibleAPI.shared.authenticate()` |

### DI Pattern Design

Two categories of ViewModels:

**Single-provider VMs** (only use UmamiAPI): SessionsViewModel, SessionDetailViewModel, JourneyViewModel, LiveEventDetailViewModel, RetentionViewModel, PagesViewModel, ComparisonViewModel, EventsViewModel, ReportsViewModel

Pattern:
```swift
class SessionsViewModel: ObservableObject {
    let websiteId: String
    private let api: UmamiAPI

    init(websiteId: String, api: UmamiAPI = .shared) {
        self.websiteId = websiteId
        self.api = api
    }
}
```

**Dual-provider VMs** (use both UmamiAPI and PlausibleAPI): DashboardViewModel, RealtimeViewModel, SettingsViewModel, AdminViewModel, CompareViewModel

Pattern:
```swift
class DashboardViewModel: ObservableObject {
    private let umamiAPI: UmamiAPI
    private let plausibleAPI: PlausibleAPI

    init(umamiAPI: UmamiAPI = .shared, plausibleAPI: PlausibleAPI = .shared) {
        self.umamiAPI = umamiAPI
        self.plausibleAPI = plausibleAPI
    }
}
```

**Note:** The requirement says "accept `AnalyticsProvider` via init parameter" but the actual code uses concrete types (UmamiAPI, PlausibleAPI) because ViewModels call provider-specific methods (e.g., `umamiAPI.getWebsites()`, `plausibleAPI.getSites()`). Using the protocol would require adding all methods to the protocol or casting. The pragmatic approach is to inject concrete types with default `.shared` values. This still enables testing via subclassing or protocol conformance of mock types.

### Existing Tests That Instantiate ViewModels

- `DashboardViewModelTests.swift`: Creates `DashboardViewModel()` directly -- will need update if init signature changes (but default values keep it backward-compatible)
- `WebsiteDetailViewModelTests.swift`: Creates `WebsiteDetailViewModel` -- same consideration

## REFACTOR-06: Structured Logging Analysis

### Current State

- **Total print() statements:** 88
- **All wrapped in `#if DEBUG`:** YES (87 `#if DEBUG` blocks, one block in NotificationManager wraps 2 prints)
- **No `os.Logger` usage anywhere in codebase**
- **No `import os` in any file**

### Print Statements by Category

| Category | Count | Files |
|----------|-------|-------|
| **api** | 7 | UmamiAPI.swift (5), PlausibleAPI.swift (2) |
| **cache** | 9 | AnalyticsCacheService.swift (9) |
| **auth** | 17 | AccountManager.swift (9), SharedCredentials.swift (8) |
| **ui** | 55 | WebsiteDetailViewModel (17), ReportsViewModel (7), DashboardView (5), SessionsView (4), EventsViewModel (3), RealtimeView (3), PagesView (2), AdminView (2), CompareViewModel (2), other Views (10) |

**Total: 88** (matches requirement)

### os.Logger Pattern

```swift
import os

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "de.godsapp.statflow"

    static let api = Logger(subsystem: subsystem, category: "api")
    static let cache = Logger(subsystem: subsystem, category: "cache")
    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let ui = Logger(subsystem: subsystem, category: "ui")
}
```

Usage replaces `#if DEBUG print(...)`:
```swift
// Before:
#if DEBUG
print("AnalyticsCacheService: Saved \(key)")
#endif

// After:
Logger.cache.debug("Saved \(key)")
```

**Key advantages:**
- No `#if DEBUG` needed -- `os.Logger` at `.debug` level is automatically stripped in release builds (zero overhead)
- Filterable in Console.app by subsystem and category
- Privacy-safe with `\(value, privacy: .private)` for sensitive data
- Available since iOS 14 (no minimum deployment target concern)

### Migration Notes

- ALL existing prints are error/debug logging in catch blocks or diagnostic output
- No prints are user-facing or functional -- purely diagnostic
- The `#if DEBUG` wrapping can be removed when switching to `Logger.debug()` since debug-level messages are compiled out of release builds
- Some prints contain interpolated error descriptions -- use `\(error.localizedDescription)` in Logger

## SEC-01: Force Unwrap Analysis

### Exact Locations

**File:** `InsightFlow/Services/KeychainService.swift`

| Line | Code | Risk |
|------|------|------|
| 18 | `let data = value.data(using: .utf8)!` | Crash if value contains invalid UTF-8 sequences (unlikely for user-entered strings but possible for corrupted data) |
| 89 | `let data = value.data(using: .utf8)!` | Same issue in `saveCredential` method |

### Fix Pattern

```swift
// Line 18 - save(_ value:for:)
static func save(_ value: String, for key: Key) throws {
    guard let data = value.data(using: .utf8) else {
        throw KeychainError.encodingFailed
    }
    // ... rest unchanged
}

// Line 89 - saveCredential(_:type:accountId:)
static func saveCredential(_ value: String, type: CredentialType, accountId: String) throws {
    guard let data = value.data(using: .utf8) else {
        throw KeychainError.encodingFailed
    }
    // ... rest unchanged
}
```

Add to `KeychainError`:
```swift
enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Keychain Speicherfehler: \(status)"
        case .encodingFailed:
            return "Wert konnte nicht als UTF-8 kodiert werden"
        }
    }
}
```

**Impact:** Both `save` and `saveCredential` already `throws`, so callers already handle errors. Adding a new error case is fully backward-compatible. No caller changes needed.

### Existing Tests

`KeychainServiceTests.swift` (84 LOC) covers save/load/delete/overwrite/isolation scenarios. The force unwrap fix does not change test behavior since test inputs are valid UTF-8 strings. One additional test for the error case is recommended.

## Architecture Patterns

### Recommended File Organization (post-refactor)

```
InsightFlow/
  Views/
    Dashboard/
      DashboardView.swift          (~795 LOC - large View)
      DashboardViewModel.swift     (~410 LOC - NEW)
      WebsiteCard.swift
      AddUmamiSiteView.swift
      AddPlausibleSiteView.swift
    Sessions/
      SessionsView.swift           (~479 LOC)
      SessionsViewModel.swift      (~245 LOC - NEW, 3 classes)
    Realtime/
      RealtimeView.swift           (~305 LOC)
      RealtimeViewModel.swift      (~363 LOC - NEW, 2 classes)
    Settings/
      SettingsView.swift           (~591 LOC - slightly over 500)
      SettingsViewModel.swift      (~162 LOC - NEW)
    Admin/
      AdminView.swift              (~251 LOC)
      AdminViewModel.swift         (~271 LOC - NEW)
    Reports/
      RetentionView.swift          (~362 LOC)
      RetentionViewModel.swift     (~89 LOC - NEW)
      InsightsView.swift           (~286 LOC)
      ComparisonViewModel.swift    (~72 LOC - NEW)
      PagesView.swift              (~141 LOC)
      PagesViewModel.swift         (~149 LOC - NEW)
      ReportsViewModel.swift       (already separate)
      ReportsHubView.swift
      ReportDetailViews.swift
    Detail/
      WebsiteDetailViewModel.swift (already separate)
      CompareViewModel.swift       (already separate)
    Events/
      EventsViewModel.swift        (already separate)
    Auth/
      LoginViewModel.swift         (already separate)
  Extensions/
    Logger+App.swift               (NEW - Logger extension)
  Services/
    KeychainService.swift          (fix force unwraps)
```

### Anti-Patterns to Avoid
- **Extracting and changing logic at the same time:** Only move code, do not refactor logic during extraction. Functional changes come in separate commits.
- **Breaking `@StateObject` initialization:** When extracting ViewModels, the View's `@StateObject var viewModel = SomeViewModel()` must still compile with the same init signature (default parameters ensure this).
- **Over-abstracting DI:** Don't introduce a DI container or property wrapper framework. Simple init injection with defaults is sufficient for this codebase.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Structured logging | Custom Logger wrapper | `os.Logger` (Foundation) | Apple's native solution, zero-cost in release, Console.app integration |
| DI container | Service locator or container | Init parameter injection with defaults | Overkill for this codebase size, adds unnecessary complexity |

## Common Pitfalls

### Pitfall 1: Xcode Project File Conflicts
**What goes wrong:** Adding new files requires updating the `.xcodeproj/project.pbxproj` file. If done in parallel tasks, merge conflicts are guaranteed.
**Why it happens:** pbxproj is a single file with UUIDs for every source reference.
**How to avoid:** Either (a) do all file additions in a single task/commit, or (b) have each extraction task also handle the pbxproj update, accepting potential conflicts.
**Warning signs:** Build fails with "file not found" after extraction.

### Pitfall 2: Missing Imports After Extraction
**What goes wrong:** The extracted ViewModel file may need imports that were in the original View file (Foundation, SwiftUI types used in ViewModel, model types).
**Why it happens:** ViewModels embedded in View files inherit the file's imports implicitly.
**How to avoid:** Each extracted ViewModel file needs `import Foundation` at minimum. If it uses `@Published` it needs `import Combine` or `import SwiftUI`. Check for model type references.
**Warning signs:** Compiler errors about undeclared types.

### Pitfall 3: Logger Privacy in Sensitive Contexts
**What goes wrong:** Logging user data (account names, URLs, tokens) without privacy annotation exposes it in device logs.
**Why it happens:** `os.Logger` redacts dynamic values by default in release, but developers may use `.public` for debugging convenience.
**How to avoid:** Use default privacy (redacted) for all user data. Only use `.public` for static strings and non-sensitive identifiers.
**Warning signs:** Sensitive data visible in Console.app from other apps.

## Code Examples

### Logger Extension (to create as new file)
```swift
// InsightFlow/Extensions/Logger+App.swift
import os

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "de.godsapp.statflow"

    /// API calls and responses (UmamiAPI, PlausibleAPI)
    static let api = Logger(subsystem: subsystem, category: "api")
    /// Cache operations (AnalyticsCacheService)
    static let cache = Logger(subsystem: subsystem, category: "cache")
    /// Authentication and account management
    static let auth = Logger(subsystem: subsystem, category: "auth")
    /// UI and ViewModel operations
    static let ui = Logger(subsystem: subsystem, category: "ui")
}
```

### ViewModel DI Pattern (verified against existing code)
```swift
// Single-provider example
@MainActor
class SessionsViewModel: ObservableObject {
    let websiteId: String
    private let api: UmamiAPI

    init(websiteId: String, api: UmamiAPI = .shared) {
        self.websiteId = websiteId
        self.api = api
    }
    // ... methods unchanged
}

// Dual-provider example
@MainActor
class DashboardViewModel: ObservableObject {
    private let umamiAPI: UmamiAPI
    private let plausibleAPI: PlausibleAPI
    private let cache: AnalyticsCacheService

    init(umamiAPI: UmamiAPI = .shared,
         plausibleAPI: PlausibleAPI = .shared,
         cache: AnalyticsCacheService = .shared) {
        self.umamiAPI = umamiAPI
        self.plausibleAPI = plausibleAPI
        self.cache = cache
        loadWebsiteOrder()
    }
    // ... methods unchanged
}
```

### KeychainService Fix
```swift
static func save(_ value: String, for key: Key) throws {
    guard let data = value.data(using: .utf8) else {
        throw KeychainError.encodingFailed
    }
    // ... rest unchanged
}
```

## Open Questions

1. **DashboardView.swift remains ~795 LOC after extraction**
   - What we know: The View file itself has substantial UI code (cards, sheets, helpers)
   - What's unclear: Whether 500 LOC limit applies to View files or only to files containing both View + ViewModel
   - Recommendation: Accept DashboardView at ~795 LOC for now. Further splitting would require extracting sub-views into separate files (AddAccountSheet, etc.) which is a larger refactor. The requirement "no file > 500 LOC except API services" may need an additional exception for large View files.

2. **SettingsView.swift at ~591 LOC after extraction**
   - Similar situation, slightly over 500 LOC
   - Recommendation: Accept at 591 LOC or extract sub-sections (appearance settings, notification settings) into separate View files as stretch goal.

3. **LoginViewModel uses API directly, not via stored property**
   - LoginViewModel calls `UmamiAPI.shared.login()` and `PlausibleAPI.shared.authenticate()` inline
   - Recommendation: Add DI to LoginViewModel as well for consistency, even though it's already in its own file.

## Sources

### Primary (HIGH confidence)
- Direct codebase analysis via file reads and grep
- All line numbers, LOC counts, and code patterns verified against current `main` branch

### Secondary (MEDIUM confidence)
- Apple `os.Logger` documentation -- `Logger` struct available since iOS 14, debug-level messages have zero runtime overhead in release builds

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - pure refactoring, no new dependencies except `import os` (built-in)
- Architecture: HIGH - patterns derived directly from existing codebase conventions
- Pitfalls: HIGH - based on direct analysis of Xcode project structure and Swift compilation rules

**Research date:** 2026-04-04
**Valid until:** 2026-05-04 (stable -- refactoring patterns don't change)
