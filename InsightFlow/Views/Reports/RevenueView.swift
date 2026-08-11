import SwiftUI
import Charts

struct RevenueView: View {
    let website: Website

    @StateObject private var viewModel: RevenueViewModel
    @AppStorage("revenue.dateRangePreset") private var storedPreset: String = DateRangePreset.last30Days.rawValue
    @AppStorage("revenue.currency") private var storedCurrency: String = RevenueCurrency.eur.rawValue

    private var selectedDateRange: DateRange {
        DateRange(preset: DateRangePreset(rawValue: storedPreset) ?? .last30Days)
    }

    private var selectedCurrency: RevenueCurrency {
        RevenueCurrency(rawValue: storedCurrency) ?? .eur
    }

    /// Revenue existiert nur in Umami v3 — bei Plausible erscheint ein Hinweis
    /// statt eines Fehlers.
    private var isPlausible: Bool {
        AnalyticsManager.shared.providerType == .plausible
    }

    init(website: Website) {
        self.website = website
        _viewModel = StateObject(wrappedValue: RevenueViewModel(websiteId: website.id))
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
                    currencyPicker

                    if viewModel.isLoading {
                        ProgressView(String(localized: "revenue.loading"))
                            .padding(40)
                    } else if !viewModel.hasData {
                        emptyState
                    } else {
                        metricCards
                        revenueChart

                        if !viewModel.revenueByEvent.isEmpty {
                            eventBreakdown
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(String(localized: "revenue.title"))
        .navigationBarTitleDisplayMode(.large)
        .task {
            guard !isPlausible else { return }
            await viewModel.load(dateRange: selectedDateRange, currency: selectedCurrency)
        }
        .onChange(of: storedPreset) { _, _ in
            guard !isPlausible else { return }
            Task { await viewModel.load(dateRange: selectedDateRange, currency: selectedCurrency) }
        }
        .onChange(of: storedCurrency) { _, _ in
            guard !isPlausible else { return }
            Task { await viewModel.load(dateRange: selectedDateRange, currency: selectedCurrency) }
        }
        .refreshable {
            guard !isPlausible else { return }
            await viewModel.load(dateRange: selectedDateRange, currency: selectedCurrency)
        }
    }

    // MARK: - Zustände

    private var unsupportedCard: some View {
        ContentUnavailableView(
            String(localized: "revenue.unsupported"),
            systemImage: "creditcard.trianglebadge.exclamationmark",
            description: Text(String(localized: "revenue.unsupported.description"))
        )
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ContentUnavailableView(
                String(localized: "revenue.empty"),
                systemImage: "eurosign.circle",
                description: Text(String(localized: "revenue.empty.description"))
            )

            GlassCard {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "revenue.setup.title"))
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text(String(localized: "revenue.setup.description"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var offlineBanner: some View {
        ReportOfflineBanner(message: String(localized: "revenue.offline"))
    }

    private func errorBanner(_ message: String) -> some View {
        ReportErrorBanner(title: String(localized: "revenue.error"), message: message)
    }

    // MARK: - Auswahl

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

    private var currencyPicker: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "revenue.currency"))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Picker(String(localized: "revenue.currency"), selection: $storedCurrency) {
                    ForEach(RevenueCurrency.allCases) { currency in
                        Text("\(currency.symbol) \(currency.rawValue)")
                            .tag(currency.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                Text(String(localized: "revenue.currency.hint"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Kennzahlen

    private var metricCards: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                RevenueMetricCard(
                    title: String(localized: "revenue.sum"),
                    value: selectedCurrency.format(viewModel.stats?.sum ?? 0),
                    icon: "eurosign.circle.fill",
                    color: .green,
                    change: viewModel.change(for: \.sum, current: viewModel.stats?.sum ?? 0)
                )

                RevenueMetricCard(
                    title: String(localized: "revenue.count"),
                    value: (viewModel.stats?.count ?? 0).formatted(.number.precision(.fractionLength(0))),
                    icon: "number.circle.fill",
                    color: .blue,
                    change: viewModel.change(for: \.count, current: viewModel.stats?.count ?? 0)
                )
            }
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                RevenueMetricCard(
                    title: String(localized: "revenue.average"),
                    value: selectedCurrency.format(viewModel.stats?.average ?? 0),
                    icon: "chart.bar.fill",
                    color: .orange,
                    change: viewModel.change(for: \.average, current: viewModel.stats?.average ?? 0)
                )

                RevenueMetricCard(
                    title: String(localized: "revenue.arpu"),
                    value: selectedCurrency.format(viewModel.stats?.arpu ?? 0),
                    icon: "person.crop.circle.badge.checkmark",
                    color: .purple,
                    change: viewModel.change(for: \.arpu, current: viewModel.stats?.arpu ?? 0)
                )
            }
            .fixedSize(horizontal: false, vertical: true)

            if let unique = viewModel.stats?.uniqueCount, unique > 0 {
                GlassCard {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundStyle(.teal)
                        Text(String(localized: "revenue.uniqueCustomers"))
                            .font(.subheadline)
                        Spacer()
                        Text(unique.formatted(.number.precision(.fractionLength(0))))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    // MARK: - Verlauf

    private var revenueChart: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text(String(localized: "revenue.chart.title"))
                    .font(.headline)

                if viewModel.chartPoints.isEmpty {
                    Text(String(localized: "revenue.chart.empty"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Chart(viewModel.chartPoints) { point in
                        BarMark(
                            x: .value(String(localized: "revenue.axis.time"), point.date),
                            y: .value(String(localized: "revenue.axis.amount"), point.amount)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .green.opacity(0.55)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(3)
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let amount = value.as(Double.self) {
                                    Text(compactAmount(amount))
                                }
                            }
                        }
                    }
                    .frame(height: 220)
                }
            }
        }
    }

    private var eventBreakdown: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text(String(localized: "revenue.events.title"))
                    .font(.headline)

                let events = Array(viewModel.revenueByEvent.prefix(10))
                let maxAmount = events.first?.amount ?? 1

                VStack(spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.offset) { index, event in
                        VStack(spacing: 6) {
                            HStack {
                                Text(event.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer()
                                Text(selectedCurrency.format(event.amount))
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }

                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(.tertiarySystemGroupedBackground))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.green.opacity(0.7))
                                        .frame(width: max(2, geometry.size.width * CGFloat(maxAmount > 0 ? event.amount / maxAmount : 0)))
                                }
                            }
                            .frame(height: 6)
                        }
                        .padding(.vertical, 8)

                        if index != events.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    /// Kompakte Achsenbeschriftung: volle Währungsformatierung wäre auf der
    /// Y-Achse zu breit, deshalb die Notation-Variante.
    private func compactAmount(_ amount: Double) -> String {
        amount.formatted(
            .currency(code: selectedCurrency.rawValue)
                .notation(.compactName)
                .precision(.fractionLength(0...1))
        )
    }
}

// MARK: - Kennzahlen-Karte

struct RevenueMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let change: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Spacer()
                // Wie bei den Hero-Karten im Dashboard: ohne Veränderung
                // erscheint kein Pfeil, statt fälschlich „aufwärts“ zu zeigen.
                if let change, change != 0 {
                    changeBadge(change)
                }
            }

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

    private func changeBadge(_ change: Double) -> some View {
        let isUp = change > 0
        return HStack(spacing: 2) {
            Image(systemName: isUp ? "arrow.up" : "arrow.down")
                .font(.caption2)
            Text(String(format: "%.0f%%", abs(change)))
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(isUp ? .green : .red)
        .accessibilityLabel(
            isUp
                ? String(localized: "revenue.change.up \(String(format: "%.0f", abs(change)))")
                : String(localized: "revenue.change.down \(String(format: "%.0f", abs(change)))")
        )
    }
}

#Preview {
    NavigationStack {
        RevenueView(
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
