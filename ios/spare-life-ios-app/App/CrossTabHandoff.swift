import Foundation

enum AppSurfaceID: String, Hashable, Sendable {
    case xianxia
    case masters
    case earnSocial = "earn_social"
    case messages
    case myProfile = "my_profile"
}

enum MessagesHandoffRoute: Hashable, Sendable {
    case home(tab: String)
    case thread(locator: MessagesConversationLocator, hint: [String: String])
    case composeDraft(
        draftID: String,
        seedText: String?,
        recipientLocator: MessagesConversationLocator?
    )
}

struct CrossTabHandoff: Identifiable, Hashable, Sendable {
    let id: String
    let sourceSurface: AppSurfaceID
    let targetSurface: AppSurfaceID
    let createdAt: Date
    let payloadVersion: Int
    let route: MessagesHandoffRoute

    init(
        id: String = UUID().uuidString.lowercased(),
        sourceSurface: AppSurfaceID,
        targetSurface: AppSurfaceID = .messages,
        createdAt: Date = Date(),
        payloadVersion: Int = 1,
        route: MessagesHandoffRoute
    ) {
        self.id = id
        self.sourceSurface = sourceSurface
        self.targetSurface = targetSurface
        self.createdAt = createdAt
        self.payloadVersion = payloadVersion
        self.route = route
    }
}

private enum MessagesHandoffHintKey {
    static let subroute = "subroute"
    static let canonicalThreadID = "canonical_thread_id"
    static let voteID = "vote_id"
}

extension MessagesRoute {
    func handoff(sourceSurface: AppSurfaceID) -> CrossTabHandoff {
        switch self {
        case .home:
            return CrossTabHandoff(
                sourceSurface: sourceSurface,
                route: .home(tab: "recent")
            )
        case .thread(let context):
            return threadHandoff(
                for: context,
                sourceSurface: sourceSurface,
                hint: [:]
            )
        case .mask(let context):
            return threadHandoff(
                for: context,
                sourceSurface: sourceSurface,
                hint: [
                    MessagesHandoffHintKey.subroute: "mask",
                    MessagesHandoffHintKey.canonicalThreadID: context.canonicalThreadID
                ]
            )
        case .relationship(let context):
            return threadHandoff(
                for: context,
                sourceSurface: sourceSurface,
                hint: [
                    MessagesHandoffHintKey.subroute: "relationship",
                    MessagesHandoffHintKey.canonicalThreadID: context.canonicalThreadID
                ]
            )
        case .memory(let context):
            return threadHandoff(
                for: context,
                sourceSurface: sourceSurface,
                hint: [
                    MessagesHandoffHintKey.subroute: "memory",
                    MessagesHandoffHintKey.canonicalThreadID: context.canonicalThreadID
                ]
            )
        case .quadRole(let context):
            return threadHandoff(
                for: context,
                sourceSurface: sourceSurface,
                hint: [
                    MessagesHandoffHintKey.subroute: "quad_role",
                    MessagesHandoffHintKey.canonicalThreadID: context.canonicalThreadID
                ]
            )
        case .groupPlay(let context):
            return threadHandoff(
                for: context,
                sourceSurface: sourceSurface,
                hint: [
                    MessagesHandoffHintKey.subroute: "group_play",
                    MessagesHandoffHintKey.canonicalThreadID: context.canonicalThreadID
                ]
            )
        case .groupVote(let context):
            return threadHandoff(
                for: context.thread,
                sourceSurface: sourceSurface,
                hint: [
                    MessagesHandoffHintKey.subroute: "group_vote",
                    MessagesHandoffHintKey.canonicalThreadID: context.thread.canonicalThreadID,
                    MessagesHandoffHintKey.voteID: context.voteID
                ]
            )
        case .composeDraft(let context):
            return CrossTabHandoff(
                sourceSurface: sourceSurface,
                route: .composeDraft(
                    draftID: context.draftID,
                    seedText: context.seedText,
                    recipientLocator: context.recipient?.locator
                )
            )
        }
    }

    private func threadHandoff(
        for context: MessagesThreadContext,
        sourceSurface: AppSurfaceID,
        hint: [String: String]
    ) -> CrossTabHandoff {
        CrossTabHandoff(
            sourceSurface: sourceSurface,
            route: .thread(
                locator: context.locator,
                hint: hint
            )
        )
    }
}
