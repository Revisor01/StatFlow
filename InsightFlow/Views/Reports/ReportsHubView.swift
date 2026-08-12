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

    /// Alle Reports dieses Hubs laufen über die Umami-API — bei Plausible
    /// erscheint deshalb ein Hinweis statt der Kacheln.
    private var isPlausible: Bool {
        AnalyticsManager.shared.providerType == .plausible
    }

    private var unsupportedCard: some View {
        ContentUnavailableView(
            String(localized: "reports.unsupported"),
            systemImage: "chart.bar.doc.horizontal",
            description: Text(String(localized: "reports.unsupported.description"))
        )
    }

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
            VStack(spacing: 16) {
                if isPlausible {
                    unsupportedCard
                } else {
                    if viewModel.isOffline {
                        offlineBanner
                            .padding(.horizontal)
                    }

                    reportGrid
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(String(localized: "reports.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !isPlausible else { return }
            await viewModel.loadReports()
        }
    }

    // MARK: - Kacheln

    private var reportGrid: some View {
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

            // Ab Umami v3 verfügbar.
            NavigationLink {
                WebVitalsView(website: website)
            } label: {
                ReportCategoryCard(
                    icon: "speedometer",
                    color: .indigo,
                    title: String(localized: "webvitals.title"),
                    subtitle: String(localized: "reports.webvitals.subtitle")
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                VisitTimesView(website: website)
            } label: {
                ReportCategoryCard(
                    icon: "clock.badge.checkmark",
                    color: .teal,
                    title: String(localized: "visittimes.title"),
                    subtitle: String(localized: "reports.visittimes.subtitle")
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                RevenueView(website: website)
            } label: {
                ReportCategoryCard(
                    icon: "eurosign.circle",
                    color: .green,
                    title: String(localized: "revenue.title"),
                    subtitle: String(localized: "reports.revenue.subtitle")
                )
            }
            .buttonStyle(.plain)
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    // Zweizeilig reservieren, damit alle Kacheln gleich hoch bleiben,
                    // auch wenn ein Untertitel nur eine Zeile braucht.
                    .lineLimit(2, reservesSpace: true)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
