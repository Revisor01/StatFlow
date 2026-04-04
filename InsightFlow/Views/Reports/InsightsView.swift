import SwiftUI
import Charts

struct InsightsView: View {
    let website: Website

    var body: some View {
        ComparisonView(website: website)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "insights.title"))
            .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Comparison View

struct ComparisonView: View {
    let website: Website

    @StateObject private var viewModel: ComparisonViewModel

    init(website: Website) {
        self.website = website
        _viewModel = StateObject(wrappedValue: ComparisonViewModel(websiteId: website.id))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                periodSelector

                if viewModel.isLoading {
                    ProgressView()
                        .padding(40)
                } else if let current = viewModel.currentStats, let previous = viewModel.previousStats {
                    comparisonCards(current: current, previous: previous)
                    comparisonChart
                }
            }
            .padding()
        }
        .task {
            await viewModel.loadComparison()
        }
    }

    private var periodSelector: some View {
        HStack(spacing: 12) {
            ForEach(ComparisonPeriod.allCases, id: \.self) { period in
                Button {
                    withAnimation {
                        viewModel.selectedPeriod = period
                    }
                    Task {
                        await viewModel.loadComparison()
                    }
                } label: {
                    Text(period.displayName)
                        .font(.subheadline)
                        .fontWeight(viewModel.selectedPeriod == period ? .semibold : .regular)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(viewModel.selectedPeriod == period ? Color.blue : Color(.secondarySystemGroupedBackground))
                        .foregroundColor(viewModel.selectedPeriod == period ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func comparisonCards(current: WebsiteStats, previous: WebsiteStats) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ComparisonCard(
                    title: String(localized: "metrics.pageviews"),
                    current: current.pageviews.value,
                    previous: previous.pageviews.value,
                    icon: "eye.fill",
                    color: .blue
                )

                ComparisonCard(
                    title: String(localized: "metrics.visitors"),
                    current: current.visitors.value,
                    previous: previous.visitors.value,
                    icon: "person.fill",
                    color: .purple
                )
            }

            HStack(spacing: 12) {
                ComparisonCard(
                    title: String(localized: "metrics.visits"),
                    current: current.visits.value,
                    previous: previous.visits.value,
                    icon: "arrow.triangle.swap",
                    color: .orange
                )

                ComparisonCard(
                    title: String(localized: "metrics.bounceRate"),
                    current: Int(current.bounceRate),
                    previous: Int(previous.bounceRate),
                    icon: "arrow.uturn.backward",
                    color: .red,
                    isPercentage: true,
                    invertColors: true
                )
            }
        }
    }

    private var comparisonChart: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text(String(localized: "insights.pageviewsComparison"))
                    .font(.headline)

                Chart {
                    ForEach(viewModel.currentPageviews) { point in
                        LineMark(
                            x: .value("Tag", point.dayIndex),
                            y: .value("Aufrufe", point.value),
                            series: .value("Zeitraum", "Aktuell")
                        )
                        .foregroundStyle(.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                    }

                    ForEach(viewModel.previousPageviews) { point in
                        LineMark(
                            x: .value("Tag", point.dayIndex),
                            y: .value("Aufrufe", point.value),
                            series: .value("Zeitraum", "Vorher")
                        )
                        .foregroundStyle(.gray.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 200)

                HStack(spacing: 16) {
                    LegendItem(color: .blue, label: viewModel.selectedPeriod.currentLabel)
                    LegendItem(color: .gray, label: viewModel.selectedPeriod.previousLabel, isDashed: true)
                }
            }
        }
    }
}

struct ComparisonCard: View {
    let title: String
    let current: Int
    let previous: Int
    let icon: String
    let color: Color
    var isPercentage: Bool = false
    var invertColors: Bool = false

    var change: Double {
        guard previous != 0 else { return current > 0 ? 100 : 0 }
        return Double(current - previous) / Double(previous) * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
                changeIndicator
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(isPercentage ? "\(current)%" : current.formatted())
                    .font(.title2)
                    .fontWeight(.bold)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 4) {
                Text("Vorher:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(isPercentage ? "\(previous)%" : previous.formatted())
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var changeIndicator: some View {
        let isPositive = change > 0
        let changeColor: Color = {
            if invertColors {
                return isPositive ? .red : .green
            }
            return isPositive ? .green : .red
        }()

        return HStack(spacing: 2) {
            Image(systemName: isPositive ? "arrow.up" : "arrow.down")
            Text(String(format: "%.0f%%", abs(change)))
        }
        .font(.caption)
        .fontWeight(.medium)
        .foregroundStyle(changeColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(changeColor.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - ViewModel

enum ComparisonPeriod: CaseIterable {
    case weekOverWeek
    case monthOverMonth

    var displayName: String {
        switch self {
        case .weekOverWeek: return String(localized: "compare.week")
        case .monthOverMonth: return String(localized: "compare.month")
        }
    }

    var currentLabel: String {
        switch self {
        case .weekOverWeek: return String(localized: "insights.thisWeek")
        case .monthOverMonth: return String(localized: "compare.month")
        }
    }

    var previousLabel: String {
        switch self {
        case .weekOverWeek: return String(localized: "insights.lastWeek")
        case .monthOverMonth: return String(localized: "insights.lastMonth")
        }
    }

    var currentRange: DateRange {
        switch self {
        case .weekOverWeek: return .last7Days
        case .monthOverMonth: return .thisMonth
        }
    }

    var previousRange: DateRange {
        switch self {
        case .weekOverWeek:
            let calendar = Calendar.current
            let now = Date()
            let start = calendar.date(byAdding: .day, value: -13, to: calendar.startOfDay(for: now))!
            let end = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now))!
            return .custom(start: start, end: end)
        case .monthOverMonth:
            return .lastMonth
        }
    }
}

struct ComparisonDataPoint: Identifiable {
    let id = UUID()
    let dayIndex: Int
    let value: Int
}

@MainActor
class ComparisonViewModel: ObservableObject {
    let websiteId: String

    @Published var selectedPeriod: ComparisonPeriod = .weekOverWeek
    @Published var currentStats: WebsiteStats?
    @Published var previousStats: WebsiteStats?
    @Published var currentPageviews: [ComparisonDataPoint] = []
    @Published var previousPageviews: [ComparisonDataPoint] = []
    @Published var isLoading = false

    private var loadingTask: Task<Void, Never>?
    private let api = UmamiAPI.shared

    init(websiteId: String) {
        self.websiteId = websiteId
    }

    func loadComparison() async {
        loadingTask?.cancel()
        let task = Task {
            isLoading = true
            defer { if !Task.isCancelled { isLoading = false } }

            do {
                async let currentStatsTask = api.getStats(websiteId: websiteId, dateRange: selectedPeriod.currentRange)
                async let previousStatsTask = api.getStats(websiteId: websiteId, dateRange: selectedPeriod.previousRange)
                async let currentPageviewsTask = api.getPageviews(websiteId: websiteId, dateRange: selectedPeriod.currentRange)
                async let previousPageviewsTask = api.getPageviews(websiteId: websiteId, dateRange: selectedPeriod.previousRange)

                let (current, previous, currentPV, previousPV) = try await (
                    currentStatsTask, previousStatsTask, currentPageviewsTask, previousPageviewsTask
                )
                guard !Task.isCancelled else { return }

                currentStats = current
                previousStats = previous

                currentPageviews = currentPV.pageviews.enumerated().map { index, point in
                    ComparisonDataPoint(dayIndex: index, value: point.value)
                }

                previousPageviews = previousPV.pageviews.enumerated().map { index, point in
                    ComparisonDataPoint(dayIndex: index, value: point.value)
                }

            } catch {
                guard !Task.isCancelled else { return }
                #if DEBUG
                print("Comparison error: \(error)")
                #endif
            }
        }
        loadingTask = task
        await task.value
    }
}

#Preview {
    NavigationStack {
        InsightsView(
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
