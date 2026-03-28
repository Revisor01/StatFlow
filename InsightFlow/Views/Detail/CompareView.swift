import SwiftUI
import Charts

enum CompareType: String, CaseIterable {
    case week = "compare.week"
    case month = "compare.month"
    case year = "compare.year"
}

enum CompareMetric: String, CaseIterable {
    case pageviews = "metrics.pageviews"
    case visitors = "metrics.visitors"

    var icon: String {
        switch self {
        case .pageviews: return "eye.fill"
        case .visitors: return "person.fill"
        }
    }

    var color: Color {
        switch self {
        case .pageviews: return .blue
        case .visitors: return .purple
        }
    }
}

struct CompareView: View {
    let website: Website

    @StateObject private var viewModel: CompareViewModel
    @State private var compareType: CompareType = .week
    @State private var chartStyle: ChartStyle = .bar
    @State private var selectedPointIndex: Int?
    @State private var selectedPeriod: String?
    @State private var selectedMetric: CompareMetric = .pageviews

    // Periode A
    @State private var periodAWeek: Int = Calendar.current.component(.weekOfYear, from: Date())
    @State private var periodAMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var periodAYear: Int = Calendar.current.component(.year, from: Date())

    // Periode B (Standard: gleiche Woche/Monat, letztes Jahr)
    @State private var periodBWeek: Int = Calendar.current.component(.weekOfYear, from: Date())
    @State private var periodBMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var periodBYear: Int = Calendar.current.component(.year, from: Date()) - 1

    init(website: Website) {
        self.website = website
        _viewModel = StateObject(wrappedValue: CompareViewModel(websiteId: website.id))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Perioden-Auswahl
                periodSelectionSection

                // Vergleichen Button
                compareButton

                // Ergebnisse
                if let stats1 = viewModel.stats1, let stats2 = viewModel.stats2 {
                    comparisonStatsSection(stats1: stats1, stats2: stats2)
                    CompareChartSection(
                        viewModel: viewModel,
                        compareType: compareType,
                        selectedMetric: selectedMetric,
                        chartStyle: $chartStyle,
                        selectedPointIndex: $selectedPointIndex,
                        selectedPeriod: $selectedPeriod,
                        periodAWeek: periodAWeek,
                        periodAMonth: periodAMonth,
                        periodAYear: periodAYear,
                        periodBWeek: periodBWeek,
                        periodBMonth: periodBMonth,
                        periodBYear: periodBYear
                    )
                } else if viewModel.isLoading {
                    ProgressView(String(localized: "compare.loading"))
                        .padding(40)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(String(localized: "compare.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker(String(localized: "compare.type"), selection: $compareType) {
                    ForEach(CompareType.allCases, id: \.self) { type in
                        Text(String(localized: String.LocalizationValue(type.rawValue))).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }
        }
    }

    // MARK: - Period Selection

    private var periodSelectionSection: some View {
        VStack(spacing: 16) {
            // Periode A
            periodCard(
                title: String(localized: "compare.periodA"),
                color: .blue,
                week: $periodAWeek,
                month: $periodAMonth,
                year: $periodAYear
            )

            // VS Divider
            HStack {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)
                Text(String(localized: "compare.vs"))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)
            }

            // Periode B
            periodCard(
                title: String(localized: "compare.periodB"),
                color: .orange,
                week: $periodBWeek,
                month: $periodBMonth,
                year: $periodBYear
            )
        }
    }

