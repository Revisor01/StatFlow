# Technology Stack

**Analysis Date:** 2026-04-04

## Languages

**Primary:**
- Swift 6.0 - All application code (`InsightFlow/`, `InsightFlowWidget/`, `InsightFlowTests/`)

**Secondary:**
- Objective-C interop - Minimal, only `objc_setAssociatedObject` in `InsightFlow/App/InsightFlowApp.swift` for notification delegate retention

## Runtime

**Environment:**
- iOS 18.0+ (deployment target: `IPHONEOS_DEPLOYMENT_TARGET = 18.0`)
- A secondary 26.1 deployment target exists in project (likely future/beta config)

**Package Manager:**
- None - zero third-party dependencies
- No SPM `Package.swift`, no CocoaPods, no Carthage
- Entire codebase is first-party Swift code using Apple system frameworks only

## Frameworks

**Core (Apple System Frameworks):**
- **SwiftUI** - All UI, app entry point (`@main struct PrivacyFlowApp: App` in `InsightFlow/App/InsightFlowApp.swift`)
- **Foundation** - Networking (`URLSession`), JSON decoding, date handling
- **Combine** - `@Published` properties, `ObservableObject` throughout all services and view models
- **WidgetKit** - Home screen widgets (`InsightFlowWidget/`)
- **AppIntents** - Widget configuration with account/website/time range selection (`InsightFlowWidget/Intents/WidgetIntents.swift`)
- **BackgroundTasks** - `BGAppRefreshTask` for scheduled notification delivery (`InsightFlowApp.swift`)
- **UserNotifications** - Local push notifications with stats summaries (`InsightFlow/Services/NotificationManager.swift`)
- **StoreKit 2** - In-app tip jar / support purchases (`InsightFlow/Services/SupportManager.swift`)
- **Security** - Keychain Services for credential storage (`InsightFlow/Services/KeychainService.swift`)
- **CryptoKit** - AES-GCM 256-bit encryption for widget shared credentials (`InsightFlow/Services/SharedCredentials.swift`)
- **Charts** (SwiftUI Charts) - Dashboard sparklines, detail view charts, widget charts

**Testing:**
- XCTest - Unit tests in `InsightFlowTests/`
- No third-party test frameworks

**Build/Dev:**
- Xcode project-based (`.xcodeproj` only, no workspace)
- No CI/CD configuration, build scripts, or linter configs detected

## Key Dependencies

All dependencies are Apple first-party frameworks. No third-party packages.

**Critical:**
- `URLSession` - All HTTP networking for both Umami and Plausible APIs
- `JSONDecoder` / `JSONSerialization` - API response parsing (custom date strategies)
- Keychain Services (`Security.framework`) - Token/API key storage, scoped per account UUID
- `CryptoKit` AES-GCM - Encrypts shared widget credential files on disk

**Infrastructure:**
- App Groups (`group.de.godsapp.statflow`) - Shared data between app and widget extension
- Keychain accessibility: `kSecAttrAccessibleAfterFirstUnlock` for background access

**Concurrency Model:**
- `actor UmamiAPI` - Thread-safe Umami API client (`InsightFlow/Services/UmamiAPI.swift`)
- `actor PlausibleAPI` - Thread-safe Plausible API client (`InsightFlow/Services/PlausibleAPI.swift`)
- `@MainActor class AccountManager` - Multi-account management (`InsightFlow/Services/AccountManager.swift`)
- `@MainActor class AnalyticsManager` - Provider switching (`InsightFlow/Services/AnalyticsProvider.swift`)
- `@MainActor class NotificationManager` - Notification scheduling (`InsightFlow/Services/NotificationManager.swift`)
- `@MainActor class DashboardSettingsManager` - Dashboard preferences (`InsightFlow/Services/DashboardSettingsManager.swift`)
- `@MainActor class SupportManager` - IAP management (`InsightFlow/Services/SupportManager.swift`)
- `@MainActor class QuickActionManager` - Deep link handling (`InsightFlow/App/InsightFlowApp.swift`)
- `final class AnalyticsCacheService: @unchecked Sendable` - File-based cache (`InsightFlow/Services/AnalyticsCacheService.swift`)

## Configuration

**Environment:**
- No `.env` files - all configuration is runtime (Keychain + UserDefaults)
- Credentials stored in iOS Keychain, scoped per account ID
- Widget credentials stored as AES-GCM encrypted files in App Group container
- Dashboard preferences stored in UserDefaults via `DashboardSettingsManager`
- Notification settings stored in UserDefaults via `NotificationManager`

**Build:**
- `InsightFlow.xcodeproj/project.pbxproj` - Single Xcode project
- `InsightFlow/InsightFlow.entitlements` - App entitlements (App Groups, Keychain Sharing)
- `InsightFlowWidgetExtension.entitlements` - Widget extension entitlements

**App Identity:**
- Bundle ID: `de.godsapp.statflow`
- Widget Bundle ID: `de.godsapp.statflow.InsightFlowWidget`
- Test Bundle ID: `de.godsapp.statflow.InsightFlowTests`
- Marketing Version: 1.3
- Current Project Version: 1
- Development Team: J459G9CJT5
- Deep link scheme: `statflow://`
- Background task ID: `de.godsapp.statflow.refresh`
- Display name in project: "PrivacyFlow" (internal/legacy name; product marketed as "InsightFlow")

## Localization

**Languages:**
- German (`de`) - `InsightFlow/Resources/de.lproj/Localizable.strings`
- English (`en`) - `InsightFlow/Resources/en.lproj/Localizable.strings`
- Uses `String(localized:)` API throughout (modern Swift localization)
- Some hardcoded German strings remain in service layer (error messages in `APIError`, metric display names in `MetricType`)

## Targets

| Target | Type | Bundle ID | Device |
|--------|------|-----------|--------|
| InsightFlow | iOS App | `de.godsapp.statflow` | iPhone + iPad (`1,2`) |
| InsightFlowWidget | Widget Extension | `de.godsapp.statflow.InsightFlowWidget` | iPhone only (`1`) |
| InsightFlowTests | Unit Tests | `de.godsapp.statflow.InsightFlowTests` | - |

## In-App Purchases

**Product IDs (consumable tips):**
- `de.godsapp.statflow.support.small` - Small tip
- `de.godsapp.statflow.support.medium` - Medium tip
- `de.godsapp.statflow.support.large` - Large tip

Managed via `InsightFlow/Services/SupportManager.swift` using StoreKit 2 (`Product.products(for:)`, `product.purchase()`).

## Platform Requirements

**Development:**
- Xcode (latest, supporting Swift 6.0 and iOS 18.0 SDK)
- Apple Developer account (for entitlements, Keychain Sharing, App Groups, StoreKit)
- No external tooling, no build scripts, no linters configured

**Production:**
- iOS 18.0+ device (iPhone required; iPad supported for main app)
- Requires network access to user's Umami or Plausible API server
- Requires App Groups entitlement for widget data sharing
- App Store distribution (code signing required)

---

*Stack analysis: 2026-04-04*
