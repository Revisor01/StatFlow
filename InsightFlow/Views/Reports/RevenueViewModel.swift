import Foundation
import SwiftUI
import os

/// Auswählbare Währungen für die Revenue-Endpunkte. Umami liefert die im
/// Tracking verwendete Währung nirgends aus, deshalb muss sie im UI gesetzt
/// und gemerkt werden. Der Server normalisiert auf Großschreibung.
enum RevenueCurrency: String, CaseIterable, Identifiable, Sendable {
    case eur = "EUR"
    case usd = "USD"
    case gbp = "GBP"
    case chf = "CHF"

    var id: String { rawValue }

    /// Kurzes Symbol für die Auswahl (z. B. „€“), aus der Locale abgeleitet.
    var symbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = rawValue
        return formatter.currencySymbol ?? rawValue
    }

    /// Formatiert einen Betrag in dieser Währung nach den Regeln der App-Locale.
    func format(_ amount: Double) -> String {
        amount.formatted(.currency(code: rawValue).precision(.fractionLength(0...2)))
    }
}

/// Ein Punkt des Umsatzverlaufs mit aufgelöstem Datum.
struct RevenueChartPoint: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let amount: Double
    let count: Double
}

@MainActor
final class RevenueViewModel: ObservableObject {
    let websiteId: String

    @Published var stats: UmamiRevenueStats?
    @Published var chart: [UmamiRevenueChartPoint] = []
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

    /// Umsatz-Tracking gilt als eingerichtet, sobald es irgendeinen Betrag oder
    /// eine gezählte Transaktion gibt. Andernfalls zeigt die View einen
    /// erklärenden Leerzustand statt einer Fehlermeldung.
    var hasData: Bool {
        guard let stats else { return false }
        if stats.sum != 0 || stats.count != 0 { return true }
        return chartPoints.contains { $0.amount != 0 || $0.count != 0 }
    }

    /// Verlauf: gleiche Zeitbuckets werden über alle Event-Namen (`x`) summiert.
    var chartPoints: [RevenueChartPoint] {
        var buckets: [Date: (amount: Double, count: Double)] = [:]
        for point in chart {
            guard let date = Self.parseDate(point.t) else { continue }
            var bucket = buckets[date] ?? (0, 0)
            bucket.amount += point.y
            bucket.count += point.count
            buckets[date] = bucket
        }
        return buckets
            .map { RevenueChartPoint(date: $0.key, amount: $0.value.amount, count: $0.value.count) }
            .sorted { $0.date < $1.date }
    }

    /// Umsatz nach Event-Name (`x`) — zeigt, welche Events Umsatz liefern.
    var revenueByEvent: [(name: String, amount: Double)] {
        var totals: [String: Double] = [:]
        for point in chart {
            let name = point.x ?? ""
            guard !name.isEmpty else { continue }
            totals[name, default: 0] += point.y
        }
        return totals
            .map { (name: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }

    /// Relative Veränderung gegenüber dem Vergleichszeitraum in Prozent.
    /// `nil`, wenn kein Vergleich vorliegt oder die Vorperiode 0 war.
    func change(for keyPath: KeyPath<UmamiRevenueStatsComparison, Double>,
                current: Double) -> Double? {
        guard let comparison = stats?.comparison else { return nil }
        let previous = comparison[keyPath: keyPath]
        guard previous != 0 else { return nil }
        return (current - previous) / abs(previous) * 100
    }

    // MARK: - Laden

    func load(dateRange: DateRange, currency: RevenueCurrency) async {
        loadingTask?.cancel()
        let task = Task {
            isLoading = true
            isOffline = false
            error = nil
            defer { if !Task.isCancelled { isLoading = false } }

            do {
                async let statsResult = api.getRevenueStats(
                    websiteId: websiteId,
                    dateRange: dateRange,
                    currency: currency.rawValue,
                    compare: .previous
                )
                async let chartResult = api.getRevenueChart(
                    websiteId: websiteId,
                    dateRange: dateRange,
                    currency: currency.rawValue
                )

                let (loadedStats, loadedChart) = try await (statsResult, chartResult)
                guard !Task.isCancelled else { return }
                stats = loadedStats
                chart = loadedChart
            } catch {
                guard !Task.isCancelled else { return }
                Logger.ui.error("Revenue error: \(error.localizedDescription)")
                stats = nil
                chart = []
                if error.isNetworkError {
                    self.isOffline = true
                } else if let apiError = error as? APIError, case .serverError(let code) = apiError,
                          code == 400 || code == 404 {
                    // Kein Revenue-Tracking konfiguriert ⇒ Leerzustand, kein Fehler.
                    self.error = nil
                } else {
                    self.error = error.localizedDescription
                }
            }
        }
        loadingTask = task
        await task.value
    }

    // MARK: - Helfer

    /// Umami liefert Zeitbuckets je nach Unit als ISO8601 oder als
    /// `yyyy-MM-dd HH:mm:ss` — beide Formate werden probiert.
    private static func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: value) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: value) { return date }

        let formats = ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd", "yyyy-MM"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }
}
