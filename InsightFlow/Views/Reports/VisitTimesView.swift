import SwiftUI

struct VisitTimesView: View {
    let website: Website

    @StateObject private var viewModel: VisitTimesViewModel
    @AppStorage("visittimes.dateRangePreset") private var storedPreset: String = DateRangePreset.last30Days.rawValue

    /// Breite der Wochentags-Spalte links neben der Heatmap.
    private let labelWidth: CGFloat = 34
    /// Kleinste noch lesbare Zellbreite — darunter wird horizontal gescrollt
    /// statt die Zellen zu quetschen.
    private let minimumCellSize: CGFloat = 13
    private let cellSpacing: CGFloat = 2

    private var selectedDateRange: DateRange {
        DateRange(preset: DateRangePreset(rawValue: storedPreset) ?? .last30Days)
    }

    /// Besuchszeiten kommen aus Umami v3 — bei Plausible erscheint ein Hinweis
    /// statt eines Fehlers.
    private var isPlausible: Bool {
        AnalyticsManager.shared.providerType == .plausible
    }

    init(website: Website) {
        self.website = website
        _viewModel = StateObject(wrappedValue: VisitTimesViewModel(websiteId: website.id))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isPlausible {
                    unsupportedCard
                } else {
                    if viewModel.isOffline {
                        offlineBanner
                    }

                    if let error = viewModel.error {
                        errorBanner(error)
                    }

                    dateRangePicker

                    if viewModel.isLoading {
                        ProgressView(String(localized: "visittimes.loading"))
                            .padding(40)
                    } else if !viewModel.hasData {
                        ContentUnavailableView(
                            String(localized: "visittimes.empty"),
                            systemImage: "clock.badge.questionmark",
                            description: Text(String(localized: "visittimes.empty.description"))
                        )
                    } else {
                        statsCards
                        heatmapCard
                        hourDistribution
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(String(localized: "visittimes.title"))
        .navigationBarTitleDisplayMode(.large)
        .task {
            guard !isPlausible else { return }
            await viewModel.load(dateRange: selectedDateRange)
        }
        .onChange(of: storedPreset) { _, _ in
            guard !isPlausible else { return }
            Task { await viewModel.load(dateRange: selectedDateRange) }
        }
        .refreshable {
            guard !isPlausible else { return }
            await viewModel.load(dateRange: selectedDateRange)
        }
    }

    // MARK: - Zustände

    private var unsupportedCard: some View {
        ContentUnavailableView(
            String(localized: "visittimes.unsupported"),
            systemImage: "clock.badge.exclamationmark",
            description: Text(String(localized: "visittimes.unsupported.description"))
        )
    }

    private var offlineBanner: some View {
        ReportOfflineBanner(message: String(localized: "visittimes.offline"))
    }

    private func errorBanner(_ message: String) -> some View {
        ReportErrorBanner(title: String(localized: "visittimes.error"), message: message)
    }

    private var dateRangePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach([DateRange.last7Days, .last30Days, .thisMonth, .lastMonth], id: \.preset) { range in
                    DateRangeChip(
                        title: range.displayName,
                        isSelected: selectedDateRange.preset == range.preset
                    ) {
                        withAnimation(.spring(duration: 0.3)) {
                            storedPreset = range.preset.rawValue
                        }
                    }
                }
            }
            .padding(.horizontal, 1)
        }
    }

    // MARK: - Kennzahlen

    private var statsCards: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                VisitTimesStatCard(
                    title: String(localized: "visittimes.visits"),
                    value: (viewModel.sessionStats?.visitCount ?? 0).formatted(.number),
                    icon: "figure.walk",
                    color: .blue
                )
                VisitTimesStatCard(
                    title: String(localized: "visittimes.visitors"),
                    value: (viewModel.sessionStats?.visitorCount ?? 0).formatted(.number),
                    icon: "person.2.fill",
                    color: .green
                )
            }
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                VisitTimesStatCard(
                    title: String(localized: "visittimes.pageviews"),
                    value: (viewModel.sessionStats?.pageviewCount ?? 0).formatted(.number),
                    icon: "doc.text.fill",
                    color: .orange
                )
                VisitTimesStatCard(
                    title: String(localized: "visittimes.countries"),
                    value: (viewModel.sessionStats?.countryCount ?? 0).formatted(.number),
                    icon: "globe.europe.africa.fill",
                    color: .purple
                )
            }
            .fixedSize(horizontal: false, vertical: true)

            if let peak = viewModel.peak, peak.value > 0 {
                GlassCard {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.title3)
                            .foregroundStyle(.yellow)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "visittimes.peak"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(peak.row.label), \(VisitTimesViewModel.hourLabel(peak.hour))")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }

                        Spacer()

                        Text(peak.value.formatted(.number))
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                }
            }
        }
    }

    // MARK: - Heatmap

    private var heatmapCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "visittimes.heatmap.title"))
                        .font(.headline)
                    Text(String(localized: "visittimes.heatmap.subtitle"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                GeometryReader { geometry in
                    let available = geometry.size.width - labelWidth - 6
                    let fittedSize = (available - cellSpacing * 23) / 24
                    let cellSize = max(minimumCellSize, fittedSize)
                    let needsScrolling = fittedSize < minimumCellSize

                    Group {
                        if needsScrolling {
                            ScrollView(.horizontal, showsIndicators: true) {
                                heatmapGrid(cellSize: cellSize)
                            }
                        } else {
                            heatmapGrid(cellSize: cellSize)
                        }
                    }
                }
                .frame(height: heatmapHeight)

                legend
            }
        }
    }

    /// Höhe der Heatmap: 7 Zeilen plus Stundenachse. Die Zellhöhe ist fix, damit
    /// die Karte bei horizontalem Scrollen nicht springt.
    private var heatmapHeight: CGFloat {
        7 * (minimumCellSize + cellSpacing) + 18
    }

    private func heatmapGrid(cellSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: cellSpacing) {
            ForEach(viewModel.rows) { row in
                HStack(spacing: cellSpacing) {
                    Text(row.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: labelWidth, alignment: .leading)

                    ForEach(Array(row.hours.enumerated()), id: \.offset) { hour, value in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(cellColor(value))
                            .frame(width: cellSize, height: minimumCellSize)
                            .accessibilityLabel(
                                String(localized: "visittimes.cell.accessibility \(row.label) \(VisitTimesViewModel.hourLabel(hour)) \(value)")
                            )
                    }
                }
            }

            // Stundenachse — beschriftet werden nur 0/6/12/18, sonst wird es eng.
            HStack(spacing: cellSpacing) {
                Spacer()
                    .frame(width: labelWidth)

                ForEach(0..<24, id: \.self) { hour in
                    Group {
                        if hour % 6 == 0 {
                            Text(VisitTimesViewModel.hourLabel(hour))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize()
                                .frame(width: cellSize, alignment: .leading)
                        } else {
                            Color.clear.frame(width: cellSize, height: 1)
                        }
                    }
                }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 8) {
            Text(String(localized: "visittimes.legend.less"))
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 2) {
                ForEach([0.08, 0.3, 0.5, 0.75, 1.0], id: \.self) { intensity in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor.opacity(intensity))
                        .frame(width: 14, height: 10)
                }
            }

            Text(String(localized: "visittimes.legend.more"))
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            Text(String(localized: "visittimes.legend.max \(viewModel.maxValue)"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    /// Farbintensität relativ zum Maximalwert. Die Wurzel-Skalierung sorgt
    /// dafür, dass auch schwache Stunden noch sichtbar bleiben.
    private func cellColor(_ value: Int) -> Color {
        let maxValue = viewModel.maxValue
        guard maxValue > 0, value > 0 else {
            return Color(.tertiarySystemGroupedBackground)
        }
        let ratio = Double(value) / Double(maxValue)
        let intensity = 0.12 + 0.88 * sqrt(ratio)
        return Color.accentColor.opacity(intensity)
    }

    // MARK: - Stundenverteilung

    private var hourDistribution: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text(String(localized: "visittimes.hours.title"))
                    .font(.headline)

                let totals = viewModel.hourTotals
                let maxTotal = totals.max() ?? 0

                GeometryReader { geometry in
                    let barWidth = max(4, (geometry.size.width - CGFloat(23) * 3) / 24)

                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(Array(totals.enumerated()), id: \.offset) { hour, total in
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.accentColor.opacity(hour == peakHour ? 1.0 : 0.55))
                                    .frame(
                                        width: barWidth,
                                        height: maxTotal > 0 ? max(2, 80 * CGFloat(total) / CGFloat(maxTotal)) : 2
                                    )

                                if hour % 6 == 0 {
                                    Text("\(hour)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .fixedSize()
                                } else {
                                    Color.clear.frame(height: 10)
                                }
                            }
                            .frame(maxHeight: .infinity, alignment: .bottom)
                        }
                    }
                }
                .frame(height: 100)

                Text(String(localized: "visittimes.hours.subtitle"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var peakHour: Int? {
        let totals = viewModel.hourTotals
        guard let maxTotal = totals.max(), maxTotal > 0 else { return nil }
        return totals.firstIndex(of: maxTotal)
    }
}

// MARK: - Kennzahlen-Karte

struct VisitTimesStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    NavigationStack {
        VisitTimesView(
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
