import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @ObservedObject private var accountManager = AccountManager.shared
    @ObservedObject private var settingsManager = DashboardSettingsManager.shared
    @EnvironmentObject private var quickActionManager: QuickActionManager
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedWebsite: Website?
    @State private var selectedDateRange: DateRange = .today
    @State private var showingAddSite = false
    @State private var showingAddUmamiSite = false
    @State private var showingAccountSwitcher = false
    @State private var isReordering = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Offline-Banner
                    if viewModel.isOffline {
                        offlineBanner
                    }

                    // Account Switcher (only show if multiple accounts)
                    if accountManager.hasMultipleAccounts {
                        accountSwitcherButton
                    }

                    dateRangePicker

                    if viewModel.websites.isEmpty && !viewModel.isLoading {
                        emptyStateView
                    } else if isReordering {
                        // Reorder Mode mit List für Drag & Drop
                        reorderingView
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.sortedWebsites) { website in
                                WebsiteCard(
                                    website: website,
                                    stats: viewModel.stats[website.id],
                                    activeVisitors: viewModel.activeVisitors[website.id] ?? 0,
                                    sparklineData: viewModel.sparklineData[website.id] ?? [],
                                    onShareLinkUpdated: { updatedWebsite in
                                        viewModel.updateWebsite(updatedWebsite)
                                    },
                                    onRemoveSite: {
                                        Task {
                                            await viewModel.removeSite(website.id)
                                        }
                                    },
                                    isUmamiProvider: !currentProviderIsPlausible,
                                    isHourlyData: selectedDateRange.unit == "hour"
                                )
                                .onTapGesture {
                                    selectedWebsite = website
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("dashboard.title")
            .toolbar {
                if isReordering {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            withAnimation(.spring(duration: 0.3)) {
                                isReordering = false
                            }
                        } label: {
                            Text("button.done")
                                .fontWeight(.semibold)
                        }
                    }
                } else {
                    // Edit-Button fur Dashboard-Anpassung
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            withAnimation(.spring(duration: 0.3)) {
                                isReordering = true
                            }
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                        .accessibilityLabel(String(localized: "dashboard.edit.button"))
                    }

                    // Chart Style Toggle (nur wenn Graph sichtbar)
                    if settingsManager.showGraph {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                withAnimation(.spring(duration: 0.3)) {
                                    settingsManager.toggleChartStyle()
                                }
                            } label: {
                                Image(systemName: settingsManager.chartStyle.icon)
                            }
                            .accessibilityLabel(String(localized: "accessibility.chartStyle.toggle"))
                            .accessibilityHint(String(localized: "accessibility.chartStyle.hint"))
                        }
                    }

                    // Website hinzufugen fur beide Provider
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            if currentProviderIsPlausible {
                                showingAddSite = true
                            } else {
                                showingAddUmamiSite = true
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel(String(localized: "accessibility.addWebsite"))
                    }
                }
            }
            .refreshable {
                await viewModel.refresh(dateRange: selectedDateRange)
            }
            .overlay {
                if viewModel.isLoading && viewModel.websites.isEmpty {
                    ProgressView("dashboard.loading")
                }
            }
            .navigationDestination(item: $selectedWebsite) { website in
                WebsiteDetailView(website: website)
            }
            .sheet(isPresented: $showingAddSite) {
                AddPlausibleSiteView {
                    Task {
                        await viewModel.loadData(dateRange: selectedDateRange)
                    }
                }
            }
            .sheet(isPresented: $showingAddUmamiSite) {
                AddUmamiSiteView {
                    Task {
                        await viewModel.loadData(dateRange: selectedDateRange)
                    }
                }
            }
        }
        .task {
            await viewModel.loadData(dateRange: selectedDateRange)
        }
        .onChange(of: selectedDateRange) { _, newValue in
            Task {
                await viewModel.loadData(dateRange: newValue)
            }
        }
        .onChange(of: quickActionManager.selectedWebsiteId) { _, websiteId in
            if let websiteId = websiteId,
               let website = viewModel.websites.first(where: { $0.id == websiteId }) {
                selectedWebsite = website
                quickActionManager.clearSelection()
            }
        }
        .onChange(of: viewModel.websites) { _, websites in
            // Verarbeite pending Deep-Link nachdem Websites geladen wurden
            if let pending = quickActionManager.pendingDeepLink,
               let website = websites.first(where: { $0.id == pending.websiteId }) {
                selectedWebsite = website
                quickActionManager.pendingDeepLink = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .accountDidChange)) { _ in
            Task {
                await viewModel.loadData(dateRange: selectedDateRange)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Auto-Refresh beim Öffnen der App
                Task {
                    await viewModel.refresh(dateRange: selectedDateRange)
                }
            }
        }
    }

    /// Use AccountManager as source of truth for provider type
    private var currentProviderIsPlausible: Bool {
        AccountManager.shared.activeAccount?.providerType == .plausible
    }

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.subheadline)
            Text("dashboard.offline")
                .font(.subheadline)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.15))
        .foregroundStyle(.orange)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("dashboard.empty.title")
                .font(.headline)

            if authManager.currentProvider == .plausible {
                Text("dashboard.empty.plausible")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    showingAddSite = true
                } label: {
                    Label("dashboard.addSite", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("dashboard.empty.umami")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
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
                            .padding(.horizontal, 16)
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
            .padding(.horizontal, 4)
        }
        .mask(
            HStack(spacing: 0) {
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 20)
            }
        )
    }

    private var reorderingView: some View {
        List {
            // MARK: - Display Settings
            Section {
                Toggle("dashboard.settings.showGraph", isOn: $settingsManager.showGraph)

                if settingsManager.showGraph {
                    Picker("chart.style", selection: $settingsManager.chartStyle) {
                        Text("chart.style.bar").tag(ChartStyle.bar)
                        Text("chart.style.line").tag(ChartStyle.line)
                    }
                }
            } header: {
                Text("dashboard.settings.graph")
            }

            Section {
                Toggle("dashboard.settings.metrics.visitors", isOn: $settingsManager.showVisitors)
                Toggle("dashboard.settings.metrics.pageviews", isOn: $settingsManager.showPageviews)
                Toggle("dashboard.settings.metrics.visits", isOn: $settingsManager.showVisits)
                Toggle("dashboard.settings.metrics.bounceRate", isOn: $settingsManager.showBounceRate)
                Toggle("dashboard.settings.metrics.duration", isOn: $settingsManager.showDuration)
            } header: {
                Text("dashboard.settings.metrics")
            }

            // MARK: - Website Order
            Section {
                ForEach(viewModel.sortedWebsites) { website in
                    HStack(spacing: 12) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(website.name)
                                .font(.body)
                                .fontWeight(.medium)
                            Text(website.displayDomain)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .onMove { from, to in
                    viewModel.moveWebsite(from: from, to: to)
                }
            } header: {
                Text("dashboard.edit.order")
            } footer: {
                Text("dashboard.reorder.hint")
            }
        }
        .environment(\.editMode, .constant(.active))
    }

    private var accountSwitcherButton: some View {
        Button {
            showingAccountSwitcher = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: accountManager.activeAccount?.icon ?? "server.rack")
                    .font(.system(size: 16))
                    .foregroundStyle(accountManager.activeAccount?.providerType == .umami ? .orange : .blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(accountManager.activeAccount?.displayName ?? "Account")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(accountManager.activeAccount?.providerType.displayName ?? "")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingAccountSwitcher) {
            AccountSwitcherSheet(onAccountChanged: {
                Task {
                    await viewModel.loadData(dateRange: selectedDateRange)
                }
            })
        }
    }
}

