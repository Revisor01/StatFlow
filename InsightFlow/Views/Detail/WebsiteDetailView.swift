import SwiftUI
import Charts

// Enum für auswählbare Metriken im Chart
enum ChartMetric: String, CaseIterable {
    case pageviews = "metrics.pageviews"
    case visitors = "metrics.visitors"

    var color: Color {
        switch self {
        case .pageviews: return .blue
        case .visitors: return .purple
        }
    }

    var icon: String {
        switch self {
        case .pageviews: return "eye.fill"
        case .visitors: return "person.fill"
        }
    }
}

enum ChartStyle: String, CaseIterable {
    case line = "chart.style.line"
    case bar = "chart.style.bar"

    var icon: String {
        switch self {
        case .line: return "chart.xyaxis.line"
        case .bar: return "chart.bar.fill"
        }
    }
}

struct WebsiteDetailView: View {
    let website: Website

    @StateObject private var viewModel: WebsiteDetailViewModel
    @State private var selectedDateRange: DateRange = .today
    @State private var selectedChartPoint: TimeSeriesPoint?
    @State private var selectedMetric: ChartMetric = .pageviews
    @State private var selectedChartStyle: ChartStyle = .bar
    @State private var showCustomDatePicker = false
    @State private var customStartDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var customEndDate = Date()

    private var isPlausible: Bool {
        AnalyticsManager.shared.providerType == .plausible
    }

