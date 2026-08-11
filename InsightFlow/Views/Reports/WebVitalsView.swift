import SwiftUI
import Charts

struct WebVitalsView: View {
    let website: Website

    @StateObject private var viewModel: WebVitalsViewModel
    @AppStorage("webvitals.dateRangePreset") private var storedPreset: String = DateRangePreset.last30Days.rawValue

    private var selectedDateRange: DateRange {
        DateRange(preset: DateRangePreset(rawValue: storedPreset) ?? .last30Days)
    }

    /// Ladezeiten kommen aus Umami v3 — bei Plausible erscheint ein Hinweis
    /// statt eines Fehlers.
    private var isPlausible: Bool {
        AnalyticsManager.shared.providerType == .plausible
    }

    init(website: Website) {
        self.website = website
        _viewModel = StateObject(wrappedValue: WebVitalsViewModel(websiteId: website.id))
    }

    private var unsupportedCard: some View {
        ContentUnavailableView(
            String(localized: "webvitals.unsupported"),
            systemImage: "speedometer",
            description: Text(String(localized: "webvitals.unsupported.description"))
        )
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

                metricPicker

                explanationCard

                if viewModel.isLoading {
                    ProgressView(String(localized: "webvitals.loading"))
                        .padding(40)
                } else if !viewModel.hasData {
                    ContentUnavailableView(
                        String(localized: "webvitals.empty"),
                        systemImage: "speedometer",
                        description: Text(String(localized: "webvitals.empty.description"))
                    )
                } else {
                    ratingCard
                    percentileCards
                    performanceChart

                    if !viewModel.topPages.isEmpty {
                        pagesTable
                    }

                    thresholdLegend
                }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(String(localized: "webvitals.title"))
        .navigationBarTitleDisplayMode(.large)
        .task {
            guard !isPlausible else { return }
            await viewModel.load(dateRange: selectedDateRange)
        }
        .onChange(of: storedPreset) { _, _ in
            guard !isPlausible else { return }
            Task { await viewModel.load(dateRange: selectedDateRange) }
        }
        .onChange(of: viewModel.selectedMetric) { _, _ in
            guard !isPlausible else { return }
            Task { await viewModel.load(dateRange: selectedDateRange) }
        }
        .refreshable {
            guard !isPlausible else { return }
            await viewModel.load(dateRange: selectedDateRange)
        }
    }

    // MARK: - Banner

    private var offlineBanner: some View {
        ReportOfflineBanner(message: String(localized: "webvitals.offline"))
    }

