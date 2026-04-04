import os
import SwiftUI

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

    private var loadingTask: Task<Void, Never>?
    private let umamiAPI: UmamiAPI
    private let plausibleAPI: PlausibleAPI

    init(umamiAPI: UmamiAPI = .shared, plausibleAPI: PlausibleAPI = .shared) {
        self.umamiAPI = umamiAPI
        self.plausibleAPI = plausibleAPI
    }

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
        loadingTask?.cancel()
        let task = Task {
            isLoading = true
            defer { if !Task.isCancelled { isLoading = false } }

            if currentProvider == .plausible {
                await loadPlausibleSites()
            } else {
                await withTaskGroup(of: Void.self) { group in
                    group.addTask { await self.loadWebsites() }
                    group.addTask { await self.loadTeams() }
                    group.addTask { await self.loadUsers() }
                }
            }
        }
        loadingTask = task
        await task.value
    }

    // MARK: - Umami

    private func loadWebsites() async {
        do {
            let result = try await umamiAPI.getWebsites()
            guard !Task.isCancelled else { return }
            websites = result
        } catch {
            guard !Task.isCancelled else { return }
            showError(error)
        }
    }

    func loadTeams() async {
        do {
            let result = try await umamiAPI.getTeams()
            guard !Task.isCancelled else { return }
            teams = result
        } catch {
            guard !Task.isCancelled else { return }
            Logger.ui.error("Teams error: \(error.localizedDescription)")
        }
    }

    private func loadUsers() async {
        do {
            let result = try await umamiAPI.getUsers()
            guard !Task.isCancelled else { return }
            users = result
        } catch {
            guard !Task.isCancelled else { return }
            Logger.ui.error("Users error: \(error.localizedDescription)")
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
            guard !Task.isCancelled else { return }
            plausibleSites = analyticsWebsites.map { PlausibleSite(domain: $0.domain, timezone: nil) }
        } catch {
            guard !Task.isCancelled else { return }
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
        await plausibleAPI.removeSite(domain: site.domain)
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
