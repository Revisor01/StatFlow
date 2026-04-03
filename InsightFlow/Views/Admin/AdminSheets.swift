import SwiftUI

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
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await viewModel.createWebsite(name: name, domain: domain)
                            dismiss()
                        }
                    } label: { Image(systemName: "checkmark") }
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
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await viewModel.createTeam(name: name)
                            // Reload teams to ensure data is up to date
                            await viewModel.loadTeams()
                            dismiss()
                        }
                    } label: { Image(systemName: "checkmark") }
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
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await viewModel.createUser(username: username, password: password, role: role)
                            dismiss()
                        }
                    } label: { Image(systemName: "checkmark") }
                    .disabled(username.isEmpty || password.isEmpty)
                }
            }
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
                    Button { dismiss() } label: { Image(systemName: "checkmark") }
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
                    Button { dismiss() } label: { Image(systemName: "checkmark") }
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
                    Button { dismiss() } label: { Image(systemName: "checkmark") }
                }
            }
        }
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
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            isUpdating = true
                            await viewModel.updateWebsite(website, name: name)
                            isUpdating = false
                            dismiss()
                        }
                    } label: { Image(systemName: "checkmark") }
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
                    Button { dismiss() } label: { Image(systemName: "checkmark") }
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
