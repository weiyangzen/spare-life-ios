import Foundation
#if canImport(Security)
import Security
#endif

enum MasterCredentialSource: String, Hashable {
    case keychain
    case environmentFallback
    case unavailable

    var label: String {
        switch self {
        case .keychain:
            return "本机钥匙串"
        case .environmentFallback:
            return "本机环境变量"
        case .unavailable:
            return "未配置"
        }
    }
}

enum MasterConversationDeliveryMode: Hashable {
    case liveRemote
    case configuredCandidate
    case localFallback
}

enum MasterConversationStatusTone: Hashable {
    case success
    case ready
    case warning
}

struct MasterConversationServiceStatus: Hashable {
    let providerName: String
    let modelName: String?
    let credentialSource: MasterCredentialSource
    let deliveryMode: MasterConversationDeliveryMode
    let tone: MasterConversationStatusTone
    let title: String
    let detail: String

    var isLiveRemote: Bool {
        deliveryMode == .liveRemote
    }

    var isLiveCandidateConfigured: Bool {
        deliveryMode == .configuredCandidate
    }

    static func live(
        modelName: String,
        credentialSource: MasterCredentialSource,
        detailOverride: String? = nil
    ) -> MasterConversationServiceStatus {
        MasterConversationServiceStatus(
            providerName: modelName,
            modelName: modelName,
            credentialSource: credentialSource,
            deliveryMode: .liveRemote,
            tone: .success,
            title: "实时对话已接通",
            detail: detailOverride ??
                "回复走 \(modelName) / chat/completions，密钥只在本机 \(credentialSource.label) 读取，不写进页面配置或版本化文档。"
        )
    }

    static func candidate(
        modelName: String,
        credentialSource: MasterCredentialSource,
        detailOverride: String? = nil
    ) -> MasterConversationServiceStatus {
        MasterConversationServiceStatus(
            providerName: modelName,
            modelName: modelName,
            credentialSource: credentialSource,
            deliveryMode: .configuredCandidate,
            tone: .ready,
            title: "k2p5 live 候选已注入",
            detail: detailOverride ??
                "当前已注入 \(modelName) / chat/completions 候选配置，但尚未收到真实远端回复，不能把会话记为已接通。"
        )
    }

    static func fallback(detail: String) -> MasterConversationServiceStatus {
        MasterConversationServiceStatus(
            providerName: "本地故事引擎",
            modelName: nil,
            credentialSource: .unavailable,
            deliveryMode: .localFallback,
            tone: .warning,
            title: "当前使用本地故事引擎",
            detail: detail
        )
    }
}

struct MasterConversationRequest {
    let profile: MasterProfile
    let mode: MasterConversationMode
    let memoryScope: MasterMemoryScope
    let authorizedMemories: [MasterMemoryNote]
    let relevantStories: [MasterStory]
    let recentMessages: [MasterMessage]
}

struct MasterConversationServiceResult {
    let text: String
    let status: MasterConversationServiceStatus
}

@MainActor
protocol MasterConversationReplying: AnyObject {
    var status: MasterConversationServiceStatus { get }
    func generateReply(for request: MasterConversationRequest) async throws -> MasterConversationServiceResult
}

enum MasterConversationServiceError: LocalizedError, Equatable {
    case missingAPIKey
    case invalidBaseURL
    case emptyResponse
    case invalidResponse
    case invalidStatusCode(Int, String)
    case unexpectedModel(expected: String, actual: String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "未检测到大师对话密钥。请先在本机钥匙串或本机 `MASTER_CHAT_API_KEY` 环境变量里配置。"
        case .invalidBaseURL:
            return "大师对话服务地址无效。请检查本机 `MASTER_CHAT_BASE_URL` 配置。"
        case .emptyResponse:
            return "大师服务返回了空回复。"
        case .invalidResponse:
            return "大师服务返回了无法识别的响应。"
        case .invalidStatusCode(let code, let detail):
            let suffix = detail.isEmpty ? "" : " \(detail)"
            return "大师服务请求失败，状态码 \(code)。\(suffix)".trimmingCharacters(in: .whitespacesAndNewlines)
        case .unexpectedModel(let expected, let actual):
            return "大师服务返回的模型是 `\(actual)`，与当前 Stage 2 要求的 `\(expected)` 不一致。"
        case .transport(let detail):
            return detail.isEmpty ? "大师服务暂时不可用。" : detail
        }
    }
}

