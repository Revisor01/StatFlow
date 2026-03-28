# External Integrations

**Analysis Date:** 2026-03-28

## APIs & External Services

**Umami Analytics:**
- Umami Cloud (default: `https://cloud.umami.is`)
- Self-hosted Umami servers (custom URLs)
- SDK/Client: Custom `UmamiAPI` actor (`InsightFlow/Services/UmamiAPI.swift`)
- Auth: Bearer token (JWT-like, stored in Keychain)
- Usage: Fetch websites, stats, realtime data, metrics (pages, referrers, countries, devices, browsers, OS, regions, cities, page titles, languages, screens, custom events)

**Plausible Analytics:**
- Plausible Cloud (default: `https://plausible.io`)
- Self-hosted Plausible servers (custom URLs via `serverURL` normalization)
- SDK/Client: Custom `PlausibleAPI` actor (`InsightFlow/Services/PlausibleAPI.swift`)
- Auth: Bearer API key (stored in Keychain as `apiKey`)
- API Endpoint: `POST /api/v2/query` for analytics queries
- Usage: Fetch sites, stats, realtime data, metrics, custom goals
- Key header: `Authorization: Bearer {apiKey}`, `Content-Type: application/json`

## Data Storage

**Databases:**
- None - stateless client application

**File Storage:**
- Local filesystem only (app group container)
- Cache location: `group.de.godsapp.statflow/analytics_cache/`
- Cache format: JSON files with TTL metadata
- Cache TTL: 3600s default (1 hour), 900s for sparklines (15 min)

**Caching:**
- Custom `AnalyticsCacheService` (`InsightFlow/Services/AnalyticsCacheService.swift`)
- Stores: websites, stats, sparklines, metrics
- App group shared: accessible to main app + widget
- Offline-capable: reads stale cached data if network fails

**Keychain Storage:**
- Service identifier: `de.godsapp.statflow`
- Stores:
  - `serverURL` - Analytics server base URL
  - `token` - Umami JWT token
  - `username` - Umami username (for reference)
  - `providerType` - Current provider (umami/plausible)
  - `apiKey` - Plausible API key
  - Account-scoped credentials: `token_{accountId}`, `apiKey_{accountId}`
- Accessibility: `kSecAttrAccessibleAfterFirstUnlock`

## Authentication & Identity

**Auth Provider:**
- Custom implementation (no OAuth)

**Umami Login Flow:**
1. POST `/api/auth/login` with `username`/`password`
2. Returns `token` (JWT-like string)
3. Token used in subsequent requests as `Authorization: Bearer {token}`
4. Token stored in Keychain
5. Session file: `InsightFlow/Views/Auth/LoginView.swift`, `LoginViewModel.swift`

**Plausible Auth Flow:**
1. Manual API key from Plausible account settings
2. Validate key by sending POST to `/api/v2/query` with empty body
3. Status 400 = key valid (malformed request), 401 = key invalid
4. API key stored in Keychain
5. Key used in requests as `Authorization: Bearer {apiKey}`
6. Session file: `InsightFlow/Views/Auth/LoginView.swift`

**Multi-Account Support:**
- `AnalyticsAccount` model stores account metadata + credentials per account
- Accounts persisted to `UserDefaults` (stripped of credentials)
- Credentials stored separately in Keychain by account UUID
- Active account tracked in `UserDefaults` key `active_account_id`
- Switching accounts via `AccountManager.setActiveAccount(_:)`

## Monitoring & Observability

**Error Tracking:**
- None detected - no Sentry, Crashlytics, or similar

**Logs:**
- Print-based debugging (conditionally compiled with `#if DEBUG`)
- Example: `InsightFlow/Services/AccountManager.swift`, `AnalyticsCacheService.swift`
- No persistent logging framework

## CI/CD & Deployment

**Hosting:**
- Apple App Store (native iOS app)
- No staging/beta infrastructure in codebase

**CI Pipeline:**
- Not found in codebase
- Assumed manual Xcode build + Archive → App Store Connect

## Environment Configuration

**Required env vars:**
- None - all configuration via app settings UI

**Secrets location:**
- iOS Keychain (no `.env` files)
- Credentials never persisted to UserDefaults or files
- See `KeychainService.swift` for access patterns

**Runtime Configuration:**
- Server URLs: User-provided via LoginView
- Credentials: User-provided via LoginView
- Account names: User-provided during setup
- Notification time: User-configurable in SettingsView
- Notification data source: User-configurable in SettingsView

## Webhooks & Callbacks

**Incoming:**
- Deep link support via `statflow://website?id={websiteId}&provider={umami|plausible}`
- Handled in `InsightFlowApp.swift` `handleDeepLink(_:)` method
- Triggers account switching + navigation to website detail view

**Outgoing:**
- None detected - read-only analytics client

## API Request Patterns

**Base URL Construction:**
- Umami: User-provided server URL (e.g., `https://umami.myserver.com`)
- Plausible: Normalized by removing trailing slashes and adding `https://` prefix if missing

**Standard Headers:**
- `Authorization: Bearer {token/apiKey}` (all authenticated requests)
- `Content-Type: application/json` (all POST/PUT requests)
- `Accept: application/json` (implicit from URLSession)

**Date Handling:**
- Umami: ISO8601 with optional fractional seconds (custom decoder)
- Plausible: Snake case to camelCase conversion (standard JSONDecoder strategy)

**Error Handling:**
- HTTP status codes checked before decoding
- Custom `APIError` enum for type-safe errors
- Umami-specific: `UmamiError` enum
- Plausible-specific: `PlausibleError` enum

**Timeout:**
- Default URLSession timeout: 15 seconds
- Configured in `URLRequest.timeoutInterval = 15`

## Data Models & Types

**Unified Analytics Models (AnalyticsProvider protocol):**
- `AnalyticsWebsite` - Site ID, name, domain, share ID, provider
- `AnalyticsStats` - Visitors, pageviews, visits, bounces, total time
- `AnalyticsChartPoint` - Date-based chart data
- `AnalyticsPageview` - URL, referrer, timestamp, geo (country/city)
- `AnalyticsEvent` - Event name, URL, timestamp
- `AnalyticsMetricItem` - Name/dimension + value
- `DateRange` - Enum: today, yesterday, last7Days, last30Days, last90Days, custom

**Umami-Specific Models:**
- `Website`, `WebsiteResponse`
- `Stats`, `StatsComparison`
- `Realtime`, `RealtimeEvent`
- `Metric`, `MetricsResponse`
- `Team`, `TeamsResponse`
- `MeResponse` - Current user info

**Plausible-Specific Models:**
- `PlausibleSite` - Site configuration
- `PlausibleStats` - Plausible-format stats
- `PlausibleGoal` - Custom goal definitions
- `PlausibleEvent` - Event tracking data

---

*Integration audit: 2026-03-28*
