import Foundation

enum CompanionMessagesChannel: String, Hashable, Sendable {
    case companion
}

enum CompanionSurfacePresentationMode: Hashable, Sendable {
    case embedded
    case modal
}

enum MessagesConversationLocator: Hashable, Sendable {
    case conversation(conversationID: String)
    case group(channelID: String, groupID: String)
    case dm(channelID: String, peerID: String)

    var sourceChannelID: String {
        switch self {
        case .conversation:
            return CompanionMessagesChannel.companion.rawValue
        case .group(let channelID, _), .dm(let channelID, _):
            return channelID
        }
    }

    var canonicalThreadID: String {
        switch self {
        case .conversation(let conversationID):
            return "conversation:\(conversationID)"
        case .group(let channelID, let groupID):
            return "group:\(channelID):\(groupID)"
        case .dm(let channelID, let peerID):
            return "dm:\(channelID):\(peerID)"
        }
    }

    var legacyThreadRoute: String {
        switch self {
        case .conversation(let conversationID):
            return "sparelife://messages/thread?conversation_id=\(conversationID)"
        case .group(let channelID, let groupID):
            return "sparelife://messages/thread?channel_id=\(channelID)&group_id=\(groupID)"
        case .dm(let channelID, let peerID):
            return "sparelife://messages/thread?channel_id=\(channelID)&dm_peer_id=\(peerID)"
        }
    }
}

struct MessagesThreadIdentity: Hashable, Sendable {
    let locator: MessagesConversationLocator
    let canonicalThreadID: String
    let sourceChannelID: String

    init(
        locator: MessagesConversationLocator,
        sourceChannelID: String? = nil
    ) {
        let resolvedChannelID = sourceChannelID ?? locator.sourceChannelID
        self.locator = locator
        self.canonicalThreadID = locator.canonicalThreadID
        self.sourceChannelID = resolvedChannelID
    }
}
