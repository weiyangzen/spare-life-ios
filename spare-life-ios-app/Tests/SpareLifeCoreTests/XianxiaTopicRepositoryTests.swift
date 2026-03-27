import XCTest
@testable import SpareLifeCore

final class XianxiaTopicRepositoryTests: XCTestCase {
    @MainActor
    func testHomeViewModelLoadsPaginatedTopicsAndPersistsMergedCache() async throws {
        let cacheRoot = makeTemporaryCacheRoot()
        defer { try? FileManager.default.removeItem(at: cacheRoot) }

        let transport = MockClawdbTransport()
        await transport.setTopicBatch(
            cursor: nil,
            batch: XianxiaTopicBatch(
                items: [
                    makeTopic(id: "group:alpha::topic-001", path: "group/alpha/topic-001", summary: "首批话题摘要 A", shardCount: 2),
                    makeTopic(id: "group:alpha::topic-002", path: "group/alpha/topic-002", summary: "首批话题摘要 B", shardCount: 1)
                ],
                nextCursor: "2",
                total: 3,
                batchSize: 2,
                tenantId: "default"
            )
        )
        await transport.setTopicBatch(
            cursor: "2",
            batch: XianxiaTopicBatch(
                items: [
                    makeTopic(id: "group:alpha::topic-003", path: "group/alpha/topic-003", summary: "第二页话题摘要 C", shardCount: 0)
                ],
                nextCursor: nil,
                total: 3,
                batchSize: 2,
                tenantId: "default"
            )
        )

        let repository = makeRepository(cacheRoot: cacheRoot, transport: transport)
        let vm = XianxiaHomeViewModel(repository: repository)

        await vm.loadInitial()
        XCTAssertEqual(vm.feedState, .loaded)
        XCTAssertEqual(vm.topics.map(\.topicId), [
            "group:alpha::topic-001",
            "group:alpha::topic-002"
        ])

        await vm.loadMore()
        XCTAssertEqual(vm.topics.map(\.topicId), [
            "group:alpha::topic-001",
            "group:alpha::topic-002",
            "group:alpha::topic-003"
        ])

        let snapshot = try await repository.cachedTopics()
        XCTAssertEqual(snapshot?.items.map(\.topicId), [
            "group:alpha::topic-001",
            "group:alpha::topic-002",
            "group:alpha::topic-003"
        ])
        XCTAssertNil(snapshot?.nextCursor)
    }

    @MainActor
    func testHomeViewModelFallsBackToCachedTopicsAfterRefreshFailure() async throws {
        let cacheRoot = makeTemporaryCacheRoot()
        defer { try? FileManager.default.removeItem(at: cacheRoot) }

        let transport = MockClawdbTransport()
        await transport.setTopicBatch(
            cursor: nil,
            batch: XianxiaTopicBatch(
                items: [
                    makeTopic(id: "group:beta::topic-001", path: "group/beta/topic-001", summary: "缓存话题摘要 1", shardCount: 3),
                    makeTopic(id: "group:beta::topic-002", path: "group/beta/topic-002", summary: "缓存话题摘要 2", shardCount: 2)
                ],
                nextCursor: nil,
                total: 2,
                batchSize: 20,
                tenantId: "default"
            )
        )

        let repository = makeRepository(cacheRoot: cacheRoot, transport: transport)
        let vm = XianxiaHomeViewModel(repository: repository)

        await vm.loadInitial()
        XCTAssertEqual(vm.feedState, .loaded)
        XCTAssertEqual(vm.topics.count, 2)

        await transport.setFailTopics(true)
        await vm.loadInitial(forceRefresh: true)

        XCTAssertEqual(vm.feedState, .loadedFromCache)
        XCTAssertEqual(vm.topics.count, 2)
        XCTAssertEqual(vm.topics.first?.summaryText, "缓存话题摘要 1")
    }

