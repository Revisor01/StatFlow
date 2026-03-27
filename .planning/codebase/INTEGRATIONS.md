# External Integrations

**Analysis Date:** 2026-03-27

## APIs & Services

| Service | Purpose | Auth Method | API Client |
|---------|---------|-------------|------------|
| Umami Analytics | Website analytics (stats, pageviews, sessions, realtime, admin) | Bearer token (JWT from username/password login) | `InsightFlow/Services/UmamiAPI.swift` |
| Plausible Analytics | Website analytics (stats, pageviews, realtime, site management) | Bearer token (API key) | `InsightFlow/Services/PlausibleAPI.swift` |
| Apple StoreKit | In-app purchase tips | App Store receipt verification | `InsightFlow/Services/SupportManager.swift` |

## Umami API Integration

**Client:** `InsightFlow/Services/UmamiAPI.swift` (Swift `actor`, thread-safe)

**Authentication:**
- Login: `POST {serverURL}/api/auth/login` with `{"username", "password"}`
- Returns JWT token, stored in Keychain under key `authToken`
- All subsequent requests use `Authorization: Bearer {token}` header

**Endpoints Used:**

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `api/auth/login` | POST | Authenticate, get JWT token |
| `api/websites` | GET | List all websites |
| `api/websites/{id}/active` | GET | Get active visitor count |
| `api/websites/{id}/stats` | GET | Get stats with comparison (visitors, pageviews, visits, bounces, totaltime) |
| `api/websites/{id}/pageviews` | GET | Get pageview/session timeseries data |
| `api/websites/{id}/metrics` | GET | Get breakdown metrics (pages, referrers, countries, devices, browsers, OS) |
| `api/websites/{id}/sessions` | GET | List sessions with pagination |
| `api/websites/{id}/sessions/{sid}/activity` | GET | Get session activity log |
| `api/websites` | POST | Create website |
| `api/websites/{id}` | POST | Update website (name, domain, shareId) |
| `api/websites/{id}` | DELETE | Delete website |
| `api/websites/{id}/reset` | POST | Reset website stats |
| `api/reports/retention` | POST | Get retention report |
| `api/reports/journey` | POST | Get user journey report |
| `api/admin/teams` | GET | List teams (admin) |
| `api/teams` | POST | Create team |
| `api/teams/{id}` | DELETE | Delete team |
| `api/teams/{id}/users` | GET/POST | List/add team members |
| `api/teams/{id}/users/{uid}` | DELETE | Remove team member |
| `api/admin/users` | GET | List users (admin) |
| `api/users` | POST | Create user |
| `api/users/{id}` | DELETE | Delete user |
| `api/realtime/{id}` | GET | Get realtime data (events, totals, series) |

**Query Parameters:**
- Time ranges use millisecond timestamps: `startAt`, `endAt`
- Units: `hour`, `day`, `month`
- Metric types: `path`, `referrer`, `browser`, `os`, `device`, `country`
- Pagination: `page`, `pageSize`

**Request Timeout:** 15s for login, 30s for all other requests

## Plausible API Integration

**Client:** `InsightFlow/Services/PlausibleAPI.swift` (`@MainActor` class)

**Authentication:**
- API key-based (no login flow)
- Validation: POST to `api/v2/query` with empty body -- expects 400 (valid key) or 401 (invalid)
- Key stored in Keychain under key `apiKey`
- Default server: `https://plausible.io` (supports self-hosted)

**API Versions Used:**

| API | Endpoints | Purpose |
|-----|-----------|---------|
| v2 (Query API) | `api/v2/query` | Stats, timeseries, breakdowns (POST with JSON body) |
| v1 (Stats API) | `api/v1/stats/realtime/visitors` | Realtime visitor count (GET) |
| v1 (Sites API) | `api/v1/sites`, `api/v1/sites/{domain}` | Site CRUD, shared links |

**v2 Query API Usage:**
```
POST api/v2/query
{
  "site_id": "example.com",
  "metrics": ["visitors", "pageviews", "visits", "bounce_rate", "visit_duration"],
  "date_range": "7d" | "day" | "month" | "year" | ["2024-01-01", "2024-01-31"],
  "dimensions": ["time:day" | "time:hour" | "event:page" | "visit:source" | "visit:country" | ...]
}
```

**Date Range Mapping (Plausible shortcuts):**
- today -> `"day"`
- last7Days -> `"7d"`
- last30Days -> `"30d"`
- thisMonth -> `"month"`
- thisYear -> `"year"`
- Other ranges -> custom `["start", "end"]` array

**Site Management (v1):**
- `POST api/v1/sites` - Create site (domain + timezone)
- `DELETE api/v1/sites/{domain}` - Delete site
- `GET api/v1/sites/{domain}` - Get site details
- `PUT api/v1/sites/{domain}/shared-links` - Create/get shared link

**Plausible Sites Storage:**
- Sites are NOT fetched from API (Plausible has no "list my sites" endpoint)
- User manually adds site domains via `PlausibleSitesManager` (`InsightFlow/Services/PlausibleAPI.swift`)
- Stored in UserDefaults (`plausible_sites` key) as JSON array of domain strings
- Also persisted per-account in `AccountManager`

## Provider Abstraction Layer

**Protocol:** `AnalyticsProvider` (`InsightFlow/Services/AnalyticsProvider.swift`)

Both Umami and Plausible implement this protocol, enabling unified data access:

