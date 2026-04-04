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

    enum CodingKeys: String, CodingKey {
        case type, value, startDate, endDate, steps, window, model, step
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        value = try container.decodeIfPresent(String.self, forKey: .value)
        startDate = try container.decodeIfPresent(String.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(String.self, forKey: .endDate)
        window = try container.decodeIfPresent(Int.self, forKey: .window)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        step = try container.decodeIfPresent(String.self, forKey: .step)

        // steps can be [[String: String]] (funnel) or Int (journey) — handle both
        if let stepsArray = try? container.decodeIfPresent([[String: String]].self, forKey: .steps) {
            steps = stepsArray
        } else {
            steps = nil
        }
    }
}

// MARK: - Funnel Report

struct FunnelStep: Codable, Identifiable, Sendable {
    let type: String       // "path" or "event"
    let value: String
    let visitors: Int
    let previous: Int?
    let dropped: Int?
    let dropoff: Double?    // API returns null for first step, fraction for others
    let remaining: Double?

    var id: String { "\(type)-\(value)" }

    var dropoffRate: Double {
        dropoff ?? 0
    }

    var droppedCount: Int {
        dropped ?? 0
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
struct GoalReportItem: Identifiable, Sendable {
    let type: String       // "path" or "event"
    let value: String
    let name: String       // Display name from report definition
    let goal: Int          // total visitors in period
    let result: Int        // visitors who triggered the goal

    var id: String { "\(type)-\(value)" }

    var completionRate: Double {
        guard goal > 0 else { return 0 }
        return Double(result) / Double(goal)
    }
}

// MARK: - Attribution Report

struct AttributionResponse: Codable, Sendable {
    let referrer: [AttributionEntry]?
    let paidAds: [AttributionEntry]?
    let utm_source: [AttributionEntry]?
    let utm_medium: [AttributionEntry]?
    let utm_campaign: [AttributionEntry]?
    let utm_content: [AttributionEntry]?
    let utm_term: [AttributionEntry]?
    let total: AttributionTotal?
}

struct AttributionEntry: Codable, Identifiable, Sendable {
    let name: String
    let value: Int

    var id: String { name }
}

struct AttributionTotal: Codable, Sendable {
    let pageviews: Int?
    let visitors: Int?
    let visits: Int?
}

/// Flat item for display in the UI
struct AttributionItem: Identifiable, Sendable {
    let category: String   // "Referrer", "Paid Ads", etc.
    let name: String
    let count: Int

    var id: String { "\(category)-\(name)" }
}


