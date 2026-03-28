import Foundation
import SwiftUI
import WidgetKit
import Combine

@MainActor
class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var serverURL: String = ""
    @Published var username: String = ""
    @Published var currentProvider: AnalyticsProviderType?

    private let umamiAPI = UmamiAPI.shared
    private let plausibleAPI = PlausibleAPI.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadStoredCredentials()
        setupNotifications()
    }

    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .allAccountsRemoved)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleAllAccountsRemoved()
            }
            .store(in: &cancellables)
    }

    private func handleAllAccountsRemoved() {
        isAuthenticated = false
        serverURL = ""
        username = ""
        currentProvider = nil
    }

    private func loadStoredCredentials() {
        // Check for provider type first
        if let providerTypeString = KeychainService.load(for: .providerType),
           let providerType = AnalyticsProviderType(rawValue: providerTypeString) {
            currentProvider = providerType

            switch providerType {
            case .umami:
                loadUmamiCredentials()
            case .plausible:
                loadPlausibleCredentials()
            }
        } else {
            // Legacy: try loading Umami credentials
            loadUmamiCredentials()
        }
    }

    private func loadUmamiCredentials() {
        guard let serverURLString = KeychainService.load(for: .serverURL),
              let token = KeychainService.load(for: .token),
              let url = URL(string: serverURLString) else {
            return
        }

        serverURL = serverURLString
        username = KeychainService.load(for: .username) ?? ""
        currentProvider = .umami

        // Also save to shared file for widget
        SharedCredentials.save(serverURL: serverURLString, token: token)

        Task {
            await umamiAPI.configure(baseURL: url, token: token)
            AnalyticsManager.shared.setProvider(umamiAPI)
            isAuthenticated = true
        }
    }

    private func loadPlausibleCredentials() {
        guard let serverURLString = KeychainService.load(for: .serverURL),
              let apiKey = KeychainService.load(for: .apiKey) else {
            return
        }

        serverURL = serverURLString
        currentProvider = .plausible

        // Save to shared file for widget (with Plausible sites)
        Task { @MainActor in
            let sites = PlausibleSitesManager.shared.getSites()
            SharedCredentials.save(
                serverURL: serverURLString,
                token: apiKey,
                providerType: .plausible,
                sites: sites
            )
            WidgetCenter.shared.reloadAllTimelines()
        }

        Task {
            AnalyticsManager.shared.setProvider(plausibleAPI)
            isAuthenticated = true
        }
    }

    // MARK: - Umami Login

    func login(serverURL: String, username: String, password: String, accountName: String = "") async {
        guard let url = URL(string: serverURL) else {
            errorMessage = String(localized: "error.invalidURL")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let token = try await umamiAPI.login(baseURL: url, username: username, password: password)

            // Save to Keychain (for app)
            try KeychainService.save(serverURL, for: .serverURL)
            try KeychainService.save(token, for: .token)
            try KeychainService.save(username, for: .username)
            try KeychainService.save(AnalyticsProviderType.umami.rawValue, for: .providerType)

            // Save to shared file (for widget)
            SharedCredentials.save(serverURL: serverURL, token: token)

            await umamiAPI.configure(baseURL: url, token: token)
            AnalyticsManager.shared.setProvider(umamiAPI)

            self.serverURL = serverURL
            self.username = username
            self.currentProvider = .umami
            isAuthenticated = true

            // Create account in AccountManager for multi-account support
            let account = AnalyticsAccount(
                name: accountName,
                serverURL: serverURL,
                providerType: .umami,
                credentials: AccountCredentials(token: token, apiKey: nil)
            )
            AccountManager.shared.addAccount(account)

            // Refresh widget
            WidgetCenter.shared.reloadAllTimelines()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Plausible Login

    func loginWithPlausible(serverURL: String, apiKey: String, accountName: String = "") async {
        isLoading = true
        errorMessage = nil

        do {
            try await plausibleAPI.authenticate(
                serverURL: serverURL,
                credentials: .plausible(apiKey: apiKey)
            )

            AnalyticsManager.shared.setProvider(plausibleAPI)

            self.serverURL = serverURL
            self.currentProvider = .plausible
            isAuthenticated = true

            // Save to shared file for widget
            let sites = PlausibleSitesManager.shared.getSites()
            SharedCredentials.save(
                serverURL: serverURL,
                token: apiKey,
                providerType: .plausible,
                sites: sites
            )

            // Create account in AccountManager for multi-account support
            let account = AnalyticsAccount(
                name: accountName,
                serverURL: serverURL,
                providerType: .plausible,
                credentials: AccountCredentials(token: nil, apiKey: apiKey),
                sites: sites
            )
            AccountManager.shared.addAccount(account)

            // Refresh widget
            WidgetCenter.shared.reloadAllTimelines()
        } catch let error as PlausibleError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Logout

    func logout() {
        KeychainService.deleteAll()
        SharedCredentials.delete()
        AnalyticsManager.shared.logout()

        Task { @MainActor in
            await umamiAPI.clearConfiguration()
            PlausibleSitesManager.shared.clearAll()
        }

        isAuthenticated = false
        serverURL = ""
        username = ""
        currentProvider = nil
        WidgetCenter.shared.reloadAllTimelines()
    }
}
