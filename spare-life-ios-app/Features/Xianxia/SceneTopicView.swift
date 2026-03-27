// SceneTopicView.swift
// Spare Life – 咸虾 Stage 1 topic shards detail

import SwiftUI

struct SceneTopicView: View {
    let topic: XianxiaTopic
    let repository: XianxiaTopicRepository

    @StateObject private var vm: SceneTopicViewModel
    @Environment(\.dismiss) private var dismiss

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
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top, spacing: Spacing.md) {
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

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(topic.title)
                        .font(.spareTitle2)
                        .foregroundColor(.primary)

                    Text(topic.topicPath)
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(topic.summaryText)
                    .font(.spareBody)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: Spacing.sm) {
                    PillTag(label: "\(topic.messageCount) 条消息", color: .secondary)
                    PillTag(label: topic.shardCount > 0 ? "\(topic.shardCount) 个 shards" : "单页话题", color: .secondary)
                    if let updatedAt = topic.updatedAt {
                        PillTag(label: XianxiaRelativeTime.string(for: updatedAt), color: .secondary)
                    }
                }
            }
            .padding(Spacing.md)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.md)
    }

    @ViewBuilder
    private var content: some View {
        switch vm.loadState {
        case .idle, .loading:
            ScrollView {
                TopicShardSkeleton()
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.lg)
            }

        case .empty:
            ScrollView {
                EmptyStateView(
                    icon: "text.bubble",
                    title: "这个 topic 还没有 shards",
                    message: "当前数据源没有返回 shard 内容，稍后下拉刷新再试。",
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
                LazyVStack(alignment: .leading, spacing: Spacing.md) {
                    if vm.loadState == .loadedFromCache {
                        TopicShardCacheBanner(
                            text: "已显示本地 shard 缓存，网络恢复后会自动刷新。"
                        )
                    }

                    ForEach(vm.shards) { shard in
                        TopicShardCardView(shard: shard)
                            .onAppear {
                                vm.loadMoreIfNeeded(after: shard)
                            }
                    }

                    if vm.isLoadingMore {
                        ProgressView("加载更多 shards…")
                            .font(.spareCaption)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, Spacing.lg)
                    }

                    Color.clear
                        .frame(height: 48)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.lg)
            }
            .refreshable {
                await vm.refreshFromPullToRefresh()
            }
        }
    }
}

private struct TopicShardCacheBanner: View {
    let text: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "externaldrive.badge.checkmark")
                .foregroundColor(.emotionNeutral)
            Text(text)
                .font(.spareCaption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(Spacing.md)
        .background(Color(.systemYellow).opacity(0.10), in: RoundedRectangle(cornerRadius: CornerRadius.sm))
    }
}

private struct TopicShardSkeleton: View {
    var body: some View {
        VStack(spacing: Spacing.md) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .frame(height: 164)
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
            shards = batch.items
            self.nextCursor = batch.nextCursor
            loadState = batch.items.isEmpty ? .empty : .loaded
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
}

// MARK: - Topic Support

struct XianxiaTopic: Identifiable, Codable, Equatable, Hashable {
    let topicId: String
    let topicPath: String
    let status: String
    let messageCount: Int
    let summary: String
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
        return trimmed.isEmpty ? "这个话题暂时还没有摘要。" : trimmed
    }
}

struct XianxiaTopicShard: Identifiable, Codable, Equatable, Hashable {
    let topicId: String
    let canonicalTopicId: String
    let topicPath: String
    let status: String
    let messageCount: Int
    let summary: String
    let updatedAt: Date?
    let shardOrdinal: Int
    let isCanonical: Bool

    var id: String { topicId }

    var summaryText: String {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "这个 shard 暂时还没有摘要。" : trimmed
    }

    var ordinalLabel: String {
        if isCanonical {
            return "主话题"
        }
        return "Shard #\(shardOrdinal)"
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

        return XianxiaTopicAPIConfiguration(
            baseURL: normalizeBaseURL(rawBaseURL) ?? URL(string: "http://100.82.60.69:17880/v1/clawdb-topics")!,
            tenantId: tenantId.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "default",
            feedBatchSize: 20,
            shardBatchSize: 20
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

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
