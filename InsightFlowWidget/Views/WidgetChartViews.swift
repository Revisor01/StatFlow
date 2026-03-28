//
//  WidgetChartViews.swift
//  InsightFlowWidget
//

import SwiftUI
import WidgetKit

// MARK: - Bar Chart View

struct BarChartView: View {
    let data: [Int]
    let color: Color
    let timeRange: String
    let showYScale: Bool
    let showXScale: Bool

    init(data: [Int], color: Color = .blue, timeRange: String = "", showYScale: Bool = false, showXScale: Bool = false) {
        self.data = data
        self.color = color
        self.timeRange = timeRange
        self.showYScale = showYScale
        self.showXScale = showXScale
    }

    private var xLabels: [String] {
        let count = data.count
        guard count >= 2 else { return [] }

        let todayLabel = String(localized: "widget.timerange.today")
        let yesterdayLabel = String(localized: "widget.timerange.yesterday")
        let last7DaysLabel = String(localized: "widget.timerange.last7days")
        let isHourly = timeRange == todayLabel || timeRange == yesterdayLabel
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        let today = Date()
        let calendar = Calendar.current

        if isHourly {
            let currentHour = calendar.component(.hour, from: today)
            if timeRange == todayLabel {
                let midHour = currentHour / 2
                return ["0h", "\(midHour)h", "\(currentHour)h"]
            } else {
                return ["0h", "12h", "24h"]
            }
        } else if timeRange == last7DaysLabel {
            var labels: [String] = []
            for i in [0, 3, 6] {
                if let date = calendar.date(byAdding: .day, value: -(6-i), to: today) {
                    formatter.dateFormat = "d. MMM"
                    labels.append(formatter.string(from: date))
                }
            }
            return labels
        } else {
            var labels: [String] = []
            for i in [0, 14, 29] {
                if let date = calendar.date(byAdding: .day, value: -(29-i), to: today) {
                    formatter.dateFormat = "d. MMM"
                    labels.append(formatter.string(from: date))
                }
            }
            return labels
        }
    }

    private var hasData: Bool {
        data.contains { $0 > 0 }
    }

    var body: some View {
        GeometryReader { geometry in
            let maxVal = max(data.max() ?? 1, 1)

            let yScaleWidth: CGFloat = showYScale ? 24 : 0
            let xScaleHeight: CGFloat = showXScale ? 12 : 0
            let graphWidth = geometry.size.width - yScaleWidth
            let graphHeight = geometry.size.height - xScaleHeight

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    // Y-Achse
                    if showYScale {
                        VStack {
                            Text("\(maxVal)")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("0")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: yScaleWidth, height: graphHeight)
                    }

                    // Bar Chart
                    if !data.isEmpty && hasData {
                        let barCount = CGFloat(data.count)
                        let totalSpacing = CGFloat(data.count - 1) * 1 // spacing: 1
                        let barWidth = max((graphWidth - totalSpacing) / barCount, 2)

                        HStack(alignment: .bottom, spacing: 1) {
                            ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                                let barHeight = graphHeight * CGFloat(value) / CGFloat(maxVal)
                                let isLast = index == data.count - 1

                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(
                                        LinearGradient(
                                            colors: [color, color.opacity(0.6)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: barWidth, height: max(barHeight, 2))
                                    .overlay(
                                        isLast ?
                                        RoundedRectangle(cornerRadius: 1.5)
                                            .stroke(color, lineWidth: 1)
                                        : nil
                                    )
                            }
                        }
                        .frame(width: graphWidth, height: graphHeight, alignment: .bottom)
                    } else {
                        // Keine Daten: zeige Baseline
                        VStack {
                            Spacer()
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                        }
                        .frame(width: graphWidth, height: graphHeight)
                    }
                }

                // X-Achse
                if showXScale {
                    HStack {
                        if showYScale {
                            Spacer().frame(width: yScaleWidth)
                        }
                        HStack {
                            ForEach(Array(xLabels.enumerated()), id: \.offset) { _, label in
                                if label != xLabels.first {
                                    Spacer()
                                }
                                Text(label)
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: graphWidth)
                    }
                    .frame(height: xScaleHeight)
                }
            }
        }
    }
}

// MARK: - Line Chart View

struct LineChartView: View {
    let data: [Int]
    let color: Color
    let timeRange: String
    let showYScale: Bool
    let showXScale: Bool

    init(data: [Int], color: Color = .blue, timeRange: String = "", showYScale: Bool = false, showXScale: Bool = false) {
        self.data = data
        self.color = color
        self.timeRange = timeRange
        self.showYScale = showYScale
        self.showXScale = showXScale
    }

