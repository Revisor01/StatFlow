import Foundation
import os

// MARK: - ViewModels

@MainActor
class SessionsViewModel: ObservableObject {
    let websiteId: String

    @Published var sessions: [Session] = []
    @Published var isLoading = false
    @Published var isOffline = false
    @Published var hasMore = false

    private var loadingTask: Task<Void, Never>?
    private var currentPage = 1
    private var totalCount = 0
    private let pageSize = 20
    private let api: UmamiAPI

    init(websiteId: String, api: UmamiAPI = .shared) {
        self.websiteId = websiteId
        self.api = api
    }

    func loadData(dateRange: DateRange) async {
        loadingTask?.cancel()
        let task = Task {
            isLoading = true
            isOffline = false
            currentPage = 1
            defer { if !Task.isCancelled { isLoading = false } }

            do {
                let response = try await api.getSessions(
                    websiteId: websiteId,
                    dateRange: dateRange,
                    page: currentPage,
                    pageSize: pageSize
                )
                guard !Task.isCancelled else { return }
                sessions = response.data
                totalCount = response.count
                hasMore = sessions.count < totalCount
            } catch {
                guard !Task.isCancelled else { return }
                Logger.ui.error("Sessions error: \(error.localizedDescription)")
                if error.isNetworkError {
                    isOffline = true
                }
            }
        }
        loadingTask = task
        await task.value
    }

    func loadMore(dateRange: DateRange) async {
        guard !isLoading, hasMore else { return }

        isLoading = true
        currentPage += 1

        do {
            let response = try await api.getSessions(
                websiteId: websiteId,
                dateRange: dateRange,
                page: currentPage,
                pageSize: pageSize
            )
            sessions.append(contentsOf: response.data)
            hasMore = sessions.count < totalCount
        } catch {
            Logger.ui.error("Sessions loadMore error: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func refresh(dateRange: DateRange) async {
        await loadData(dateRange: dateRange)
    }
}

@MainActor
class SessionDetailViewModel: ObservableObject {
    let websiteId: String
    let sessionId: String

    @Published var activities: [SessionActivity] = []
    @Published var isLoading = false

    private var loadingTask: Task<Void, Never>?
    private let api: UmamiAPI

    init(websiteId: String, sessionId: String, api: UmamiAPI = .shared) {
        self.websiteId = websiteId
        self.sessionId = sessionId
        self.api = api
    }

    func loadActivity(dateRange: DateRange) async {
        loadingTask?.cancel()
        let task = Task {
            isLoading = true
            defer { if !Task.isCancelled { isLoading = false } }

            do {
                let result = try await api.getSessionActivity(
                    websiteId: websiteId,
                    sessionId: sessionId,
                    dateRange: dateRange
                )
                guard !Task.isCancelled else { return }
                activities = result
            } catch {
                guard !Task.isCancelled else { return }
                Logger.ui.error("Activity error: \(error.localizedDescription)")
            }
        }
        loadingTask = task
        await task.value
    }
}

@MainActor
class JourneyViewModel: ObservableObject {
    let websiteId: String

    @Published var journeys: [JourneyPath] = []
    @Published var isLoading = false

    private var loadingTask: Task<Void, Never>?
    private let api: UmamiAPI

    init(websiteId: String, api: UmamiAPI = .shared) {
        self.websiteId = websiteId
        self.api = api
    }

    func loadJourneys(dateRange: DateRange) async {
        loadingTask?.cancel()
        let task = Task {
            isLoading = true
            defer { if !Task.isCancelled { isLoading = false } }

            do {
                let result = try await api.getJourneyReport(
                    websiteId: websiteId,
                    dateRange: dateRange,
                    steps: 5
                )
                guard !Task.isCancelled else { return }
                journeys = result
            } catch {
                guard !Task.isCancelled else { return }
                Logger.ui.error("Journey error: \(error.localizedDescription)")
            }
        }
        loadingTask = task
        await task.value
    }
}
