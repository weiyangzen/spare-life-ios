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

enum ConversationCounterpartMode: String, Codable, CaseIterable, Hashable, Identifiable {
    case human
    case persona

    var id: String { rawValue }

    var label: String {
        switch self {
        case .human:   return "真人"
        case .persona: return "分身"
        }
    }

    var icon: String {
        switch self {
        case .human:   return "person.fill"
        case .persona: return "sparkles"
        }
    }

    var tint: Color {
        switch self {
        case .human:   return .blue
        case .persona: return .spareYellow
        }
    }

    func helperText(contactName: String) -> String {
        switch self {
        case .human:
            return "当前直接和 \(contactName) 的真人聊天，消息列表保持标准 IM 语义。"
        case .persona:
            return "当前切到 \(contactName) 的分身代聊，消息气泡与输入提示会同步切换。"
        }
    }

    func recipientName(contactName: String) -> String {
        switch self {
        case .human:
            return contactName
        case .persona:
            return "\(contactName)的分身"
        }
    }

    static func defaultMode(for kind: ConversationKind) -> ConversationCounterpartMode {
        kind == .agentDirect ? .persona : .human
    }
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
    var isOnline: Bool = false                      // 联系人在线状态
    var isTyping: Bool = false                      // 正在输入指示
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
    var id: String { contactID }
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

// MARK: - Sort Mode

enum ConversationSortMode: String, CaseIterable, Identifiable {
    case byTime   = "by_time"
    case byUnread = "by_unread"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .byTime:   return "按时间"
        case .byUnread: return "按未读"
        }
    }

    var icon: String {
        switch self {
        case .byTime:   return "clock"
        case .byUnread: return "envelope.badge"
        }
    }
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

    /// The most recently active contacts, shown as a quick-access horizontal
    /// avatar strip at the top of the IM hub (Blueprint line:1152).
    var recentContacts: [ConversationThread] {
        Array(
            threads
                .sorted { $0.lastTimestamp > $1.lastTimestamp }
                .prefix(8)
        )
    }

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
        do {
            threads = try CompanionChatSeedLoader.loadThreads()
            loadState = .loaded
        } catch {
            loadState = .error(error.localizedDescription)
        }
    }

    func refresh() async {
        do {
            self.threads = try CompanionChatSeedLoader.loadThreads()
            self.loadState = .loaded
        } catch {
            self.loadState = .error(error.localizedDescription)
        }
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
}

// MARK: - Local Seed / Mode Persistence

enum CompanionChatSeedLoader {
    private static let cacheKey = "companion_chat.local_seed.v1"

    static func loadThreads() throws -> [ConversationThread] {
        let document = try loadDocument()
        return try document.threads.map { try $0.thread }
    }

    private static func loadDocument(defaults: UserDefaults = .standard) throws -> CompanionChatSeedDocument {
        let seedData: Data
        if let cached = defaults.data(forKey: cacheKey) {
            seedData = cached
        } else {
            guard let embedded = CompanionChatEmbeddedSeed.payload.data(using: .utf8) else {
                throw CompanionChatSeedError.seedUnavailable
            }
            defaults.set(embedded, forKey: cacheKey)
            seedData = embedded
        }

        do {
            return try JSONDecoder().decode(CompanionChatSeedDocument.self, from: seedData)
        } catch {
            defaults.removeObject(forKey: cacheKey)
            throw CompanionChatSeedError.decodeFailed(error.localizedDescription)
        }
    }
}

enum CompanionChatModeStore {
    private static let keyPrefix = "companion_chat.counterpart_mode."

    static func load(
        threadID: String,
        defaults: UserDefaults = .standard,
        defaultMode: ConversationCounterpartMode
    ) -> ConversationCounterpartMode {
        guard
            let rawValue = defaults.string(forKey: keyPrefix + threadID),
            let mode = ConversationCounterpartMode(rawValue: rawValue)
        else {
            return defaultMode
        }
        return mode
    }

    static func save(
        _ mode: ConversationCounterpartMode,
        threadID: String,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(mode.rawValue, forKey: keyPrefix + threadID)
    }
}

private enum CompanionChatSeedError: LocalizedError {
    case seedUnavailable
    case decodeFailed(String)
    case invalidThread(String)

    var errorDescription: String? {
        switch self {
        case .seedUnavailable:
            return "消息联系人本地 seed 不可用。"
        case .decodeFailed(let detail):
            return "解析消息联系人本地 seed 失败：\(detail)"
        case .invalidThread(let detail):
            return "消息联系人 seed 无效：\(detail)"
        }
    }
}

private struct CompanionChatSeedDocument: Decodable {
    let threads: [ThreadRecord]

    struct ThreadRecord: Decodable {
        let id: String
        let contactName: String
        let avatarSeed: Int
        let kind: String
        let lastMessage: String
        let lastMinutesAgo: Int
        let unreadCount: Int
        let isPinned: Bool
        let relationTemperature: String
        let activeMaskName: String?
        let isOnline: Bool
        let isTyping: Bool

        enum CodingKeys: String, CodingKey {
            case id
            case contactName = "contact_name"
            case avatarSeed = "avatar_seed"
            case kind
            case lastMessage = "last_message"
            case lastMinutesAgo = "last_minutes_ago"
            case unreadCount = "unread_count"
            case isPinned = "is_pinned"
            case relationTemperature = "relation_temperature"
            case activeMaskName = "active_mask_name"
            case isOnline = "is_online"
            case isTyping = "is_typing"
        }

