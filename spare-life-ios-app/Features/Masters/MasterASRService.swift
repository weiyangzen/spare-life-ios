import Foundation

protocol MasterAudioTranscribing: Sendable {
    func transcribeAudio(at fileURL: URL) async throws -> String
}

enum MasterASRServiceError: LocalizedError, Equatable {
    case invalidBaseURL
    case unreadableAudio(String)
    case emptyResponse
    case invalidResponse
    case invalidStatusCode(Int, String)
    case methodNotAllowed(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "ASR 服务地址无效。请检查本机 `MASTER_ASR_URL` 或 `MASTER_ASR_BASE_URL` 配置。"
        case .unreadableAudio(let detail):
            return detail.isEmpty ? "当前音频文件不可读。" : detail
        case .emptyResponse:
            return "ASR 服务返回了空文本。"
        case .invalidResponse:
            return "ASR 服务返回了无法识别的响应。"
        case .invalidStatusCode(let code, let detail):
            let suffix = detail.isEmpty ? "" : " \(detail)"
            return "ASR 服务请求失败，状态码 \(code)。\(suffix)".trimmingCharacters(in: .whitespacesAndNewlines)
        case .methodNotAllowed(let detail):
            let suffix = detail.isEmpty ? "" : " \(detail)"
            return "当前 ASR 路由返回 405，尚不能确认真实写入入口。\(suffix)".trimmingCharacters(in: .whitespacesAndNewlines)
        case .transport(let detail):
            return detail.isEmpty ? "ASR 服务暂时不可用。" : detail
        }
    }
}

struct MasterASRConfiguration: Equatable, Sendable {
    let url: URL
    let method: String
    let authHeaderName: String?
    let authScheme: String?
    let apiKey: String?
    let model: String?
    let language: String?
    let responseFormat: String?

    static func current(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        userDefaults: UserDefaults = .standard
    ) throws -> MasterASRConfiguration {
        try resolved(environment: environment, userDefaults: userDefaults).configuration
    }

    static func currentStatus(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        userDefaults: UserDefaults = .standard
    ) -> MasterASRConnectionStatus {
        do {
            return try resolved(environment: environment, userDefaults: userDefaults).status
        } catch {
            return MasterASRConnectionStatus(
                tone: .warning,
                title: "ASR 地址无效",
                detail: error.localizedDescription
            )
        }
    }