    private func errorBanner(_ message: String) -> some View {
        ReportErrorBanner(title: String(localized: "webvitals.error"), message: message)
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

    private var metricPicker: some View {
        Picker(String(localized: "webvitals.metric.picker"), selection: $viewModel.selectedMetric) {
            ForEach(UmamiWebVitalMetric.allCases, id: \.self) { metric in
                Text(metric.shortName).tag(metric)
            }
        }
        .pickerStyle(.segmented)
    }

    private var explanationCard: some View {
        GlassCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.selectedMetric.localizedName)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(viewModel.selectedMetric.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Bewertung

    @ViewBuilder
    private var ratingCard: some View {
        if let percentiles = viewModel.percentiles, let rating = viewModel.rating {
            GlassCard {
                VStack(spacing: 16) {
                    HStack(spacing: 10) {
                        Image(systemName: rating.symbolName)
                            .font(.title2)
                            .foregroundStyle(rating.color)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(rating.localizedName)
                                .font(.headline)
                                .foregroundStyle(rating.color)
                            Text(String(localized: "webvitals.rating.basis"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 8)

                        Text(viewModel.selectedMetric.formattedValue(percentiles.p75))
                            .font(.title2)
                            .fontWeight(.bold)
                            .monospacedDigit()
                            .foregroundStyle(rating.color)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }

                    WebVitalThresholdBar(metric: viewModel.selectedMetric, value: percentiles.p75)

                    if viewModel.sampleCount > 0 {
                        HStack {
                            Image(systemName: "waveform.path.ecg")
                                .font(.caption2)
                            Text(String(localized: "webvitals.samples \(viewModel.sampleCount)"))
                                .font(.caption2)
                            Spacer()
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var percentileCards: some View {
        if let percentiles = viewModel.percentiles {
            HStack(alignment: .top, spacing: 12) {
                WebVitalPercentileCard(
                    title: String(localized: "webvitals.percentile.p50"),
                    subtitle: String(localized: "webvitals.percentile.p50.hint"),
                    value: viewModel.selectedMetric.formattedValue(percentiles.p50),
                    color: viewModel.selectedMetric.rating(for: percentiles.p50).color
                )

                WebVitalPercentileCard(
                    title: String(localized: "webvitals.percentile.p75"),
                    subtitle: String(localized: "webvitals.percentile.p75.hint"),
                    value: viewModel.selectedMetric.formattedValue(percentiles.p75),
                    color: viewModel.selectedMetric.rating(for: percentiles.p75).color,
                    isHighlighted: true
                )

                WebVitalPercentileCard(
                    title: String(localized: "webvitals.percentile.p95"),
                    subtitle: String(localized: "webvitals.percentile.p95.hint"),
                    value: viewModel.selectedMetric.formattedValue(percentiles.p95),
                    color: viewModel.selectedMetric.rating(for: percentiles.p95).color
                )
            }
            // Gleiche Kartenhöhe, auch wenn die Hinweistexte unterschiedlich
            // lang umbrechen (relevant bei großer Schrift).
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Chart

    @ViewBuilder
    private var performanceChart: some View {
        let points = viewModel.chartPoints
        let metric = viewModel.selectedMetric

        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "webvitals.chart.title"))
                        .font(.headline)
                    Text(String(localized: "webvitals.chart.subtitle"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if points.isEmpty {
                    Text(String(localized: "webvitals.chart.empty"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    Chart {
                        RuleMark(y: .value(String(localized: "webvitals.threshold.good"), metric.goodThreshold))
                            .foregroundStyle(.green.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                        RuleMark(y: .value(String(localized: "webvitals.threshold.poor"), metric.poorThreshold))
                            .foregroundStyle(.red.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                        ForEach(points) { point in
                            AreaMark(
                                x: .value("Datum", point.date),
                                yStart: .value("p50", point.p50),
                                yEnd: .value("p95", point.p95)
                            )
                            .foregroundStyle(.blue.opacity(0.12))
                            .interpolationMethod(.catmullRom)
                        }

                        ForEach(points) { point in
                            LineMark(
                                x: .value("Datum", point.date),
                                y: .value("p75", point.p75)
                            )
                            .foregroundStyle(metric.rating(for: point.p75).color)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("Datum", point.date),
                                y: .value("p75", point.p75)
                            )
                            .foregroundStyle(metric.rating(for: point.p75).color)
                            .symbolSize(points.count > 30 ? 0 : 22)
                        }
                    }
                    .chartYScale(domain: 0...viewModel.chartUpperBound)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let raw = value.as(Double.self) {
                                    Text(metric.axisLabel(raw))
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(preset: .aligned) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        }
                    }
                    .frame(height: 220)

                    HStack(spacing: 14) {
                        WebVitalLegendDot(color: .blue.opacity(0.35), label: String(localized: "webvitals.chart.range"))
                        WebVitalLegendDot(color: .secondary, label: String(localized: "webvitals.chart.median"))
                        Spacer()
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Seiten

    private var pagesTable: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "webvitals.pages.title"))
                        .font(.headline)
                    Text(String(localized: "webvitals.pages.subtitle"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 0) {
                    HStack {
                        Text(String(localized: "webvitals.pages.page"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(String(localized: "webvitals.percentile.p75"))
                            .frame(width: 80, alignment: .trailing)
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    ForEach(viewModel.topPages) { page in
                        HStack {
                            Text(page.name ?? "—")
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack(spacing: 6) {
                                Circle()
                                    .fill(viewModel.selectedMetric.rating(for: page.p75).color)
                                    .frame(width: 7, height: 7)

                                Text(viewModel.selectedMetric.formattedValue(page.p75))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .monospacedDigit()
                                    .foregroundStyle(viewModel.selectedMetric.rating(for: page.p75).color)
                            }
                            .frame(width: 80, alignment: .trailing)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 8)

                        if page.id != viewModel.topPages.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Legende der Schwellwerte

    private var thresholdLegend: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "webvitals.thresholds.title"))
                    .font(.headline)

                let metric = viewModel.selectedMetric

                WebVitalThresholdRow(
                    color: .green,
                    label: String(localized: "webvitals.rating.good"),
                    value: String(localized: "webvitals.threshold.upTo \(metric.formattedValue(metric.goodThreshold))")
                )
                WebVitalThresholdRow(
                    color: .orange,
                    label: String(localized: "webvitals.rating.needsImprovement"),
                    value: String(
                        localized: "webvitals.threshold.between \(metric.formattedValue(metric.goodThreshold)) \(metric.formattedValue(metric.poorThreshold))"
                    )
                )
                WebVitalThresholdRow(
                    color: .red,
                    label: String(localized: "webvitals.rating.poor"),
                    value: String(localized: "webvitals.threshold.above \(metric.formattedValue(metric.poorThreshold))")
                )

                Text(String(localized: "webvitals.thresholds.note"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Gemeinsame Banner der Report-Ansichten

/// Hinweis auf fehlende Verbindung — einheitlich in Web Vitals, Umsatz und
/// Besuchszeiten, damit die Reports sich wie eine Ansicht anfühlen.
struct ReportOfflineBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.subheadline)
            Text(message)
                .font(.subheadline)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.15))
        .foregroundStyle(.orange)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// Fehlerhinweis in denselben Maßen wie der Offline-Banner.
struct ReportErrorBanner: View {
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.12))
        .foregroundStyle(.red)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Bausteine

struct WebVitalPercentileCard: View {
    let title: String
    let subtitle: String
    let value: String
    let color: Color
    var isHighlighted: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isHighlighted ? color.opacity(0.6) : .clear, lineWidth: 1.5)
        )
    }
}

/// Farbskala gut/verbesserungswürdig/schlecht mit Marker für den aktuellen Wert.
struct WebVitalThresholdBar: View {
    let metric: UmamiWebVitalMetric
    let value: Double

    private var upperBound: Double {
        max(metric.poorThreshold * 1.5, value * 1.1)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let goodWidth = width * CGFloat(metric.goodThreshold / upperBound)
            let poorStart = width * CGFloat(metric.poorThreshold / upperBound)
            let markerX = min(width, width * CGFloat(min(value, upperBound) / upperBound))

            ZStack(alignment: .leading) {
                HStack(spacing: 2) {
                    Rectangle()
                        .fill(Color.green.opacity(0.75))
                        .frame(width: max(0, goodWidth - 2))
                    Rectangle()
                        .fill(Color.orange.opacity(0.75))
                        .frame(width: max(0, poorStart - goodWidth - 2))
                    Rectangle()
                        .fill(Color.red.opacity(0.75))
                }
                .clipShape(Capsule())

                Capsule()
                    .fill(Color(.systemBackground))
                    .frame(width: 4, height: 16)
                    .overlay(Capsule().stroke(Color.primary.opacity(0.7), lineWidth: 1))
                    .offset(x: max(0, markerX - 2))
            }
        }
        .frame(height: 16)
    }
}

struct WebVitalThresholdRow: View {
    let color: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 12, height: 12)

            Text(label)
                .font(.subheadline)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

struct WebVitalLegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
        }
    }
}

#Preview {
    NavigationStack {
        WebVitalsView(
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
