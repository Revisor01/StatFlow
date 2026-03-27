# Technology Stack

**Analysis Date:** 2026-03-27

## Languages

**Primary:**
- Swift 6.0 - Main app target (`InsightFlow/`)
- Swift 5.0 - Widget extension target (`InsightFlowWidget/`)

## Runtime

**Environment:**
- iOS (iPhone + iPad)
- Xcode project format: objectVersion 77 (Xcode 16+)

**Deployment Targets:**
- Main app: iOS 18.0
- Widget extension: iOS 26.1

**Bundle Identifier:**
- App: `de.godsapp.PrivacyFlow`
- Widget: `de.godsapp.PrivacyFlow.InsightFlowWidget`

**Marketing Version:** 1.3

## Frameworks

**Core (Apple System Frameworks):**

| Name | Purpose |
|------|---------|
| SwiftUI | All UI, app lifecycle (`@main struct PrivacyFlowApp: App`) |
| WidgetKit | Home screen widgets with timeline-based updates |
| Foundation | Networking (`URLSession`), JSON coding, file management |
| Security | Keychain Services for credential storage |
| CryptoKit | AES-GCM encryption for shared credentials between app and widget |
| BackgroundTasks | `BGAppRefreshTask` for scheduled notification delivery |
| UserNotifications | Local push notifications for daily/weekly stats summaries |
| StoreKit | In-app purchases (tip jar / support the developer) |
| Combine | Reactive bindings in `AuthManager` (notification subscriptions) |
| AppIntents | Widget configuration intents |

**No third-party dependencies.** The project uses zero external packages -- no SPM, CocoaPods, or Carthage. All networking, JSON parsing, caching, and encryption use Apple frameworks only.

## Build System

**Build Tool:** Xcode (native `.xcodeproj`, no workspace)
- Project file: `InsightFlow.xcodeproj/project.pbxproj`
- Uses `PBXFileSystemSynchronizedRootGroup` (Xcode 16+ file sync feature)

**Package Manager:** None -- no `Package.swift`, no `Podfile`, no `Cartfile`

**Targets:**
1. `InsightFlow` - Main iOS app (Swift 6.0, iOS 18.0)
2. `InsightFlowWidgetExtension` - Widget extension (Swift 5.0, iOS 26.1)

**Key Build Settings:**
- `SWIFT_VERSION = 6.0` (main app), `5.0` (widget)
- `IPHONEOS_DEPLOYMENT_TARGET = 18.0` (main app), `26.1` (widget)
- `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`
- `INFOPLIST_KEY_LSApplicationCategoryType = public.app-category.utilities`
- Portrait only on iPhone, all orientations on iPad

## Configuration

**App Groups:**
- `group.de.godsapp.PrivacyFlow` - Shared container for app-widget communication
- Used by: `SharedCredentials`, `AnalyticsCacheService`, `AccountManager.syncAccountsToWidget()`

**Entitlements (App - `InsightFlow/InsightFlow.entitlements`):**
- `aps-environment`: Push notification entitlement (development)
- `com.apple.security.application-groups`: App Group for widget data sharing

**Entitlements (Widget - `InsightFlowWidgetExtension.entitlements`):**
- `com.apple.security.application-groups`: Same App Group

**Info.plist (`InsightFlow/Info.plist`):**
- `BGTaskSchedulerPermittedIdentifiers`: `de.godsapp.PrivacyFlow.refresh`
- `CFBundleLocalizations`: `en`, `de`
- `CFBundleURLSchemes`: `privacyflow` (deep linking)
- `UIBackgroundModes`: `fetch`, `processing`

**Localization:**
- Two languages: English (`en`) and German (`de`)
- Localization files: `InsightFlow/Resources/{en,de}.lproj/Localizable.strings`
- Widget localization: `InsightFlowWidget/Resources/{en,de}.lproj/Localizable.strings`
- Uses `String(localized:)` API throughout (modern Swift localization)

## Data Storage

**Keychain (`InsightFlow/Services/KeychainService.swift`):**
- Service identifier: `de.godsapp.PrivacyFlow`
- Keys: `serverURL`, `authToken`, `username`, `providerType`, `serverType`, `apiKey`, `plausibleSiteId`
- Accessibility: `kSecAttrAccessibleAfterFirstUnlock`

**UserDefaults:**
- Account list: `analytics_accounts` (JSON-encoded `[AnalyticsAccount]`)
- Active account: `active_account_id`
- Notification settings: `notificationSettings`, `notificationTime`, `notificationDataSource`
- Dashboard settings: `dashboard_enabled_metrics`, `dashboard_show_graph`, `dashboard_chart_style`, `dashboard_show_date_range_picker`
- Plausible sites: `plausible_sites`
- Support tracking: `supportReminderShown`, `hasSupported`, `appLaunchCount`

**App Group Container (file-based):**
- `widget_credentials.encrypted` - AES-GCM encrypted credentials for widget
- `widget_credentials.key` - Symmetric encryption key
- `widget_accounts.json` - Multi-account data for widget
- `analytics_cache/` - JSON cache files with TTL (1h default, 15min sparklines)

## In-App Purchases

**Product IDs (`InsightFlow/Services/SupportManager.swift`):**
- `de.godsapp.insightflow.support.small` (small tip)
- `de.godsapp.insightflow.support.medium` (medium tip)
- `de.godsapp.insightflow.support.large` (large tip)

Uses StoreKit 2 API (`Product.products(for:)`, `product.purchase()`).

## Platform Requirements

**Development:**
- Xcode 16+ (required for `PBXFileSystemSynchronizedRootGroup` and Swift 6.0)
- macOS (Xcode development)
- Apple Developer account (for App Groups, push notifications, StoreKit)

**Production:**
- iOS 18.0+ devices
- Network access required (connects to user-provided analytics server URLs)

---

*Stack analysis: 2026-03-27*
