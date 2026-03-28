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
        let rawURL =
            value(
                environment: environment,
                userDefaults: userDefaults,
                environmentKeys: ["MASTER_ASR_URL"],
                defaultsKeys: ["masters.asr.url"]
            )
        let baseURL =
            value(
                environment: environment,
                userDefaults: userDefaults,
                environmentKeys: ["MASTER_ASR_BASE_URL"],
                defaultsKeys: ["masters.asr.baseURL"]
            ) ?? "http://100.82.60.69:17880"
        let path =
            value(
                environment: environment,
                userDefaults: userDefaults,
                environmentKeys: ["MASTER_ASR_PATH"],
                defaultsKeys: ["masters.asr.path"]
            ) ?? "/v1/audio/transcriptions"

        guard let url = normalizedURL(rawURL: rawURL, baseURL: baseURL, path: path) else {
            throw MasterASRServiceError.invalidBaseURL
        }

        let method =
            value(
                environment: environment,
                userDefaults: userDefaults,
                environmentKeys: ["MASTER_ASR_METHOD"],
                defaultsKeys: ["masters.asr.method"]
            ) ?? "POST"
        let authHeaderName = value(
            environment: environment,
            userDefaults: userDefaults,
            environmentKeys: ["MASTER_ASR_AUTH_HEADER"],
            defaultsKeys: ["masters.asr.authHeader"]
        )
        let authScheme = value(
            environment: environment,
            userDefaults: userDefaults,
            environmentKeys: ["MASTER_ASR_AUTH_SCHEME"],
            defaultsKeys: ["masters.asr.authScheme"]
        )
        let apiKey = value(
            environment: environment,
            userDefaults: userDefaults,
            environmentKeys: ["MASTER_ASR_API_KEY", "MASTER_ASR_AUTH_TOKEN"],
            defaultsKeys: ["masters.asr.apiKey", "masters.asr.authToken"]
        )
        let model = value(
            environment: environment,
            userDefaults: userDefaults,
            environmentKeys: ["MASTER_ASR_MODEL"],
            defaultsKeys: ["masters.asr.model"]
        ) ?? "whisper-1"
        let language = value(
            environment: environment,
            userDefaults: userDefaults,
            environmentKeys: ["MASTER_ASR_LANGUAGE"],
            defaultsKeys: ["masters.asr.language"]
        )
        let responseFormat = value(
            environment: environment,
            userDefaults: userDefaults,
            environmentKeys: ["MASTER_ASR_RESPONSE_FORMAT"],
            defaultsKeys: ["masters.asr.responseFormat"]
        )

        return MasterASRConfiguration(
            url: url,
            method: method.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            authHeaderName: authHeaderName,
            authScheme: authScheme,
            apiKey: apiKey,
            model: model.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
            language: language?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
            responseFormat: responseFormat?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        )
    }

    private static func value(
        environment: [String: String],
        userDefaults: UserDefaults,
        environmentKeys: [String],
        defaultsKeys: [String]
    ) -> String? {
        for key in environmentKeys {
            if let value = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
                return value
            }
        }
        for key in defaultsKeys {
            if let value = userDefaults.string(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
                return value
            }
        }
        return nil
    }

    private static func normalizedURL(rawURL: String?, baseURL: String, path: String) -> URL? {
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
