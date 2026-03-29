import XCTest
@testable import SpareLifeCore

final class MasterConversationServiceTests: XCTestCase {
    func testMasterChatLiveSmokeDerivesModelCatalogURLFromChatCompletionsURL() {
        let url = MasterChatLiveProbe.modelCatalogURL(
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

        let resolved = try MasterChatLiveProbe.resolveCandidate(
            environment: [
                "ANTHROPIC_BASE_URL": "http://24.199.97.185:8080",
                "ANTHROPIC_AUTH_TOKEN": "legacy-token"
            ],
            userDefaults: defaults,
            keychainAPIKey: { nil }
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

        let resolved = try MasterChatLiveProbe.resolveCandidate(
            environment: [
                "MASTER_CHAT_BASE_URL": "https://chat.example.com/gateway",
                "MASTER_CHAT_API_KEY": "stage2-secret",
                "MASTER_CHAT_MODEL": "stage2-k2p5",
                "ANTHROPIC_BASE_URL": "http://24.199.97.185:8080",
                "ANTHROPIC_AUTH_TOKEN": "legacy-token"
            ],
            userDefaults: defaults,
            keychainAPIKey: { nil }
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

    func testMasterChatLiveProbeUsesDefaultsAndKeychainBeforeLegacyFallbacks() throws {
        let suiteName = "master-chat-live-probe-defaults-keychain-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated user defaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set("https://chat.example.com/defaults-gateway", forKey: "masters.chat.baseURL")
        defaults.set("defaults-k2p5", forKey: "masters.chat.model")

        let resolved = try MasterChatLiveProbe.resolveCandidate(
            environment: [
                "ANTHROPIC_BASE_URL": "http://24.199.97.185:8080",
                "ANTHROPIC_AUTH_TOKEN": "legacy-token"
            ],
            userDefaults: defaults,
            keychainAPIKey: { "keychain-secret" }
        )

        XCTAssertEqual(
            resolved.configuration.chatCompletionsURL.absoluteString,
            "https://chat.example.com/defaults-gateway/v1/chat/completions"
        )
        XCTAssertEqual(resolved.configuration.apiKey, "keychain-secret")
        XCTAssertEqual(resolved.configuration.credentialSource, .keychain)
        XCTAssertEqual(resolved.configuration.model, "defaults-k2p5")
        XCTAssertTrue(resolved.sourceSummary.contains("baseURL=defaults(masters.chat.baseURL)"))
        XCTAssertTrue(resolved.sourceSummary.contains("apiKey=keychain(\(K2P5MasterConversationService.keychainService)/\(K2P5MasterConversationService.keychainAccount))"))
        XCTAssertTrue(resolved.sourceSummary.contains("model=defaults(masters.chat.model)"))
        XCTAssertFalse(resolved.sourceSummary.contains("legacy env(ANTHROPIC_BASE_URL)"))
        XCTAssertFalse(resolved.sourceSummary.contains("legacy env(ANTHROPIC_AUTH_TOKEN)"))
    }

    func testMasterChatLiveProbePreflightRejectsMissingExpectedModel() async throws {
        let candidate = MasterChatLiveProbeCandidate(
            configuration: MasterChatConfiguration(
                apiKey: "secret-token",
                credentialSource: .environmentFallback,
                chatCompletionsURL: URL(string: "https://chat.example.com/v1/chat/completions")!,
                model: "k2p5"
            ),
            sourceSummary: "baseURL=env(MASTER_CHAT_BASE_URL)；apiKey=env(MASTER_CHAT_API_KEY)；model=fallback(k2p5)"
        )

        do {
            _ = try await MasterChatLiveProbe.ensureExpectedModelAdvertised(candidate: candidate) { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                let payload = #"""
                {"data":[{"id":"claude-sonnet-4-6"},{"id":"claude-haiku-4-5-20251001"}],"object":"list"}
                """#
                return (payload.data(using: .utf8)!, response)
            }
            XCTFail("Expected missing k2p5 to be rejected")
        } catch let error as MasterChatLiveProbeError {
            XCTAssertEqual(
                error,
                .modelNotAdvertised(
                    url: "https://chat.example.com/v1/models",
                    sourceSummary: "baseURL=env(MASTER_CHAT_BASE_URL)；apiKey=env(MASTER_CHAT_API_KEY)；model=fallback(k2p5)",
                    expectedModel: "k2p5",
                    availableModels: ["claude-sonnet-4-6", "claude-haiku-4-5-20251001"]
                )
            )
        }
    }

    func testMasterChatLiveProbePreflightAcceptsVersionedK2P5ModelAlias() async throws {
        let candidate = MasterChatLiveProbeCandidate(
            configuration: MasterChatConfiguration(
                apiKey: "secret-token",
                credentialSource: .environmentFallback,
                chatCompletionsURL: URL(string: "https://chat.example.com/v1/chat/completions")!,
                model: "k2p5"
            ),
            sourceSummary: "baseURL=env(MASTER_CHAT_BASE_URL)；apiKey=env(MASTER_CHAT_API_KEY)；model=fallback(k2p5)"
        )

        let availableModels = try await MasterChatLiveProbe.ensureExpectedModelAdvertised(candidate: candidate) { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let payload = #"""
            {"data":[{"id":"k2p5-20260328"},{"id":"claude-sonnet-4-6"}],"object":"list"}
            """#
            return (payload.data(using: .utf8)!, response)
        }

        XCTAssertEqual(availableModels, ["k2p5-20260328", "claude-sonnet-4-6"])
    }

    @MainActor
    func testMasterExperienceStoreRefreshCatalogAppliesInvalidAPIKeyPreflightStatusToEntry() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("master-store-k2p5-preflight-invalid-key-\(UUID().uuidString)", isDirectory: true)
        let archiveURL = tempDirectory.appendingPathComponent("master-conversations.json", isDirectory: false)
        let suiteName = "master-chat-preflight-invalid-key-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated user defaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        let probe = MasterExperienceStore.makeDefaultChatLiveStatusProbe(
            environment: [
                "ANTHROPIC_BASE_URL": "http://24.199.97.185:8080",
                "ANTHROPIC_AUTH_TOKEN": "legacy-invalid-token"
            ],
            userDefaults: defaults
        ) { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let payload = #"{"code":"INVALID_API_KEY","message":"Invalid API key"}"#
            return (payload.data(using: .utf8)!, response)
        }

        let store = MasterExperienceStore(
            catalogLoader: { try MasterCatalogLoader.load() },
            conversationService: FailingConversationService(),
            chatLiveStatusProbe: probe,
            localStateStore: MasterConversationLocalStateStore(archiveURL: archiveURL)
        )

        await store.refreshCatalog()

        XCTAssertEqual(store.conversationServiceStatus.title, "k2p5 鉴权失效")
        XCTAssertFalse(store.conversationServiceStatus.isLiveRemote)
        XCTAssertTrue(store.conversationServiceStatus.detail.contains("/v1/models"))
        XCTAssertTrue(
            store.conversationServiceStatus.detail.contains("401") ||
            store.conversationServiceStatus.detail.contains("Invalid API key")
        )
        XCTAssertTrue(
            store.conversationServiceStatus.detail.contains("INVALID_API_KEY") ||
            store.conversationServiceStatus.detail.contains("Invalid API key")
        )
        XCTAssertTrue(store.conversationServiceStatus.detail.contains("legacy env(ANTHROPIC_AUTH_TOKEN)"))

        let profile = try XCTUnwrap(store.visibleDirectoryMasters.first)
        store.openConversation(for: profile)

        XCTAssertEqual(store.conversation?.serviceStatus.title, "k2p5 鉴权失效")
        XCTAssertTrue(store.conversation?.serviceStatus.detail.contains("INVALID_API_KEY") == true)
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
    func testK2P5ServiceAcceptsVersionedReturnedModelAlias() async throws {
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
            let payload = #"{"model":"k2p5-20260328","choices":[{"message":{"role":"assistant","content":"这件事我先不绕。你先把动作压成七天内能看到反馈的样本。"}}]}"#
            return (payload.data(using: .utf8)!, response)
        }

        let result = try await service.generateReply(for: makeRequest(messagePairCount: 1))

        XCTAssertEqual(result.status.modelName, "k2p5-20260328")
        XCTAssertTrue(result.status.isLiveRemote)
        XCTAssertTrue(result.text.contains("七天内能看到反馈"))
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
        let expectedTotalMasterCount = try MasterCatalogLoader.load().masters.count
        let expectedVisibleMasterCount = min(expectedTotalMasterCount, 8)

        let store = MasterExperienceStore(
            catalogLoader: { try MasterCatalogLoader.load() },
            conversationService: FailingConversationService(),
            localStateStore: stateStore
        )

        let data = try await Self.waitForAutomationResult(at: resultURL)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(payload["command"] as? String, "directory_snapshot")
        XCTAssertEqual(payload["success"] as? Bool, true)
        XCTAssertEqual(payload["visibleMasterCount"] as? Int, expectedVisibleMasterCount)
        XCTAssertEqual(payload["totalMasterCount"] as? Int, expectedTotalMasterCount)
        XCTAssertEqual(payload["matchedCoverageCount"] as? Int, expectedTotalMasterCount)
        XCTAssertEqual(payload["hasExactStage1Coverage"] as? Bool, true)
        XCTAssertNil(payload["error"] as? String)
        XCTAssertNotNil(store)
    }

    @MainActor
    func testMasterStage1AutomationWritesStage2SmokeValidation() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("master-store-automation-stage2-smoke-\(UUID().uuidString)", isDirectory: true)
        let archiveURL = tempDirectory.appendingPathComponent("master-conversations.json", isDirectory: false)
        let stateStore = MasterConversationLocalStateStore(archiveURL: archiveURL)
        let resultURL = stateStore.resultFileURL
        let firstPrompt = "别给安慰，我只要你判断现在该先止损还是继续推进转岗。"
        let secondPrompt = "如果今天只能做一件七天内能看到反馈的动作，你会逼我先做什么？"
        let environmentKeys = [
            "SPARE_MASTERS_AUTOMATION_COMMAND",
            "SPARE_MASTERS_AUTOMATION_MASTER_ID",
            "SPARE_MASTERS_AUTOMATION_FIRST_PROMPT",
            "SPARE_MASTERS_AUTOMATION_SECOND_PROMPT",
            "SPARE_MASTERS_AUTOMATION_RESUME_PROMPT"
        ]
        defer {
            environmentKeys.forEach { unsetenv($0) }
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        setenv("SPARE_MASTERS_AUTOMATION_COMMAND", "stage2_smoke", 1)
        setenv("SPARE_MASTERS_AUTOMATION_MASTER_ID", "001546", 1)
        setenv("SPARE_MASTERS_AUTOMATION_FIRST_PROMPT", firstPrompt, 1)
        setenv("SPARE_MASTERS_AUTOMATION_SECOND_PROMPT", secondPrompt, 1)
        let expectedTotalMasterCount = try MasterCatalogLoader.load().masters.count
        let expectedVisibleMasterCount = min(expectedTotalMasterCount, 8)

        let capture = ConversationRequestCapture()
        let store = MasterExperienceStore(
            catalogLoader: { try MasterCatalogLoader.load() },
            conversationService: makeAutomationLiveService(capture: capture),
            localStateStore: stateStore
        )

        let data = try await Self.waitForAutomationResult(at: resultURL)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(payload["command"] as? String, "stage2_smoke")
        XCTAssertEqual(payload["success"] as? Bool, true)
        XCTAssertEqual(payload["masterID"] as? String, "001546")
        XCTAssertEqual(payload["visibleMasterCount"] as? Int, expectedVisibleMasterCount)
        XCTAssertEqual(payload["totalMasterCount"] as? Int, expectedTotalMasterCount)
        XCTAssertEqual(payload["matchedCoverageCount"] as? Int, expectedTotalMasterCount)
        XCTAssertEqual(payload["hasExactStage1Coverage"] as? Bool, true)
        XCTAssertEqual(payload["transcriptCount"] as? Int, 5)
        XCTAssertEqual(payload["serviceMode"] as? String, "liveRemote")
        XCTAssertEqual(payload["serviceTitle"] as? String, "实时对话已接通")
        XCTAssertNotNil(payload["sessionID"] as? String)
        XCTAssertNil(payload["error"] as? String)
        XCTAssertNotNil(store)

        let requests = await capture.all()
        XCTAssertEqual(requests.count, 2)

        let secondRequest = try XCTUnwrap(requests.last)
        let secondBody = try XCTUnwrap(secondRequest.httpBody)
        let secondPayload = try XCTUnwrap(JSONSerialization.jsonObject(with: secondBody) as? [String: Any])
        XCTAssertEqual(secondPayload["model"] as? String, "k2p5")

        let messages = try XCTUnwrap(secondPayload["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 5)
        XCTAssertEqual(messages[0]["role"] as? String, "system")
        XCTAssertEqual(messages[1]["role"] as? String, "assistant")
        XCTAssertEqual(messages[2]["role"] as? String, "user")
        XCTAssertEqual(messages[2]["content"] as? String, firstPrompt)
        XCTAssertEqual(messages[3]["role"] as? String, "assistant")
        XCTAssertFalse((messages[3]["content"] as? String)?.isEmpty ?? true)
        XCTAssertEqual(messages[4]["role"] as? String, "user")
        XCTAssertEqual(messages[4]["content"] as? String, secondPrompt)
    }

    @MainActor
    func testMasterStage1AutomationWritesExactPreflightBlockerBeforeStage2SmokeSend() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("master-store-automation-stage2-preflight-\(UUID().uuidString)", isDirectory: true)
        let archiveURL = tempDirectory.appendingPathComponent("master-conversations.json", isDirectory: false)
        let stateStore = MasterConversationLocalStateStore(archiveURL: archiveURL)
        let resultURL = stateStore.resultFileURL
        let environmentKeys = [
            "SPARE_MASTERS_AUTOMATION_COMMAND",
            "SPARE_MASTERS_AUTOMATION_MASTER_ID",
            "SPARE_MASTERS_AUTOMATION_FIRST_PROMPT",
            "SPARE_MASTERS_AUTOMATION_SECOND_PROMPT",
            "SPARE_MASTERS_AUTOMATION_RESUME_PROMPT"
        ]
        defer {
            environmentKeys.forEach { unsetenv($0) }
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        setenv("SPARE_MASTERS_AUTOMATION_COMMAND", "stage2_smoke", 1)
        setenv("SPARE_MASTERS_AUTOMATION_MASTER_ID", "001546", 1)
        let expectedTotalMasterCount = try MasterCatalogLoader.load().masters.count
        let expectedVisibleMasterCount = min(expectedTotalMasterCount, 8)

        let blockedStatus = MasterConversationServiceStatus(
            providerName: "k2p5",
            modelName: "k2p5",
            credentialSource: .environmentFallback,
            deliveryMode: .localFallback,
            tone: .warning,
            title: "k2p5 预检未通过",
            detail: "已对 http://24.199.97.185:8080/v1/models 做 live `/v1/models` 预检，但还不能把会话记为已接通。阻塞：Live k2p5 smoke blocked before send: http://24.199.97.185:8080/v1/models [baseURL=legacy env(ANTHROPIC_BASE_URL)；apiKey=legacy env(ANTHROPIC_AUTH_TOKEN)；model=fallback(k2p5)] does not advertise 'k2p5'; available=claude-opus-4-6"
        )

        let store = MasterExperienceStore(
            catalogLoader: { try MasterCatalogLoader.load() },
            conversationService: FailingConversationService(),
            chatLiveStatusProbe: { blockedStatus },
            localStateStore: stateStore
        )

        let data = try await Self.waitForAutomationResult(at: resultURL)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(payload["command"] as? String, "stage2_smoke")
        XCTAssertEqual(payload["success"] as? Bool, false)
        XCTAssertEqual(payload["masterID"] as? String, "001546")
        XCTAssertEqual(payload["visibleMasterCount"] as? Int, expectedVisibleMasterCount)
        XCTAssertEqual(payload["totalMasterCount"] as? Int, expectedTotalMasterCount)
        XCTAssertEqual(payload["matchedCoverageCount"] as? Int, expectedTotalMasterCount)
        XCTAssertEqual(payload["hasExactStage1Coverage"] as? Bool, true)
        XCTAssertEqual(payload["serviceMode"] as? String, "localFallback")
        XCTAssertEqual(payload["serviceTitle"] as? String, "k2p5 预检未通过")
        XCTAssertTrue((payload["serviceDetail"] as? String)?.contains("does not advertise 'k2p5'") == true)
        XCTAssertTrue((payload["error"] as? String)?.contains("进入真实对话前的 k2p5 预检未通过") == true)
        XCTAssertNil(payload["sessionID"] as? String)
        XCTAssertNotNil(store)
    }

    @MainActor
    func testMasterStage1AutomationWritesInvalidAPIKeyPreflightBlockerBeforeStage2SmokeSend() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("master-store-automation-stage2-invalid-key-\(UUID().uuidString)", isDirectory: true)
        let archiveURL = tempDirectory.appendingPathComponent("master-conversations.json", isDirectory: false)
        let stateStore = MasterConversationLocalStateStore(archiveURL: archiveURL)
        let resultURL = stateStore.resultFileURL
        let suiteName = "master-chat-automation-invalid-key-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated user defaults suite")
            return
        }
        let environmentKeys = [
            "SPARE_MASTERS_AUTOMATION_COMMAND",
            "SPARE_MASTERS_AUTOMATION_MASTER_ID"
        ]
        defer {
            environmentKeys.forEach { unsetenv($0) }
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        setenv("SPARE_MASTERS_AUTOMATION_COMMAND", "stage2_smoke", 1)
        setenv("SPARE_MASTERS_AUTOMATION_MASTER_ID", "001546", 1)

        let probe = MasterExperienceStore.makeDefaultChatLiveStatusProbe(
            environment: [
                "ANTHROPIC_BASE_URL": "http://24.199.97.185:8080",
                "ANTHROPIC_AUTH_TOKEN": "legacy-invalid-token"
            ],
            userDefaults: defaults
        ) { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let payload = #"{"code":"INVALID_API_KEY","message":"Invalid API key"}"#
            return (payload.data(using: .utf8)!, response)
        }

        let store = MasterExperienceStore(
            catalogLoader: { try MasterCatalogLoader.load() },
            conversationService: FailingConversationService(),
            chatLiveStatusProbe: probe,
            localStateStore: stateStore
        )

        let data = try await Self.waitForAutomationResult(at: resultURL)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(payload["command"] as? String, "stage2_smoke")
        XCTAssertEqual(payload["success"] as? Bool, false)
        XCTAssertEqual(payload["masterID"] as? String, "001546")
        XCTAssertEqual(payload["serviceMode"] as? String, "localFallback")
        XCTAssertEqual(payload["serviceTitle"] as? String, "k2p5 鉴权失效")
        XCTAssertTrue((payload["serviceDetail"] as? String)?.contains("401") == true)
        XCTAssertTrue((payload["serviceDetail"] as? String)?.contains("INVALID_API_KEY") == true)
        XCTAssertTrue((payload["error"] as? String)?.contains("进入真实对话前的 k2p5 预检未通过") == true)
        XCTAssertNotNil(store)
    }

    @MainActor
    func testMasterStage1AutomationWritesResumeChatValidationAfterSeedChat() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("master-store-automation-resume-chat-\(UUID().uuidString)", isDirectory: true)
        let archiveURL = tempDirectory.appendingPathComponent("master-conversations.json", isDirectory: false)
        let stateStore = MasterConversationLocalStateStore(archiveURL: archiveURL)
        let resultURL = stateStore.resultFileURL
        let resumePrompt = "我准备把动作缩成一个实验了。恢复会话后，继续追问我最容易自欺的地方。"
        let environmentKeys = [
            "SPARE_MASTERS_AUTOMATION_COMMAND",
            "SPARE_MASTERS_AUTOMATION_MASTER_ID",
            "SPARE_MASTERS_AUTOMATION_FIRST_PROMPT",
            "SPARE_MASTERS_AUTOMATION_SECOND_PROMPT",
            "SPARE_MASTERS_AUTOMATION_RESUME_PROMPT"
        ]
        defer {
            environmentKeys.forEach { unsetenv($0) }
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        setenv("SPARE_MASTERS_AUTOMATION_COMMAND", "seed_chat", 1)
        setenv("SPARE_MASTERS_AUTOMATION_MASTER_ID", "001546", 1)

        let firstStore = MasterExperienceStore(
            catalogLoader: { try MasterCatalogLoader.load() },
            conversationService: makeAutomationLiveService(capture: ConversationRequestCapture()),
            localStateStore: stateStore
        )

        let seedData = try await Self.waitForAutomationResult(at: resultURL)
        let seedPayload = try XCTUnwrap(JSONSerialization.jsonObject(with: seedData) as? [String: Any])
        XCTAssertEqual(seedPayload["command"] as? String, "seed_chat")
        XCTAssertEqual(seedPayload["success"] as? Bool, true)
        XCTAssertEqual(seedPayload["transcriptCount"] as? Int, 5)
        XCTAssertNotNil(firstStore)

        try? FileManager.default.removeItem(at: resultURL)

        setenv("SPARE_MASTERS_AUTOMATION_COMMAND", "resume_chat", 1)
        setenv("SPARE_MASTERS_AUTOMATION_RESUME_PROMPT", resumePrompt, 1)

        let secondStore = MasterExperienceStore(
            catalogLoader: { try MasterCatalogLoader.load() },
            conversationService: makeAutomationLiveService(capture: ConversationRequestCapture()),
            localStateStore: stateStore
        )

        let resumeData = try await Self.waitForAutomationResult(at: resultURL)
        let resumePayload = try XCTUnwrap(JSONSerialization.jsonObject(with: resumeData) as? [String: Any])

        XCTAssertEqual(resumePayload["command"] as? String, "resume_chat")
        XCTAssertEqual(resumePayload["success"] as? Bool, true)
        XCTAssertEqual(resumePayload["masterID"] as? String, "001546")
        XCTAssertEqual(resumePayload["resumedTranscriptCount"] as? Int, 5)
        XCTAssertEqual(resumePayload["transcriptCount"] as? Int, 7)
        XCTAssertEqual(resumePayload["serviceMode"] as? String, "liveRemote")
        XCTAssertEqual(resumePayload["serviceTitle"] as? String, "实时对话已接通")
        XCTAssertNotNil(resumePayload["sessionID"] as? String)
        XCTAssertNil(resumePayload["error"] as? String)
        XCTAssertNotNil(secondStore)
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

        let liveSmoke: MasterChatLiveProbeCandidate
        do {
            liveSmoke = try MasterChatLiveProbe.resolveCandidate(
                environment: environment,
                userDefaults: defaults
            )
        } catch {
            throw XCTSkip(error.localizedDescription)
        }
        do {
            _ = try await MasterChatLiveProbe.ensureExpectedModelAdvertised(candidate: liveSmoke)
        } catch {
            throw XCTSkip(error.localizedDescription)
        }
        let configuration = liveSmoke.configuration
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

    @MainActor
    func testMasterExperienceStoreRefreshCatalogAppliesChatLiveProbeBlockerToEntryStatus() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("master-store-k2p5-preflight-blocked-\(UUID().uuidString)", isDirectory: true)
        let archiveURL = tempDirectory.appendingPathComponent("master-conversations.json", isDirectory: false)
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        let blockedStatus = MasterConversationServiceStatus(
            providerName: "k2p5",
            modelName: "k2p5",
            credentialSource: .environmentFallback,
            deliveryMode: .localFallback,
            tone: .warning,
            title: "k2p5 预检未通过",
            detail: "已对 http://24.199.97.185:8080/v1/models 做 live `/v1/models` 预检，但还不能把会话记为已接通。阻塞：Live k2p5 smoke blocked before send: http://24.199.97.185:8080/v1/models [baseURL=legacy env(ANTHROPIC_BASE_URL)；apiKey=legacy env(ANTHROPIC_AUTH_TOKEN)；model=fallback(k2p5)] does not advertise 'k2p5'; available=claude-opus-4-6"
        )
        let store = MasterExperienceStore(
            catalogLoader: { try MasterCatalogLoader.load() },
            conversationService: FailingConversationService(),
            chatLiveStatusProbe: { blockedStatus },
            localStateStore: MasterConversationLocalStateStore(archiveURL: archiveURL)
        )

        await store.refreshCatalog()

        XCTAssertEqual(store.conversationServiceStatus.title, "k2p5 预检未通过")
        XCTAssertFalse(store.conversationServiceStatus.isLiveRemote)
        XCTAssertTrue(store.conversationServiceStatus.detail.contains("does not advertise 'k2p5'"))

        let profile = try XCTUnwrap(store.visibleDirectoryMasters.first)
        store.openConversation(for: profile)

        XCTAssertEqual(store.conversation?.serviceStatus.title, "k2p5 预检未通过")
        XCTAssertTrue(store.conversation?.serviceStatus.detail.contains("does not advertise 'k2p5'") == true)
    }

    @MainActor
    func testMasterExperienceStoreRefreshCatalogAppliesChatLiveProbeCandidateToEntryStatus() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("master-store-k2p5-preflight-ready-\(UUID().uuidString)", isDirectory: true)
        let archiveURL = tempDirectory.appendingPathComponent("master-conversations.json", isDirectory: false)
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        let preflightReadyStatus = MasterConversationServiceStatus.candidate(
            modelName: "k2p5",
            credentialSource: .environmentFallback,
            detailOverride: "已对 https://chat.example.com/v1/models 做 live `/v1/models` 预检，确认端点广告 k2p5；available=k2p5 / claude-sonnet-4-6。目标 https://chat.example.com/v1/chat/completions。来源：baseURL=env(MASTER_CHAT_BASE_URL)；apiKey=env(MASTER_CHAT_API_KEY)；model=fallback(k2p5)。在收到首条真实远端回复前，只能视为 live 候选配置已注入。"
        )
        let store = MasterExperienceStore(
            catalogLoader: { try MasterCatalogLoader.load() },
            conversationService: FailingConversationService(),
            chatLiveStatusProbe: { preflightReadyStatus },
            localStateStore: MasterConversationLocalStateStore(archiveURL: archiveURL)
        )

        await store.refreshCatalog()

        XCTAssertEqual(store.conversationServiceStatus.title, "k2p5 live 候选已注入")
        XCTAssertFalse(store.conversationServiceStatus.isLiveRemote)
        XCTAssertTrue(store.conversationServiceStatus.isLiveCandidateConfigured)
        XCTAssertTrue(store.conversationServiceStatus.detail.contains("确认端点广告 k2p5"))

        let profile = try XCTUnwrap(store.visibleDirectoryMasters.first)
        store.openConversation(for: profile)

        XCTAssertEqual(store.conversation?.serviceStatus.title, "k2p5 live 候选已注入")
        XCTAssertTrue(store.conversation?.serviceStatus.isLiveCandidateConfigured == true)
        XCTAssertTrue(store.conversation?.serviceStatus.detail.contains("确认端点广告 k2p5") == true)
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

    @MainActor
    private func makeAutomationLiveService(
        capture: ConversationRequestCapture
    ) -> K2P5MasterConversationService {
        let configuration = MasterChatConfiguration(
            apiKey: "secret-token",
            credentialSource: .environmentFallback,
            chatCompletionsURL: URL(string: "https://chat.example.com/v1/chat/completions")!,
            model: "k2p5"
        )

        return K2P5MasterConversationService(configuration: configuration) { request in
            let turn = await capture.storeAndReturnCount(request)
            let reply: String
            switch turn {
            case 1:
                reply = "先把现金流收住，再把转岗动作压成七天内能拿到反馈的样本。"
            case 2:
                reply = "今天就去交付一个最小样本给真实用户，别再拿准备感冒充推进。"
            default:
                reply = "你最容易自欺的地方，就是继续优化准备动作，却不把样本暴露给真实反馈。"
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
