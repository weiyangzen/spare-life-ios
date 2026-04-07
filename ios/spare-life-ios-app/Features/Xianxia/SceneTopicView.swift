// SceneTopicView.swift
// Spare Life – 咸虾 Stage 1 topic shards detail

import SwiftUI

struct SceneTopicView: View {
    let topic: XianxiaTopic
    let repository: XianxiaTopicRepository

    @StateObject private var vm: SceneTopicViewModel
    @Environment(\.dismiss) private var dismiss
    private let compactSpacing: CGFloat = 8

    init(topic: XianxiaTopic, repository: XianxiaTopicRepository = XianxiaTopicRepository()) {
        self.topic = topic
        self.repository = repository
        _vm = StateObject(wrappedValue: SceneTopicViewModel(topic: topic, repository: repository))
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider()
                content
            }
        }
        .spareNavigationBarHidden(true)
        .task {
            vm.loadIfNeeded()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color(.secondarySystemGroupedBackground), in: Circle())
            }
            .accessibilityLabel("返回")
            .accessibilityIdentifier("xianxia.topicDetail.back")

            VStack(alignment: .leading, spacing: 2) {
                Text("话题内容")
                    .font(.spareTitle2)
                    .foregroundColor(.primary)

                Text("仅保留正文内容")
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.md)
        .padding(.bottom, compactSpacing)
    }

    @ViewBuilder
    private var content: some View {
        switch vm.loadState {
        case .idle, .loading:
            ScrollView {
                TopicShardSkeleton()
                    .padding(.horizontal, compactSpacing)
                    .padding(.top, compactSpacing)
            }

        case .empty:
            ScrollView {
                EmptyStateView(
                    icon: "text.bubble",
                    title: "这个话题暂时没有内容",
                    message: "当前数据源没有返回可展示的原始文字。",
                    actionLabel: "重新拉取",
                    action: { vm.refresh() }
                )
                .padding(.top, Spacing.xxxl)
            }

        case .error(let message):
            ScrollView {
                ErrorStateView(
                    message: message,
                    cached: false,
                    retry: { vm.refresh() }
                )
                .padding(.top, Spacing.xxxl)
            }

        case .loadedFromCache, .loaded:
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: compactSpacing) {
                    ForEach(vm.shards) { shard in
                        TopicShardCardView(shard: shard)
                            .onAppear {
                                vm.loadMoreIfNeeded(after: shard)
                            }
                    }

                    if vm.isLoadingMore {
                        ProgressView("加载更多内容…")
                            .font(.spareCaption)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, Spacing.md)
                    }

                    Color.clear
                        .frame(height: 32)
                }
                .padding(.horizontal, compactSpacing)
                .padding(.top, compactSpacing)
            }
            .refreshable {
                await vm.refreshFromPullToRefresh()
            }
            .accessibilityIdentifier("xianxia.topicDetail.scrollView")
        }
    }
}

private struct TopicShardSkeleton: View {
    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(Color.white)
                    .frame(height: 96)
                    .shimmer()
            }
        }
    }
}

@MainActor
final class SceneTopicViewModel: ObservableObject {
    @Published private(set) var loadState: XianxiaTopicShardState = .idle
    @Published private(set) var shards: [XianxiaTopicShard] = []
    @Published private(set) var isLoadingMore = false

    let topic: XianxiaTopic
    private let repository: XianxiaTopicRepository
    private var nextCursor: String?
    private var hasStartedInitialLoad = false

    init(topic: XianxiaTopic, repository: XianxiaTopicRepository = XianxiaTopicRepository()) {
        self.topic = topic
        self.repository = repository
    }

    func loadIfNeeded() {
        guard !hasStartedInitialLoad else { return }
        hasStartedInitialLoad = true
        Task {
            await loadInitial()
        }
    }

    func refresh() {
        Task {
            await loadInitial(forceRefresh: true)
        }
    }

    func refreshFromPullToRefresh() async {
        await loadInitial(forceRefresh: true)
    }

