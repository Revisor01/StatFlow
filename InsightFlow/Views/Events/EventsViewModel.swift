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
    @Published var selectedEventValues: [String: [EventDataValue]] = [:]

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
                // event-data/fields returns { propertyName, dataType, total }.
                // Scope to the tapped event so we only show its own properties.
                let allFields = try await api.getEventDataFields(
                    websiteId: websiteId,
                    dateRange: dateRange,
                    eventName: eventName
                )
                guard !Task.isCancelled else { return }

                let propertyNames = allFields.map { $0.propertyName }.sorted()
                selectedEventProperties = propertyNames

                // The fields endpoint carries no value breakdown — load values per property
                // from event-data/values (scoped to the tapped event). Failures per property
                // are non-fatal: we still show the property name.
                var valuesDict: [String: [EventDataValue]] = [:]
                for name in propertyNames {
                    guard !Task.isCancelled else { return }
                    do {
                        let values = try await api.getEventDataValues(
                            websiteId: websiteId,
                            dateRange: dateRange,
                            eventName: eventName,
                            propertyName: name
                        )
                        valuesDict[name] = values.sorted { $0.total > $1.total }
                    } catch {
                        Logger.ui.error("EventDataValues error for \(name): \(error.localizedDescription)")
                    }
                }
                guard !Task.isCancelled else { return }
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
