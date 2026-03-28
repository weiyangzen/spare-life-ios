import XCTest
@testable import SpareLifeCore

final class MasterConversationServiceTests: XCTestCase {
    func testMasterChatConfigurationBuildsChatCompletionsURLAndDefaultsToK2P5() throws {
        let suiteName = "master-chat-config-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated user defaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set("https://chat.example.com/gateway", forKey: "masters.chat.baseURL")

        let configuration = try MasterChatConfiguration.current(
            environment: ["MASTER_CHAT_API_KEY": "env-secret"],
            userDefaults: defaults,
            keychainAPIKey: { nil },
            persistAPIKey: { _ in false }
        )

        XCTAssertEqual(configuration.apiKey, "env-secret")
        XCTAssertEqual(configuration.credentialSource, .environmentFallback)
        XCTAssertEqual(configuration.chatCompletionsURL.absoluteString, "https://chat.example.com/gateway/v1/chat/completions")
        XCTAssertEqual(configuration.model, "k2p5")
    }

    @MainActor
    func testK2P5ServiceBuildsOpenAICompatibleRequestAndKeepsFullContext() async throws {
        let capture = ConversationRequestCapture()
        let configuration = MasterChatConfiguration(
            apiKey: "secret-token",
            credentialSource: .environmentFallback,
            chatCompletionsURL: URL(string: "https://chat.example.com/v1/chat/completions")!,
            model: "k2p5"
        )
        let service = K2P5MasterConversationService(configuration: configuration) { request in
            await capture.store(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (#"{"model":"k2p5","choices":[{"message":{"role":"assistant","content":"联通成功"}}]}"#.data(using: .utf8)!, response)
        }

        let result = try await service.generateReply(for: makeRequest(messagePairCount: 7))
        let capturedRequest = await capture.load()
        let request = try XCTUnwrap(capturedRequest)

        XCTAssertEqual(result.text, "联通成功")
        XCTAssertEqual(result.status.modelName, "k2p5")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://chat.example.com/v1/chat/completions")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret-token")

        let body = try XCTUnwrap(request.httpBody)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(payload["model"] as? String, "k2p5")
        XCTAssertEqual(payload["max_tokens"] as? Int, 700)

        let messages = try XCTUnwrap(payload["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 15)
        XCTAssertEqual(messages.first?["role"] as? String, "system")
        XCTAssertTrue(messages.contains { ($0["content"] as? String) == "用户消息 0" })
        XCTAssertTrue(messages.contains { ($0["content"] as? String) == "助手消息 0" })
        XCTAssertTrue(messages.contains { ($0["content"] as? String) == "用户消息 6" })
        XCTAssertTrue(messages.contains { ($0["content"] as? String) == "助手消息 6" })
    }

    @MainActor
    func testK2P5ServiceDecodesArrayContentBlocks() async throws {
        let configuration = MasterChatConfiguration(
            apiKey: "secret-token",
            credentialSource: .environmentFallback,
            chatCompletionsURL: URL(string: "https://chat.example.com/v1/chat/completions")!,
            model: "k2p5"
        )
        let service = K2P5MasterConversationService(configuration: configuration) { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (#"{"choices":[{"message":{"role":"assistant","content":[{"type":"output_text","text":"第一句"},{"type":"output_text","text":"第二句"}]}}]}"#.data(using: .utf8)!, response)
        }

        let result = try await service.generateReply(for: makeRequest(messagePairCount: 1))
        XCTAssertEqual(result.text, "第一句\n\n第二句")
    }

    @MainActor
    func testMasterExperienceStoreLiveSmokeRunsWhenExplicitlyEnabled() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["MASTER_CHAT_LIVE_SMOKE"] == "1" else {
            throw XCTSkip("Set MASTER_CHAT_LIVE_SMOKE=1 to run the live k2p5 one-to-one smoke test.")
        }

        let suiteName = "master-chat-live-smoke-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated user defaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let configuration = try MasterChatConfiguration.current(
            environment: environment,
            userDefaults: defaults,
            keychainAPIKey: { nil },
            persistAPIKey: { _ in false }
        )
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("master-live-chat-tests-\(UUID().uuidString)", isDirectory: true)
        let archiveURL = tempDirectory.appendingPathComponent("master-conversations.json", isDirectory: false)
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        let service = K2P5MasterConversationService(configuration: configuration) { request in
            try await URLSession.shared.data(for: request)
        }
        let store = MasterExperienceStore(
            catalogLoader: { try MasterCatalogLoader.load() },
            conversationService: service,
            localStateStore: MasterConversationLocalStateStore(archiveURL: archiveURL)
        )

        await store.refreshCatalog()

        let targetMasterID = environment["MASTER_CHAT_SMOKE_MASTER_ID"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let profile = try XCTUnwrap(
            targetMasterID.flatMap(store.master(withID:)) ?? store.visibleDirectoryMasters.first
        )
        let firstPrompt = requiredLiveSmokeValue(
            for: "MASTER_CHAT_SMOKE_FIRST_PROMPT",
            environment: environment,
            fallback: "我准备在三个月内从内容运营转到 AI 产品，但现金流很紧。你先别安慰我，直接判断我现在最该收缩还是推进。"
        )
        let secondPrompt = requiredLiveSmokeValue(
            for: "MASTER_CHAT_SMOKE_SECOND_PROMPT",
            environment: environment,
            fallback: "如果只能做一个今天就能开始、七天内有反馈的动作，你会让我先做什么？"
        )

        store.openConversation(for: profile)
        let initialCount = try XCTUnwrap(store.conversation?.messages.count)

        await store.sendMessage(firstPrompt)
        let firstConversation = try XCTUnwrap(store.conversation)
        guard firstConversation.serviceStatus.isLiveRemote else {
            throw XCTSkip("Live k2p5 smoke blocked on first turn: \(firstConversation.serviceStatus.detail)")
        }
        XCTAssertGreaterThanOrEqual(firstConversation.messages.count, initialCount + 2)
        XCTAssertEqual(firstConversation.messages[firstConversation.messages.count - 2].text, firstPrompt)
        XCTAssertEqual(firstConversation.messages.last?.role, .assistant)
        XCTAssertFalse(
            firstConversation.messages.last?.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
        )

        await store.sendMessage(secondPrompt)
        let secondConversation = try XCTUnwrap(store.conversation)
        guard secondConversation.serviceStatus.isLiveRemote else {
            throw XCTSkip("Live k2p5 smoke blocked on follow-up: \(secondConversation.serviceStatus.detail)")
        }
        XCTAssertGreaterThanOrEqual(secondConversation.messages.count, initialCount + 4)
        XCTAssertEqual(secondConversation.messages[secondConversation.messages.count - 2].text, secondPrompt)
        XCTAssertEqual(secondConversation.messages.last?.role, .assistant)
        XCTAssertFalse(
            secondConversation.messages.last?.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
        )

        if let expectedSubstring = environment["MASTER_CHAT_SMOKE_EXPECT_SUBSTRING"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !expectedSubstring.isEmpty {
            XCTAssertTrue(
                secondConversation.messages.last?.text.localizedCaseInsensitiveContains(expectedSubstring) == true,
                "Expected reply to contain '\(expectedSubstring)', got '\(secondConversation.messages.last?.text ?? "")'"
            )
        }
    }

    private func makeRequest(messagePairCount: Int) throws -> MasterConversationRequest {
        let snapshot = try MasterCatalogLoader.load()
        let profile = try XCTUnwrap(snapshot.masters.first)
        var messages: [MasterMessage] = []
        for index in 0..<messagePairCount {
            messages.append(
                MasterMessage(
                    id: "user-\(index)",
                    role: .user,
                    text: "用户消息 \(index)",
                    timestamp: "刚刚",
                    referencedStoryTitles: [],
                    referencedMemoryLabels: [],
                    ctas: []
                )
            )
            messages.append(
                MasterMessage(
                    id: "assistant-\(index)",
                    role: .assistant,
                    text: "助手消息 \(index)",
                    timestamp: "刚刚",
                    referencedStoryTitles: [],
                    referencedMemoryLabels: [],
                    ctas: []
                )
            )
        }

        return MasterConversationRequest(
            profile: profile,
            mode: .mentor,
            memoryScope: .masterOnly,
            authorizedMemories: Array(profile.memoryNotes.prefix(1)),
            relevantStories: Array(profile.stories.prefix(1)),
            recentMessages: messages
        )
    }

    private func requiredLiveSmokeValue(
        for key: String,
        environment: [String: String],
        fallback: String
    ) -> String {
        guard let value = environment[key]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty else {
            return fallback
        }
        return value
    }
}

private actor ConversationRequestCapture {
    private(set) var request: URLRequest?

    func store(_ request: URLRequest) {
        self.request = request
    }

    func load() -> URLRequest? {
        request
    }
}
