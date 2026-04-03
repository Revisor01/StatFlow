import Foundation

// MARK: - Event Data Models

struct EventDataResponse: Codable, Sendable {
    let data: [EventDataItem]
    let count: Int
    let page: Int
    let pageSize: Int
}

struct EventDataItem: Codable, Identifiable, Sendable {
    let id: String
    let websiteId: String
    let eventName: String
    let propertyName: String?
    let dataType: Int?
    let value: String?
    let createdAt: String
}

struct EventDataEvent: Codable, Identifiable, Sendable {
    let eventName: String
    let propertyName: String?
    let total: Int

    var id: String { "\(eventName)-\(propertyName ?? "")" }
}

struct EventDataField: Codable, Identifiable, Sendable {
    let propertyName: String
    let dataType: Int
    let total: Int

    var id: String { propertyName }
}

struct EventDataFieldValue: Codable, Identifiable, Sendable {
    let propertyName: String
    let dataType: Int
    let value: String
    let total: Int

    var id: String { "\(propertyName)-\(value)" }
}

struct EventDataProperty: Codable, Identifiable, Sendable {
    let eventName: String
    let propertyName: String
    let total: Int

    var id: String { "\(eventName)-\(propertyName)" }
}

struct EventDataValue: Codable, Identifiable, Sendable {
    let value: String
    let total: Int

    var id: String { value }
}

struct EventDataStats: Codable, Sendable {
    let events: Int
    let properties: Int
    let records: Int
}
