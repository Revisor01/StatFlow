---
quick_id: 260521-ske
slug: notif-snapshot-today-bars
type: execute
wave: 1
depends_on: []
files_modified:
  - InsightFlow/Services/NotificationManager.swift
  - InsightFlow/App/InsightFlowApp.swift
  - InsightFlow/Views/Detail/WebsiteDetailViewModel.swift
autonomous: false
requirements:
  - QUICK-260521-ske
must_haves:
  truths:
    - "Push notification body refreshes daily — second day shows new stats, not frozen first-day values"
    - "BGAppRefreshTaskRequest is submitted when app enters background (not only inside the task handler)"
    - "Bar chart for 'today' renders bars even when only 1 pageview exists and that datapoint's UTC hour exceeds the current UTC hour"
    - "Bar chart for 'today' renders bars when local 'today' starts on the previous UTC day (early morning CEST case)"
    - "Yesterday/non-today hourly chart behavior unchanged (still 0...23 slots)"
  artifacts:
    - path: "InsightFlow/Services/NotificationManager.swift"
      provides: "scheduleAllNotifications() called from BG task handler with fresh content.body"
    - path: "InsightFlow/App/InsightFlowApp.swift"
      provides: "scheduleAppRefresh() called on scenePhase==.background and at launch; handler triggers scheduleAllNotifications()"
    - path: "InsightFlow/Views/Detail/WebsiteDetailViewModel.swift"
      provides: "fillMissingTimeSlots uses max(currentUtcHour, maxDataHour) and earliest startOfDay across data for 'today' hourly"
  key_links:
    - from: "InsightFlowApp.scenePhase"
      to: "scheduleAppRefresh()"
      via: ".onChange(of: scenePhase) where newPhase == .background"
      pattern: "scheduleAppRefresh"
    - from: "BGAppRefreshTask handler"
      to: "NotificationManager.scheduleAllNotifications()"
      via: "Task { await manager.scheduleAllNotifications() }"
      pattern: "scheduleAllNotifications"
    - from: "fillMissingTimeSlots (preset == .today, isHourly)"
      to: "dataByComponent keys"
      via: "max(currentUtcHour, maxDataHour) + min(startOfDay(now), startOfDay(earliest data))"
      pattern: "max\\(.*currentHour|maxDataHour"
---

<objective>
Fix two iOS bugs in StatFlow:

1. **Frozen push notifications:** `UNCalendarNotificationTrigger(repeats: true)` snapshots `content.body` at scheduling time, so the same stats body is shown every day. The existing `BGTaskScheduler` registration is in place but (a) its task handler calls `sendScheduledNotifications()` (sends ad-hoc notifications) instead of `scheduleAllNotifications()` (which removes pending + re-adds with fresh body), and (b) `scheduleAppRefresh()` is never invoked outside of the handler itself, so no task is ever queued in the first place.

2. **Empty bar chart for today with sparse data:** `fillMissingTimeSlots` for `preset == .today` and `isHourly == true` clips the slot range to `0...currentUtcHour` and bases `startOfDay` on `now`. When the local "today" maps to UTC such that an API datapoint sits in a UTC hour **greater than** the current UTC hour (or on the **previous UTC day**), that datapoint's key is never iterated and the chart appears empty.

Purpose: Notifications must reflect current data daily without requiring app foregrounding; the today bar chart must render every API datapoint regardless of UTC/local skew.

Output: Three modified files, no UI changes, no new tests. Manual verification described per task.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/quick/260521-ske-notif-snapshot-today-bars/260521-ske-CONTEXT.md
@InsightFlow/Services/NotificationManager.swift
@InsightFlow/App/InsightFlowApp.swift
@InsightFlow/Views/Detail/WebsiteDetailViewModel.swift
@InsightFlow/Info.plist
@InsightFlow/Models/DateRange.swift

<interfaces>
<!-- Key existing surface area the executor must respect. -->

From `InsightFlow/App/InsightFlowApp.swift` (already wired):
```swift
@main struct PrivacyFlowApp: App {
    @StateObject private var notificationManager = NotificationManager()
    init() { registerBackgroundTasks() /* ... */ }
    var body: some Scene { WindowGroup { ContentView()... } }

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "de.godsapp.statflow.refresh",
            using: nil
        ) { task in Self.handleAppRefresh(task: task as! BGAppRefreshTask) }
    }
    private static func handleAppRefresh(task: BGAppRefreshTask) { /* currently calls sendScheduledNotifications() */ }
    private static func scheduleAppRefresh() { /* never called outside handler */ }
}
```