    func loadInitial(forceRefresh: Bool = false) async {
        if !forceRefresh {
            await hydrateShardsFromCacheIfPresent()
        } else if shards.isEmpty {
            loadState = .loading
        }

        do {
            let batch = try await repository.fetchShards(topicId: topic.topicId, cursor: nil)
            shards = batch.items
            nextCursor = batch.nextCursor
            loadState = batch.items.isEmpty ? .empty : .loaded
        } catch {
            if !shards.isEmpty {
                loadState = .loadedFromCache
                return
            }

            await hydrateShardsFromCacheIfPresent()
            if shards.isEmpty {
                loadState = .error(error.xianxiaUserFacingMessage)
            } else {
                loadState = .loadedFromCache
            }
        }
    }

    func loadMoreIfNeeded(after shard: XianxiaTopicShard) {
        guard shouldPrefetch(after: shard) else { return }
        Task {
            await loadMore()
        }
    }

    func loadMore() async {
        guard let nextCursor, !nextCursor.isEmpty else { return }
        guard !isLoadingMore else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let batch = try await repository.fetchShards(topicId: topic.topicId, cursor: nextCursor)
            shards = Self.upsertAppend(existing: shards, incoming: batch.items)
            self.nextCursor = batch.nextCursor
            loadState = shards.isEmpty ? .empty : .loaded
        } catch {
            if shards.isEmpty {
                loadState = .error(error.xianxiaUserFacingMessage)
            } else {
                loadState = .loadedFromCache
            }
        }
    }

    private func shouldPrefetch(after shard: XianxiaTopicShard) -> Bool {
        guard let nextCursor, !nextCursor.isEmpty else { return false }
        let threshold = Set(shards.suffix(3).map(\.id))
        return threshold.contains(shard.id)
    }

    private func hydrateShardsFromCacheIfPresent() async {
        do {
            guard let snapshot = try await repository.cachedShards(topicId: topic.topicId), !snapshot.items.isEmpty else {
                if shards.isEmpty {
                    loadState = .loading
                }
                return
            }

            shards = snapshot.items
            nextCursor = snapshot.nextCursor
            loadState = .loadedFromCache
        } catch {
            if shards.isEmpty {
                loadState = .loading
            }
        }
    }

    private static func upsertAppend(
        existing: [XianxiaTopicShard],
        incoming: [XianxiaTopicShard]
    ) -> [XianxiaTopicShard] {
        var merged = existing
        var indexByID = Dictionary(uniqueKeysWithValues: merged.enumerated().map { ($1.id, $0) })

        for shard in incoming {
            if let index = indexByID[shard.id] {
                merged[index] = shard
            } else {
                indexByID[shard.id] = merged.count
                merged.append(shard)
            }
        }

        return merged
    }
}

// MARK: - Topic Support

struct XianxiaTopic: Identifiable, Codable, Equatable, Hashable {
    let topicId: String
    let topicPath: String
    let status: String
    let messageCount: Int
    let summary: String
    var senderTail: String? = nil
    var rawText: String? = nil
    let updatedAt: Date?
    let shardCount: Int

    var id: String { topicId }

    var title: String {
        let candidate = topicPath
            .split(separator: "/")
            .last
            .map(String.init)?
            .split(separator: ":")
            .last
            .map(String.init)?
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let candidate, !candidate.isEmpty {
            return candidate
        }

        let fallback = topicId
            .split(separator: ":")
            .last
            .map(String.init)?
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return (fallback?.isEmpty == false) ? fallback! : "未命名话题"
    }

    var summaryText: String {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "这个话题暂时还没有内容。" : trimmed
    }

    var senderTailDisplay: String {
        XianxiaSenderMask.tail6(senderTail, fallback: topicId)
    }

    var rawTextDisplay: String {
        XianxiaFeishuTextExtractor.displayText(primary: rawText, fallback: summaryText)
    }
}

struct XianxiaTopicShard: Identifiable, Codable, Equatable, Hashable {
    let topicId: String
    let canonicalTopicId: String
    let topicPath: String
    let status: String
    let messageCount: Int
    let summary: String
    var senderTail: String? = nil
    var rawText: String? = nil
    let updatedAt: Date?
    let shardOrdinal: Int
    let isCanonical: Bool

    var id: String { topicId }

    var summaryText: String {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "这个话题暂时还没有内容。" : trimmed
    }

    var senderTailDisplay: String {
        XianxiaSenderMask.tail6(senderTail, fallback: topicId)
    }

    var rawTextDisplay: String {
        XianxiaFeishuTextExtractor.displayText(primary: rawText, fallback: summaryText)
    }
}

