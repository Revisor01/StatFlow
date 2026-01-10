import SwiftUI
import Charts

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let containerWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > containerWidth && currentX > 0 {
                // Move to next line
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalHeight = currentY + lineHeight
        }

        return CGSize(width: containerWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                // Move to next line
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))

            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }
    }
}

struct WebsiteCard: View {
    let website: Website
    let stats: WebsiteStats?
    let activeVisitors: Int
    let sparklineData: [TimeSeriesPoint]
    var onShareLinkUpdated: ((Website) -> Void)? = nil
    var onRemoveSite: (() -> Void)? = nil
    var isUmamiProvider: Bool = true
    var isHourlyData: Bool = false

    @State private var showTrackingCode = false
    @State private var showShareSheet = false
    @State private var showDeleteConfirmation = false
    @ObservedObject private var settingsManager = DashboardSettingsManager.shared

    private var serverURL: String {
        KeychainService.load(for: .serverURL) ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection

            if let stats = stats {
                statsSection(stats)
            } else {
                loadingSection
            }

            if settingsManager.showGraph && sparklineData.contains(where: { $0.value > 0 }) {
                sparklineSection
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contextMenu {
            // Tracking Code für beide Provider
            Button {
                showTrackingCode = true
            } label: {
                Label(String(localized: "admin.websites.trackingCode"), systemImage: "doc.text")
            }

            // Share Link nur für Umami
            if isUmamiProvider {
                Button {
                    showShareSheet = true
                } label: {
                    Label(website.shareId != nil ? String(localized: "admin.websites.shareLink.copy") : String(localized: "admin.websites.shareLink.create"), systemImage: "square.and.arrow.up")
                }
            }

            // Website löschen für beide Provider
            if onRemoveSite != nil {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label(String(localized: "dashboard.removeSite"), systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showTrackingCode) {
            DashboardTrackingCodeSheet(website: website, serverURL: serverURL)
        }
        .sheet(isPresented: $showShareSheet) {
            DashboardShareLinkSheet(website: website, serverURL: serverURL, onUpdated: onShareLinkUpdated)
        }
        .alert(
            String(localized: "dashboard.removeSite.confirm.title"),
            isPresented: $showDeleteConfirmation
        ) {
            Button(String(localized: "button.cancel"), role: .cancel) {}
            Button(String(localized: "button.delete"), role: .destructive) {
                onRemoveSite?()
            }
        } message: {
            Text(isUmamiProvider
                ? String(localized: "dashboard.removeSite.confirm.umami")
                : String(localized: "dashboard.removeSite.confirm.plausible"))
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(website.name)
                    .font(.headline)
                    .fontWeight(.semibold)

                if let domain = website.domain, let url = URL(string: "https://\(domain)") {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Text(website.displayDomain)
                            Image(systemName: "arrow.up.forward")
                                .font(.caption2)
                        }
                        .font(.caption)
                        .foregroundStyle(.blue)
                    }
                } else {
                    Text(website.displayDomain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            LiveIndicator(count: activeVisitors)
        }
    }

    private func statsSection(_ stats: WebsiteStats) -> some View {
        // Alle aktivierten Metriken sammeln
        let enabledMetrics = DashboardMetric.allCases.filter { settingsManager.isEnabled($0) }

        // Flexibles Layout mit FlowLayout-Verhalten
        return FlowLayout(spacing: 16) {
            ForEach(enabledMetrics) { metric in
                statItemView(for: metric, stats: stats)
            }
        }
    }

    @ViewBuilder
    private func statItemView(for metric: DashboardMetric, stats: WebsiteStats) -> some View {
        switch metric {
        case .visitors:
            StatItem(
                icon: metric.icon,
                iconColor: metric.iconColor,
                value: stats.visitors.value,
                label: String(localized: "dashboard.visitors"),
                change: stats.visitors.change,
                changePercentage: stats.visitors.changePercentage
            )
        case .pageviews:
            StatItem(
                icon: metric.icon,
                iconColor: metric.iconColor,
                value: stats.pageviews.value,
                label: String(localized: "dashboard.pageviews"),
                change: stats.pageviews.change,
                changePercentage: stats.pageviews.changePercentage
            )
        case .visits:
            StatItem(
                icon: metric.icon,
                iconColor: metric.iconColor,
                value: stats.visits.value,
                label: String(localized: "dashboard.visits"),
                change: stats.visits.change,
                changePercentage: stats.visits.changePercentage
            )
        case .bounceRate:
            StatItem(
                icon: metric.icon,
                iconColor: metric.iconColor,
                formattedValue: formatBounceRate(stats.bounces.value, visits: stats.visits.value),
                label: String(localized: "dashboard.bounceRate"),
                change: stats.bounces.change,
                changePercentage: stats.bounces.changePercentage
            )
        case .duration:
            StatItem(
                icon: metric.icon,
                iconColor: metric.iconColor,
                formattedValue: formatDuration(stats.totaltime.value, visits: stats.visits.value),
                label: String(localized: "dashboard.duration"),
                change: stats.totaltime.change,
                changePercentage: stats.totaltime.changePercentage
            )
        }
    }

    private func formatBounceRate(_ bounces: Int, visits: Int) -> String {
        guard visits > 0 else { return "0%" }
        let rate = Double(bounces) / Double(visits) * 100
        return String(format: "%.0f%%", rate)
    }

    private func formatDuration(_ totalTime: Int, visits: Int) -> String {
        guard visits > 0 else { return "0:00" }
        let avgSeconds = totalTime / visits
        let minutes = avgSeconds / 60
        let seconds = avgSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var loadingSection: some View {
        HStack(spacing: 24) {
            ForEach(0..<3, id: \.self) { _ in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                        .frame(width: 50, height: 24)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                        .frame(width: 40, height: 12)
                }
            }
        }
        .redacted(reason: .placeholder)
    }

    @ViewBuilder
    private var sparklineSection: some View {
        if settingsManager.chartStyle == .bar {
            barSparkline
        } else {
            lineSparkline
        }
    }

    private var sparklineXAxisValues: [Date] {
        guard sparklineData.count > 1 else { return [] }
        let dates = sparklineData.map { $0.date }.sorted()
        guard let first = dates.first, let last = dates.last else { return [] }

        // Zeige Start, Mitte und Ende
        let middle = dates[dates.count / 2]
        return [first, middle, last]
    }

    private var lineSparkline: some View {
        Chart {
            ForEach(sparklineData) { point in
                LineMark(
                    x: .value("Datum", point.date),
                    y: .value("Aufrufe", point.value)
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.monotone)

                AreaMark(
                    x: .value("Datum", point.date),
                    y: .value("Aufrufe", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue.opacity(0.3), .blue.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)
            }
        }
        .chartXAxis {
            AxisMarks(values: sparklineXAxisValues) { _ in
                AxisValueLabel(format: .dateTime.hour().minute())
                    .font(.caption2)
            }
        }
        .chartYAxis(.hidden)
        .chartYScale(domain: .automatic(includesZero: true))
        .frame(maxWidth: .infinity)
        .frame(height: 70)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "accessibility.chart.pageviews"))
    }

    private var barSparkline: some View {
        Chart {
            // X-Achsen-Basislinie für Orientierung
            RuleMark(y: .value("Baseline", 0))
                .foregroundStyle(.gray.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 1))

            ForEach(sparklineData) { point in
                BarMark(
                    x: .value("Datum", point.date, unit: isHourlyData ? .hour : .day),
                    y: .value("Aufrufe", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(2)
            }
        }
        .chartXAxis {
            AxisMarks(values: sparklineXAxisValues) { _ in
                if isHourlyData {
                    AxisValueLabel(format: .dateTime.hour().minute())
                        .font(.caption2)
                } else {
                    AxisValueLabel(format: .dateTime.day().month())
                        .font(.caption2)
                }
            }
        }
        .chartYAxis(.hidden)
        .frame(maxWidth: .infinity)
        .frame(height: 70)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "accessibility.chart.pageviews"))
    }
}

struct LiveIndicator: View {
    let count: Int

    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(.green.opacity(0.5), lineWidth: 2)
                        .scaleEffect(isAnimating ? 2 : 1)
                        .opacity(isAnimating ? 0 : 1)
                )
                .onAppear {
                    withAnimation(.easeOut(duration: 1).repeatForever(autoreverses: false)) {
                        isAnimating = true
                    }
                }