Identifier already used: `de.godsapp.statflow.refresh` (NOT `refresh-notifications` — keep the existing identifier; Info.plist already lists it).

`Info.plist` already contains:
- `BGTaskSchedulerPermittedIdentifiers` → `["de.godsapp.statflow.refresh"]`
- `UIBackgroundModes` → `["fetch", "processing"]`

→ **No Info.plist changes required.** No Xcode capability changes required (already configured per existing commit history).

From `InsightFlow/Services/NotificationManager.swift`:
```swift
@MainActor class NotificationManager: ObservableObject {
    func scheduleAllNotifications() async  // removes pending + re-adds with current stats (FRESH body)
    nonisolated func sendScheduledNotifications() async  // sends ad-hoc trigger==nil notifications immediately
}
```
The BG task handler must call `scheduleAllNotifications()` (which is `@MainActor`-isolated) — not `sendScheduledNotifications()`. `scheduleAllNotifications()` is the right primitive: it clears pending and re-creates `UNCalendarNotificationTrigger`s with a freshly fetched `content.body`.

From `InsightFlow/Views/Detail/WebsiteDetailViewModel.swift::fillMissingTimeSlots`:
```swift
// Current bug site (today hourly branch, ~line 175-202):
if isHourly {
    let baseDate: Date = (preset == .today) ? now : ...
    let startOfDay = utcCalendar.startOfDay(for: baseDate)
    let currentHour: Int = (preset == .today)
        ? utcCalendar.component(.hour, from: now)  // <- too restrictive
        : 23
    for hour in 0...currentHour {
        // build key from startOfDay + hour, look up in dataByComponent
    }
}
```
`dataByComponent` keys for hourly today look like `"2026-5-21-22"` (UTC year-month-day-hour).
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Fix BGTask wiring + handler to refresh notification bodies daily</name>
  <files>InsightFlow/App/InsightFlowApp.swift</files>
  <action>
Fix Bug 1 by making the existing `BGTaskScheduler` plumbing actually do what its name implies. Three changes in `InsightFlowApp.swift`:

**1) Change the handler to re-schedule notifications (not send ad-hoc ones).**

In `handleAppRefresh(task:)`, replace the body so that it:
- Calls `scheduleAppRefresh()` first (re-queue the next refresh) — this stays.
- Then runs `await NotificationManager.shared.scheduleAllNotifications()` (NOT `sendScheduledNotifications()`).

Problem: `NotificationManager` is currently constructed as a `@StateObject` in the `App` and as a fresh local in the handler. `scheduleAllNotifications()` is `@MainActor`-isolated. To make this work without introducing a singleton-refactor (out of scope per CONTEXT.md), create a `MainActor.run`-wrapped instance inside the operation:

```swift
let operation = Task {
    await MainActor.run {
        // Use a fresh instance — it reads UserDefaults (settings, time, dataSource)
        // and accounts via AccountManager.shared, so a new instance is fine.
        NotificationManager()
    }
    let manager = await MainActor.run { NotificationManager() }
    await manager.scheduleAllNotifications()
}
```

Simplify to:
```swift
let operation = Task { @MainActor in
    let manager = NotificationManager()
    await manager.scheduleAllNotifications()
}
```

`task.expirationHandler` continues to cancel `operation`; `task.setTaskCompleted(success:)` is called after `await operation.value`.

**2) Submit the first BGTask at app launch.**

In `init()` of `PrivacyFlowApp`, after `registerBackgroundTasks()`, call `Self.scheduleAppRefresh()`. Without this, no task is ever queued and the handler never runs. Note: `scheduleAppRefresh()` is currently `private static` — keep it `static` so it's callable from `init`.

**3) Re-submit BGTask whenever the app enters background.**

Add `@Environment(\.scenePhase) private var scenePhase` to `PrivacyFlowApp` and on the `WindowGroup` content add:

```swift
.onChange(of: scenePhase) { _, newPhase in
    if newPhase == .background {
        Self.scheduleAppRefresh()
    }
}
```

(Use the iOS 17+ two-parameter onChange signature — the project already requires iOS 17 based on existing code patterns; if compiler complains, fall back to the single-parameter form `.onChange(of: scenePhase) { newPhase in ... }`.)

**4) Tweak `scheduleAppRefresh()` earliest-begin-date to fire ~30 min before notification time (per CONTEXT.md guidance).**