struct MasterChatConfiguration: Equatable, Sendable {
    let apiKey: String
    let credentialSource: MasterCredentialSource
    let chatCompletionsURL: URL
    let model: String

    static func current(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        userDefaults: UserDefaults = .standard,
        keychainAPIKey: () -> String? = { K2P5MasterConversationService.keychainAPIKey() },
        persistAPIKey: (String) -> Bool = { K2P5MasterConversationService.storeAPIKeyInKeychain($0) }
    ) throws -> MasterChatConfiguration {
        let resolution = resolved(
            environment: environment,
            userDefaults: userDefaults,
            keychainAPIKey: keychainAPIKey,
            persistAPIKey: persistAPIKey,
            allowPersistEnvironmentAPIKey: true
        )
        if let configuration = resolution.configuration {
            return configuration
        }
        throw resolution.error ?? .invalidBaseURL
    }

    static func currentStatus(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        userDefaults: UserDefaults = .standard,
        keychainAPIKey: () -> String? = { K2P5MasterConversationService.keychainAPIKey() },
        persistAPIKey: (String) -> Bool = { K2P5MasterConversationService.storeAPIKeyInKeychain($0) }
    ) -> MasterConversationServiceStatus {
        resolved(
            environment: environment,
            userDefaults: userDefaults,
            keychainAPIKey: keychainAPIKey,
            persistAPIKey: persistAPIKey,
            allowPersistEnvironmentAPIKey: false
        ).status
    }

    private static func resolveCredential(
        environment: [String: String],
        keychainAPIKey: () -> String?,
        persistAPIKey: (String) -> Bool,
        allowPersistEnvironmentAPIKey: Bool
    ) -> MasterChatResolvedCredential {
        if let apiKey = keychainAPIKey()?.trimmingCharacters(in: .whitespacesAndNewlines),
           !apiKey.isEmpty {
            return MasterChatResolvedCredential(
                value: apiKey,
                source: .keychain,
                detailSource: .keychain("\(K2P5MasterConversationService.keychainService)/\(K2P5MasterConversationService.keychainAccount)")
            )
        }

        if let environmentKey = environment["MASTER_CHAT_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !environmentKey.isEmpty {
            if allowPersistEnvironmentAPIKey,
               persistAPIKey(environmentKey),
               let persisted = keychainAPIKey()?.trimmingCharacters(in: .whitespacesAndNewlines),
               !persisted.isEmpty {
                return MasterChatResolvedCredential(
                    value: persisted,
                    source: .keychain,
                    detailSource: .keychain("\(K2P5MasterConversationService.keychainService)/\(K2P5MasterConversationService.keychainAccount)")
                )
            }
            return MasterChatResolvedCredential(
                value: environmentKey,
                source: .environmentFallback,
                detailSource: .environment("MASTER_CHAT_API_KEY")
            )
        }

        return MasterChatResolvedCredential(
            value: nil,
            source: .unavailable,
            detailSource: nil
        )
    }

