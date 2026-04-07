import Foundation

enum AppSurfaceID: String, Hashable, Sendable {
    case xianxia
    case masters
    case earnSocial = "earn_social"
    case messages
    case myProfile = "my_profile"

    var title: String {
        switch self {
        case .xianxia:
            return "闲虾"
        case .masters:
            return "闲聊"
        case .earnSocial:
            return "赚闲能"
        case .messages:
            return "消息"
        case .myProfile:
            return "我的"
        }
    }
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

enum EarnSocialHandoffRoute: Hashable, Sendable {
    case market(lane: EarnSocialLaneID, topic: String?)
}

enum MyProfileHandoffRoute: Hashable, Sendable {
    case home
}

enum CrossTabHandoffRoute: Hashable, Sendable {
    case messages(MessagesHandoffRoute)
    case earnSocial(EarnSocialHandoffRoute)
    case myProfile(MyProfileHandoffRoute)
}

enum MessagesPendingHandoff: Hashable, Sendable {
    case composeDraft(
        draftID: String,
        seedText: String?,
        sessionID: String?,
        recipientLocator: MessagesConversationLocator?
    )
    case legacyThreadLaneCounterpart(
        laneID: String,
        counterpartName: String
    )
    case legacyBondBridge(
        bondID: String,
        icebreakSessionID: String?
    )
    case unresolvedThread(
        locator: MessagesConversationLocator,
        hint: [String: String]
    )
}

enum MyProfilePendingHandoff: Hashable, Sendable {
    case highlightMemory(sourceSurface: AppSurfaceID)
}

enum CrossTabPendingHandoff: Hashable, Sendable {
    case messages(MessagesPendingHandoff)
    case myProfile(MyProfilePendingHandoff)

    var messagesValue: MessagesPendingHandoff? {
        guard case .messages(let pending) = self else { return nil }
        return pending
    }

    var myProfileValue: MyProfilePendingHandoff? {
        guard case .myProfile(let pending) = self else { return nil }
        return pending
    }
}

struct CrossTabHandoff: Identifiable, Hashable, Sendable {
    let id: String
    let sourceSurface: AppSurfaceID
    let targetSurface: AppSurfaceID
    let createdAt: Date
    let payloadVersion: Int
    let route: CrossTabHandoffRoute
    let pending: CrossTabPendingHandoff?

    init(
        id: String = UUID().uuidString.lowercased(),
        sourceSurface: AppSurfaceID,
        targetSurface: AppSurfaceID,
        createdAt: Date = Date(),
        payloadVersion: Int = 1,
        route: CrossTabHandoffRoute,
        pending: CrossTabPendingHandoff? = nil
    ) {
        self.id = id
        self.sourceSurface = sourceSurface
        self.targetSurface = targetSurface
        self.createdAt = createdAt
        self.payloadVersion = payloadVersion
        self.route = route
        self.pending = pending
    }

    var messagesPending: MessagesPendingHandoff? {
        pending?.messagesValue
    }

    var myProfilePending: MyProfilePendingHandoff? {
        pending?.myProfileValue
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
                targetSurface: .messages,
                route: .messages(.home(tab: "recent"))
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
                targetSurface: .messages,
                route: .messages(
                    .composeDraft(
                        draftID: context.draftID,
                        seedText: context.seedText,
                        recipientLocator: context.recipient?.locator
                    )
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
            targetSurface: .messages,
            route: .messages(
                .thread(
                    locator: context.locator,
                    hint: hint
                )
            )
        )
    }
}

enum LegacyAppRouteBuilder {
    static func messagesComposeDraft(
        draft: String? = nil,
        sessionID: String? = nil
    ) -> String {
        buildURL(
            host: "messages",
            path: "self",
            query: [
                "draft": sanitized(draft),
                "session_id": sanitized(sessionID)
            ]
        )
    }

    static func messagesThread(
        lane: EarnSocialLaneID,
        counterpartName: String
    ) -> String {
        buildURL(
            host: "messages",
            path: "thread",
            query: [
                "lane": lane.rawValue,
                "counterpart": sanitized(counterpartName)
            ]
        )
    }

    static func messagesBondBridge(
        bondID: String,
        icebreakSessionID: String? = nil
    ) -> String {
        buildURL(
            host: "messages",
            path: "thread",
            query: [
                "bond_id": sanitized(bondID),
                "icebreak_session_id": sanitized(icebreakSessionID)
            ]
        )
    }

    static func myProfileMemoryHighlight() -> String {
        buildURL(
            host: "my",
            path: "profile",
            query: ["highlight": "memory"]
        )
    }

    static func earnSocialMarket(
        lane: EarnSocialLaneID,
        topic: String? = nil
    ) -> String {
        buildURL(
            host: "earn-social",
            path: "market",
            query: [
                "lane": lane.rawValue,
                "topic": sanitized(topic)
            ]
        )
    }

