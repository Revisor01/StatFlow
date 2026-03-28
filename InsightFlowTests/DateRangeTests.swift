import XCTest
@testable import InsightFlow

final class DateRangeTests: XCTestCase {

    func testTodayStartBeforeOrEqualEnd() {
        let dates = DateRange.today.dates
        XCTAssertLessThanOrEqual(dates.start, dates.end)
    }

    func testTodayUnitIsHour() {
        XCTAssertEqual(DateRange.today.unit, "hour")
    }

    func testYesterdayUnitIsHour() {
        XCTAssertEqual(DateRange.yesterday.unit, "hour")
    }

    func testLast7DaysSpanIs6Days() {
        let dates = DateRange.last7Days.dates
        let diff = Calendar.current.dateComponents([.day], from: dates.start, to: dates.end).day ?? 0
        XCTAssertEqual(diff, 6, "Last 7 days sollte 6 Tage Differenz haben (heute - 6)")
    }

    func testLast30DaysSpanIs29Days() {
        let dates = DateRange.last30Days.dates
        let diff = Calendar.current.dateComponents([.day], from: dates.start, to: dates.end).day ?? 0
        XCTAssertEqual(diff, 29, "Last 30 days sollte 29 Tage Differenz haben (heute - 29)")
    }

    func testLast30DaysUnitIsDay() {
        XCTAssertEqual(DateRange.last30Days.unit, "day")
    }

    func testThisYearUnitIsMonth() {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let daysSinceJanFirst = calendar.dateComponents([.day], from: startOfYear, to: now).day ?? 0
        // Nur testen wenn wir mehr als 90 Tage nach Jahresanfang sind
        guard daysSinceJanFirst > 90 else {
            XCTAssertEqual(DateRange.thisYear.unit, "day", "Vor Tag 90: Einheit sollte 'day' sein")
            return
        }
        XCTAssertEqual(DateRange.thisYear.unit, "month", "Nach Tag 90: Einheit sollte 'month' sein")
    }

    func testCustomRangePreservesExactDates() {
        let start = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        let end = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 31))!
        let range = DateRange.custom(start: start, end: end)
        XCTAssertEqual(range.dates.start, start)
        XCTAssertEqual(range.dates.end, end)
    }

    func testAllPresetsStartBeforeEnd() {
        let presets: [DateRange] = [
            .today, .yesterday, .thisWeek, .last7Days,
            .last30Days, .thisMonth, .lastMonth, .thisYear, .lastYear
        ]
        for range in presets {
            let dates = range.dates
            XCTAssertLessThanOrEqual(
                dates.start, dates.end,
                "Preset \(range.preset.rawValue): start muss <= end sein"
            )
        }
    }

    func testThisWeekStartsOnMonday() {
        let dates = DateRange.thisWeek.dates
        let weekday = Calendar.current.component(.weekday, from: dates.start)
        // weekday: 1=Sunday, 2=Monday in Gregorian Calendar
        XCTAssertEqual(weekday, 2, "thisWeek muss am Montag beginnen (weekday=2)")
    }
}
