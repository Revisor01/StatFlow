import Foundation

@MainActor
class ReportsViewModel: ObservableObject {
    let websiteId: String

    @Published var reports: [Report] = []
    @Published var funnelData: [FunnelStep] = []
    @Published var utmData: [UTMReportItem] = []
    @Published var goalData: [GoalReportItem] = []
    @Published var attributionData: [AttributionItem] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    private let api = UmamiAPI.shared

    // MARK: - Computed Properties

    var funnelReports: [Report] {
        reports.filter { $0.type == "funnel" }
    }

    var hasFunnelReports: Bool {
        !funnelReports.isEmpty
    }

    var hasGoalReports: Bool {
        !reports.filter { $0.type == "goals" }.isEmpty
    }

    // MARK: - Init

    init(websiteId: String) {
        self.websiteId = websiteId
    }

    // MARK: - Data Loading

    func loadReports() async {
        isLoading = true
        error = nil

        do {
            let response = try await api.getReports(websiteId: websiteId)
            reports = response.data
        } catch {
            #if DEBUG
            print("ReportsViewModel: loadReports error: \(error)")
            #endif
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadUTMReport(dateRange: DateRange) async {
        isLoading = true
        error = nil

        do {
            utmData = try await api.getUTMReport(websiteId: websiteId, dateRange: dateRange)
        } catch {
            #if DEBUG
            print("ReportsViewModel: loadUTMReport error: \(error)")
            #endif
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadAttributionReport(dateRange: DateRange) async {
        isLoading = true
        error = nil

        do {
            attributionData = try await api.getAttributionReport(websiteId: websiteId, dateRange: dateRange)
        } catch {
            #if DEBUG
            print("ReportsViewModel: loadAttributionReport error: \(error)")
            #endif
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadFunnelReport(report: Report, dateRange: DateRange) async {
        isLoading = true
        error = nil

        do {
            let params = parseParameters(report.parameters)
            let steps = params?["steps"] as? [[String: String]] ?? []
            funnelData = try await api.getFunnelReport(
                websiteId: websiteId,
                dateRange: dateRange,
                steps: steps
            )
        } catch {
            #if DEBUG
            print("ReportsViewModel: loadFunnelReport error: \(error)")
            #endif
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadGoalReport(report: Report, dateRange: DateRange) async {
        isLoading = true
        error = nil

        do {
            let params = parseParameters(report.parameters)
            let goals = params?["goals"] as? [[String: Any]] ?? []
            goalData = try await api.getGoalReport(
                websiteId: websiteId,
                dateRange: dateRange,
                goals: goals
            )
        } catch {
            #if DEBUG
            print("ReportsViewModel: loadGoalReport error: \(error)")
            #endif
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Helpers

    private func parseParameters(_ jsonString: String?) -> [String: Any]? {
        guard let jsonString, !jsonString.isEmpty,
              let data = jsonString.data(using: .utf8) else {
            return nil
        }

        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
