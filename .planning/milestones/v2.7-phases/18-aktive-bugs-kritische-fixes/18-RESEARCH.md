# Phase 18: Aktive Bugs & Kritische Fixes - Research

**Researched:** 2026-04-04
**Domain:** SwiftUI MVVM bug fixes, concurrency patterns, cache architecture
**Confidence:** HIGH

## Summary

This phase addresses four distinct issues in the StatFlow iOS app: a missing `@ObservedObject` annotation on CompareChartSection, a cache strategy that incorrectly preloads data when online, a widget account-sync race condition, and missing task cancellation guards in 12+ ViewModels. All four issues are well-understood from direct codebase inspection -- no external library research needed.

The codebase already contains a canonical reference pattern in `WebsiteDetailViewModel` with proper `loadingTask?.cancel()`, `Task.isCancelled` guards, and structured `withTaskGroup` usage. The fix strategy is to replicate this pattern across all other ViewModels.

**Primary recommendation:** Fix in order BUG-01 (trivial, one-line), TASK-01 (mechanical, high-impact), BUG-02 (architectural change to cache flow), BUG-03 (widget coordination).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
None -- all implementation choices at Claude's discretion (infrastructure/bugfix phase).

Key constraint from STATE.md: Cache dient ausschliesslich als Offline-Fallback. Wenn online -> immer frische API-Daten.

### Claude's Discretion
All implementation choices.

### Deferred Ideas (OUT OF SCOPE)
None.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BUG-01 | CompareChartSection @ObservedObject Fix | Line 5 of CompareChartSection.swift: `let viewModel: CompareViewModel` confirmed -- must be `@ObservedObject var viewModel` |
| BUG-02 | Cache nur fuer Offline | DashboardViewModel.loadData() calls loadFromCache() BEFORE API call at line 932 -- cache data shown as preview then potentially overwritten |
| BUG-03 | Widget Account-Sync Race Condition | AccountManager.setActiveAccount() is async but widget reads credentials from file -- timing gap identified |
| TASK-01 | Task-Cancellation in all ViewModels | 12 ViewModels found without loadingTask pattern, WebsiteDetailViewModel is canonical reference |
</phase_requirements>

## BUG-01: CompareChartSection @ObservedObject Audit

### Confirmed Bug

**File:** `InsightFlow/Views/Detail/CompareChartSection.swift`, line 5
```swift
// CURRENT (broken):
let viewModel: CompareViewModel

// FIX:
@ObservedObject var viewModel: CompareViewModel
```

CompareView (parent) owns `viewModel` via `@StateObject` (line 32 of CompareView.swift) and passes it to CompareChartSection. Since CompareChartSection reads `viewModel.pageviews1`, `viewModel.visitors1`, etc. in computed properties, changes to those `@Published` properties won't trigger a re-render with `let`.

### Full Audit: All Child Views Receiving ObservableObject

**CORRECTLY using `@ObservedObject`:**
| File | Line | Declaration | Status |
|------|------|-------------|--------|
| `WebsiteDetailChartSection.swift` | 5 | `@ObservedObject var viewModel: WebsiteDetailViewModel` | OK |
| `WebsiteDetailMetricsSections.swift` | 5 | `@ObservedObject var viewModel: WebsiteDetailViewModel` | OK |
| `WebsiteDetailView.swift` | 713 | `@ObservedObject var viewModel: WebsiteDetailViewModel` (FilterSelectionSheet) | OK |
| `AdminCards.swift` | 7, 113, 198, 245 | `@ObservedObject var viewModel: AdminViewModel` | OK |
| `AdminSheets.swift` | 6, 63, 99, 149, 266, 366, 427 | `@ObservedObject var viewModel: AdminViewModel` | OK |
| `SettingsView.swift` | 452 | `@ObservedObject var notificationManager: NotificationManager` | OK |

**BROKEN -- needs fix:**
| File | Line | Declaration | Fix |
|------|------|-------------|-----|
| `CompareChartSection.swift` | 5 | `let viewModel: CompareViewModel` | Change to `@ObservedObject var viewModel: CompareViewModel` |

