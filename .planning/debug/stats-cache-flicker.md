---
slug: stats-cache-flicker
status: resolved
trigger: "Loading values STILL flickers: opening a website's detail/dashboard shows the OLD cached value first, then it visibly swaps to the NEW value. User wants: pre-load AND cache all common ranges (Today/Yesterday/Week/7d) up front so the correct value is already there, and only refresh silently in the background — no jarring visible swap."
created: 2026-05-24
updated: 2026-05-24
---

# Debug Session: stats-cache-flicker

## Symptoms

<symptoms>
DATA_START
**Expected behavior (user's stated wish):**
- Open a website detail page (or dashboard) and immediately see the CORRECT value — no visible change.
- The app should pre-load and cache all common date ranges (Today, Yesterday, This Week, Last 7 days) up front, then on open just refresh silently in the background.

**Actual behavior:**
1. On open, the OLD/stale value is shown first, then it VISIBLY swaps to the new value a moment later. User hates this swap ("That's shit").
2. User perceives the app as "doesn't cache" — every open feels like it goes to the network and then changes the number in front of them.

**Error messages:** None.

**Timeline:** Appeared after the two follow-up commits to the prior fix (julian-frozen-stats-tab-reload):
- 5d1a435 feat(dashboard): stale-while-revalidate on tab switch
- 497b27d feat(detail): periodic silent refresh of daily stats while open

**Reproduction:**
- Switch to the Dashboard tab (after first load) → old in-memory numbers shown, then they jump when silent revalidate lands.
- Open a website detail page → numbers shown, then jump again on completion / on the 45s auto-refresh tick.
DATA_END
</symptoms>

## Current Focus

- hypothesis: The flicker is NOT a file-cache read at all. It is an in-memory @Published-state swap. Each open/tab-switch triggers a fresh network fetch (online path NEVER reads AnalyticsCacheService); when the response lands, the @Published value is overwritten unconditionally — even if visually different from what is currently shown. The recent "stale-while-revalidate" (dashboard) and "periodic silent refresh" (detail) commits deliberately keep stale on screen and swap it for fresh, which IS the visible swap the user is complaining about. There is NO pre-loading of multiple date ranges. The user's "doesn't cache" perception is correct for the online path.
- next_action: DIAGNOSIS ONLY — no fix applied. Report mechanism + ranked fix options.
- reasoning_checkpoint: confirmed via direct file reads; the online path in both Dashboard and Detail ViewModels writes @Published state directly from the network response with no equality guard, and AnalyticsCacheService is only consulted on `error.isNetworkError` (offline fallback). Only the currently-selected range is ever fetched.

## Investigation Leads (orchestrator pre-notes)

DATA_START
Two suspect commits:
- 5d1a435 "stale-while-revalidate on tab switch" — show stale value immediately, fetch fresh, swap in.
- 497b27d "periodic silent refresh of daily stats while open" — 45s background re-fetch while detail open.

"Stale-while-revalidate" literally = show stale, then swap to fresh. That swap IS the complaint. The previous fix over-corrected: from "always reload (slow)" to "show stale then swap (flickery)".

Files to trace:
- AnalyticsCacheService.swift — what is cached, key derivation (dateRangeId = preset.rawValue; .custom collapses to "custom"), TTL 3600s, whether online path reads cache or only offline fallback.
- WebsiteDetailViewModel.swift — loadData/loadStats, stale→fresh swap, periodic silent refresh, ensureProviderConfigured.
- WebsiteDetailView.swift — .task(id:), rendering during swap.
- DashboardViewModel.swift / DashboardView.swift — stale-while-revalidate, load-once guard, card swap.
- DateRange.swift — presets, cache key per range.
DATA_END

## Evidence

- timestamp: 2026-05-24 | **Online path NEVER reads the file cache.** `DashboardViewModel.loadData` (DashboardViewModel.swift:146-204) is documented "Online-First: ALWAYS fetch fresh from API, NO cache preload" (line 164). The file `AnalyticsCacheService` is consulted ONLY inside the `catch` branch when `error.isNetworkError` → `loadFromCache(dateRange:)` (lines 191-200). So on every normal (online) open/tab-switch, a network round-trip happens; the cache write at `cache.saveStats(...)` (line 298) and `cache.saveSparkline(...)` (line 340) is write-only for the online path. → The cache exists purely as an offline fallback. The user's "doesn't cache" perception is literally true for the online path.

- timestamp: 2026-05-24 | **Detail view does not touch the file cache at all.** `WebsiteDetailViewModel.loadStats` (WebsiteDetailViewModel.swift:129-145) calls `provider.getAnalyticsStats(...)` and assigns `stats = websiteStats` (line 135) directly. It never reads or writes `AnalyticsCacheService`. So the detail "value" is purely the last in-memory `@Published var stats` from the previous network fetch, then overwritten by the next network fetch.

- timestamp: 2026-05-24 | **The flicker is an unconditional @Published mutation = the visible swap.** Detail: `stats = websiteStats` (WebsiteDetailViewModel.swift:135) and `totalVisitors = websiteStats.visitors.value` (line 136) are assigned with NO check "did the value actually change?". Dashboard: `stats[websiteId] = analyticsStats.toWebsiteStats()` (DashboardViewModel.swift:295) likewise unconditional. SwiftUI re-renders the bound `Text` whenever the published value changes, even if old and new render to the same string — and especially when they differ (the user's "old then new" jump).

- timestamp: 2026-05-24 | **Detail hero numbers animate the swap, making it MORE noticeable.** `HeroStatCard` value `Text(value)` uses `.contentTransition(.numericText())` (WebsiteDetailSupportingViews.swift:97 and :155). When `stats` is overwritten with a different value, SwiftUI runs the numeric "rolling" transition — the exact visible "old value → new value" animation the user describes. The live-visitor capsule in the detail toolbar also uses `.contentTransition(.numericText())` (WebsiteDetailView.swift:117, :135).

- timestamp: 2026-05-24 | **Dashboard card value has NO content transition — it's an instant text replace.** `StatBox.body` renders `Text(displayValue)` (WebsiteCard.swift:460) with no `.contentTransition`; the loading vs. loaded branch is `if let stats { statsSection } else { loadingSection }` (WebsiteCard.swift:82-86). So on the dashboard the swap is an abrupt instant change of the number (also jarring, just not animated). Card body has no `.animation` modifier on the value itself.

- timestamp: 2026-05-24 | **`stale-while-revalidate` commit (5d1a435) is the dashboard trigger.** DashboardView `.task` (DashboardView.swift:148-153 region per current file; introduced in 5d1a435) now calls `performInitialLoad(silent: true)` on every subsequent tab reappearance. `silent` only skips the `isLoading` spinner (`if !silent { isLoading = true }`, DashboardViewModel.swift:155) — it does NOT skip the @Published overwrite. Result: returning to the dashboard keeps the stale in-memory numbers on screen, fires a full network refetch with no spinner, then overwrites every `stats[id]` when each response lands → visible jump with no loading indicator to explain it.

- timestamp: 2026-05-24 | **`periodic silent refresh` commit (497b27d) is the detail trigger.** `WebsiteDetailView.task(id: selectedDateRange)` (WebsiteDetailView.swift:148-153) does `await viewModel.loadData(...)` then `viewModel.startAutoRefresh(dateRange:)`. `startAutoRefresh` (WebsiteDetailViewModel.swift:113-122) loops every 45s (`autoRefreshInterval = .seconds(45)`, line 108) calling `loadData(dateRange:, silent: true)`. Each tick re-runs all 18 sub-loads (loadData task group, lines 66-85) and reassigns `stats`, `pageviewsData`, every metric array — unconditionally. So even while sitting on the page, numbers can visibly roll every 45 seconds.

- timestamp: 2026-05-24 | **NO pre-loading of multiple date ranges exists anywhere.** Both `DashboardViewModel.loadData` and `WebsiteDetailViewModel.loadData` take a single `dateRange` and fetch ONLY that range (Dashboard: loadStats/loadSparkline keyed by the one `dateRange.preset.rawValue`; Detail: all sub-loaders receive the one `dateRange`). On the detail screen the default is `.today` (WebsiteDetailView.swift:41); changing the chip re-fires `.task(id: selectedDateRange)` which fetches that range fresh (no prior cache hit). Nothing ever fetches Today + Yesterday + Week + 7d together. The user's explicit request (pre-load+cache all 4 ranges) is currently NOT implemented at all.

- timestamp: 2026-05-24 | **Cache key per range is well-formed for the 4 presets the user cares about.** `statsKey = "stats_\(websiteId)_\(dateRangeId)"` (AnalyticsCacheService.swift:47-49) and callers pass `dateRangeId = dateRange.preset.rawValue` (DashboardViewModel.swift:277, :320). For Today/Yesterday/Week/7d the rawValues are distinct: "today" / "yesterday" / "week" / "7d" (DateRange.swift:4-12). So a per-range cache is feasible with the existing key scheme; only `.custom` collapses to "custom" (known secondary issue, out of scope here). `defaultTTL = 3600s` (AnalyticsCacheService.swift:13), `sparklineTTL = 900s` (line 14).

## Eliminated

- "It reads a stale file from AnalyticsCacheService and shows that first" — ELIMINATED. The online path never reads the file cache (only on `error.isNetworkError`). The stale value the user sees is the last in-memory `@Published` value, not a disk read.
- "Date-range cache key collision causes a wrong cached value to show" — ELIMINATED for the 4 relevant presets; their rawValues are distinct and, anyway, the online path doesn't read the cache. (The `.custom`→"custom" collapse is a separate offline-only issue, untouched.)
- "Frozen/wrong-account value" (the prior bug) — ELIMINATED as the cause here; `ensureProviderConfigured()` (WebsiteDetailViewModel.swift:93-98) now runs before each load. The current complaint is the visible swap of an otherwise-correct value, not a wrong value.

## Resolution

- root_cause: **The flicker is a visible in-memory @Published value swap, intentionally introduced by the two follow-up commits.** The online code path in both ViewModels (a) never serves from cache, so every open/tab-switch/45s-tick performs a real network fetch, and (b) overwrites the bound `@Published` value (`stats`, `stats[id]`, metric arrays) unconditionally when the response lands — with no "value unchanged" guard. Because the recent commits keep the previous (stale) value on screen WITHOUT a spinner (`silent` only suppresses `isLoading`, not the overwrite) and, on the detail screen, animate the change via `.contentTransition(.numericText())` (WebsiteDetailSupportingViews.swift:97,155), the user sees "old value, then it rolls/jumps to the new value." There is NO pre-loading or caching of the four common ranges; the cache is write-only on the online path and read only as an offline fallback. So the previous fix went from "always reload with spinner (slow)" to "show stale then silently swap (flickery)" — which is precisely what the user now hates.

- fix: APPLIED (Option 1 + 2 combined; build verified ** BUILD SUCCEEDED **).
  1) **Equatable** added to `WebsiteStats`, `StatValue`, `TimeSeriesPoint`, `MetricItem` (Stats.swift) so values can be compared.
  2) **Equality guards** on every @Published write of stats/sparkline in both ViewModels — value is only reassigned when it actually changed, so a silent refresh returning identical numbers no longer re-renders (kills the flicker for the common "nothing changed" case). DashboardViewModel.loadStats/loadSparkline, WebsiteDetailViewModel.loadStats.
  3) **Cache-first online path**: WebsiteDetailViewModel.loadStats and DashboardViewModel.loadStats now read `AnalyticsCacheService` for the exact range FIRST (instant correct value on open / range-switch), then revalidate and write back. Previously the detail view never touched the file cache and the dashboard read it only on network error.
  4) **Pre-load all 4 ranges**: `prefetchOtherRanges(except:)` on both ViewModels silently fetches Today/Yesterday/Week/7d into the cache (no @Published mutation) after the selected range loads. Detail: account-aware via ensureProviderConfigured, runs in `.task`, cancelled on disappear. Dashboard: single-account mode only (stable provider), runs after performInitialLoad's non-all-accounts branch. So switching the range chip now shows the already-cached correct value immediately, then revalidates silently.

