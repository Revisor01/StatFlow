import SwiftUI

// MARK: - EventsView

struct EventsView: View {
    let website: Website

    @StateObject private var viewModel: EventsViewModel
    @State private var selectedDateRange: DateRange = .thisWeek
    @State private var selectedEvent: AnalyticsMetricItem?

    init(website: Website) {
        self.website = website
        _viewModel = StateObject(wrappedValue: EventsViewModel(websiteId: website.id))
    }

    var body: some View {
        VStack(spacing: 0) {
            dateRangePicker
                .padding()

            if viewModel.isOffline {
                offlineBanner
                    .padding(.horizontal)
            }

            if viewModel.isLoading && viewModel.events.isEmpty {
                Spacer()
                ProgressView(String(localized: "events.loading"))
                Spacer()
            } else if viewModel.events.isEmpty {
                Spacer()
                ContentUnavailableView(
                    String(localized: "events.empty"),
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text(String(localized: "events.empty.description"))
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if let stats = viewModel.eventStats {
                            statsHeader(stats: stats)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                        }

                        ForEach(viewModel.events) { event in
                            NavigationLink {
                                EventDetailView(
                                    website: website,
                                    eventName: event.name,
                                    eventCount: event.value,
                                    dateRange: selectedDateRange
                                )
                            } label: {
                                EventRow(event: event)
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .padding(.leading)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(String(localized: "events.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadEvents(dateRange: selectedDateRange)
        }
        .onChange(of: selectedDateRange) { _, newValue in
            Task {
                await viewModel.loadEvents(dateRange: newValue)
            }
        }
        .refreshable {
            await viewModel.loadEvents(dateRange: selectedDateRange)
        }
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

    private var dateRangePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DateRange.allCases, id: \.preset) { range in
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            selectedDateRange = range
                        }
                    } label: {
                        Text(range.displayName)
                            .font(.subheadline)
                            .fontWeight(selectedDateRange.preset == range.preset ? .semibold : .regular)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedDateRange.preset == range.preset ? Color.primary : .clear)
                            .foregroundColor(selectedDateRange.preset == range.preset ? Color(.systemBackground) : .primary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(selectedDateRange.preset == range.preset ? .clear : .secondary.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func statsHeader(stats: EventStatsResponse) -> some View {
        GlassCard {
            HStack(spacing: 0) {
                StatPill(
                    value: "\(stats.events)",
                    label: String(localized: "events.stats.events"),
                    icon: "bell.fill",
                    color: .blue
                )
                Divider()
                    .frame(height: 36)
                StatPill(
                    value: "\(stats.properties)",
                    label: String(localized: "events.stats.properties"),
                    icon: "list.bullet",
                    color: .purple
                )
                Divider()
                    .frame(height: 36)
                StatPill(
                    value: "\(stats.records)",
                    label: String(localized: "events.stats.records"),
                    icon: "doc.text.fill",
                    color: .orange
                )
            }
        }
    }
}

// MARK: - EventRow

struct EventRow: View {
    let event: AnalyticsMetricItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.fill")
                .font(.callout)
                .foregroundStyle(.blue)
                .frame(width: 28, height: 28)
                .background(Color.blue.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(event.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)

            Spacer()

            Text("\(event.value)")
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.blue)
                .clipShape(Capsule())

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - StatPill

struct StatPill: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
                Text(value)
                    .font(.callout)
                    .fontWeight(.bold)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - EventDetailView

struct EventDetailView: View {
    let website: Website
    let eventName: String
    let eventCount: Int
    let dateRange: DateRange

    @StateObject private var viewModel: EventsViewModel

    init(website: Website, eventName: String, eventCount: Int, dateRange: DateRange) {
        self.website = website
        self.eventName = eventName
        self.eventCount = eventCount
        self.dateRange = dateRange
        _viewModel = StateObject(wrappedValue: EventsViewModel(websiteId: website.id))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header Card
                GlassCard {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "bell.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(eventName)
                                    .font(.headline)
                                    .lineLimit(2)

                                Text("\(eventCount) \(String(localized: "events.stats.events"))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                    }
                }
                .padding(.horizontal)

                if viewModel.isLoading && viewModel.selectedEventProperties.isEmpty {
                    ProgressView()
                        .padding(40)
                } else if viewModel.selectedEventProperties.isEmpty {
                    GlassCard {
                        Text(String(localized: "events.detail.noProperties"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    }
                    .padding(.horizontal)
                } else {
                    propertiesSection
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(String(localized: "events.detail.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadEventDetail(eventName: eventName, dateRange: dateRange)
        }
    }

    private var propertiesSection: some View {
        VStack(spacing: 12) {
            let distinctProperties = Array(Set(viewModel.selectedEventProperties.compactMap { $0.propertyName })).sorted()

            if distinctProperties.isEmpty {
                GlassCard {
                    Text(String(localized: "events.detail.noProperties"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
                .padding(.horizontal)
            } else {
                ForEach(distinctProperties, id: \.self) { propertyName in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(
                                title: propertyName,
                                icon: "list.bullet"
                            )

                            if let values = viewModel.selectedEventValues[propertyName], !values.isEmpty {
                                ForEach(values) { valueItem in
                                    HStack {
                                        Text(valueItem.value)
                                            .font(.subheadline)
                                            .lineLimit(1)

                                        Spacer()

                                        Text("\(valueItem.total)")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.secondary)
                                    }

                                    if valueItem.id != values.last?.id {
                                        Divider()
                                    }
                                }
                            } else {
                                Text(String(localized: "events.detail.noProperties"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        EventsView(
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
