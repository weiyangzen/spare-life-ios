// CompanionChatStore.swift
// Spare Life – 消息 / 熟人聊天 共享数据模型与 Store
// Blueprint §消息 功能点 1137-1141 (line:1137-1141)
// UIUX lane – slot 2

import Foundation
import SwiftUI

// MARK: - Conversation Thread (IM hub model)

enum ConversationKind: String, Hashable {
    case human          // 普通熟人 1v1
    case quadRole       // 真人 + 双方分身同场
    case group          // 群聊
    case agentDirect    // 直接和分身聊
}

struct ConversationThread: Identifiable, Hashable {
    let id: String
    let contactName: String
    let avatarSeed: Int
    let kind: ConversationKind
    var lastMessage: String
    var lastTimestamp: Date
    var unreadCount: Int
    var isPinned: Bool
    var relationTemperature: RelationTemperature   // 熟人关系温度
    var activeMaskName: String?                     // 当前对该联系人启用的面具名称
}

// MARK: - Relation Temperature (跨会话情感连续性)

enum RelationTemperature: String, CaseIterable, Identifiable {
    case cold    = "cold"
    case warming = "warming"
    case warm    = "warm"
    case close   = "close"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cold:    return "陌生"
        case .warming: return "升温"
        case .warm:    return "熟悉"
        case .close:   return "亲近"
        }
    }

    var color: Color {
        switch self {
        case .cold:    return .emotionNeutral
        case .warming: return .emotionSplit
        case .warm:    return Color(red: 0.28, green: 0.63, blue: 1.00)
        case .close:   return .emotionPositive
        }
    }

    var icon: String {
        switch self {
        case .cold:    return "thermometer.snowflake"
        case .warming: return "flame"
        case .warm:    return "sun.max.fill"
        case .close:   return "heart.fill"
        }
    }
}

// MARK: - Chat Message

enum ChatSenderRole: String, Hashable {
    case myHuman     = "my_human"
    case myPersona   = "my_persona"
    case theirHuman  = "their_human"
    case theirPersona = "their_persona"
    case agentHelper = "agent_helper"   // Agent 辅助线程
    case system      = "system"

    var displayName: String {
        switch self {
        case .myHuman:      return "我"
        case .myPersona:    return "我的分身"
        case .theirHuman:   return "对方"
        case .theirPersona: return "对方分身"
        case .agentHelper:  return "Agent 助手"
        case .system:       return "系统"
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
        case .myHuman:      return .spareYellow
        case .myPersona:    return Color(red: 1.00, green: 0.94, blue: 0.60)
        case .theirHuman:   return Color(.secondarySystemGroupedBackground)
        case .theirPersona: return Color(red: 0.90, green: 0.93, blue: 1.00)
        case .agentHelper:  return Color(red: 0.94, green: 0.95, blue: 1.00)
        case .system:       return Color.secondary.opacity(0.15)
        }
    }
}

struct ChatMessage: Identifiable, Hashable {
    let id: String
    let senderRole: ChatSenderRole
    let senderName: String
    let content: String
    let timestamp: Date
    var isAgentThread: Bool       // true = 属于 Agent 辅助线程，不在主线程显示
    var referencedMessageID: String?
}

// MARK: - Contact Mask (per-contact 面具覆写)

struct MaskToneOption: Identifiable, Hashable {
    let id: String
    let label: String
    let description: String
}

struct ContactMaskConfig: Identifiable, Hashable {
    let contactID: String
    var maskName: String
    var tone: String          // e.g. "professional", "casual", "warm"
    var topicWhitelist: [String]
    var topicBlacklist: [String]
    var disclosureLevel: Int  // 0-4: 不透露 → 全透露
    var historyLog: [MaskHistoryEntry]
}

struct MaskHistoryEntry: Identifiable, Hashable {
    let id: String
    let timestamp: Date
    let changedField: String
    let oldValue: String
    let newValue: String
}

// MARK: - Bond / Relationship Rituals (关系养成)

enum BondTaskStatus: String, Hashable {
    case pending, inProgress, done, expired