enum XianxiaTopicFeedState: Equatable {
    case idle
    case loading
    case loaded
    case loadedFromCache
    case empty
    case error(String)
}

enum XianxiaTopicShardState: Equatable {
    case idle
    case loading
    case loaded
    case loadedFromCache
    case empty
    case error(String)
}

struct XianxiaTopicBatch: Codable, Equatable {
    let items: [XianxiaTopic]
    let nextCursor: String?
    let total: Int
    let batchSize: Int
    let tenantId: String
}

struct XianxiaTopicShardBatch: Codable, Equatable {
    let items: [XianxiaTopicShard]
    let nextCursor: String?
    let total: Int
    let batchSize: Int
    let tenantId: String
    let topicId: String
}

struct XianxiaTopicPageSnapshot: Codable, Equatable {
    let items: [XianxiaTopic]
    let nextCursor: String?
    let total: Int?
    let updatedAt: Date
}

struct XianxiaTopicShardSnapshot: Codable, Equatable {
    let topicId: String
    let items: [XianxiaTopicShard]
    let nextCursor: String?
    let updatedAt: Date
}

struct XianxiaTopicAPIConfiguration: Equatable, Sendable {
    let baseURL: URL
    let tenantId: String
    let feedBatchSize: Int
    let shardBatchSize: Int

    static func current(
        processInfo: ProcessInfo = .processInfo,
        userDefaults: UserDefaults = .standard
    ) -> XianxiaTopicAPIConfiguration {
        let rawBaseURL =
            processInfo.environment["XIANXIA_TOPICS_BASE_URL"] ??
            processInfo.environment["CLAWDB_TOPICS_BASE_URL"] ??
            userDefaults.string(forKey: "xianxia.topic.baseURL") ??
            userDefaults.string(forKey: "clawdbTopics.baseURL") ??
            "http://100.82.60.69:17880/v1/clawdb-topics"

        let tenantId =
            processInfo.environment["XIANXIA_TOPICS_TENANT_ID"] ??
            processInfo.environment["CLAWDB_TOPICS_TENANT_ID"] ??
            userDefaults.string(forKey: "xianxia.topic.tenantId") ??
            userDefaults.string(forKey: "clawdbTopics.tenantId") ??
            "default"

        let feedBatchSize =
            positiveInt(processInfo.environment["XIANXIA_TOPICS_FEED_BATCH_SIZE"]) ??
            positiveInt(processInfo.environment["CLAWDB_TOPICS_FEED_BATCH_SIZE"]) ??
            positiveInt(userDefaults.string(forKey: "xianxia.topic.feedBatchSize")) ??
            positiveInt(userDefaults.string(forKey: "clawdbTopics.feedBatchSize")) ??
            20

        let shardBatchSize =
            positiveInt(processInfo.environment["XIANXIA_TOPICS_SHARD_BATCH_SIZE"]) ??
            positiveInt(processInfo.environment["CLAWDB_TOPICS_SHARD_BATCH_SIZE"]) ??
            positiveInt(userDefaults.string(forKey: "xianxia.topic.shardBatchSize")) ??
            positiveInt(userDefaults.string(forKey: "clawdbTopics.shardBatchSize")) ??
            20

        return XianxiaTopicAPIConfiguration(
            baseURL: normalizeBaseURL(rawBaseURL) ?? URL(string: "http://100.82.60.69:17880/v1/clawdb-topics")!,
            tenantId: tenantId.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "default",
            feedBatchSize: feedBatchSize,
            shardBatchSize: shardBatchSize
        )
    }

    var topicsURL: URL {
        baseURL.appendingPathComponent("topics", isDirectory: false)
    }

    func shardsURL(topicId: String) -> URL {
        baseURL
            .appendingPathComponent("topics", isDirectory: true)
            .appendingPathComponent(topicId, isDirectory: true)
            .appendingPathComponent("shards", isDirectory: false)
    }

    private static func normalizeBaseURL(_ rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var url = URL(string: trimmed) else {
            return nil
        }

        let normalizedPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if normalizedPath.isEmpty {
            url.appendPathComponent("v1", isDirectory: true)
            url.appendPathComponent("clawdb-topics", isDirectory: false)
            return url
        }

        if normalizedPath.hasSuffix("v1/clawdb-topics") {
            return url
        }

        url.appendPathComponent("v1", isDirectory: true)
        url.appendPathComponent("clawdb-topics", isDirectory: false)
        return url
    }

