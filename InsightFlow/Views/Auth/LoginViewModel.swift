import Foundation

@MainActor
class LoginViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Umami Login

    func login(serverURL: String, username: String, password: String, accountName: String = "") async {
        guard let url = URL(string: serverURL) else {
            errorMessage = String(localized: "error.invalidURL")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let token = try await UmamiAPI.shared.login(baseURL: url, username: username, password: password)

            let account = AnalyticsAccount(
                name: accountName.isEmpty ? username : accountName,
                serverURL: serverURL,
                providerType: .umami,
                credentials: AccountCredentials(token: token, apiKey: nil)
            )
            AccountManager.shared.addAccount(account)
            AccountManager.shared.setActiveAccount(account)
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
            try await PlausibleAPI.shared.authenticate(
                serverURL: serverURL,
                credentials: .plausible(apiKey: apiKey)
            )

            let sites = PlausibleSitesManager.shared.getSites()
            let account = AnalyticsAccount(
                name: accountName.isEmpty ? "Plausible" : accountName,
                serverURL: serverURL,
                providerType: .plausible,
                credentials: AccountCredentials(token: nil, apiKey: apiKey),
                sites: sites
            )
            AccountManager.shared.addAccount(account)
            AccountManager.shared.setActiveAccount(account)
        } catch let error as PlausibleError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
