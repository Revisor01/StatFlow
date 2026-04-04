import Foundation
import os

@MainActor
class EventsViewModel: ObservableObject {
    let websiteId: String

    @Published var events: [AnalyticsMetricItem] = []
    @Published var eventStats: EventStatsResponse?
    @Published var isLoading = false
    @Published var isOffline = false
    @Published var error: String?

    // Detail-View properties
    @Published var selectedEventProperties: [String] = []
    @Published var selectedEventValues: [String: [EventDataFieldValue]] = [:]

    private var loadingTask: Task<Void, Never>?
    private let api: UmamiAPI

    init(websiteId: String, api: UmamiAPI = .shared) {
        self.websiteId = websiteId
        self.api = api
    }

    func loadEvents(dateRange: DateRange) async {
        loadingTask?.cancel()
        let task = Task {
            isLoading = true
            isOffline = false
            error = nil
            defer { if !Task.isCancelled { isLoading = false } }

            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    do {
                        let items = try await self.api.getEvents(
                            websiteId: self.websiteId,
                            dateRange: dateRange
                        )
                        guard !Task.isCancelled else { return }
                        await MainActor.run {
                            self.events = items
                        }
                    } catch {
                        guard !Task.isCancelled else { return }
                        Logger.ui.error("Events error: \(error.localizedDescription)")
                        await MainActor.run {
                            if error.isNetworkError {
                                self.isOffline = true
                            } else {
                                self.error = error.localizedDescription
                            }
                        }
                    }
                }

                group.addTask {
                    do {
                        let stats = try await self.api.getEventsStats(
                            websiteId: self.websiteId,
                            dateRange: dateRange
                        )
                        guard !Task.isCancelled else { return }
                        await MainActor.run {
                            self.eventStats = stats
                        }
                    } catch {
                        guard !Task.isCancelled else { return }
                        Logger.ui.error("EventStats error: \(error.localizedDescription)")
                    }
                }
            }
        }
        loadingTask = task
        await task.value
    }

    func loadEventDetail(eventName: String, dateRange: DateRange) async {
        loadingTask?.cancel()
        let task = Task {
            isLoading = true
            selectedEventProperties = []
            selectedEventValues = [:]
            defer { if !Task.isCancelled { isLoading = false } }

            do {
                // event-data/fields returns all property+value combinations across all events
                let allFields = try await api.getEventDataFields(
                    websiteId: websiteId,
                    dateRange: dateRange
                )
                guard !Task.isCancelled else { return }

                // Group by propertyName, collect values per property
                let propertyNames = Set(allFields.map { $0.propertyName })
                selectedEventProperties = propertyNames.sorted()

                var valuesDict: [String: [EventDataFieldValue]] = [:]
                for name in propertyNames {
                    valuesDict[name] = allFields
                        .filter { $0.propertyName == name }
                        .sorted { $0.total > $1.total }
                }
                selectedEventValues = valuesDict
            } catch {
                guard !Task.isCancelled else { return }
                Logger.ui.error("EventDetail error: \(error.localizedDescription)")
                self.error = error.localizedDescription
            }
        }
        loadingTask = task
        await task.value
    }
}
