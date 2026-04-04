import Foundation

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
    private let api = UmamiAPI.shared

    init(websiteId: String) {
        self.websiteId = websiteId
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
                        #if DEBUG
                        print("Events error: \(error)")
                        #endif
                        await MainActor.run {
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
                        #if DEBUG
                        print("EventStats error: \(error)")
                        #endif
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
                #if DEBUG
                print("EventDetail error: \(error)")
                #endif
                self.error = error.localizedDescription
            }
        }
        loadingTask = task
        await task.value
    }
}
