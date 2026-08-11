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

/// Filter-Operatoren der Plausible Query API v2.
/// Belegt in priv/json-schemas/query-api-schema.json (Tag v3.2.1):
/// filter_with_is ("is"), filter_with_contains ("contains"),
/// filter_operation_without_goals ("is_not", "contains_not"),
/// filter_operation_regex ("matches", "matches_not"),
/// filter_operation_wildcard ("matches_wildcard", "matches_wildcard_not").
enum PlausibleFilterOperator: String, Sendable {
    case is_ = "is"
    case isNot = "is_not"
    case contains = "contains"
    /// Plausible v2 heißt der Operator "contains_not".
    /// "does_not_contain" wird vom Schema abgelehnt.
    case doesNotContain = "contains_not"
    case matches = "matches"
    case matchesNot = "matches_not"
    case matchesWildcard = "matches_wildcard"
    case matchesWildcardNot = "matches_wildcard_not"

    /// Nur "is"/"is_not"/"contains"/"contains_not" akzeptieren laut Schema
    /// den vierten Eintrag mit { "case_sensitive": Bool }.
    /// Regex- und Wildcard-Filter sind auf maxItems 3 begrenzt.
    var supportsCaseSensitiveModifier: Bool {
        switch self {
        case .is_, .isNot, .contains, .doesNotContain:
            return true
        case .matches, .matchesNot, .matchesWildcard, .matchesWildcardNot:
            return false
        }
    }
}

/// Behavioral-Filter aus Plausible CE 3.x (filter_has_done im JSON-Schema).
/// Umschließt genau EINEN weiteren Filter, z. B.
/// ["has_done", ["is", "event:goal", ["Signup"]]]
enum PlausibleBehavioralOperator: String, Sendable {
    case hasDone = "has_done"
    case hasNotDone = "has_not_done"
}

// MARK: - Goal Conversion

struct GoalConversion: Identifiable, Sendable {
    let id = UUID()
    let goalName: String
    let visitors: Int
    let events: Int
}

struct PlausibleQueryFilter: Sendable {
    let dimension: String
    let operator_: PlausibleFilterOperator
    let values: [String]

    /// Groß-/Kleinschreibung beachten. `nil` = Feld weglassen (Plausible-Default: true).
    /// Wird nur für is/is_not/contains/contains_not serialisiert.
    let caseSensitive: Bool?

    /// Wenn gesetzt, wird dieser Filter als Behavioral-Filter umschlossen:
    /// ["has_done", ["is", "event:goal", ["Signup"]]]
    let behavioral: PlausibleBehavioralOperator?

    init(
        dimension: String,
        operator_: PlausibleFilterOperator,
        values: [String],
        caseSensitive: Bool? = nil,
        behavioral: PlausibleBehavioralOperator? = nil
    ) {
        self.dimension = dimension
        self.operator_ = operator_
        self.values = values
        self.caseSensitive = caseSensitive
        self.behavioral = behavioral
    }

    /// Behavioral-Filter bequem erzeugen: "Besucher, die Goal X ausgelöst haben".
    static func hasDone(
        dimension: String = "event:goal",
        operator_: PlausibleFilterOperator = .is_,
        values: [String],
        caseSensitive: Bool? = nil
    ) -> PlausibleQueryFilter {
        PlausibleQueryFilter(dimension: dimension, operator_: operator_, values: values,
                             caseSensitive: caseSensitive, behavioral: .hasDone)
    }

    /// Gegenstück: "Besucher, die Goal X NICHT ausgelöst haben".
    static func hasNotDone(
        dimension: String = "event:goal",
        operator_: PlausibleFilterOperator = .is_,
        values: [String],
        caseSensitive: Bool? = nil
    ) -> PlausibleQueryFilter {
        PlausibleQueryFilter(dimension: dimension, operator_: operator_, values: values,
                             caseSensitive: caseSensitive, behavioral: .hasNotDone)
    }

    /// Der innere, einfache Filter: ["is", "visit:source", ["Google"]]
    /// plus optionalem Modifier-Objekt als viertem Eintrag.
    private func simpleForm() -> [Any] {
        var parts: [Any] = [operator_.rawValue, dimension, values]
        // Modifier nur anhängen, wenn der Operator ihn laut Schema erlaubt.
        if let caseSensitive, operator_.supportsCaseSensitiveModifier {
            parts.append(["case_sensitive": caseSensitive])
        }
        return parts
    }

    /// Serialisiert in das Plausible-v2-Filterformat.
    /// Einfach:     ["is", "visit:source", ["Google"]]
    /// Mit Modifier:["contains", "event:page", ["/Blog"], {"case_sensitive": false}]
    /// Behavioral:  ["has_done", ["is", "event:goal", ["Signup"]]]
    func toQueryParam() -> [Any] {
        guard let behavioral else { return simpleForm() }
        return [behavioral.rawValue, simpleForm()]
    }
}