**No other `let viewModel` patterns found** -- only CompareChartSection has this bug.

### CompareHeroCard Check

CompareHeroCard receives stats as value types (`WebsiteStats?`), not the ViewModel directly. No fix needed there.

**Confidence: HIGH** -- direct codebase inspection, single clear bug.

## BUG-02: Cache Architecture Redesign

### Current Flow (broken)

In `DashboardViewModel.loadData()` (line 917-976):
1. Line 932: `loadFromCache(dateRange:)` -- immediately populates `websites`, `sparklineData` from cache
2. Line 935+: API call to get fresh websites
3. Fresh websites overwrite cached websites
4. `loadWebsiteData()` fetches fresh stats/sparklines

**The problem:** Cache is preloaded at step 1 as a "preview", which:
- Flashes stale data before fresh data arrives
- If API partially fails, stale cached data persists in some fields

### Required New Flow

**When online:**
1. Set `isLoading = true`
2. Call API directly (no cache preload)
3. On success: update UI, save to cache
4. On failure: check if network error -> show offline banner

**When offline (network error detected):**
1. Load from cache as fallback
2. Show visual indicator: "Offline -- letzte Daten von [Zeitpunkt]"
3. Cache TTL: data > 24h should NOT be shown (requirement says 24h, current TTL is 1h for default, 15min for sparklines)

### Files to Modify

| File | Change |
|------|--------|
| `InsightFlow/Views/Dashboard/DashboardView.swift` (DashboardViewModel, line 917+) | Remove `loadFromCache()` call from main path; only call in catch block for network errors |
| `InsightFlow/Services/AnalyticsCacheService.swift` | Add `isExpired` check with 24h TTL for offline display; add `clearStaleEntries()` already exists (line 240); `evictOldestEntries()` already exists (line 264) but max is 100MB not 50MB |
| `InsightFlow/App/InsightFlowApp.swift` | Already calls `clearStaleEntries(olderThan: 7)` and `evictOldestEntries(maxSize: 100MB)` at launch |

### Current Cache Parameters vs Required

| Parameter | Current | Required |
|-----------|---------|----------|
| Default TTL | 1 hour | Keep for freshness, but add 24h offline-display TTL |
| Sparkline TTL | 15 min | Same as above |
| Stale cutoff | 7 days | Keep (cleanup) |
| Max cache size | 100 MB | 50 MB per requirement |
| `clearStaleEntries()` on start | Yes (7 days) | Yes |
| `evictOldestEntries()` on start | Yes (100MB) | Change threshold to 50MB |
| `isExpired` check on website list | Not used | Must check before displaying offline data |

### Offline Display

Need to expose `cachedAt` timestamp to the UI. `CachedData<T>` already has `cachedAt: Date` and `isExpired: Bool`. The DashboardViewModel needs a new `@Published var offlineCacheDate: Date?` to show "Offline -- letzte Daten von [Zeitpunkt]".

**Confidence: HIGH** -- direct codebase inspection, clear architectural change.

## BUG-03: Widget Account-Sync Race Condition

### Current Flow

In `AccountManager.setActiveAccount()` (line 165):
```swift
func setActiveAccount(_ account: AnalyticsAccount) async {
    activeAccount = account                           // 1. Update local state
    UserDefaults.standard.set(...)                     // 2. Persist
    await applyAccountCredentials(account)             // 3. Async: Keychain + API reconfig + widget sync
}
```

In `applyAccountCredentials()` (line 262):
1. Saves to Keychain (sync)
2. `await UmamiAPI.shared.reconfigureFromKeychain()` or `PlausibleAPI.shared.reconfigureFromKeychain()` (async actor call)
3. Sets `AnalyticsManager.shared.setProvider()`
4. Posts `.accountDidChange` notification
5. Calls `updateWidgetCredentials()` which writes encrypted file + `WidgetCenter.shared.reloadAllTimelines()`

### The Race Condition

When user switches accounts:
1. `setActiveAccount()` is called
2. Widget timeline might be refreshed by system BEFORE `applyAccountCredentials` finishes writing the new encrypted file
3. Widget reads OLD credentials from the file
4. Widget shows data from previous account

