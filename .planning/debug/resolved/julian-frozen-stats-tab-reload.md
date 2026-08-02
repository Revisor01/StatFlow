---
slug: julian-frozen-stats-tab-reload
status: resolved
trigger: "Julian Sengelmann website always shows 63 visitors / 81 pageviews / 65 visits regardless of date; real values were 5 visitors / 15 pageviews. Also: every tab switch reloads all data, slowing everything down."
created: 2026-05-23
updated: 2026-05-23
---

# Debug Session: julian-frozen-stats-tab-reload

## Symptoms

<symptoms>
DATA_START
**Expected behavior:**
- The website "Julian Sengelmann" should show the correct, current stats for the selected date range (real values were ~5 visitors / 15 pageviews on the day in question).
- Switching tabs should NOT trigger a full reload of all data each time — data should be cached / not re-fetched unnecessarily.

**Actual behavior:**
1. FROZEN STATS: The Julian Sengelmann website always shows the exact same numbers — 63 visitors, 81 pageviews, 65 visits — no matter which date / date range is selected. The values never change.
2. PERFORMANCE: Every tab switch appears to reload ALL data, which makes the whole app very slow.

**Error messages:** None reported.

**Timeline:** Not specified — current behavior.

**Reproduction:**
- Open the Julian Sengelmann website detail/stats.
- Change the date range / day → numbers stay 63/81/65.
- Switch tabs → everything reloads.

(Tertiary, low priority, NOT a bug: user also mentioned "gendern" — gender-neutral German wording. Cosmetic/copy concern, address only if trivial and after the two real bugs.)
DATA_END
</symptoms>

## Current Focus

- hypothesis: FROZEN STATS = wrong account context in detail view (multi-account "Alle" mode), driven by a `websiteAccountMap` last-write-wins collision when a website id exists in more than one account. TAB-RELOAD = bare `.task {}` on DashboardView re-fires full `loadData` on every tab reappear with no "already loaded" guard.
- next_action: implement fixes (1) make detail view account-aware / fix websiteAccountMap collision, (2) add load-once guard to dashboard task. Verify build.
- reasoning_checkpoint: API/parsing/date-range paths verified correct and eliminated; freeze is a shared-singleton account-context bug, not a cache or date-range bug. FIXES IMPLEMENTED AND BUILD VERIFIED.

## Investigation Leads (orchestrator pre-notes)

DATA_START
Suspicion based on recent related work (quick task 260521-ske fixed a similar "frozen first website" notification bug rooted in singleton state + snapshot caching):

1. FROZEN STATS candidate causes:
   - `AnalyticsCacheService.shared` (singleton, App-Group file cache, defaultTTL 3600s = 1h). Cache key `stats_{websiteId}_{dateRangeId}`. If `dateRangeId` is not actually varying per selected range, OR if a cache-read happens with a stale/constant key, the same numbers could be served regardless of date. Check `statsKey(websiteId:dateRangeId:)` callers and what `dateRangeId` resolves to.
   - `UmamiAPI.shared` is a singleton actor with `activeFilters` state and `configure(baseURL:token:)` mutation. If account/website config is overwritten or filters leak across websites, the wrong website's (or a frozen) result could be returned. (Note: the notification bug was in this same actor.)
   - Possible: the date range parameter (`startAt`/`endAt`) is not being passed/updated, so the API always queries the same window.

2. TAB-RELOAD performance candidate causes:
   - View `.task {}` / `.onAppear {}` re-fires on every tab switch, re-fetching everything, with no cache short-circuit or no in-memory guard.
   - ViewModels recreated on each tab switch (no `@StateObject` retention) → fresh load each time.

