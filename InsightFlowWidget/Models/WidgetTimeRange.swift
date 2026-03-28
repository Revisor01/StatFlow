//
//  WidgetTimeRange.swift
//  InsightFlowWidget
//

import SwiftUI
import AppIntents

// MARK: - Time Range Enum

enum WidgetTimeRange: String, CaseIterable, AppEnum {
    case today
    case yesterday
    case last7Days
    case last30Days

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "widget.timerange.type"
    static var caseDisplayRepresentations: [WidgetTimeRange: DisplayRepresentation] = [
        .today: "widget.timerange.today",
        .yesterday: "widget.timerange.yesterday",
        .last7Days: "widget.timerange.last7days",
        .last30Days: "widget.timerange.last30days"
    ]

    var localizedName: String {
        switch self {
        case .today: return String(localized: "widget.timerange.today")
        case .yesterday: return String(localized: "widget.timerange.yesterday")
        case .last7Days: return String(localized: "widget.timerange.last7days")
        case .last30Days: return String(localized: "widget.timerange.last30days")
        }
    }

    var days: Int {
        switch self {
        case .today: return 0
        case .yesterday: return 1
        case .last7Days: return 6
        case .last30Days: return 29
        }
    }

    var unit: String {
        switch self {
        case .today, .yesterday: return "hour"
        default: return "day"
        }
    }
}

// MARK: - Chart Style Enum

enum WidgetChartStyle: String, CaseIterable, AppEnum {
    case bars
    case line

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Chart Style"
    static var caseDisplayRepresentations: [WidgetChartStyle: DisplayRepresentation] = [
        .bars: "Bars",
        .line: "Line"
    ]
}
