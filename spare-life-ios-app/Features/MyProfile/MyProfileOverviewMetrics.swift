import Foundation

struct MyProfileXianrenStats: Equatable {
    let channelCount: Int
    let topicCount: Int
    let uniqueIDCount: Int
    let mentionCount: Int
    let latestTopicAt: Date?
}

enum MyProfileXianrenLoadState: Equatable {
    case idle
    case loading
    case live(MyProfileXianrenStats)
    case cached(MyProfileXianrenStats, message: String)
    case failure(String)
}

struct MyProfileMasterStats: Equatable {
    let masterCount: Int
    let interactionCount: Int
    let latestInteractionAt: Date?

    static let empty = MyProfileMasterStats(
        masterCount: 0,
        interactionCount: 0,
        latestInteractionAt: nil
    )
}

struct MyProfileEarnSocialStats: Equatable {
    let participantCount: Int
    let interactionCount: Int
    let styleDescription: String

    static let mock = MyProfileEarnSocialStats(
        participantCount: 18,
        interactionCount: 64,
        styleDescription: "擅长冷启动破冰、压缩需求、把模糊机会整理成可成交对话。"
    )
}

struct MyProfileMessageStats: Equatable {
    let selfHumanInteractionCount: Int
    let selfAvatarOutboundCount: Int
    let outboundHumanInteractionCount: Int
    let avatarToAvatarInteractionCount: Int

    static let mock = MyProfileMessageStats(
        selfHumanInteractionCount: 11,
        selfAvatarOutboundCount: 27,
        outboundHumanInteractionCount: 9,
        avatarToAvatarInteractionCount: 14
    )
}

actor MyProfileXianrenStatsRepository {
    private let topicRepository: XianxiaTopicRepository

    init(topicRepository: XianxiaTopicRepository = XianxiaTopicRepository()) {
        self.topicRepository = topicRepository
    }

    func loadLiveStats() async throws -> MyProfileXianrenStats {
        let topics = try await fetchAllTopics()
        return Self.aggregate(from: topics)
    }

    func loadCachedStats() async -> MyProfileXianrenStats? {
        do {
            guard let snapshot = try await topicRepository.cachedTopics(), !snapshot.items.isEmpty else {
                return nil
            }
            return Self.aggregate(from: snapshot.items)
        } catch {
            return nil
        }
    }

    private func fetchAllTopics() async throws -> [XianxiaTopic] {
        var cursor: String?
        var mergedTopics: [XianxiaTopic] = []

        repeat {
            let batch = try await topicRepository.fetchTopics(cursor: cursor, batchSize: 200)
            mergedTopics = batch.items
            cursor = batch.nextCursor
        } while cursor != nil

        return mergedTopics
    }

    private static func aggregate(from topics: [XianxiaTopic]) -> MyProfileXianrenStats {
        let channels = Set(topics.compactMap(Self.channelName(for:)))
        let uniqueIDs = Set(topics.flatMap(Self.entityIDs(for:)))
        let mentionCount = topics.reduce(0) { $0 + Self.mentionCount(in: $1.summary) }
        let latestTopicAt = topics.compactMap(\.updatedAt).max()

        return MyProfileXianrenStats(
            channelCount: channels.count,
            topicCount: topics.count,
            uniqueIDCount: uniqueIDs.count,
            mentionCount: mentionCount,
            latestTopicAt: latestTopicAt
        )
    }

    private static func channelName(for topic: XianxiaTopic) -> String? {
        let segments = topic.topicPath.split(separator: "/").map(String.init)
        guard segments.count > 1 else { return nil }
        let channel = segments[1].trimmingCharacters(in: .whitespacesAndNewlines)
        return channel.isEmpty ? nil : channel
    }

    private static func entityIDs(for topic: XianxiaTopic) -> [String] {
        let corpus = [topic.topicId, topic.topicPath, topic.summary].joined(separator: "\n")
        return MyProfileXianrenTextParser.entityIDs(in: corpus)
    }

    private static func mentionCount(in summary: String) -> Int {
        MyProfileXianrenTextParser.mentionCount(in: summary)
    }
}

struct MyProfileMasterStatsProvider {
    private let localStateStore: MasterConversationLocalStateStore

    init(localStateStore: MasterConversationLocalStateStore = MasterConversationLocalStateStore()) {
        self.localStateStore = localStateStore
    }

    func load() -> MyProfileMasterStats {
        let state = (try? localStateStore.load()) ?? .empty
        let masterIDs = Set(state.recentSessions.map(\.masterID))
        let interactionCount = state.sessionTranscripts.values.reduce(into: 0) { count, messages in
            count += messages.filter { $0.role == .user }.count
        }
        let latestInteractionAt = state.recentSessions.compactMap {
            MyProfileOverviewDateParser.date(from: $0.lastMessageAt)
        }.max()

        return MyProfileMasterStats(
            masterCount: masterIDs.count,
            interactionCount: interactionCount,
            latestInteractionAt: latestInteractionAt
        )
    }
}

private enum MyProfileXianrenTextParser {
    static let entityIDRegex = try! NSRegularExpression(
        pattern: #"\b(?:oc|ou)_[0-9a-f]{32}\b"#,
        options: [.caseInsensitive]
    )
    static let mentionRegex = try! NSRegularExpression(
        pattern: #"(?<!\S)@[^\s|]+"#
    )

    static func entityIDs(in text: String) -> [String] {
        matches(of: entityIDRegex, in: text).map { $0.lowercased() }
    }

    static func mentionCount(in text: String) -> Int {
        matches(of: mentionRegex, in: text).count
    }

    private static func matches(of regex: NSRegularExpression, in text: String) -> [String] {
        let nsRange = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, options: [], range: nsRange).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }
    }
}

private enum MyProfileOverviewDateParser {
    static func date(from rawValue: String) -> Date? {
        fractionalFormatter().date(from: rawValue) ?? standardFormatter().date(from: rawValue)
    }

    private static func fractionalFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    private static func standardFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }
}
