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

    private let api = UmamiAPI.shared

    init(websiteId: String) {
        self.websiteId = websiteId
    }

    func loadEvents(dateRange: DateRange) async {
        isLoading = true
        isOffline = false
        error = nil

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                do {
                    let items = try await self.api.getEvents(
                        websiteId: self.websiteId,
                        dateRange: dateRange
                    )
                    await MainActor.run {
                        self.events = items
                    }
                } catch {
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
                    await MainActor.run {
                        self.eventStats = stats
                    }
                } catch {
                    #if DEBUG
                    print("EventStats error: \(error)")
                    #endif
                }
            }
        }

        isLoading = false
    }

    func loadEventDetail(eventName: String, dateRange: DateRange) async {
        isLoading = true
        selectedEventProperties = []
        selectedEventValues = [:]

        do {
            // event-data/fields returns all property+value combinations across all events
            let allFields = try await api.getEventDataFields(
                websiteId: websiteId,
                dateRange: dateRange
            )

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
            #if DEBUG
            print("EventDetail error: \(error)")
            #endif
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