    private static func resolvedValue(
        environment: [String: String],
        userDefaults: UserDefaults,
        environmentKey: String,
        defaultsKey: String
    ) -> MasterChatResolvedValue? {
        if let value = environment[environmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !value.isEmpty {
            return MasterChatResolvedValue(
                value: value,
                source: .environment(environmentKey)
            )
        }

        if let value = userDefaults.string(forKey: defaultsKey)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !value.isEmpty {
            return MasterChatResolvedValue(
                value: value,
                source: .userDefaults(defaultsKey)
            )
        }

        return nil
    }

    private static func resolved(
        environment: [String: String],
        userDefaults: UserDefaults,
        keychainAPIKey: () -> String?,
        persistAPIKey: (String) -> Bool,
        allowPersistEnvironmentAPIKey: Bool
    ) -> MasterChatConfigurationResolution {
        let credential = resolveCredential(
            environment: environment,
            keychainAPIKey: keychainAPIKey,
            persistAPIKey: persistAPIKey,
            allowPersistEnvironmentAPIKey: allowPersistEnvironmentAPIKey
        )
        let baseURL = resolvedValue(
            environment: environment,
            userDefaults: userDefaults,
            environmentKey: "MASTER_CHAT_BASE_URL",
            defaultsKey: "masters.chat.baseURL"
        )
        let model = resolvedValue(
            environment: environment,
            userDefaults: userDefaults,
            environmentKey: "MASTER_CHAT_MODEL",
            defaultsKey: "masters.chat.model"
        ) ?? MasterChatResolvedValue(
            value: K2P5MasterConversationService.modelFallback,
            source: .fallback(K2P5MasterConversationService.modelFallback)
        )

        let chatCompletionsURL = chatCompletionsURL(rawValue: baseURL?.value)
        let configuration: MasterChatConfiguration?
        let error: MasterConversationServiceError?
        if credential.value == nil {
            configuration = nil
            error = .missingAPIKey
        } else if baseURL == nil || chatCompletionsURL == nil {
            configuration = nil
            error = .invalidBaseURL
        } else {
            configuration = MasterChatConfiguration(
                apiKey: credential.value ?? "",
                credentialSource: credential.source,
                chatCompletionsURL: chatCompletionsURL!,
                model: model.value
            )
            error = nil
        }

        return MasterChatConfigurationResolution(
            configuration: configuration,
            error: error,
            baseURLSource: baseURL?.source,
            baseURLValue: baseURL?.value,
            modelSource: model.source,
            modelValue: model.value,
            apiKeySource: credential.detailSource,
            credentialSource: credential.source,
            legacyEnvironmentKeys: K2P5MasterConversationService.detectedLegacyEnvironmentKeys(in: environment)
        )
    }

    fileprivate static func chatCompletionsURL(rawValue: String?) -> URL? {
        guard let rawValue = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty,
              var url = URL(string: rawValue) else {
            return nil
        }

        let normalizedPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if normalizedPath.hasSuffix("v1/chat/completions") || normalizedPath.hasSuffix("chat/completions") {
            return url
        }
        if normalizedPath.hasSuffix("v1") {
            url.appendPathComponent("chat", isDirectory: true)
            url.appendPathComponent("completions", isDirectory: false)
            return url
        }

        url.appendPathComponent("v1", isDirectory: true)
        url.appendPathComponent("chat", isDirectory: true)
        url.appendPathComponent("completions", isDirectory: false)
        return url
    }
}

private struct MasterChatResolvedCredential {
    let value: String?
    let source: MasterCredentialSource
    let detailSource: MasterChatConfigSource?
}

private struct MasterChatResolvedValue {
    let value: String
    let source: MasterChatConfigSource
}

private enum MasterChatConfigSource: Hashable {
    case environment(String)
    case userDefaults(String)
    case keychain(String)
    case fallback(String)

    var summary: String {
        switch self {
        case .environment(let key):
            return "env(\(key))"
        case .userDefaults(let key):
            return "defaults(\(key))"
        case .keychain(let key):
            return "keychain(\(key))"
        case .fallback(let value):
            return "fallback(\(value))"
        }
    }
}

private struct MasterChatConfigurationResolution {
    let configuration: MasterChatConfiguration?
    let error: MasterConversationServiceError?
    let baseURLSource: MasterChatConfigSource?
    let baseURLValue: String?
    let modelSource: MasterChatConfigSource
    let modelValue: String
    let apiKeySource: MasterChatConfigSource?
    let credentialSource: MasterCredentialSource
    let legacyEnvironmentKeys: [String]

    var status: MasterConversationServiceStatus {
        if let configuration {
            return .candidate(
                modelName: configuration.model,
                credentialSource: configuration.credentialSource,
                detailOverride: "当前将请求 \(configuration.model) / chat/completions，目标 \(configuration.chatCompletionsURL.absoluteString)。来源：\(sourceAuditSummary)。但在收到首条真实远端回复前，只能视为 live 候选配置已注入。"
            )
        }

        if baseURLValue == nil {
            return MasterConversationServiceStatus(
                providerName: "本地故事引擎",
                modelName: nil,
                credentialSource: credentialSource,
                deliveryMode: .localFallback,
                tone: .warning,
                title: "k2p5 端点未注入",
                detail: "当前还没有拿到 Stage 2 大师闲聊的 live baseURL，不能把会话当成已接通 `k2p5`。\(endpointInjectionGuidance) \(modelInjectionGuidance) 来源：\(sourceAuditSummary)。\(legacyHint)"
            )
        }

        if error == .invalidBaseURL {
            return MasterConversationServiceStatus(
                providerName: "本地故事引擎",
                modelName: nil,
                credentialSource: credentialSource,
                deliveryMode: .localFallback,
                tone: .warning,
                title: "k2p5 地址无效",
                detail: "当前 `MASTER_CHAT_BASE_URL` 无法解析成可请求的 `/v1/chat/completions` 地址。\(endpointInjectionGuidance) 来源：\(sourceAuditSummary)。\(legacyHint)"
            )
        }

        return MasterConversationServiceStatus(
            providerName: "本地故事引擎",
            modelName: nil,
            credentialSource: credentialSource,
            deliveryMode: .localFallback,
            tone: .warning,
            title: "k2p5 鉴权未配置",
            detail: "当前会请求 \(resolvedEndpointSummary)，但还缺少可发送的 API key。\(authInjectionGuidance) \(modelInjectionGuidance) 来源：\(sourceAuditSummary)。\(legacyHint)"
        )
    }

