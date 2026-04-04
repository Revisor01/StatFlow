import SwiftUI
import Charts

struct RealtimeView: View {
    let website: Website

    @StateObject private var viewModel: RealtimeViewModel
    @State private var selectedEvent: RealtimeEvent?

    private var isPlausible: Bool {
        AnalyticsManager.shared.providerType == .plausible
    }

    init(website: Website) {
        self.website = website
        _viewModel = StateObject(wrappedValue: RealtimeViewModel(websiteId: website.id))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                liveVisitorsCard

                if !viewModel.topPages.isEmpty {
                    topPagesSection
                }

                // Only show recent activity for Umami (Plausible doesn't have individual events)
                if !isPlausible && !viewModel.recentEvents.isEmpty {
                    recentActivitySection
                }

                if !viewModel.countries.isEmpty {
                    countriesSection
                }
            }
            .padding()
        }
        .background(
            LinearGradient(
                colors: [.green.opacity(0.05), .blue.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle(String(localized: "realtime.title"))
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            await viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
        .sheet(item: $selectedEvent) { event in
            LiveEventDetailView(event: event, website: website)
        }
    }

    private var liveVisitorsCard: some View {
        GlassCard {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "realtime.active"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(viewModel.activeVisitors)")
                                .font(.system(size: 56, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.green, .mint],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .contentTransition(.numericText())

                            LivePulse()
                        }

                        Text(String(localized: isPlausible ? "realtime.today" : "realtime.last30min"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
                        StatBubble(
                            value: viewModel.totalPageviews,
                            label: String(localized: "realtime.pageviews"),
                            icon: "eye.fill",
                            color: .blue
                        )

                        // Only show events for Umami (Plausible doesn't track realtime events)
                        if !isPlausible {
                            StatBubble(
                                value: viewModel.totalEvents,
                                label: String(localized: "website.events"),
                                icon: "bolt.fill",
                                color: .orange
                            )
                        }
                    }
                }
            }
        }
    }

    private var topPagesSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: String(localized: "realtime.activePages"), icon: "doc.text.fill")

                ForEach(viewModel.topPages.prefix(8), id: \.key) { page in
                    HStack {
                        Text(page.key)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        Text("\(page.value)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var recentActivitySection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: String(localized: "realtime.recentActivity"), icon: "clock.arrow.circlepath")

                ForEach(viewModel.recentEvents.prefix(10)) { event in
                    Button {
                        selectedEvent = event
                    } label: {
                        eventRow(event)
                    }
                    .buttonStyle(.plain)

                    if event.id != viewModel.recentEvents.prefix(10).last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private func eventRow(_ event: RealtimeEvent) -> some View {
        HStack(spacing: 12) {
            Image(systemName: event.isPageview ? "doc.text" : "bolt")
                .foregroundStyle(event.isPageview ? .blue : .orange)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.urlPath ?? "/")
                    .font(.subheadline)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let country = event.country {
                        Text(countryFlag(country))
                    }

                    if let browser = event.browser {
                        Text(browser.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let os = event.os {
                        Text("• \(os)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let device = event.device {
                        Text("• \(device)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(event.timeAgo)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var countriesSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: String(localized: "realtime.countries"), icon: "globe.europe.africa.fill")

                ForEach(viewModel.countries.prefix(5), id: \.key) { country in
                    HStack {
                        Text(countryFlag(country.key))
                            .font(.title3)
                        Text(countryName(country.key))
                            .font(.subheadline)
                        Spacer()
                        Text("\(country.value)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private func countryFlag(_ code: String) -> String {
        let base: UInt32 = 127397
        var flag = ""
        for scalar in code.uppercased().unicodeScalars {
            if let unicode = UnicodeScalar(base + scalar.value) {
                flag.append(String(unicode))
            }
        }
        return flag.isEmpty ? "🌍" : flag
    }

    private func countryName(_ code: String) -> String {
        Locale.current.localizedString(forRegionCode: code) ?? code
    }
}

struct LivePulse: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Circle()
                .fill(.green)
                .frame(width: 12, height: 12)

            Circle()
                .stroke(.green.opacity(0.5), lineWidth: 2)
                .frame(width: 12, height: 12)
                .scaleEffect(isAnimating ? 2.5 : 1)
                .opacity(isAnimating ? 0 : 1)

            Circle()
                .stroke(.green.opacity(0.3), lineWidth: 2)
                .frame(width: 12, height: 12)
                .scaleEffect(isAnimating ? 3.5 : 1)
                .opacity(isAnimating ? 0 : 0.5)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

struct StatBubble: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(value)")
                    .font(.headline)
                    .contentTransition(.numericText())

                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - ViewModel

@MainActor
class RealtimeViewModel: ObservableObject {
    let websiteId: String

    @Published var activeVisitors: Int = 0
    @Published var totalPageviews: Int = 0
    @Published var totalEvents: Int = 0
    @Published var topPages: [(key: String, value: Int)] = []
    @Published var countries: [(key: String, value: Int)] = []
    @Published var recentEvents: [RealtimeEvent] = []

    private var pollingTask: Task<Void, Never>?
    private let umamiAPI = UmamiAPI.shared
    private let plausibleAPI = PlausibleAPI.shared

    var isPlausible: Bool {
        AnalyticsManager.shared.providerType == .plausible
    }

    init(websiteId: String) {
        self.websiteId = websiteId
    }

    func startPolling() async {
        await refresh()

        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                if !Task.isCancelled {
                    await refresh()
                }
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func refresh() async {
        if isPlausible {
            await refreshPlausible()
        } else {
            await refreshUmami()
        }
    }

    private func refreshPlausible() async {
        do {
            // Fetch all data in parallel
            async let visitors = plausibleAPI.getActiveVisitors(websiteId: websiteId)
            async let pageviews = plausibleAPI.getRealtimePageviews(websiteId: websiteId)
            async let pages = plausibleAPI.getRealtimeTopPages(websiteId: websiteId)
            async let countriesData = plausibleAPI.getRealtimeCountries(websiteId: websiteId)

            let (v, pv, p, c) = try await (visitors, pageviews, pages, countriesData)

            guard !Task.isCancelled else { return }
            activeVisitors = v
            totalPageviews = pv
            totalEvents = 0 // Plausible doesn't track custom events in realtime the same way
            topPages = p.map { ($0.name, $0.value) }
            countries = c.map { ($0.name, $0.value) }
            recentEvents = [] // Plausible doesn't provide individual events

        } catch {
            guard !Task.isCancelled else { return }
            #if DEBUG
            print("Plausible Realtime error: \(error)")
            #endif
        }
    }

    private func refreshUmami() async {
        do {
            let data = try await umamiAPI.getRealtime(websiteId: websiteId)

            guard !Task.isCancelled else { return }

            // Aktive Besucher = unique Sessions in den letzten 5 Minuten
            let fiveMinutesAgo = Date().addingTimeInterval(-300)
            let recentSessions = Set(data.events.filter { $0.createdDate > fiveMinutesAgo }.map { $0.sessionId })
            activeVisitors = recentSessions.count

            // Totals
            totalPageviews = data.totals?.views ?? data.events.filter { $0.isPageview }.count
            totalEvents = data.totals?.events ?? data.events.filter { !$0.isPageview && !$0.isSession }.count

            // Top Pages sortiert
            topPages = data.urls.sorted { $0.value > $1.value }

            // Countries sortiert
            countries = data.countries.sorted { $0.value > $1.value }

            // Recent Events (nur pageviews, sortiert nach Zeit)
            recentEvents = data.events
                .filter { $0.isPageview }
                .sorted { $0.createdDate > $1.createdDate }

        } catch {
            guard !Task.isCancelled else { return }
            #if DEBUG
            print("Realtime error: \(error)")
            #endif
        }
    }
}

// MARK: - Live Event Detail View

struct LiveEventDetailView: View {
    let event: RealtimeEvent
    let website: Website

    @StateObject private var viewModel: LiveEventDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(event: RealtimeEvent, website: Website) {
        self.event = event
        self.website = website
        _viewModel = StateObject(wrappedValue: LiveEventDetailViewModel(
            websiteId: website.id,
            sessionId: event.sessionId
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Visitor Info Card
                    GlassCard {
                        VStack(spacing: 16) {
                            HStack {
                                Text(countryFlag(event.country ?? ""))
                                    .font(.largeTitle)

                                VStack(alignment: .leading, spacing: 4) {
                                    if let country = event.country {
                                        Text(countryName(country))
                                            .font(.headline)
                                    }

                                    Text(event.timeAgo)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Circle()
                                    .fill(.green)
                                    .frame(width: 10, height: 10)
                            }

                            Divider()

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ProfileItem(icon: "globe", label: String(localized: "website.browsers"), value: event.browser?.capitalized ?? "-")
                                ProfileItem(icon: "desktopcomputer", label: "OS", value: event.os ?? "-")
                                ProfileItem(icon: "iphone", label: String(localized: "sessions.detail.device"), value: deviceName(event.device ?? "-"))
                                ProfileItem(icon: "doc.text", label: String(localized: "pages.title"), value: event.urlPath ?? "/")
                            }

                            if let referrer = event.referrerDomain, !referrer.isEmpty {
                                Divider()
                                HStack {
                                    Image(systemName: "link")
                                        .foregroundStyle(.secondary)
                                    Text(String(localized: "realtime.from") + " \(referrer)")
                                        .font(.subheadline)
                                    Spacer()
                                }
                            }
                        }
                    }

                    // Session Activity
                    if !viewModel.activities.isEmpty {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Text(String(localized: "journeys.userJourney"))
                                    .font(.headline)

                                ForEach(viewModel.activities) { activity in
                                    HStack(alignment: .top, spacing: 12) {
                                        Circle()
                                            .fill(activity.isPageview ? .blue : .orange)
                                            .frame(width: 8, height: 8)
                                            .padding(.top, 6)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(activity.urlPath ?? "/")
                                                .font(.subheadline)
                                                .fontWeight(.medium)

                                            if let eventName = activity.eventName {
                                                Text(eventName)
                                                    .font(.caption)
                                                    .foregroundStyle(.orange)
                                            }

                                            Text(formatTime(activity.createdDate))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()
                                    }

                                    if activity.id != viewModel.activities.last?.id {
                                        Rectangle()
                                            .fill(.secondary.opacity(0.2))
                                            .frame(width: 1, height: 20)
                                            .padding(.leading, 3.5)
                                    }
                                }
                            }
                        }
                    } else if viewModel.isLoading {
                        ProgressView(String(localized: "sessions.detail.loading"))
                            .padding(40)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "sessions.visitor.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "button.done")) {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.loadActivity()
            }
        }
    }

    private func countryFlag(_ code: String) -> String {
        guard !code.isEmpty else { return "🌍" }
        let base: UInt32 = 127397
        var flag = ""
        for scalar in code.uppercased().unicodeScalars {
            if let unicode = UnicodeScalar(base + scalar.value) {
                flag.append(String(unicode))
            }
        }
        return flag.isEmpty ? "🌍" : flag
    }

    private func countryName(_ code: String) -> String {
        Locale.current.localizedString(forRegionCode: code) ?? code
    }

    private func deviceName(_ name: String) -> String {
        switch name.lowercased() {
        case "desktop", "laptop": return String(localized: "device.desktop")
        case "mobile": return String(localized: "device.mobile")
        case "tablet": return String(localized: "device.tablet")
        default: return name
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct ProfileItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
        }
    }
}

@MainActor
class LiveEventDetailViewModel: ObservableObject {
    let websiteId: String
    let sessionId: String

    @Published var activities: [SessionActivity] = []
    @Published var isLoading = false

    private let api = UmamiAPI.shared
    private var loadingTask: Task<Void, Never>?

    init(websiteId: String, sessionId: String) {
        self.websiteId = websiteId
        self.sessionId = sessionId
    }

    func loadActivity() async {
        loadingTask?.cancel()
        let task = Task {
            isLoading = true
            defer { if !Task.isCancelled { isLoading = false } }

            do {
                let result = try await api.getSessionActivity(
                    websiteId: websiteId,
                    sessionId: sessionId,
                    dateRange: .today
                )
                guard !Task.isCancelled else { return }
                activities = result
            } catch {
                guard !Task.isCancelled else { return }
                #if DEBUG
                print("Live session activity error: \(error)")
                #endif
            }
        }
        loadingTask = task
        await task.value
    }

    func cancelLoading() {
        loadingTask?.cancel()
        loadingTask = nil
    }
}

#Preview {
    NavigationStack {
        RealtimeView(
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
