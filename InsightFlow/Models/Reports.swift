import Foundation

// MARK: - Report CRUD Models

struct ReportListResponse: Codable, Sendable {
    let data: [Report]
    let count: Int
    let page: Int
    let pageSize: Int
}

struct Report: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let userId: String
    let websiteId: String
    let type: String
    let name: String
    let description: String?
    let parameters: ReportParameters?
    let createdAt: String
    let updatedAt: String?
}

struct ReportParameters: Codable, Sendable, Hashable {
    let type: String?
    let value: String?
    let startDate: String?
    let endDate: String?
    let steps: [[String: String]]?
    let window: Int?
    let model: String?
    let step: String?
}

// MARK: - Funnel Report

struct FunnelStep: Codable, Identifiable, Sendable {
    let type: String       // "path" or "event"
    let value: String
    let visitors: Int
    let dropoff: Int

    var id: String { "\(type)-\(value)" }

    var dropoffRate: Double {
        guard visitors + dropoff > 0 else { return 0 }
        return Double(dropoff) / Double(visitors + dropoff) * 100
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

    var id: String { "\(source ?? "")-\(medium ?? "")-\(campaign ?? "")" }
}

// MARK: - Goal Report

/// Result from /api/reports/goal — single goal query returns {num, total}
struct GoalReportResult: Codable, Sendable {
    let num: Int
    let total: Int

    var completionRate: Double {
        guard total > 0 else { return 0 }
        return Double(num) / Double(total) * 100
    }
}

/// Used in the UI to display goal data with metadata from the report definition
struct GoalReportItem: Codable, Identifiable, Sendable {
    let type: String       // "path" or "event"
    let value: String
    let goal: Int
    let result: Int

    var id: String { "\(type)-\(value)" }

    var completionRate: Double {
        guard goal > 0 else { return 0 }
        return Double(result) / Double(goal) * 100
    }
}

// MARK: - Attribution Report

struct AttributionItem: Codable, Identifiable, Sendable {
    let source: String?
    let medium: String?
    let campaign: String?
    let channel: String?
    let visitors: Int

    var id: String { "\(source ?? "")-\(channel ?? "")" }
}


