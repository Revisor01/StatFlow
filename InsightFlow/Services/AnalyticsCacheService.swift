import Foundation

/// Caching-Service für Analytics-Daten, der offline Zugriff ermöglicht
/// Speichert Daten im App Group Container für App + Widget Zugriff
final class AnalyticsCacheService: @unchecked Sendable {
    static let shared = AnalyticsCacheService()

    private let appGroupID = "group.de.godsapp.statflow"
    private let cacheFolder = "analytics_cache"

    // Cache TTL (Time-To-Live) in Sekunden
    private let defaultTTL: TimeInterval = 3600 // 1 Stunde
    private let sparklineTTL: TimeInterval = 900 // 15 Minuten für Sparklines

    /// Maximum age for cache data to be shown in offline mode (24 hours)
    static let offlineDisplayTTL: TimeInterval = 24 * 60 * 60

    private let overrideCacheDirectory: URL?

    private var cacheDirectory: URL? {
        if let override = overrideCacheDirectory { return override }
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }
        let cacheURL = containerURL.appendingPathComponent(cacheFolder)

        // Erstelle Cache-Ordner falls nicht vorhanden
        if !FileManager.default.fileExists(atPath: cacheURL.path) {
            try? FileManager.default.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        }

        return cacheURL
    }

    private init() { self.overrideCacheDirectory = nil }

    /// Testbarer Init mit Override für das Cache-Verzeichnis (kein App-Group-Entitlement nötig)
    init(cacheDirectoryOverride: URL) { self.overrideCacheDirectory = cacheDirectoryOverride }

    // MARK: - Cache Keys

    private func websitesKey(accountId: String) -> String {
        "websites_\(accountId)"
    }

    private func statsKey(websiteId: String, dateRangeId: String) -> String {
        "stats_\(websiteId)_\(dateRangeId)"
    }

    private func sparklineKey(websiteId: String, dateRangeId: String) -> String {
        "sparkline_\(websiteId)_\(dateRangeId)"
    }

    private func metricsKey(websiteId: String, dateRangeId: String, metricType: String) -> String {
        "metrics_\(websiteId)_\(dateRangeId)_\(metricType)"
    }

    // MARK: - Generic Cache Operations

    private func save<T: Codable>(_ data: T, forKey key: String, ttl: TimeInterval? = nil) {
        guard let cacheDir = cacheDirectory else { return }

        let wrapper = CacheWrapper(
            data: data,
            cachedAt: Date(),
            expiresAt: Date().addingTimeInterval(ttl ?? defaultTTL)
        )

        let fileURL = cacheDir.appendingPathComponent("\(key).json")

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let encoded = try encoder.encode(wrapper)
            try encoded.write(to: fileURL, options: Data.WritingOptions.atomic)
            #if DEBUG
            print("AnalyticsCacheService: Saved \(key)")
            #endif
        } catch {
            #if DEBUG
            print("AnalyticsCacheService: Error saving \(key) - \(error)")
            #endif
        }
    }

    private func load<T: Codable>(forKey key: String, type: T.Type) -> CachedData<T>? {
        guard let cacheDir = cacheDirectory else { return nil }

        let fileURL = cacheDir.appendingPathComponent("\(key).json")

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let data = try Data(contentsOf: fileURL)
            let wrapper = try decoder.decode(CacheWrapper<T>.self, from: data)

            let isExpired = Date() > wrapper.expiresAt

            return CachedData(
                data: wrapper.data,
                cachedAt: wrapper.cachedAt,
                isExpired: isExpired
            )
        } catch {
            #if DEBUG
            print("AnalyticsCacheService: Error loading \(key) - \(error)")
            #endif
            return nil
        }
    }

    private func delete(forKey key: String) {
        guard let cacheDir = cacheDirectory else { return }
        let fileURL = cacheDir.appendingPathComponent("\(key).json")
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Websites Cache

    func saveWebsites(_ websites: [CachedWebsite], accountId: String) {
        save(websites, forKey: websitesKey(accountId: accountId))
    }

    func loadWebsites(accountId: String) -> CachedData<[CachedWebsite]>? {
        load(forKey: websitesKey(accountId: accountId), type: [CachedWebsite].self)
    }

    // MARK: - Stats Cache

    func saveStats(_ stats: CachedStats, websiteId: String, dateRangeId: String) {
        save(stats, forKey: statsKey(websiteId: websiteId, dateRangeId: dateRangeId))
    }

    func loadStats(websiteId: String, dateRangeId: String) -> CachedData<CachedStats>? {
        load(forKey: statsKey(websiteId: websiteId, dateRangeId: dateRangeId), type: CachedStats.self)
    }

    // MARK: - Sparkline Cache

    func saveSparkline(_ points: [CachedChartPoint], websiteId: String, dateRangeId: String) {
        save(points, forKey: sparklineKey(websiteId: websiteId, dateRangeId: dateRangeId), ttl: sparklineTTL)
    }

    func loadSparkline(websiteId: String, dateRangeId: String) -> CachedData<[CachedChartPoint]>? {
        load(forKey: sparklineKey(websiteId: websiteId, dateRangeId: dateRangeId), type: [CachedChartPoint].self)
    }

    // MARK: - Metrics Cache

    func saveMetrics(_ metrics: [CachedMetricItem], websiteId: String, dateRangeId: String, metricType: String) {
        save(metrics, forKey: metricsKey(websiteId: websiteId, dateRangeId: dateRangeId, metricType: metricType))
    }

    func loadMetrics(websiteId: String, dateRangeId: String, metricType: String) -> CachedData<[CachedMetricItem]>? {
        load(forKey: metricsKey(websiteId: websiteId, dateRangeId: dateRangeId, metricType: metricType), type: [CachedMetricItem].self)
    }

    // MARK: - Cache Management

    /// Löscht den gesamten Cache
    func clearAllCache() {
        guard let cacheDir = cacheDirectory else { return }
        try? FileManager.default.removeItem(at: cacheDir)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        #if DEBUG
        print("AnalyticsCacheService: Cleared all cache")
        #endif
    }

    /// Löscht abgelaufene Cache-Einträge
    func clearExpiredCache() {
        guard let cacheDir = cacheDirectory,
              let files = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil) else {
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var deletedCount = 0
        for fileURL in files where fileURL.pathExtension == "json" {
            if let data = try? Data(contentsOf: fileURL),
               let wrapper = try? decoder.decode(CacheMetadata.self, from: data),
               Date() > wrapper.expiresAt {
                try? FileManager.default.removeItem(at: fileURL)
                deletedCount += 1
            }
        }

        #if DEBUG
        if deletedCount > 0 {
            print("AnalyticsCacheService: Cleared \(deletedCount) expired entries")
        }
        #endif
    }

    /// Löscht Cache für eine bestimmte Website
    func clearCache(for websiteId: String) {
        guard let cacheDir = cacheDirectory,
              let files = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil) else {
            return
        }

        for fileURL in files where fileURL.lastPathComponent.contains(websiteId) {
            try? FileManager.default.removeItem(at: fileURL)
        }

        #if DEBUG
        print("AnalyticsCacheService: Cleared cache for website \(websiteId)")
        #endif
    }

    /// Löscht Cache für einen Account
    func clearCache(forAccount accountId: String) {
        delete(forKey: websitesKey(accountId: accountId))
        #if DEBUG
        print("AnalyticsCacheService: Cleared cache for account \(accountId)")
        #endif
    }

    /// Gibt die Cache-Größe in Bytes zurück
    func cacheSize() -> Int64 {
        guard let cacheDir = cacheDirectory,
              let files = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        var totalSize: Int64 = 0
        for fileURL in files {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(size)
            }
        }

        return totalSize
    }

    /// Löscht Cache-Einträge älter als N Tage (basierend auf cachedAt, nicht expiresAt)
    func clearStaleEntries(olderThan days: Int = 7) {
        guard let cacheDir = cacheDirectory,
              let files = try? FileManager.default.contentsOfDirectory(
                  at: cacheDir, includingPropertiesForKeys: nil) else { return }
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var deletedCount = 0
        for fileURL in files where fileURL.pathExtension == "json" {
            if let data = try? Data(contentsOf: fileURL),
               let metadata = try? decoder.decode(CacheMetadata.self, from: data),
               metadata.cachedAt < cutoff {
                try? FileManager.default.removeItem(at: fileURL)
                deletedCount += 1
            }
        }
        #if DEBUG
        if deletedCount > 0 {
            print("AnalyticsCacheService: Cleared \(deletedCount) stale entries (>\(days) days)")
        }
        #endif
    }

    /// Löscht älteste Cache-Dateien bis Gesamtgröße unter maxSize liegt
    func evictOldestEntries(maxSize: Int64) {
        guard let cacheDir = cacheDirectory,
              let files = try? FileManager.default.contentsOfDirectory(
                  at: cacheDir,
                  includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]) else { return }

        // Sortiere nach Änderungsdatum (älteste zuerst)
        let sorted = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> (URL, Date, Int64)? in
                guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                      let date = values.contentModificationDate,
                      let size = values.fileSize else { return nil }
                return (url, date, Int64(size))
            }
            .sorted { $0.1 < $1.1 }

        var currentSize = cacheSize()
        var deletedCount = 0
        for (url, _, fileSize) in sorted {
            guard currentSize > maxSize else { break }
            try? FileManager.default.removeItem(at: url)
            currentSize -= fileSize
            deletedCount += 1
        }
        #if DEBUG
        if deletedCount > 0 {
            print("AnalyticsCacheService: Evicted \(deletedCount) entries (cache was over \(maxSize) bytes)")
        }
        #endif
    }

    /// Check if cached data is recent enough to display in offline mode (< 24h old)
    func isValidForOfflineDisplay<T: Codable>(forKey key: String, type: T.Type) -> (data: T, cachedAt: Date)? {
        guard let cached = load(forKey: key, type: type) else { return nil }
        let age = Date().timeIntervalSince(cached.cachedAt)
        guard age < Self.offlineDisplayTTL else { return nil }
        return (cached.data, cached.cachedAt)
    }

    /// Formatierte Cache-Größe
    var formattedCacheSize: String {
        let size = cacheSize()
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - Cache Models

/// Wrapper für gecachte Daten mit Metadaten
private struct CacheWrapper<T: Codable>: Codable {
    let data: T
    let cachedAt: Date
    let expiresAt: Date
}

/// Nur Metadaten zum Prüfen der Gültigkeit
private struct CacheMetadata: Codable {
    let cachedAt: Date
    let expiresAt: Date
}

/// Ergebnis eines Cache-Ladevorgangs
struct CachedData<T> {
    let data: T
    let cachedAt: Date
    let isExpired: Bool
}

// MARK: - Cacheable Models

/// Codable Version von AnalyticsWebsite
struct CachedWebsite: Codable {
    let id: String
    let name: String
    let domain: String
    let shareId: String?
    let provider: String // AnalyticsProviderType.rawValue

    init(from website: AnalyticsWebsite) {
        self.id = website.id
        self.name = website.name
        self.domain = website.domain
        self.shareId = website.shareId
        self.provider = website.provider.rawValue
    }

    func toAnalyticsWebsite() -> AnalyticsWebsite {
        AnalyticsWebsite(
            id: id,
            name: name,
            domain: domain,
            shareId: shareId,
            provider: AnalyticsProviderType(rawValue: provider) ?? .umami
        )
    }
}

/// Codable Version von AnalyticsStats
struct CachedStats: Codable {
    let visitors: CachedStatValue
    let pageviews: CachedStatValue
    let visits: CachedStatValue
    let bounces: CachedStatValue
    let totaltime: CachedStatValue

    init(from stats: AnalyticsStats) {
        self.visitors = CachedStatValue(from: stats.visitors)
        self.pageviews = CachedStatValue(from: stats.pageviews)
        self.visits = CachedStatValue(from: stats.visits)
        self.bounces = CachedStatValue(from: stats.bounces)
        self.totaltime = CachedStatValue(from: stats.totaltime)
    }

    func toAnalyticsStats() -> AnalyticsStats {
        AnalyticsStats(
            visitors: visitors.toStatValue(),
            pageviews: pageviews.toStatValue(),
            visits: visits.toStatValue(),
            bounces: bounces.toStatValue(),
            totaltime: totaltime.toStatValue()
        )
    }
}

struct CachedStatValue: Codable {
    let value: Int
    let change: Int

    init(from statValue: StatValue) {
        self.value = statValue.value
        self.change = statValue.change
    }

    func toStatValue() -> StatValue {
        StatValue(value: value, change: change)
    }
}

/// Codable Version von AnalyticsChartPoint
struct CachedChartPoint: Codable {
    let date: Date
    let value: Int

    init(from point: AnalyticsChartPoint) {
        self.date = point.date
        self.value = point.value
    }

    func toAnalyticsChartPoint() -> AnalyticsChartPoint {
        AnalyticsChartPoint(date: date, value: value)
    }
}

/// Codable Version von AnalyticsMetricItem
struct CachedMetricItem: Codable {
    let name: String
    let value: Int

    init(from item: AnalyticsMetricItem) {
        self.name = item.name
        self.value = item.value
    }

    func toAnalyticsMetricItem() -> AnalyticsMetricItem {
        AnalyticsMetricItem(name: name, value: value)
    }
}

// MARK: - Array Extensions

extension Array where Element == CachedWebsite {
    func toAnalyticsWebsites() -> [AnalyticsWebsite] {
        map { $0.toAnalyticsWebsite() }
    }
}

extension Array where Element == AnalyticsWebsite {
    func toCached() -> [CachedWebsite] {
        map { CachedWebsite(from: $0) }
    }
}

extension Array where Element == CachedChartPoint {
    func toAnalyticsChartPoints() -> [AnalyticsChartPoint] {
        map { $0.toAnalyticsChartPoint() }
    }
}

extension Array where Element == AnalyticsChartPoint {
    func toCached() -> [CachedChartPoint] {
        map { CachedChartPoint(from: $0) }
    }
}

extension Array where Element == CachedMetricItem {
    func toAnalyticsMetricItems() -> [AnalyticsMetricItem] {
        map { $0.toAnalyticsMetricItem() }
    }
}

extension Array where Element == AnalyticsMetricItem {
    func toCached() -> [CachedMetricItem] {
        map { CachedMetricItem(from: $0) }
    }
}
