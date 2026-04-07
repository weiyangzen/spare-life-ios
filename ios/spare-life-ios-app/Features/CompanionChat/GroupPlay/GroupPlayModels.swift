import Foundation
import SwiftUI

enum GroupAgentRole: String, CaseIterable, Identifiable {
    case host
    case scribe
    case vibe
    case proposer

    var id: String { rawValue }

    var label: String {
        switch self {
        case .host:
            return "主持人"
        case .scribe:
            return "书记员"
        case .vibe:
            return "气氛组"
        case .proposer:
            return "提案器"
        }
    }

    var icon: String {
        switch self {
        case .host:
            return "person.wave.2.fill"
        case .scribe:
            return "list.bullet.rectangle.portrait.fill"
        case .vibe:
            return "sparkles"
        case .proposer:
            return "lightbulb.fill"
        }
    }

    var tint: Color {
        switch self {
        case .host, .scribe, .proposer:
            return .spareYellowInk
        case .vibe:
            return .emotionPositive
        }
    }

    var summaryHint: String {
        switch self {
        case .host:
            return "负责控节奏、拉齐规则并收口结论"
        case .scribe:
            return "负责提炼共识、自动整理纪要与行动项"
        case .vibe:
            return "负责暖场、降噪，避免讨论变成刷屏"
        case .proposer:
            return "负责发起议题、补全候选方案"
        }
    }
}

struct GroupPlayMessage: Identifiable, Hashable {
    let id: String
    let sender: String
    let role: GroupAgentRole?
    let content: String
    let timestamp: Date
    let isSuppressed: Bool
}

struct GroupVoteChoice: Identifiable, Hashable {
    let id: String
    let title: String
    var count: Int
    var selectedByMe: Bool
}

struct GroupVoteSession: Identifiable, Hashable {
    enum Status: String {
        case open
        case closed
    }

    let id: String
    let question: String
    var choices: [GroupVoteChoice]
    var status: Status
    let createdAt: Date
    let deadline: Date?
}

struct GroupSummaryRecord: Identifiable, Hashable {
    let id: String
    let headline: String
    let body: String
    let actionCount: Int
    let suppressedCount: Int
    let timestamp: Date
}

struct GroupActionItem: Identifiable, Hashable {
    let id: String
    let title: String
    let owner: String
    let dueAt: Date?
    var done: Bool
}

struct GroupPlaySnapshot: Hashable {
    let groupTitle: String
    let memberNames: [String]
    var residentAgentEnabled: Bool
    let noiseThreshold: Int
    var messages: [GroupPlayMessage]
    var votes: [GroupVoteSession]
    var summaries: [GroupSummaryRecord]
    var actionItems: [GroupActionItem]
}

enum GroupPlayLoadState: Equatable {
    case idle
    case loading
    case loaded
    case error(String)
}
