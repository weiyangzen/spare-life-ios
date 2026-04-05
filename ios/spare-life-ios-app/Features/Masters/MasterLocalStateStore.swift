import Foundation

struct MasterConversationLocalState {
    struct ResumeSession: Hashable {
        let id: String
        let masterID: String
        let displayName: String
        let title: String
        let topic: String
        let preview: String
        let unreadCount: Int
        let lastMessageAt: String
        let isPinned: Bool

        func materialize(seedMessages: [MasterMessage]) -> MasterRecentSession {
            MasterRecentSession(
                id: id,
                masterID: masterID,
                displayName: displayName,
                title: title,
                topic: topic,
                preview: preview,
                unreadCount: unreadCount,
                lastMessageAt: lastMessageAt,
                isPinned: isPinned,
                seedMessages: seedMessages
            )
        }
    }

    let recentSessions: [ResumeSession]
    let sessionTranscripts: [String: [MasterMessage]]
    let memoryNotesByMasterID: [String: [MasterMemoryNote]]

    static let empty = MasterConversationLocalState(
        recentSessions: [],
        sessionTranscripts: [:],
        memoryNotesByMasterID: [:]
    )
}

struct MasterConversationLocalStateStore {
    private let fileManager: FileManager
    private let archiveURL: URL

    init(
        fileManager: FileManager = .default,
        archiveURL: URL? = nil
    ) {
        self.fileManager = fileManager
        self.archiveURL = archiveURL ?? Self.defaultArchiveURL(fileManager: fileManager)
    }

    func load() throws -> MasterConversationLocalState {
        guard fileManager.fileExists(atPath: archiveURL.path) else {
            return .empty
        }

        let data = try Data(contentsOf: archiveURL)
        let archive = try MasterConversationLocalStateCoding.decoder.decode(Archive.self, from: data)
        return archive.materialize()
    }

    func save(
        recentSessions: [MasterRecentSession],
        sessionTranscripts: [String: [MasterMessage]],
        masters: [MasterProfile]
    ) throws {
        let archive = Archive(
            recentSessions: recentSessions.map(SessionRecord.init),
            transcripts: sessionTranscripts
                .sorted { $0.key < $1.key }
                .map { TranscriptRecord(sessionID: $0.key, messages: $0.value.map(MessageRecord.init)) },
            memoryBuckets: masters
                .map { profile in
                    MemoryBucket(masterID: profile.id, notes: profile.memoryNotes.map(MemoryRecord.init))
                }
                .filter { !$0.notes.isEmpty }
                .sorted { $0.masterID < $1.masterID }
        )

        try fileManager.createDirectory(
            at: archiveURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try MasterConversationLocalStateCoding.encoder.encode(archive)
        try data.write(to: archiveURL, options: .atomic)
    }

    var resultFileURL: URL {
        archiveURL.deletingLastPathComponent().appendingPathComponent("masters-preview-validation.json", isDirectory: false)
    }

    private static func defaultArchiveURL(fileManager: FileManager) -> URL {
        let baseURL =
            (try? fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )) ??
            fileManager.temporaryDirectory

        return baseURL
            .appendingPathComponent("SpareLife/Masters", isDirectory: true)
            .appendingPathComponent("master-conversations.json", isDirectory: false)
    }
}

private struct Archive: Codable {
    let recentSessions: [SessionRecord]
    let transcripts: [TranscriptRecord]
    let memoryBuckets: [MemoryBucket]

    func materialize() -> MasterConversationLocalState {
        MasterConversationLocalState(
            recentSessions: recentSessions.map(\.resumeSession),
            sessionTranscripts: Dictionary(uniqueKeysWithValues: transcripts.map { ($0.sessionID, $0.messages.compactMap(\.message)) }),
            memoryNotesByMasterID: Dictionary(uniqueKeysWithValues: memoryBuckets.map { ($0.masterID, $0.notes.compactMap(\.memoryNote)) })
        )
    }
}

private struct SessionRecord: Codable {
    let id: String
    let masterID: String
    let displayName: String
    let title: String
    let topic: String
    let preview: String
    let unreadCount: Int
    let lastMessageAt: String
    let isPinned: Bool

    init(_ session: MasterRecentSession) {
        id = session.id
        masterID = session.masterID
        displayName = session.displayName
        title = session.title
        topic = session.topic
        preview = session.preview
        unreadCount = session.unreadCount
        lastMessageAt = session.lastMessageAt
        isPinned = session.isPinned
    }

    var resumeSession: MasterConversationLocalState.ResumeSession {
        MasterConversationLocalState.ResumeSession(
            id: id,
            masterID: masterID,
            displayName: displayName,
            title: title,
            topic: topic,
            preview: preview,
            unreadCount: unreadCount,
            lastMessageAt: lastMessageAt,
            isPinned: isPinned
        )
    }
}

private struct TranscriptRecord: Codable {
    let sessionID: String
    let messages: [MessageRecord]
}

private struct MessageRecord: Codable {
    let id: String
    let role: String
    let text: String
    let timestamp: String
    let referencedStoryTitles: [String]
    let referencedMemoryLabels: [String]
    let ctas: [ActionRecord]

    init(_ message: MasterMessage) {
        id = message.id
        role = message.role.rawValue
        text = message.text
        timestamp = message.timestamp
        referencedStoryTitles = message.referencedStoryTitles
        referencedMemoryLabels = message.referencedMemoryLabels
        ctas = message.ctas.map(ActionRecord.init)
    }

    var message: MasterMessage? {
        guard let role = MasterMessageRole(rawValue: role) else { return nil }
        return MasterMessage(
            id: id,
            role: role,
            text: text,
            timestamp: timestamp,
            referencedStoryTitles: referencedStoryTitles,
            referencedMemoryLabels: referencedMemoryLabels,
            ctas: ctas.compactMap(\.action)
        )
    }
}

private struct ActionRecord: Codable {
    let id: String
    let label: String
    let reason: String
    let route: String
    let target: String

    init(_ action: MasterActionRecommendation) {
        id = action.id
        label = action.label
        reason = action.reason
        route = action.route
        target = action.target.rawValue
    }

    var action: MasterActionRecommendation? {
        guard let target = MasterActionTarget(rawValue: target) else { return nil }
        return MasterActionRecommendation(
            id: id,
            label: label,
            reason: reason,
            route: route,
            target: target
        )
    }
}

private struct MemoryBucket: Codable {
    let masterID: String
    let notes: [MemoryRecord]
}

private struct MemoryRecord: Codable {
    let id: String
    let label: String
    let summary: String
    let scope: String
    let updatedAt: String
    let isSensitive: Bool

    init(_ note: MasterMemoryNote) {
        id = note.id
        label = note.label
        summary = note.summary
        scope = note.scope.rawValue
        updatedAt = note.updatedAt
        isSensitive = note.isSensitive
    }

    var memoryNote: MasterMemoryNote? {
        guard let scope = MasterMemoryScope(rawValue: scope) else { return nil }
        return MasterMemoryNote(
            id: id,
            label: label,
            summary: summary,
            scope: scope,
            updatedAt: updatedAt,
            isSensitive: isSensitive
        )
    }
}

private enum MasterConversationLocalStateCoding {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    static let decoder = JSONDecoder()
}