    private static func resolvedValue(
        environment: [String: String],
        userDefaults: UserDefaults,
        environmentKeys: [String],
        defaultsKeys: [String]
    ) -> MasterASRResolvedValue? {
        for key in environmentKeys {
            if let value = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
                return MasterASRResolvedValue(
                    value: value,
                    source: .environment(key)
                )
            }
        }
        for key in defaultsKeys {
            if let value = userDefaults.string(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
                return MasterASRResolvedValue(
                    value: value,
                    source: .userDefaults(key)
                )
            }
        }
        return nil
    }

    fileprivate static func normalizedURL(rawURL: String?, baseURL: String, path: String) -> URL? {
        if let rawURL = rawURL?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
            return URL(string: rawURL)
        }

        guard var url = URL(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }

        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            return url
        }

        if let directURL = URL(string: trimmedPath), directURL.scheme != nil {
            return directURL
        }

        let normalizedPath = trimmedPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !normalizedPath.isEmpty else {
            return url
        }

        for component in normalizedPath.split(separator: "/") {
            url.appendPathComponent(String(component), isDirectory: false)
        }
        return url
    }

    private static func resolved(
        environment: [String: String],
        userDefaults: UserDefaults
    ) throws -> MasterASRConfigurationResolution {
        let rawURL = resolvedValue(
            environment: environment,
            userDefaults: userDefaults,
            environmentKeys: ["MASTER_ASR_URL"],
            defaultsKeys: ["masters.asr.url"]
        )
        let configuredBaseURL = resolvedValue(
            environment: environment,
            userDefaults: userDefaults,
            environmentKeys: ["MASTER_ASR_BASE_URL"],
            defaultsKeys: ["masters.asr.baseURL"]
        )
        let configuredPath = resolvedValue(
            environment: environment,
            userDefaults: userDefaults,
            environmentKeys: ["MASTER_ASR_PATH"],
            defaultsKeys: ["masters.asr.path"]
        )
        let configuredMethod = resolvedValue(
            environment: environment,
            userDefaults: userDefaults,
            environmentKeys: ["MASTER_ASR_METHOD"],
            defaultsKeys: ["masters.asr.method"]
        )
        let authHeaderName = resolvedValue(
            environment: environment,
            userDefaults: userDefaults,
            environmentKeys: ["MASTER_ASR_AUTH_HEADER"],
            defaultsKeys: ["masters.asr.authHeader"]
        )
        let authScheme = resolvedValue(
            environment: environment,
            userDefaults: userDefaults,
            environmentKeys: ["MASTER_ASR_AUTH_SCHEME"],
            defaultsKeys: ["masters.asr.authScheme"]
        )
        let apiKey = resolvedValue(
            environment: environment,
            userDefaults: userDefaults,
            environmentKeys: ["MASTER_ASR_API_KEY", "MASTER_ASR_AUTH_TOKEN"],
            defaultsKeys: ["masters.asr.apiKey", "masters.asr.authToken"]
        )
        let model = resolvedValue(
            environment: environment,
            userDefaults: userDefaults,
            environmentKeys: ["MASTER_ASR_MODEL"],
            defaultsKeys: ["masters.asr.model"]
        )?.value ?? "whisper-1"
        let language = resolvedValue(
            environment: environment,
            userDefaults: userDefaults,
            environmentKeys: ["MASTER_ASR_LANGUAGE"],
            defaultsKeys: ["masters.asr.language"]
        )?.value
        let responseFormat = resolvedValue(
            environment: environment,
            userDefaults: userDefaults,
            environmentKeys: ["MASTER_ASR_RESPONSE_FORMAT"],
            defaultsKeys: ["masters.asr.responseFormat"]
        )?.value

        let baseURL = configuredBaseURL?.value ?? MasterASRConfigurationResolution.defaultBaseURL
        let path = configuredPath?.value ?? MasterASRConfigurationResolution.defaultPath
        guard let url = normalizedURL(rawURL: rawURL?.value, baseURL: baseURL, path: path) else {
            throw MasterASRServiceError.invalidBaseURL
        }

        let configuration = MasterASRConfiguration(
            url: url,
            method: (configuredMethod?.value ?? MasterASRConfigurationResolution.defaultMethod)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased(),
            authHeaderName: authHeaderName?.value,
            authScheme: authScheme?.value,
            apiKey: apiKey?.value,
            model: model.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
            language: language?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
            responseFormat: responseFormat?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        )

        return MasterASRConfigurationResolution(
            configuration: configuration,
            hasExplicitEndpointOverride: rawURL != nil || configuredBaseURL != nil || configuredPath != nil || configuredMethod != nil,
            hasAuthHeader: authHeaderName?.value.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty != nil,
            hasAPIKey: apiKey?.value.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty != nil,
            rawURLSource: rawURL?.source,
            baseURLSource: configuredBaseURL?.source,
            pathSource: configuredPath?.source,
            methodSource: configuredMethod?.source,
            authHeaderSource: authHeaderName?.source,
            authSchemeSource: authScheme?.source,
            apiKeySource: apiKey?.source
        )
    }
}

enum MasterASRConnectionTone: Equatable, Sendable {
    case ready
    case warning
}

struct MasterASRConnectionStatus: Equatable, Sendable {
    let tone: MasterASRConnectionTone
    let title: String
    let detail: String
}