    private static func positiveInt(_ rawValue: String?) -> Int? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value > 0 else {
            return nil
        }
        return value
    }
}

enum XianxiaTopicRepositoryError: LocalizedError {
    case invalidResponse
    case invalidHTTPStatus(Int)
    case gateway(String)
    case missingPayload
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "话题数据源返回了无法识别的响应。"
        case .invalidHTTPStatus(let statusCode):
            return "话题数据源请求失败，状态码 \(statusCode)。"
        case .gateway(let message):
            return message
        case .missingPayload:
            return "话题数据源没有返回可用数据。"
        case .transport(let message):
            return message
        }
    }
}

typealias XianxiaTopicTransport = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

actor XianxiaTopicRepository {
    nonisolated let configuration: XianxiaTopicAPIConfiguration

    private let fileManager: FileManager
    private let cacheRoot: URL
    private let transport: XianxiaTopicTransport

    init(
        configuration: XianxiaTopicAPIConfiguration = .current(),
        fileManager: FileManager = .default,
        cacheRoot: URL? = nil,
        transport: XianxiaTopicTransport? = nil
    ) {
        self.configuration = configuration
        self.fileManager = fileManager
        self.cacheRoot = cacheRoot ?? Self.defaultCacheRoot(fileManager: fileManager)
        self.transport = transport ?? { request in
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw XianxiaTopicRepositoryError.invalidResponse
                }
                return (data, httpResponse)
            } catch let error as XianxiaTopicRepositoryError {
                throw error
            } catch {
                throw XianxiaTopicRepositoryError.transport(error.localizedDescription)
            }
        }
    }

    func cachedTopics() throws -> XianxiaTopicPageSnapshot? {
        try ensureCacheDirectory()
        return try read(XianxiaTopicPageSnapshot.self, from: topicsCacheURL())
    }

    func cachedShards(topicId: String) throws -> XianxiaTopicShardSnapshot? {
        try ensureCacheDirectory()
        return try read(XianxiaTopicShardSnapshot.self, from: shardsCacheURL(topicId: topicId))
    }

    @discardableResult
    func fetchTopics(cursor: String? = nil, batchSize: Int? = nil) async throws -> XianxiaTopicBatch {
        var components = URLComponents(url: configuration.topicsURL, resolvingAgainstBaseURL: false)
        var queryItems = [
            URLQueryItem(name: "batchSize", value: String(batchSize ?? configuration.feedBatchSize)),
            URLQueryItem(name: "tenantId", value: configuration.tenantId)
        ]
        if let cursor, !cursor.isEmpty {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw XianxiaTopicRepositoryError.invalidResponse
        }

        let batch: XianxiaTopicBatch = try await request(url: url)
        let existing = try cachedTopics()?.items ?? []
        let merged = mergeTopics(existing: existing, incoming: batch.items, resetting: cursor == nil)
        let snapshot = XianxiaTopicPageSnapshot(
            items: merged,
            nextCursor: batch.nextCursor,
            total: batch.total,
            updatedAt: Date()
        )
        try write(snapshot, to: topicsCacheURL())
        return XianxiaTopicBatch(
            items: merged,
            nextCursor: batch.nextCursor,
            total: batch.total,
            batchSize: batch.batchSize,
            tenantId: batch.tenantId
        )
    }

    @discardableResult
    func fetchShards(
        topicId: String,
        cursor: String? = nil,
        batchSize: Int? = nil
    ) async throws -> XianxiaTopicShardBatch {
        var components = URLComponents(url: configuration.shardsURL(topicId: topicId), resolvingAgainstBaseURL: false)
        var queryItems = [
            URLQueryItem(name: "batchSize", value: String(batchSize ?? configuration.shardBatchSize)),
            URLQueryItem(name: "tenantId", value: configuration.tenantId)
        ]
        if let cursor, !cursor.isEmpty {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw XianxiaTopicRepositoryError.invalidResponse
        }

        let batch: XianxiaTopicShardBatch = try await request(url: url)
        let existing = try cachedShards(topicId: topicId)?.items ?? []
        let merged = mergeShards(existing: existing, incoming: batch.items, resetting: cursor == nil)
        let snapshot = XianxiaTopicShardSnapshot(
            topicId: topicId,
            items: merged,
            nextCursor: batch.nextCursor,
            updatedAt: Date()
        )
        try write(snapshot, to: shardsCacheURL(topicId: topicId))
        return XianxiaTopicShardBatch(
            items: merged,
            nextCursor: batch.nextCursor,
            total: batch.total,
            batchSize: batch.batchSize,
            tenantId: batch.tenantId,
            topicId: batch.topicId
        )
    }

    private func request<Payload: Decodable>(url: URL) async throws -> Payload {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15

        let (data, response) = try await transport(request)
        guard (200..<300).contains(response.statusCode) else {
            if let envelope = try? XianxiaTopicCoding.decoder.decode(ClawdbGatewayEnvelope<ClawdbEmptyPayload>.self, from: data),
               let message = envelope.error,
               !message.isEmpty {
                throw XianxiaTopicRepositoryError.gateway(message)
            }
            throw XianxiaTopicRepositoryError.invalidHTTPStatus(response.statusCode)
        }

        let envelope = try XianxiaTopicCoding.decoder.decode(ClawdbGatewayEnvelope<Payload>.self, from: data)
        guard envelope.ok else {
            throw XianxiaTopicRepositoryError.gateway(envelope.error?.nonEmpty ?? "话题数据源返回失败。")
        }
        guard let payload = envelope.data else {
            throw XianxiaTopicRepositoryError.missingPayload
        }
        return payload
    }

    private func ensureCacheDirectory() throws {
        try fileManager.createDirectory(at: cacheRoot, withIntermediateDirectories: true, attributes: nil)
    }

    private func topicsCacheURL() -> URL {
        cacheRoot.appendingPathComponent(cacheFileName(prefix: "topics"), isDirectory: false)
    }

    private func shardsCacheURL(topicId: String) -> URL {
        cacheRoot.appendingPathComponent(cacheFileName(prefix: "shards-\(topicId)"), isDirectory: false)
    }

    private func cacheFileName(prefix: String) -> String {
        let scope = "\(configuration.baseURL.absoluteString)|\(configuration.tenantId)|\(prefix)"
        return "xianxia-\(StableCacheDigest.hex(scope)).json"
    }

    private func read<Payload: Decodable>(_ type: Payload.Type, from url: URL) throws -> Payload? {
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        let data = try Data(contentsOf: url)
        return try XianxiaTopicCoding.decoder.decode(Payload.self, from: data)
    }

    private func write<Payload: Encodable>(_ payload: Payload, to url: URL) throws {
        try ensureCacheDirectory()
        let data = try XianxiaTopicCoding.encoder.encode(payload)
        try data.write(to: url, options: .atomic)
    }

    private func mergeTopics(
        existing: [XianxiaTopic],
        incoming: [XianxiaTopic],
        resetting: Bool
    ) -> [XianxiaTopic] {
        if resetting {
            return incoming
        }

        var merged = existing
        var indexByID = Dictionary(uniqueKeysWithValues: merged.enumerated().map { ($1.id, $0) })
        for item in incoming {
            if let existingIndex = indexByID[item.id] {
                merged[existingIndex] = item
            } else {
                indexByID[item.id] = merged.count
                merged.append(item)
            }
        }
        return merged
    }

    private func mergeShards(
        existing: [XianxiaTopicShard],
        incoming: [XianxiaTopicShard],
        resetting: Bool
    ) -> [XianxiaTopicShard] {
        if resetting {
            return incoming
        }

        var merged = existing
        var indexByID = Dictionary(uniqueKeysWithValues: merged.enumerated().map { ($1.id, $0) })
        for item in incoming {
            if let existingIndex = indexByID[item.id] {
                merged[existingIndex] = item
            } else {
                indexByID[item.id] = merged.count
                merged.append(item)
            }
        }
        return merged
    }

    private static func defaultCacheRoot(fileManager: FileManager) -> URL {
        let baseURL =
            (try? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)) ??
            fileManager.temporaryDirectory
        return baseURL.appendingPathComponent("SpareLife/XianxiaTopics", isDirectory: true)
    }
}

