# External Integrations

**Analysis Date:** 2026-04-04

## APIs & External Services

### Umami Analytics API

- **Provider type:** `AnalyticsProviderType.umami`
- **Default cloud URL:** `https://cloud.umami.is`
- **Self-hosted:** Any URL (user-provided)
- **Client:** `actor UmamiAPI` at `InsightFlow/Services/UmamiAPI.swift` (singleton: `UmamiAPI.shared`)
- **Auth:** Username/password login returns JWT token; stored in Keychain as `.token`
- **Auth header:** `Authorization: Bearer {token}`
- **Timeout:** 15s for login, 30s for all other requests
- **Date format:** Timestamps as epoch milliseconds (`startAt`, `endAt`); ISO8601 with fractional seconds for report parameters

**Umami API Endpoints Used:**

| Method | Endpoint | Purpose | Function |
|--------|----------|---------|----------|
| POST | `/api/auth/login` | Authentication | `login(baseURL:username:password:)` |
| GET | `/api/websites` | List websites | `getWebsites()` |
| GET | `/api/websites/{id}` | Single website | `getWebsite(websiteId:)` |
| GET | `/api/websites/{id}/active` | Active visitors | `getActiveVisitors(websiteId:)` |
| GET | `/api/websites/{id}/stats` | Aggregate stats | `getStats(websiteId:dateRange:)` |
| GET | `/api/websites/{id}/pageviews` | Timeseries data | `getPageviews(websiteId:dateRange:)` |
| GET | `/api/websites/{id}/metrics` | Dimension metrics | `getMetrics(websiteId:dateRange:type:limit:)` |
| GET | `/api/websites/{id}/events` | Event list | `getEventsDetail(websiteId:dateRange:page:pageSize:)` |
| GET | `/api/websites/{id}/event-data/stats` | Event stats | `getEventsStats(websiteId:dateRange:)` |
| GET | `/api/websites/{id}/event-data/fields` | Event data fields | `getEventDataFields(websiteId:dateRange:)` |
| GET | `/api/websites/{id}/event-data/values` | Event data values | `getEventDataValues(websiteId:dateRange:eventName:propertyName:)` |
| GET | `/api/websites/{id}/sessions` | Session list | `getSessions(websiteId:dateRange:page:pageSize:)` |
| GET | `/api/websites/{id}/sessions/{sid}` | Single session | `getSession(websiteId:sessionId:)` |
| GET | `/api/websites/{id}/sessions/{sid}/activity` | Session activity | `getSessionActivity(websiteId:sessionId:dateRange:)` |
| GET | `/api/realtime/{id}` | Realtime data | `getRealtime(websiteId:)` |
| POST | `/api/websites` | Create website | `createWebsite(name:domain:teamId:)` |
| POST | `/api/websites/{id}` | Update website | `updateWebsite(websiteId:name:domain:shareId:clearShareId:)` |
| DELETE | `/api/websites/{id}` | Delete website | `deleteWebsite(websiteId:)` |
| GET | `/api/reports` | List reports | `getReports(websiteId:page:pageSize:)` |
| POST | `/api/reports/journey` | Journey report | `getJourneyReport(websiteId:dateRange:steps:)` |
| POST | `/api/reports/retention` | Retention report | `getRetention(websiteId:dateRange:)` |
| POST | `/api/reports/funnel` | Funnel report | `getFunnelReport(websiteId:dateRange:steps:window:)` |
| POST | `/api/reports/goal` | Goal report | `getGoalReport(websiteId:dateRange:goalType:goalValue:)` |
| POST | `/api/reports/attribution` | Attribution report | `getAttributionReport(websiteId:dateRange:model:type:step:)` |
| GET | `/api/admin/teams` | List teams (admin) | `getTeams()` |
| POST | `/api/teams` | Create team | `createTeam(name:)` |
| DELETE | `/api/teams/{id}` | Delete team | `deleteTeam(teamId:)` |
| GET | `/api/teams/{id}/users` | Team members | `getTeamMembers(teamId:)` |
| POST | `/api/teams/{id}/users` | Add team member | `addTeamMember(teamId:userId:role:)` |
| DELETE | `/api/teams/{id}/users/{uid}` | Remove member | `removeTeamMember(teamId:userId:)` |
| GET | `/api/admin/users` | List users (admin) | `getUsers()` |
| POST | `/api/users` | Create user | `createUser(username:password:role:)` |
| DELETE | `/api/users/{id}` | Delete user | `deleteUser(userId:)` |