private struct MasterASRConfigurationResolution: Equatable, Sendable {
    static let defaultBaseURL = "http://100.82.60.69:17880"
    static let defaultPath = "/v1/audio/transcriptions"
    static let defaultMethod = "POST"
    static let endpointEnvironmentKeys = ["MASTER_ASR_URL", "MASTER_ASR_BASE_URL", "MASTER_ASR_PATH", "MASTER_ASR_METHOD"]
    static let endpointDefaultsKeys = ["masters.asr.url", "masters.asr.baseURL", "masters.asr.path", "masters.asr.method"]
    static let authEnvironmentKeys = ["MASTER_ASR_AUTH_HEADER", "MASTER_ASR_AUTH_SCHEME", "MASTER_ASR_API_KEY", "MASTER_ASR_AUTH_TOKEN"]
    static let authDefaultsKeys = ["masters.asr.authHeader", "masters.asr.authScheme", "masters.asr.apiKey", "masters.asr.authToken"]

    let configuration: MasterASRConfiguration
    let hasExplicitEndpointOverride: Bool
    let hasAuthHeader: Bool
    let hasAPIKey: Bool
    let rawURLSource: MasterASRConfigSource?
    let baseURLSource: MasterASRConfigSource?
    let pathSource: MasterASRConfigSource?
    let methodSource: MasterASRConfigSource?
    let authHeaderSource: MasterASRConfigSource?
    let authSchemeSource: MasterASRConfigSource?
    let apiKeySource: MasterASRConfigSource?

    var status: MasterASRConnectionStatus {
        if usesDefaultProbeRoute {
            return MasterASRConnectionStatus(
                tone: .warning,
                title: "ASR 仍在探测路由",
                detail: "当前仍会请求 \(endpointSummary)。仓内还没有 ClawDB live 的 host / path / method。\(endpointInjectionGuidance) 来源：\(sourceAuditSummary)."
            )
        }

        if !hasExplicitEndpointOverride {
            return MasterASRConnectionStatus(
                tone: .warning,
                title: "ASR live 端点未注入",
                detail: "当前没有拿到 live 端点覆盖配置，不能把客户端当成已接通 ClawDB live ASR。\(endpointInjectionGuidance) 来源：\(sourceAuditSummary)."
            )
        }

        if !hasAuthHeader || !hasAPIKey {
            return MasterASRConnectionStatus(
                tone: .warning,
                title: "ASR 鉴权尚未补齐",
                detail: "当前会请求 \(endpointSummary)，但还缺少可发送的鉴权头或密钥。\(authInjectionGuidance) 来源：\(sourceAuditSummary)。ClawDB live 联调前不能诚实勾选 ASR 主项。"
            )
        }

        return MasterASRConnectionStatus(
            tone: .ready,
            title: "ASR live 候选配置已注入",
            detail: "当前会请求 \(endpointSummary)，并携带 \(authHeaderSummary)。来源：\(sourceAuditSummary)。客户端已具备 live 联调接缝，但端点是否可用仍需真实服务验证。"
        )
    }

    private var usesDefaultProbeRoute: Bool {
        configuration.method == Self.defaultMethod && configuration.url.absoluteString == defaultProbeURL.absoluteString
    }

    private var defaultProbeURL: URL {
        MasterASRConfiguration.normalizedURL(
            rawURL: nil,
            baseURL: Self.defaultBaseURL,
            path: Self.defaultPath
        ) ?? URL(string: "\(Self.defaultBaseURL)\(Self.defaultPath)")!
    }

    private var endpointSummary: String {
        "\(configuration.method) \(configuration.url.absoluteString)"
    }

    private var authHeaderSummary: String {
        let headerName = configuration.authHeaderName?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "鉴权头"
        guard let scheme = configuration.authScheme?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty else {
            return "\(headerName) 头"
        }
        return "\(headerName) 头（scheme: \(scheme)）"
    }

    private var endpointInjectionGuidance: String {
        "可通过 env(\(Self.endpointEnvironmentKeys.joined(separator: " / "))) 或 defaults(\(Self.endpointDefaultsKeys.joined(separator: " / "))) 注入"
    }

    private var authInjectionGuidance: String {
        "可通过 env(\(Self.authEnvironmentKeys.joined(separator: " / "))) 或 defaults(\(Self.authDefaultsKeys.joined(separator: " / "))) 注入"
    }

    private var sourceAuditSummary: String {
        [
            endpointSourceSummary,
            authSourceSummary
        ].joined(separator: "；")
    }

