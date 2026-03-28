import Foundation

// MARK: - Plausible Goal Models

struct PlausibleGoal: Codable, Sendable, Identifiable {
    let id: Int
    let goalType: String
    let eventName: String?
    let pagePath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case goalType = "goal_type"
        case eventName = "event_name"
        case pagePath = "page_path"
    }

    var displayName: String {
        eventName ?? pagePath ?? "Unknown"
    }
}

struct PlausibleGoalsResponse: Codable, Sendable {
    let goals: [PlausibleGoal]
}

enum PlausibleGoalType: String, Codable, Sendable {
    case event = "event"
    case page = "page"
}

// MARK: - Plausible Query Filter

enum PlausibleFilterOperator: String, Sendable {
    case is_ = "is"
    case isNot = "is_not"
    case contains = "contains"
    case doesNotContain = "does_not_contain"
    case matches = "matches"
    case matchesNot = "matches_not"
}

struct PlausibleQueryFilter: Sendable {
    let dimension: String
    let operator_: PlausibleFilterOperator
    let values: [String]

    /// Converts to Plausible v2 Query API filter format: ["is", "visit:source", ["Google"]]
    func toQueryParam() -> [Any] {
        [operator_.rawValue, dimension, values]
    }
}
