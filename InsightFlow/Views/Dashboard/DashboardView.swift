import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @ObservedObject private var accountManager = AccountManager.shared
    @ObservedObject private var settingsManager = DashboardSettingsManager.shared
    @EnvironmentObject private var quickActionManager: QuickActionManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedWebsite: Website?
    @State private var selectedDateRange: DateRange = .today
    @State private var showingAddSite = false
    @State private var showingAddUmamiSite = false
    @State private var showingAddAccount = false
    @State private var isReordering = false
    @State private var showAllAccounts = false
    @State private var websiteAccountMap: [String: AnalyticsAccount] = [:]

    var body: some View {
        NavigationStack {
            Group {
                if isReordering {
                    // Reorder Mode - List ohne ScrollView
                    reorderingView
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Offline-Banner
                            if viewModel.isOffline {
                                offlineBanner
                            }

                            if settingsManager.showDateRangePicker {
                                dateRangePicker
                            }

                            if viewModel.websites.isEmpty && !viewModel.isLoading {
                                emptyStateView
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
                                            onRemoveSite: showAllAccounts ? nil : {
                                                Task {
                                                    await viewModel.removeSite(website.id)
                                                }
                                            },
                                            isUmamiProvider: showAllAccounts
                                                ? websiteAccountMap[website.id]?.providerType == .umami
                                                : !currentProviderIsPlausible,
                                            isHourlyData: selectedDateRange.unit == "hour",
                                            providerName: showAllAccounts
                                                ? websiteAccountMap[website.id]?.providerType.displayName
                                                : nil
                                        )
                                        .onTapGesture {
                                            Task {
                                                if showAllAccounts,
                                                   let account = websiteAccountMap[website.id] {
                                                    await accountManager.setActiveAccount(account)
                                                    showAllAccounts = false
                                                }
                                                selectedWebsite = website
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
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

                    // Account-Switcher Menu (nur wenn mehrere Accounts)
                    if accountManager.hasMultipleAccounts {
                        ToolbarItem(placement: .navigationBarLeading) {
                            accountSwitcherMenu
                        }
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
            .sheet(isPresented: $showingAddAccount) {
                NavigationStack {
                    AddAccountView(onAccountAdded: {
                        Task {
                            await viewModel.loadData(dateRange: selectedDateRange)
                        }
                    })
                }
            }
        }
        .task {
            if showAllAccounts {
                let map = await viewModel.loadAllAccountsData(dateRange: selectedDateRange, accounts: accountManager.accounts)
                websiteAccountMap = map
            } else {
                await viewModel.loadData(dateRange: selectedDateRange)
            }
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
            // Only reload when NOT in all-accounts mode (avoid disrupting combined view)
            if !showAllAccounts {
                Task {
                    await viewModel.loadData(dateRange: selectedDateRange, clearFirst: true)
                }
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

    private var activeAccountId: UUID {
        accountManager.activeAccount?.id ?? UUID()
    }

    @ViewBuilder
    private var accountSwitcherMenu: some View {
        Menu {
            accountSwitcherMenuItems
        } label: {
            accountSwitcherLabel
        }
    }

    @ViewBuilder
    private var accountSwitcherLabel: some View {
        if showAllAccounts {
            Image(systemName: "rectangle.stack")
                .foregroundStyle(Color.purple)
        } else {
            let iconName = accountManager.activeAccount?.icon ?? "server.rack"
            let isUmami = accountManager.activeAccount?.providerType == .umami
            Image(systemName: iconName)
                .foregroundStyle(isUmami ? Color.orange : Color.blue)
        }
    }

    @ViewBuilder
    private var accountSwitcherMenuItems: some View {
        // "Alle" als erste Option
        Button {
            showAllAccounts = true
            Task {
                let map = await viewModel.loadAllAccountsData(
                    dateRange: selectedDateRange,
                    accounts: accountManager.accounts
                )
                websiteAccountMap = map
            }
        } label: {
            HStack {
                Label(String(localized: "account.switcher.all"), systemImage: "rectangle.stack")
                if showAllAccounts {
                    Image(systemName: "checkmark")
                }
            }
        }

        Divider()

        // Einzelne Accounts
        ForEach(accountManager.accounts) { account in
            Button {
                showAllAccounts = false
                Task {
                    await accountManager.setActiveAccount(account)
                    await viewModel.loadData(dateRange: selectedDateRange)
                }
            } label: {
                HStack {
                    Label(account.displayName, systemImage: account.icon)
                    if !showAllAccounts && accountManager.activeAccount?.id == account.id {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }

        Divider()

        Button {
            showingAddAccount = true
        } label: {
            Label("account.switcher.addAccount", systemImage: "plus.circle.fill")
        }
    }

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.subheadline)
            if let cacheDate = viewModel.offlineCacheDate {
                Text("dashboard.offlineData \(cacheDate, format: .relative(presentation: .named))")
                    .font(.subheadline)
            } else {
                Text("dashboard.offline")
                    .font(.subheadline)
            }
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

            if accountManager.activeAccount?.providerType == .plausible {
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
                Toggle("dashboard.settings.showDateRangePicker", isOn: $settingsManager.showDateRangePicker)

                Toggle("dashboard.settings.showGraph", isOn: $settingsManager.showGraph)

                if settingsManager.showGraph {
                    Picker("dashboard.settings.chartStyle", selection: $settingsManager.chartStyle) {
                        Text("chart.style.bar").tag(DashboardChartStyle.bar)
                        Text("chart.style.line").tag(DashboardChartStyle.line)
                    }
                }
            } header: {
                Text("dashboard.settings.display")
            }

            Section {
                ForEach(DashboardMetric.allCases) { metric in
                    Toggle(metric.localizedName, isOn: Binding(
                        get: { settingsManager.isEnabled(metric) },
                        set: { settingsManager.setEnabled(metric, enabled: $0) }
                    ))
                }
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("dashboard.edit.order")
                    Text("dashboard.reorder.hint")
                        .font(.footnote)
                        .fontWeight(.regular)
                        .textCase(.none)
                }
            }
        }
        .listStyle(.insetGrouped)
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

    @State private var serverType: ServerType = .cloud
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

                // Server Type Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("login.serverType")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)

                    HStack(spacing: 12) {
                        ForEach(ServerType.allCases, id: \.self) { type in
                            ServerTypeButton(
                                type: type,
                                isSelected: serverType == type,
                                providerColor: selectedProvider == .umami ? Color.orange : Color.blue
                            ) {
                                withAnimation(.spring(duration: 0.3)) {
                                    serverType = type
                                    if type == .cloud {
                                        serverURL = selectedProvider == .umami
                                            ? "https://cloud.umami.is"
                                            : "https://plausible.io"
                                    } else {
                                        serverURL = ""
                                    }
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

                        if serverType == .selfHosted {
                            TextField("account.add.serverURL", text: $serverURL)
                                .textContentType(.URL)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
                                .padding()
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
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
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
            }
        }
    }

    private var isFormValid: Bool {
        let hasValidServer = serverType == .cloud || !serverURL.isEmpty
        if selectedProvider == .umami {
            return hasValidServer && !username.isEmpty && !password.isEmpty
        } else {
            return hasValidServer && !apiKey.isEmpty
        }
    }

    private func addAccount() async {
        isLoading = true
        errorMessage = nil

        do {
            var normalizedURL = serverType == .cloud
                ? (selectedProvider == .umami ? "https://cloud.umami.is" : "https://plausible.io")
                : serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
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
                await accountManager.setActiveAccount(account)
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
                await accountManager.setActiveAccount(account)
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

#Preview {
    DashboardView()
}