    private var endpointSourceSummary: String {
        if let rawURLSource {
            return "endpoint=\(rawURLSource.summary)"
        }

        let parts = [
            sourceComponent(label: "baseURL", source: baseURLSource),
            sourceComponent(label: "path", source: pathSource),
            sourceComponent(label: "method", source: methodSource)
        ].compactMap { $0 }

        if parts.isEmpty {
            return "endpoint=内建 probe 默认值"
        }
        return "endpoint=" + parts.joined(separator: "，")
    }

    private var authSourceSummary: String {
        let parts = [
            sourceComponent(label: "authHeader", source: authHeaderSource),
            sourceComponent(label: "authScheme", source: authSchemeSource),
            sourceComponent(label: "apiKey", source: apiKeySource)
        ].compactMap { $0 }

        if parts.isEmpty {
            return "auth=未注入"
        }
        return "auth=" + parts.joined(separator: "，")
    }

    private func sourceComponent(
        label: String,
        source: MasterASRConfigSource?
    ) -> String? {
        guard let source else { return nil }
        return "\(label)=\(source.summary)"
    }
}

private struct MasterASRResolvedValue: Equatable, Sendable {
    let value: String
    let source: MasterASRConfigSource
}

private enum MasterASRConfigSource: Equatable, Sendable {
    case environment(String)
    case userDefaults(String)

    var summary: String {
        switch self {
        case .environment(let key):
            return "env(\(key))"
        case .userDefaults(let key):
            return "defaults(\(key))"
        }
    }
}

typealias MasterASRTransport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

final class ClawDBMasterASRService: MasterAudioTranscribing, @unchecked Sendable {
    private let resolveConfiguration: () throws -> MasterASRConfiguration
    private let transport: MasterASRTransport

    init(
        session: URLSession = .shared,
        processInfo: ProcessInfo = .processInfo,
        userDefaults: UserDefaults = .standard
    ) {
        self.resolveConfiguration = {
            try MasterASRConfiguration.current(
                environment: processInfo.environment,
                userDefaults: userDefaults
            )
        }
        self.transport = { request in
            try await session.data(for: request)
        }
    }

    init(
        configuration: MasterASRConfiguration,
        transport: @escaping MasterASRTransport
    ) {
        self.resolveConfiguration = { configuration }
        self.transport = transport
    }

    func transcribeAudio(at fileURL: URL) async throws -> String {
        let configuration = try resolveConfiguration()
        let audioData = try await loadAudioData(from: fileURL)
        guard !audioData.isEmpty else {
            throw MasterASRServiceError.unreadableAudio("当前音频文件为空，无法发起转写。")
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: configuration.url)
        request.httpMethod = configuration.method
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "content-type")