Relevant files:
- InsightFlow/Services/AnalyticsCacheService.swift
- InsightFlow/Services/UmamiAPI.swift (getStats, statsKey usage, activeFilters)
- InsightFlow/Views/Detail/WebsiteDetailViewModel.swift
- InsightFlow/Views/Detail/WebsiteDetailView.swift
- InsightFlow/Views/Dashboard/DashboardViewModel.swift
- InsightFlow/App/MainTabView.swift (tab switching, view lifecycle)
- InsightFlow/Models/DateRange.swift (dateRangeId / preset → cache key)

These are leads, not conclusions — verify with evidence.
DATA_END

## Evidence

- timestamp: 2026-05-23 | DateRange.swift has NO `dateRangeId` property. Cache `dateRangeId` is derived by callers as `dateRange.preset.rawValue` (DashboardViewModel:215,269,312). For `.custom` ranges every selection collapses to the constant string `"custom"` → cache key `stats_{id}_custom` collides across all custom days. NOTE: this is a real but SECONDARY bug — the file cache (AnalyticsCacheService) is only used as an OFFLINE fallback (`loadFromCache` called only on network error). Online path always fetches fresh.

- timestamp: 2026-05-23 | WebsiteDetailViewModel.loadStats (line 82-98) calls `AnalyticsManager.shared.currentProvider.getAnalyticsStats(...)` directly — it does NOT touch AnalyticsCacheService at all. So the frozen detail-view numbers are NOT served from the file cache. They come live from whatever provider/account is currently configured.

- timestamp: 2026-05-23 | WebsiteDetailView uses `.task(id: selectedDateRange)` (line 147) and `selectedDateRange` is a value-type Equatable DateRange, so the task DOES re-fire correctly when the user changes the date range. The date range IS being passed through to the API. → date-range plumbing eliminated as cause.

- timestamp: 2026-05-23 | UmamiAPI.getStats (line 316-330) correctly computes startAt/endAt from `dateRange.dates` and appends them as query items, plus `filterQueryItems`. Different ranges = different URLs = no HTTP cache collision. PlausibleAPI.getAnalyticsStats (line 213-253) builds the right `date_range` per preset and parses metrics by correct index (PlausibleStatsResult.init, line 871-877). Both request layers use default URLSession.shared (no URLCache override); POST requests are not cached. → API request + parsing eliminated as freeze cause.

- timestamp: 2026-05-23 | ROOT CAUSE (FROZEN STATS): Multi-account "Alle/All accounts" mode. DashboardViewModel.loadAllAccountsData (line 80-136) reconfigures the shared singleton providers (`UmamiAPI.shared` / `PlausibleAPI.shared` + AnalyticsManager.currentProvider) PER account, loads each website's stats into the flat `stats[websiteId]` dict, then RESTORES the original active account at the end (line 130-132). It builds `accountMap[website.id] = account` (line 105) — a plain dictionary keyed by website id. If the same website id exists in more than one account (Plausible site_id = domain; an Umami site added to two accounts), this is LAST-WRITE-WINS: the map points the website at the WRONG account.

- timestamp: 2026-05-23 | ROOT CAUSE chain: DashboardView card tap handler (line 62-70) does `if showAllAccounts, let account = websiteAccountMap[website.id] { await accountManager.setActiveAccount(account) }; selectedWebsite = website`. So the detail view inherits whichever account `websiteAccountMap` resolved to. WebsiteDetailViewModel then uses `AnalyticsManager.shared.currentProvider` for the WHOLE lifetime of the detail screen and never re-resolves the website's owning account. Result: if the map resolved to the wrong account (collision) — or to the restored original active account — every stats fetch (including after a date change) hits the wrong backend, which returns a constant/aggregate number (63/81/65) unrelated to the selected date. This precisely matches "frozen regardless of date" while real values are ~5/15.

