import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var notificationManager: NotificationManager

    @StateObject private var viewModel = SettingsViewModel()
    @ObservedObject private var accountManager = AccountManager.shared
    @State private var showLogoutConfirmation = false
    @State private var showOnboarding = false
    @State private var showSupport = false
    @State private var showEditApiKey = false
    @State private var showAddAccount = false
    @State private var showEditAccount = false
    @State private var accountToEdit: AnalyticsAccount?
    @State private var newApiKey = ""
    @AppStorage("colorScheme") private var colorScheme: String = "system"

    var body: some View {
        NavigationStack {
            List {
                accountsSection

                supportSection

                appearanceSection

                notificationsSection

                aboutSection

                logoutSection
            }
            .preferredColorScheme(preferredColorScheme)
            .navigationTitle("settings.title")
            .alert("settings.logout", isPresented: $showLogoutConfirmation) {
                Button("button.cancel", role: .cancel) { }
                Button("settings.logout", role: .destructive) {
                    accountManager.clearActiveAccount()
                }
            } message: {
                Text("settings.logout.confirm")
            }
            .task {
                await viewModel.loadWebsites()
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView(isPresented: $showOnboarding)
            }
            .sheet(isPresented: $showSupport) {
                SupportView()
            }
            .sheet(isPresented: $showAddAccount) {
                NavigationStack {
                    AddAccountView(onAccountAdded: {
                        Task {
                            await viewModel.loadWebsites()
                        }
                    })
                }
            }
            .sheet(isPresented: $showEditAccount) {
                if let account = accountToEdit {
                    NavigationStack {
                        EditAccountView(account: account, onAccountUpdated: {
                            Task {
                                await viewModel.loadWebsites()
                            }
                        })
                    }
                }
            }
            .alert("settings.editApiKey", isPresented: $showEditApiKey) {
                TextField("API Key", text: $newApiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("button.cancel", role: .cancel) { }
                Button("button.save") {
                    if !newApiKey.isEmpty {
                        try? KeychainService.save(newApiKey, for: .apiKey)
                    }
                }
            } message: {
                Text("settings.editApiKey.message")
            }
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch colorScheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private var accountsSection: some View {
        Section {
            // Zeige aktuellen Account wenn kein activeAccount gesetzt ist und Accounts vorhanden
            if accountManager.accounts.isEmpty {
                if let active = accountManager.activeAccount {
                    currentAccountRow(active)
                }
            } else {
                // Alle Accounts anzeigen
                ForEach(accountManager.accounts) { account in
                    AccountSettingsRow(
                        account: account,
                        isActive: accountManager.activeAccount?.id == account.id,
                        onSelect: {
                            accountManager.setActiveAccount(account)
                            Task {
                                await viewModel.loadWebsites()
                            }
                        }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            accountManager.removeAccount(account)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .tint(.red)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            accountToEdit = account
                            showEditAccount = true
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }

            // Account hinzufügen Button
            Button {
                showAddAccount = true
            } label: {
                Label("account.switcher.addAccount", systemImage: "plus.circle.fill")
                    .foregroundStyle(.blue)
            }
        } header: {
            Text("settings.accounts")
        }
    }

    private func currentAccountRow(_ account: AnalyticsAccount) -> some View {
        HStack(spacing: 12) {
            Image(systemName: account.providerType == .umami ? "chart.bar.xaxis" : "chart.line.uptrend.xyaxis")
                .font(.system(size: 24))
                .foregroundStyle(account.providerType == .umami ? .orange : .blue)
                .frame(width: 36, height: 36)
                .background(
                    (account.providerType == .umami ? Color.orange : Color.blue).opacity(0.12)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(account.serverURL
                    .replacingOccurrences(of: "https://", with: "")
                    .replacingOccurrences(of: "http://", with: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
    }

    private func maskedApiKey(_ key: String) -> String {
        guard key.count > 8 else { return "••••••••" }
        let prefix = String(key.prefix(4))
        let suffix = String(key.suffix(4))
        return "\(prefix)••••\(suffix)"
    }

    private var supportSection: some View {
        Section {
            Button {
                showSupport = true
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.pink, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)

                        Image(systemName: "heart.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("settings.support.title")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("settings.support.subtitle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var appearanceSection: some View {
        Section {
            Picker("settings.appearance", selection: $colorScheme) {
                Text("settings.appearance.system").tag("system")
                Text("settings.appearance.light").tag("light")
                Text("settings.appearance.dark").tag("dark")
            }

            NavigationLink {
                DashboardSettingsView()
            } label: {
                Label("dashboard.settings.title", systemImage: "square.grid.2x2")
            }
        } header: {
            Text("settings.appearance")
        }
    }

    private var notificationsSection: some View {
        Section {
            // Zeit-Einstellung
            DatePicker(
                String(localized: "settings.notifications.time"),
                selection: $notificationManager.notificationTime,
                displayedComponents: .hourAndMinute
            )

            // Datenquelle-Einstellung
            Picker("settings.notifications.stats", selection: $notificationManager.dataSource) {
                ForEach(NotificationDataSource.allCases, id: \.self) { source in
                    Text(source.localizedName).tag(source)
                }
            }

            ForEach(viewModel.websites) { website in
                NotificationSettingRow(
                    website: website,
                    setting: notificationManager.getSetting(for: website.id)
                ) { newSetting in
                    Task {
                        if newSetting != .disabled {
                            let granted = await notificationManager.requestPermission()
                            if !granted {
                                return
                            }
                        }
                        notificationManager.updateSetting(for: website.id, setting: newSetting)
                    }
                }
            }
        } header: {
            Text("settings.notifications")
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "settings.notifications.footer \(notificationManager.formattedTime)"))

                if notificationManager.dataSource == .auto {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("settings.notifications.stats.auto")
                            .fontWeight(.medium)
                        Text("settings.notifications.stats.auto.description")
                    }
                }
            }
        }
    }

    private var aboutSection: some View {
        Section {
            Button {
                showOnboarding = true
            } label: {
                HStack {
                    Label("settings.about.intro", systemImage: "questionmark.circle")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            // Umami Link
            Link(destination: URL(string: "https://umami.is")!) {
                HStack {
                    Label("Umami Analytics", systemImage: "chart.bar.xaxis")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            // Plausible Link
            Link(destination: URL(string: "https://plausible.io")!) {
                HStack {
                    Label("Plausible Analytics", systemImage: "chart.line.uptrend.xyaxis")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            // GitHub Umami
            Link(destination: URL(string: "https://github.com/umami-software/umami")!) {
                HStack {
                    Label("Umami GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            // GitHub Plausible
            Link(destination: URL(string: "https://github.com/plausible/analytics")!) {
                HStack {
                    Label("Plausible GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        } header: {
            Text("settings.about")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text("settings.about.license")

                Text("Plausible Analytics is open source under AGPL-3.0 license.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
        }
    }

    private var logoutSection: some View {
        Section {
            Button(role: .destructive) {
                showLogoutConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Label("settings.logout", systemImage: "rectangle.portrait.and.arrow.right")
                    Spacer()
                }
            }
        } footer: {
            VStack(spacing: 4) {
                Text("PrivacyFlow v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                HStack(spacing: 4) {
                    Text("Made with")
                    Image(systemName: "heart.fill")
                    Text("in Hennstedt")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
        }
    }
}

struct AccountSettingsRow: View {
    let account: AnalyticsAccount
    let isActive: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: account.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(account.providerType == .umami ? .orange : .blue)
                    .frame(width: 36, height: 36)
                    .background(
                        (account.providerType == .umami ? Color.orange : Color.blue).opacity(0.12)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(account.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Text(account.serverURL
                        .replacingOccurrences(of: "https://", with: "")
                        .replacingOccurrences(of: "http://", with: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
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

struct NotificationSettingRow: View {
    let website: Website
    let setting: NotificationSetting
    let onSettingChanged: (NotificationSetting) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(website.name)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(website.displayDomain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: settingIcon)
                    .foregroundStyle(settingColor)
            }

            Picker(String(localized: "settings.notifications.frequency"), selection: Binding(
                get: { setting },
                set: { onSettingChanged($0) }
            )) {
                ForEach(NotificationSetting.allCases, id: \.self) { option in
                    Text(option.localizedName).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 4)
    }

    private var settingIcon: String {
        switch setting {
        case .disabled: return "bell.slash"
        case .daily: return "bell.badge"
        case .weekly: return "bell.badge.circle"
        }
    }

    private var settingColor: Color {
        switch setting {
        case .disabled: return .secondary
        case .daily: return .blue
        case .weekly: return .purple
        }
    }
}

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var websites: [Website] = []

    private let umamiAPI = UmamiAPI.shared
    private let plausibleAPI = PlausibleAPI.shared

    private var isPlausible: Bool {
        AnalyticsManager.shared.providerType == .plausible
    }

    func loadWebsites() async {
        do {
            if isPlausible {
                let sites = try await plausibleAPI.getAnalyticsWebsites()
                websites = sites.map { site in
                    Website(id: site.id, name: site.name, domain: site.domain, shareId: nil, teamId: nil, resetAt: nil, createdAt: nil)
                }
            } else {
                websites = try await umamiAPI.getWebsites()
            }
        } catch {
            #if DEBUG
            print("Failed to load websites: \(error)")
            #endif
        }
    }
}

// MARK: - Edit Account View

struct EditAccountView: View {
    let account: AnalyticsAccount
    var onAccountUpdated: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var accountManager = AccountManager.shared
    @State private var accountName: String
    @State private var isSaving = false

    init(account: AnalyticsAccount, onAccountUpdated: (() -> Void)? = nil) {
        self.account = account
        self.onAccountUpdated = onAccountUpdated
        _accountName = State(initialValue: account.name)
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: account.icon)
                        .font(.system(size: 24))
                        .foregroundStyle(account.providerType == .umami ? .orange : .blue)
                        .frame(width: 36, height: 36)
                        .background(
                            (account.providerType == .umami ? Color.orange : Color.blue).opacity(0.12)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.providerType == .umami ? "Umami" : "Plausible")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text(account.serverURL
                            .replacingOccurrences(of: "https://", with: "")
                            .replacingOccurrences(of: "http://", with: ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Section {
                TextField("account.edit.name", text: $accountName)
            } header: {
                Text("account.edit.name.header")
            } footer: {
                Text("account.edit.name.footer")
            }
        }
        .navigationTitle("account.edit.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("button.cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("button.save") {
                    saveAccount()
                }
                .disabled(isSaving)
            }
        }
    }

    private func saveAccount() {
        isSaving = true

        // Create updated account with new name
        let updatedAccount = AnalyticsAccount(
            id: account.id,
            name: accountName,
            serverURL: account.serverURL,
            providerType: account.providerType,
            credentials: account.credentials,
            sites: account.sites
        )

        // Update in manager
        accountManager.addAccount(updatedAccount)

        // If this was the active account, refresh it
        if accountManager.activeAccount?.id == account.id {
            accountManager.setActiveAccount(updatedAccount)
        }

        onAccountUpdated?()
        dismiss()
    }
}

#Preview {
    SettingsView()
        .environmentObject(NotificationManager())
}
