import SwiftUI

struct ReportsHubView: View {
    let website: Website

    @StateObject private var viewModel: ReportsViewModel
    @State private var selectedDateRange: DateRange = .thisMonth

    init(website: Website) {
        self.website = website
        _viewModel = StateObject(wrappedValue: ReportsViewModel(websiteId: website.id))
    }

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.subheadline)
            Text("detail.offline")
                .font(.subheadline)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.15))
        .foregroundStyle(.orange)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if viewModel.isOffline {
                    offlineBanner
                        .padding(.horizontal)
                }

                LazyVGrid(columns: columns, spacing: 16) {
                NavigationLink {
                    FunnelReportView(
                        website: website,
                        dateRange: selectedDateRange
                    )
                } label: {
                    ReportCategoryCard(
                        icon: "chart.bar.doc.horizontal",
                        color: .blue,
                        title: String(localized: "reports.funnel"),
                        subtitle: String(localized: "reports.funnel.subtitle")
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    UTMReportView(website: website, dateRange: selectedDateRange)
                } label: {
                    ReportCategoryCard(
                        icon: "link.badge.plus",
                        color: .green,
                        title: String(localized: "reports.utm"),
                        subtitle: String(localized: "reports.utm.subtitle")
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    GoalReportView(
                        website: website,
                        dateRange: selectedDateRange
                    )
                } label: {
                    ReportCategoryCard(
                        icon: "target",
                        color: .orange,
                        title: String(localized: "reports.goals"),
                        subtitle: String(localized: "reports.goals.subtitle")
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    AttributionReportView(website: website, dateRange: selectedDateRange)
                } label: {
                    ReportCategoryCard(
                        icon: "point.3.filled.connected.trianglepath.dotted",
                        color: .purple,
                        title: String(localized: "reports.attribution"),
                        subtitle: String(localized: "reports.attribution.subtitle")
                    )
                }
                .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(String(localized: "reports.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadReports()
        }
    }
}

// MARK: - Report Category Card

struct ReportCategoryCard: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(color)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    NavigationStack {
        ReportsHubView(
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
