// ConversationRouter.swift
// Spare Life – typed messages route + handoff coordinator.

import SwiftUI

struct MessagesThreadContext: Hashable {
    let thread: ConversationThread
    let identity: MessagesThreadIdentity

    init(thread: ConversationThread) {
        self.thread = thread
        self.identity = thread.identity
    }

    var locator: MessagesConversationLocator {
        identity.locator
    }

    var canonicalThreadID: String {
        identity.canonicalThreadID
    }

    static func == (lhs: MessagesThreadContext, rhs: MessagesThreadContext) -> Bool {
        lhs.identity == rhs.identity
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(identity)
    }
}

struct MessagesGroupVoteContext: Hashable {
    let thread: MessagesThreadContext
    let voteID: String
    let title: String

    init(thread: ConversationThread, voteID: String, title: String) {
        self.thread = MessagesThreadContext(thread: thread)
        self.voteID = voteID
        self.title = title
    }

    init(thread: MessagesThreadContext, voteID: String, title: String) {
        self.thread = thread
        self.voteID = voteID
        self.title = title
    }

    static func == (lhs: MessagesGroupVoteContext, rhs: MessagesGroupVoteContext) -> Bool {
        lhs.thread == rhs.thread && lhs.voteID == rhs.voteID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(thread)
        hasher.combine(voteID)
    }
}

struct MessagesComposeDraftContext: Hashable {
    let draftID: String
    let seedText: String?
    let recipient: MessagesThreadContext?

    init(
        draftID: String = UUID().uuidString.lowercased(),
        seedText: String? = nil,
        recipient: ConversationThread? = nil
    ) {
        self.draftID = draftID
        self.seedText = seedText
        self.recipient = recipient.map(MessagesThreadContext.init(thread:))
    }

    init(
        draftID: String = UUID().uuidString.lowercased(),
        seedText: String? = nil,
        recipientContext: MessagesThreadContext?
    ) {
        self.draftID = draftID
        self.seedText = seedText
        self.recipient = recipientContext
    }

    static func == (lhs: MessagesComposeDraftContext, rhs: MessagesComposeDraftContext) -> Bool {
        lhs.draftID == rhs.draftID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(draftID)
    }
}

enum MessagesRoute: Hashable {
    case home
    case thread(MessagesThreadContext)
    case mask(MessagesThreadContext)
    case relationship(MessagesThreadContext)
    case memory(MessagesThreadContext)
    case quadRole(MessagesThreadContext)
    case groupPlay(MessagesThreadContext)
    case groupVote(MessagesGroupVoteContext)
    case composeDraft(MessagesComposeDraftContext)

    var canonicalStack: [MessagesRoute] {
        switch self {
        case .home:
            return []
        case .thread(let context):
            return [.thread(context)]
        case .mask(let context):
            return [.thread(context), .mask(context)]
        case .relationship(let context):
            return [.thread(context), .relationship(context)]
        case .memory(let context):
            return [.thread(context), .memory(context)]
        case .quadRole(let context):
            return [.thread(context), .quadRole(context)]
        case .groupPlay(let context):
            return [.thread(context), .groupPlay(context)]
        case .groupVote(let context):
            return [.thread(context.thread), .groupVote(context)]
        case .composeDraft(let context):
            return [.composeDraft(context)]
        }
    }

    var title: String {
        switch self {
        case .home:
            return "消息首页"
        case .thread:
            return "消息线程"
        case .mask:
            return "面具设置"
        case .relationship:
            return "关系养成"
        case .memory:
            return "跨会话记忆"
        case .quadRole:
            return "四人场"
        case .groupPlay:
            return "群聊玩法"
        case .groupVote:
            return "群投票"
        case .composeDraft:
            return "草稿撰写"
        }
    }
}

@MainActor
final class ConversationRouter: ObservableObject {
    @Published var path: [MessagesRoute] = []
    @Published private(set) var lastRequestedRoute: MessagesRoute = .home
    @Published private(set) var lastHandoff: CrossTabHandoff?
    @Published private(set) var handoffSerial: UInt64 = 0

    var currentRoute: MessagesRoute {
        path.last ?? .home
    }

    func goHome(sourceSurface: AppSurfaceID = .messages) {
        navigate(to: .home, sourceSurface: sourceSurface)
    }

    func open(_ route: MessagesRoute, sourceSurface: AppSurfaceID = .messages) {
        navigate(to: route, sourceSurface: sourceSurface)
    }

    func openChat(_ thread: ConversationThread, sourceSurface: AppSurfaceID = .messages) {
        open(.thread(MessagesThreadContext(thread: thread)), sourceSurface: sourceSurface)
    }

    func openMask(for thread: ConversationThread, sourceSurface: AppSurfaceID = .messages) {
        open(.mask(MessagesThreadContext(thread: thread)), sourceSurface: sourceSurface)
    }

    func openRelationship(for thread: ConversationThread, sourceSurface: AppSurfaceID = .messages) {
        open(.relationship(MessagesThreadContext(thread: thread)), sourceSurface: sourceSurface)
    }

    func openMemory(for thread: ConversationThread, sourceSurface: AppSurfaceID = .messages) {
        open(.memory(MessagesThreadContext(thread: thread)), sourceSurface: sourceSurface)
    }

    func openQuadRole(for thread: ConversationThread, sourceSurface: AppSurfaceID = .messages) {
        open(.quadRole(MessagesThreadContext(thread: thread)), sourceSurface: sourceSurface)
    }

    func openGroupPlay(for thread: ConversationThread, sourceSurface: AppSurfaceID = .messages) {
        open(.groupPlay(MessagesThreadContext(thread: thread)), sourceSurface: sourceSurface)
    }

    func openGroupVote(
        for thread: ConversationThread,
        voteID: String,
        title: String,
        sourceSurface: AppSurfaceID = .messages
    ) {
        open(
            .groupVote(MessagesGroupVoteContext(thread: thread, voteID: voteID, title: title)),
            sourceSurface: sourceSurface
        )
    }

    func openComposeDraft(
        draftID: String = UUID().uuidString.lowercased(),
        seedText: String? = nil,
        recipient: ConversationThread? = nil
    ) {
        open(
            .composeDraft(
                MessagesComposeDraftContext(
                    draftID: draftID,
                    seedText: seedText,
                    recipient: recipient
                )
            )
        )
    }

    private func navigate(to route: MessagesRoute, sourceSurface: AppSurfaceID = .messages) {
        lastRequestedRoute = route
        lastHandoff = route.handoff(sourceSurface: sourceSurface)
        path = route.canonicalStack
        handoffSerial &+= 1
    }
}
