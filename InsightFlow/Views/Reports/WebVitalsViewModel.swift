import Foundation
import SwiftUI
import os

/// Bewertung eines Web-Vital-Werts nach den offiziellen Core-Web-Vitals-Schwellwerten.
enum WebVitalRating {
    case good
    case needsImprovement
    case poor

    var color: Color {
        switch self {
        case .good: return .green
        case .needsImprovement: return .orange
        case .poor: return .red
        }
    }

    var localizedName: String {
        switch self {
        case .good: return String(localized: "webvitals.rating.good")
        case .needsImprovement: return String(localized: "webvitals.rating.needsImprovement")
        case .poor: return String(localized: "webvitals.rating.poor")
        }
    }

    var symbolName: String {
        switch self {
        case .good: return "checkmark.circle.fill"
        case .needsImprovement: return "exclamationmark.triangle.fill"
        case .poor: return "xmark.octagon.fill"
        }
    }
}

/// Offizielle Core-Web-Vitals-Schwellwerte je Kennzahl.
/// LCP/INP/FCP/TTFB in Millisekunden, CLS einheitenlos.
extension UmamiWebVitalMetric {
    /// Obergrenze für „gut“ (Wert ≤ goodThreshold).
    var goodThreshold: Double {
        switch self {
        case .lcp: return 2500
        case .inp: return 200
        case .cls: return 0.1
        case .fcp: return 1800
        case .ttfb: return 800
        }
    }

    /// Obergrenze für „verbesserungswürdig“ (Wert > poorThreshold ⇒ schlecht).
    var poorThreshold: Double {
        switch self {
        case .lcp: return 4000
        case .inp: return 500
        case .cls: return 0.25
        case .fcp: return 3000
        case .ttfb: return 1800
        }
    }

    /// CLS ist eine einheitenlose Verschiebungs-Kennzahl, alle anderen sind Zeiten.
    var isDuration: Bool {
        self != .cls
    }

    var localizedName: String {
        switch self {
        case .lcp: return String(localized: "webvitals.metric.lcp")
        case .inp: return String(localized: "webvitals.metric.inp")
        case .cls: return String(localized: "webvitals.metric.cls")
        case .fcp: return String(localized: "webvitals.metric.fcp")
        case .ttfb: return String(localized: "webvitals.metric.ttfb")
        }
    }

    var shortName: String {
        rawValue.uppercased()
    }

    var localizedDescription: String {
        switch self {
        case .lcp: return String(localized: "webvitals.metric.lcp.description")
        case .inp: return String(localized: "webvitals.metric.inp.description")
        case .cls: return String(localized: "webvitals.metric.cls.description")
        case .fcp: return String(localized: "webvitals.metric.fcp.description")
        case .ttfb: return String(localized: "webvitals.metric.ttfb.description")
        }
    }

    func rating(for value: Double) -> WebVitalRating {
        if value <= goodThreshold { return .good }
        if value > poorThreshold { return .poor }
        return .needsImprovement
    }

    /// Formatiert einen Rohwert passend zur Kennzahl:
    /// Zeiten als „340 ms“ bzw. „1,2 s“, CLS mit drei Nachkommastellen ohne Einheit.
    func formattedValue(_ value: Double) -> String {
        guard isDuration else {
            return value.formatted(
                .number.precision(.fractionLength(3)).grouping(.never)
            )
        }

        if value < 1000 {
            let rounded = value.rounded()
            return String(
                localized: "webvitals.unit.milliseconds \(rounded.formatted(.number.precision(.fractionLength(0))))"
            )
        }

        let seconds = value / 1000
        let fractionDigits = seconds < 10 ? 2 : 1
        return String(
            localized: "webvitals.unit.seconds \(seconds.formatted(.number.precision(.fractionLength(fractionDigits))))"
        )
    }

    /// Kurzform für Achsenbeschriftungen — ohne Einheit im Label selbst.
    func axisLabel(_ value: Double) -> String {
        guard isDuration else {
            return value.formatted(.number.precision(.fractionLength(2)).grouping(.never))
        }
        if value < 1000 {
            return value.formatted(.number.precision(.fractionLength(0)))
        }
        return (value / 1000).formatted(.number.precision(.fractionLength(1))) + " s"
    }

    var axisUnitLabel: String {
        isDuration ? String(localized: "webvitals.axis.time") : String(localized: "webvitals.axis.score")
    }
}

/// Ein Punkt der Zeitreihe, aufbereitet für Swift Charts.
struct WebVitalsChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let p50: Double
    let p75: Double
    let p95: Double
}

@MainActor
final class WebVitalsViewModel: ObservableObject {
    let websiteId: String

    @Published var report: UmamiPerformanceReport?
    @Published var selectedMetric: UmamiWebVitalMetric = .lcp
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

    var percentiles: UmamiPercentiles? {
        report?.summary.percentiles(for: selectedMetric)
    }

    /// Bewertet wird nach Konvention das 75. Perzentil.
    var rating: WebVitalRating? {
        guard let percentiles else { return nil }
        return selectedMetric.rating(for: percentiles.p75)
    }

    var sampleCount: Int {
        Int(report?.summary.count ?? 0)
    }

    var hasData: Bool {
        guard let report else { return false }
        if report.summary.count > 0 { return true }
        return !chartPoints.isEmpty
    }

    var chartPoints: [WebVitalsChartPoint] {
        guard let report else { return [] }
        return report.chart.compactMap { point in
            guard let date = Self.parseDate(point.t) else { return nil }
            return WebVitalsChartPoint(date: date, p50: point.p50, p75: point.p75, p95: point.p95)
        }
        .sorted { $0.date < $1.date }
    }

    /// Obergrenze der Y-Achse: mindestens bis zur „schlecht“-Schwelle, damit die
    /// eingezeichneten Schwellwert-Linien immer sichtbar bleiben.
    var chartUpperBound: Double {
        let dataMax = chartPoints.map(\.p95).max() ?? 0
        let threshold = selectedMetric.poorThreshold
        return max(dataMax * 1.15, threshold * 1.25)
    }

    /// Aufschlüsselung nach Seiten für die gewählte Kennzahl (Top 8, nach p75 absteigend).
    var topPages: [UmamiPerformanceMetric] {
        guard let report else { return [] }
        return report.pages
            .filter { !($0.name ?? "").isEmpty }
            .sorted { $0.p75 > $1.p75 }
            .prefix(8)
            .map { $0 }
    }

    // MARK: - Laden

    func load(dateRange: DateRange) async {
        loadingTask?.cancel()
        let metric = selectedMetric
        let task = Task {
            isLoading = true
            isOffline = false
            error = nil
            defer { if !Task.isCancelled { isLoading = false } }

            do {
                let result = try await api.getPerformanceReport(
                    websiteId: websiteId,
                    dateRange: dateRange,
                    metric: metric
                )
                guard !Task.isCancelled else { return }
                report = result
            } catch {
                guard !Task.isCancelled else { return }
                Logger.ui.error("WebVitals error: \(error.localizedDescription)")
                report = nil
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

    private static func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: value) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: value) { return date }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd", "yyyy-MM"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }
}