```swift
protocol AnalyticsProvider: Sendable {
    var providerType: AnalyticsProviderType { get }
    var serverURL: String { get }
    var isAuthenticated: Bool { get }
    func authenticate(serverURL: String, credentials: AnalyticsCredentials) async throws
    func getAnalyticsWebsites() async throws -> [AnalyticsWebsite]
    func getAnalyticsStats(websiteId: String, dateRange: DateRange) async throws -> AnalyticsStats
    func getPageviewsData(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsChartPoint]
    func getVisitorsData(websiteId: String, dateRange: DateRange) async throws -> [AnalyticsChartPoint]
    func getActiveVisitors(websiteId: String) async throws -> Int
    func getRealtimeData(websiteId: String) async throws -> AnalyticsRealtimeData
    func getPages/getReferrers/getCountries/getDevices/getBrowsers/getOS(...)
}
```

**Manager:** `AnalyticsManager` (`InsightFlow/Services/AnalyticsProvider.swift`) -- singleton that holds the current provider and authentication state.

**Credentials:**
```swift
enum AnalyticsCredentials {
    case umami(username: String, password: String)
    case plausible(apiKey: String)
}
```

## Multi-Account Support

**Manager:** `AccountManager` (`InsightFlow/Services/AccountManager.swift`)

**Account Model:**
```swift
struct AnalyticsAccount: Codable, Identifiable {
    let id: UUID
    let name: String
    let serverURL: String
    let providerType: AnalyticsProviderType  // .umami | .plausible
    let credentials: AccountCredentials       // token and/or apiKey
    var sites: [String]?                      // Plausible site domains
}
```

**Account Switching Flow:**
1. `AccountManager.setActiveAccount()` called
2. Credentials written to Keychain (overwriting previous)
3. API client reconfigured (`UmamiAPI.reconfigureFromKeychain()` or `PlausibleAPI.reconfigureFromKeychain()`)
4. `AnalyticsManager.setProvider()` updates current provider
5. Widget credentials updated via `SharedCredentials`
6. `NotificationCenter` posts `.accountDidChange` (with 0.3s delay for data settling)

**Migration:** `migrateFromLegacyCredentials()` handles upgrading from single-account to multi-account system.

## Data Sharing (App <-> Widget)

**Mechanism:** File-based via App Group container (`group.de.godsapp.PrivacyFlow`)

**Files:**
| File | Format | Purpose |
|------|--------|---------|
| `widget_credentials.encrypted` | AES-GCM encrypted JSON | Primary credentials for widget |
| `widget_credentials.key` | Raw 256-bit key | Encryption key for credentials file |
| `widget_accounts.json` | Plain JSON | All accounts for multi-account widget support |
| `analytics_cache/*.json` | Plain JSON with TTL | Cached analytics data (accessible by both app and widget) |

**SharedCredentials** (`InsightFlow/Services/SharedCredentials.swift`):
- Encrypts with AES-GCM (CryptoKit) using a locally generated 256-bit symmetric key
- Handles legacy migration from unencrypted `widget_credentials.json`
- Contains: `serverURL`, `token`, `providerType`, `websiteId`, `websiteName`, `timeRange`, `sites`

## Analytics Cache

**Service:** `AnalyticsCacheService` (`InsightFlow/Services/AnalyticsCacheService.swift`)

**Storage:** JSON files in App Group container under `analytics_cache/` directory

**Cache TTLs:**
- Default: 3600s (1 hour)
- Sparklines: 900s (15 minutes)

**Cached Data Types:**
- Websites list (per account)
- Stats (per website + date range)
- Sparkline chart points (per website + date range)
- Metrics (per website + date range + metric type)

**Cache Keys:** Composite strings like `stats_{websiteId}_{dateRangeId}`, `sparkline_{websiteId}_{dateRangeId}`

## Notifications

**Service:** `NotificationManager` (`InsightFlow/Services/NotificationManager.swift`)

**Mechanism:**
- Uses `UNCalendarNotificationTrigger` for daily/weekly scheduled local notifications
- Background refresh via `BGAppRefreshTask` identifier `de.godsapp.PrivacyFlow.refresh`
- Fetches live stats from the API at notification time and includes data in notification body

**Notification Content:**
- Title: `{websiteName} ({accountName})`
- Subtitle: Period (Today/Yesterday/Last 7 days)
- Body: `{visitors} Besucher {change}% - {pageviews} Aufrufe {change}% - {visits} Besuche {change}%`

**Settings (per website):**
- `disabled` / `daily` / `weekly`
- Configurable notification time (default 9:00)
- Data source: `today` / `yesterday` / `auto` (morning=yesterday, evening=today)

## Deep Linking

**URL Scheme:** `privacyflow://`

**Supported URLs:**
- `privacyflow://website?id={websiteId}&provider={umami|plausible}`
- Handles account switching if needed (stores pending deep link)
- Implementation: `InsightFlowApp.handleDeepLink()` in `InsightFlow/App/InsightFlowApp.swift`

## Environment Configuration

**No environment files.** All configuration is user-provided at runtime:

| Setting | Storage | Input |
|---------|---------|-------|
| Server URL | Keychain (`serverURL`) | User enters during login |
| Umami token | Keychain (`authToken`) | Obtained from API login |
| Plausible API key | Keychain (`apiKey`) | User enters during login |
| Provider type | Keychain (`providerType`) | Selected during login |

**No hardcoded API URLs** -- both Umami and Plausible support self-hosted servers. The only default is Plausible Cloud at `https://plausible.io`.

---

*Integration audit: 2026-03-27*
