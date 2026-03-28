import SwiftUI
import Charts

struct WebsiteDetailChartSection: View {
    let viewModel: WebsiteDetailViewModel
    @Binding var selectedMetric: ChartMetric
    @Binding var selectedChartPoint: TimeSeriesPoint?
    @Binding var selectedChartStyle: ChartStyle
    let selectedDateRange: DateRange

    // MARK: - Computed helpers

    private var isHourlyData: Bool {
        selectedDateRange.unit == "hour"
    }

    private var isYearlyData: Bool {
        selectedDateRange.preset == .thisYear || selectedDateRange.preset == .lastYear
    }

    private var currentChartData: [TimeSeriesPoint] {
        switch selectedMetric {
        case .pageviews:
            return viewModel.pageviewsData
        case .visitors:
            return viewModel.sessionsData
        }
    }

    private var chartXAxisValues: [Date] {
        guard viewModel.pageviewsData.count > 1 else {
            return viewModel.pageviewsData.map { $0.date }
        }

        let dates = viewModel.pageviewsData.map { $0.date }.sorted()
        guard let firstDate = dates.first, let lastDate = dates.last else { return [] }

        if isHourlyData {
            var result: [Date] = []
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: firstDate)

            for hour in [0, 6, 12, 18] {
                if let targetDate = calendar.date(byAdding: .hour, value: hour, to: startOfDay),
                   targetDate <= lastDate {
                    result.append(targetDate)
                }
            }

            if result.isEmpty {
                result = [firstDate, lastDate]
            }

            return result
        }

        let dayCount = Calendar.current.dateComponents([.day], from: firstDate, to: lastDate).day ?? 0

