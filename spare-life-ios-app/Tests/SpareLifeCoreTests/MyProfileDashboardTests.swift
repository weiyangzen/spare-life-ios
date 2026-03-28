import XCTest
@testable import SpareLifeCore

final class MyProfileDashboardTests: XCTestCase {
    func testDashboardLayoutReusesStage2SharedBreakpoints() {
        XCTAssertEqual(MyProfileDashboardLayout.shared(for: 393).columnCount, 2)
        XCTAssertEqual(MyProfileDashboardLayout.shared(for: 834).columnCount, 2)
        XCTAssertEqual(MyProfileDashboardLayout.shared(for: 1024).columnCount, 5)
        XCTAssertEqual(MyProfileDashboardLayout.shared(for: 393).cardSpacing, Spacing.sm, accuracy: 0.001)
    }

    func testDashboardLayoutKeepsEightToFiveCardFootprintAsMinimumHeight() {
        let layout = MyProfileDashboardLayout.shared(for: 393)
        let expectedHeight = max(112, floor(((393 - (layout.horizontalPadding * 2) - layout.cardSpacing) / 2) / layout.cardAspectRatio))

        XCTAssertEqual(layout.minimumCardHeight, expectedHeight, accuracy: 0.001)
    }

    func testXianrenStatsAggregateAcrossPaginatedTopicSnapshots() async throws {
        let cacheRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-profile-xianren-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: cacheRoot) }

        let transport = MyProfileMockClawdbTransport()
        await transport.setTopicBatch(
            cursor: nil,
            batch: XianxiaTopicBatch(
                items: [
                    makeTopic(
                        id: "group:alpha::topic-001",
                        path: "group/alpha/topic-001",
                        summary: "命中 @alice oc_11111111111111111111111111111111",
                        updatedAt: Date(timeIntervalSince1970: 1_770_000_000)
                    ),
                    makeTopic(
                        id: "group:beta::topic-002",
                        path: "group/beta/topic-002",
                        summary: "命中 @bob @carol ou_22222222222222222222222222222222",
                        updatedAt: Date(timeIntervalSince1970: 1_770_000_100)
                    )
                ],
                nextCursor: "cursor-2",
                total: 3,
                batchSize: 2,
                tenantId: "default"
            )
        )
        await transport.setTopicBatch(
            cursor: "cursor-2",
            batch: XianxiaTopicBatch(
                items: [
                    makeTopic(
                        id: "group:gamma::topic-003",
                        path: "group/gamma/topic-003",
                        summary: "补充 @dave oc_33333333333333333333333333333333",
                        updatedAt: Date(timeIntervalSince1970: 1_770_000_200)
                    )
                ],
                nextCursor: nil,
                total: 3,
                batchSize: 2,
                tenantId: "default"
            )
        )

        let repository = XianxiaTopicRepository(
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

        let statsRepository = MyProfileXianrenStatsRepository(topicRepository: repository)
        let stats = try await statsRepository.loadLiveStats()

        XCTAssertEqual(stats.channelCount, 3)
        XCTAssertEqual(stats.topicCount, 3)
        XCTAssertEqual(stats.uniqueIDCount, 3)
        XCTAssertEqual(stats.mentionCount, 4)
        XCTAssertEqual(stats.latestTopicAt, Date(timeIntervalSince1970: 1_770_000_200))
    }

    private func makeTopic(
        id: String,
        path: String,
        summary: String,
        updatedAt: Date
    ) -> XianxiaTopic {
        XianxiaTopic(
            topicId: id,
            topicPath: path,
            status: "active",
            messageCount: 12,
            summary: summary,
            updatedAt: updatedAt,
            shardCount: 1
        )
    }
}

private actor MyProfileMockClawdbTransport {
    private var topicBatches: [String: XianxiaTopicBatch] = [:]

    func setTopicBatch(cursor: String?, batch: XianxiaTopicBatch) {
        topicBatches[cursor ?? "__first__"] = batch
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

        guard url.path.hasSuffix("/topics") else {
            throw XianxiaTopicRepositoryError.transport("Unhandled mock route: \(url.absoluteString)")
        }

        let cursor = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "cursor" })?
            .value
        let key = cursor ?? "__first__"

        guard let batch = topicBatches[key] else {
            throw XianxiaTopicRepositoryError.transport("Missing topic mock for \(key)")
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(MyProfileGatewayEnvelope(ok: true, data: batch, error: nil))
        return (data, response)
    }
}

private struct MyProfileGatewayEnvelope<Payload: Encodable>: Encodable {
    let ok: Bool
    let data: Payload
    let error: String?
}