Currently `earliestBeginDate` is set exactly to notification time. Subtract 30 minutes so the system has a window to fire the refresh before the user notification trigger. Replace the assignment block:

```swift
let leadTime: TimeInterval = -30 * 60 // 30 minutes earlier
if let scheduledDate = Calendar.current.date(from: components) {
    let target = scheduledDate.addingTimeInterval(leadTime)
    if target < Date() {
        // Today's slot already passed → schedule for tomorrow
        request.earliestBeginDate = Calendar.current.date(byAdding: .day, value: 1, to: target)
    } else {
        request.earliestBeginDate = target
    }
} else {
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
}
```

**Decisions explained in comments:**
- Comment the handler explaining why we call `scheduleAllNotifications` (refreshes `content.body`, fixes the snapshot bug).
- Comment the `onChange(.background)` site explaining BGTask requeue strategy.

Per D-01 (BGTaskScheduler chosen) and D-02 (refresh ~30 min before notification time).

Do NOT touch the identifier string (`de.godsapp.statflow.refresh`) — it matches Info.plist already.
Do NOT modify Info.plist (already configured).
Do NOT modify NotificationManager.swift in this task.
  </action>
  <verify>
    <automated>xcodebuild -project InsightFlow.xcodeproj -scheme InsightFlow -destination 'generic/platform=iOS Simulator' -configuration Debug build 2>&amp;1 | tail -30 | grep -E 'BUILD SUCCEEDED|error:'</automated>
  </verify>
  <done>
- Build succeeds without warnings about `onChange` or actor isolation.
- `handleAppRefresh` calls `scheduleAllNotifications()` (verified via grep).
- `init()` calls `Self.scheduleAppRefresh()` (verified via grep).
- `scenePhase == .background` triggers `Self.scheduleAppRefresh()` (verified via grep).
- `earliestBeginDate` accounts for 30-minute lead time (verified via grep for `30 * 60` or `leadTime`).
  </done>
</task>

<task type="auto">
  <name>Task 2: Fix fillMissingTimeSlots for today hourly when API datapoint UTC hour > current UTC hour</name>
  <files>InsightFlow/Views/Detail/WebsiteDetailViewModel.swift</files>
  <action>
Fix Bug 2 by widening the slot iteration range in `fillMissingTimeSlots` so no API datapoint is dropped due to UTC-vs-local skew. Only the `isHourly && preset == .today` branch changes; everything else stays.

**Step A: Compute `maxDataHour` and `earliestDataStartOfDay` from `dataByComponent`.**

After building `dataByComponent` (around current line 167), before the `if isHourly` block, derive two values from the actual data — but only used in the today branch:

```swift
// Find the earliest UTC startOfDay and the maximum UTC (day*24 + hour) actually present in the data.
// Used below to ensure no datapoint is dropped due to UTC-vs-local timezone skew.
var earliestDataDate: Date? = nil
var latestDataDate: Date? = nil
for point in data {
    if earliestDataDate == nil || point.date < earliestDataDate! { earliestDataDate = point.date }
    if latestDataDate == nil || point.date > latestDataDate! { latestDataDate = point.date }
}
```

**Step B: In the `isHourly && preset == .today` path, rebase `startOfDay` and broaden the loop.**

Replace the block (currently lines ~175-202):

```swift
if isHourly {
    let baseDate: Date
    switch dateRange.preset {
    case .today: baseDate = now
    case .yesterday: baseDate = calendar.date(byAdding: .day, value: -1, to: now) ?? now
    default: baseDate = dateRange.dates.start
    }

    let startOfDay = utcCalendar.startOfDay(for: baseDate)
    let currentHour: Int
    if dateRange.preset == .today {
        currentHour = utcCalendar.component(.hour, from: now)
    } else {
        currentHour = 23
    }

    for hour in 0...currentHour {
        // ...build key, lookup, append...
    }
}
```

with:

