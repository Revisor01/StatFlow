import SwiftUI

struct AdminView: View {
    @StateObject private var viewModel = AdminViewModel()
    @State private var selectedSection: AdminSection = .websites

    private var availableSections: [AdminSection] {
        viewModel.currentProvider == .plausible
            ? [.websites]
            : AdminSection.allCases
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                switch selectedSection {
                case .websites:
                    websitesSection
                case .teams:
                    teamsSection
                case .users:
                    usersSection
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("admin.title")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if availableSections.count > 1 {
                        Picker("admin.section", selection: $selectedSection) {
                            ForEach(availableSections, id: \.self) { section in
                                Text(section.localizedTitle).tag(section)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 280)
                    }
                }
            }
            .task {
                await viewModel.loadAll()
            }
            .refreshable {
                await viewModel.loadAll()
            }
            .onReceive(NotificationCenter.default.publisher(for: .accountDidChange)) { _ in
                Task {
                    await viewModel.loadAll()
                }
            }
            .sheet(isPresented: $viewModel.showCreateWebsite) {
                CreateWebsiteSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showCreateTeam) {
                CreateTeamSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showCreateUser) {
                CreateUserSheet(viewModel: viewModel)
            }
            .alert("error.title", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }

    // MARK: - Websites Section

    private var websitesSection: some View {
        VStack(spacing: 16) {
            Button {
                viewModel.showCreateWebsite = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("admin.websites.new")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            .padding(.top)

            if viewModel.currentProvider == .plausible {
                plausibleSitesContent
            } else {
                umamiWebsitesContent
            }
        }
        .padding(.bottom)
    }

    private var umamiWebsitesContent: some View {
        Group {
            if viewModel.isLoading && viewModel.websites.isEmpty {
                ProgressView()
                    .padding(40)
            } else if viewModel.websites.isEmpty {
                ContentUnavailableView(
                    "admin.websites.empty",
                    systemImage: "globe",
                    description: Text("admin.websites.empty.description")
                )
                .padding(40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.websites) { website in
                        WebsiteAdminCard(website: website, viewModel: viewModel)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var plausibleSitesContent: some View {
        Group {
            if viewModel.isLoading && viewModel.plausibleSites.isEmpty {
                ProgressView()
                    .padding(40)
            } else if viewModel.plausibleSites.isEmpty {
                ContentUnavailableView(
                    "admin.websites.empty",
                    systemImage: "globe",
                    description: Text("admin.websites.empty.description")
                )
                .padding(40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.plausibleSites) { site in
                        PlausibleSiteAdminCard(site: site, viewModel: viewModel)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Teams Section

    private var teamsSection: some View {
        VStack(spacing: 16) {
            Button {
                viewModel.showCreateTeam = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("admin.teams.new")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            .padding(.top)

            if viewModel.teams.isEmpty {
                ContentUnavailableView(
                    "admin.teams.empty",
                    systemImage: "person.3",
                    description: Text("admin.teams.empty.description")
                )
                .padding(40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.teams) { team in
                        TeamCard(team: team, viewModel: viewModel)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom)
    }

    // MARK: - Users Section

    private var usersSection: some View {
        VStack(spacing: 16) {
            Button {
                viewModel.showCreateUser = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("admin.users.new")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            .padding(.top)

            if viewModel.users.isEmpty {
                ContentUnavailableView(
                    "admin.users.empty",
                    systemImage: "person",
                    description: Text("admin.users.empty.description")
                )
                .padding(40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.users) { user in
                        UserCard(user: user, viewModel: viewModel)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom)
    }
}

// MARK: - Admin Section Enum

enum AdminSection: CaseIterable {
    case websites, teams, users

    var localizedTitle: String {
        switch self {
        case .websites: return String(localized: "admin.websites")
        case .teams: return String(localized: "admin.teams")
        case .users: return String(localized: "admin.users")
        }
    }

    var icon: String {
        switch self {
        case .websites: return "globe"
        case .teams: return "person.3"
        case .users: return "person"
        }
    }
}

// MARK: - Website Admin Card

struct WebsiteAdminCard: View {
    let website: Website
    @ObservedObject var viewModel: AdminViewModel
    @State private var showDeleteConfirm = false
    @State private var showShareSheet = false
    @State private var showTrackingCode = false
    @State private var showEditSheet = false

    var teamName: String? {
        viewModel.teams.first(where: { $0.id == website.teamId })?.name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(website.name)
                        .font(.headline)
                    Text(website.displayDomain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let teamName = teamName {
                        HStack(spacing: 4) {
                            Image(systemName: "person.3.fill")
                                .font(.caption2)
                            Text(teamName)
                                .font(.caption)
                        }
                        .foregroundStyle(.purple)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    if website.shareId != nil {
                        Image(systemName: "link")
                            .foregroundStyle(.blue)
                    }
                    Button {
                        showEditSheet = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }

            Divider()

            HStack(spacing: 12) {
                Button {
                    showTrackingCode = true
                } label: {
                    Label("admin.websites.code", systemImage: "doc.text")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                Button {
                    showShareSheet = true
                } label: {
                    Label("admin.websites.share", systemImage: "square.and.arrow.up")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .alert("admin.websites.delete", isPresented: $showDeleteConfirm) {
            Button("button.cancel", role: .cancel) { }
            Button("button.delete", role: .destructive) {
                Task {
                    await viewModel.deleteWebsite(website)
                }
            }
        } message: {
            Text(String(localized: "admin.websites.delete.message \(website.name)"))
        }
        .sheet(isPresented: $showTrackingCode) {
            TrackingCodeSheet(website: website, serverURL: viewModel.serverURL)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareLinkSheet(website: website, viewModel: viewModel)
        }
        .sheet(isPresented: $showEditSheet) {
            EditWebsiteSheet(website: website, viewModel: viewModel)
        }
    }
}

// MARK: - Team Card

struct TeamCard: View {
    let team: Team
    @ObservedObject var viewModel: AdminViewModel
    @State private var showDeleteConfirm = false
    @State private var showMemberSheet = false

    var assignedWebsites: [Website] {
        viewModel.websites.filter { $0.teamId == team.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.3.fill")
                    .foregroundStyle(.purple)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(team.name)
                        .font(.headline)
                    if let accessCode = team.accessCode {
                        Text("\(String(localized: "admin.teams.accessCode")) \(accessCode)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        showMemberSheet = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }

            if !assignedWebsites.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("admin.teams.websites")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(assignedWebsites) { website in
                        HStack(spacing: 4) {
                            Image(systemName: "globe")
                                .font(.caption2)
                            Text(website.name)
                                .font(.caption)
                        }
                        .foregroundStyle(.blue)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .alert("admin.teams.delete", isPresented: $showDeleteConfirm) {
            Button("button.cancel", role: .cancel) { }
            Button("button.delete", role: .destructive) {
                Task {
                    await viewModel.deleteTeam(team)
                }
            }
        }
        .sheet(isPresented: $showMemberSheet) {
            TeamMemberSheet(team: team, viewModel: viewModel)
        }
    }
}

// MARK: - User Card

struct UserCard: View {
    let user: UmamiUser
    @ObservedObject var viewModel: AdminViewModel
    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: user.isAdmin ? "person.badge.key.fill" : "person.fill")
                .foregroundStyle(user.isAdmin ? .orange : .blue)
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text(user.username)
                    .font(.headline)
                Text(user.localizedRoleDisplayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !user.isAdmin {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .alert("admin.users.delete", isPresented: $showDeleteConfirm) {
            Button("button.cancel", role: .cancel) { }
            Button("button.delete", role: .destructive) {
                Task {
                    await viewModel.deleteUser(user)
                }
            }
        }
    }
}

// MARK: - Create Sheets

struct CreateWebsiteSheet: View {
    @ObservedObject var viewModel: AdminViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var domain = ""

    private var isPlausible: Bool {
        viewModel.currentProvider == .plausible
    }

    private var isValid: Bool {
        if isPlausible {
            return !domain.isEmpty
        } else {
            return !name.isEmpty && !domain.isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if !isPlausible {
                        TextField("Name", text: $name)
                    }
                    TextField("Domain", text: $domain)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                } header: {
                    Text("admin.details")
                } footer: {
                    if isPlausible {
                        Text("admin.websites.plausible.hint")
                    }
                }
            }
            .navigationTitle("admin.websites.new")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("button.create") {
                        Task {
                            await viewModel.createWebsite(name: name, domain: domain)
                            dismiss()
                        }
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}

struct CreateTeamSheet: View {
    @ObservedObject var viewModel: AdminViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                } header: {
                    Text("admin.details")
                }
            }
            .navigationTitle("admin.teams.new")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("button.create") {
                        Task {
                            await viewModel.createTeam(name: name)
                            // Reload teams to ensure data is up to date
                            await viewModel.loadTeams()
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

struct CreateUserSheet: View {
    @ObservedObject var viewModel: AdminViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var password = ""
    @State private var role = "user"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "admin.users.username"), text: $username)
                        .textInputAutocapitalization(.never)
                    SecureField(String(localized: "admin.users.password"), text: $password)
                } header: {
                    Text("admin.users.credentials")
                }

                Section {
                    Picker("admin.users.role", selection: $role) {
                        Text("admin.users.role.user").tag("user")
                        Text("admin.users.role.admin").tag("admin")
                    }
                } header: {
                    Text("admin.users.permissions")
                }
            }
            .navigationTitle("admin.users.new")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("button.create") {
                        Task {
                            await viewModel.createUser(username: username, password: password, role: role)
                            dismiss()
                        }
                    }
                    .disabled(username.isEmpty || password.isEmpty)
                }
            }
        }
    }
}

// MARK: - Plausible Site Admin Card

struct PlausibleSiteAdminCard: View {
    let site: PlausibleSite
    @ObservedObject var viewModel: AdminViewModel
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(site.domain)
                        .font(.headline)
                    if let timezone = site.timezone {
                        Text(timezone)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.indigo)
            }

            Divider()

            HStack(spacing: 12) {
                Spacer()

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("button.delete", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .alert("admin.websites.delete", isPresented: $showDeleteConfirm) {
            Button("button.cancel", role: .cancel) { }
            Button("button.delete", role: .destructive) {
                Task {
                    await viewModel.deletePlausibleSite(site)
                }
            }
        } message: {
            Text(String(localized: "admin.websites.delete.message \(site.domain)"))
        }
    }
}

// MARK: - Plausible Tracking Code Sheet

struct PlausibleTrackingCodeSheet: View {
    let domain: String
    @ObservedObject var viewModel: AdminViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var trackingCode: String {
        viewModel.getPlausibleTrackingCode(domain: domain)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("admin.websites.trackingCode.description")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(trackingCode)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button {
                        UIPasteboard.general.string = trackingCode
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copied = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            Text(copied ? "button.copied" : "admin.websites.trackingCode.copy")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(copied ? Color.green : Color.indigo)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .navigationTitle("admin.websites.trackingCode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("button.done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Tracking Code Sheet (Umami)

struct TrackingCodeSheet: View {
    let website: Website
    let serverURL: String
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var trackingCode: String {
        """
        <script defer src="\(serverURL)/script.js" data-website-id="\(website.id)"></script>
        """
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("admin.websites.trackingCode.description")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(trackingCode)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button {
                        UIPasteboard.general.string = trackingCode
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copied = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            Text(copied ? String(localized: "button.copied") : String(localized: "admin.websites.trackingCode.copy"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(copied ? Color.green : Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .navigationTitle(String(localized: "admin.websites.trackingCode"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("button.done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Share Link Sheet

struct ShareLinkSheet: View {
    let website: Website
    @ObservedObject var viewModel: AdminViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var shareId: String
    @State private var isShareEnabled: Bool
    @State private var copied = false
    @State private var isUpdating = false

    init(website: Website, viewModel: AdminViewModel) {
        self.website = website
        self.viewModel = viewModel
        _shareId = State(initialValue: website.shareId ?? StringUtils.generateShareId())
        _isShareEnabled = State(initialValue: website.shareId != nil)
    }

    var shareURL: String {
        "\(viewModel.serverURL)/share/\(shareId)/\(website.displayDomain)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(String(localized: "admin.websites.shareLink.enabled"), isOn: $isShareEnabled)
                        .disabled(isUpdating)
                        .onChange(of: isShareEnabled) { _, newValue in
                            Task {
                                isUpdating = true
                                if newValue {
                                    await viewModel.updateWebsiteShareId(website, shareId: shareId)
                                } else {
                                    await viewModel.disableWebsiteShareId(website)
                                }
                                isUpdating = false
                            }
                        }
                } footer: {
                    Text("admin.websites.shareLink.description")
                }

                if isShareEnabled {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("admin.websites.shareLink.id")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("ShareID", text: $shareId)
                                .textInputAutocapitalization(.never)
                                .font(.system(.body, design: .monospaced))
                        }
                    } footer: {
                        if shareId.count < 8 {
                            Text("admin.websites.shareLink.minLength")
                                .foregroundStyle(.red)
                        }
                    }

                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("admin.websites.shareLink.existing")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(shareURL)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)

                            Button {
                                UIPasteboard.general.string = shareURL
                                copied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    copied = false
                                }
                            } label: {
                                HStack {
                                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                    Text(copied ? "button.copied" : "admin.websites.shareLink.copy")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(copied ? .green : .blue)
                        }
                    }
                }
            }
            .navigationTitle("admin.websites.shareLink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("button.done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
class AdminViewModel: ObservableObject {
    @Published var websites: [Website] = []
    @Published var plausibleSites: [PlausibleSite] = []
    @Published var teams: [Team] = []
    @Published var users: [UmamiUser] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showCreateWebsite = false
    @Published var showCreateTeam = false
    @Published var showCreateUser = false

    private let umamiAPI = UmamiAPI.shared
    private let plausibleAPI = PlausibleAPI.shared

    var currentProvider: AnalyticsProviderType? {
        if let providerString = KeychainService.load(for: .providerType) {
            return AnalyticsProviderType(rawValue: providerString)
        }
        return .umami
    }

    var serverURL: String {
        KeychainService.load(for: .serverURL) ?? ""
    }

    func loadAll() async {
        isLoading = true
        if currentProvider == .plausible {
            await loadPlausibleSites()
        } else {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadWebsites() }
                group.addTask { await self.loadTeams() }
                group.addTask { await self.loadUsers() }
            }
        }
        isLoading = false
    }

    // MARK: - Umami

    private func loadWebsites() async {
        do {
            websites = try await umamiAPI.getWebsites()
        } catch {
            showError(error)
        }
    }

    func loadTeams() async {
        do {
            teams = try await umamiAPI.getTeams()
        } catch {
            #if DEBUG
            print("Teams error: \(error)")
            #endif
        }
    }

    private func loadUsers() async {
        do {
            users = try await umamiAPI.getUsers()
        } catch {
            #if DEBUG
            print("Users error: \(error)")
            #endif
        }
    }

    func createWebsite(name: String, domain: String) async {
        if currentProvider == .plausible {
            await createPlausibleSite(domain: domain)
        } else {
            do {
                let website = try await umamiAPI.createWebsite(name: name, domain: domain)
                websites.append(website)
            } catch {
                showError(error)
            }
        }
    }

    func deleteWebsite(_ website: Website) async {
        do {
            try await umamiAPI.deleteWebsite(websiteId: website.id)
            websites.removeAll { $0.id == website.id }
        } catch {
            showError(error)
        }
    }

    func updateWebsiteShareId(_ website: Website, shareId: String) async {
        do {
            let updated = try await umamiAPI.updateWebsite(websiteId: website.id, shareId: shareId)
            if let index = websites.firstIndex(where: { $0.id == website.id }) {
                websites[index] = updated
            }
        } catch {
            showError(error)
        }
    }

    func disableWebsiteShareId(_ website: Website) async {
        do {
            let updated = try await umamiAPI.updateWebsite(websiteId: website.id, clearShareId: true)
            if let index = websites.firstIndex(where: { $0.id == website.id }) {
                websites[index] = updated
            }
        } catch {
            showError(error)
        }
    }

    func createTeam(name: String) async {
        do {
            let team = try await umamiAPI.createTeam(name: name)
            teams.append(team)
        } catch {
            showError(error)
        }
    }

    func deleteTeam(_ team: Team) async {
        do {
            try await umamiAPI.deleteTeam(teamId: team.id)
            teams.removeAll { $0.id == team.id }
        } catch {
            showError(error)
        }
    }

    func createUser(username: String, password: String, role: String) async {
        do {
            let user = try await umamiAPI.createUser(username: username, password: password, role: role)
            users.append(user)
        } catch {
            showError(error)
        }
    }

    func deleteUser(_ user: UmamiUser) async {
        do {
            try await umamiAPI.deleteUser(userId: user.id)
            users.removeAll { $0.id == user.id }
        } catch {
            showError(error)
        }
    }

    func updateWebsite(_ website: Website, name: String?) async {
        do {
            let updated = try await umamiAPI.updateWebsite(websiteId: website.id, name: name)
            if let index = websites.firstIndex(where: { $0.id == website.id }) {
                websites[index] = updated
            }
        } catch {
            showError(error)
        }
    }

    func addTeamMember(teamId: String, userId: String, role: String) async {
        do {
            _ = try await umamiAPI.addTeamMember(teamId: teamId, userId: userId, role: role)
            await loadTeams()
        } catch {
            showError(error)
        }
    }

    func removeTeamMember(teamId: String, userId: String) async {
        do {
            try await umamiAPI.removeTeamMember(teamId: teamId, userId: userId)
            await loadTeams()
        } catch {
            showError(error)
        }
    }

    // MARK: - Plausible

    private func loadPlausibleSites() async {
        do {
            let analyticsWebsites = try await plausibleAPI.getAnalyticsWebsites()
            plausibleSites = analyticsWebsites.map { PlausibleSite(domain: $0.domain, timezone: nil) }
        } catch {
            showError(error)
        }
    }

    func createPlausibleSite(domain: String) async {
        do {
            // Use addSite which validates via Stats API and stores locally
            try await plausibleAPI.addSite(domain: domain)
            // Reload the sites list
            await loadPlausibleSites()
        } catch {
            showError(error)
        }
    }

    func deletePlausibleSite(_ site: PlausibleSite) async {
        // Remove from local storage only (Sites API v1 not available with Stats API key)
        plausibleAPI.removeSite(domain: site.domain)
        plausibleSites.removeAll { $0.domain == site.domain }
    }

    func getPlausibleTrackingCode(domain: String) -> String {
        plausibleAPI.getTrackingCode(domain: domain)
    }

    func createPlausibleSharedLink(domain: String) async throws -> PlausibleSharedLink {
        try await plausibleAPI.createOrGetSharedLink(domain: domain)
    }

    private func showError(_ error: Error) {
        // Ignore cancelled errors (can happen during pull-to-refresh)
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return
        }
        errorMessage = error.localizedDescription
        showError = true
    }
}

// MARK: - Edit Website Sheet

struct EditWebsiteSheet: View {
    let website: Website
    @ObservedObject var viewModel: AdminViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var isUpdating = false

    init(website: Website, viewModel: AdminViewModel) {
        self.website = website
        self.viewModel = viewModel
        _name = State(initialValue: website.name)
    }

    var teamName: String? {
        viewModel.teams.first(where: { $0.id == website.teamId })?.name
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("admin.details") {
                    TextField("Name", text: $name)
                    Text(website.displayDomain)
                        .foregroundStyle(.secondary)
                }

                if let teamName = teamName {
                    Section {
                        Text(teamName)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("admin.websites.team")
                    } footer: {
                        Text("admin.websites.team.hint")
                    }
                }
            }
            .navigationTitle("admin.websites.edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("button.save") {
                        Task {
                            isUpdating = true
                            await viewModel.updateWebsite(website, name: name)
                            isUpdating = false
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || isUpdating)
                }
            }
        }
    }
}

// MARK: - Team Member Sheet

struct TeamMemberSheet: View {
    let team: Team
    @ObservedObject var viewModel: AdminViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedUserId: String?
    @State private var selectedRole: String = "team-member"
    @State private var isAdding = false

    var availableUsers: [UmamiUser] {
        viewModel.users.filter { user in
            !viewModel.isUserInTeam(userId: user.id, teamId: team.id)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if !availableUsers.isEmpty {
                    Section("admin.teams.members.add") {
                        Picker("admin.teams.members.user", selection: $selectedUserId) {
                            Text("admin.teams.members.select").tag(nil as String?)
                            ForEach(availableUsers) { user in
                                Text(user.username).tag(user.id as String?)
                            }
                        }

                        Picker("admin.teams.role", selection: $selectedRole) {
                            Text("admin.teams.role.member").tag("team-member")
                            Text("admin.teams.role.manager").tag("team-manager")
                            Text("admin.teams.role.viewonly").tag("team-view-only")
                        }

                        Button {
                            guard let userId = selectedUserId else { return }
                            Task {
                                isAdding = true
                                await viewModel.addTeamMember(teamId: team.id, userId: userId, role: selectedRole)
                                selectedUserId = nil
                                isAdding = false
                            }
                        } label: {
                            HStack {
                                if isAdding {
                                    ProgressView()
                                } else {
                                    Image(systemName: "person.badge.plus")
                                    Text("button.add")
                                }
                            }
                        }
                        .disabled(selectedUserId == nil || isAdding)
                    }
                }

                Section("admin.teams.members.current") {
                    if let members = viewModel.getTeamMembers(teamId: team.id) {
                        ForEach(members, id: \.id) { member in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(member.user?.username ?? String(localized: "device.unknown"))
                                        .font(.subheadline)
                                    Text(memberRoleDisplayName(member.role))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if member.role != "team-owner" {
                                    Button(role: .destructive) {
                                        Task {
                                            await viewModel.removeTeamMember(teamId: team.id, userId: member.userId)
                                        }
                                    } label: {
                                        Image(systemName: "person.badge.minus")
                                    }
                                }
                            }
                        }
                    } else {
                        Text("admin.teams.members.none")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("admin.teams.members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("button.done") { dismiss() }
                }
            }
        }
    }

    private func memberRoleDisplayName(_ role: String) -> String {
        switch role {
        case "team-owner": return String(localized: "admin.teams.role.owner")
        case "team-manager": return String(localized: "admin.teams.role.manager")
        case "team-member": return String(localized: "admin.teams.role.member")
        case "team-view-only": return String(localized: "admin.teams.role.viewonly")
        default: return role
        }
    }
}

// MARK: - ViewModel Extensions

extension AdminViewModel {
    func isUserInTeam(userId: String, teamId: String) -> Bool {
        guard let team = teams.first(where: { $0.id == teamId }) else { return false }
        return team.members?.contains(where: { $0.userId == userId }) ?? false
    }

    func getTeamMembers(teamId: String) -> [TeamMember]? {
        teams.first(where: { $0.id == teamId })?.members
    }
}

// MARK: - User Extension for localized role

extension UmamiUser {
    var localizedRoleDisplayName: String {
        if isAdmin {
            return String(localized: "admin.users.role.admin")
        } else {
            return String(localized: "admin.users.role.user")
        }
    }
}

#Preview {
    AdminView()
}