**UTM Report:** Not a direct API call; parses UTM parameters from `query` metric type results (`getUTMReport` in `UmamiAPI.swift`).

**Metric Types (Umami):**
`path`, `referrer`, `browser`, `os`, `device`, `country`, `region`, `city`, `language`, `screen`, `event`, `query`, `title`, `hostname` - defined in `MetricType` enum at `InsightFlow/Models/Stats.swift`.

### Plausible Analytics API

- **Provider type:** `AnalyticsProviderType.plausible`
- **Default cloud URL:** `https://plausible.io`
- **Self-hosted:** Any URL (user-provided, normalized: https prefix added, trailing slashes removed)
- **Client:** `actor PlausibleAPI` at `InsightFlow/Services/PlausibleAPI.swift` (singleton: `PlausibleAPI.shared`)
- **Auth:** API key (manually obtained from Plausible account settings); stored in Keychain as `.apiKey`
- **Auth header:** `Authorization: Bearer {apiKey}`
- **Timeout:** 15s for auth validation, 30s for data requests
- **Date format:** `yyyy-MM-dd` for day ranges, `yyyy-MM-dd HH:mm:ss` for hourly; native shortcuts (`"day"`, `"7d"`, `"30d"`, `"month"`, `"year"`)

**Plausible API Endpoints Used:**

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/api/v2/query` | All analytics queries (stats, timeseries, breakdown by dimension) |
| GET | `/api/v1/sites` | List sites (for site management) |
| GET | `/api/v1/stats/realtime/visitors?site_id=` | Active visitors (v1 API for CE compatibility) |

**Plausible Query Dimensions:**
`visit:source`, `visit:referrer`, `visit:utm_source`, `visit:utm_medium`, `visit:utm_campaign`, `visit:utm_content`, `visit:utm_term`, `visit:country`, `visit:region`, `visit:city`, `visit:device`, `visit:browser`, `visit:os`, `visit:entry_page`, `visit:exit_page`, `event:page`, `event:name`, `time:day`, `time:hour`

**Plausible Data Conversions (important):**
- Bounce rate: Plausible returns percentage (e.g., 31 for 31%); converted to absolute count: `bounces = bounce_rate * visits / 100`
- Visit duration: Plausible returns average seconds per visit; converted to total time: `totaltime = visit_duration * visits`
- These conversions happen in `PlausibleAPI.getAnalyticsStats()` to match the unified `AnalyticsStats` model

## Provider Abstraction Layer

**Protocol:** `AnalyticsProvider` at `InsightFlow/Services/AnalyticsProvider.swift`

Both `UmamiAPI` and `PlausibleAPI` conform to this protocol. Key unified methods:
- `authenticate(serverURL:credentials:)` - Provider-specific login
- `getAnalyticsWebsites()` -> `[AnalyticsWebsite]`
- `getAnalyticsStats(websiteId:dateRange:)` -> `AnalyticsStats`
- `getPageviewsData(websiteId:dateRange:)` -> `[AnalyticsChartPoint]`
- `getVisitorsData(websiteId:dateRange:)` -> `[AnalyticsChartPoint]`
- `getActiveVisitors(websiteId:)` -> `Int`
- `getRealtimeData(websiteId:)` -> `AnalyticsRealtimeData`
- `getPages/getReferrers/getCountries/getDevices/getBrowsers/getOS/getRegions/getCities/getPageTitles/getLanguages/getScreens/getEvents` -> `[AnalyticsMetricItem]`

**Credentials enum:** `AnalyticsCredentials` - `.umami(username:password:)` or `.plausible(apiKey:)`

**Manager:** `AnalyticsManager` (`@MainActor`) manages current provider and persists provider type to Keychain.

## Data Storage

**Databases:**
- None - stateless client application, no local database

**File Storage (App Group Container):**
- Cache location: `group.de.godsapp.statflow/analytics_cache/`
- Cache format: JSON files with TTL metadata wrapper (`CacheWrapper<T>`)
- Cache TTL: 3600s default (1 hour), 900s for sparklines (15 min)
- Cache max size: 100MB (enforced at app startup in `InsightFlowApp.init()`)
- Stale entry cleanup: entries older than 7 days removed at app startup
- Service: `AnalyticsCacheService` at `InsightFlow/Services/AnalyticsCacheService.swift`

**Widget Credential Storage:**
- Encrypted file: `group.de.godsapp.statflow/widget_credentials.encrypted`
- Encryption key file: `group.de.godsapp.statflow/widget_credentials.key`
- Multi-account file: `group.de.godsapp.statflow/widget_accounts.encrypted`
- Encryption: AES-GCM 256-bit via CryptoKit (`InsightFlow/Services/SharedCredentials.swift`)
- Legacy migration: automatically migrates unencrypted `widget_credentials.json` to encrypted format

**Keychain Storage:**
- Service identifier: `de.godsapp.statflow`
- Global keys: `serverURL`, `authToken`, `username`, `providerType`, `serverType`, `apiKey`, `plausibleSiteId`
- Account-scoped keys: `token_{accountUUID}`, `apiKey_{accountUUID}`
- Accessibility: `kSecAttrAccessibleAfterFirstUnlock`
- Service: `KeychainService` at `InsightFlow/Services/KeychainService.swift`

**UserDefaults:**
- `analytics_accounts` - Account list (credentials stripped, stored in Keychain separately)
- `active_account_id` - UUID string of active account
- `credentials_migrated_v2` - Migration flag for Keychain migration (SEC-04)
- `notificationSettings` - Per-website notification preferences (JSON)
- `notificationTime` - Scheduled notification time
- `notificationDataSource` - today/yesterday/auto
- `dashboard_enabled_metrics` - Visible dashboard metrics
- `dashboard_show_graph` - Graph visibility toggle
- `dashboard_chart_style` - line/bar
- `dashboard_show_date_range_picker` - Date range picker visibility
- `supportReminderShown`, `hasSupported`, `appLaunchCount` - Support reminder tracking

## Authentication & Identity

**Auth Provider:**
- Custom implementation - no OAuth, no third-party auth SDK

**Umami Login Flow:**
1. User enters server URL + username + password in `InsightFlow/Views/Auth/LoginView.swift`
2. POST to `/api/auth/login` with JSON body `{"username": ..., "password": ...}`
3. Response contains `token` (JWT-like string)
4. Token + serverURL + username + providerType saved to Keychain
5. `UmamiAPI.shared` configured with `baseURL` and `token` (actor state)
6. Account created via `AccountManager.addAccount()` with credentials

**Plausible Auth Flow:**
1. User enters server URL + API key in `InsightFlow/Views/Auth/LoginView.swift`
2. Validation: POST to `/api/v2/query` with empty body
3. HTTP 400 = key valid (malformed request expected); HTTP 401 = invalid key
4. Server URL normalized (https prefix, no trailing slash)
5. API key + serverURL saved to Keychain
6. Provider type set to `.plausible` via `AnalyticsManager.shared.saveProviderType()`

**Multi-Account Architecture:**
- Model: `AnalyticsAccount` at `InsightFlow/Services/AccountManager.swift`
- Accounts stored in UserDefaults (credentials stripped out)
- Credentials stored in Keychain by `{credentialType}_{accountUUID}`
- On load: accounts hydrated with Keychain credentials via `hydrateWithKeychainCredentials()`
- Switching accounts: `AccountManager.setActiveAccount()` writes to Keychain, reconfigures API actors, posts `.accountDidChange` notification, reloads widget timelines
- Migration from legacy single-account system via `migrateFromLegacyCredentials()`
- Migration from UserDefaults credentials to Keychain via `migrateCredentialsToKeychain()` (SEC-04 fix)

## Monitoring & Observability

**Error Tracking:**
- None - no Sentry, Crashlytics, or similar

**Logs:**
- `#if DEBUG print(...)` throughout service layer
- No persistent logging, no log levels, no crash reporting

