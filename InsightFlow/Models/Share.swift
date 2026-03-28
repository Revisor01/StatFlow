import Foundation

// MARK: - Share Page Models

struct SharePage: Codable, Identifiable, Sendable {
    let id: String
    let entityId: String
    let shareType: Int     // 1=website, 2=link, 3=pixel, 4=board
    let name: String
    let slug: String
    let parameters: String?  // JSON string
    let createdAt: String
    let updatedAt: String?
}

struct ShareListResponse: Codable, Sendable {
    let data: [SharePage]
    let count: Int
}

// MARK: - Me (Current User) Models

struct MeResponse: Codable, Sendable {
    let id: String
    let username: String
    let role: String
    let createdAt: String?
}
