import SwiftUI

enum ChatSenderRole: String, Hashable {
    case myHuman = "my_human"
    case myPersona = "my_persona"
    case theirHuman = "their_human"
    case theirPersona = "their_persona"
    case agentHelper = "agent_helper"
    case system = "system"

    var displayName: String {
        switch self {
        case .myHuman:
            return "我"
        case .myPersona:
            return "我的分身"
        case .theirHuman:
            return "对方"
        case .theirPersona:
            return "对方分身"
        case .agentHelper:
            return "Agent 助手"
        case .system:
            return "系统"
        }
    }

    var isLocal: Bool {
        self == .myHuman || self == .myPersona
    }

    var isAgent: Bool {
        self == .agentHelper || self == .myPersona || self == .theirPersona
    }

    var bubbleColor: Color {
        switch self {
        case .myHuman:
            return .spareYellow
        case .myPersona:
            return .spareYellowLight
        case .theirHuman:
            return Color(.secondarySystemGroupedBackground)
        case .theirPersona:
            return .spareYellowWash
        case .agentHelper:
            return Color.spareYellow.opacity(0.14)
        case .system:
            return Color.secondary.opacity(0.15)
        }
    }
}

struct ChatMessage: Identifiable, Hashable {
    let id: String
    let senderRole: ChatSenderRole
    let senderName: String
    let content: String
    let timestamp: Date
    var isAgentThread: Bool
    var referencedMessageID: String?
}
