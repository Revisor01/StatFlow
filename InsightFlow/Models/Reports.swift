import Foundation

// MARK: - Report List

struct Report: Codable, Identifiable, Sendable {
    let id: String
    let userId: String
    let websiteId: String
    let type: String         // "funnel", "utm", "goals", "attribution"
    let name: String
    let description: String?
    let parameters: String?  // JSON string
    let createdAt: String
    let updatedAt: String?
}

struct ReportListResponse: Codable, Sendable {
    let data: [Report]
    let count: Int
    let page: Int
    let pageSize: Int
}

// MARK: - Funnel Report

struct FunnelStep: Codable, Identifiable, Sendable {
    let type: String       // "path" or "event"
    let value: String
    let visitors: Int
    let dropoff: Int

    var id: String { value }

    var dropoffRate: Double {
        guard visitors + dropoff > 0 else { return 0 }
        return Double(dropoff) / Double(visitors + dropoff)
    }
}

// MARK: - UTM Report

struct UTMReportItem: Codable, Identifiable, Sendable {
    let source: String?
    let medium: String?
    let campaign: String?
    let content: String?
    let term: String?
    let visitors: Int

    var id: String {
        [source, medium, campaign].compactMap { $0 }.joined(separator: "/")
    }
}

// MARK: - Goal Report

struct GoalReportItem: Codable, Identifiable, Sendable {
    let type: String       // "path" or "event"
    let value: String
    let goal: Int
    let result: Int

    var id: String { value }

    var completionRate: Double {
        guard goal > 0 else { return 0 }
        return Double(result) / Double(goal)
    }
}

// MARK: - Attribution Report

struct AttributionItem: Codable, Identifiable, Sendable {
    let source: String?
    let medium: String?
    let campaign: String?
    let channel: String?
    let visitors: Int

    var id: String {
        [channel, source, medium, campaign].compactMap { $0 }.joined(separator: "/")
    }
}