// MARK: - Account Switcher Sheet

struct AccountSwitcherSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var accountManager = AccountManager.shared
    var onAccountChanged: (() -> Void)?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(accountManager.accounts) { account in
                        AccountRow(
                            account: account,
                            isActive: accountManager.activeAccount?.id == account.id,
                            onSelect: {
                                accountManager.setActiveAccount(account)
                                onAccountChanged?()
                                dismiss()
                            }
                        )
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            accountManager.removeAccount(accountManager.accounts[index])
                        }
                    }
                } header: {
                    Text("account.switcher.accounts")
                }

                Section {
                    NavigationLink {
                        AddAccountView(onAccountAdded: {
                            onAccountChanged?()
                            dismiss()
                        })
                    } label: {
                        Label("account.switcher.addAccount", systemImage: "plus.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .navigationTitle("account.switcher.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("button.done") { dismiss() }
                }
            }
        }
    }
}

struct AccountRow: View {
    let account: AnalyticsAccount
    let isActive: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: account.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(account.providerType == .umami ? .orange : .blue)
                    .frame(width: 32, height: 32)
                    .background(
                        (account.providerType == .umami ? Color.orange : Color.blue).opacity(0.15)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(account.displayName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text(account.providerType.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Account View

struct AddAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var accountManager = AccountManager.shared

    @State private var selectedProvider: AnalyticsProviderType = .umami
    @State private var serverURL = ""
    @State private var accountName = ""

    // Umami
    @State private var username = ""
    @State private var password = ""

    // Plausible
    @State private var apiKey = ""

    @State private var isLoading = false
    @State private var errorMessage: String?

    var onAccountAdded: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Provider Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("account.add.provider")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        ForEach(AnalyticsProviderType.allCases, id: \.self) { provider in
                            ProviderSelectionButton(
                                provider: provider,
                                isSelected: selectedProvider == provider
                            ) {
                                withAnimation(.spring(duration: 0.3)) {
                                    selectedProvider = provider
                                }
                            }
                        }
                    }
                }

                // Details Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("account.add.details")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 12) {
                        TextField("account.add.name", text: $accountName)
                            .textContentType(.organizationName)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        TextField("account.add.serverURL", text: $serverURL)
                            .textContentType(.URL)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                // Credentials Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("account.add.credentials")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    if selectedProvider == .umami {
                        VStack(spacing: 12) {
                            TextField("account.add.username", text: $username)
                                .textContentType(.username)
                                .textInputAutocapitalization(.never)
                                .padding()
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            SecureField("account.add.password", text: $password)
                                .textContentType(.password)
                                .padding()
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            SecureField("account.add.apiKey", text: $apiKey)
                                .textContentType(.password)
                                .padding()
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            Text("account.add.apiKey.hint")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Error Message
                if let error = errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.subheadline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Add Button
                Button {
                    Task { await addAccount() }
                } label: {
                    HStack {
                        Spacer()
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("account.add.button")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(isFormValid ? (selectedProvider == .umami ? Color.orange : Color.blue) : Color.gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!isFormValid || isLoading)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("account.add.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("button.cancel") {
                    dismiss()
                }
            }
        }
    }

    private var isFormValid: Bool {
        if serverURL.isEmpty { return false }
        if selectedProvider == .umami {
            return !username.isEmpty && !password.isEmpty
        } else {
            return !apiKey.isEmpty
        }
    }

    private func addAccount() async {
        isLoading = true
        errorMessage = nil

        do {
            var normalizedURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
            while normalizedURL.hasSuffix("/") { normalizedURL.removeLast() }
            if !normalizedURL.lowercased().hasPrefix("http") {
                normalizedURL = "https://" + normalizedURL
            }

            if selectedProvider == .umami {
                // Authenticate with Umami
                try await UmamiAPI.shared.authenticate(serverURL: normalizedURL, credentials: .umami(username: username, password: password))
                let token = KeychainService.load(for: .token) ?? ""

                let account = AnalyticsAccount(
                    name: accountName,
                    serverURL: normalizedURL,
                    providerType: .umami,
                    credentials: AccountCredentials(token: token, apiKey: nil)
                )
                accountManager.addAccount(account)
                accountManager.setActiveAccount(account)
            } else {
                // Authenticate with Plausible
                try await PlausibleAPI.shared.authenticate(serverURL: normalizedURL, credentials: .plausible(apiKey: apiKey))

                let account = AnalyticsAccount(
                    name: accountName,
                    serverURL: normalizedURL,
                    providerType: .plausible,
                    credentials: AccountCredentials(token: nil, apiKey: apiKey),
                    sites: []
                )
                accountManager.addAccount(account)
                accountManager.setActiveAccount(account)
            }

            await MainActor.run {
                onAccountAdded?()
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// MARK: - Provider Selection Button

struct ProviderSelectionButton: View {
    let provider: AnalyticsProviderType
    let isSelected: Bool
    let action: () -> Void

    private var providerColor: Color {
        provider == .umami ? .orange : .blue
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSelected ? providerColor.opacity(0.15) : Color(.tertiarySystemGroupedBackground))
                        .frame(width: 50, height: 50)

                    Image(systemName: provider.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(isSelected ? providerColor : .secondary)
                }

                Text(provider.displayName)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? providerColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var websites: [Website] = []
    @Published var stats: [String: WebsiteStats] = [:]
    @Published var activeVisitors: [String: Int] = [:]
    @Published var sparklineData: [String: [TimeSeriesPoint]] = [:]
    @Published var isLoading = false
    @Published var error: String?
    @Published var isOffline = false
    @Published var websiteOrder: [String] = [] {
        didSet {
            saveWebsiteOrder()
        }
    }

    private let umamiAPI = UmamiAPI.shared
    private let plausibleAPI = PlausibleAPI.shared
    private let cache = AnalyticsCacheService.shared
    private var currentDateRange: DateRange = .today

    /// Sortierte Websites basierend auf gespeicherter Reihenfolge
    var sortedWebsites: [Website] {
        if websiteOrder.isEmpty {
            return websites
        }

        return websites.sorted { a, b in
            let indexA = websiteOrder.firstIndex(of: a.id) ?? Int.max
            let indexB = websiteOrder.firstIndex(of: b.id) ?? Int.max
            return indexA < indexB
        }
    }

    init() {
        loadWebsiteOrder()
    }

    private var orderKey: String {
        "websiteOrder_\(currentAccountId)"
    }

    private func loadWebsiteOrder() {
        if let order = UserDefaults.standard.stringArray(forKey: orderKey) {
            websiteOrder = order
        }
    }

    private func saveWebsiteOrder() {
        UserDefaults.standard.set(websiteOrder, forKey: orderKey)
    }

    func moveWebsite(from source: IndexSet, to destination: Int) {
        var order = sortedWebsites.map { $0.id }
        order.move(fromOffsets: source, toOffset: destination)
        websiteOrder = order
    }

    private var isPlausible: Bool {
        AnalyticsManager.shared.providerType == .plausible
    }

    private var currentAccountId: String {
        AccountManager.shared.activeAccount?.id.uuidString ?? "default"
    }

    func loadData(dateRange: DateRange) async {
        isLoading = true
        currentDateRange = dateRange
        isOffline = false

        // Lade die Website-Reihenfolge für den aktuellen Account
        loadWebsiteOrder()

        // 1. Lade zuerst aus dem Cache für sofortige Anzeige
        loadFromCache(dateRange: dateRange)

        // 2. Dann versuche frische Daten zu laden
        do {
            if isPlausible {
                let analyticsWebsites = try await plausibleAPI.getAnalyticsWebsites()
                websites = analyticsWebsites.map { site in
                    Website(id: site.id, name: site.name, domain: site.domain, shareId: nil, teamId: nil, resetAt: nil, createdAt: nil)
                }
                // Cache die Websites
                cache.saveWebsites(analyticsWebsites.toCached(), accountId: currentAccountId)
            } else {
                websites = try await umamiAPI.getWebsites()
                // Cache die Websites
                let analyticsWebsites = websites.map { site in
                    AnalyticsWebsite(id: site.id, name: site.name, domain: site.domain ?? site.name, shareId: site.shareId, provider: .umami)
                }
                cache.saveWebsites(analyticsWebsites.toCached(), accountId: currentAccountId)
            }

            await withTaskGroup(of: Void.self) { group in
                for website in websites {
                    group.addTask { await self.loadWebsiteData(website, dateRange: dateRange) }
                }
            }

            isLoading = false
        } catch {
            // Prüfe ob es sich um einen echten Netzwerkfehler handelt
            let isNetworkError = (error as? URLError)?.code == .notConnectedToInternet ||
                                 (error as? URLError)?.code == .networkConnectionLost ||
                                 (error as? URLError)?.code == .timedOut ||
                                 (error as? URLError)?.code == .cannotFindHost ||
                                 (error as? URLError)?.code == .cannotConnectToHost

            if websites.isEmpty {
                self.error = error.localizedDescription
            } else if isNetworkError {
                // Nur bei echtem Netzwerkfehler Offline-Indikator zeigen
                isOffline = true
            }
            // Bei anderen Fehlern (z.B. API-Fehler) keinen Offline-Banner zeigen
            isLoading = false
        }
    }

    /// Lädt Daten aus dem lokalen Cache
    private func loadFromCache(dateRange: DateRange) {
        // Lade gecachte Websites
        if let cachedWebsites = cache.loadWebsites(accountId: currentAccountId) {
            let analyticsWebsites = cachedWebsites.data.toAnalyticsWebsites()
            websites = analyticsWebsites.map { site in
                Website(id: site.id, name: site.name, domain: site.domain, shareId: site.shareId, teamId: nil, resetAt: nil, createdAt: nil)
            }

            // Lade gecachte Stats und Sparklines für jede Website
            for website in websites {
                let dateRangeId = dateRange.preset.rawValue

                // Stats laden
                if let cachedStats = cache.loadStats(websiteId: website.id, dateRangeId: dateRangeId) {
                    stats[website.id] = cachedStats.data.toAnalyticsStats().toWebsiteStats()
                }

                // Sparkline laden
                if let cachedSparkline = cache.loadSparkline(websiteId: website.id, dateRangeId: dateRangeId) {
                    let points = cachedSparkline.data.toAnalyticsChartPoints()
                    let formatter = ISO8601DateFormatter()
                    sparklineData[website.id] = points.map { point in
                        TimeSeriesPoint(x: formatter.string(from: point.date), y: point.value)
                    }
                }
            }
        }
    }

    func refresh(dateRange: DateRange) async {
        await loadData(dateRange: dateRange)
    }

    func updateWebsite(_ website: Website) {
        if let index = websites.firstIndex(where: { $0.id == website.id }) {
            websites[index] = website
        }
    }

    func removeSite(_ websiteId: String) async {
        if isPlausible {
            plausibleAPI.removeSite(domain: websiteId)
        } else {
            // Umami: Delete via API
            do {
                try await umamiAPI.deleteWebsite(websiteId: websiteId)
            } catch {
                print("Failed to delete Umami website: \(error)")
                return
            }
        }
        websites.removeAll { $0.id == websiteId }
        stats.removeValue(forKey: websiteId)
        activeVisitors.removeValue(forKey: websiteId)
        sparklineData.removeValue(forKey: websiteId)
    }

    private func loadWebsiteData(_ website: Website, dateRange: DateRange) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadStats(for: website.id, dateRange: dateRange) }
            group.addTask { await self.loadActiveVisitors(for: website.id) }
            group.addTask { await self.loadSparkline(for: website.id, dateRange: dateRange) }
        }
    }

    private func loadStats(for websiteId: String, dateRange: DateRange) async {
        let dateRangeId = dateRange.preset.rawValue

        do {
            let analyticsStats: AnalyticsStats
            if isPlausible {
                analyticsStats = try await plausibleAPI.getAnalyticsStats(websiteId: websiteId, dateRange: dateRange)
            } else {
                let websiteStats = try await umamiAPI.getStats(websiteId: websiteId, dateRange: dateRange)
                analyticsStats = AnalyticsStats(
                    visitors: websiteStats.visitors,
                    pageviews: websiteStats.pageviews,
                    visits: websiteStats.visits,
                    bounces: websiteStats.bounces,
                    totaltime: websiteStats.totaltime
                )
            }

            stats[websiteId] = analyticsStats.toWebsiteStats()

            // Cache die Stats
            cache.saveStats(CachedStats(from: analyticsStats), websiteId: websiteId, dateRangeId: dateRangeId)
        } catch {
            #if DEBUG
            print("Failed to load stats for \(websiteId): \(error)")
            #endif
        }
    }

    private func loadActiveVisitors(for websiteId: String) async {
        do {
            if isPlausible {
                let count = try await plausibleAPI.getActiveVisitors(websiteId: websiteId)
                activeVisitors[websiteId] = count
            } else {
                let count = try await umamiAPI.getActiveVisitors(websiteId: websiteId)
                activeVisitors[websiteId] = count
            }
        } catch {
            #if DEBUG
            print("Failed to load active visitors for \(websiteId): \(error)")
            #endif
        }
    }

    private func loadSparkline(for websiteId: String, dateRange: DateRange) async {
        let dateRangeId = dateRange.preset.rawValue

        do {
            let chartPoints: [AnalyticsChartPoint]
            if isPlausible {
                chartPoints = try await plausibleAPI.getPageviewsData(websiteId: websiteId, dateRange: dateRange)
            } else {
                let pageviews = try await umamiAPI.getPageviews(websiteId: websiteId, dateRange: dateRange)
                chartPoints = pageviews.pageviews.map { point in
                    AnalyticsChartPoint(date: point.date, value: point.value)
                }
            }

            let formatter = ISO8601DateFormatter()
            let rawData = chartPoints.map { point in
                TimeSeriesPoint(x: formatter.string(from: point.date), y: point.value)
            }
            sparklineData[websiteId] = fillMissingTimeSlots(data: rawData, dateRange: dateRange)

            // Cache die Sparkline-Daten
            cache.saveSparkline(chartPoints.toCached(), websiteId: websiteId, dateRangeId: dateRangeId)
        } catch {
            #if DEBUG
            print("Failed to load sparkline for \(websiteId): \(error)")
            #endif
        }
    }

    /// Fills in missing time slots with zero values for complete chart display
    private func fillMissingTimeSlots(data: [TimeSeriesPoint], dateRange: DateRange) -> [TimeSeriesPoint] {
        let calendar = Calendar.current
        let now = Date()
        let isHourly = dateRange.unit == "hour"

        // Create a map of existing data by date
        var dataMap: [Date: Int] = [:]
        for point in data {
            dataMap[point.date] = point.value
        }

        var result: [TimeSeriesPoint] = []
        let formatter = ISO8601DateFormatter()

        if isHourly {
            // Generate all hours for the day
            let baseDate: Date
            switch dateRange.preset {
            case .today:
                baseDate = now
            case .yesterday:
                baseDate = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            default:
                baseDate = dateRange.dates.start
            }

            let startOfDay = calendar.startOfDay(for: baseDate)
            let currentHour = dateRange.preset == .today ? calendar.component(.hour, from: now) : 23

            for hour in 0...currentHour {
                if let hourDate = calendar.date(byAdding: .hour, value: hour, to: startOfDay) {
                    // Find matching value in data
                    let value = dataMap.first { existing in
                        calendar.component(.hour, from: existing.key) == hour &&
                        calendar.isDate(existing.key, inSameDayAs: hourDate)
                    }?.value ?? 0

                    result.append(TimeSeriesPoint(x: formatter.string(from: hourDate), y: value))
                }
            }
        } else {
            // Generate all days in range
            let dates = dateRange.dates
            var currentDate = calendar.startOfDay(for: dates.start)
            let endDate = calendar.startOfDay(for: dates.end)

            while currentDate <= endDate {
                // Find matching value in data
                let value = dataMap.first { existing in
                    calendar.isDate(existing.key, inSameDayAs: currentDate)
                }?.value ?? 0

                result.append(TimeSeriesPoint(x: formatter.string(from: currentDate), y: value))

                if let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) {
                    currentDate = nextDay
                } else {
                    break
                }
            }
        }

        return result.isEmpty ? data : result
    }
}

#Preview {
    DashboardView()
        .environmentObject(AuthManager())
}