    private static func buildURL(
        host: String,
        path: String,
        query: [String: String?]
    ) -> String {
        var components = URLComponents()
        components.scheme = "sparelife"
        components.host = host
        components.path = "/\(path)"
        let items = query.compactMap { key, value -> URLQueryItem? in
            guard let value, !value.isEmpty else { return nil }
            return URLQueryItem(name: key, value: value)
        }
        if !items.isEmpty {
            components.queryItems = items
        }
        return components.string ?? "sparelife://\(host)/\(path)"
    }

    private static func sanitized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

enum LegacyAppRouteNormalizer {
    static func normalize(
        _ rawRoute: String,
        sourceSurface: AppSurfaceID,
        homeTab: String = "recent"
    ) -> CrossTabHandoff? {
        guard let components = normalizedURLComponents(from: rawRoute) else { return nil }
        let host = components.host?.lowercased() ?? ""
        let path = normalizedPath(components.path)
        let query = queryMap(from: components.queryItems)

        switch (host, path) {
        case ("messages", "self"):
            let draft = query["draft"]
            let sessionID = query["session_id"]
            guard draft != nil || sessionID != nil else { return nil }
            let draftID = composeDraftID(draft: draft, sessionID: sessionID)
            let pending = MessagesPendingHandoff.composeDraft(
                draftID: draftID,
                seedText: draft,
                sessionID: sessionID,
                recipientLocator: nil
            )
            return CrossTabHandoff(
                sourceSurface: sourceSurface,
                targetSurface: .messages,
                route: .messages(
                    .composeDraft(
                        draftID: draftID,
                        seedText: draft,
                        recipientLocator: nil
                    )
                ),
                pending: .messages(pending)
            )

        case ("messages", "thread"):
            if let bondID = query["bond_id"] {
                return CrossTabHandoff(
                    sourceSurface: sourceSurface,
                    targetSurface: .messages,
                    route: .messages(.home(tab: homeTab)),
                    pending: .messages(
                        .legacyBondBridge(
                            bondID: bondID,
                            icebreakSessionID: query["icebreak_session_id"]
                        )
                    )
                )
            }

            if let laneID = query["lane"], let counterpartName = query["counterpart"] {
                return CrossTabHandoff(
                    sourceSurface: sourceSurface,
                    targetSurface: .messages,
                    route: .messages(.home(tab: homeTab)),
                    pending: .messages(
                        .legacyThreadLaneCounterpart(
                            laneID: laneID,
                            counterpartName: counterpartName
                        )
                    )
                )
            }

            return nil

        case ("my", "profile"):
            let pending: CrossTabPendingHandoff? = if query["highlight"] == "memory" {
                .myProfile(.highlightMemory(sourceSurface: sourceSurface))
            } else {
                nil
            }
            return CrossTabHandoff(
                sourceSurface: sourceSurface,
                targetSurface: .myProfile,
                route: .myProfile(.home),
                pending: pending
            )

        case ("earn-social", "market"):
            guard let laneValue = query["lane"], let lane = EarnSocialLaneID(rawValue: laneValue) else {
                return nil
            }
            return CrossTabHandoff(
                sourceSurface: sourceSurface,
                targetSurface: .earnSocial,
                route: .earnSocial(
                    .market(
                        lane: lane,
                        topic: query["topic"]
                    )
                )
            )

        default:
            return nil
        }
    }

    private static func normalizedURLComponents(from rawRoute: String) -> URLComponents? {
        let trimmed = rawRoute.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let components = URLComponents(string: trimmed), components.scheme == "sparelife" else {
            return nil
        }
        return components
    }

    private static func normalizedPath(_ rawPath: String) -> String {
        rawPath.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
    }

    private static func queryMap(from items: [URLQueryItem]?) -> [String: String] {
        (items ?? []).reduce(into: [:]) { partialResult, item in
            let key = item.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { return }
            let value = item.value?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let value, !value.isEmpty else { return }
            partialResult[key] = value
        }
    }

    private static func composeDraftID(
        draft: String?,
        sessionID: String?
    ) -> String {
        let parts = [sessionID, draft].compactMap { value in
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (trimmed?.isEmpty == false) ? trimmed : nil
        }
        let suffix = stableIdentifierSuffix(from: parts)
        return "legacy-draft-\(suffix)"
    }

    private static func stableIdentifierSuffix(from parts: [String]) -> String {
        let joined = parts.joined(separator: "-")
        guard !joined.isEmpty else { return "default" }

        let slug = joined
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")

        if !slug.isEmpty {
            return String(slug.prefix(24))
        }

        let hex = joined.unicodeScalars.prefix(6)
            .map { String(format: "%04x", $0.value) }
            .joined()

        return hex.isEmpty ? "default" : hex
    }
}
