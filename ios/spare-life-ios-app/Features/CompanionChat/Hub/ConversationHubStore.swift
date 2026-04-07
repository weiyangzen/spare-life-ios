import Foundation
import SwiftUI

enum ConversationKind: String, Hashable {
    case human
    case quadRole
    case group
    case agentDirect
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
    var relationTemperature: RelationTemperature
    var activeMaskName: String?
    var isOnline: Bool
    var isTyping: Bool
    let identity: MessagesThreadIdentity

    init(
        id: String,
        contactName: String,
        avatarSeed: Int,
        kind: ConversationKind,
        lastMessage: String,
        lastTimestamp: Date,
        unreadCount: Int,
        isPinned: Bool,
        relationTemperature: RelationTemperature,
        activeMaskName: String?,
        isOnline: Bool = false,
        isTyping: Bool = false,
        sourceChannelID: String = CompanionMessagesChannel.companion.rawValue,
        locator: MessagesConversationLocator? = nil
    ) {
        self.id = id
        self.contactName = contactName
        self.avatarSeed = avatarSeed
        self.kind = kind
        self.lastMessage = lastMessage
        self.lastTimestamp = lastTimestamp
        self.unreadCount = unreadCount
        self.isPinned = isPinned
        self.relationTemperature = relationTemperature
        self.activeMaskName = activeMaskName
        self.isOnline = isOnline
        self.isTyping = isTyping
        self.identity = MessagesThreadIdentity(
            locator: locator ?? .conversation(conversationID: id),
            sourceChannelID: sourceChannelID
        )
    }

    var locator: MessagesConversationLocator { identity.locator }
    var canonicalThreadID: String { identity.canonicalThreadID }
    var sourceChannelID: String { identity.sourceChannelID }
    var routePrimaryKey: String { canonicalThreadID }
}

enum ConversationSortMode: String, CaseIterable, Identifiable {
    case byTime = "by_time"
    case byUnread = "by_unread"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .byTime:
            return "按时间"
        case .byUnread:
            return "按未读"
        }
    }

    var icon: String {
        switch self {
        case .byTime:
            return "clock"
        case .byUnread:
            return "envelope.badge"
        }
    }
}

enum ConversationHubLoadState {
    case idle
    case loading
    case loaded
    case error(String)
}

@MainActor
final class ConversationHubStore: ObservableObject {
    @Published private(set) var loadState: ConversationHubLoadState = .idle
    @Published private(set) var threads: [ConversationThread] = []
    @Published var searchQuery = ""
    @Published var selectedKind: ConversationKind? = nil

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

    func retry() {
        loadState = .idle
        load()
    }

    static func mockThreads() -> [ConversationThread] {
        [
            ConversationThread(
                id: "t1",
                contactName: "Dubi",
                avatarSeed: 2,
                kind: .human,
                lastMessage: "那我先去占窗边的位置。",
                lastTimestamp: Date() - 300,
                unreadCount: 2,
                isPinned: true,
                relationTemperature: .close,
                activeMaskName: "温柔模式",
                isOnline: true,
                isTyping: false,
                locator: .dm(
                    channelID: CompanionMessagesChannel.companion.rawValue,
                    peerID: "contact-dubi"
                )
            ),
            ConversationThread(
                id: "t2",
                contactName: "Sophie",
                avatarSeed: 5,
                kind: .quadRole,
                lastMessage: "我让分身先把今晚的路线发你。",
                lastTimestamp: Date() - 1800,
                unreadCount: 5,
                isPinned: false,
                relationTemperature: .warm,
                activeMaskName: nil,
                isOnline: true,
                locator: .dm(
                    channelID: CompanionMessagesChannel.companion.rawValue,
                    peerID: "contact-sophie"
                )
            ),
            ConversationThread(
                id: "t3",
                contactName: "Omar & Aris(群)",
                avatarSeed: 8,
                kind: .group,
                lastMessage: "Aris：明晚先把场地定下来？",
                lastTimestamp: Date() - 3600,
                unreadCount: 0,
                isPinned: false,
                relationTemperature: .warming,
                activeMaskName: nil,
                locator: .group(
                    channelID: CompanionMessagesChannel.companion.rawValue,
                    groupID: "group-omar-aris"
                )
            ),
            ConversationThread(
                id: "t4",
                contactName: "Mia",
                avatarSeed: 1,
                kind: .human,
                lastMessage: "我把那份书单补在共享文档里了。",
                lastTimestamp: Date() - 7200,
                unreadCount: 0,
                isPinned: false,
                relationTemperature: .warm,
                activeMaskName: "职场正式",
                locator: .dm(
                    channelID: CompanionMessagesChannel.companion.rawValue,
                    peerID: "contact-mia"
                )
            ),
            ConversationThread(
                id: "t5",
                contactName: "Hannah",
                avatarSeed: 3,
                kind: .agentDirect,
                lastMessage: "我已经把你的待办拆成 3 个优先级。",
                lastTimestamp: Date() - 86400,
                unreadCount: 1,
                isPinned: false,
                relationTemperature: .cold,
                activeMaskName: nil,
                locator: .dm(
                    channelID: CompanionMessagesChannel.companion.rawValue,
                    peerID: "agent-hannah"
                )
            )
        ]
    }
}
