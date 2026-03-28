import SwiftUI
import Charts

struct RetentionView: View {
    let website: Website

    @StateObject private var viewModel: RetentionViewModel
    @State private var selectedDateRange: DateRange = .thisWeek

    init(website: Website) {
        self.website = website
        _viewModel = StateObject(wrappedValue: RetentionViewModel(websiteId: website.id))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                dateRangePicker

                explanationCard

                if viewModel.isLoading {
                    ProgressView(String(localized: "retention.loading"))
                        .padding(40)
                } else if viewModel.retentionRows.isEmpty {
                    ContentUnavailableView(
                        String(localized: "retention.empty"),
                        systemImage: "chart.bar.xaxis",
                        description: Text(String(localized: "retention.empty.description"))
                    )
                } else if viewModel.returningVisitorRows.isEmpty {
                    noRetentionDataView
                } else {
                    summaryCards
                    retentionChart
                    retentionTable
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(String(localized: "retention.title"))
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadRetention(dateRange: selectedDateRange)
        }
        .onChange(of: selectedDateRange) { _, newValue in
            Task {
                await viewModel.loadRetention(dateRange: newValue)
            }
        }
        .refreshable {
            await viewModel.loadRetention(dateRange: selectedDateRange)
        }
    }

    private var explanationCard: some View {
        GlassCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "retention.what.title"))
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(String(localized: "retention.what.description"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var noRetentionDataView: some View {
        GlassCard {
            VStack(spacing: 16) {
                Image(systemName: "person.2.slash")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)

                Text(String(localized: "retention.noReturning"))
                    .font(.headline)

                Text(String(localized: "retention.noReturning.description"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 20) {
                    VStack {
                        Text("\(viewModel.totalVisitors)")
                            .font(.title)
                            .fontWeight(.bold)
                        Text(String(localized: "retention.visitors"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack {
                        Text("\(viewModel.uniqueDays)")
                            .font(.title)
                            .fontWeight(.bold)
                        Text(String(localized: "retention.days"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 8)
            }
            .padding()
        }
    }

    private var dateRangePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach([DateRange.last7Days, .last30Days, .thisMonth, .lastMonth], id: \.preset) { range in
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            selectedDateRange = range
                        }
                    } label: {
                        Text(range.displayName)
                            .font(.subheadline)
                            .fontWeight(selectedDateRange.preset == range.preset ? .semibold : .regular)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedDateRange.preset == range.preset ? Color.primary : .clear)
                            .foregroundColor(selectedDateRange.preset == range.preset ? Color(.systemBackground) : .primary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(selectedDateRange.preset == range.preset ? .clear : .secondary.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var summaryCards: some View {
        HStack(spacing: 12) {
            RetentionSummaryCard(
                title: String(localized: "retention.average"),
                value: String(format: "%.1f%%", viewModel.averageRetention),
                icon: "chart.line.uptrend.xyaxis",
                color: .blue
            )

            RetentionSummaryCard(
                title: String(localized: "retention.max"),
                value: String(format: "%.1f%%", viewModel.maxRetention),
                icon: "arrow.up.circle.fill",
                color: .green
            )

            RetentionSummaryCard(
                title: String(localized: "retention.days"),
                value: "\(viewModel.retentionRows.count)",
                icon: "calendar",
                color: .orange
            )
        }
    }

    private var retentionChart: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text(String(localized: "retention.overTime"))
                    .font(.headline)

                Chart {
                    ForEach(viewModel.chartData) { point in
                        BarMark(
                            x: .value("Tag", "Tag \(point.day)"),
                            y: .value("Retention", point.percentage)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .orange.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(4)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let percentage = value.as(Double.self) {
                                Text("\(Int(percentage))%")
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...100)
                .frame(height: 200)
            }
        }
    }

    private var retentionTable: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "retention.returning"))
                        .font(.headline)

                    Text(String(localized: "retention.returningNote"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text(String(localized: "retention.firstVisit"))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(String(localized: "retention.after"))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .frame(width: 50, alignment: .center)
                        Text(String(localized: "retention.returned"))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .frame(width: 50, alignment: .trailing)
                        Text(String(localized: "retention.rate"))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .frame(width: 70, alignment: .trailing)
                    }
                    .padding(.vertical, 8)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    ForEach(viewModel.returningVisitorRows.prefix(20)) { row in
                        HStack {
                            Text(formatDate(row.date))
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(row.day == 1 ? String(localized: "retention.oneDay") : String(localized: "retention.nDays \(row.day)"))
                                .font(.caption)
                                .foregroundStyle(.blue)
                                .frame(width: 50, alignment: .center)
                            Text("\(row.returnVisitors)/\(row.visitors)")
                                .font(.caption)
                                .frame(width: 50, alignment: .trailing)
                            HStack(spacing: 4) {
                                RetentionBar(percentage: row.percentage)
                                Text(String(format: "%.0f%%", row.percentage))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(retentionColor(row.percentage))
                            }
                            .frame(width: 70, alignment: .trailing)
                        }
                        .padding(.vertical, 8)

                        if row.id != viewModel.returningVisitorRows.prefix(20).last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func formatDate(_ dateString: String) -> String {
        // Parse ISO8601 format
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        if let date = isoFormatter.date(from: dateString) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "dd.MM.yyyy"
            return outputFormatter.string(from: date)
        }

        // Fallback für einfaches Datum
        let simpleFormatter = DateFormatter()
        simpleFormatter.dateFormat = "yyyy-MM-dd"
        if let date = simpleFormatter.date(from: dateString) {
            simpleFormatter.dateFormat = "dd.MM.yyyy"
            return simpleFormatter.string(from: date)
        }

        return dateString
    }

    private func retentionColor(_ percentage: Double) -> Color {
        if percentage >= 30 { return .green }
        if percentage >= 15 { return .orange }
        return .red
    }
}

struct RetentionSummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.headline)
                .fontWeight(.bold)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct RetentionBar: View {
    let percentage: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(.tertiarySystemGroupedBackground))

                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor)
                    .frame(width: max(2, geometry.size.width * CGFloat(percentage / 100)))
            }
        }
        .frame(width: 30, height: 6)
    }

    private var barColor: Color {
        if percentage >= 30 { return .green }
        if percentage >= 15 { return .orange }
        return .red
    }
}

struct RetentionChartPoint: Identifiable {
    let id = UUID()
    let day: Int
    let percentage: Double
}

@MainActor
class RetentionViewModel: ObservableObject {
    let websiteId: String

    @Published var retentionRows: [RetentionRow] = []
    @Published var isLoading = false

    private let api = UmamiAPI.shared

    init(websiteId: String) {
        self.websiteId = websiteId
    }

    // Nur Zeilen mit day > 0 (echte Rückkehrer)
    var returningVisitorRows: [RetentionRow] {
        retentionRows.filter { $0.day > 0 }
    }

    var totalVisitors: Int {
        retentionRows.filter { $0.day == 0 }.reduce(0) { $0 + $1.visitors }
    }

    var uniqueDays: Int {
        Set(retentionRows.map { $0.date }).count
    }

    var averageRetention: Double {
        let rows = returningVisitorRows
        guard !rows.isEmpty else { return 0 }
        let total = rows.reduce(0.0) { $0 + $1.percentage }
        return total / Double(rows.count)
    }

    var maxRetention: Double {
        returningVisitorRows.map(\.percentage).max() ?? 0
    }

    var chartData: [RetentionChartPoint] {
        // Gruppiere nach Tag (day) und berechne Durchschnitt
        var dayAverages: [Int: [Double]] = [:]
        for row in returningVisitorRows {
            dayAverages[row.day, default: []].append(row.percentage)
        }

        return dayAverages.keys.sorted().map { day in
            let percentages = dayAverages[day]!
            let avg = percentages.reduce(0, +) / Double(percentages.count)
            return RetentionChartPoint(day: day, percentage: avg)
        }
    }

    func loadRetention(dateRange: DateRange) async {
        isLoading = true

        do {
            retentionRows = try await api.getRetention(websiteId: websiteId, dateRange: dateRange)
        } catch {
            #if DEBUG
            print("Retention error: \(error)")
            #endif
            retentionRows = []
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        RetentionView(
            website: Website(
                id: "1",
                name: "Test",
                domain: "test.de",
                shareId: nil,
            teamId: nil,
                resetAt: nil,
                createdAt: nil
            )
        )
    }
}
