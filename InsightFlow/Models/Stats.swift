import Foundation

struct WebsiteStatsResponse: Codable, Sendable {
    let pageviews: Int
    let visitors: Int
    let visits: Int
    let bounces: Int
    let totaltime: Int
    let comparison: StatsComparison
}

struct StatsComparison: Codable, Sendable {
    let pageviews: Int
    let visitors: Int
    let visits: Int
    let bounces: Int
    let totaltime: Int
}

struct WebsiteStats: Sendable, Equatable {
    let pageviews: StatValue
    let visitors: StatValue
    let visits: StatValue
    let bounces: StatValue
    let totaltime: StatValue

    init(from response: WebsiteStatsResponse) {
        self.pageviews = StatValue(
            value: response.pageviews,
            change: response.pageviews - response.comparison.pageviews
        )
        self.visitors = StatValue(
            value: response.visitors,
            change: response.visitors - response.comparison.visitors
        )
        self.visits = StatValue(
            value: response.visits,
            change: response.visits - response.comparison.visits
        )
        self.bounces = StatValue(
            value: response.bounces,
            change: response.bounces - response.comparison.bounces
        )
        self.totaltime = StatValue(
            value: response.totaltime,
            change: response.totaltime - response.comparison.totaltime
        )
    }

    init(pageviews: StatValue, visitors: StatValue, visits: StatValue, bounces: StatValue, totaltime: StatValue) {
        self.pageviews = pageviews
        self.visitors = visitors
        self.visits = visits
        self.bounces = bounces
        self.totaltime = totaltime
    }

    var bounceRate: Double {
        guard visits.value > 0 else { return 0 }
        return Double(bounces.value) / Double(visits.value) * 100
    }

    var averageTime: TimeInterval {
        guard visits.value > 0 else { return 0 }
        return Double(totaltime.value) / Double(visits.value)
    }

