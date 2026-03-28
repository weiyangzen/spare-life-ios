import Foundation

struct MasterChatLiveProbeCandidate: Equatable, Sendable {
    let configuration: MasterChatConfiguration
    let sourceSummary: String
}

enum MasterChatLiveProbeError: LocalizedError, Equatable {
    case missingBaseURL
    case missingAPIKey
    case nonHTTPResponse(url: String, sourceSummary: String)
    case invalidStatusCode(url: String, sourceSummary: String, statusCode: Int, detail: String)
    case transport(url: String, sourceSummary: String, detail: String)
    case modelNotAdvertised(url: String, sourceSummary: String, expectedModel: String, availableModels: [String])

    var errorDescription: String? {
        switch self {
        case .missingBaseURL:
            return "Live k2p5 smoke blocked before send: missing MASTER_CHAT_BASE_URL, defaults(masters.chat.baseURL), and no legacy ANTHROPIC_BASE_URL / ANTHROPIC_HOST is available."
        case .missingAPIKey:
            return "Live k2p5 smoke blocked before send: missing MASTER_CHAT_API_KEY, keychain(\(K2P5MasterConversationService.keychainService)/\(K2P5MasterConversationService.keychainAccount)), and no legacy ANTHROPIC_AUTH_TOKEN / ANTHROPIC_API_KEY is available."
        case .nonHTTPResponse(let url, let sourceSummary):
            return "Live k2p5 smoke blocked before send: \(url) [\(sourceSummary)] returned a non-HTTP response."
        case .invalidStatusCode(let url, let sourceSummary, let statusCode, let detail):
            let suffix = detail.isEmpty ? "" : " \(detail)"
            return "Live k2p5 smoke blocked before send: \(url) [\(sourceSummary)] returned \(statusCode).\(suffix)"
        case .transport(let url, let sourceSummary, let detail):
            let suffix = detail.isEmpty ? "Unknown transport error." : detail
            return "Live k2p5 smoke blocked before send: failed to probe \(url) [\(sourceSummary)]. \(suffix)"
        case .modelNotAdvertised(let url, let sourceSummary, let expectedModel, let availableModels):
            return "Live k2p5 smoke blocked before send: \(url) [\(sourceSummary)] does not advertise '\(expectedModel)'; available=\(availableModels.joined(separator: ", "))"
        }
    }
}

enum MasterChatLiveProbe {
    static func resolveCandidate(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        userDefaults: UserDefaults = .standard,
        keychainAPIKey: () -> String? = { K2P5MasterConversationService.keychainAPIKey() }
    ) throws -> MasterChatLiveProbeCandidate {
        var resolvedEnvironment = environment

        let keychainValue = trimmedValue(keychainAPIKey())

        let baseURLSource: String
        if let baseURL = trimmedEnvironmentValue("MASTER_CHAT_BASE_URL", in: environment) {
            resolvedEnvironment["MASTER_CHAT_BASE_URL"] = baseURL
            baseURLSource = "env(MASTER_CHAT_BASE_URL)"
        } else if let baseURL = trimmedDefaultsValue("masters.chat.baseURL", in: userDefaults) {
            resolvedEnvironment["MASTER_CHAT_BASE_URL"] = baseURL
            baseURLSource = "defaults(masters.chat.baseURL)"
        } else if let legacyBaseURL = trimmedEnvironmentValue("ANTHROPIC_BASE_URL", in: environment) {
            resolvedEnvironment["MASTER_CHAT_BASE_URL"] = legacyBaseURL
            baseURLSource = "legacy env(ANTHROPIC_BASE_URL)"
        } else if let legacyHost = trimmedEnvironmentValue("ANTHROPIC_HOST", in: environment) {
            resolvedEnvironment["MASTER_CHAT_BASE_URL"] = legacyHost
            baseURLSource = "legacy env(ANTHROPIC_HOST)"
        } else {
            throw MasterChatLiveProbeError.missingBaseURL
        }

        let apiKeySource: String
        if let keychainValue {
            resolvedEnvironment["MASTER_CHAT_API_KEY"] = keychainValue
            apiKeySource = "keychain(\(K2P5MasterConversationService.keychainService)/\(K2P5MasterConversationService.keychainAccount))"
        } else if let apiKey = trimmedEnvironmentValue("MASTER_CHAT_API_KEY", in: environment) {
            resolvedEnvironment["MASTER_CHAT_API_KEY"] = apiKey
            apiKeySource = "env(MASTER_CHAT_API_KEY)"
        } else if let legacyAuthToken = trimmedEnvironmentValue("ANTHROPIC_AUTH_TOKEN", in: environment) {
            resolvedEnvironment["MASTER_CHAT_API_KEY"] = legacyAuthToken
            apiKeySource = "legacy env(ANTHROPIC_AUTH_TOKEN)"
        } else if let legacyAPIKey = trimmedEnvironmentValue("ANTHROPIC_API_KEY", in: environment) {
            resolvedEnvironment["MASTER_CHAT_API_KEY"] = legacyAPIKey
            apiKeySource = "legacy env(ANTHROPIC_API_KEY)"
        } else {
            throw MasterChatLiveProbeError.missingAPIKey
        }

        let modelSource: String
        if let model = trimmedEnvironmentValue("MASTER_CHAT_MODEL", in: environment) {
            resolvedEnvironment["MASTER_CHAT_MODEL"] = model
            modelSource = "env(MASTER_CHAT_MODEL)"
        } else if let model = trimmedDefaultsValue("masters.chat.model", in: userDefaults) {
            resolvedEnvironment["MASTER_CHAT_MODEL"] = model
            modelSource = "defaults(masters.chat.model)"
        } else {
            resolvedEnvironment["MASTER_CHAT_MODEL"] = K2P5MasterConversationService.modelFallback
            modelSource = "fallback(\(K2P5MasterConversationService.modelFallback))"
        }

        let configuration = try MasterChatConfiguration.current(
            environment: resolvedEnvironment,
            userDefaults: userDefaults,
            keychainAPIKey: { keychainValue },
            persistAPIKey: { _ in false }
        )

        return MasterChatLiveProbeCandidate(
            configuration: configuration,
            sourceSummary: "baseURL=\(baseURLSource)；apiKey=\(apiKeySource)；model=\(modelSource)"
        )
    }