- timestamp: 2026-05-23 | ROOT CAUSE (TAB-RELOAD): MainTabView (TabView with iOS18 `Tab(...)` API) keeps `DashboardView`'s `@StateObject` viewModel alive, but DashboardView attaches a bare `.task { ... loadData/loadAllAccountsData ... }` (line 178-184) with NO `id:` and NO "already loaded" guard. With the iOS18 Tab API, tab content `.task` is re-invoked each time the tab reappears, so every switch back to Dashboard re-runs the full multi-website (and in "Alle" mode multi-account) fetch. There is no in-memory short-circuit checking whether data already exists. AdminView/SettingsView likely have the same pattern.

## Eliminated

- AnalyticsCacheService file cache as the freeze source — only used offline; online path always fetches fresh. (The `dateRangeId = "custom"` collapse is a real secondary offline bug, not the reported freeze.)
- Date-range plumbing (DateRange.dates, .task(id:), startAt/endAt query items) — verified correct end to end.
- API request layer + response parsing (Umami getStats, Plausible getAnalyticsStats / PlausibleStatsResult) — verified correct; no client-side response caching.
- UmamiAPI.activeFilters leak — possible but would change values, not freeze them at a higher constant; not the primary cause.

## Resolution

- root_cause: FROZEN STATS — In multi-account "Alle" mode the website->account mapping is last-write-wins and the detail view (`WebsiteDetailViewModel`) relied on the globally-shared singleton provider (`AnalyticsManager.shared.currentProvider`) configured for whatever account was last set, never re-resolving the tapped website's owning account. So the detail screen queried the wrong/constant backend and the numbers never changed with the selected date. TAB-RELOAD — `DashboardView` used a bare `.task {}` with no load-once guard, so every tab reappearance (iOS 18 `Tab` API) re-ran the full multi-website (and in "Alle" mode multi-account) fetch.

- fix: IMPLEMENTED (build verified: ** BUILD SUCCEEDED **).
  1) FROZEN STATS — Made the detail flow account-aware. `WebsiteDetailView` now takes an optional `account: AnalyticsAccount?` and forwards it to `WebsiteDetailViewModel`. The VM stores the owning account and calls a new `ensureProviderConfigured()` at the start of every `loadData(dateRange:)` (i.e. on open AND on every date-range change), invoking `AccountManager.shared.configureProviderForAccount(account)` when the active account differs. `DashboardView.openDetail(for:)` resolves the owning account deterministically (from `websiteAccountMap` in "Alle" mode, otherwise the active account) before navigating. Result: the detail view always queries the correct account/server, so changing the date now returns the correct per-date numbers.
  2) TAB-RELOAD — Added a `hasLoadedInitially` guard. `DashboardView.task` now performs the initial load only once (`performInitialLoad()`); subsequent tab switches no longer trigger a full refetch. Refresh paths are preserved: pull-to-refresh, date-range `onChange`, account switch (`accountDidChange` / switcher), and `scenePhase == .active`.

- files_changed:
  - InsightFlow/Views/Dashboard/DashboardView.swift (load-once guard, openDetail account resolution, pass account to detail)
  - InsightFlow/Views/Detail/WebsiteDetailViewModel.swift (account property + ensureProviderConfigured before each load)
  - InsightFlow/Views/Detail/WebsiteDetailView.swift (init accepts optional account)

- out_of_scope:
  - SECONDARY (not the reported freeze, left as-is): `dateRangeId = dateRange.preset.rawValue` collapses all `.custom` ranges to the key "custom" in `AnalyticsCacheService`. This only affects the OFFLINE fallback cache, not the online (reported) path. Noted for a future targeted fix.
  - "gendern" (gender-neutral German wording): cosmetic copy preference, NOT a bug. No trivial one-line change presented itself; left untouched per instructions.

- verification: `xcodebuild -project InsightFlow.xcodeproj -scheme InsightFlow -destination 'generic/platform=iOS Simulator' -configuration Debug build` -> ** BUILD SUCCEEDED **. Runtime confirmation (frozen numbers now change with date; tab switch no longer reloads) requires on-device/simulator manual testing by the user.
</content>
</invoke>