The `reloadAllTimelines()` at step 5 happens AFTER the file write, so theoretically the widget should get new data. But:
- The widget might already be in mid-refresh from a system-triggered reload
- There's no guarantee the file write is flushed before `reloadAllTimelines()` triggers the widget's `timeline()` call

### Fix Strategy

The widget's `fetchStats()` in `WidgetNetworking.swift` already uses account-based credential lookup (line 52+) rather than just reading the global credentials file. The issue is more likely in the DashboardViewModel's `loadAllAccountsData()` (line 856) which temporarily switches accounts in a loop:

```swift
for account in accounts {
    await AccountManager.shared.setActiveAccount(account)  // switches global state!
    // ... load data ...
}
// Restore original
if let original = originalAccount {
    await AccountManager.shared.setActiveAccount(original)
}
```

This loop switches the global active account for EACH account, which triggers widget reloads mid-loop. The fix should:
1. Not call `setActiveAccount` in the multi-account loop (or use a non-widget-triggering variant)
2. Ensure widget credential write completes fully before `reloadAllTimelines()`
3. Consider adding a version/timestamp to the shared file that the widget checks

**Confidence: MEDIUM** -- the race condition is plausible but hard to reproduce deterministically. The multi-account loop in `loadAllAccountsData()` is the most likely trigger.

## TASK-01: Task Cancellation Audit

### Reference Pattern (WebsiteDetailViewModel)

```swift
// File: InsightFlow/Views/Detail/WebsiteDetailViewModel.swift
private var loadingTask: Task<Void, Never>?

func loadData(dateRange: DateRange) async {
    loadingTask?.cancel()
    let task = Task {
        isLoading = true
        defer { if !Task.isCancelled { isLoading = false } }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadSomething() }
            // ...
        }
    }
    loadingTask = task
    await task.value
}

func cancelLoading() {
    loadingTask?.cancel()
    loadingTask = nil
}
```

Each sub-method uses:
```swift
guard !Task.isCancelled else { return }
```
after every `await` before writing to `@Published` properties.

### Complete ViewModel Inventory

| ViewModel | File | Has `loadingTask`? | Has `Task.isCancelled`? | Needs Fix |
|-----------|------|--------------------|-------------------------|-----------|
| `WebsiteDetailViewModel` | `Views/Detail/WebsiteDetailViewModel.swift` | YES | YES (35 guards) | NO (reference) |
| `DashboardViewModel` | `Views/Dashboard/DashboardView.swift:791` | NO | YES (in sub-methods only) | YES -- needs loadingTask for loadData/loadAllAccountsData |
| `CompareViewModel` | `Views/Detail/CompareViewModel.swift` | NO | NO | YES |
| `EventsViewModel` | `Views/Events/EventsViewModel.swift` | NO | NO | YES |
| `ReportsViewModel` | `Views/Reports/ReportsViewModel.swift` | NO | NO | YES -- 6 async load methods |
| `RealtimeViewModel` | `Views/Realtime/RealtimeView.swift:306` | HAS pollingTask | YES (in polling loop) | PARTIAL -- pollingTask OK, but refresh() needs guards |
| `LiveEventDetailViewModel` | `Views/Realtime/RealtimeView.swift:603` | NO | NO | YES |
| `AdminViewModel` | `Views/Admin/AdminView.swift:250` | NO | NO | YES |
| `SettingsViewModel` | `Views/Settings/SettingsView.swift:592` | NO | NO | YES |
| `SessionsViewModel` | `Views/Sessions/SessionsView.swift:480` | NO | NO | YES |
| `SessionDetailViewModel` | `Views/Sessions/SessionsView.swift:559` | NO | NO | YES |
| `JourneyViewModel` | `Views/Sessions/SessionsView.swift:593` | NO | NO | YES |
| `RetentionViewModel` | `Views/Reports/RetentionView.swift:363` | NO | NO | YES |
| `PagesViewModel` | `Views/Reports/PagesView.swift:142` | NO | NO | YES |
| `ComparisonViewModel` | `Views/Reports/InsightsView.swift:287` | NO | NO | YES |
| `LoginViewModel` | `Views/Auth/LoginViewModel.swift` | NO | NO | LOW PRIORITY -- login is user-initiated, rarely re-triggered |