    private var resolvedEndpointSummary: String {
        if let configuration {
            return configuration.chatCompletionsURL.absoluteString
        }
        if let rawBaseURL = baseURLValue,
           let url = MasterChatConfiguration.chatCompletionsURL(rawValue: rawBaseURL) {
            return url.absoluteString
        }
        return "未解析"
    }

    private var endpointInjectionGuidance: String {
        "可通过 env(MASTER_CHAT_BASE_URL) 或 defaults(masters.chat.baseURL) 注入。"
    }

    private var authInjectionGuidance: String {
        "可通过 env(MASTER_CHAT_API_KEY) 或本机钥匙串 `\(K2P5MasterConversationService.keychainService)` / `\(K2P5MasterConversationService.keychainAccount)` 注入。"
    }

    private var modelInjectionGuidance: String {
        "模型可通过 env(MASTER_CHAT_MODEL) 或 defaults(masters.chat.model) 覆盖，默认 `\(K2P5MasterConversationService.modelFallback)`。"
    }

    private var legacyHint: String {
        guard !legacyEnvironmentKeys.isEmpty else { return "" }
        return "当前 shell 只检测到 legacy `ANTHROPIC_*` 配置（\(legacyEnvironmentKeys.joined(separator: ", "))）；Stage 2 的 `k2p5` 链路仍只认 `MASTER_CHAT_*`。"
    }

    private var sourceAuditSummary: String {
        [
            "baseURL=\(baseURLSource?.summary ?? "未注入")",
            "model=\(modelSource.summary)",
            "apiKey=\(apiKeySource?.summary ?? "未注入")"
        ].joined(separator: "；")
    }
}

typealias MasterConversationTransport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

@MainActor
final class K2P5MasterConversationService: MasterConversationReplying {
    nonisolated static let keychainService = "com.wangweiyang.sparelife.masters.chat"
    nonisolated static let keychainAccount = "k2p5.api-key"
    nonisolated static let modelFallback = "k2p5"

    private let resolveConfiguration: () throws -> MasterChatConfiguration
    private let resolveStatus: () -> MasterConversationServiceStatus
    private let transport: MasterConversationTransport
    private let processInfo: ProcessInfo

    init(
        session: URLSession = .shared,
        processInfo: ProcessInfo = .processInfo,
        userDefaults: UserDefaults = .standard
    ) {
        self.resolveConfiguration = {
            try MasterChatConfiguration.current(
                environment: processInfo.environment,
                userDefaults: userDefaults
            )
        }
        self.resolveStatus = {
            MasterChatConfiguration.currentStatus(
                environment: processInfo.environment,
                userDefaults: userDefaults
            )
        }
        self.transport = { request in
            try await session.data(for: request)
        }
        self.processInfo = processInfo
    }

    init(
        configuration: MasterChatConfiguration,
        transport: @escaping MasterConversationTransport
    ) {
        self.resolveConfiguration = { configuration }
        self.resolveStatus = {
            .candidate(
                modelName: configuration.model,
                credentialSource: configuration.credentialSource,
                detailOverride: "当前将请求 \(configuration.model) / chat/completions，目标 \(configuration.chatCompletionsURL.absoluteString)。来源：baseURL=显式配置；model=显式配置；apiKey=\(configuration.credentialSource.label)。但在收到首条真实远端回复前，只能视为 live 候选配置已注入。"
            )
        }
        self.transport = transport
        self.processInfo = .processInfo
    }

    var status: MasterConversationServiceStatus {
        resolveStatus()
    }

