import SwiftUI
import Charts

struct CompareChartSection: View {
    @ObservedObject var viewModel: CompareViewModel
    let compareType: CompareType
    let selectedMetric: CompareMetric
    @Binding var chartStyle: ChartStyle
    @Binding var selectedPointIndex: Int?
    @Binding var selectedPeriod: String?
    let periodAWeek: Int
    let periodAMonth: Int
    let periodAYear: Int
    let periodBWeek: Int
    let periodBMonth: Int
    let periodBYear: Int

    // MARK: - Computed helpers

    private var periodAColor: Color {
        selectedMetric == .pageviews ? .blue : .purple
    }

    private var expectedDataPoints: Int {
        switch compareType {
        case .week: return 7
        case .month: return 31
        case .year: return 12
        }
    }

    var currentData1: [TimeSeriesPoint] {
        let rawData: [TimeSeriesPoint]
        switch selectedMetric {
        case .pageviews: rawData = viewModel.pageviews1
        case .visitors: rawData = viewModel.visitors1
        }
        return padDataToExpectedCount(rawData)
    }

    var currentData2: [TimeSeriesPoint] {
        let rawData: [TimeSeriesPoint]
        switch selectedMetric {
        case .pageviews: rawData = viewModel.pageviews2
        case .visitors: rawData = viewModel.visitors2
        }
        return padDataToExpectedCountB(rawData)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            comparisonChartHeader
            comparisonChartLegend
            comparisonChartContent
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Header

    private var comparisonChartHeader: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: selectedMetric.icon)
                    .foregroundStyle(periodAColor)
                Text(String(localized: String.LocalizationValue(selectedMetric.rawValue)) + " " + String(localized: "compare.inComparison"))
                    .font(.headline)
            }

            Spacer()

            if let index = selectedPointIndex {
                let value1 = index < currentData1.count ? currentData1[index].value : 0
                let value2 = index < currentData2.count ? currentData2[index].value : 0

                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("\(value1)").foregroundStyle(periodAColor)
                        Text("/")
                        Text("\(value2)").foregroundStyle(.orange)
                    }
                    .font(.headline)
                    Text(xAxisLabel(for: index))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                withAnimation(.spring(duration: 0.3)) {
                    chartStyle = chartStyle == .line ? .bar : .line
                }
            } label: {
                Image(systemName: chartStyle.icon)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Legend

    private var comparisonChartLegend: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(periodAColor)
                    .frame(width: 16, height: 3)
                Text(periodLabel(week: periodAWeek, month: periodAMonth, year: periodAYear))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.orange)
                    .frame(width: 16, height: 3)
                Text(periodLabel(week: periodBWeek, month: periodBMonth, year: periodBYear))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Chart Content

    @ViewBuilder
    private var comparisonChartContent: some View {
        if !currentData1.isEmpty || !currentData2.isEmpty {
            let useBarChart = compareType == .year || chartStyle == .bar
            if useBarChart {
                comparisonBarChart
            } else {
                comparisonLineChart
            }
        }
    }

    // MARK: - Line Chart

    private var comparisonLineChart: some View {
        let maxCount = max(currentData1.count, currentData2.count)
        let chartColor = periodAColor

        return Chart {
            ForEach(Array(currentData1.enumerated()), id: \.offset) { index, point in
                LineMark(
                    x: .value("X", index),
                    y: .value(selectedMetric.rawValue, point.value),
                    series: .value("Periode", "A")
                )
                .foregroundStyle(chartColor)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.monotone)
            }

            ForEach(Array(currentData1.enumerated()), id: \.offset) { index, point in
                AreaMark(
                    x: .value("X", index),
                    y: .value(selectedMetric.rawValue, point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [chartColor.opacity(0.2), chartColor.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)
            }

            ForEach(Array(currentData2.enumerated()), id: \.offset) { index, point in
                LineMark(
                    x: .value("X", index),
                    y: .value(selectedMetric.rawValue, point.value),
                    series: .value("Periode", "B")
                )
                .foregroundStyle(.orange)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                .interpolationMethod(.monotone)
            }

            ForEach(Array(currentData1.enumerated()), id: \.offset) { index, point in
                PointMark(
                    x: .value("X", index),
                    y: .value(selectedMetric.rawValue, point.value)
                )
                .foregroundStyle(chartColor)
                .symbolSize(selectedPointIndex == index ? 60 : (maxCount <= 12 ? 30 : 20))
            }

            ForEach(Array(currentData2.enumerated()), id: \.offset) { index, point in
                PointMark(
                    x: .value("X", index),
                    y: .value(selectedMetric.rawValue, point.value)
                )
                .foregroundStyle(.orange)
                .symbolSize(selectedPointIndex == index ? 60 : (maxCount <= 12 ? 30 : 20))
            }

            if let idx = selectedPointIndex {
                RuleMark(x: .value("X", idx))
                    .foregroundStyle(.gray.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: 1)) { value in
                if let index = value.as(Int.self), shouldShowXAxisLabel(for: index, totalCount: maxCount) {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                        .foregroundStyle(.gray.opacity(0.3))
                    AxisValueLabel {
                        Text(xAxisLabel(for: index))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                    .foregroundStyle(.gray.opacity(0.3))
                AxisValueLabel()
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                updateCompareSelectedPoint(at: value.location, geometry: geometry, proxy: proxy)
                            }
                    )
                    .onTapGesture { location in
                        handleCompareChartTap(location: location, geometry: geometry, proxy: proxy)
                    }
            }
        }
        .chartLegend(.hidden)
        .chartYScale(domain: .automatic(includesZero: true))
        .frame(height: 220)
    }

    // MARK: - Bar Chart

    private var comparisonBarChart: some View {
        let chartColor = periodAColor
        let maxCount = max(currentData1.count, currentData2.count)

        return Chart {
            ForEach(Array(currentData1.enumerated()), id: \.offset) { index, point in
                BarMark(
                    x: .value("X", xAxisLabel(for: index)),
                    y: .value(selectedMetric.rawValue, point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [chartColor, chartColor.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(3)
                .position(by: .value("Periode", "A"))
                .annotation(position: .top) {
                    if selectedPointIndex == index && selectedPeriod == "A" {
                        Text("\(point.value)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(chartColor)
                    }
                }
            }

            ForEach(Array(currentData2.enumerated()), id: \.offset) { index, point in
                BarMark(
                    x: .value("X", xAxisLabel(for: index)),
                    y: .value(selectedMetric.rawValue, point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .orange.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(3)
                .position(by: .value("Periode", "B"))
                .annotation(position: .top) {
                    if selectedPointIndex == index && selectedPeriod == "B" {
                        Text("\(point.value)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                if let label = value.as(String.self) {
                    let shouldShow = compareType != .month ||
                        label == "1." || label == "15." || label == "\(maxCount)."
                    if shouldShow {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                            .foregroundStyle(.gray.opacity(0.3))
                        AxisValueLabel {
                            Text(label)
                                .font(.caption2)
                        }
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                    .foregroundStyle(.gray.opacity(0.3))
                AxisValueLabel()
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                updateCompareBarSelectedPoint(at: value.location, geometry: geometry, proxy: proxy)
                            }
                    )
                    .onTapGesture { location in
                        handleCompareBarTap(location: location, geometry: geometry, proxy: proxy)
                    }
            }
        }
        .chartLegend(.hidden)
        .frame(height: 220)
    }

    // MARK: - Interaction Helpers

    private func updateCompareSelectedPoint(at location: CGPoint, geometry: GeometryProxy, proxy: ChartProxy) {
        let x = location.x - geometry[proxy.plotFrame!].origin.x
        if let index: Int = proxy.value(atX: x) {
            let maxCount = max(currentData1.count, currentData2.count)
            let clampedIndex = max(0, min(index, maxCount - 1))
            withAnimation(.easeOut(duration: 0.1)) {
                selectedPointIndex = clampedIndex
            }
        }
    }

    private func updateCompareBarSelectedPoint(at location: CGPoint, geometry: GeometryProxy, proxy: ChartProxy) {
        let x = location.x - geometry[proxy.plotFrame!].origin.x
        let plotWidth = geometry[proxy.plotFrame!].width
        let maxCount = max(currentData1.count, currentData2.count)

        let index = Int((x / plotWidth) * CGFloat(maxCount))
        let clampedIndex = max(0, min(index, maxCount - 1))

        let barWidth = plotWidth / CGFloat(maxCount)
        let posInBar = x.truncatingRemainder(dividingBy: barWidth)
        let period = posInBar < barWidth / 2 ? "A" : "B"

        withAnimation(.easeOut(duration: 0.1)) {
            selectedPointIndex = clampedIndex
            selectedPeriod = period
        }
    }

    private func handleCompareChartTap(location: CGPoint, geometry: GeometryProxy, proxy: ChartProxy) {
        let x = location.x - geometry[proxy.plotFrame!].origin.x
        if let index: Int = proxy.value(atX: x) {
            withAnimation(.easeOut(duration: 0.15)) {
                if selectedPointIndex == index {
                    selectedPointIndex = nil
                } else {
                    selectedPointIndex = index
                }
            }
        }
    }

    private func handleCompareBarTap(location: CGPoint, geometry: GeometryProxy, proxy: ChartProxy) {
        let x = location.x - geometry[proxy.plotFrame!].origin.x
        let plotWidth = geometry[proxy.plotFrame!].width
        let maxCount = max(currentData1.count, currentData2.count)

        let index = Int((x / plotWidth) * CGFloat(maxCount))
        let clampedIndex = max(0, min(index, maxCount - 1))

        let barWidth = plotWidth / CGFloat(maxCount)
        let posInBar = x.truncatingRemainder(dividingBy: barWidth)
        let period = posInBar < barWidth / 2 ? "A" : "B"

        withAnimation(.easeOut(duration: 0.15)) {
            if selectedPointIndex == clampedIndex && selectedPeriod == period {
                selectedPointIndex = nil
                selectedPeriod = nil
            } else {
                selectedPointIndex = clampedIndex
                selectedPeriod = period
            }
        }
    }

    // MARK: - Data Padding

    private func padDataToExpectedCount(_ data: [TimeSeriesPoint]) -> [TimeSeriesPoint] {
        let calendar = Calendar.current

        var result: [TimeSeriesPoint] = []

        switch compareType {
        case .week:
            var components = DateComponents()
            components.weekOfYear = periodAWeek
            components.yearForWeekOfYear = periodAYear
            components.weekday = 2
            let weekStart = calendar.date(from: components) ?? Date()

            for dayIndex in 0..<7 {
                let targetDate = calendar.date(byAdding: .day, value: dayIndex, to: weekStart)!
                let matchingPoint = data.first { point in
                    let pointDay = calendar.component(.weekday, from: point.date)
                    let normalizedDay = pointDay == 1 ? 6 : pointDay - 2
                    return normalizedDay == dayIndex
                }
                let dateString = DateFormatters.iso8601WithFractional.string(from: targetDate)
                result.append(TimeSeriesPoint(x: dateString, y: matchingPoint?.value ?? 0))
            }

        case .month:
            var startComponents = DateComponents()
            startComponents.year = periodAYear
            startComponents.month = periodAMonth
            startComponents.day = 1
            let monthStart = calendar.date(from: startComponents) ?? Date()
            let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 31

            for dayIndex in 0..<daysInMonth {
                let targetDate = calendar.date(byAdding: .day, value: dayIndex, to: monthStart)!
                let targetDay = dayIndex + 1
                let matchingPoint = data.first { point in
                    calendar.component(.day, from: point.date) == targetDay
                }
                let dateString = DateFormatters.iso8601WithFractional.string(from: targetDate)
                result.append(TimeSeriesPoint(x: dateString, y: matchingPoint?.value ?? 0))
            }

        case .year:
            for monthIndex in 0..<12 {
                var targetComponents = DateComponents()
                targetComponents.year = periodAYear
                targetComponents.month = monthIndex + 1
                targetComponents.day = 1
                let targetDate = calendar.date(from: targetComponents) ?? Date()

                let matchingPoint = data.first { point in
                    calendar.component(.month, from: point.date) == monthIndex + 1
                }
                let dateString = DateFormatters.iso8601WithFractional.string(from: targetDate)
                result.append(TimeSeriesPoint(x: dateString, y: matchingPoint?.value ?? 0))
            }
        }

        return result
    }

    private func padDataToExpectedCountB(_ data: [TimeSeriesPoint]) -> [TimeSeriesPoint] {
        let calendar = Calendar.current

        var result: [TimeSeriesPoint] = []

        switch compareType {
        case .week:
            var components = DateComponents()
            components.weekOfYear = periodBWeek
            components.yearForWeekOfYear = periodBYear
            components.weekday = 2
            let weekStart = calendar.date(from: components) ?? Date()

            for dayIndex in 0..<7 {
                let targetDate = calendar.date(byAdding: .day, value: dayIndex, to: weekStart)!
                let matchingPoint = data.first { point in
                    let pointDay = calendar.component(.weekday, from: point.date)
                    let normalizedDay = pointDay == 1 ? 6 : pointDay - 2
                    return normalizedDay == dayIndex
                }
                let dateString = DateFormatters.iso8601WithFractional.string(from: targetDate)
                result.append(TimeSeriesPoint(x: dateString, y: matchingPoint?.value ?? 0))
            }

        case .month:
            var startComponents = DateComponents()
            startComponents.year = periodBYear
            startComponents.month = periodBMonth
            startComponents.day = 1
            let monthStart = calendar.date(from: startComponents) ?? Date()
            let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 31

            for dayIndex in 0..<daysInMonth {
                let targetDate = calendar.date(byAdding: .day, value: dayIndex, to: monthStart)!
                let targetDay = dayIndex + 1
                let matchingPoint = data.first { point in
                    calendar.component(.day, from: point.date) == targetDay
                }
                let dateString = DateFormatters.iso8601WithFractional.string(from: targetDate)
                result.append(TimeSeriesPoint(x: dateString, y: matchingPoint?.value ?? 0))
            }

        case .year:
            for monthIndex in 0..<12 {
                var targetComponents = DateComponents()
                targetComponents.year = periodBYear
                targetComponents.month = monthIndex + 1
                targetComponents.day = 1
                let targetDate = calendar.date(from: targetComponents) ?? Date()

                let matchingPoint = data.first { point in
                    calendar.component(.month, from: point.date) == monthIndex + 1
                }
                let dateString = DateFormatters.iso8601WithFractional.string(from: targetDate)
                result.append(TimeSeriesPoint(x: dateString, y: matchingPoint?.value ?? 0))
            }
        }

        return result
    }

    // MARK: - Label Helpers

    private func periodLabel(week: Int, month: Int, year: Int) -> String {
        switch compareType {
        case .week:
            return String(localized: "compare.calendarWeek") + " \(week), \(year)"
        case .month:
            return "\(monthName(month)) \(year)"
        case .year:
            return "\(year)"
        }
    }

    private func monthName(_ month: Int) -> String {
        DateFormatters.shortDate.monthSymbols[month - 1]
    }

    private func xAxisLabel(for index: Int) -> String {
        let calendar = Calendar.current

        switch compareType {
        case .week:
            var components = DateComponents()
            components.weekOfYear = periodAWeek
            components.yearForWeekOfYear = periodAYear
            components.weekday = 2
            if let weekStart = calendar.date(from: components),
               let date = calendar.date(byAdding: .day, value: index, to: weekStart) {
                let day = calendar.component(.day, from: date)
                let month = calendar.component(.month, from: date)
                return "\(day).\(month)."
            }
            return "\(index + 1)"
        case .month:
            return "\(index + 1)."
        case .year:
            let months = [
                String(localized: "compare.months.jan"),
                String(localized: "compare.months.feb"),
                String(localized: "compare.months.mar"),
                String(localized: "compare.months.apr"),
                String(localized: "compare.months.may"),
                String(localized: "compare.months.jun"),
                String(localized: "compare.months.jul"),
                String(localized: "compare.months.aug"),
                String(localized: "compare.months.sep"),
                String(localized: "compare.months.oct"),
                String(localized: "compare.months.nov"),
                String(localized: "compare.months.dec")
            ]
            return index < months.count ? months[index] : "\(index + 1)"
        }
    }

    private func shouldShowXAxisLabel(for index: Int, totalCount: Int) -> Bool {
        switch compareType {
        case .week:
            return true
        case .month:
            let day = index + 1
            return day == 1 || day == 15 || day == totalCount
        case .year:
            return true
        }
    }
}
