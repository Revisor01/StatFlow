import Foundation
import SwiftUI

// MARK: - Dashboard Chart Style

enum DashboardChartStyle: String, CaseIterable {
    case line
    case bar

    var icon: String {
        switch self {
        case .line: return "chart.xyaxis.line"
        case .bar: return "chart.bar.fill"
        }
    }

    var localizedName: String {
        switch self {
        case .line: return String(localized: "chart.style.line")
        case .bar: return String(localized: "chart.style.bar")
        }
    }
}

// MARK: - Dashboard Metric

enum DashboardMetric: String, CaseIterable, Identifiable {
    case visitors = "visitors"
    case pageviews = "pageviews"
    case visits = "visits"
    case bounceRate = "bounceRate"
    case duration = "duration"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .visitors: return String(localized: "dashboard.settings.metrics.visitors")
        case .pageviews: return String(localized: "dashboard.settings.metrics.pageviews")
        case .visits: return String(localized: "dashboard.settings.metrics.visits")
        case .bounceRate: return String(localized: "dashboard.settings.metrics.bounceRate")
        case .duration: return String(localized: "dashboard.settings.metrics.duration")
        }
    }

    var icon: String {
        switch self {
        case .visitors: return "person.fill"
        case .pageviews: return "eye.fill"
        case .visits: return "arrow.triangle.swap"
        case .bounceRate: return "arrow.uturn.left"
        case .duration: return "clock.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .visitors: return .purple
        case .pageviews: return .blue
        case .visits: return .orange
        case .bounceRate: return .red
        case .duration: return .teal
        }
    }
}

// MARK: - Dashboard Settings Manager

@MainActor
class DashboardSettingsManager: ObservableObject {
    static let shared = DashboardSettingsManager()

    private let enabledMetricsKey = "dashboard_enabled_metrics"
    private let showGraphKey = "dashboard_show_graph"
    private let chartStyleKey = "dashboard_chart_style"
    private let showDateRangePickerKey = "dashboard_show_date_range_picker"

    @Published var enabledMetrics: Set<DashboardMetric> {
        didSet {
            saveSettings()
        }
    }

    @Published var showGraph: Bool {
        didSet {
            UserDefaults.standard.set(showGraph, forKey: showGraphKey)
        }
    }

    @Published var chartStyle: DashboardChartStyle {
        didSet {
            UserDefaults.standard.set(chartStyle.rawValue, forKey: chartStyleKey)
        }
    }

    @Published var showDateRangePicker: Bool {
        didSet {
            UserDefaults.standard.set(showDateRangePicker, forKey: showDateRangePickerKey)
        }
    }

    private init() {
        // Default: graph enabled
        showGraph = UserDefaults.standard.object(forKey: showGraphKey) as? Bool ?? true

        // Default: date range picker enabled
        showDateRangePicker = UserDefaults.standard.object(forKey: showDateRangePickerKey) as? Bool ?? true

        // Default chart style: bar
        if let savedStyle = UserDefaults.standard.string(forKey: chartStyleKey),
           let style = DashboardChartStyle(rawValue: savedStyle) {
            chartStyle = style
        } else {
            chartStyle = .bar
        }

        // Default: visitors, pageviews, visits enabled
        if let savedStrings = UserDefaults.standard.stringArray(forKey: enabledMetricsKey) {
            enabledMetrics = Set(savedStrings.compactMap { DashboardMetric(rawValue: $0) })
            // Ensure at least one metric is enabled
            if enabledMetrics.isEmpty {
                enabledMetrics = [.visitors, .pageviews, .visits]
            }
        } else {
            // Default: only visitors, pageviews, visits (not bounce rate or duration)
            enabledMetrics = [.visitors, .pageviews, .visits]
        }
    }

    func toggleChartStyle() {
        chartStyle = chartStyle == .line ? .bar : .line
    }

    func isEnabled(_ metric: DashboardMetric) -> Bool {
        enabledMetrics.contains(metric)
    }

    func toggle(_ metric: DashboardMetric) {
        // Prevent disabling if it's the last enabled metric
        if enabledMetrics.contains(metric) && enabledMetrics.count > 1 {
            enabledMetrics.remove(metric)
        } else if !enabledMetrics.contains(metric) {
            enabledMetrics.insert(metric)
        }
    }

    func setEnabled(_ metric: DashboardMetric, enabled: Bool) {
        if enabled {
            enabledMetrics.insert(metric)
        } else if enabledMetrics.count > 1 {
            enabledMetrics.remove(metric)
        }
    }

    private func saveSettings() {
        let strings = enabledMetrics.map { $0.rawValue }
        UserDefaults.standard.set(Array(strings), forKey: enabledMetricsKey)
    }
}