            Text("\(count)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.green.opacity(0.15))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "accessibility.liveVisitors \(count)"))
    }
}

struct StatItem: View {
    var icon: String? = nil
    var iconColor: Color = .primary
    var value: Int = 0
    var formattedValue: String? = nil
    let label: String
    let change: Int
    var changePercentage: Double = 0

    private var changeColor: Color {
        if change > 0 { return .green }
        if change < 0 { return .red }
        return .secondary
    }

    private var formattedPercentageText: String {
        if change > 0 { return "+\(String(format: "%.0f", changePercentage))%" }
        if change < 0 { return "\(String(format: "%.0f", changePercentage))%" }
        return "0%"
    }

    private var displayValue: String {
        formattedValue ?? value.formatted()
    }

    var body: some View {
        HStack(spacing: 6) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(displayValue)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text(formattedPercentageText)
                        .font(.caption2)
                        .foregroundStyle(changeColor)
                }

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Dashboard Tracking Code Sheet

struct DashboardTrackingCodeSheet: View {
    let website: Website
    let serverURL: String
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var trackingCode: String {
        """
        <script defer src="\(serverURL)/script.js" data-website-id="\(website.id)"></script>
        """
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(String(localized: "admin.websites.trackingCode.description"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(trackingCode)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button {
                        UIPasteboard.general.string = trackingCode
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copied = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            Text(copied ? String(localized: "button.copied") : String(localized: "admin.websites.trackingCode.copy"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(copied ? Color.green : Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .navigationTitle(String(localized: "admin.websites.trackingCode"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "button.done")) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Dashboard Share Link Sheet

struct DashboardShareLinkSheet: View {
    let website: Website
    let serverURL: String
    var onUpdated: ((Website) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var shareId: String
    @State private var isShareEnabled: Bool
    @State private var copied = false
    @State private var isUpdating = false

    private let api = UmamiAPI.shared

    init(website: Website, serverURL: String, onUpdated: ((Website) -> Void)? = nil) {
        self.website = website
        self.serverURL = serverURL
        self.onUpdated = onUpdated
        _shareId = State(initialValue: website.shareId ?? StringUtils.generateShareId())
        _isShareEnabled = State(initialValue: website.shareId != nil)
    }

    var shareURL: String {
        "\(serverURL)/share/\(shareId)/\(website.displayDomain)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(String(localized: "admin.websites.shareLink.enabled"), isOn: $isShareEnabled)
                        .disabled(isUpdating)
                        .onChange(of: isShareEnabled) { _, newValue in
                            Task {
                                isUpdating = true
                                do {
                                    let updated: Website
                                    if newValue {
                                        // Enable share link
                                        updated = try await api.updateWebsite(websiteId: website.id, shareId: shareId)
                                    } else {
                                        // Disable share link
                                        updated = try await api.updateWebsite(websiteId: website.id, clearShareId: true)
                                    }
                                    onUpdated?(updated)
                                } catch {
                                    // Revert toggle on error
                                    isShareEnabled = !newValue
                                    print("Share link error: \(error)")
                                }
                                isUpdating = false
                            }
                        }
                } footer: {
                    Text(String(localized: "admin.websites.shareLink.description"))
                }

                if isShareEnabled {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "admin.websites.shareLink.id"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("ShareID", text: $shareId)
                                .textInputAutocapitalization(.never)
                                .font(.system(.body, design: .monospaced))
                        }
                    } footer: {
                        if shareId.count < 8 {
                            Text(String(localized: "admin.websites.shareLink.minLength"))
                                .foregroundStyle(.red)
                        }
                    }

                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(String(localized: "admin.websites.shareLink.existing"))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(shareURL)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)

                            Button {
                                UIPasteboard.general.string = shareURL
                                copied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    copied = false
                                }
                            } label: {
                                HStack {
                                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                    Text(copied ? String(localized: "button.copied") : String(localized: "admin.websites.shareLink.copy"))
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(copied ? .green : .blue)
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "admin.websites.shareLink"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "button.done")) { dismiss() }
                }
            }
        }
    }
}

#Preview {
    WebsiteCard(
        website: Website(
            id: "1",
            name: "Kirche Wesselburen",
            domain: "kirche-wesselburen.de",
            shareId: nil,
            teamId: nil,
            resetAt: nil,
            createdAt: nil
        ),
        stats: WebsiteStats(
            pageviews: StatValue(value: 1234, change: 123),
            visitors: StatValue(value: 456, change: 45),
            visits: StatValue(value: 567, change: -23),
            bounces: StatValue(value: 123, change: 10),
            totaltime: StatValue(value: 45000, change: 5000)
        ),
        activeVisitors: 5,
        sparklineData: []
    )
    .padding()
}
