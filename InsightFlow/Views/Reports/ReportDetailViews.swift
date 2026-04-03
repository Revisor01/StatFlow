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
    let dateRange: DateRange

    @StateObject private var viewModel: ReportsViewModel

    init(website: Website, dateRange: DateRange) {
        self.website = website
        self.dateRange = dateRange
        _viewModel = StateObject(wrappedValue: ReportsViewModel(websiteId: website.id))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading && viewModel.funnelData.isEmpty {
                    ProgressView()
                        .padding(40)
                } else if viewModel.funnelData.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        String(localized: "reports.empty.funnel"),
                        systemImage: "chart.bar.doc.horizontal",
                        description: Text(String(localized: "reports.empty.funnel.description"))
                    )
                } else {
                    funnelStepsView
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(String(localized: "reports.funnel"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadFirstFunnel(dateRange: dateRange)
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
    let dateRange: DateRange

    @StateObject private var viewModel: ReportsViewModel

    init(website: Website, dateRange: DateRange) {
        self.website = website
        self.dateRange = dateRange
        _viewModel = StateObject(wrappedValue: ReportsViewModel(websiteId: website.id))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading && viewModel.goalData.isEmpty {
                    ProgressView()
                        .padding(40)
                } else if viewModel.goalData.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        String(localized: "reports.empty.goals"),
                        systemImage: "target",
                        description: Text(String(localized: "reports.empty.goals.description"))
                    )
                } else {
                    goalItemsView
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(String(localized: "reports.goals"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadAllGoals(dateRange: dateRange)
        }
    }

    @ViewBuilder
    private var goalItemsView: some View {
        ForEach(viewModel.goalData) { item in
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "target")
                            .font(.title3)
                            .foregroundStyle(.orange)

                        Text(item.name)
                            .font(.headline)
                            .lineLimit(2)

                        Spacer()
                    }

                    HStack {
                        ProgressView(value: min(item.completionRate, 1.0))
                            .tint(item.completionRate >= 0.5 ? .green : .orange)

                        Text(String(format: "%.1f%%", item.completionRate * 100))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(item.completionRate >= 0.5 ? .green : .orange)
                            .monospacedDigit()
                            .frame(width: 52, alignment: .trailing)
                    }

                    HStack {
                        Text("\(item.result)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(String(localized: "reports.goals.of"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(item.goal)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(String(localized: "reports.goals.visitors"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal)
        }
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
