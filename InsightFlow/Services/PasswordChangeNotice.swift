import Foundation

/// Merkt sich Konten, für die Umami (ab 3.5) beim Login noch das Standardpasswort meldet.
enum PasswordChangeNotice {
    static let storageKey = "umami.passwordChangeNotice"

    /// Kommagetrennte Konto-IDs, damit `@AppStorage` die Liste direkt beobachten kann.
    static func accountIds(in raw: String) -> Set<String> {
        Set(raw.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }

    static func updated(_ raw: String, accountId: UUID, required: Bool) -> String {
        var ids = accountIds(in: raw)
        if required {
            ids.insert(accountId.uuidString)
        } else {
            ids.remove(accountId.uuidString)
        }
        return ids.sorted().joined(separator: ",")
    }

    static func isMarked(_ raw: String, accountId: UUID) -> Bool {
        accountIds(in: raw).contains(accountId.uuidString)
    }

    static func record(accountId: UUID, required: Bool, defaults: UserDefaults = .standard) {
        let raw = defaults.string(forKey: storageKey) ?? ""
        defaults.set(updated(raw, accountId: accountId, required: required), forKey: storageKey)
    }
}
