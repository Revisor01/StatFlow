import Foundation

@MainActor
class LoginViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// Wird gesetzt, sobald Umami für den Login einen zweiten Faktor verlangt.
    /// Die View blendet daraufhin die Code-Eingabe ein.
    @Published var requiresTwoFactor = false

    private let umamiAPI: UmamiAPI
    private let plausibleAPI: PlausibleAPI

    /// Zwischenstand des zweistufigen Logins: Der `partialToken` ist nur wenige
    /// Minuten gültig, die übrigen Werte brauchen wir erst beim Anlegen des Accounts.
    private var pendingTwoFactor: (partialToken: String, url: URL, serverURL: String, username: String, accountName: String)?

    init(umamiAPI: UmamiAPI = .shared, plausibleAPI: PlausibleAPI = .shared) {
        self.umamiAPI = umamiAPI
        self.plausibleAPI = plausibleAPI
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
            let result = try await umamiAPI.login(baseURL: url, username: username, password: password)

            switch result {
            case .token(let token):
                await createAccount(
                    token: token,
                    serverURL: serverURL,
                    username: username,
                    accountName: accountName
                )
            case .twoFactorRequired(let partialToken):
                pendingTwoFactor = (partialToken, url, serverURL, username, accountName)
                requiresTwoFactor = true
            }
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Zweiter Schritt des Logins: TOTP- oder Backup-Code einlösen.
    func submitTwoFactorCode(_ code: String, isBackupCode: Bool = false) async {
        guard let pending = pendingTwoFactor else {
            errorMessage = String(localized: "error.auth")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let token = try await umamiAPI.verifyTwoFactor(
                baseURL: pending.url,
                partialToken: pending.partialToken,
                code: code,
                isBackupCode: isBackupCode
            )

            await createAccount(
                token: token,
                serverURL: pending.serverURL,
                username: pending.username,
                accountName: pending.accountName
            )
            cancelTwoFactor()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Bricht die Code-Eingabe ab und kehrt zur Anmeldemaske zurück.
    func cancelTwoFactor() {
        pendingTwoFactor = nil
        requiresTwoFactor = false
    }

    private func createAccount(token: String, serverURL: String, username: String, accountName: String) async {
        let account = AnalyticsAccount(
            name: accountName.isEmpty ? username : accountName,
            serverURL: serverURL,
            providerType: .umami,
            credentials: AccountCredentials(token: token, apiKey: nil)
        )
        AccountManager.shared.addAccount(account)
        await AccountManager.shared.setActiveAccount(account)
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

            let sites = PlausibleSitesManager.shared.getSites()
            let account = AnalyticsAccount(
                name: accountName.isEmpty ? "Plausible" : accountName,
                serverURL: serverURL,
                providerType: .plausible,
                credentials: AccountCredentials(token: nil, apiKey: apiKey),
                sites: sites
            )
            AccountManager.shared.addAccount(account)
            await AccountManager.shared.setActiveAccount(account)
        } catch let error as PlausibleError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
