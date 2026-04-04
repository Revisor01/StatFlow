import Foundation

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var websites: [Website] = []
    @Published var websitesByAccount: [(account: AnalyticsAccount, websites: [Website])] = []

    private var loadingTask: Task<Void, Never>?
    private let umamiAPI = UmamiAPI.shared
    private let plausibleAPI = PlausibleAPI.shared

    func loadWebsites() async {
        loadingTask?.cancel()
        let task = Task {
            var result: [(account: AnalyticsAccount, websites: [Website])] = []
            let accounts = AccountManager.shared.accounts

            for account in accounts {
                guard !Task.isCancelled else { return }
                var accountWebsites: [Website] = []
                do {
                    switch account.providerType {
                    case .umami:
                        guard let token = account.credentials.token,
                              let url = URL(string: account.serverURL) else { continue }
                        await umamiAPI.configure(baseURL: url, token: token)
                        accountWebsites = try await umamiAPI.getWebsites()
                        guard !Task.isCancelled else { return }

                    case .plausible:
                        guard let sites = account.sites, !sites.isEmpty else { continue }
                        guard let apiKey = account.credentials.apiKey else { continue }
                        try? KeychainService.save(account.serverURL, for: .serverURL)
                        try? KeychainService.save(apiKey, for: .apiKey)
                        await plausibleAPI.reconfigureFromKeychain()
                        let plausibleSites = try await plausibleAPI.getAnalyticsWebsites()
                        guard !Task.isCancelled else { return }
                        accountWebsites = plausibleSites.map { site in
                            Website(id: site.id, name: site.name, domain: site.domain, shareId: nil, teamId: nil, resetAt: nil, createdAt: nil)
                        }
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                    #if DEBUG
                    print("Failed to load websites for account \(account.displayName): \(error)")
                    #endif
                }

                if !accountWebsites.isEmpty {
                    result.append((account: account, websites: accountWebsites))
                }
            }

            guard !Task.isCancelled else { return }
            websitesByAccount = result
            // Flat-Liste fuer Kompatibilitaet
            websites = result.flatMap { $0.websites }
        }
        loadingTask = task
        await task.value
    }
}