    var icon: String {
        switch self {
        case .pending:    return "circle"
        case .inProgress: return "arrow.triangle.2.circlepath.circle.fill"
        case .done:       return "checkmark.circle.fill"
        case .expired:    return "xmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .pending:    return .secondary
        case .inProgress: return .blue
        case .done:       return .emotionPositive
        case .expired:    return .emotionNegative
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

struct MemorySnippet: Identifiable, Hashable {
    let id: String
    let summary: String
    let emotionTag: EmotionBadge.Emotion
    let timestamp: Date
    var isHighlighted: Bool
}

struct RelationshipProfile: Identifiable, Hashable {
    let id: String               // same as contactID
    let contactName: String
    let temperature: RelationTemperature
    let bondLevel: Int           // 0-100
    var bondTasks: [BondTask]
    var anniversaries: [AnniversaryCard]
    var memoryThread: [MemorySnippet]
}

// MARK: - Conversation Hub Store (IM首页)

enum ConversationHubLoadState {
    case idle, loading, loaded, error(String)
}

@MainActor
final class ConversationHubStore: ObservableObject {
    @Published private(set) var loadState: ConversationHubLoadState = .idle
    @Published private(set) var threads: [ConversationThread] = []
    @Published var searchQuery: String = ""
    @Published var selectedKind: ConversationKind? = nil

    var filteredThreads: [ConversationThread] {
        var result = threads
        if let kind = selectedKind {
            result = result.filter { $0.kind == kind }
        }
        if !searchQuery.isEmpty {
            let q = searchQuery.lowercased()
            result = result.filter {
                $0.contactName.lowercased().contains(q) ||
                $0.lastMessage.lowercased().contains(q)
            }
        }
        return result.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.lastTimestamp > $1.lastTimestamp
        }
    }

    var totalUnread: Int {
        threads.reduce(0) { $0 + $1.unreadCount }
    }

    func load() {
        guard case .idle = loadState else { return }
        loadState = .loading
        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            self.threads = Self.mockThreads()
            self.loadState = .loaded
        }
    }

    func refresh() async {
        try? await Task.sleep(nanoseconds: 400_000_000)
        self.threads = Self.mockThreads()
    }

    func markRead(threadID: String) {
        if let idx = threads.firstIndex(where: { $0.id == threadID }) {
            threads[idx].unreadCount = 0
        }
    }

    func pin(threadID: String) {
        if let idx = threads.firstIndex(where: { $0.id == threadID }) {
            threads[idx].isPinned.toggle()
        }
    }

    func retry() { loadState = .idle; load() }

    // MARK: Mock

    static func mockThreads() -> [ConversationThread] {
        [
            ConversationThread(
                id: "t1", contactName: "林熙", avatarSeed: 2, kind: .human,
                lastMessage: "下午一起去那个咖啡馆？",
                lastTimestamp: Date() - 300, unreadCount: 2, isPinned: true,
                relationTemperature: .close, activeMaskName: "温柔模式"
            ),
            ConversationThread(
                id: "t2", contactName: "陈明", avatarSeed: 5, kind: .quadRole,
                lastMessage: "你的分身刚才说了个很有趣的观点",
                lastTimestamp: Date() - 1800, unreadCount: 5, isPinned: false,
                relationTemperature: .warm, activeMaskName: nil
            ),
            ConversationThread(
                id: "t3", contactName: "周游 & 王芳", avatarSeed: 8, kind: .group,
                lastMessage: "王芳：明天的活动确认参加！",
                lastTimestamp: Date() - 3600, unreadCount: 0, isPinned: false,
                relationTemperature: .warming, activeMaskName: nil
            ),
            ConversationThread(
                id: "t4", contactName: "李雪", avatarSeed: 1, kind: .human,
                lastMessage: "收到，我会准时到的",
                lastTimestamp: Date() - 7200, unreadCount: 0, isPinned: false,
                relationTemperature: .warm, activeMaskName: "职场正式"
            ),
            ConversationThread(
                id: "t5", contactName: "张伟", avatarSeed: 3, kind: .agentDirect,
                lastMessage: "你的分身：我帮你整理了今日任务清单。",
                lastTimestamp: Date() - 86400, unreadCount: 1, isPinned: false,
                relationTemperature: .cold, activeMaskName: nil
            ),
        ]
    }
}