        var thread: ConversationThread {
            get throws {
                guard let kind = ConversationKind(rawValue: kind) else {
                    throw CompanionChatSeedError.invalidThread("未知对话类型：\(kind)")
                }
                guard let relationTemperature = RelationTemperature(rawValue: relationTemperature) else {
                    throw CompanionChatSeedError.invalidThread("未知关系温度：\(relationTemperature)")
                }

                return ConversationThread(
                    id: id,
                    contactName: contactName,
                    avatarSeed: avatarSeed,
                    kind: kind,
                    lastMessage: lastMessage,
                    lastTimestamp: Date().addingTimeInterval(-Double(max(lastMinutesAgo, 0)) * 60),
                    unreadCount: unreadCount,
                    isPinned: isPinned,
                    relationTemperature: relationTemperature,
                    activeMaskName: activeMaskName,
                    isOnline: isOnline,
                    isTyping: isTyping
                )
            }
        }
    }
}

private enum CompanionChatEmbeddedSeed {
    static let payload = """
    {
      "threads": [
        {
          "id": "t1",
          "contact_name": "林熙",
          "avatar_seed": 2,
          "kind": "human",
          "last_message": "下午一起去那个咖啡馆？",
          "last_minutes_ago": 5,
          "unread_count": 2,
          "is_pinned": true,
          "relation_temperature": "close",
          "active_mask_name": "温柔模式",
          "is_online": true,
          "is_typing": true
        },
        {
          "id": "t2",
          "contact_name": "陈明",
          "avatar_seed": 5,
          "kind": "quadRole",
          "last_message": "你的分身刚才说了个很有趣的观点",
          "last_minutes_ago": 18,
          "unread_count": 5,
          "is_pinned": false,
          "relation_temperature": "warm",
          "active_mask_name": null,
          "is_online": true,
          "is_typing": false
        },
        {
          "id": "t3",
          "contact_name": "李雪",
          "avatar_seed": 1,
          "kind": "human",
          "last_message": "收到，我会准时到的",
          "last_minutes_ago": 42,
          "unread_count": 0,
          "is_pinned": false,
          "relation_temperature": "warm",
          "active_mask_name": "职场正式",
          "is_online": false,
          "is_typing": false
        },
        {
          "id": "t4",
          "contact_name": "张伟",
          "avatar_seed": 3,
          "kind": "agentDirect",
          "last_message": "你的分身：我帮你整理了今日任务清单。",
          "last_minutes_ago": 70,
          "unread_count": 1,
          "is_pinned": false,
          "relation_temperature": "cold",
          "active_mask_name": null,
          "is_online": true,
          "is_typing": false
        },
        {
          "id": "t5",
          "contact_name": "王舒宁",
          "avatar_seed": 6,
          "kind": "human",
          "last_message": "周末去看展吗？我刚买到两张票。",
          "last_minutes_ago": 95,
          "unread_count": 3,
          "is_pinned": false,
          "relation_temperature": "warming",
          "active_mask_name": "轻松破冰",
          "is_online": true,
          "is_typing": true
        },
        {
          "id": "t6",
          "contact_name": "许诺",
          "avatar_seed": 7,
          "kind": "quadRole",
          "last_message": "我这边让分身先同步一下会前资料",
          "last_minutes_ago": 160,
          "unread_count": 0,
          "is_pinned": false,
          "relation_temperature": "warm",
          "active_mask_name": "合作模式",
          "is_online": false,
          "is_typing": false
        },
        {
          "id": "t7",
          "contact_name": "赵一帆",
          "avatar_seed": 4,
          "kind": "human",
          "last_message": "晚上跑步的话我 8 点到楼下",
          "last_minutes_ago": 230,
          "unread_count": 4,
          "is_pinned": false,
          "relation_temperature": "close",
          "active_mask_name": null,
          "is_online": true,
          "is_typing": false
        },
        {
          "id": "t8",
          "contact_name": "苏棠",
          "avatar_seed": 9,
          "kind": "human",
          "last_message": "那家店我帮你问过了，可以带宠物。",
          "last_minutes_ago": 430,
          "unread_count": 0,
          "is_pinned": false,
          "relation_temperature": "warming",
          "active_mask_name": "邻里随和",
          "is_online": false,
          "is_typing": false
        },
        {
          "id": "t9",
          "contact_name": "周岚",
          "avatar_seed": 10,
          "kind": "agentDirect",
          "last_message": "分身已确认明天上午 10 点回访。",
          "last_minutes_ago": 980,
          "unread_count": 2,
          "is_pinned": false,
          "relation_temperature": "cold",
          "active_mask_name": "咨询窗口",
          "is_online": false,
          "is_typing": false
        },
        {
          "id": "t10",
          "contact_name": "何川",
          "avatar_seed": 11,
          "kind": "human",
          "last_message": "资料我收到了，晚点给你反馈。",
          "last_minutes_ago": 1600,
          "unread_count": 0,
          "is_pinned": false,
          "relation_temperature": "warm",
          "active_mask_name": null,
          "is_online": false,
          "is_typing": false
        }
      ]
    }
    """
}
