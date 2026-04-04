import Foundation

/// Shared DateFormatter instances to avoid expensive repeated allocations.
/// Thread-safe: static let ensures single initialization, DateFormatter is
/// thread-safe for read-only access on iOS 7+.
/// nonisolated(unsafe) suppresses Sendable warnings — these are only used for
/// reading (date/string parsing), never mutated after initialization.
enum DateFormatters {
    /// ISO8601 with fractional seconds — for Umami API dates like "2024-01-15T10:30:00.000Z"
    nonisolated(unsafe) static let iso8601WithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// ISO8601 standard — fallback for dates without fractional seconds
    nonisolated(unsafe) static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// "yyyy-MM-dd" for Plausible API and date-only strings
    nonisolated(unsafe) static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// Short date style for UI display (locale-aware)
    nonisolated(unsafe) static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        return f
    }()

    /// "yyyy-MM-dd HH:mm:ss" for Plausible hourly data
    nonisolated(unsafe) static let yyyyMMddHHmmss: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// Medium date+time for UI display (locale-aware)
    nonisolated(unsafe) static let mediumDateTime: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    /// "MMM yyyy" for month display
    nonisolated(unsafe) static let monthYear: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()
}