    static func modelCatalogURL(for chatCompletionsURL: URL) -> URL {
        chatCompletionsURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("models")
    }

    static func preflightAvailableModels(
        candidate: MasterChatLiveProbeCandidate,
        transport: @escaping MasterConversationTransport = { request in
            try await URLSession.shared.data(for: request)
        }
    ) async throws -> [String] {
        let catalogURL = modelCatalogURL(for: candidate.configuration.chatCompletionsURL)
        var request = URLRequest(url: catalogURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("Bearer \(candidate.configuration.apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await transport(request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw MasterChatLiveProbeError.nonHTTPResponse(
                    url: catalogURL.absoluteString,
                    sourceSummary: candidate.sourceSummary
                )
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                let detail = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                throw MasterChatLiveProbeError.invalidStatusCode(
                    url: catalogURL.absoluteString,
                    sourceSummary: candidate.sourceSummary,
                    statusCode: httpResponse.statusCode,
                    detail: detail
                )
            }

            let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let models = (payload?["data"] as? [[String: Any]])?
                .compactMap { entry in
                    trimmedValue(entry["id"] as? String)
                } ?? []
            return models
        } catch let error as MasterChatLiveProbeError {
            throw error
        } catch {
            throw MasterChatLiveProbeError.transport(
                url: catalogURL.absoluteString,
                sourceSummary: candidate.sourceSummary,
                detail: error.localizedDescription
            )
        }
    }

    static func ensureExpectedModelAdvertised(
        candidate: MasterChatLiveProbeCandidate,
        transport: @escaping MasterConversationTransport = { request in
            try await URLSession.shared.data(for: request)
        }
    ) async throws -> [String] {
        let availableModels = try await preflightAvailableModels(
            candidate: candidate,
            transport: transport
        )
        guard availableModels.contains(candidate.configuration.model) else {
            throw MasterChatLiveProbeError.modelNotAdvertised(
                url: modelCatalogURL(for: candidate.configuration.chatCompletionsURL).absoluteString,
                sourceSummary: candidate.sourceSummary,
                expectedModel: candidate.configuration.model,
                availableModels: availableModels
            )
        }
        return availableModels
    }

    private static func trimmedEnvironmentValue(
        _ key: String,
        in environment: [String: String]
    ) -> String? {
        trimmedValue(environment[key])
    }

    private static func trimmedDefaultsValue(
        _ key: String,
        in userDefaults: UserDefaults
    ) -> String? {
        trimmedValue(userDefaults.string(forKey: key))
    }

    private static func trimmedValue(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
