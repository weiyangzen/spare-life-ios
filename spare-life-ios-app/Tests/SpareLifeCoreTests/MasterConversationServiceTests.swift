import XCTest
@testable import SpareLifeCore

final class MasterConversationServiceTests: XCTestCase {
    func testMasterChatLiveSmokeDerivesModelCatalogURLFromChatCompletionsURL() {
        let url = Self.modelCatalogURL(
            for: URL(string: "https://chat.example.com/gateway/v1/chat/completions")!
        )

        XCTAssertEqual(url.absoluteString, "https://chat.example.com/gateway/v1/models")
    }

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

    func testMasterChatConfigurationStatusWarnsWhenBaseURLMissingAndLegacyEnvExists() {
        let suiteName = "master-chat-status-missing-base-url-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated user defaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let status = MasterChatConfiguration.currentStatus(
            environment: [
                "MASTER_CHAT_API_KEY": "env-secret",
                "ANTHROPIC_HOST": "http://24.199.97.185:8080",
                "ANTHROPIC_BASE_URL": "http://24.199.97.185:8080",
                "ANTHROPIC_AUTH_TOKEN": "legacy-token",
                "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-4-6"
            ],
            userDefaults: defaults,
            keychainAPIKey: { nil },
            persistAPIKey: { _ in false }
        )

