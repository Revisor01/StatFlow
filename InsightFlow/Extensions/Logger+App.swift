import Foundation
import os

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "de.godsapp.statflow"

    /// API calls and responses (UmamiAPI, PlausibleAPI)
    static let api = Logger(subsystem: subsystem, category: "api")
    /// Cache operations (AnalyticsCacheService)
    static let cache = Logger(subsystem: subsystem, category: "cache")
    /// Authentication and account management
    static let auth = Logger(subsystem: subsystem, category: "auth")
    /// UI and ViewModel operations
    static let ui = Logger(subsystem: subsystem, category: "ui")
}