**Total needing fix: 14 ViewModels** (excluding LoginViewModel as low priority, and WebsiteDetailViewModel as reference).

### Fix Template per ViewModel

For each ViewModel with async load methods:

1. Add `private var loadingTask: Task<Void, Never>?`
2. Wrap each public async load in:
   ```swift
   func loadX(...) async {
       loadingTask?.cancel()
       let task = Task {
           // existing code, but add:
           guard !Task.isCancelled else { return }
           // before each @Published write after an await
       }
       loadingTask = task
       await task.value
   }
   ```
3. Add `guard !Task.isCancelled else { return }` after each `await` before `@Published` mutations
4. Add `func cancelLoading()` where the view needs it (e.g., `.onDisappear`)

### Special Cases

- **DashboardViewModel**: Has TWO public async methods (`loadData`, `loadAllAccountsData`). Both need the pattern. Sub-methods already have `Task.isCancelled` guards for individual loads.
- **ReportsViewModel**: Has 6 separate async load methods (loadReports, loadUTMReport, loadAttributionReport, loadFunnelReport, loadFirstFunnel, loadAllGoals). Each needs its own task tracking, or a single `loadingTask` that cancels on any new call.
- **RealtimeViewModel**: Already has `pollingTask` for the polling loop. The `refresh()` method called within the loop and externally should add `Task.isCancelled` guards.
- **LoginViewModel**: Low priority -- login is a one-shot user action. Include for completeness but deprioritize.

**Confidence: HIGH** -- mechanical pattern replication from known-good reference.

## Architecture Patterns

### Pattern: Online-First Cache Strategy
```
loadData() {
    isLoading = true
    do {
        data = try await api.fetch()
        guard !Task.isCancelled else { return }
        self.property = data
        cache.save(data)  // update cache after success
    } catch {
        if isNetworkError(error) {
            // ONLY load cache on network failure
            if let cached = cache.load(), !cached.isExpired {
                self.property = cached.data
                self.offlineCacheDate = cached.cachedAt
                self.isOffline = true
            }
        }
    }
    isLoading = false
}
```

### Anti-Patterns to Avoid
- **Cache-as-preview:** Loading cache data before API call causes flash of stale content
- **`let viewModel` for ObservableObject:** SwiftUI won't observe changes -- always use `@ObservedObject var`
- **Unguarded async state writes:** Multiple concurrent loads overwrite each other's results
- **Global state switching in loops:** `setActiveAccount` in a loop triggers side effects per iteration

## Common Pitfalls

### Pitfall 1: Task.isCancelled After Actor Boundary
**What goes wrong:** `guard !Task.isCancelled` placed before `await` instead of after
**Why it happens:** Misunderstanding of when cancellation signals propagate
**How to avoid:** Always place guard AFTER each `await`, BEFORE each `@Published` write
**Warning signs:** Published properties updated with stale data from cancelled requests

### Pitfall 2: Cache TTL Mismatch
**What goes wrong:** Cache shown to user that's too old to be useful
**Why it happens:** Different TTL for "is data fresh enough to display" vs "should we delete the file"
**How to avoid:** Separate offline-display TTL (24h) from cleanup TTL (7 days) from freshness TTL (1h)

### Pitfall 3: Widget Credential Race
**What goes wrong:** Widget reads credentials mid-write
**Why it happens:** File write + reloadAllTimelines not atomic
**How to avoid:** Write file with `.atomic` option (already done), ensure reloadAllTimelines called AFTER write completes

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Network status detection | Custom reachability monitor | URLError code matching (existing pattern) | Already consistent across all ViewModels |
| Cache expiration | Custom timer-based cache invalidation | File-based TTL with CacheWrapper (existing) | Already implemented and tested |

## Code Examples

