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
    @Published var selectedEventProperties: [EventDataEvent] = []
    @Published var selectedEventValues: [String: [EventDataValue]] = [:]

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
            let allEvents = try await api.getEventDataEvents(
                websiteId: websiteId,
                dateRange: dateRange
            )
            let properties = allEvents.filter { $0.eventName == eventName }
            selectedEventProperties = properties

            // Load values for each distinct property
            var valuesDict: [String: [EventDataValue]] = [:]
            await withTaskGroup(of: (String, [EventDataValue]).self) { group in
                let propertyNames = Set(properties.compactMap { $0.propertyName })
                for propertyName in propertyNames {
                    group.addTask {
                        do {
                            let values = try await self.api.getEventDataValues(
                                websiteId: self.websiteId,
                                dateRange: dateRange,
                                eventName: eventName,
                                propertyName: propertyName
                            )
                            return (propertyName, values)
                        } catch {
                            #if DEBUG
                            print("EventDataValues error for \(propertyName): \(error)")
                            #endif
                            return (propertyName, [])
                        }
                    }
                }
                for await (propertyName, values) in group {
                    valuesDict[propertyName] = values
                }
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
