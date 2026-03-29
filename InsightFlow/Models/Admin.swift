import Foundation

// MARK: - Team Models

struct Team: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let accessCode: String?
    let createdAt: Date?
    let members: [TeamMember]?
}

struct TeamsResponse: Codable, Sendable {
    let data: [Team]
    let count: Int
}

struct TeamCreateResponse: Codable, Sendable {
    let id: String
    let name: String
    let accessCode: String?
    let logoUrl: String?
    let createdAt: Date?
    let updatedAt: Date?
    let deletedAt: Date?
}

struct TeamMember: Codable, Identifiable, Sendable {
    let id: String
    let userId: String
    let teamId: String
    let role: String
    let user: TeamMemberUser?

    struct TeamMemberUser: Codable, Sendable {
        let id: String
        let username: String
    }
}

struct TeamMembersResponse: Codable, Sendable {
    let data: [TeamMember]
}

// MARK: - User Models

struct UmamiUser: Codable, Identifiable, Sendable {
    let id: String
    let username: String
    let role: String
    let createdAt: Date?

    var isAdmin: Bool {
        role == "admin"
    }

    var roleDisplayName: String {
        switch role {
        case "admin": return "Administrator"
        case "user": return "Benutzer"
        default: return role
        }
    }
}

struct UsersResponse: Codable, Sendable {
    let data: [UmamiUser]
    let count: Int
}

// MARK: - Journey Models

struct JourneyPath: Codable, Identifiable, Sendable {
    let items: [String?]
    let count: Int

    var id: String {
        items.compactMap { $0 }.joined(separator: "→") + "-\(count)"
    }

    /// Nur die nicht-nil Pfade
    var paths: [String] {
        items.compactMap { $0 }
    }

    /// Formatierter Pfad für Anzeige
    var displayPath: String {
        paths.joined(separator: " → ")
    }

    /// Anzahl der Schritte
    var stepCount: Int {
        paths.count
    }
}