    @MainActor
    func testHomeViewModelReusesPersistedTopicsAcrossFreshRepositoryInstance() async throws {
        let cacheRoot = makeTemporaryCacheRoot()
        defer { try? FileManager.default.removeItem(at: cacheRoot) }

        let warmTransport = MockClawdbTransport()
        await warmTransport.setTopicBatch(
            cursor: nil,
            batch: XianxiaTopicBatch(
                items: [
                    makeTopic(id: "group:delta::topic-001", path: "group/delta/topic-001", summary: "持久化话题摘要 1", shardCount: 1),
                    makeTopic(id: "group:delta::topic-002", path: "group/delta/topic-002", summary: "持久化话题摘要 2", shardCount: 4)
                ],
                nextCursor: nil,
                total: 2,
                batchSize: 20,
                tenantId: "default"
            )
        )

        let warmRepository = makeRepository(cacheRoot: cacheRoot, transport: warmTransport)
        let warmViewModel = XianxiaHomeViewModel(repository: warmRepository)

        await warmViewModel.loadInitial()
        XCTAssertEqual(warmViewModel.feedState, .loaded)
        XCTAssertEqual(warmViewModel.topics.map(\.topicId), [
            "group:delta::topic-001",
            "group:delta::topic-002"
        ])

        let coldTransport = MockClawdbTransport()
        await coldTransport.setFailTopics(true)

        let coldRepository = makeRepository(cacheRoot: cacheRoot, transport: coldTransport)
        let coldViewModel = XianxiaHomeViewModel(repository: coldRepository)

        await coldViewModel.loadInitial()
        XCTAssertEqual(coldViewModel.feedState, .loadedFromCache)
        XCTAssertEqual(coldViewModel.topics.map(\.topicId), [
            "group:delta::topic-001",
            "group:delta::topic-002"
        ])
        XCTAssertEqual(coldViewModel.topics.last?.summaryText, "持久化话题摘要 2")
    }

    @MainActor
    func testSceneTopicViewModelFallsBackToCachedShardsAfterFailure() async throws {
        let cacheRoot = makeTemporaryCacheRoot()
        defer { try? FileManager.default.removeItem(at: cacheRoot) }

        let topic = makeTopic(
            id: "group:gamma::topic-001",
            path: "group/gamma/topic-001",
            summary: "Shard 测试话题",
            shardCount: 2
        )

        let transport = MockClawdbTransport()
        await transport.setShardBatch(
            topicId: topic.topicId,
            cursor: nil,
            batch: XianxiaTopicShardBatch(
                items: [
                    makeShard(topicId: "group:gamma::topic-001::shard:2", canonicalId: topic.topicId, summary: "最新 shard", shardOrdinal: 2),
                    makeShard(topicId: "group:gamma::topic-001::shard:1", canonicalId: topic.topicId, summary: "较早 shard", shardOrdinal: 1)
                ],
                nextCursor: nil,
                total: 2,
                batchSize: 20,
                tenantId: "default",
                topicId: topic.topicId
            )
        )

        let repository = makeRepository(cacheRoot: cacheRoot, transport: transport)
        let vm = SceneTopicViewModel(topic: topic, repository: repository)

        await vm.loadInitial()
        XCTAssertEqual(vm.loadState, .loaded)
        XCTAssertEqual(vm.shards.count, 2)

        await transport.setFailShards(true)
        await vm.loadInitial(forceRefresh: true)

        XCTAssertEqual(vm.loadState, .loadedFromCache)
        XCTAssertEqual(vm.shards.map(\.summaryText), ["最新 shard", "较早 shard"])

        let snapshot = try await repository.cachedShards(topicId: topic.topicId)
        XCTAssertEqual(snapshot?.items.count, 2)
    }

    private func makeRepository(
        cacheRoot: URL,
        transport: MockClawdbTransport
    ) -> XianxiaTopicRepository {
        XianxiaTopicRepository(
            configuration: XianxiaTopicAPIConfiguration(
                baseURL: URL(string: "https://example.com/v1/clawdb-topics")!,
                tenantId: "default",
                feedBatchSize: 20,
                shardBatchSize: 20
            ),
            cacheRoot: cacheRoot,
            transport: { request in
                try await transport.handle(request)
            }
        )
    }