    private func periodCard(title: String, color: Color, week: Binding<Int>, month: Binding<Int>, year: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(periodLabel(week: week.wrappedValue, month: month.wrappedValue, year: year.wrappedValue))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                switch compareType {
                case .week:
                    Picker(String(localized: "compare.calendarWeek"), selection: week) {
                        ForEach(1...53, id: \.self) { w in
                            Text(String(localized: "compare.calendarWeek") + " \(w)").tag(w)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                case .month:
                    Picker(String(localized: "compare.month"), selection: month) {
                        ForEach(1...12, id: \.self) { m in
                            Text(monthName(m)).tag(m)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                case .year:
                    EmptyView()
                }

                // Jahr (immer sichtbar)
                Picker(String(localized: "compare.year"), selection: year) {
                    ForEach((2020...Calendar.current.component(.year, from: Date())).reversed(), id: \.self) { y in
                        Text(String(y)).tag(y)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: compareType == .year ? .infinity : nil)
                .padding(.vertical, 8)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

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
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.monthSymbols[month - 1]
    }

    // MARK: - Compare Button

    private var compareButton: some View {
        Button {
            Task {
                await loadComparison()
            }
        } label: {
            HStack {
                Image(systemName: "arrow.left.arrow.right")
                Text(String(localized: "compare.button"))
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(viewModel.isLoading)
    }

    private func loadComparison() async {
        let dateRange1 = createDateRange(week: periodAWeek, month: periodAMonth, year: periodAYear)
        let dateRange2 = createDateRange(week: periodBWeek, month: periodBMonth, year: periodBYear)
        await viewModel.loadComparison(dateRange1: dateRange1, dateRange2: dateRange2)
    }

    private func createDateRange(week: Int, month: Int, year: Int) -> DateRange {
        let calendar = Calendar.current

        switch compareType {
        case .week:
            var components = DateComponents()
            components.weekOfYear = week
            components.yearForWeekOfYear = year
            components.weekday = 2 // Montag

            guard let startOfWeek = calendar.date(from: components) else {
                return .last7Days
            }
            let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
            return .custom(start: startOfWeek, end: min(endOfWeek, Date()))

        case .month:
            var startComponents = DateComponents()
            startComponents.year = year
            startComponents.month = month
            startComponents.day = 1

            guard let startOfMonth = calendar.date(from: startComponents) else {
                return .thisMonth
            }

            var endComponents = DateComponents()
            endComponents.month = 1
            endComponents.day = -1
            let endOfMonth = calendar.date(byAdding: endComponents, to: startOfMonth)!

            return .custom(start: startOfMonth, end: min(endOfMonth, Date()))

        case .year:
            var startComponents = DateComponents()
            startComponents.year = year
            startComponents.month = 1
            startComponents.day = 1

            var endComponents = DateComponents()
            endComponents.year = year
            endComponents.month = 12
            endComponents.day = 31

            guard let start = calendar.date(from: startComponents),
                  let end = calendar.date(from: endComponents) else {
                return .thisYear
            }

            return .custom(start: start, end: min(end, Date()))
        }
    }

    // MARK: - Comparison Stats

    private func comparisonStatsSection(stats1: WebsiteStats, stats2: WebsiteStats) -> some View {
        VStack(spacing: 16) {
            // Header mit Perioden
            HStack {
                VStack(alignment: .leading) {
                    Circle().fill(.blue).frame(width: 8, height: 8)
                    Text(periodLabel(week: periodAWeek, month: periodAMonth, year: periodAYear))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Circle().fill(.orange).frame(width: 8, height: 8)
                    Text(periodLabel(week: periodBWeek, month: periodBMonth, year: periodBYear))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 8)

            // Anklickbare Hero Cards - alle 4 Werte
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                // Aufrufe Hero - klickbar
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        selectedMetric = .pageviews
                        selectedPointIndex = nil
                    }
                } label: {
                    CompareHeroCard(
                        label: String(localized: "metrics.pageviews"),
                        icon: "eye.fill",
                        value1: stats1.pageviews.value,
                        value2: stats2.pageviews.value,
                        isSelected: selectedMetric == .pageviews
                    )
                }
                .buttonStyle(.plain)

                // Besucher Hero - klickbar
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        selectedMetric = .visitors
                        selectedPointIndex = nil
                    }
                } label: {
                    CompareHeroCard(
                        label: String(localized: "metrics.visitors"),
                        icon: "person.fill",
                        value1: stats1.visitors.value,
                        value2: stats2.visitors.value,
                        isSelected: selectedMetric == .visitors
                    )
                }
                .buttonStyle(.plain)

                // Besuche Hero (nicht anklickbar für Graph)
                CompareHeroCard(
                    label: String(localized: "metrics.visits"),
                    icon: "arrow.triangle.swap",
                    value1: stats1.visits.value,
                    value2: stats2.visits.value,
                    isSelected: false
                )

                // Absprungrate Hero
                CompareHeroCard(
                    label: String(localized: "metrics.bounceRate"),
                    icon: "arrow.uturn.backward",
                    value1: Int(stats1.bounceRate),
                    value2: Int(stats2.bounceRate),
                    isSelected: false,
                    isPercentage: true,
                    invertBetter: true
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    NavigationStack {
        CompareView(
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
