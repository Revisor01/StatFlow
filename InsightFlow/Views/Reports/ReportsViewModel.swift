import Foundation

@MainActor
class ReportsViewModel: ObservableObject {
    let websiteId: String

    @Published var reports: [Report] = []
    @Published var funnelData: [FunnelStep] = []
    @Published var utmData: [UTMReportItem] = []
    @Published var goalData: [GoalReportItem] = []
    @Published var goalResults: [String: GoalReportResult] = [:]
    @Published var attributionData: [AttributionItem] = []
    @Published var isLoading: Bool = false
    @Published var isOffline = false
    @Published var error: String?

    private let api = UmamiAPI.shared

    // MARK: - Computed Properties

    var funnelReports: [Report] {
        reports.filter { $0.type == "funnel" }
    }

    var hasFunnelReports: Bool {
        !funnelReports.isEmpty
    }

    var goalReports: [Report] {
        reports.filter { $0.type == "goal" }
    }

    var hasGoalReports: Bool {
        !goalReports.isEmpty
    }

    // MARK: - Init

    init(websiteId: String) {
        self.websiteId = websiteId
    }

    // MARK: - Data Loading

    func loadReports() async {
        isLoading = true
        isOffline = false
        error = nil

        do {
            let response = try await api.getReports(websiteId: websiteId)
            reports = response.data
        } catch {
            #if DEBUG
            print("ReportsViewModel: loadReports error: \(error)")
            #endif
            let isNetworkError = (error as? URLError)?.code == .notConnectedToInternet ||
                                 (error as? URLError)?.code == .networkConnectionLost ||
                                 (error as? URLError)?.code == .timedOut ||
                                 (error as? URLError)?.code == .cannotFindHost ||
                                 (error as? URLError)?.code == .cannotConnectToHost
            if isNetworkError {
                self.isOffline = true
            } else {
                self.error = error.localizedDescription
            }
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
            let steps = report.parameters?.steps ?? []
            let window = report.parameters?.window ?? 60
            funnelData = try await api.getFunnelReport(
                websiteId: websiteId,
                dateRange: dateRange,
                steps: steps,
                window: window
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
            let goalType = report.parameters?.type ?? "event"
            let goalValue = report.parameters?.value ?? ""

            let result = try await api.getGoalReport(
                websiteId: websiteId,
                dateRange: dateRange,
                goalType: goalType,
                goalValue: goalValue
            )
            goalResults[report.id] = result

            // Build GoalReportItem for display compatibility
            let item = GoalReportItem(
                type: goalType,
                value: goalValue,
                goal: result.total,
                result: result.num
            )
            goalData = [item]
        } catch {
            #if DEBUG
            print("ReportsViewModel: loadGoalReport error: \(error)")
            #endif
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Helpers
}
