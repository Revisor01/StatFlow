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