        if let authHeaderName = configuration.authHeaderName?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
           let apiKey = configuration.apiKey?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
            request.setValue(
                authHeaderValue(apiKey: apiKey, scheme: configuration.authScheme),
                forHTTPHeaderField: authHeaderName
            )
        }

        request.httpBody = buildMultipartBody(
            boundary: boundary,
            fileURL: fileURL,
            audioData: audioData,
            configuration: configuration
        )

        do {
            let (data, response) = try await transport(request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw MasterASRServiceError.invalidResponse
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 405 {
                    throw MasterASRServiceError.methodNotAllowed(
                        "\(configuration.method) \(configuration.url.absoluteString)"
                    )
                }
                throw Self.decodeError(data: data, statusCode: httpResponse.statusCode)
            }

            guard let transcript = Self.extractTranscript(from: data) else {
                throw MasterASRServiceError.invalidResponse
            }

            let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw MasterASRServiceError.emptyResponse
            }
            return trimmed
        } catch let error as MasterASRServiceError {
            throw error
        } catch {
            throw MasterASRServiceError.transport(error.localizedDescription)
        }
    }

    private func authHeaderValue(apiKey: String, scheme: String?) -> String {
        guard let scheme = scheme?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty else {
            return apiKey
        }
        return "\(scheme) \(apiKey)"
    }

    private func buildMultipartBody(
        boundary: String,
        fileURL: URL,
        audioData: Data,
        configuration: MasterASRConfiguration
    ) -> Data {
        var body = Data()
        appendField(named: "file", value: fileURL.lastPathComponent, to: &body, boundary: boundary, isFileName: true)
        body.append(audioData)
        body.appendUTF8("\r\n")

        if let model = configuration.model {
            appendField(named: "model", value: model, to: &body, boundary: boundary)
        }
        if let language = configuration.language {
            appendField(named: "language", value: language, to: &body, boundary: boundary)
        }
        if let responseFormat = configuration.responseFormat {
            appendField(named: "response_format", value: responseFormat, to: &body, boundary: boundary)
        }

        body.appendUTF8("--\(boundary)--\r\n")
        return body
    }

    private func appendField(
        named name: String,
        value: String,
        to body: inout Data,
        boundary: String,
        isFileName: Bool = false
    ) {
        body.appendUTF8("--\(boundary)\r\n")
        if isFileName {
            let contentType = mimeType(for: URL(fileURLWithPath: value).pathExtension)
            body.appendUTF8(
                "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(value)\"\r\n"
            )
            body.appendUTF8("Content-Type: \(contentType)\r\n\r\n")
        } else {
            body.appendUTF8("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            body.appendUTF8(value)
            body.appendUTF8("\r\n")
        }
    }

    private func mimeType(for pathExtension: String) -> String {
        switch pathExtension.lowercased() {
        case "m4a":
            return "audio/mp4"
        case "mp3":
            return "audio/mpeg"
        case "wav":
            return "audio/wav"
        case "aac":
            return "audio/aac"
        case "caf":
            return "audio/x-caf"
        default:
            return "application/octet-stream"
        }
    }

    private func loadAudioData(from fileURL: URL) async throws -> Data {
        do {
            return try await Task.detached(priority: .userInitiated) {
                try Data(contentsOf: fileURL)
            }.value
        } catch {
            throw MasterASRServiceError.unreadableAudio("读取音频文件失败：\(error.localizedDescription)")
        }
    }

    private static func decodeError(data: Data, statusCode: Int) -> MasterASRServiceError {
        let detail = extractErrorDetail(from: data)
        return .invalidStatusCode(statusCode, detail)
    }

    private static func extractErrorDetail(from data: Data) -> String {
        if let envelope = try? JSONDecoder().decode(MasterASRErrorEnvelope.self, from: data) {
            if let nested = envelope.errorMessage?.nonEmpty {
                return nested
            }
            if let flat = envelope.error?.nonEmpty {
                return flat
            }
            if let message = envelope.message?.nonEmpty {
                return message
            }
        }

        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func extractTranscript(from data: Data) -> String? {
        if let payload = try? JSONDecoder().decode(MasterASRTextEnvelope.self, from: data),
           let text = payload.bestText?.nonEmpty {
            return text
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let directCandidates = [
                json["text"] as? String,
                json["transcript"] as? String,
                json["result"] as? String
            ]
            for candidate in directCandidates {
                if let text = candidate?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
                    return text
                }
            }

            if let nested = json["data"] as? [String: Any] {
                let nestedCandidates = [
                    nested["text"] as? String,
                    nested["transcript"] as? String,
                    nested["result"] as? String
                ]
                for candidate in nestedCandidates {
                    if let text = candidate?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
                        return text
                    }
                }
            }
        }

        return nil
    }
}

private struct MasterASRTextEnvelope: Decodable {
    struct NestedPayload: Decodable {
        let text: String?
        let transcript: String?
        let result: String?
    }

    let text: String?
    let transcript: String?
    let result: String?
    let data: NestedPayload?

    var bestText: String? {
        text ?? transcript ?? result ?? data?.text ?? data?.transcript ?? data?.result
    }
}

private struct MasterASRErrorEnvelope: Decodable {
    struct NestedError: Decodable {
        let message: String?
    }

    let error: String?
    let message: String?
    let details: String?
    let payload: NestedError?

    var errorMessage: String? {
        payload?.message ?? details
    }
}

private extension Data {
    mutating func appendUTF8(_ string: String) {
        append(Data(string.utf8))
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