    func generateReply(for request: MasterConversationRequest) async throws -> MasterConversationServiceResult {
        let configuration = try resolveConfiguration()
        var urlRequest = URLRequest(url: configuration.chatCompletionsURL)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 60
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(
            OpenAIChatCompletionsRequest(
                model: configuration.model,
                maxTokens: 700,
                messages: buildMessages(for: request)
            )
        )

        do {
            let (data, response) = try await transport(urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw MasterConversationServiceError.invalidResponse
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                throw Self.decodeError(data: data, statusCode: httpResponse.statusCode)
            }

            guard let text = Self.extractText(from: data) else {
                throw MasterConversationServiceError.emptyResponse
            }

            let resolvedModelName = Self.extractModelName(from: data) ?? configuration.model
            try Self.validateReturnedModel(resolvedModelName, expected: configuration.model)
            let styledText = MasterRoleplayReplyComposer.remoteReply(from: text, for: request)

            return MasterConversationServiceResult(
                text: styledText,
                status: .live(
                    modelName: resolvedModelName,
                    credentialSource: configuration.credentialSource
                )
            )
        } catch let error as MasterConversationServiceError {
            throw error
        } catch {
            throw MasterConversationServiceError.transport(error.localizedDescription)
        }
    }

    private func buildSystemPrompt(for request: MasterConversationRequest) -> String {
        let profile = request.profile
        let memorySummary = request.authorizedMemories.isEmpty
            ? "当前没有可用的长期记忆授权，只根据本轮对话和最近消息继续。"
            : request.authorizedMemories
                .map { "- \($0.label)：\($0.summary)（范围：\($0.scope.rawValue)）" }
                .joined(separator: "\n")
        let storySummary = request.relevantStories.isEmpty
            ? "当前问题没有命中特别相关的固定故事，请按人设直接回应。"
            : request.relevantStories.map { story in
                let beats = story.beats.prefix(3).joined(separator: "；")
                return "- \(story.title)：\(story.summary)\n  关键片段：\(beats)"
            }
            .joined(separator: "\n")

        return """
        你是 Spare Life iOS 里的大师分身，不要暴露自己是模型、系统提示或服务配置。
        你必须稳定扮演这位大师，只能使用已导入的人设、故事和用户授权记忆，不得捏造未导入的生平。

        大师档案：
        - 姓名：\(profile.displayName)
        - 头衔：\(profile.title)
        - 领域：\(profile.domainTitle)
        - 一句话：\(profile.tagline)
        - 说话风格：\(profile.voice)
        - 建议风格：\(profile.adviceStyle)
        - 决策风格：\(profile.decisionStyle)
        - 风险偏好：\(profile.riskAppetite)
        - 擅长：\(profile.expertiseTags.joined(separator: "、"))
        - 聚焦：\(profile.focusTags.joined(separator: "、"))
        - 边界：\(profile.boundaries.joined(separator: "；"))

        会话模式：
        \(modeInstruction(for: request.mode))

        记忆范围：
        - 当前授权范围：\(request.memoryScope.rawValue)
        - 记忆说明：\(memoryScopeInstruction(for: request.memoryScope))

        已授权记忆：
        \(memorySummary)

        本轮最相关的人生故事证据：
        \(storySummary)

        回复要求：
        - 用简体中文回复，把这轮输出写成小说场景里这位角色当面对用户说出的台词，默认保持 2-4 句连贯对白。
        - 先承接用户这轮问题和最近上下文，再给判断或陪伴，不要忽略连续性。
        - 如果合适，可以自然提到相关故事，但不要像数据库检索结果。
        - 如果用户问题超出你的边界，要直接收敛并说明原因，不要装懂。
        - 尽量给出一个当下可执行的下一步，或一个能推进澄清的追问。
        - 禁止出现“作为 AI / 模型 / 助手”“建议如下”“首先 / 其次 / 最后”“1. 2. 3.” 这类通用助手口吻。
        - 不要解释你的回复策略，也不要复述“说话风格 / 建议风格 / 决策风格”等字段名。
        - 除非用户明确要求，否则不要输出项目符号清单，也不要冗长说教。
        """
    }

    private func buildMessages(for request: MasterConversationRequest) -> [OpenAIChatCompletionsRequest.Message] {
        let transcript = request.recentMessages
            .filter { $0.role != .system }
            .map { message in
                OpenAIChatCompletionsRequest.Message(
                    role: message.role == .user ? "user" : "assistant",
                    content: message.text
                )
            }

        return [
            OpenAIChatCompletionsRequest.Message(
                role: "system",
                content: buildSystemPrompt(for: request)
            )
        ] + transcript
    }