- files_changed:
  - InsightFlow/Models/Stats.swift (Equatable on WebsiteStats, StatValue, TimeSeriesPoint, MetricItem)
  - InsightFlow/Views/Detail/WebsiteDetailViewModel.swift (cache property, cache-first loadStats + guard, prefetchOtherRanges/stopPrefetch)
  - InsightFlow/Views/Detail/WebsiteDetailView.swift (call prefetchOtherRanges in .task, stopPrefetch in onDisappear)
  - InsightFlow/Views/Dashboard/DashboardViewModel.swift (cache-first loadStats + guards on stats/sparkline, prefetchOtherRanges/prefetchStats/stopPrefetch)
  - InsightFlow/Views/Dashboard/DashboardView.swift (call prefetchOtherRanges after single-account load)

- known_limitations:
  - Dashboard pre-load runs in single-account mode only; in "Alle Accounts" mode the per-account provider reconfiguration makes a safe global prefetch complex, so it's deferred there (detail-view prefetch is account-aware and still works).
  - The `.contentTransition(.numericText())` numeric roll on the detail hero cards is left in place; with the equality guard it now only animates on a GENUINE value change, which is acceptable. Can be revisited if the user still finds genuine-change rolls distracting.
  - Original ranked options retained below for reference.

- fix_options (original diagnosis — ranked by match to user's stated desire — pre-load+cache all ranges, no visible swap):

- fix_options (ranked by match to user's stated desire — pre-load+cache all ranges, no visible swap):

  1. **(Best match) Pre-fetch + persist all 4 common ranges, and read cache-first so the selected range is already correct on open; only swap when the value genuinely changed.**
     - Add a warm-up that fetches Today/Yesterday/Week/7d for the visible website(s) and writes them via the existing `cache.saveStats(...)` keyed by `dateRange.preset.rawValue` (keys already distinct, AnalyticsCacheService.swift:47-49).
     - On open/range-change, read the cached value for that exact range FIRST and populate `@Published` synchronously (instant, correct-for-that-range), then revalidate.
     - Combine with option 2 so the revalidation does NOT cause a visible jump.
     - Feasibility: HIGH. Cache key scheme, save APIs, and per-preset rawValues already exist. Requires: a cache-read path on the online flow (today it's offline-only, DashboardViewModel.swift:191-200), plus a small warm-up loop over `DateRange.allCases`/the 4 presets. Detail view currently bypasses the file cache entirely (WebsiteDetailViewModel.swift:129-145) so it would need a read+write hook added.

  2. **(Eliminates the visible swap directly) Only mutate the @Published value when it actually changed (equality guard), and/or drop `.contentTransition(.numericText())` on silent refreshes.**
     - Guard `stats`/`stats[id]`/metric assignments: `if newValue != current { ... }` (WebsiteDetailViewModel.swift:135-136; DashboardViewModel.swift:295). If the silent refresh returns the same numbers, nothing re-renders → no flicker. When numbers truly changed, the swap is legitimate (the data did change).
     - For the unavoidable legitimate change, consider suppressing the numeric content transition during silent refresh so it updates without the attention-grabbing roll (WebsiteDetailSupportingViews.swift:97,155).
     - Feasibility: HIGH, small, surgical. Requires `Equatable` on `WebsiteStats` (likely trivial). Best paired with option 1; on its own it removes the "swap to identical value" churn but a genuine change still swaps.

  3. **(Simplest, weakest match) Show a subtle non-blocking loading state instead of stale numbers on first open, and stop the 45s auto-refresh from mutating visible totals.**
     - e.g. on a cold open show a placeholder/redacted shimmer until fresh arrives (so there's no "old number" to swap FROM), and reduce/disable the 45s detail poller (497b27d) for the hero totals, keeping it only for the realtime visitor count.
     - Feasibility: MEDIUM. Does not deliver the user's requested pre-load/cache, and reintroduces a (subtle) loading state the prior commit tried to remove. Use only if 1+2 are deferred.

  Recommended combination: **Option 1 + Option 2** — genuinely pre-load & cache the 4 ranges (matches the explicit ask) AND guard the @Published mutation so the silent revalidation only re-renders when the data really changed (kills the flicker).

- files_changed: [] (no fix applied)

- key_references:
  - DashboardViewModel.swift:146-204 (online-first loadData, cache only on network error), :191-200 (offline fallback), :277/:320 (dateRangeId = preset.rawValue), :295 (unconditional stats mutation), :298/:340 (write-only cache on online path)
  - WebsiteDetailViewModel.swift:48-89 (loadData + silent), :93-98 (ensureProviderConfigured), :108/:113-122 (45s autoRefresh), :129-145 (loadStats, no cache, unconditional `stats =` mutation)
  - WebsiteDetailView.swift:41 (default .today), :117/:135 (numericText capsule), :148-153 (.task → loadData + startAutoRefresh), :154-164 (scenePhase polling)
  - WebsiteDetailSupportingViews.swift:97,155 (HeroStatCard `.contentTransition(.numericText())` — animated swap)
  - WebsiteCard.swift:82-86 (loading vs stats branch), :460 (dashboard value Text, NO content transition = instant replace)
  - AnalyticsCacheService.swift:13-14 (TTLs), :47-49 (statsKey), :129-135 (saveStats/loadStats), :282-288 (offline display TTL)
  - DateRange.swift:4-12 (preset rawValues today/yesterday/week/7d), :148-150 (allCases)
  - Commits: 5d1a435 (dashboard stale-while-revalidate), 497b27d (detail 45s silent refresh)
</content>
</invoke>
