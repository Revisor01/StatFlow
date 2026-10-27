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

/// Filter-Operatoren der Plausible Query API v2 (query-api-schema.json, v3.2.1).
enum PlausibleFilterOperator: String, Sendable {
    case is_ = "is"
    case isNot = "is_not"
    case contains = "contains"
    /// Plausible v2 heißt "contains_not", "does_not_contain" lehnt das Schema ab.
    case doesNotContain = "contains_not"
    case matches = "matches"
    case matchesNot = "matches_not"
    case matchesWildcard = "matches_wildcard"
    case matchesWildcardNot = "matches_wildcard_not"

    /// Nur is/is_not/contains/contains_not erlauben den vierten Eintrag { "case_sensitive": Bool }.
    var supportsCaseSensitiveModifier: Bool {
        switch self {
        case .is_, .isNot, .contains, .doesNotContain:
            return true
        case .matches, .matchesNot, .matchesWildcard, .matchesWildcardNot:
            return false
        }
    }
}

/// Behavioral-Filter (filter_has_done), umschließt genau einen Filter: ["has_done", ["is", "event:goal", ["Signup"]]].
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

    /// Conversion-Rate in Prozent, nur mit event:goal als Dimension oder Filter abfragbar; nil ohne Wert.
    let conversionRate: Double?

    /// Conversion-Rate innerhalb der Dimensionsgruppe (0–100).
    let groupConversionRate: Double?

    /// Defaults halten bestehende Aufrufer ohne Conversion-Rate gültig.
    init(
        goalName: String,
        visitors: Int,
        events: Int,
        conversionRate: Double? = nil,
        groupConversionRate: Double? = nil
    ) {
        self.goalName = goalName
        self.visitors = visitors
        self.events = events
        self.conversionRate = conversionRate
        self.groupConversionRate = groupConversionRate
    }
}

struct PlausibleQueryFilter: Sendable {
    let dimension: String
    let operator_: PlausibleFilterOperator
    let values: [String]

    /// Groß-/Kleinschreibung beachten; nil lässt das Feld weg, nur für is/is_not/contains/contains_not.
    let caseSensitive: Bool?

    /// Wenn gesetzt, wird der Filter als Behavioral-Filter umschlossen.
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

    /// Der innere Filter, etwa ["is", "visit:source", ["Google"]], mit optionalem Modifier.
    private func simpleForm() -> [Any] {
        var parts: [Any] = [operator_.rawValue, dimension, values]
        // Modifier nur anhängen, wenn der Operator ihn laut Schema erlaubt.
        if let caseSensitive, operator_.supportsCaseSensitiveModifier {
            parts.append(["case_sensitive": caseSensitive])
        }
        return parts
    }

    /// Serialisiert ins Plausible-v2-Format, etwa ["contains", "event:page", ["/Blog"], {"case_sensitive": false}].
    func toQueryParam() -> [Any] {
        guard let behavioral else { return simpleForm() }
        return [behavioral.rawValue, simpleForm()]
    }
}
