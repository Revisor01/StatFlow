# Technology Stack

**Analysis Date:** 2026-03-28

## Languages

**Primary:**
- Swift 5.10+ - iOS app, widgets, tests

**Secondary:**
- Objective-C - Minimal use, mostly via Swift interop (Security framework)

## Runtime

**Environment:**
- iOS 18.0+ (deployment target)
- iPad OS (SwiftUI supports universal apps)
- WidgetKit 6.0+ (for iOS 17+/18+)

**Build System:**
- Xcode 15.x+ (Swift 5.10 support)
- Apple Clang compiler

## Frameworks

**Core (Apple):**
- SwiftUI - UI layer, all views and navigation
- Foundation - Standard library, networking, data handling
- Combine - Reactive programming for state management
- UserNotifications - Local and push notifications
- BackgroundTasks - App refresh scheduling (BGAppRefreshTask)
- Security - Keychain access (SecItem APIs)
- WidgetKit - Native iOS widget extension

**Networking:**
- URLSession - HTTP networking, default Apple framework
- No third-party HTTP clients or libraries

**Data Storage:**
- Keychain Services - Secure credential storage (via Security framework)
- FileManager - App group container for cache storage
- UserDefaults - User preferences and settings
- JSON Codable - Data serialization/deserialization

**Localization:**
- Strings files (localized resources)
- String(localized:) for runtime localization

**Testing:**
- XCTest - Unit testing framework
- No third-party test frameworks

## Key Dependencies

**Critical:**
- URLSession - HTTP client for Umami and Plausible API calls
- Keychain Services - Stores authentication tokens (umami), API keys (plausible), credentials per account
- WidgetKit - Enables iOS lock screen and home screen widgets

**Data Processing:**
- JSONDecoder/JSONEncoder - Custom date formatting for ISO8601 with fractional seconds
- AnalyticsCacheService - Custom caching with app group container support

**Actor-Based Concurrency:**
- UmamiAPI (actor) - Thread-safe Umami API client
- PlausibleAPI (actor) - Thread-safe Plausible API client
- AccountManager (@MainActor) - Multi-account management on main thread
- NotificationManager (@MainActor) - Notification scheduling on main thread
- QuickActionManager (@MainActor) - Deep link handling

## Configuration

**Environment:**
- Bundle identifier: `de.godsapp.statflow`
- App groups: `group.de.godsapp.statflow` (shared with widget)
- Keychain service: `de.godsapp.statflow`
- Widget identifier: `PrivacyFlowWidget`
- Widget supported sizes: `.systemSmall`, `.systemMedium`

**Build Targets:**
- InsightFlow (main app)
- InsightFlowWidgetExtension (widget app extension)
- InsightFlowTests (unit tests)

**File Organization:**
- `InsightFlow/` - Main app source
- `InsightFlowWidget/` - Widget extension (separate bundle)
- `InsightFlowTests/` - XCTest unit tests
- `build/` - Build artifacts

**Background Task:**
- Task identifier: `de.godsapp.statflow.refresh` (for app refresh notifications)
- Earliest begin date: Configurable notification time (default 9:00 AM)

## Platform Requirements

**Development:**
- Xcode 15+ with iOS 18 SDK
- macOS 13.0+ (for running Xcode)
- Swift 5.10+

**Production:**
- Deployment target: iOS 18.0+
- Code signing: Required for App Store
- Push notifications entitlements: Not required (local only)
- Keychain Sharing capability: Enabled for secure storage

---

*Stack analysis: 2026-03-28*