## CI/CD & Deployment

**Hosting:**
- Apple App Store (native iOS app)
- No TestFlight configuration in codebase

**CI Pipeline:**
- Not detected - assumed manual Xcode Archive + App Store Connect upload

## Webhooks & Callbacks

**Incoming:**
- Deep link: `statflow://website?id={websiteId}&provider={umami|plausible}`
- Handled in `InsightFlowApp.handleDeepLink(_:)` at `InsightFlow/App/InsightFlowApp.swift`
- Triggers account switching if needed + navigation to website detail

**Outgoing:**
- None - read-only analytics client, no write-back or webhook calls

## Notifications

**Local Notifications:**
- Scheduled via `UNCalendarNotificationTrigger` (daily or weekly)
- Background refresh via `BGAppRefreshTask` (identifier: `de.godsapp.statflow.refresh`)
- Per-website settings: disabled / daily / weekly (`NotificationSetting` enum)
- Data source: today / yesterday / auto (morning=yesterday, evening=today)
- Summary mode: when 5+ websites enabled, sends single summary notification per account
- Thread grouping: `threadIdentifier = "account-{accountUUID}"`
- Service: `NotificationManager` at `InsightFlow/Services/NotificationManager.swift`

## Widget Integration

**Widget Extension:** `InsightFlowWidget/`
- Uses `AppIntentTimelineProvider` for configuration
- Configurable: account, website, time range
- Reads credentials from encrypted App Group files (`SharedCredentials`)
- Has its own networking layer (`InsightFlowWidget/Networking/WidgetNetworking.swift`)
- Has its own cache (`InsightFlowWidget/Cache/WidgetCache.swift`)
- Refresh policy: every 15 minutes
- Supported sizes: small, medium