```swift
if isHourly {
    let nowStartOfDay = utcCalendar.startOfDay(for: now)

    // Determine slot start and end based on preset.
    let startOfDay: Date
    let lastHourOffset: Int   // hours since startOfDay (inclusive upper bound)

    switch dateRange.preset {
    case .today:
        // Use the earlier of (today UTC start) and (earliest data UTC start).
        // Handles the local-early-morning case where local "today" maps to two UTC days.
        let earliestUtcStart: Date
        if let earliest = earliestDataDate {
            earliestUtcStart = utcCalendar.startOfDay(for: earliest)
        } else {
            earliestUtcStart = nowStartOfDay
        }
        startOfDay = min(nowStartOfDay, earliestUtcStart)

        // Current hour relative to startOfDay (may exceed 23 when startOfDay is the previous UTC day).
        let currentHourOffset = Int(
            (now.timeIntervalSince(startOfDay) / 3600.0).rounded(.down)
        )
        // Hour offset of the latest datapoint relative to startOfDay (may exceed currentHourOffset
        // when API data sits in a UTC hour ahead of the device's UTC clock).
        let latestDataHourOffset: Int
        if let latest = latestDataDate {
            latestDataHourOffset = Int(
                (latest.timeIntervalSince(startOfDay) / 3600.0).rounded(.down)
            )
        } else {
            latestDataHourOffset = currentHourOffset
        }
        lastHourOffset = max(currentHourOffset, latestDataHourOffset)

    case .yesterday:
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        startOfDay = utcCalendar.startOfDay(for: yesterday)
        lastHourOffset = 23

    default:
        startOfDay = utcCalendar.startOfDay(for: dateRange.dates.start)
        lastHourOffset = 23
    }

    // Guard against negative ranges (defensive — should not occur in normal flow).
    let upperBound = max(0, lastHourOffset)

    for hourOffset in 0...upperBound {
        if let hourDate = utcCalendar.date(byAdding: .hour, value: hourOffset, to: startOfDay) {
            let comps = utcCalendar.dateComponents([.year, .month, .day, .hour], from: hourDate)
            let key = "\(comps.year!)-\(comps.month!)-\(comps.day!)-\(comps.hour!)"
            let value = dataByComponent[key] ?? 0
            result.append(TimeSeriesPoint(x: DateFormatters.iso8601.string(from: hourDate), y: value))
        }
    }
}
```

**Why this works:**
- `min(nowStartOfDay, earliestDataUtcStart)` handles the cross-UTC-day case (local "today" starts during previous UTC day; the only datapoint sits in UTC hour 22 of yesterday).
- `max(currentHourOffset, latestDataHourOffset)` ensures any datapoint whose UTC hour is ahead of `now`'s UTC hour (within the same local-day window) is still included.
- `hourOffset` may exceed 23 when `startOfDay` falls on the previous UTC day — `Calendar.date(byAdding: .hour, value: 30, to:)` handles overflow correctly into the next UTC day, and the key generation re-extracts year/month/day/hour from the resulting `Date`, so day-rollover is automatic.
- The `else` branch for `yesterday` and other presets is unchanged (`0...23`), satisfying CONTEXT.md's "Keep non-today hourly behavior unchanged" constraint.

**Do NOT change:**
- The `else` (non-hourly) day-loop branch.
- The `dataByComponent` key construction.
- The `result.isEmpty ? data : result` final return.
- Any other ViewModel method.

Per D-01 from CONTEXT.md (currentHour = max of current UTC hour and max data hour) and D-02 (earliest UTC startOfDay across data and today).
  </action>
  <verify>
    <automated>xcodebuild -project InsightFlow.xcodeproj -scheme InsightFlow -destination 'generic/platform=iOS Simulator' -configuration Debug build 2>&amp;1 | tail -30 | grep -E 'BUILD SUCCEEDED|error:'</automated>
  </verify>
  <done>
- Build succeeds.
- `fillMissingTimeSlots` contains `max(currentHourOffset, latestDataHourOffset)` (verified via grep).
- `fillMissingTimeSlots` contains `min(nowStartOfDay, earliestUtcStart)` (verified via grep).
- `else` (yesterday/default) branch still uses `lastHourOffset = 23` (verified via grep).
- Hourly slot loop uses `hourOffset` based on `timeIntervalSince(startOfDay)` not raw `component(.hour, from: now)`.
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 3: Manual UAT — notification refresh + today bar chart</name>
  <what-built>
- Bug 1 (Task 1): BGTaskScheduler now schedules `de.godsapp.statflow.refresh` at app launch and on every transition to background, with `earliestBeginDate` set to ~30 minutes before the configured notification time. The handler calls `NotificationManager.scheduleAllNotifications()` which removes pending notifications and re-adds them with a freshly fetched `content.body`.
- Bug 2 (Task 2): `fillMissingTimeSlots` for `preset == .today` and hourly unit now uses `min(nowStartOfDay, earliestDataUtcStart)` as slot start and `max(currentHourOffset, latestDataHourOffset)` as slot end, so no API datapoint is dropped when local "today" spans two UTC days or when an API datapoint sits in a UTC hour ahead of the device's current UTC hour.
  </what-built>
  <how-to-verify>