enum XianxiaRelativeTime {
    static func string(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

extension Error {
    var xianxiaUserFacingMessage: String {
        if let error = self as? XianxiaTopicRepositoryError {
            return error.errorDescription ?? "话题数据暂时不可用。"
        }

        let message = localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? "话题数据暂时不可用。" : message
    }
}

private struct ClawdbGatewayEnvelope<Payload: Decodable>: Decodable {
    let ok: Bool
    let data: Payload?
    let error: String?
}

private struct ClawdbEmptyPayload: Decodable {}

private enum XianxiaTopicCoding {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(XianxiaISO8601.string(from: date))
        }
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = XianxiaISO8601.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date: \(string)")
        }
        return decoder
    }()
}

private enum XianxiaISO8601 {
    static func date(from rawValue: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: rawValue) {
            return date
        }

        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return standard.date(from: rawValue)
    }

    static func string(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}

private enum StableCacheDigest {
    static func hex(_ value: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return String(format: "%016llx", hash)
    }
}

private enum XianxiaSenderMask {
    static func tail6(_ candidate: String?, fallback: String) -> String {
        let primary = (candidate?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? candidate!
            : fallback)
        let cleaned = primary
            .replacingOccurrences(of: "[^0-9A-Za-z\\u4e00-\\u9fff]+", with: "", options: .regularExpression)
        let source = cleaned.isEmpty ? primary : cleaned
        return String(source.suffix(6))
    }
}