        XCTAssertEqual(status.title, "k2p5 端点未注入")
        XCTAssertFalse(status.isLiveRemote)
        XCTAssertTrue(status.detail.contains("MASTER_CHAT_BASE_URL"))
        XCTAssertTrue(status.detail.contains("defaults(masters.chat.baseURL)"))
        XCTAssertTrue(status.detail.contains("ANTHROPIC_HOST"))
        XCTAssertTrue(status.detail.contains("ANTHROPIC_BASE_URL"))
        XCTAssertTrue(status.detail.contains("ANTHROPIC_DEFAULT_OPUS_MODEL"))
        XCTAssertTrue(status.detail.contains("apiKey=env(MASTER_CHAT_API_KEY)"))
    }

    func testMasterChatConfigurationStatusWarnsWhenEndpointExistsButAPIKeyMissing() {
        let suiteName = "master-chat-status-missing-api-key-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated user defaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set("https://chat.example.com/gateway", forKey: "masters.chat.baseURL")
        defaults.set("stage2-k2p5", forKey: "masters.chat.model")

        let status = MasterChatConfiguration.currentStatus(
            environment: [:],
            userDefaults: defaults,
            keychainAPIKey: { nil },
            persistAPIKey: { _ in false }
        )

        XCTAssertEqual(status.title, "k2p5 鉴权未配置")
        XCTAssertFalse(status.isLiveRemote)
        XCTAssertTrue(status.detail.contains("https://chat.example.com/gateway/v1/chat/completions"))
        XCTAssertTrue(status.detail.contains("MASTER_CHAT_API_KEY"))
        XCTAssertTrue(status.detail.contains(K2P5MasterConversationService.keychainService))
        XCTAssertTrue(status.detail.contains(K2P5MasterConversationService.keychainAccount))
        XCTAssertTrue(status.detail.contains("model=defaults(masters.chat.model)"))
    }

    func testMasterChatConfigurationStatusReportsInjectedLiveCandidateSources() {
        let suiteName = "master-chat-status-live-candidate-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated user defaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let status = MasterChatConfiguration.currentStatus(
            environment: [
                "MASTER_CHAT_BASE_URL": "https://chat.example.com/gateway",
                "MASTER_CHAT_API_KEY": "env-secret",
                "MASTER_CHAT_MODEL": "stage2-k2p5"
            ],
            userDefaults: defaults,
            keychainAPIKey: { nil },
            persistAPIKey: { _ in false }
        )

        XCTAssertEqual(status.tone, .ready)
        XCTAssertEqual(status.title, "k2p5 live 候选已注入")
        XCTAssertFalse(status.isLiveRemote)
        XCTAssertTrue(status.isLiveCandidateConfigured)
        XCTAssertEqual(status.modelName, "stage2-k2p5")
        XCTAssertTrue(status.detail.contains("https://chat.example.com/gateway/v1/chat/completions"))
        XCTAssertTrue(status.detail.contains("baseURL=env(MASTER_CHAT_BASE_URL)"))
        XCTAssertTrue(status.detail.contains("model=env(MASTER_CHAT_MODEL)"))
        XCTAssertTrue(status.detail.contains("apiKey=env(MASTER_CHAT_API_KEY)"))
        XCTAssertTrue(status.detail.contains("live 候选配置已注入"))
    }

    func testMasterChatLiveSmokeConfigurationFallsBackToLegacyAnthropicEnvironment() throws {
        let suiteName = "master-chat-live-smoke-legacy-fallback-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated user defaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let resolved = try Self.liveSmokeConfiguration(
            environment: [
                "ANTHROPIC_BASE_URL": "http://24.199.97.185:8080",
                "ANTHROPIC_AUTH_TOKEN": "legacy-token"
            ],
            userDefaults: defaults
        )

        XCTAssertEqual(
            resolved.configuration.chatCompletionsURL.absoluteString,
            "http://24.199.97.185:8080/v1/chat/completions"
        )
        XCTAssertEqual(resolved.configuration.apiKey, "legacy-token")
        XCTAssertEqual(resolved.configuration.model, "k2p5")
        XCTAssertTrue(resolved.sourceSummary.contains("baseURL=legacy env(ANTHROPIC_BASE_URL)"))
        XCTAssertTrue(resolved.sourceSummary.contains("apiKey=legacy env(ANTHROPIC_AUTH_TOKEN)"))
        XCTAssertTrue(resolved.sourceSummary.contains("model=fallback(k2p5)"))
    }

    func testMasterChatLiveSmokeConfigurationPrefersStage2EnvironmentOverLegacyFallbacks() throws {
        let suiteName = "master-chat-live-smoke-stage2-priority-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated user defaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let resolved = try Self.liveSmokeConfiguration(
            environment: [
                "MASTER_CHAT_BASE_URL": "https://chat.example.com/gateway",
                "MASTER_CHAT_API_KEY": "stage2-secret",
                "MASTER_CHAT_MODEL": "stage2-k2p5",
                "ANTHROPIC_BASE_URL": "http://24.199.97.185:8080",
                "ANTHROPIC_AUTH_TOKEN": "legacy-token"
            ],
            userDefaults: defaults
        )

        XCTAssertEqual(
            resolved.configuration.chatCompletionsURL.absoluteString,
            "https://chat.example.com/gateway/v1/chat/completions"
        )
        XCTAssertEqual(resolved.configuration.apiKey, "stage2-secret")
        XCTAssertEqual(resolved.configuration.model, "stage2-k2p5")
        XCTAssertTrue(resolved.sourceSummary.contains("baseURL=env(MASTER_CHAT_BASE_URL)"))
        XCTAssertTrue(resolved.sourceSummary.contains("apiKey=env(MASTER_CHAT_API_KEY)"))
        XCTAssertTrue(resolved.sourceSummary.contains("model=env(MASTER_CHAT_MODEL)"))
        XCTAssertFalse(resolved.sourceSummary.contains("legacy env(ANTHROPIC_BASE_URL)"))
        XCTAssertFalse(resolved.sourceSummary.contains("legacy env(ANTHROPIC_AUTH_TOKEN)"))
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
            let payload = #"""
            {"model":"k2p5","choices":[{"message":{"role":"assistant","content":"这件事我先不绕。你先把现金流收住，再把下一步缩到一周内能见反馈的动作。"}}]}
            """#
            return (payload.data(using: .utf8)!, response)
        }

        let result = try await service.generateReply(for: makeRequest(messagePairCount: 7))
        let capturedRequest = await capture.load()
        let request = try XCTUnwrap(capturedRequest)

        XCTAssertEqual(result.text, "这件事我先不绕。你先把现金流收住，再把下一步缩到一周内能见反馈的动作。")
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
        let systemPrompt = try XCTUnwrap(messages.first?["content"] as? String)
        XCTAssertTrue(systemPrompt.contains("小说场景里这位角色当面对用户说出的台词"))
        XCTAssertTrue(systemPrompt.contains("禁止出现“作为 AI / 模型 / 助手”"))
        XCTAssertTrue(systemPrompt.contains("不要解释你的回复策略"))
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
            let payload = #"""
            {"choices":[{"message":{"role":"assistant","content":[{"type":"output_text","text":"这件事我先不绕。"},{"type":"output_text","text":"你先把现金流收住，再把动作压成七天实验。"}]}}]}
            """#
            return (payload.data(using: .utf8)!, response)
        }

        let result = try await service.generateReply(for: makeRequest(messagePairCount: 1))
        XCTAssertEqual(result.text, "这件事我先不绕。\n\n你先把现金流收住，再把动作压成七天实验。")
    }

    @MainActor
    func testK2P5ServiceRewritesGenericAssistantReplyIntoCharacterDialogue() async throws {
        let request = try makeRequest(messagePairCount: 1)
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
            let payload = #"""
            {"model":"k2p5","choices":[{"message":{"role":"assistant","content":"作为 AI 助手，我建议你：\n1. 先收缩现金流。\n2. 用七天实验验证转岗样本。\n3. 不要裸辞。"}}]}
            """#
            return (payload.data(using: .utf8)!, response)
        }

        let result = try await service.generateReply(for: request)

        XCTAssertFalse(result.text.contains("作为 AI"))
        XCTAssertFalse(result.text.contains("1."))
        XCTAssertTrue(result.text.contains("别再绕背景了，我们直接下判断。"))
        XCTAssertTrue(result.text.contains("先收缩现金流"))
        XCTAssertTrue(result.text.contains("七天实验"))
        XCTAssertTrue(result.text.contains(request.relevantStories[0].title))
    }

    @MainActor
    func testK2P5ServiceRewritesPlainProseReplyIntoCharacterDialogueWhenItLacksSceneAnchors() async throws {
        let request = try makeRequest(messagePairCount: 1)
        let configuration = MasterChatConfiguration(
            apiKey: "secret-token",
            credentialSource: .environmentFallback,
            chatCompletionsURL: URL(string: "https://chat.example.com/v1/chat/completions")!,
            model: "k2p5"
        )
        let rawReply = "先收缩现金流，再把转岗动作压成一个七天实验。结果出来前不要裸辞。"
        let service = K2P5MasterConversationService(configuration: configuration) { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let payload = #"{"model":"k2p5","choices":[{"message":{"role":"assistant","content":"\#(rawReply)"}}]}"#
            return (payload.data(using: .utf8)!, response)
        }

        let result = try await service.generateReply(for: request)

        XCTAssertNotEqual(result.text, rawReply)
        XCTAssertTrue(result.text.contains("别再绕背景了，我们直接下判断。"))
        XCTAssertTrue(result.text.contains(request.relevantStories[0].title))
        XCTAssertTrue(result.text.contains("先收缩现金流"))
        XCTAssertTrue(result.text.contains("七天实验"))
    }

    @MainActor
    func testK2P5ServiceRejectsUnexpectedReturnedModel() async throws {
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
            let payload = #"{"model":"claude-sonnet-4-5","choices":[{"message":{"role":"assistant","content":"这件事我先不绕。你先把现金流收住。"}}]}"#
            return (payload.data(using: .utf8)!, response)
        }

        do {
            _ = try await service.generateReply(for: makeRequest(messagePairCount: 1))
            XCTFail("Expected mismatched model to be rejected")
        } catch let error as MasterConversationServiceError {
            XCTAssertEqual(
                error,
                .unexpectedModel(expected: "k2p5", actual: "claude-sonnet-4-5")
            )
        }
    }

    @MainActor
    func testMasterExperienceStoreFallbackReplyUsesInCharacterDialogueInsteadOfMetaNarration() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("master-store-local-roleplay-\(UUID().uuidString)", isDirectory: true)
        let archiveURL = tempDirectory.appendingPathComponent("master-conversations.json", isDirectory: false)
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        let store = MasterExperienceStore(
            catalogLoader: { try MasterCatalogLoader.load() },
            conversationService: FailingConversationService(),
            localStateStore: MasterConversationLocalStateStore(archiveURL: archiveURL)
        )

        await store.refreshCatalog()

        let profile = try XCTUnwrap(store.visibleDirectoryMasters.first)
        store.openConversation(for: profile)

        var conversation = try XCTUnwrap(store.conversation)
        conversation.mode = .mentor
        store.conversation = conversation

        await store.sendMessage("我准备在三个月内从内容运营转到 AI 产品，但现金流很紧。你先别安慰我，直接判断我现在最该收缩还是推进。")

        let updatedConversation = try XCTUnwrap(store.conversation)
        let reply = try XCTUnwrap(updatedConversation.messages.last)

        XCTAssertEqual(updatedConversation.serviceStatus.title, "当前使用本地故事引擎")
        XCTAssertEqual(reply.role, .assistant)
        XCTAssertFalse(reply.text.contains("会按"))
        XCTAssertFalse(reply.text.contains("我的立场是"))
        XCTAssertTrue(reply.text.contains("别再绕背景了，我们直接下判断。"))
        XCTAssertFalse(reply.referencedStoryTitles.isEmpty)
        XCTAssertTrue(reply.text.contains(reply.referencedStoryTitles[0]))
    }

    @MainActor
    func testMasterExperienceStoreBootstrapsDirectorySnapshotAutomationWhenCommandInjected() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("master-store-automation-bootstrap-\(UUID().uuidString)", isDirectory: true)
        let archiveURL = tempDirectory.appendingPathComponent("master-conversations.json", isDirectory: false)
        let stateStore = MasterConversationLocalStateStore(archiveURL: archiveURL)
        let resultURL = stateStore.resultFileURL
        let environmentKeys = [
            "SPARE_MASTERS_AUTOMATION_COMMAND",
            "SPARE_MASTERS_AUTOMATION_MASTER_ID"
        ]
        defer {
            environmentKeys.forEach { unsetenv($0) }
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        setenv("SPARE_MASTERS_AUTOMATION_COMMAND", "directory_snapshot", 1)
        setenv("SPARE_MASTERS_AUTOMATION_MASTER_ID", "001546", 1)

        XCTAssertTrue(MasterStage1Automation.isEnabled())

        let store = MasterExperienceStore(
            catalogLoader: { try MasterCatalogLoader.load() },
            conversationService: FailingConversationService(),
            localStateStore: stateStore
        )

        let data = try await Self.waitForAutomationResult(at: resultURL)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(payload["command"] as? String, "directory_snapshot")
        XCTAssertEqual(payload["success"] as? Bool, true)
        XCTAssertEqual(payload["visibleMasterCount"] as? Int, 8)
        XCTAssertEqual(payload["totalMasterCount"] as? Int, 8)
        XCTAssertEqual(payload["matchedCoverageCount"] as? Int, 8)
        XCTAssertEqual(payload["hasExactStage1Coverage"] as? Bool, true)
        XCTAssertNil(payload["error"] as? String)
        XCTAssertNotNil(store)
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

        let liveSmoke = try Self.liveSmokeConfiguration(
            environment: environment,
            userDefaults: defaults
        )
        let configuration = liveSmoke.configuration
        let availableModels = try await Self.preflightAvailableModels(
            configuration: configuration,
            sourceSummary: liveSmoke.sourceSummary
        )
        guard availableModels.contains(configuration.model) else {
            throw XCTSkip(
                "Live k2p5 smoke blocked before send: \(Self.modelCatalogURL(for: configuration.chatCompletionsURL).absoluteString) [\(liveSmoke.sourceSummary)] does not advertise '\(configuration.model)'; available=\(availableModels.joined(separator: ", "))"
            )
        }
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
            throw XCTSkip(
                "Live k2p5 smoke blocked on first turn [\(liveSmoke.sourceSummary)]: \(firstConversation.serviceStatus.detail)"
            )
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
            throw XCTSkip(
                "Live k2p5 smoke blocked on follow-up [\(liveSmoke.sourceSummary)]: \(secondConversation.serviceStatus.detail)"
            )
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

    @MainActor
    func testMasterExperienceStorePersistsOneToOneK2P5ConversationAcrossReloads() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("master-store-k2p5-local-\(UUID().uuidString)", isDirectory: true)
        let archiveURL = tempDirectory.appendingPathComponent("master-conversations.json", isDirectory: false)
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        let capture = ConversationRequestCapture()
        let configuration = MasterChatConfiguration(
            apiKey: "secret-token",
            credentialSource: .environmentFallback,
            chatCompletionsURL: URL(string: "https://chat.example.com/v1/chat/completions")!,
            model: "k2p5"
        )

        let service = K2P5MasterConversationService(configuration: configuration) { request in
            let turn = await capture.storeAndReturnCount(request)
            let reply: String
            switch turn {
            case 1:
                reply = "这件事我先不绕。你先把现金流口子收住，再把转岗动作压成一个七天实验。"
            case 2:
                reply = "我只催你一件事：今天就把一个可交付样本发给三个能给真实反馈的人。再往后拖，你会继续拿准备感冒充推进。"
            default:
                reply = "我继续追问你一句：你最可能自欺的地方，就是拿准备感代替真实曝光。别让准备感替你演完了行动。"
            }

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let payload = #"{"model":"k2p5","choices":[{"message":{"role":"assistant","content":"\#(reply)"}}]}"#
            return (payload.data(using: .utf8)!, response)
        }

        let localStateStore = MasterConversationLocalStateStore(archiveURL: archiveURL)
        let firstStore = MasterExperienceStore(
            catalogLoader: { try MasterCatalogLoader.load() },
            conversationService: service,
            localStateStore: localStateStore
        )

        await firstStore.refreshCatalog()

        XCTAssertEqual(firstStore.visibleDirectoryMasters.count, 8)
        let profile = try XCTUnwrap(firstStore.visibleDirectoryMasters.first)
        let firstPrompt = "我准备在三个月内从内容运营转到 AI 产品，但现金流很紧。你先别安慰我，直接判断我现在最该收缩还是推进。"
        let secondPrompt = "如果只能做一个今天就能开始、七天内有反馈的动作，你会让我先做什么？"
        let resumePrompt = "我照你的话准备收成一个实验了。退出再回来后，请继续沿着刚才的话题追问我最容易自欺的地方。"

        firstStore.openConversation(for: profile)
        await firstStore.sendMessage(firstPrompt)
        await firstStore.sendMessage(secondPrompt)

        let firstConversation = try XCTUnwrap(firstStore.conversation)
        XCTAssertTrue(firstConversation.serviceStatus.isLiveRemote)
        XCTAssertEqual(firstConversation.serviceStatus.modelName, "k2p5")
        XCTAssertEqual(firstConversation.messages.count, 5)
        XCTAssertEqual(firstConversation.messages[1].text, firstPrompt)
        XCTAssertEqual(firstConversation.messages[2].text, "这件事我先不绕。你先把现金流口子收住，再把转岗动作压成一个七天实验。")
        XCTAssertEqual(firstConversation.messages[3].text, secondPrompt)
        XCTAssertEqual(firstConversation.messages[4].text, "我只催你一件事：今天就把一个可交付样本发给三个能给真实反馈的人。再往后拖，你会继续拿准备感冒充推进。")

        let reloadedStore = MasterExperienceStore(
            catalogLoader: { try MasterCatalogLoader.load() },
            conversationService: service,
            localStateStore: localStateStore
        )
        await reloadedStore.refreshCatalog()

        XCTAssertEqual(reloadedStore.visibleDirectoryMasters.count, 8)
        let persistedSession = try XCTUnwrap(reloadedStore.recentSessions.first(where: { $0.masterID == profile.id }))
        reloadedStore.restoreSession(persistedSession)

        let restoredConversation = try XCTUnwrap(reloadedStore.conversation)
        XCTAssertEqual(restoredConversation.messages.map(\.text), firstConversation.messages.map(\.text))
        XCTAssertEqual(restoredConversation.messages.count, 5)

        await reloadedStore.sendMessage(resumePrompt)

        let resumedConversation = try XCTUnwrap(reloadedStore.conversation)
        XCTAssertTrue(resumedConversation.serviceStatus.isLiveRemote)
        XCTAssertEqual(resumedConversation.serviceStatus.modelName, "k2p5")
        XCTAssertEqual(resumedConversation.messages.count, 7)
        XCTAssertEqual(resumedConversation.messages[5].text, resumePrompt)
        XCTAssertEqual(resumedConversation.messages[6].text, "我继续追问你一句：你最可能自欺的地方，就是拿准备感代替真实曝光。别让准备感替你演完了行动。")

        let requests = await capture.all()
        XCTAssertEqual(requests.count, 3)

        let thirdRequest = try XCTUnwrap(requests.last)
        XCTAssertEqual(thirdRequest.url?.absoluteString, "https://chat.example.com/v1/chat/completions")
        XCTAssertEqual(thirdRequest.httpMethod, "POST")
        XCTAssertEqual(thirdRequest.value(forHTTPHeaderField: "Authorization"), "Bearer secret-token")

        let body = try XCTUnwrap(thirdRequest.httpBody)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(payload["model"] as? String, "k2p5")
        let messages = try XCTUnwrap(payload["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 7)
        XCTAssertEqual(messages.first?["role"] as? String, "system")
        XCTAssertTrue(messages.contains { ($0["content"] as? String) == firstPrompt })
        XCTAssertTrue(messages.contains { ($0["content"] as? String) == "这件事我先不绕。你先把现金流口子收住，再把转岗动作压成一个七天实验。" })
        XCTAssertTrue(messages.contains { ($0["content"] as? String) == secondPrompt })
        XCTAssertTrue(messages.contains { ($0["content"] as? String) == "我只催你一件事：今天就把一个可交付样本发给三个能给真实反馈的人。再往后拖，你会继续拿准备感冒充推进。" })
        XCTAssertTrue(messages.contains { ($0["content"] as? String) == resumePrompt })
    }

    @MainActor
    func testMasterExperienceStoreShowsCandidateBeforeFirstLiveReplyThenPromotesToLive() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("master-store-k2p5-candidate-\(UUID().uuidString)", isDirectory: true)
        let archiveURL = tempDirectory.appendingPathComponent("master-conversations.json", isDirectory: false)
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

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
            return (#"{"model":"k2p5","choices":[{"message":{"role":"assistant","content":"先把你的验证动作缩成一周内能交付的样本。"}}]}"#.data(using: .utf8)!, response)
        }

        let store = MasterExperienceStore(
            catalogLoader: { try MasterCatalogLoader.load() },
            conversationService: service,
            localStateStore: MasterConversationLocalStateStore(archiveURL: archiveURL)
        )

        await store.refreshCatalog()

        let profile = try XCTUnwrap(store.visibleDirectoryMasters.first)
        store.openConversation(for: profile)

        let initialConversation = try XCTUnwrap(store.conversation)
        XCTAssertEqual(initialConversation.serviceStatus.tone, .ready)
        XCTAssertEqual(initialConversation.serviceStatus.title, "k2p5 live 候选已注入")
        XCTAssertFalse(initialConversation.serviceStatus.isLiveRemote)
        XCTAssertTrue(initialConversation.serviceStatus.isLiveCandidateConfigured)

        await store.sendMessage("我该先收缩现金流，还是继续推进转岗样本？")

        let updatedConversation = try XCTUnwrap(store.conversation)
        XCTAssertEqual(updatedConversation.serviceStatus.tone, .success)
        XCTAssertEqual(updatedConversation.serviceStatus.title, "实时对话已接通")
        XCTAssertTrue(updatedConversation.serviceStatus.isLiveRemote)
        XCTAssertFalse(updatedConversation.serviceStatus.isLiveCandidateConfigured)
        XCTAssertEqual(updatedConversation.serviceStatus.modelName, "k2p5")
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

    private static func waitForAutomationResult(
        at url: URL,
        timeout: TimeInterval = 8
    ) async throws -> Data {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: url.path) {
                return try Data(contentsOf: url)
            }
            try await Task.sleep(nanoseconds: 200_000_000)
        }

        XCTFail("Timed out waiting for automation result at \(url.path)")
        return Data()
    }

    private static func preflightAvailableModels(
        configuration: MasterChatConfiguration,
        sourceSummary: String
    ) async throws -> [String] {
        var request = URLRequest(url: modelCatalogURL(for: configuration.chatCompletionsURL))
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw XCTSkip(
                    "Live k2p5 smoke blocked before send: /v1/models [\(sourceSummary)] returned a non-HTTP response."
                )
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                let detail = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                throw XCTSkip(
                    "Live k2p5 smoke blocked before send: \(request.url?.absoluteString ?? "/v1/models") [\(sourceSummary)] returned \(httpResponse.statusCode). \(detail)"
                )
            }
            let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let models = (payload["data"] as? [[String: Any]])?
                .compactMap { entry in
                    (entry["id"] as? String)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .filter { !$0.isEmpty } ?? []
            return models
        } catch let error as XCTSkip {
            throw error
        } catch {
            throw XCTSkip(
                "Live k2p5 smoke blocked before send: failed to probe /v1/models [\(sourceSummary)]. \(error.localizedDescription)"
            )
        }
    }

    private static func liveSmokeConfiguration(
        environment: [String: String],
        userDefaults: UserDefaults
    ) throws -> LiveSmokeConfiguration {
        var resolvedEnvironment = environment

        let baseURLSource: String
        if trimmedEnvironmentValue("MASTER_CHAT_BASE_URL", in: resolvedEnvironment) != nil {
            baseURLSource = "env(MASTER_CHAT_BASE_URL)"
        } else if let legacyBaseURL = trimmedEnvironmentValue("ANTHROPIC_BASE_URL", in: environment) {
            resolvedEnvironment["MASTER_CHAT_BASE_URL"] = legacyBaseURL
            baseURLSource = "legacy env(ANTHROPIC_BASE_URL)"
        } else if let legacyHost = trimmedEnvironmentValue("ANTHROPIC_HOST", in: environment) {
            resolvedEnvironment["MASTER_CHAT_BASE_URL"] = legacyHost
            baseURLSource = "legacy env(ANTHROPIC_HOST)"
        } else {
            throw XCTSkip(
                "Live k2p5 smoke blocked before send: missing MASTER_CHAT_BASE_URL and no legacy ANTHROPIC_BASE_URL / ANTHROPIC_HOST is available."
            )
        }

        let apiKeySource: String
        if trimmedEnvironmentValue("MASTER_CHAT_API_KEY", in: resolvedEnvironment) != nil {
            apiKeySource = "env(MASTER_CHAT_API_KEY)"
        } else if let legacyAuthToken = trimmedEnvironmentValue("ANTHROPIC_AUTH_TOKEN", in: environment) {
            resolvedEnvironment["MASTER_CHAT_API_KEY"] = legacyAuthToken
            apiKeySource = "legacy env(ANTHROPIC_AUTH_TOKEN)"
        } else if let legacyAPIKey = trimmedEnvironmentValue("ANTHROPIC_API_KEY", in: environment) {
            resolvedEnvironment["MASTER_CHAT_API_KEY"] = legacyAPIKey
            apiKeySource = "legacy env(ANTHROPIC_API_KEY)"
        } else {
            throw XCTSkip(
                "Live k2p5 smoke blocked before send: missing MASTER_CHAT_API_KEY and no legacy ANTHROPIC_AUTH_TOKEN / ANTHROPIC_API_KEY is available."
            )
        }

        let modelSource: String
        if let model = trimmedEnvironmentValue("MASTER_CHAT_MODEL", in: resolvedEnvironment) {
            resolvedEnvironment["MASTER_CHAT_MODEL"] = model
            modelSource = "env(MASTER_CHAT_MODEL)"
        } else {
            resolvedEnvironment["MASTER_CHAT_MODEL"] = K2P5MasterConversationService.modelFallback
            modelSource = "fallback(\(K2P5MasterConversationService.modelFallback))"
        }

        let configuration = try MasterChatConfiguration.current(
            environment: resolvedEnvironment,
            userDefaults: userDefaults,
            keychainAPIKey: { nil },
            persistAPIKey: { _ in false }
        )
        return LiveSmokeConfiguration(
            configuration: configuration,
            sourceSummary: "baseURL=\(baseURLSource)；apiKey=\(apiKeySource)；model=\(modelSource)"
        )
    }

    private static func trimmedEnvironmentValue(_ key: String, in environment: [String: String]) -> String? {
        guard let value = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func modelCatalogURL(for chatCompletionsURL: URL) -> URL {
        chatCompletionsURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("models")
    }
}

private struct LiveSmokeConfiguration {
    let configuration: MasterChatConfiguration
    let sourceSummary: String
}

private actor ConversationRequestCapture {
    private var requests: [URLRequest] = []

    func store(_ request: URLRequest) {
        requests.append(request)
    }

    func storeAndReturnCount(_ request: URLRequest) -> Int {
        requests.append(request)
        return requests.count
    }

    func load() -> URLRequest? {
        requests.last
    }

    func all() -> [URLRequest] {
        requests
    }
}

@MainActor
private final class FailingConversationService: MasterConversationReplying {
    var status: MasterConversationServiceStatus {
        .candidate(
            modelName: "k2p5",
            credentialSource: .environmentFallback
        )
    }

    func generateReply(for request: MasterConversationRequest) async throws -> MasterConversationServiceResult {
        throw MasterConversationServiceError.transport("network down")
    }
}
