import SwiftUI

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
