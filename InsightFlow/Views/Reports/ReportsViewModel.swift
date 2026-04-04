import Foundation
import os

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

    private var loadingTask: Task<Void, Never>?
    private let api: UmamiAPI

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

    init(websiteId: String, api: UmamiAPI = .shared) {
        self.websiteId = websiteId
        self.api = api
    }

    // MARK: - Data Loading

    func loadReports() async {
        loadingTask?.cancel()
        let task = Task {
            isLoading = true
            isOffline = false
            error = nil
            defer { if !Task.isCancelled { isLoading = false } }

            do {
                let response = try await api.getReports(websiteId: websiteId)
                guard !Task.isCancelled else { return }
                reports = response.data
            } catch {
                guard !Task.isCancelled else { return }
                Logger.ui.error("loadReports error: \(error.localizedDescription)")
                if error.isNetworkError {
                    self.isOffline = true
                } else {
                    self.error = error.localizedDescription
                }
            }
        }
        loadingTask = task
        await task.value
    }

    func loadUTMReport(dateRange: DateRange) async {
        loadingTask?.cancel()
        let task = Task {
            isLoading = true
            error = nil
            defer { if !Task.isCancelled { isLoading = false } }

            do {
                let result = try await api.getUTMReport(websiteId: websiteId, dateRange: dateRange)
                guard !Task.isCancelled else { return }
                utmData = result
            } catch {
                guard !Task.isCancelled else { return }
                Logger.ui.error("loadUTMReport error: \(error.localizedDescription)")
                self.error = error.localizedDescription
            }
        }
        loadingTask = task
        await task.value
    }

    func loadAttributionReport(dateRange: DateRange) async {
        loadingTask?.cancel()
        let task = Task {
            isLoading = true
            error = nil
            defer { if !Task.isCancelled { isLoading = false } }

            do {
                let result = try await api.getAttributionReport(websiteId: websiteId, dateRange: dateRange)
                guard !Task.isCancelled else { return }
                attributionData = result
            } catch {
                guard !Task.isCancelled else { return }
                Logger.ui.error("loadAttributionReport error: \(error.localizedDescription)")
                self.error = error.localizedDescription
            }
        }
        loadingTask = task
        await task.value
    }

    func loadFunnelReport(report: Report, dateRange: DateRange) async {
        loadingTask?.cancel()
        let task = Task {
            isLoading = true
            error = nil
            defer { if !Task.isCancelled { isLoading = false } }

            do {
                let steps = report.parameters?.steps ?? []
                let window = report.parameters?.window ?? 60
                let result = try await api.getFunnelReport(
                    websiteId: websiteId,
                    dateRange: dateRange,
                    steps: steps,
                    window: window
                )
                guard !Task.isCancelled else { return }
                funnelData = result
            } catch {
                guard !Task.isCancelled else { return }
                Logger.ui.error("loadFunnelReport error: \(error.localizedDescription)")
                self.error = error.localizedDescription
            }
        }
        loadingTask = task
        await task.value
    }

    func loadFirstFunnel(dateRange: DateRange) async {
        loadingTask?.cancel()
        let task = Task {
            isLoading = true
            error = nil
            defer { if !Task.isCancelled { isLoading = false } }

            do {
                if reports.isEmpty {
                    let response = try await api.getReports(websiteId: websiteId)
                    guard !Task.isCancelled else { return }
                    reports = response.data
                }
                let funnels = reports.filter { $0.type == "funnel" }
                if let first = funnels.first {
                    let steps = first.parameters?.steps ?? []
                    let window = first.parameters?.window ?? 60
                    let result = try await api.getFunnelReport(
                        websiteId: websiteId,
                        dateRange: dateRange,
                        steps: steps,
                        window: window
                    )
                    guard !Task.isCancelled else { return }
                    funnelData = result
                }
            } catch {
                guard !Task.isCancelled else { return }
                Logger.ui.error("loadFirstFunnel error: \(error.localizedDescription)")
                self.error = error.localizedDescription
            }
        }
        loadingTask = task
        await task.value
    }

    func loadAllGoals(dateRange: DateRange) async {
        loadingTask?.cancel()
        let task = Task {
            isLoading = true
            error = nil
            goalData = []
            defer { if !Task.isCancelled { isLoading = false } }

            do {
                // Load reports if not already loaded
                if reports.isEmpty {
                    let response = try await api.getReports(websiteId: websiteId)
                    guard !Task.isCancelled else { return }
                    reports = response.data
                }

                let goals = reports.filter { $0.type == "goal" }

                for report in goals {
                    guard !Task.isCancelled else { return }
                    let goalType = report.parameters?.type ?? "event"
                    let goalValue = report.parameters?.value ?? ""
                    do {
                        let result = try await api.getGoalReport(
                            websiteId: websiteId,
                            dateRange: dateRange,
                            goalType: goalType,
                            goalValue: goalValue
                        )
                        guard !Task.isCancelled else { return }
                        let item = GoalReportItem(
                            type: goalType,
                            value: goalValue,
                            name: report.name,
                            goal: result.total,
                            result: result.num
                        )
                        goalData.append(item)
                    } catch {
                        guard !Task.isCancelled else { return }
                        Logger.ui.error("loadGoalReport error for \(report.name): \(error.localizedDescription)")
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                Logger.ui.error("loadAllGoals error: \(error.localizedDescription)")
                self.error = error.localizedDescription
            }
        }
        loadingTask = task
        await task.value
    }

    // MARK: - Helpers
}
