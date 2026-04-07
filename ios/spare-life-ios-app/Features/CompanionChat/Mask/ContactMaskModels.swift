import Foundation

struct MaskToneOption: Identifiable, Hashable {
    let id: String
    let label: String
    let description: String
}

struct ContactMaskConfig: Identifiable, Hashable {
    var id: String { contactID }
    let contactID: String
    var maskName: String
    var tone: String
    var topicWhitelist: [String]
    var topicBlacklist: [String]
    var disclosureLevel: Int
    var historyLog: [MaskHistoryEntry]
}

struct MaskHistoryEntry: Identifiable, Hashable {
    let id: String
    let timestamp: Date
    let changedField: String
    let oldValue: String
    let newValue: String
}
