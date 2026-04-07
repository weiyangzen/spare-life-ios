import Foundation
import SwiftUI

enum BondTaskStatus: String, Hashable {
    case pending
    case inProgress
    case done
    case expired

    var icon: String {
        switch self {
        case .pending:
            return "circle"
        case .inProgress:
            return "arrow.triangle.2.circlepath.circle.fill"
        case .done:
            return "checkmark.circle.fill"
        case .expired:
            return "xmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .pending:
            return .secondary
        case .inProgress:
            return .spareYellowInk
        case .done:
            return .emotionPositive
        case .expired:
            return .emotionNegative
        }
    }
}

struct BondTask: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    var status: BondTaskStatus
    let rewardEnergy: Int
    let dueDate: Date?
}

struct AnniversaryCard: Identifiable, Hashable {
    let id: String
    let title: String
    let date: Date
    let note: String
    let emoji: String
}

struct RelationshipProfile: Identifiable, Hashable {
    let id: String
    let contactName: String
    let temperature: RelationTemperature
    let bondLevel: Int
    var bondTasks: [BondTask]
    var anniversaries: [AnniversaryCard]
    var memoryThread: [MemorySnippet]

    static func routeSeed(for thread: ConversationThread) -> RelationshipProfile {
        RelationshipProfile(
            id: thread.routePrimaryKey,
            contactName: thread.contactName,
            temperature: thread.relationTemperature,
            bondLevel: 68,
            bondTasks: [],
            anniversaries: [],
            memoryThread: []
        )
    }
}
