import SwiftUI

// MARK: - UTM Report View

struct UTMReportView: View {
    let website: Website
    let dateRange: DateRange

    @StateObject private var viewModel: ReportsViewModel

    init(website: Website, dateRange: DateRange) {
        self.website = website
        self.dateRange = dateRange
        _viewModel = StateObject(wrappedValue: ReportsViewModel(websiteId: website.id))
    }

    var sortedUTMData: [UTMReportItem] {
        viewModel.utmData.sorted {
            ($0.source ?? "") < ($1.source ?? "")
        }
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.utmData.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.utmData.isEmpty {
                ContentUnavailableView(
                    String(localized: "reports.empty.utm"),
                    systemImage: "link.badge.plus",
                    description: Text(String(localized: "reports.empty.utm.description"))
                )
            } else {
                List(sortedUTMData) { item in
                    UTMReportRow(item: item)
                }
                .listStyle(.plain)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(String(localized: "reports.utm"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadUTMReport(dateRange: dateRange)
        }
    }
}

struct UTMReportRow: View {
    let item: UTMReportItem

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if let source = item.source {
                        TagBadge(text: source, color: .blue)
                    }
                    if let medium = item.medium {
                        TagBadge(text: medium, color: .green)
                    }
                }

                if let campaign = item.campaign {
                    TagBadge(text: campaign, color: .orange)
                }
            }

            Spacer()

            Text("\(item.visitors)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Attribution Report View

struct AttributionReportView: View {
    let website: Website
    let dateRange: DateRange

    @StateObject private var viewModel: ReportsViewModel

    init(website: Website, dateRange: DateRange) {
        self.website = website
        self.dateRange = dateRange
        _viewModel = StateObject(wrappedValue: ReportsViewModel(websiteId: website.id))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.attributionData.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.attributionData.isEmpty {
                ContentUnavailableView(
                    String(localized: "reports.empty.attribution"),
                    systemImage: "point.3.filled.connected.trianglepath.dotted",
                    description: Text(String(localized: "reports.empty.attribution.description"))
                )
            } else {
                List(viewModel.attributionData) { item in
                    AttributionRow(item: item)
                }
                .listStyle(.plain)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(String(localized: "reports.attribution"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadAttributionReport(dateRange: dateRange)
        }
    }
}

struct AttributionRow: View {
    let item: AttributionItem

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if let channel = item.channel {
                    Text(channel)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                HStack(spacing: 6) {
                    if let source = item.source {
                        TagBadge(text: source, color: .blue)
                    }
                    if let medium = item.medium {
                        TagBadge(text: medium, color: .purple)
                    }
                }
            }

            Spacer()

            Text("\(item.visitors)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Funnel Report View

struct FunnelReportView: View {
    let website: Website
    let reports: [Report]
    let dateRange: DateRange

    @StateObject private var viewModel: ReportsViewModel
    @State private var selectedReport: Report?

    init(website: Website, reports: [Report], dateRange: DateRange) {
        self.website = website
        self.reports = reports
        self.dateRange = dateRange
        _viewModel = StateObject(wrappedValue: ReportsViewModel(websiteId: website.id))
    }

    var body: some View {
        Group {
            if reports.isEmpty {
                ContentUnavailableView(
                    String(localized: "reports.empty.funnel"),
                    systemImage: "chart.bar.doc.horizontal",
                    description: Text(String(localized: "reports.empty.funnel.description"))
                )
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Report picker
                        if reports.count > 1 {
                            GlassCard {
                                Picker(String(localized: "reports.selectReport"), selection: $selectedReport) {
                                    ForEach(reports) { report in
                                        Text(report.name).tag(Optional(report))
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            .padding(.horizontal)
                        }

                        // Funnel steps
                        if viewModel.isLoading && viewModel.funnelData.isEmpty {
                            ProgressView()
                                .padding(40)
                        } else if viewModel.funnelData.isEmpty {
                            GlassCard {
                                Text(String(localized: "reports.empty.funnel.description"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding()
                            }
                            .padding(.horizontal)
                        } else {
                            funnelStepsView
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(String(localized: "reports.funnel"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedReport = reports.first
        }
        .onChange(of: selectedReport) { _, newReport in
            guard let report = newReport else { return }
            Task {
                await viewModel.loadFunnelReport(report: report, dateRange: dateRange)
            }
        }
    }

    @ViewBuilder
    private var funnelStepsView: some View {
        let maxVisitors = viewModel.funnelData.map(\.visitors).max() ?? 1

        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(viewModel.funnelData.enumerated()), id: \.element.id) { index, step in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(step.value)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(step.visitors) \(String(localized: "reports.funnel.visitors"))")
                                    .font(.caption)
                                    .fontWeight(.semibold)

                                if index > 0 && step.dropoff > 0 {
                                    Text("-\(Int(step.dropoffRate * 100))% \(String(localized: "reports.funnel.dropoff"))")
                                        .font(.caption2)
                                        .foregroundStyle(.red)
                                }
                            }
                        }

                        // Bar
                        GeometryReader { geo in
                            let width = maxVisitors > 0
                                ? geo.size.width * CGFloat(step.visitors) / CGFloat(maxVisitors)
                                : 0
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue.opacity(0.2))
                                .frame(maxWidth: .infinity)
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.blue)
                                        .frame(width: max(4, width))
                                }
                        }
                        .frame(height: 8)
                    }

                    if index < viewModel.funnelData.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Goal Report View

struct GoalReportView: View {
    let website: Website
    let reports: [Report]
    let dateRange: DateRange

    @StateObject private var viewModel: ReportsViewModel
    @State private var selectedReport: Report?

    init(website: Website, reports: [Report], dateRange: DateRange) {
        self.website = website
        self.reports = reports
        self.dateRange = dateRange
        _viewModel = StateObject(wrappedValue: ReportsViewModel(websiteId: website.id))
    }

    var body: some View {
        Group {
            if reports.isEmpty {
                ContentUnavailableView(
                    String(localized: "reports.empty.goals"),
                    systemImage: "target",
                    description: Text(String(localized: "reports.empty.goals.description"))
                )
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Report picker
                        if reports.count > 1 {
                            GlassCard {
                                Picker(String(localized: "reports.selectReport"), selection: $selectedReport) {
                                    ForEach(reports) { report in
                                        Text(report.name).tag(Optional(report))
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            .padding(.horizontal)
                        }

                        // Goal items
                        if viewModel.isLoading && viewModel.goalData.isEmpty {
                            ProgressView()
                                .padding(40)
                        } else if viewModel.goalData.isEmpty {
                            GlassCard {
                                Text(String(localized: "reports.empty.goals.description"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding()
                            }
                            .padding(.horizontal)
                        } else {
                            goalItemsView
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(String(localized: "reports.goals"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedReport = reports.first
        }
        .onChange(of: selectedReport) { _, newReport in
            guard let report = newReport else { return }
            Task {
                await viewModel.loadGoalReport(report: report, dateRange: dateRange)
            }
        }
    }

    @ViewBuilder
    private var goalItemsView: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(viewModel.goalData) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(item.value)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)

                            Spacer()

                            Text("\(item.result)/\(item.goal)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }

                        HStack {
                            ProgressView(value: min(item.completionRate, 1.0))
                                .tint(item.completionRate >= 1.0 ? .green : .orange)

                            Text(String(format: "%.0f%%", item.completionRate * 100))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(item.completionRate >= 1.0 ? .green : .orange)
                                .frame(width: 36, alignment: .trailing)
                        }

                        Text(String(localized: "reports.goals.completion"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if item.id != viewModel.goalData.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Shared Helper Views

struct TagBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