**Setup (one-time, manual in Xcode):**
1. Confirm Xcode target → Signing &amp; Capabilities → Background Modes has both "Background fetch" and "Background processing" enabled. They should already be on from prior commits — flag only if missing.

**Bug 1 — Notification body refresh (BGTask simulation):**

1. Build &amp; run the app on a real device or simulator (iOS 17+) with at least one Umami/Plausible account configured and at least one website with daily notifications enabled, notification time set to e.g. 09:00.
2. Background the app (swipe up to home or lock).
3. In Xcode debugger console, simulate the BGTask firing:
   ```
   e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"de.godsapp.statflow.refresh"]
   ```
4. Foreground the app and open Xcode console logs (filter: "Geplante Notifications"). Expected: log line "Geplante Notifications: N" with N ≥ 1, and pending notification identifiers prefixed with `scheduled-`. The body content reflects current stats.
5. Repeat after waiting for fresh data on the Umami/Plausible test account (e.g. visit t.godsapp.de tracked page a few times). After simulated BGTask fire, pending notifications should have updated visitor/pageview counts in their `content.body`.
6. Real-world test (slower but definitive): leave the app installed for 2 days; on day 2 the morning notification should NOT show day-1's exact same numbers when stats have changed.

**Bug 2 — Today bar chart with sparse data:**

1. Pick a website on t.godsapp.de that has very few pageviews today (1–2 total). If none exists, generate 1 pageview manually now.
2. Open the app → Detail view for that website → DateRange = "Heute" (today).
3. Expected: at least one visible bar in the pageviews chart at the UTC hour corresponding to the pageview. Previously the chart appeared empty.
4. Edge case — early morning local time: change device timezone (Settings → General → Date &amp; Time) to one where local time is 00:30–02:30 (e.g. Pacific/Auckland during European mid-afternoon) and reload. The chart for "today" should still show bars matching the API datapoints, with bars rendered for hours on the previous UTC day if applicable.
5. Yesterday view should still show a full 0–23 hour x-axis (no regression).

**If all 6 verification steps pass:** Type "approved".
**If anything fails:** Describe which step failed, attach Xcode console log if relevant.
  </how-to-verify>
  <resume-signal>Type "approved" or describe issues</resume-signal>
</task>

</tasks>

<verification>
- `grep -c "scheduleAllNotifications" InsightFlow/App/InsightFlowApp.swift` ≥ 1
- `grep -c "scenePhase" InsightFlow/App/InsightFlowApp.swift` ≥ 1
- `grep -c "Self.scheduleAppRefresh" InsightFlow/App/InsightFlowApp.swift` ≥ 2  (init + onChange + handler)
- `grep -c "max(currentHourOffset" InsightFlow/Views/Detail/WebsiteDetailViewModel.swift` ≥ 1
- `grep -c "min(nowStartOfDay" InsightFlow/Views/Detail/WebsiteDetailViewModel.swift` ≥ 1
- `xcodebuild ... build` → BUILD SUCCEEDED
- Manual UAT (Task 3) signed off
</verification>

<success_criteria>
- App builds without errors or new warnings.
- Pending notifications re-scheduled on `scenePhase == .background` and on BGTask handler fire — verified via simulated BGTask launch + console log.
- Today bar chart renders bars for an API datapoint whose UTC hour exceeds the current device UTC hour.
- Today bar chart renders bars when local "today" spans two UTC days (early-morning timezone test).
- Yesterday / non-today hourly charts unchanged.
- No regressions to `sendScheduledNotifications()` (we don't touch it — but it's no longer called from the BG handler).
</success_criteria>

<output>
After completion, create `.planning/quick/260521-ske-notif-snapshot-today-bars/260521-ske-SUMMARY.md` covering:
- Both bug fixes summarized.
- Note for the user: Xcode capability "Background Modes" should already be enabled — re-confirm in Signing &amp; Capabilities if BGTask never fires in production.
- Mention that the existing identifier `de.godsapp.statflow.refresh` was reused (not `refresh-notifications` as CONTEXT.md suggested) because Info.plist + handler registration already referenced it.
- Document the timezone math used in `fillMissingTimeSlots` for future maintenance.
</output>
