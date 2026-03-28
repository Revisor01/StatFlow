//
//  WidgetSizeViews.swift
//  InsightFlowWidget
//

import SwiftUI
import WidgetKit

// MARK: - Widget Views

struct PrivacyFlowWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(data: entry.data)
            case .systemMedium:
                MediumWidgetView(data: entry.data, chartStyle: entry.configuration.chartStyle)
            default:
                SmallWidgetView(data: entry.data)
            }
        }
        .widgetURL(entry.data.deepLinkURL)
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let data: WidgetData

    private func formatNumber(_ value: Int) -> String {
        if value >= 1000000 {
            return String(format: "%.1fM", Double(value) / 1000000)
        } else if value >= 10000 {
            return String(format: "%.0fk", Double(value) / 1000)
        } else if value >= 1000 {
            return String(format: "%.1fk", Double(value) / 1000)
        }
        return "\(value)"
    }

    private func formatPercentage(_ value: Int) -> String {
        if value > 0 { return "+\(value)%" }
        if value < 0 { return "\(value)%" }
        return "0%"
    }

    private func changeColor(_ value: Int) -> Color {
        if value > 0 { return .green }
        if value < 0 { return .red }
        return .secondary
    }

    var body: some View {
        if let error = data.errorMessage {
            VStack(spacing: 6) {
                Image(systemName: data.isConfigured ? "hand.tap" : "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 4) {
                    if data.activeVisitors > 0 {
                        Circle().fill(.green).frame(width: 6, height: 6)
                    }
                    Text(data.websiteName)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Spacer()
                    Text(data.timeRange)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Besucher:innen
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.purple)
                    Text(formatNumber(data.visitors))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(formatPercentage(data.visitorsChange))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(changeColor(data.visitorsChange))
                }

                Text(String(localized: "widget.stats.visitors"))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 15)

                Spacer()

                // Pageviews
                HStack(spacing: 4) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.blue)
                    Text(formatNumber(data.pageviews))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(formatPercentage(data.pageviewsChange))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(changeColor(data.pageviewsChange))
                }

                Text(String(localized: "widget.stats.pageviews"))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 15)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(10)
        }
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let data: WidgetData
    let chartStyle: WidgetChartStyle

    private func formatPercentage(_ value: Int) -> String {
        if value > 0 { return "+\(value)%" }
        if value < 0 { return "\(value)%" }
        return "0%"
    }

    private func changeColor(_ value: Int) -> Color {
        if value > 0 { return .green }
        if value < 0 { return .red }
        return .secondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let error = data.errorMessage {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: data.isConfigured ? "hand.tap" : "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                // Header
                HStack(spacing: 5) {
                    Text(data.websiteName)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if data.activeVisitors > 0 {
                        Circle().fill(.green).frame(width: 6, height: 6)
                        Text("\(data.activeVisitors)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.green)
                    }
                    Spacer()
                    Text(data.timeRange)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                // Stats mit Icons und Prozenten
                HStack(spacing: 16) {
                    // Visitors
                    HStack(spacing: 5) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.purple)
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text("\(data.visitors)")
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                Text(formatPercentage(data.visitorsChange))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(changeColor(data.visitorsChange))
                            }
                            Text(String(localized: "widget.stats.visitors"))
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Pageviews
                    HStack(spacing: 5) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text("\(data.pageviews)")
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                Text(formatPercentage(data.pageviewsChange))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(changeColor(data.pageviewsChange))
                            }
                            Text(String(localized: "widget.stats.pageviews"))
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding(.top, 4)

                Spacer(minLength: 2)

                // Graph mit Skala - Bar oder Line je nach Einstellung
                Group {
                    if chartStyle == .line {
                        LineChartView(data: data.sparklineData, color: .blue, timeRange: data.timeRange, showYScale: true, showXScale: true)
                    } else {
                        BarChartView(data: data.sparklineData, color: .blue, timeRange: data.timeRange, showYScale: true, showXScale: true)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 60)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(6)
    }
}
