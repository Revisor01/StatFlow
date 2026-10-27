import Foundation

enum DateRangePreset: String, CaseIterable, Identifiable, Sendable {
    case today = "today"
    case yesterday = "yesterday"
    case thisWeek = "week"
    case last7Days = "7d"
    case last30Days = "30d"
    case thisMonth = "month"
    case lastMonth = "last_month"
    case thisYear = "year"
    case lastYear = "last_year"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .today: return String(localized: "daterange.today")
        case .yesterday: return String(localized: "daterange.yesterday")
        case .thisWeek: return String(localized: "daterange.thisWeek")
        case .last7Days: return String(localized: "daterange.last7days")
        case .last30Days: return String(localized: "daterange.last30days")
        case .thisMonth: return String(localized: "daterange.thisMonth")
        case .lastMonth: return String(localized: "daterange.lastMonth")
        case .thisYear: return String(localized: "daterange.thisYear")
        case .lastYear: return String(localized: "daterange.lastYear", defaultValue: "Last Year")
        case .custom: return String(localized: "daterange.custom")
        }
    }

    static var presets: [DateRangePreset] {
        allCases.filter { $0 != .custom }
    }
}

struct DateRange: Equatable, Sendable {
    let preset: DateRangePreset
    let customStart: Date?
    let customEnd: Date?

    static let today = DateRange(preset: .today)
    static let yesterday = DateRange(preset: .yesterday)
    static let thisWeek = DateRange(preset: .thisWeek)
    static let last7Days = DateRange(preset: .last7Days)
    static let last30Days = DateRange(preset: .last30Days)
    static let thisMonth = DateRange(preset: .thisMonth)
    static let lastMonth = DateRange(preset: .lastMonth)
    static let thisYear = DateRange(preset: .thisYear)
    static let lastYear = DateRange(preset: .lastYear)

    init(preset: DateRangePreset, customStart: Date? = nil, customEnd: Date? = nil) {
        self.preset = preset
        self.customStart = customStart
        self.customEnd = customEnd
    }

    static func custom(start: Date, end: Date) -> DateRange {
        DateRange(preset: .custom, customStart: start, customEnd: end)
    }

    var displayName: String {
        if preset == .custom, let start = customStart, let end = customEnd {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        }
        return preset.displayName
    }

    var dates: (start: Date, end: Date) {
        if preset == .custom, let start = customStart, let end = customEnd {
            return (start, end)
        }

        let calendar = Calendar.current
        let now = Date()
        let endOfToday = calendar.startOfDay(for: now).addingTimeInterval(86400 - 1)

        switch preset {
        case .today:
            return (calendar.startOfDay(for: now), endOfToday)

        case .yesterday:
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
            let startOfYesterday = calendar.startOfDay(for: yesterday)
            let endOfYesterday = startOfYesterday.addingTimeInterval(86400 - 1)
            return (startOfYesterday, endOfYesterday)

        case .thisWeek:
            // Start of current week (Monday)
            let weekday = calendar.component(.weekday, from: now)
            // Woche beginnt am Montag (weekday 2, Sonntag = 1).
            let daysFromMonday = (weekday + 5) % 7  // Convert to days since Monday
            let startOfWeek = calendar.date(byAdding: .day, value: -daysFromMonday, to: calendar.startOfDay(for: now))!
            return (startOfWeek, endOfToday)

        case .last7Days:
            let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))!
            return (start, endOfToday)

        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now))!
            return (start, endOfToday)

        case .thisMonth:
            let components = calendar.dateComponents([.year, .month], from: now)
            let start = calendar.date(from: components)!
            return (start, endOfToday)

        case .lastMonth:
            let components = calendar.dateComponents([.year, .month], from: now)
            let startOfThisMonth = calendar.date(from: components)!
            let endOfLastMonth = startOfThisMonth.addingTimeInterval(-1)
            let lastMonthComponents = calendar.dateComponents([.year, .month], from: endOfLastMonth)
            let startOfLastMonth = calendar.date(from: lastMonthComponents)!
            return (startOfLastMonth, endOfLastMonth)

        case .thisYear:
            let year = calendar.component(.year, from: now)
            let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
            return (startOfYear, endOfToday)

        case .lastYear:
            let year = calendar.component(.year, from: now) - 1
            let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
            let endOfYear = calendar.date(from: DateComponents(year: year, month: 12, day: 31, hour: 23, minute: 59, second: 59))!
            return (startOfYear, endOfYear)

        case .custom:
            return (calendar.startOfDay(for: now), endOfToday)
        }
    }

    var unit: String {
        let daysDiff = Calendar.current.dateComponents([.day], from: dates.start, to: dates.end).day ?? 0

        if daysDiff <= 1 {
            return "hour"
        } else if daysDiff <= 90 {
            return "day"
        } else {
            return "month"
        }
    }

    static var allCases: [DateRange] {
        [.today, .yesterday, .thisWeek, .last7Days, .thisMonth, .lastMonth]
    }

    /// Default date range for the app
    static var defaultRange: DateRange {
        .thisWeek
    }
}