    var averageTimeFormatted: String {
        let minutes = Int(averageTime) / 60
        let seconds = Int(averageTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct StatValue: Codable, Sendable, Equatable {
    let value: Int
    let change: Int

    var changePercentage: Double {
        guard value - change != 0 else { return 0 }
        return Double(change) / Double(value - change) * 100
    }

    var isPositiveChange: Bool {
        change >= 0
    }
}

struct ActiveVisitorsResponse: Codable, Sendable {
    let visitors: Int

    var count: Int { visitors }
}

struct PageviewsData: Codable, Sendable {
    let pageviews: [TimeSeriesPoint]
    let sessions: [TimeSeriesPoint]
}

struct TimeSeriesPoint: Codable, Identifiable, Sendable, Equatable {
    let x: String
    let y: Int

    var id: String { x }

    var date: Date {
        DateFormatters.iso8601WithFractional.date(from: x)
            ?? DateFormatters.iso8601.date(from: x)
            ?? Date()
    }

    var value: Int { y }
}

struct MetricItem: Codable, Identifiable, Sendable, Equatable {
    let x: String?
    let y: Int

    var id: String { x ?? "unknown" }
    var name: String { x ?? String(localized: "metrics.unknown") }
    var value: Int { y }
}

enum MetricType: String, CaseIterable, Sendable {
    case path = "path"
    case referrer = "referrer"
    case browser = "browser"
    case os = "os"
    case device = "device"
    case country = "country"
    case region = "region"
    case city = "city"
    case language = "language"
    case screen = "screen"
    case event = "event"
    case query = "query"
    case title = "title"
    case hostname = "hostname"

    var displayName: String {
        switch self {
        case .path: return "Seiten"
        case .referrer: return "Referrer"
        case .browser: return "Browser"
        case .os: return "Betriebssystem"
        case .device: return "Geräte"
        case .country: return "Länder"
        case .region: return "Regionen"
        case .city: return "Städte"
        case .language: return "Sprachen"
        case .screen: return "Bildschirme"
        case .event: return "Events"
        case .query: return "Query-Parameter"
        case .title: return "Seitentitel"
        case .hostname: return "Hosts"
        }
    }

    var icon: String {
        switch self {
        case .path: return "doc.text.fill"
        case .referrer: return "link"
        case .browser: return "globe"
        case .os: return "desktopcomputer"
        case .device: return "iphone"
        case .country: return "globe.europe.africa.fill"
        case .region: return "map.fill"
        case .city: return "building.2.fill"
        case .language: return "character.bubble.fill"
        case .screen: return "rectangle.dashed"
        case .event: return "bell.fill"
        case .query: return "magnifyingglass"
        case .title: return "textformat"
        case .hostname: return "server.rack"
        }
    }
}

struct EventData: Codable, Identifiable, Sendable {
    let x: String
    let t: String
    let y: Int

    var id: String { "\(x)-\(t)" }
    var eventName: String { x }
    var timestamp: String { t }
    var count: Int { y }
}

// MARK: - Realtime Data

struct RealtimeData: Codable, Sendable {
    let countries: [String: Int]
    let urls: [String: Int]
    let referrers: [String: Int]
    let events: [RealtimeEvent]
    let series: RealtimeSeries?
    let totals: RealtimeTotals?
    let timestamp: Int?
}

struct RealtimeEvent: Codable, Identifiable, Sendable {
    let __type: String
    let sessionId: String
    let eventName: String?
    let createdAt: String
    let browser: String?
    let os: String?
    let device: String?
    let country: String?
    let urlPath: String?
    let referrerDomain: String?

    var id: String { "\(sessionId)-\(createdAt)" }

    var isPageview: Bool { __type == "pageview" }
    var isSession: Bool { __type == "session" }

    var createdDate: Date {
        DateFormatters.iso8601WithFractional.date(from: createdAt) ?? Date()
    }

    var timeAgo: String {
        let interval = Date().timeIntervalSince(createdDate)
        let minutes = Int(interval / 60)
        if minutes < 1 { return "jetzt" }
        if minutes == 1 { return "1 Min" }
        return "\(minutes) Min"
    }
}

struct RealtimeSeries: Codable, Sendable {
    let views: [RealtimeSeriesPoint]?
    let visitors: [RealtimeSeriesPoint]?
}

struct RealtimeSeriesPoint: Codable, Sendable {
    let x: String
    let y: Int
}

struct RealtimeTotals: Codable, Sendable {
    let views: Int?
    let visitors: Int?
    let events: Int?
    let countries: Int?
}

// MARK: - Sessions

struct SessionsResponse: Codable, Sendable {
    let data: [Session]
    let count: Int
    let page: Int
    let pageSize: Int
}

struct Session: Codable, Identifiable, Sendable {
    let id: String
    let websiteId: String
    let hostname: String?
    let browser: String?
    let os: String?
    let device: String?
    let screen: String?
    let language: String?
    let country: String?
    let region: String?
    let city: String?
    let firstAt: String?
    let lastAt: String?
    let visits: Int?
    let views: Int?
    let createdAt: String?

    var firstDate: Date? {
        guard let firstAt = firstAt else { return nil }
        return DateFormatters.iso8601WithFractional.date(from: firstAt)
    }

    var lastDate: Date? {
        guard let lastAt = lastAt else { return nil }
        return DateFormatters.iso8601WithFractional.date(from: lastAt)
    }

    var duration: String {
        guard let first = firstDate, let last = lastDate else { return "-" }
        let interval = last.timeIntervalSince(first)
        let minutes = Int(interval / 60)
        let seconds = Int(interval) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
}

struct SessionActivity: Codable, Identifiable, Sendable {
    let createdAt: String
    let urlPath: String?
    let urlQuery: String?
    let referrerDomain: String?
    let eventId: String?
    let eventType: Int?
    let eventName: String?
    let visitId: String?

    var id: String { "\(createdAt)-\(urlPath ?? "")-\(eventId ?? "")" }

    var createdDate: Date {
        DateFormatters.iso8601WithFractional.date(from: createdAt) ?? Date()
    }

    var isPageview: Bool { eventType == 1 }
    var isEvent: Bool { eventType == 2 }
}

// MARK: - Retention

struct RetentionRow: Codable, Identifiable, Sendable {
    let date: String
    let day: Int
    let visitors: Int
    let returnVisitors: Int
    let percentage: Double

    var id: String { "\(date)-\(day)" }

    var formattedDate: Date? {
        DateFormatters.iso8601WithFractional.date(from: date)
            ?? DateFormatters.iso8601.date(from: date)
    }
}

// MARK: - Date Range

struct DateRangeResponse: Codable, Sendable {
    let startDate: String
    let endDate: String
}

// MARK: - Expanded Metrics

struct ExpandedMetricItem: Codable, Identifiable, Sendable {
    let name: String
    let pageviews: Int
    let visitors: Int
    let visits: Int
    let bounces: Int
    let totaltime: Int

    var id: String { name }

    var bounceRate: Double {
        guard visits > 0 else { return 0 }
        return Double(bounces) / Double(visits) * 100
    }

    var avgTime: TimeInterval {
        guard visits > 0 else { return 0 }
        return Double(totaltime) / Double(visits)
    }
}

// MARK: - Session Stats

struct SessionStatsResponse: Codable, Sendable {
    let visitors: Int
    let visits: Int
    let pageviews: Int
    let bounces: Int
    let totaltime: Int
    let comparison: StatsComparison?
}

struct WeeklySessionPoint: Codable, Identifiable, Sendable {
    let day: Int     // 0=Sunday .. 6=Saturday
    let hour: Int    // 0-23
    let count: Int

    var id: String { "\(day)-\(hour)" }
}

// MARK: - Session Properties

struct SessionPropertyItem: Codable, Identifiable, Sendable {
    let propertyName: String
    let dataType: Int
    let value: String
    let total: Int

    var id: String { "\(propertyName)-\(value)" }
}

struct SessionDataProperty: Codable, Identifiable, Sendable {
    let propertyName: String
    let dataType: Int
    let total: Int

    var id: String { propertyName }
}

struct SessionDataValue: Codable, Identifiable, Sendable {
    let value: String
    let total: Int

    var id: String { value }
}

// MARK: - Events (website-level)

struct EventsResponse: Codable, Sendable {
    let data: [EventDetail]
    let count: Int
    let page: Int
    let pageSize: Int
}

struct EventDetail: Codable, Identifiable, Sendable {
    let id: String
    let websiteId: String
    let sessionId: String
    let eventName: String?
    let urlPath: String?
    let createdAt: String

    var createdDate: Date {
        DateFormatters.iso8601WithFractional.date(from: createdAt) ?? Date()
    }
}

struct EventStatsResponse: Codable, Sendable {
    let events: Int
    let properties: Int
    let records: StringOrInt

    var recordsCount: Int { records.intValue }
}

/// Handles Umami API inconsistency where `records` can be either Int or String
struct StringOrInt: Codable, Sendable {
    let intValue: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            intValue = intVal
        } else if let strVal = try? container.decode(String.self), let parsed = Int(strVal) {
            intValue = parsed
        } else {
            intValue = 0
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(intValue)
    }
}

// MARK: - Umami v3 Segments

/// Segment bzw. Cohort einer Website (Umami v3, `api/websites/{id}/segments`).
/// `parameters` bleibt bewusst lose typisiert — das Schema erlaubt beliebige
/// Filter-/Action-Kombinationen, die die App nicht auswerten muss.
struct UmamiSegment: Codable, Sendable, Identifiable {
    let id: String
    let websiteId: String?
    let type: String
    let name: String
    let parameters: UmamiJSONValue?
    let createdAt: Date?
    let updatedAt: Date?

    var segmentType: UmamiSegmentType? { UmamiSegmentType(rawValue: type) }
}

/// Umami unterscheidet nur diese beiden Segment-Typen (`segmentTypeParam`).
enum UmamiSegmentType: String, Sendable, CaseIterable {
    case segment
    case cohort
}

/// Paged-Envelope, den Umamis `pagedQuery` für Segment-Listen zurückgibt.
struct UmamiSegmentsResponse: Codable, Sendable {
    let data: [UmamiSegment]
    let count: Int?
    let page: Int?
    let pageSize: Int?
}

/// Minimaler, typloser JSON-Container für Felder ohne festes Schema.
enum UmamiJSONValue: Codable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([UmamiJSONValue])
    case object([String: UmamiJSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([UmamiJSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: UmamiJSONValue].self) {
            self = .object(value)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var doubleValue: Double? {
        if case .number(let value) = self { return value }
        return nil
    }
}

// MARK: - Umami v3 Sessions

/// `api/websites/{id}/sessions/stats` — jede Kennzahl kommt als `{ "value": n }`.
struct UmamiSessionStats: Codable, Sendable {
    struct Metric: Codable, Sendable {
        let value: Double
    }

    let pageviews: Metric?
    let visitors: Metric?
    let visits: Metric?
    let countries: Metric?
    let events: Metric?

    var pageviewCount: Int { Int(pageviews?.value ?? 0) }
    var visitorCount: Int { Int(visitors?.value ?? 0) }
    var visitCount: Int { Int(visits?.value ?? 0) }
    var countryCount: Int { Int(countries?.value ?? 0) }
    var eventCount: Int { Int(events?.value ?? 0) }
}

/// `api/websites/{id}/sessions/weekly` liefert eine 7×24-Matrix roher Zahlen
/// (Index 0 = Sonntag, innere Achse = Stunde 0…23).
struct UmamiWeeklyTraffic: Sendable {
    /// Rohmatrix wie vom Server geliefert: 7 Tage × 24 Stunden.
    let days: [[Int]]

    func value(day: Int, hour: Int) -> Int {
        guard days.indices.contains(day), days[day].indices.contains(hour) else { return 0 }
        return days[day][hour]
    }

    var total: Int { days.flatMap { $0 }.reduce(0, +) }
}

// MARK: - Umami v3 Revenue

/// `api/websites/{id}/revenue/stats` — flache Kennzahlen plus `comparison`
/// mit demselben Aufbau. Die SQL-Aliase sind snake_case, der Decoder nutzt
/// aber keine Konvertierungsstrategie: CodingKeys müssen exakt passen.
struct UmamiRevenueStats: Codable, Sendable {
    let sum: Double
    let count: Double
    let average: Double
    let uniqueCount: Double
    let arpu: Double
    let comparison: UmamiRevenueStatsComparison?

    enum CodingKeys: String, CodingKey {
        case sum, count, average, arpu, comparison
        case uniqueCount = "unique_count"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sum = Self.decodeNumber(container, .sum)
        count = Self.decodeNumber(container, .count)
        average = Self.decodeNumber(container, .average)
        uniqueCount = Self.decodeNumber(container, .uniqueCount)
        arpu = Self.decodeNumber(container, .arpu)
        comparison = try container.decodeIfPresent(UmamiRevenueStatsComparison.self, forKey: .comparison)
    }

    /// Postgres liefert `sum`/`count` je nach Treiber als String oder Zahl.
    static func decodeNumber(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double {
        if let value = try? container.decodeIfPresent(Double.self, forKey: key) { return value ?? 0 }
        if let value = try? container.decodeIfPresent(String.self, forKey: key) { return Double(value ?? "") ?? 0 }
        return 0
    }
}

/// Vergleichszeitraum aus `revenue/stats` — identische Felder, aber ohne
/// weitere Verschachtelung.
struct UmamiRevenueStatsComparison: Codable, Sendable {
    let sum: Double
    let count: Double
    let average: Double
    let uniqueCount: Double
    let arpu: Double

    enum CodingKeys: String, CodingKey {
        case sum, count, average, arpu
        case uniqueCount = "unique_count"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func number(_ key: CodingKeys) -> Double {
            if let value = try? container.decodeIfPresent(Double.self, forKey: key) { return value ?? 0 }
            if let value = try? container.decodeIfPresent(String.self, forKey: key) { return Double(value ?? "") ?? 0 }
            return 0
        }
        sum = number(.sum)
        count = number(.count)
        average = number(.average)
        uniqueCount = number(.uniqueCount)
        arpu = number(.arpu)
    }
}

/// `api/websites/{id}/revenue/chart` → `{ "chart": [...] }`.
/// Pro Punkt: x = Event-Name, t = Zeitbucket, y = Umsatz, count = Anzahl.
struct UmamiRevenueChartResponse: Codable, Sendable {
    let chart: [UmamiRevenueChartPoint]
}

struct UmamiRevenueChartPoint: Codable, Sendable {
    let x: String?
    let t: String?
    let y: Double
    let count: Double

    enum CodingKeys: String, CodingKey {
        case x, t, y, count
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        x = try? container.decodeIfPresent(String.self, forKey: .x)
        t = try? container.decodeIfPresent(String.self, forKey: .t)
        if let value = try? container.decodeIfPresent(Double.self, forKey: .y) {
            y = value ?? 0
        } else if let value = try? container.decodeIfPresent(String.self, forKey: .y) {
            y = Double(value ?? "") ?? 0
        } else {
            y = 0
        }
        if let value = try? container.decodeIfPresent(Double.self, forKey: .count) {
            count = value ?? 0
        } else if let value = try? container.decodeIfPresent(String.self, forKey: .count) {
            count = Double(value ?? "") ?? 0
        } else {
            count = 0
        }
    }
}

// MARK: - Ereignis-Kennzahlen (`api/websites/{id}/events/stats`)

/// Umhüllung des Endpunkts — die Nutzdaten liegen hier unter `data`,
/// anders als bei den meisten anderen Umami-Endpunkten.
struct UmamiEventStatsResponse: Codable, Sendable {
    let data: UmamiEventStats
}

/// Ereignis-Kennzahlen inklusive Vorperiodenvergleich.
struct UmamiEventStats: Codable, Sendable, Equatable {
    let events: Int
    let visitors: Int
    let visits: Int
    let uniqueEvents: Int
    let comparison: UmamiEventStatsComparison?

    /// Differenz zur Vorperiode — nil, wenn der Server keinen Vergleich liefert.
    var eventsChange: Int? { comparison.map { events - $0.events } }
    var visitorsChange: Int? { comparison.map { visitors - $0.visitors } }
    var visitsChange: Int? { comparison.map { visits - $0.visits } }
    var uniqueEventsChange: Int? { comparison.map { uniqueEvents - $0.uniqueEvents } }
}

/// Werte des Vergleichszeitraums.
struct UmamiEventStatsComparison: Codable, Sendable, Equatable {
    let events: Int
    let visitors: Int
    let visits: Int
    let uniqueEvents: Int
}

// MARK: - Ereignisse im Zeitverlauf (`api/websites/{id}/events/series`)

/// Ein Punkt der Ereignis-Zeitreihe: x = Ereignisname, t = Zeitbucket,
/// y = Anzahl. `t` kommt als "yyyy-MM-dd HH:mm:ss" (kein ISO-Z).
struct UmamiEventSeriesPoint: Codable, Sendable, Identifiable {
    let x: String?
    let t: String?
    let y: Double

    var id: String { "\(x ?? "")-\(t ?? "")" }

    /// Ereignisname für die Anzeige.
    var eventName: String { x ?? "" }

    /// Zeitbucket als Date — Umami liefert hier lokale Zeit ohne Zeitzone.
    var date: Date? {
        guard let t else { return nil }
        return DateFormatters.yyyyMMddHHmmss.date(from: t)
    }

    /// Anzahl als Int für die Darstellung.
    var count: Int { Int(y) }

    enum CodingKeys: String, CodingKey {
        case x, t, y
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        x = try? container.decodeIfPresent(String.self, forKey: .x)
        t = try? container.decodeIfPresent(String.self, forKey: .t)
        if let value = try? container.decodeIfPresent(Double.self, forKey: .y) {
            y = value ?? 0
        } else if let value = try? container.decodeIfPresent(String.self, forKey: .y) {
            y = Double(value ?? "") ?? 0
        } else {
            y = 0
        }
    }
}

// MARK: - Werteliste je Feld (`api/websites/{id}/values`)

/// Ein Wert eines Feldes mit seiner Häufigkeit — Grundlage für
/// Filter-Vorschläge. `value` kann null sein (z. B. bei nie gesetzten Feldern).
struct UmamiFieldValue: Codable, Sendable, Identifiable {
    let value: String?
    let count: Double

    var id: String { value ?? "__null__" }

    /// Häufigkeit als Int für die Darstellung.
    var total: Int { Int(count) }

    enum CodingKeys: String, CodingKey {
        case value, count
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try? container.decodeIfPresent(String.self, forKey: .value)
        if let number = try? container.decodeIfPresent(Double.self, forKey: .count) {
            count = number ?? 0
        } else if let text = try? container.decodeIfPresent(String.self, forKey: .count) {
            count = Double(text ?? "") ?? 0
        } else {
            count = 0
        }
    }
}

/// Felder, für die `api/websites/{id}/values` Werte liefert
/// (entspricht `fieldsParam` im Umami-Schema).
enum UmamiValueField: String, CaseIterable, Sendable {
    case path
    case referrer
    case title
    case query
    case os
    case browser
    case device
    case country
    case region
    case city
    case tag
    case hostname
    case distinctId
    case language
    case event
    case utmSource
    case utmMedium
    case utmCampaign
    case utmContent
    case utmTerm
}