        if dayCount <= 7 {
            if dates.count <= 5 {
                return dates
            }
            let step = max(1, dates.count / 4)
            var result: [Date] = [firstDate]
            for i in stride(from: step, to: dates.count - 1, by: step) {
                result.append(dates[i])
            }
            if result.last != lastDate {
                result.append(lastDate)
            }
            return result
        } else if dayCount <= 14 {
            let step = max(1, dates.count / 4)
            var result: [Date] = [firstDate]
            for i in stride(from: step, to: dates.count - 1, by: step) {
                result.append(dates[i])
            }
            if result.last != lastDate {
                result.append(lastDate)
            }
            return result
        } else if dayCount <= 31 {
            var result: [Date] = [firstDate]
            var currentDate = firstDate
            while let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: currentDate),
                  nextWeek < lastDate {
                result.append(nextWeek)
                currentDate = nextWeek
            }
            if result.last != lastDate {
                result.append(lastDate)
            }
            return result
        } else {
            let step = max(1, dates.count / 4)
            var result: [Date] = [firstDate]
            for i in stride(from: step, to: dates.count - 1, by: step) {
                result.append(dates[i])
            }
            if result.last != lastDate {
                result.append(lastDate)
            }
            return result
        }
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                chartHeader
                chartContent
            }
        }
    }

    private var chartHeader: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: selectedMetric.icon)
                    .foregroundStyle(selectedMetric.color)
                Text(String(localized: String.LocalizationValue(selectedMetric.rawValue)))
                    .font(.headline)
            }

            Spacer()

            if let point = selectedChartPoint {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(point.value.formatted())
                        .font(.headline)
                        .foregroundStyle(selectedMetric.color)
                    if isHourlyData {
                        Text(point.date, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(point.date, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            Button {
                withAnimation(.spring(duration: 0.3)) {
                    selectedChartStyle = selectedChartStyle == .line ? .bar : .line
                }
            } label: {
                Image(systemName: selectedChartStyle.icon)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(Circle())
            }
        }
    }

    @ViewBuilder
    private var chartContent: some View {
        let useBarChart = isYearlyData || selectedChartStyle == .bar
        if useBarChart {
            barChartView
        } else {
            lineChartView
        }
    }

    private var lineChartView: some View {
        Chart {
            ForEach(currentChartData) { point in
                LineMark(
                    x: .value("Datum", point.date),
                    y: .value(selectedMetric.rawValue, point.value)
                )
                .foregroundStyle(selectedMetric.color)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
            }

            ForEach(currentChartData) { point in
                AreaMark(
                    x: .value("Datum", point.date),
                    y: .value(selectedMetric.rawValue, point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [selectedMetric.color.opacity(0.3), selectedMetric.color.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)
            }

            if currentChartData.count <= 31 {
                ForEach(currentChartData) { point in
                    PointMark(
                        x: .value("Datum", point.date),
                        y: .value(selectedMetric.rawValue, point.value)
                    )
                    .foregroundStyle(selectedMetric.color)
                    .symbolSize(currentChartData.count <= 12 ? 30 : 20)
                }
            }

            if let selected = selectedChartPoint {
                RuleMark(x: .value("Datum", selected.date))
                    .foregroundStyle(.gray.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))

                PointMark(
                    x: .value("Datum", selected.date),
                    y: .value(selectedMetric.rawValue, selected.value)
                )
                .foregroundStyle(selectedMetric.color)
                .symbolSize(80)
                .annotation(position: .top, spacing: 8) {
                    Text("\(selected.value)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(selectedMetric.color)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: chartXAxisValues) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                    .foregroundStyle(.gray.opacity(0.3))
                if isHourlyData {
                    AxisValueLabel(format: .dateTime.hour().minute())
                } else {
                    AxisValueLabel(format: .dateTime.day().month())
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
        .chartYScale(domain: .automatic(includesZero: true))
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                updateSelectedPoint(at: value.location, geometry: geometry, proxy: proxy)
                            }
                    )
                    .onTapGesture { location in
                        toggleSelectedPoint(at: location, geometry: geometry, proxy: proxy)
                    }
            }
        }
        .frame(height: 220)
    }

    private var barChartView: some View {
        let barUnit: Calendar.Component = isYearlyData ? .month : (isHourlyData ? .hour : .day)

        return Chart {
            RuleMark(y: .value("Baseline", 0))
                .foregroundStyle(.gray.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 1))

            ForEach(currentChartData) { point in
                BarMark(
                    x: .value("Datum", point.date, unit: barUnit),
                    y: .value(selectedMetric.rawValue, point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [selectedMetric.color, selectedMetric.color.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(4)
                .annotation(position: .top, spacing: 4) {
                    if selectedChartPoint?.id == point.id {
                        Text("\(point.value)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(selectedMetric.color)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
            }

            if let selected = selectedChartPoint {
                RuleMark(x: .value("Datum", selected.date))
                    .foregroundStyle(.gray.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                    .foregroundStyle(.gray.opacity(0.3))
                if isYearlyData {
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                } else if isHourlyData {
                    AxisValueLabel(format: .dateTime.hour())
                } else {
                    AxisValueLabel(format: .dateTime.day().month())
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
                                updateSelectedPoint(at: value.location, geometry: geometry, proxy: proxy)
                            }
                            .onEnded { _ in
                                // Punkt bleibt sichtbar bis erneutes Tippen
                            }
                    )
                    .onTapGesture { location in
                        toggleSelectedPoint(at: location, geometry: geometry, proxy: proxy)
                    }
            }
        }
        .frame(height: 220)
    }

    private func updateSelectedPoint(at location: CGPoint, geometry: GeometryProxy, proxy: ChartProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let x = location.x - geometry[plotFrame].origin.x
        if let date: Date = proxy.value(atX: x) {
            if let closest = currentChartData.min(by: {
                abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
            }) {
                withAnimation(.easeOut(duration: 0.1)) {
                    selectedChartPoint = closest
                }
            }
        }
    }

    private func toggleSelectedPoint(at location: CGPoint, geometry: GeometryProxy, proxy: ChartProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let x = location.x - geometry[plotFrame].origin.x
        if let date: Date = proxy.value(atX: x) {
            withAnimation(.easeOut(duration: 0.15)) {
                if let closest = currentChartData.min(by: {
                    abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                }) {
                    if selectedChartPoint?.id == closest.id {
                        selectedChartPoint = nil
                    } else {
                        selectedChartPoint = closest
                    }
                }
            }
        }
    }
}
