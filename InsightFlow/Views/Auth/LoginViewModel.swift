import Foundation

@MainActor
class LoginViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// Gesetzt, sobald Umami einen zweiten Faktor verlangt; die View zeigt dann die Code-Eingabe.
    @Published var requiresTwoFactor = false

    private let umamiAPI: UmamiAPI
    private let plausibleAPI: PlausibleAPI

    /// Zwischenstand des zweistufigen Logins; der `partialToken` gilt nur wenige Minuten.
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

    /// Anmeldung an Umami Cloud; der Schlüssel liegt wie das self-hosted-Token, damit Widget und Kontowechsel gleich bleiben.
    func loginWithUmamiCloud(apiKey: String, accountName: String = "") async {
        isLoading = true
        errorMessage = nil

        do {
            try await umamiAPI.authenticate(
                serverURL: UmamiAPI.cloudBaseURL,
                credentials: .umamiCloud(apiKey: apiKey)
            )

            let account = AnalyticsAccount(
                name: accountName.isEmpty ? "Umami Cloud" : accountName,
                serverURL: UmamiAPI.cloudBaseURL,
                providerType: .umami,
                credentials: AccountCredentials(token: apiKey, apiKey: nil)
            )
            AccountManager.shared.addAccount(account)
            await AccountManager.shared.setActiveAccount(account)
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Anmeldung an einer eigenen Instanz per API-Schlüssel (ab 3.4), gesendet als Bearer.
    func loginWithUmamiSelfHostedKey(serverURL: String, apiKey: String, accountName: String = "") async {
        guard URL(string: serverURL) != nil else {
            errorMessage = String(localized: "error.invalidURL")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await umamiAPI.authenticate(
                serverURL: serverURL,
                credentials: .umamiSelfHostedKey(apiKey: apiKey)
            )

            let host = URL(string: serverURL)?.host ?? serverURL
            let account = AnalyticsAccount(
                name: accountName.isEmpty ? host : accountName,
                serverURL: serverURL,
                providerType: .umami,
                // Schlüssel im Feld `token`, damit Widget-Sync und Kontowechsel gleich bleiben.
                credentials: AccountCredentials(token: apiKey, apiKey: nil)
            )
            AccountManager.shared.addAccount(account)
            await AccountManager.shared.setActiveAccount(account)
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

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