**Data Sharing (App -> Widget):**
1. Main app writes encrypted credentials to App Group container
2. Main app syncs all accounts to `widget_accounts.encrypted`
3. Widget reads and decrypts at timeline refresh
4. Widget makes its own API calls using decrypted credentials
5. `WidgetCenter.shared.reloadAllTimelines()` called after account changes

## Error Handling

**Error Enums:**
- `APIError` (Umami): `.notConfigured`, `.invalidURL`, `.invalidResponse`, `.authenticationFailed`, `.unauthorized`, `.serverError(Int)` - at `InsightFlow/Services/UmamiAPI.swift`
- `PlausibleError`: `.notAuthenticated`, `.invalidCredentials`, `.invalidResponse`, `.unauthorized`, `.serverError(Int)`, `.noData` - at `InsightFlow/Services/PlausibleAPI.swift`
- `KeychainError`: `.saveFailed(OSStatus)` - at `InsightFlow/Services/KeychainService.swift`
- `SharedCredentials.EncryptionError`: `.encryptionFailed`, `.decryptionFailed` - at `InsightFlow/Services/SharedCredentials.swift`

**HTTP Error Handling Pattern:**
```swift
guard (200...299).contains(httpResponse.statusCode) else {
    if httpResponse.statusCode == 401 { throw APIError.unauthorized }
    throw APIError.serverError(httpResponse.statusCode)
}
```

---

*Integration audit: 2026-04-04*