    private var xLabels: [String] {
        let count = data.count
        guard count >= 2 else { return [] }

        let todayLabel = String(localized: "widget.timerange.today")
        let yesterdayLabel = String(localized: "widget.timerange.yesterday")
        let last7DaysLabel = String(localized: "widget.timerange.last7days")
        let isHourly = timeRange == todayLabel || timeRange == yesterdayLabel
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        let today = Date()
        let calendar = Calendar.current

        if isHourly {
            let currentHour = calendar.component(.hour, from: today)
            if timeRange == todayLabel {
                let midHour = currentHour / 2
                return ["0h", "\(midHour)h", "\(currentHour)h"]
            } else {
                return ["0h", "12h", "24h"]
            }
        } else if timeRange == last7DaysLabel {
            var labels: [String] = []
            for i in [0, 3, 6] {
                if let date = calendar.date(byAdding: .day, value: -(6-i), to: today) {
                    formatter.dateFormat = "d. MMM"
                    labels.append(formatter.string(from: date))
                }
            }
            return labels
        } else {
            var labels: [String] = []
            for i in [0, 14, 29] {
                if let date = calendar.date(byAdding: .day, value: -(29-i), to: today) {
                    formatter.dateFormat = "d. MMM"
                    labels.append(formatter.string(from: date))
                }
            }
            return labels
        }
    }

    private var hasData: Bool {
        data.contains { $0 > 0 }
    }

    var body: some View {
        GeometryReader { geometry in
            let maxVal = max(data.max() ?? 1, 1)

            let yScaleWidth: CGFloat = showYScale ? 24 : 0
            let xScaleHeight: CGFloat = showXScale ? 12 : 0
            let graphWidth = geometry.size.width - yScaleWidth
            let graphHeight = geometry.size.height - xScaleHeight

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    // Y-Achse
                    if showYScale {
                        VStack {
                            Text("\(maxVal)")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("0")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: yScaleWidth, height: graphHeight)
                    }

                    // Line Chart
                    if !data.isEmpty && hasData {
                        let points = data.enumerated().map { index, value -> CGPoint in
                            let x = graphWidth * CGFloat(index) / CGFloat(max(data.count - 1, 1))
                            let y = graphHeight - (graphHeight * CGFloat(value) / CGFloat(maxVal))
                            return CGPoint(x: x, y: y)
                        }

                        ZStack {
                            // Fill area under curved line
                            Path { path in
                                guard points.count > 1 else { return }
                                path.move(to: CGPoint(x: points[0].x, y: graphHeight))
                                path.addLine(to: points[0])

                                for i in 1..<points.count {
                                    let p0 = points[i - 1]
                                    let p1 = points[i]
                                    let midX = (p0.x + p1.x) / 2

                                    path.addCurve(
                                        to: p1,
                                        control1: CGPoint(x: midX, y: p0.y),
                                        control2: CGPoint(x: midX, y: p1.y)
                                    )
                                }

                                path.addLine(to: CGPoint(x: points.last!.x, y: graphHeight))
                                path.closeSubpath()
                            }
                            .fill(
                                LinearGradient(
                                    colors: [color.opacity(0.3), color.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                            // Curved Line
                            Path { path in
                                guard points.count > 1 else { return }
                                path.move(to: points[0])

                                for i in 1..<points.count {
                                    let p0 = points[i - 1]
                                    let p1 = points[i]
                                    let midX = (p0.x + p1.x) / 2

                                    path.addCurve(
                                        to: p1,
                                        control1: CGPoint(x: midX, y: p0.y),
                                        control2: CGPoint(x: midX, y: p1.y)
                                    )
                                }
                            }
                            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                            // End dot
                            if let lastPoint = points.last {
                                Circle()
                                    .fill(color)
                                    .frame(width: 6, height: 6)
                                    .position(lastPoint)
                            }
                        }
                        .frame(width: graphWidth, height: graphHeight)
                    } else {
                        // Keine Daten: zeige Baseline
                        VStack {
                            Spacer()
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                        }
                        .frame(width: graphWidth, height: graphHeight)
                    }
                }

                // X-Achse
                if showXScale {
                    HStack {
                        if showYScale {
                            Spacer().frame(width: yScaleWidth)
                        }
                        HStack {
                            ForEach(Array(xLabels.enumerated()), id: \.offset) { _, label in
                                if label != xLabels.first {
                                    Spacer()
                                }
                                Text(label)
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: graphWidth)
                    }
                    .frame(height: xScaleHeight)
                }
            }
        }
    }
}