    init(website: Website) {
        self.website = website
        _viewModel = StateObject(wrappedValue: WebsiteDetailViewModel(websiteId: website.id))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                dateRangePicker

                if let stats = viewModel.stats {
                    heroStats(stats)
                }

                if !viewModel.pageviewsData.isEmpty {
                    WebsiteDetailChartSection(
                        viewModel: viewModel,
                        selectedMetric: $selectedMetric,
                        selectedChartPoint: $selectedChartPoint,
                        selectedChartStyle: $selectedChartStyle,
                        selectedDateRange: selectedDateRange
                    )
                }

                // Schnellzugriff
                quickActionsSection

                if !viewModel.topPages.isEmpty {
                    topPagesSection
                }

                if !viewModel.referrers.isEmpty {
                    referrersSection
                }

                WebsiteDetailMetricsSections(viewModel: viewModel)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(website.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isPlausible {
                    // Plausible: Just show count, no detail view (no individual user tracking)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        Text("\(viewModel.activeVisitors)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .contentTransition(.numericText())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.green.opacity(0.15))
                    .clipShape(Capsule())
                } else {
                    // Umami: Full realtime view with user journeys
                    NavigationLink {
                        RealtimeView(website: website)
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                            Text("\(viewModel.activeVisitors)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .contentTransition(.numericText())
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.green.opacity(0.15))
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .refreshable {
            await viewModel.loadData(dateRange: selectedDateRange)
        }
        .task {
            await viewModel.loadData(dateRange: selectedDateRange)
        }
        .onChange(of: selectedDateRange) { _, newValue in
            Task {
                await viewModel.loadData(dateRange: newValue)
            }
        }
    }

    // MARK: - Date Range Picker

    private var dateRangePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DateRange.allCases, id: \.preset) { range in
                    DateRangeChip(
                        title: range.displayName,
                        isSelected: selectedDateRange.preset == range.preset && selectedDateRange.preset != .custom
                    ) {
                        withAnimation(.spring(duration: 0.3)) {
                            selectedDateRange = range
                        }
                    }
                }

                // Custom Button
                DateRangeChip(
                    title: selectedDateRange.preset == .custom ? selectedDateRange.displayName : String(localized: "daterange.custom"),
                    isSelected: selectedDateRange.preset == .custom
                ) {
                    showCustomDatePicker = true
                }
            }
            .padding(.horizontal, 4)
            .padding(.trailing, 20)
        }
        .mask(
            HStack(spacing: 0) {
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 30)
            }
        )
        .sheet(isPresented: $showCustomDatePicker) {
            CustomDateRangePicker(
                startDate: $customStartDate,
                endDate: $customEndDate
            ) {
                withAnimation(.spring(duration: 0.3)) {
                    selectedDateRange = .custom(start: customStartDate, end: customEndDate)
                }
                showCustomDatePicker = false
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Hero Stats

    private func heroStats(_ stats: WebsiteStats) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            // Aufrufe - klickbar, ändert Graph
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    selectedMetric = .pageviews
                    selectedChartPoint = nil
                }
            } label: {
                HeroStatCard(
                    value: stats.pageviews.value.formatted(),
                    label: String(localized: "metrics.pageviews"),
                    change: stats.pageviews.changePercentage,
                    icon: "eye.fill",
                    color: .blue,
                    isSelected: selectedMetric == .pageviews
                )
            }
            .buttonStyle(.plain)

            // Besucher:innen - klickbar für Graph, mit Link zu Sessions (nur Umami)
            if isPlausible {
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        selectedMetric = .visitors
                        selectedChartPoint = nil
                    }
                } label: {
                    HeroStatCard(
                        value: stats.visitors.value.formatted(),
                        label: String(localized: "metrics.visitors"),
                        change: stats.visitors.changePercentage,
                        icon: "person.fill",
                        color: .purple,
                        isSelected: selectedMetric == .visitors
                    )
                }
                .buttonStyle(.plain)
            } else {
                HeroStatCardWithLink(
                    value: stats.visitors.value.formatted(),
                    label: String(localized: "metrics.visitors"),
                    change: stats.visitors.changePercentage,
                    icon: "person.fill",
                    color: .purple,
                    isSelected: selectedMetric == .visitors,
                    onTap: {
                        withAnimation(.spring(duration: 0.3)) {
                            selectedMetric = .visitors
                            selectedChartPoint = nil
                        }
                    },
                    destination: { SessionsView(website: website) }
                )
            }

            // Besuche - Navigation zu Retention (nur Umami)
            if isPlausible {
                HeroStatCard(
                    value: stats.visits.value.formatted(),
                    label: String(localized: "metrics.visits"),
                    change: stats.visits.changePercentage,
                    icon: "arrow.triangle.swap",
                    color: .orange
                )
            } else {
                ZStack(alignment: .topTrailing) {
                    NavigationLink {
                        RetentionView(website: website)
                    } label: {
                        HeroStatCard(
                            value: stats.visits.value.formatted(),
                            label: String(localized: "metrics.visits"),
                            change: stats.visits.changePercentage,
                            icon: "arrow.triangle.swap",
                            color: .orange
                        )
                    }
                    .buttonStyle(.plain)

                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.orange, .orange.opacity(0.2))
                        .padding(8)
                }
            }

            HeroStatCard(
                value: String(format: "%.1f%%", stats.bounceRate),
                label: String(localized: "metrics.bounceRate"),
                change: stats.bounces.changePercentage,
                icon: "arrow.uturn.backward",
                color: stats.bounceRate > 50 ? .red : .green,
                invertChangeColor: true
            )

            HeroStatCard(
                value: stats.averageTimeFormatted,
                label: String(localized: "metrics.duration"),
                change: stats.totaltime.changePercentage,
                icon: "clock.fill",
                color: .indigo
            )

            // Live - Navigation zu Realtime (nur Umami)
            if isPlausible {
                HeroStatCard(
                    value: "\(viewModel.activeVisitors)",
                    label: String(localized: "dashboard.live"),
                    change: nil,
                    icon: "wifi",
                    color: .green,
                    isLive: true
                )
            } else {
                NavigationLink {
                    RealtimeView(website: website)
                } label: {
                    HeroStatCard(
                        value: "\(viewModel.activeVisitors)",
                        label: String(localized: "dashboard.live"),
                        change: nil,
                        icon: "wifi",
                        color: .green,
                        isLive: true,
                        showChevron: true
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Quick Actions

    @ViewBuilder
    private var quickActionsSection: some View {
        if isPlausible {
            // Plausible: Only Compare is available (no Sessions)
            HStack(spacing: 12) {
                NavigationLink {
                    CompareView(website: website)
                } label: {
                    QuickActionCard(
                        icon: "arrow.left.arrow.right",
                        title: String(localized: "compare.title"),
                        subtitle: String(localized: "compare.type"),
                        color: .orange
                    )
                }
                .buttonStyle(.plain)
            }
        } else {
            HStack(spacing: 12) {
                // Sessions / User Journey - Umami only
                NavigationLink {
                    SessionsView(website: website)
                } label: {
                    QuickActionCard(
                        icon: "person.2.fill",
                        title: String(localized: "sessions.tab.sessions"),
                        subtitle: String(localized: "journeys.userJourney"),
                        color: .purple
                    )
                }
                .buttonStyle(.plain)

                // Vergleich
                NavigationLink {
                    CompareView(website: website)
                } label: {
                    QuickActionCard(
                        icon: "arrow.left.arrow.right",
                        title: String(localized: "compare.title"),
                        subtitle: String(localized: "compare.type"),
                        color: .orange
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Top Pages

    @ViewBuilder
    private var topPagesSection: some View {
        if isPlausible {
            // Plausible: No detailed pages view, just show the card without navigation
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: String(localized: "website.topPages"), icon: "doc.text.fill")

                    ForEach(viewModel.topPages.prefix(8), id: \.name) { page in
                        HStack(alignment: .top) {
                            Text(page.name)
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
                            Text(page.value.formatted())
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                        }
                        .padding(.vertical, 4)

                        if page.name != viewModel.topPages.prefix(8).last?.name {
                            Divider()
                        }
                    }
                }
            }
        } else {
            NavigationLink {
                PagesView(website: website)
            } label: {
                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            SectionHeader(title: String(localized: "website.topPages"), icon: "doc.text.fill")
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }

                    // Kombiniere Titel und Pfade für die Anzeige
                    let combinedItems = createCombinedItems()

                    ForEach(combinedItems.prefix(8), id: \.path) { item in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.subheadline)
                                    .lineLimit(1)

                                Text(website.displayDomain + item.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(item.views.formatted())
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                        }
                        .padding(.vertical, 4)

                        if item.path != combinedItems.prefix(8).last?.path {
                            Divider()
                        }
                    }
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private struct CombinedItem {
        let title: String
        let path: String
        let views: Int
    }

    private func createCombinedItems() -> [CombinedItem] {
        var result: [CombinedItem] = []
        var usedTitles: Set<String> = []

        for page in viewModel.topPages {
            let matchingTitle = viewModel.pageTitles.first { title in
                !usedTitles.contains(title.name) &&
                abs(title.value - page.value) <= max(1, Int(Double(page.value) * 0.15))
            }

            let title: String
            if let match = matchingTitle {
                usedTitles.insert(match.name)
                title = match.name
            } else {
                title = extractTitleFromPath(page.name)
            }

            result.append(CombinedItem(title: title, path: page.name, views: page.value))
        }

        return result
    }

    private func extractTitleFromPath(_ path: String) -> String {
        if path == "/" { return String(localized: "website.homepage") }
        let mainPath = path.split(separator: "?").first ?? Substring(path)
        let segments = mainPath.trimmingCharacters(in: CharacterSet(charactersIn: "/")).split(separator: "/")
        if let lastSegment = segments.last {
            return String(lastSegment).replacingOccurrences(of: "-", with: " ").capitalized
        }
        return path
    }

    // MARK: - Referrers

    private var referrersSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: String(localized: "website.referrers"), icon: "link")

                ForEach(viewModel.referrers.prefix(8)) { item in
                    HStack {
                        Text(item.name.isEmpty ? String(localized: "website.referrer.direct") : shortenReferrer(item.name))
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        Text(item.value.formatted())
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 4)

                    if item.id != viewModel.referrers.prefix(8).last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Helper Functions

    private func shortenReferrer(_ referrer: String) -> String {
        var result = referrer
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")

        if let slashIndex = result.firstIndex(of: "/") {
            result = String(result[..<slashIndex])
        }

        return result.count > 25 ? String(result.prefix(22)) + "..." : result
    }
}

#Preview {
    NavigationStack {
        WebsiteDetailView(
            website: Website(
                id: "1",
                name: "Test Website",
                domain: "test.de",
                shareId: nil,
            teamId: nil,
                resetAt: nil,
                createdAt: nil
            )
        )
    }
}
