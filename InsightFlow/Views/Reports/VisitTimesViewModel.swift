import Foundation
import SwiftUI
import os

/// Eine Zeile der Heatmap: ein Wochentag mit seinen 24 Stundenwerten.
///
/// WICHTIG — Annahme zur Reihenfolge der API-Matrix:
/// `api/websites/{id}/sessions/weekly` liefert eine 7×24-Matrix, deren äußerer
/// Index dem SQL-Wochentag von Umami entspricht: **Index 0 = Sonntag**,
/// Index 6 = Samstag (so dokumentiert in `UmamiWeeklyTraffic` und identisch zu
/// `UmamiSessionsByDay.day` in Models/Stats.swift, „0=Sunday .. 6=Saturday“).
/// Die Anzeige-Reihenfolge stammt dagegen aus `Calendar.current.firstWeekday`
/// (in DE Montag, in US Sonntag) — deshalb wird der API-Index beim Aufbau der
/// Zeilen umgerechnet und nie direkt als Anzeigeposition verwendet.
struct VisitTimesRow: Identifiable, Sendable {
    /// Index in der API-Matrix (0 = Sonntag).
    let apiDayIndex: Int
    /// Lokalisierter, abgekürzter Wochentagsname („Mo“, „Mon“ …).
    let label: String
    /// 24 Werte, Stunde 0…23.
    let hours: [Int]

    var id: Int { apiDayIndex }
    var total: Int { hours.reduce(0, +) }
}

@MainActor
final class VisitTimesViewModel: ObservableObject {
    let websiteId: String

    @Published var weekly: UmamiWeeklyTraffic?
    @Published var sessionStats: UmamiSessionStats?
    @Published var isLoading = false
    @Published var isOffline = false
    @Published var error: String?

    private var loadingTask: Task<Void, Never>?
    private let api: UmamiAPI

    init(websiteId: String, api: UmamiAPI = .shared) {
        self.websiteId = websiteId
        self.api = api
    }

    // MARK: - Abgeleitete Werte

    var hasData: Bool {
        (weekly?.total ?? 0) > 0
    }

    /// Zeilen in der Reihenfolge des lokalen Kalenders (DE: Mo…So, US: So…Sa).
    var rows: [VisitTimesRow] {
        guard let weekly else { return [] }

        let calendar = Calendar.current
        // firstWeekday ist 1-basiert (1 = Sonntag), die API-Matrix 0-basiert.
        let offset = calendar.firstWeekday - 1
        let symbols = calendar.shortWeekdaySymbols // Index 0 = Sonntag

        return (0..<7).map { position in
            let apiIndex = (position + offset) % 7
            let hours = (0..<24).map { weekly.value(day: apiIndex, hour: $0) }
            return VisitTimesRow(
                apiDayIndex: apiIndex,
                label: symbols.indices.contains(apiIndex) ? symbols[apiIndex] : "",
                hours: hours
            )
        }
    }

    /// Höchster Zellwert — Referenz für die Farbintensität der Heatmap.
    var maxValue: Int {
        weekly?.days.flatMap { $0 }.max() ?? 0
    }

    var totalVisits: Int {
        weekly?.total ?? 0
    }

    /// Stärkste Stunde über alle Tage hinweg (für die Kennzahl „Beste Zeit“).
    var peak: (row: VisitTimesRow, hour: Int, value: Int)? {
        var best: (row: VisitTimesRow, hour: Int, value: Int)?
        for row in rows {
            for (hour, value) in row.hours.enumerated() where value > (best?.value ?? 0) {
                best = (row, hour, value)
            }
        }
        return best
    }

    /// Aufsummierte Besuche je Stunde über alle Wochentage.
    var hourTotals: [Int] {
        guard let weekly else { return Array(repeating: 0, count: 24) }
        return (0..<24).map { hour in
            (0..<7).reduce(0) { $0 + weekly.value(day: $1, hour: hour) }
        }
    }

    // MARK: - Laden

    func load(dateRange: DateRange) async {
        loadingTask?.cancel()
        let task = Task {
            isLoading = true
            isOffline = false
            error = nil
            defer { if !Task.isCancelled { isLoading = false } }

            do {
                async let weeklyResult = api.getWeeklyTraffic(websiteId: websiteId, dateRange: dateRange)
                async let statsResult = api.getSessionStats(websiteId: websiteId, dateRange: dateRange)

                let (loadedWeekly, loadedStats) = try await (weeklyResult, statsResult)
                guard !Task.isCancelled else { return }
                weekly = loadedWeekly
                sessionStats = loadedStats
            } catch {
                guard !Task.isCancelled else { return }
                Logger.ui.error("VisitTimes error: \(error.localizedDescription)")
                weekly = nil
                sessionStats = nil
                if error.isNetworkError {
                    self.isOffline = true
                } else {
                    self.error = error.localizedDescription
                }
            }
        }
        loadingTask = task
        await task.value
    }

    // MARK: - Helfer

    /// Lokalisierte Stundenbeschriftung (z. B. „14 Uhr“ / „2 PM“) — leitet das
    /// Format aus der Locale ab, damit 12-/24-Stunden-Regionen korrekt sind.
    static func hourLabel(_ hour: Int) -> String {
        let calendar = Calendar.current
        guard let date = calendar.date(from: DateComponents(
            year: 2000, month: 1, day: 1, hour: hour, minute: 0
        )) else { return "\(hour)" }

        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("j")
        return formatter.string(from: date)
    }
}
