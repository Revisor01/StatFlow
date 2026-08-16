import Foundation

struct Website: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let domain: String?
    let shareId: String?
    let teamId: String?
    let resetAt: Date?
    let createdAt: Date?

    /// Name des Teams, dem die Website gehört. Kommt nicht vom Server, sondern
    /// wird beim Laden ergänzt, damit die Übersicht die Herkunft anzeigen kann.
    var teamName: String?

    var displayDomain: String {
        domain ?? name
    }

    init(
        id: String,
        name: String,
        domain: String?,
        shareId: String?,
        teamId: String?,
        resetAt: Date?,
        createdAt: Date?,
        teamName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.domain = domain
        self.shareId = shareId
        self.teamId = teamId
        self.resetAt = resetAt
        self.createdAt = createdAt
        self.teamName = teamName
    }
}

struct WebsiteResponse: Codable, Sendable {
    let data: [Website]?
    let count: Int?

    var websites: [Website] {
        data ?? []
    }
}
