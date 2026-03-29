import SwiftUI

enum SessionsTab: String, CaseIterable {
    case journeys = "sessions.tab.journeys"
    case sessions = "sessions.tab.sessions"
}

struct SessionsView: View {
    let website: Website

    @StateObject private var viewModel: SessionsViewModel
    @StateObject private var journeyViewModel: JourneyViewModel
    @State private var selectedSession: Session?
    @State private var selectedDateRange: DateRange = .thisWeek
    @State private var selectedTab: SessionsTab = .journeys

    init(website: Website) {
        self.website = website
        _viewModel = StateObject(wrappedValue: SessionsViewModel(websiteId: website.id))
        _journeyViewModel = StateObject(wrappedValue: JourneyViewModel(websiteId: website.id))
    }

    var body: some View {
        VStack(spacing: 0) {
            dateRangePicker
                .padding()

            if viewModel.isOffline {
                offlineBanner
                    .padding(.horizontal)
            }

            switch selectedTab {
            case .journeys:
                journeysContent
            case .sessions:
                sessionsContent
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(String(localized: "sessions.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker(String(localized: "sessions.title"), selection: $selectedTab) {
                    ForEach(SessionsTab.allCases, id: \.self) { tab in
                        Text(String(localized: String.LocalizationValue(tab.rawValue))).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
        }
        .sheet(item: $selectedSession) { session in
            SessionDetailView(
                website: website,
                session: session,
                dateRange: selectedDateRange
            )
        }
        .refreshable {
            if selectedTab == .sessions {
                await viewModel.refresh(dateRange: selectedDateRange)
            } else {
                await journeyViewModel.loadJourneys(dateRange: selectedDateRange)
            }
        }
        .task {
            await journeyViewModel.loadJourneys(dateRange: selectedDateRange)
        }
        .onChange(of: selectedDateRange) { _, newValue in
            Task {
                if selectedTab == .journeys {
                    await journeyViewModel.loadJourneys(dateRange: newValue)
                } else {
                    await viewModel.loadData(dateRange: newValue)
                }
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            Task {
                if newValue == .sessions && viewModel.sessions.isEmpty {
                    await viewModel.loadData(dateRange: selectedDateRange)
                } else if newValue == .journeys && journeyViewModel.journeys.isEmpty {
                    await journeyViewModel.loadJourneys(dateRange: selectedDateRange)
                }
            }
        }
    }

    @ViewBuilder
    private var sessionsContent: some View {
        if viewModel.isLoading && viewModel.sessions.isEmpty {
            Spacer()
            ProgressView(String(localized: "sessions.loading"))
            Spacer()
        } else if viewModel.sessions.isEmpty {
            Spacer()
            ContentUnavailableView(
                String(localized: "sessions.empty"),
                systemImage: "person.slash",
                description: Text(String(localized: "sessions.empty.description"))
            )
            Spacer()
        } else {
            List {
                ForEach(viewModel.sessions) { session in
                    SessionRow(session: session)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedSession = session
                        }
                }

                if viewModel.hasMore {
                    Button {
                        Task {
                            await viewModel.loadMore(dateRange: selectedDateRange)
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView()
                            } else {
                                Text(String(localized: "sessions.loadMore"))
                            }
                            Spacer()
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private var journeysContent: some View {
        if journeyViewModel.isLoading && journeyViewModel.journeys.isEmpty {
            Spacer()
            ProgressView(String(localized: "journeys.loading"))
            Spacer()
        } else if journeyViewModel.journeys.isEmpty {
            Spacer()
            ContentUnavailableView(
                String(localized: "journeys.empty"),
                systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                description: Text(String(localized: "journeys.empty.description"))
            )
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(journeyViewModel.journeys) { journey in
                        JourneyCard(journey: journey)
                    }
                }
                .padding()
            }
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
}

struct SessionRow: View {
    let session: Session

    var body: some View {
        HStack(spacing: 12) {
            // Country Flag
            Text(countryFlag(session.country ?? ""))
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if let browser = session.browser {
                        Text(browser.capitalized)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    if let os = session.os {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(os)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    if let city = session.city, let country = session.country {
                        Text("\(city), \(countryName(country))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let country = session.country {
                        Text(countryName(country))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "eye")
                        .font(.caption2)
                    Text("\(session.views ?? 0)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.blue)

                Text(session.duration)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
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
}

struct SessionDetailView: View {
    let website: Website
    let session: Session
    let dateRange: DateRange

    @StateObject private var viewModel: SessionDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(website: Website, session: Session, dateRange: DateRange) {
        self.website = website
        self.session = session
        self.dateRange = dateRange
        _viewModel = StateObject(wrappedValue: SessionDetailViewModel(
            websiteId: website.id,
            sessionId: session.id
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    sessionInfoCard

                    if !viewModel.activities.isEmpty {
                        activityTimeline
                    } else if viewModel.isLoading {
                        ProgressView()
                            .padding(40)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "sessions.detail.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "button.done")) {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.loadActivity(dateRange: dateRange)
            }
        }
    }

    private var sessionInfoCard: some View {
        GlassCard {
            VStack(spacing: 16) {
                HStack {
                    Text(countryFlag(session.country ?? ""))
                        .font(.largeTitle)

                    VStack(alignment: .leading, spacing: 4) {
                        if let city = session.city, let country = session.country {
                            Text("\(city), \(countryName(country))")
                                .font(.headline)
                        } else if let country = session.country {
                            Text(countryName(country))
                                .font(.headline)
                        }

                        if let region = session.region {
                            Text(region)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }

                Divider()

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    InfoItem(icon: "globe", label: String(localized: "website.browsers"), value: session.browser?.capitalized ?? "-")
                    InfoItem(icon: "desktopcomputer", label: "OS", value: session.os ?? "-")
                    InfoItem(icon: "iphone", label: String(localized: "sessions.detail.device"), value: deviceName(session.device ?? "-"))
                    InfoItem(icon: "rectangle.dashed", label: String(localized: "website.screens"), value: session.screen ?? "-")
                    InfoItem(icon: "eye", label: String(localized: "sessions.detail.pageviews"), value: "\(session.views ?? 0)")
                    InfoItem(icon: "clock", label: String(localized: "metrics.duration"), value: session.duration)
                }
            }
        }
    }

    private var activityTimeline: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text(String(localized: "sessions.detail.activities"))
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

struct InfoItem: View {
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

// MARK: - ViewModels

@MainActor
class SessionsViewModel: ObservableObject {
    let websiteId: String

    @Published var sessions: [Session] = []
    @Published var isLoading = false
    @Published var isOffline = false
    @Published var hasMore = false

    private var currentPage = 1
    private var totalCount = 0
    private let pageSize = 20
    private let api = UmamiAPI.shared

    init(websiteId: String) {
        self.websiteId = websiteId
    }

    func loadData(dateRange: DateRange) async {
        isLoading = true
        isOffline = false
        currentPage = 1

        do {
            let response = try await api.getSessions(
                websiteId: websiteId,
                dateRange: dateRange,
                page: currentPage,
                pageSize: pageSize
            )
            sessions = response.data
            totalCount = response.count
            hasMore = sessions.count < totalCount
        } catch {
            #if DEBUG
            print("Sessions error: \(error)")
            #endif
            let isNetworkError = (error as? URLError)?.code == .notConnectedToInternet ||
                                 (error as? URLError)?.code == .networkConnectionLost ||
                                 (error as? URLError)?.code == .timedOut ||
                                 (error as? URLError)?.code == .cannotFindHost ||
                                 (error as? URLError)?.code == .cannotConnectToHost
            if isNetworkError {
                isOffline = true
            }
        }

        isLoading = false
    }

    func loadMore(dateRange: DateRange) async {
        guard !isLoading, hasMore else { return }

        isLoading = true
        currentPage += 1

        do {
            let response = try await api.getSessions(
                websiteId: websiteId,
                dateRange: dateRange,
                page: currentPage,
                pageSize: pageSize
            )
            sessions.append(contentsOf: response.data)
            hasMore = sessions.count < totalCount
        } catch {
            #if DEBUG
            print("Sessions error: \(error)")
            #endif
        }

        isLoading = false
    }

    func refresh(dateRange: DateRange) async {
        await loadData(dateRange: dateRange)
    }
}

@MainActor
class SessionDetailViewModel: ObservableObject {
    let websiteId: String
    let sessionId: String

    @Published var activities: [SessionActivity] = []
    @Published var isLoading = false

    private let api = UmamiAPI.shared

    init(websiteId: String, sessionId: String) {
        self.websiteId = websiteId
        self.sessionId = sessionId
    }

    func loadActivity(dateRange: DateRange) async {
        isLoading = true

        do {
            activities = try await api.getSessionActivity(
                websiteId: websiteId,
                sessionId: sessionId,
                dateRange: dateRange
            )
        } catch {
            #if DEBUG
            print("Activity error: \(error)")
            #endif
        }

        isLoading = false
    }
}

@MainActor
class JourneyViewModel: ObservableObject {
    let websiteId: String

    @Published var journeys: [JourneyPath] = []
    @Published var isLoading = false

    private let api = UmamiAPI.shared

    init(websiteId: String) {
        self.websiteId = websiteId
    }

    func loadJourneys(dateRange: DateRange) async {
        isLoading = true

        do {
            journeys = try await api.getJourneyReport(
                websiteId: websiteId,
                dateRange: dateRange,
                steps: 5
            )
        } catch {
            #if DEBUG
            print("Journey error: \(error)")
            #endif
        }

        isLoading = false
    }
}

// MARK: - Journey Card

struct JourneyCard: View {
    let journey: JourneyPath

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(String(localized: "journeys.visitors \(journey.count)"))
                        .font(.headline)
                        .foregroundStyle(.blue)

                    Spacer()

                    Text(String(localized: "journeys.steps \(journey.stepCount)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Capsule())
                }

                // Journey Path Visualization
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(journey.paths.enumerated()), id: \.offset) { index, path in
                        HStack(spacing: 8) {
                            // Step number
                            Text("\(index + 1)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .frame(width: 20, height: 20)
                                .background(stepColor(for: index, total: journey.stepCount))
                                .clipShape(Circle())

                            // Path
                            Text(path)
                                .font(.subheadline)
                                .lineLimit(1)

                            Spacer()
                        }

                        // Connector line
                        if index < journey.paths.count - 1 {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 2, height: 12)
                                .padding(.leading, 9)
                        }
                    }
                }
            }
        }
    }

    private func stepColor(for index: Int, total: Int) -> Color {
        let progress = total > 1 ? Double(index) / Double(total - 1) : 0
        return Color(
            hue: 0.6 - (progress * 0.15), // Blue to purple gradient
            saturation: 0.7,
            brightness: 0.8
        )
    }
}

#Preview {
    NavigationStack {
        SessionsView(
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