    private func modeInstruction(for mode: MasterConversationMode) -> String {
        switch mode {
        case .storyFirst:
            return "优先先用相关人生故事建立可信感，再落到判断和行动。"
        case .adviceFirst:
            return "优先先给明确结论，再补故事、边界和原因。"
        case .companion:
            return "优先稳住情绪和关系感受，减少命令式语气。"
        case .mentor:
            return "优先拉回行动节奏，直接指出推进上的松动与下一步。"
        }
    }

    private func memoryScopeInstruction(for scope: MasterMemoryScope) -> String {
        switch scope {
        case .sessionOnly:
            return "不要假设有长期记忆，只能使用当前会话。"
        case .masterOnly:
            return "只把记忆当作当前这位大师可见的长期上下文。"
        case .crossMaster:
            return "只把必要记忆当作会诊共享上下文，不要扩展隐私范围。"
        }
    }

    nonisolated fileprivate static func detectedLegacyEnvironmentKeys(in environment: [String: String]) -> [String] {
        let legacyKeys = [
            "ANTHROPIC_HOST",
            "ANTHROPIC_BASE_URL",
            "ANTHROPIC_API_KEY",
            "ANTHROPIC_AUTH_TOKEN",
            "ANTHROPIC_DEFAULT_OPUS_MODEL",
            "ANTHROPIC_DEFAULT_SONNET_MODEL"
        ]
        return legacyKeys.filter { key in
            environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty != nil
        }
    }

    private static func decodeError(data: Data, statusCode: Int) -> MasterConversationServiceError {
        if let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = payload["error"] as? [String: Any],
               let message = error["message"] as? String {
                return .invalidStatusCode(statusCode, message.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            if let message = payload["message"] as? String {
                return .invalidStatusCode(statusCode, message.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        let fallback = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return .invalidStatusCode(statusCode, fallback)
    }

    private static func extractText(from data: Data) -> String? {
        guard let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let choices = payload["choices"] as? [[String: Any]] {
            for choice in choices {
                if let message = choice["message"] as? [String: Any],
                   let text = extractContent(from: message["content"]) {
                    return text
                }
                if let text = extractContent(from: choice["text"]) {
                    return text
                }
            }
        }

        if let message = payload["message"] as? [String: Any],
           let text = extractContent(from: message["content"]) {
            return text
        }

        return nil
    }

    private static func extractContent(from value: Any?) -> String? {
        switch value {
        case let text as String:
            return text.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        case let part as [String: Any]:
            let candidate = (part["text"] as? String) ?? (part["content"] as? String)
            return candidate?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        case let parts as [[String: Any]]:
            let text = parts
                .compactMap { part in
                    ((part["text"] as? String) ?? (part["content"] as? String))?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .nonEmpty
                }
                .joined(separator: "\n\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return text.nonEmpty
        default:
            return nil
        }
    }

    private static func extractModelName(from data: Data) -> String? {
        guard let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let model = payload["model"] as? String else {
            return nil
        }
        return model.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    private static func validateReturnedModel(
        _ actualModel: String,
        expected expectedModel: String
    ) throws {
        guard normalizedModelSignature(actualModel) == normalizedModelSignature(expectedModel) else {
            throw MasterConversationServiceError.unexpectedModel(
                expected: expectedModel,
                actual: actualModel
            )
        }
    }

    private static func normalizedModelSignature(_ rawValue: String) -> String {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if normalized.contains(K2P5MasterConversationService.modelFallback) {
            return K2P5MasterConversationService.modelFallback
        }
        return normalized
    }

    nonisolated static func keychainAPIKey() -> String? {
        #if canImport(Security)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
        #else
        return nil
        #endif
    }

    @discardableResult
    nonisolated static func storeAPIKeyInKeychain(_ value: String) -> Bool {
        #if canImport(Security)
        let encoded = Data(value.utf8)
        let baseQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount
        ]

        let addQuery = baseQuery.merging([
            kSecValueData: encoded,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]) { _, new in new }

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecSuccess {
            return true
        }

        guard addStatus == errSecDuplicateItem else {
            return false
        }

        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData: encoded] as CFDictionary
        )
        return updateStatus == errSecSuccess
        #else
        return false
        #endif
    }
}

private struct OpenAIChatCompletionsRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let maxTokens: Int
    let messages: [Message]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