private enum XianxiaFeishuTextExtractor {
    private static let textPattern = #"text\s*\|\s*([^|]+?)\s*\|"#

    static func displayText(primary: String?, fallback: String) -> String {
        let primaryExtracted = extract(from: primary)
        if !primaryExtracted.isEmpty {
            return primaryExtracted
        }

        let fallbackExtracted = extract(from: fallback)
        if !fallbackExtracted.isEmpty {
            return fallbackExtracted
        }

        let trimmedFallback = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedFallback.isEmpty ? "这个话题暂时还没有内容。" : trimmedFallback
    }

    private static func extract(from rawValue: String?) -> String {
        guard let rawValue else { return "" }
        let normalized = rawValue.replacingOccurrences(of: "\r\n", with: "\n")
        let payload: String
        if let splitRange = normalized.range(of: "split=-") {
            payload = String(normalized[splitRange.upperBound...])
        } else {
            payload = normalized
        }

        let lines = payload
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        var extracted: [String] = []

        for line in lines {
            guard !line.isEmpty else { continue }

            let textSegments = textSegments(in: line)
            if !textSegments.isEmpty {
                extracted.append(contentsOf: textSegments)
                continue
            }

            let plainLine = normalizedPlainLine(from: line)
            if isMeaningfulContent(plainLine) {
                extracted.append(plainLine)
            }
        }

        let cleaned = extracted
            .map { cleanContentFragment($0) }
            .filter { isMeaningfulContent($0) }

        guard !cleaned.isEmpty else { return "" }
        return cleaned.joined(separator: "\n")
    }

    private static func textSegments(in line: String) -> [String] {
        let nsLine = line as NSString
        let regex = try? NSRegularExpression(pattern: textPattern, options: [.caseInsensitive])
        let matches = regex?.matches(in: line, options: [], range: NSRange(location: 0, length: nsLine.length)) ?? []

        return matches.compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            let captured = nsLine.substring(with: match.range(at: 1))
            let cleaned = cleanContentFragment(captured)
            return isMeaningfulContent(cleaned) ? cleaned : nil
        }
    }

    private static func normalizedPlainLine(from line: String) -> String {
        line
            .replacingOccurrences(of: #"^\-\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanContentFragment(_ fragment: String) -> String {
        fragment
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isMeaningfulContent(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        guard !value.contains(":") && !value.contains("=") else { return false }
        guard !value.contains("{") && !value.contains("}") else { return false }
        guard !value.contains("\"") else { return false }
        let lowered = value.lowercased()
        let metadataHints = [
            "topic",
            "status",
            "canonical",
            "parent",
            "messages",
            "drift",
            "keywords",
            "merged",
            "split",
            "detail",
            "code"
        ]
        guard !metadataHints.contains(where: { lowered.contains($0) }) else { return false }
        guard !value.contains("|") else { return false }
        return true
    }

    private static func textContent(in line: String) -> String? {
        let segments = textSegments(in: line)
        if let first = segments.first {
            return first
        }
        return nil
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