### Task Cancellation Pattern (from WebsiteDetailViewModel)
```swift
// Source: InsightFlow/Views/Detail/WebsiteDetailViewModel.swift
private var loadingTask: Task<Void, Never>?

func loadData(dateRange: DateRange) async {
    loadingTask?.cancel()
    let task = Task {
        isLoading = true
        defer { if !Task.isCancelled { isLoading = false } }
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadStats(dateRange: dateRange) }
            // ... more parallel loads
        }
    }
    loadingTask = task
    await task.value
}

private func loadStats(dateRange: DateRange) async {
    do {
        let result = try await provider.getAnalyticsStats(...)
        guard !Task.isCancelled else { return }
        stats = result.toWebsiteStats()
    } catch {
        guard !Task.isCancelled else { return }
        // error handling
    }
}
```

### Offline-Only Cache Load Pattern (new)
```swift
// How DashboardViewModel.loadData should work:
func loadData(dateRange: DateRange) async {
    loadingTask?.cancel()
    let task = Task {
        isLoading = true
        isOffline = false
        offlineCacheDate = nil
        defer { if !Task.isCancelled { isLoading = false } }
        
        do {
            let freshWebsites = try await fetchWebsites()
            guard !Task.isCancelled else { return }
            websites = freshWebsites
            cache.saveWebsites(freshWebsites.toCached(), accountId: currentAccountId)
            
            await loadAllWebsiteData(dateRange: dateRange)
        } catch {
            guard !Task.isCancelled else { return }
            if isNetworkError(error) {
                // Cache ONLY as offline fallback
                loadFromCache(dateRange: dateRange)
                isOffline = true
            } else {
                self.error = error.localizedDescription
            }
        }
    }
    loadingTask = task
    await task.value
}
```

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (built-in) |
| Config file | Xcode project target `InsightFlowTests` |
| Quick run command | `xcodebuild test -scheme InsightFlow -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:InsightFlowTests -quiet` |
| Full suite command | Same as quick run (8 test files, lightweight) |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BUG-01 | CompareChartSection observes ViewModel | manual | Visual verification in Preview/Simulator | N/A (UI) |
| BUG-02 | Cache only loads on offline | unit | `xcodebuild test ... -only-testing:InsightFlowTests/DashboardViewModelTests` | Exists but needs update |
| BUG-02 | Cache TTL 24h for offline display | unit | `xcodebuild test ... -only-testing:InsightFlowTests/AnalyticsCacheServiceTests` | Exists |
| BUG-02 | evictOldestEntries at 50MB | unit | `xcodebuild test ... -only-testing:InsightFlowTests/AnalyticsCacheServiceTests` | Exists |
| BUG-03 | Widget reads correct account after switch | manual | Requires device with widget | N/A (widget) |
| TASK-01 | ViewModels cancel previous loads | unit | `xcodebuild test ... -only-testing:InsightFlowTests/WebsiteDetailViewModelTests` | Exists (reference) |

### Wave 0 Gaps
- [ ] Update `DashboardViewModelTests.swift` to verify cache NOT preloaded when online
- [ ] Update `AnalyticsCacheServiceTests.swift` to verify 50MB threshold + 24h offline TTL

## Sources

### Primary (HIGH confidence)
- Direct codebase inspection of all 16 ViewModel classes
- Direct inspection of CompareChartSection.swift, AnalyticsCacheService.swift, AccountManager.swift
- Direct inspection of WidgetStorage.swift, WidgetNetworking.swift, SharedCredentials.swift

### Secondary (MEDIUM confidence)
- Apple documentation on `@ObservedObject` vs `let` for ObservableObject (well-known SwiftUI behavior)
- Swift structured concurrency: Task.isCancelled cooperative cancellation model

## Metadata

**Confidence breakdown:**
- BUG-01: HIGH -- single confirmed line, trivial fix
- BUG-02: HIGH -- clear architectural issue, well-understood cache service
- BUG-03: MEDIUM -- race condition plausible but hard to confirm without reproduction
- TASK-01: HIGH -- mechanical audit, canonical reference exists

**Research date:** 2026-04-04
**Valid until:** 2026-05-04 (stable codebase, no external dependencies)
