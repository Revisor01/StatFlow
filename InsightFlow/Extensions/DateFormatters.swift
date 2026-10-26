import Foundation

/// Shared DateFormatter instances to avoid expensive repeated allocations.
/// DateFormatter is Sendable; ISO8601DateFormatter is not, so those two need
/// nonisolated(unsafe). All of them are only read after initialization.
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
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// Short date style for UI display (locale-aware)
    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        return f
    }()

    /// "yyyy-MM-dd HH:mm:ss" for Plausible hourly data
    static let yyyyMMddHHmmss: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// Medium date+time for UI display (locale-aware)
    static let mediumDateTime: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    /// "MMM yyyy" for month display
    static let monthYear: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()
}
