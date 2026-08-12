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

    // Include all UTM dimensions so distinct combinations never collide in ForEach.
    var id: String {
        [source, medium, campaign, content, term].map { $0 ?? "" }.joined(separator: "|")
    }
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
    enum Kind: Sendable {
        case referrer, paidAds, utm
    }

    let category: String   // localized label, e.g. "Referrer", "UTM Source"
    let kind: Kind         // language-independent, drives badge color
    let name: String
    let count: Int

    var id: String { "\(category)-\(name)" }
}


// MARK: - Umami v3 Performance / Web Vitals

/// Antwort von POST `api/reports/performance`.
/// `chart` zeigt die Perzentile der über `metric` gewählten Kennzahl im
/// Zeitverlauf, `summary` alle fünf Web Vitals über den ganzen Zeitraum.
struct UmamiPerformanceReport: Codable, Sendable {
    let chart: [UmamiPerformanceChartPoint]
    let summary: UmamiPerformanceSummary
    let pages: [UmamiPerformanceMetric]
    let pageTitles: [UmamiPerformanceMetric]
    let devices: [UmamiPerformanceMetric]
    let browsers: [UmamiPerformanceMetric]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        chart = (try? container.decodeIfPresent([UmamiPerformanceChartPoint].self, forKey: .chart)) as? [UmamiPerformanceChartPoint] ?? []
        summary = try container.decode(UmamiPerformanceSummary.self, forKey: .summary)
        pages = (try? container.decodeIfPresent([UmamiPerformanceMetric].self, forKey: .pages)) as? [UmamiPerformanceMetric] ?? []
        pageTitles = (try? container.decodeIfPresent([UmamiPerformanceMetric].self, forKey: .pageTitles)) as? [UmamiPerformanceMetric] ?? []
        devices = (try? container.decodeIfPresent([UmamiPerformanceMetric].self, forKey: .devices)) as? [UmamiPerformanceMetric] ?? []
        browsers = (try? container.decodeIfPresent([UmamiPerformanceMetric].self, forKey: .browsers)) as? [UmamiPerformanceMetric] ?? []
    }
}

/// Web-Vital-Kennzahl, die der Performance-Report als Zeitreihe ausgibt.
/// FID gibt es in v3 nicht mehr — der Nachfolger heißt INP.
enum UmamiWebVitalMetric: String, Sendable, CaseIterable {
    case lcp
    case inp
    case cls
    case fcp
    case ttfb
}

/// Perzentil-Tripel, in dem Umami jede Web-Vital-Kennzahl ausdrückt.
struct UmamiPercentiles: Codable, Sendable {
    let p50: Double
    let p75: Double
    let p95: Double

    enum CodingKeys: String, CodingKey {
        case p50, p75, p95
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func number(_ key: CodingKeys) -> Double {
            if let value = try? container.decodeIfPresent(Double.self, forKey: key) { return value ?? 0 }
            if let value = try? container.decodeIfPresent(String.self, forKey: key) { return Double(value ?? "") ?? 0 }
            return 0
        }
        p50 = number(.p50)
        p75 = number(.p75)
        p95 = number(.p95)
    }
}

struct UmamiPerformanceChartPoint: Codable, Sendable {
    let t: String?
    let p50: Double
    let p75: Double
    let p95: Double

    enum CodingKeys: String, CodingKey {
        case t, p50, p75, p95
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        t = try? container.decodeIfPresent(String.self, forKey: .t)
        func number(_ key: CodingKeys) -> Double {
            if let value = try? container.decodeIfPresent(Double.self, forKey: key) { return value ?? 0 }
            if let value = try? container.decodeIfPresent(String.self, forKey: key) { return Double(value ?? "") ?? 0 }
            return 0
        }
        p50 = number(.p50)
        p75 = number(.p75)
        p95 = number(.p95)
    }
}

/// `summary` enthält alle fünf Vitals plus die Zahl der ausgewerteten Events.
struct UmamiPerformanceSummary: Codable, Sendable {
    let lcp: UmamiPercentiles
    let inp: UmamiPercentiles
    let cls: UmamiPercentiles
    let fcp: UmamiPercentiles
    let ttfb: UmamiPercentiles
    let count: Double

    enum CodingKeys: String, CodingKey {
        case lcp, inp, cls, fcp, ttfb, count
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lcp = try container.decode(UmamiPercentiles.self, forKey: .lcp)
        inp = try container.decode(UmamiPercentiles.self, forKey: .inp)
        cls = try container.decode(UmamiPercentiles.self, forKey: .cls)
        fcp = try container.decode(UmamiPercentiles.self, forKey: .fcp)
        ttfb = try container.decode(UmamiPercentiles.self, forKey: .ttfb)
        if let value = try? container.decodeIfPresent(Double.self, forKey: .count) {
            count = value ?? 0
        } else if let value = try? container.decodeIfPresent(String.self, forKey: .count) {
            count = Double(value ?? "") ?? 0
        } else {
            count = 0
        }
    }

    func percentiles(for metric: UmamiWebVitalMetric) -> UmamiPercentiles {
        switch metric {
        case .lcp: return lcp
        case .inp: return inp
        case .cls: return cls
        case .fcp: return fcp
        case .ttfb: return ttfb
        }
    }
}

/// Aufschlüsselung der gewählten Kennzahl nach Seite, Titel, Gerät oder Browser.
struct UmamiPerformanceMetric: Codable, Sendable, Identifiable {
    let name: String?
    let p50: Double
    let p75: Double
    let p95: Double
    let count: Double

    var id: String { name ?? "" }

    enum CodingKeys: String, CodingKey {
        case name, p50, p75, p95, count
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try? container.decodeIfPresent(String.self, forKey: .name)
        func number(_ key: CodingKeys) -> Double {
            if let value = try? container.decodeIfPresent(Double.self, forKey: key) { return value ?? 0 }
            if let value = try? container.decodeIfPresent(String.self, forKey: key) { return Double(value ?? "") ?? 0 }
            return 0
        }
        p50 = number(.p50)
        p75 = number(.p75)
        p95 = number(.p95)
        count = number(.count)
    }
}

// MARK: - Verfügbarer Datenzeitraum (`api/websites/{id}/daterange`)

/// Zeitraum, für den die Website überhaupt Daten hat. Damit lassen sich in der
/// Datumsauswahl Zeiträume ohne Daten kennzeichnen.
/// Der Server liefert ISO-Zeitstempel, z. B. "2025-11-01T01:57:01.000Z".
struct UmamiDataDateRange: Sendable, Equatable {
    let startDate: Date?
    let endDate: Date?

    init(from response: DateRangeResponse) {
        self.startDate = DateFormatters.iso8601WithFractional.date(from: response.startDate)
            ?? DateFormatters.iso8601.date(from: response.startDate)
        self.endDate = DateFormatters.iso8601WithFractional.date(from: response.endDate)
            ?? DateFormatters.iso8601.date(from: response.endDate)
    }

    init(startDate: Date?, endDate: Date?) {
        self.startDate = startDate
        self.endDate = endDate
    }

    /// Liegt das Datum im Bereich, für den Daten vorliegen?
    func contains(_ date: Date) -> Bool {
        guard let startDate, let endDate else { return false }
        return date >= startDate && date <= endDate
    }

    /// Überschneidet sich der gewählte Zeitraum überhaupt mit vorhandenen Daten?
    func overlaps(start: Date, end: Date) -> Bool {
        guard let startDate, let endDate else { return false }
        return start <= endDate && end >= startDate
    }
}
