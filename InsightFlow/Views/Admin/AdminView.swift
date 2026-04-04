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
                // LazyVStack: intentional — homogeneous ForEach, list can grow large
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
                // LazyVStack: intentional — homogeneous ForEach, list can grow large
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
                VStack(spacing: 12) {
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
                VStack(spacing: 12) {
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