    private func makeTemporaryCacheRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("xianxia-topic-tests-\(UUID().uuidString)", isDirectory: true)
    }

    private func makeTopic(
        id: String,
        path: String,
        summary: String,
        shardCount: Int
    ) -> XianxiaTopic {
        XianxiaTopic(
            topicId: id,
            topicPath: path,
            status: "active",
            messageCount: 18,
            summary: summary,
            updatedAt: Date(timeIntervalSince1970: 1_770_000_000),
            shardCount: shardCount
        )
    }

    private func makeShard(
        topicId: String,
        canonicalId: String,
        summary: String,
        shardOrdinal: Int
    ) -> XianxiaTopicShard {
        XianxiaTopicShard(
            topicId: topicId,
            canonicalTopicId: canonicalId,
            topicPath: canonicalId,
            status: "active",
            messageCount: 8,
            summary: summary,
            updatedAt: Date(timeIntervalSince1970: 1_770_000_100 + TimeInterval(shardOrdinal)),
            shardOrdinal: shardOrdinal,
            isCanonical: false
        )
    }
}

private actor MockClawdbTransport {
    private var topicBatches: [String: XianxiaTopicBatch] = [:]
    private var shardBatches: [String: XianxiaTopicShardBatch] = [:]
    private var failTopics = false
    private var failShards = false

    func setTopicBatch(cursor: String?, batch: XianxiaTopicBatch) {
        topicBatches[topicCursorKey(cursor)] = batch
    }

    func setShardBatch(topicId: String, cursor: String?, batch: XianxiaTopicShardBatch) {
        shardBatches[shardCursorKey(topicId: topicId, cursor: cursor)] = batch
    }

    func setFailTopics(_ shouldFail: Bool) {
        failTopics = shouldFail
    }

    func setFailShards(_ shouldFail: Bool) {
        failShards = shouldFail
    }

    func handle(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard let url = request.url else {
            throw XianxiaTopicRepositoryError.invalidResponse
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let cursor = components?.queryItems?.first(where: { $0.name == "cursor" })?.value

        if url.path.hasSuffix("/shards") {
            if failShards {
                throw XianxiaTopicRepositoryError.transport("Simulated shard outage")
            }

            let encodedTopicId = url.deletingLastPathComponent().lastPathComponent
            let topicId = encodedTopicId.removingPercentEncoding ?? encodedTopicId
            let key = shardCursorKey(topicId: topicId, cursor: cursor)
            guard let batch = shardBatches[key] else {
                throw XianxiaTopicRepositoryError.transport("Missing shard mock for \(key)")
            }
            return (try encodeEnvelope(batch), response)
        }

        if url.path.hasSuffix("/topics") {
            if failTopics {
                throw XianxiaTopicRepositoryError.transport("Simulated topic outage")
            }

            let key = topicCursorKey(cursor)
            guard let batch = topicBatches[key] else {
                throw XianxiaTopicRepositoryError.transport("Missing topic mock for \(key)")
            }
            return (try encodeEnvelope(batch), response)
        }

        throw XianxiaTopicRepositoryError.transport("Unhandled mock route: \(url.absoluteString)")
    }

    private func encodeEnvelope<Payload: Encodable>(_ payload: Payload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(GatewayEnvelope(ok: true, data: payload, error: nil))
    }

    private func topicCursorKey(_ cursor: String?) -> String {
        cursor ?? "__first__"
    }

    private func shardCursorKey(topicId: String, cursor: String?) -> String {
        "\(topicId)|\(cursor ?? "__first__")"
    }
}

private struct GatewayEnvelope<Payload: Encodable>: Encodable {
    let ok: Bool
    let data: Payload
    let error: String?
}
