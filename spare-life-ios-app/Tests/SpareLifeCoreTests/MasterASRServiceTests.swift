import XCTest
@testable import SpareLifeCore

final class MasterASRServiceTests: XCTestCase {
    func testMasterASRConfigurationStatusWarnsWhenStillUsingDefaultProbeRoute() {
        let suiteName = "master-asr-status-default-route-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated user defaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let status = MasterASRConfiguration.currentStatus(environment: [:], userDefaults: defaults)

        XCTAssertEqual(status.tone, .warning)
        XCTAssertEqual(status.title, "ASR 仍在探测路由")
        XCTAssertTrue(status.detail.contains("POST http://100.82.60.69:17880/v1/audio/transcriptions"))
        XCTAssertTrue(status.detail.contains("MASTER_ASR_URL / MASTER_ASR_BASE_URL / MASTER_ASR_PATH / MASTER_ASR_METHOD"))
        XCTAssertTrue(status.detail.contains("masters.asr.url / masters.asr.baseURL / masters.asr.path / masters.asr.method"))
        XCTAssertTrue(status.detail.contains("endpoint=内建 probe 默认值"))
        XCTAssertTrue(status.detail.contains("auth=未注入"))
    }

    func testMasterASRConfigurationStatusWarnsWhenEndpointExistsButAuthIsMissing() {
        let suiteName = "master-asr-status-missing-auth-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated user defaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set("https://asr.example.com/live", forKey: "masters.asr.baseURL")
        defaults.set("/speech/transcribe", forKey: "masters.asr.path")
        defaults.set("put", forKey: "masters.asr.method")

        let status = MasterASRConfiguration.currentStatus(environment: [:], userDefaults: defaults)

        XCTAssertEqual(status.tone, .warning)
        XCTAssertEqual(status.title, "ASR 鉴权尚未补齐")
        XCTAssertTrue(status.detail.contains("PUT https://asr.example.com/live/speech/transcribe"))
        XCTAssertTrue(status.detail.contains("MASTER_ASR_AUTH_HEADER / MASTER_ASR_AUTH_SCHEME / MASTER_ASR_API_KEY / MASTER_ASR_AUTH_TOKEN"))
        XCTAssertTrue(status.detail.contains("masters.asr.authHeader / masters.asr.authScheme / masters.asr.apiKey / masters.asr.authToken"))
        XCTAssertTrue(status.detail.contains("baseURL=defaults(masters.asr.baseURL)"))
        XCTAssertTrue(status.detail.contains("path=defaults(masters.asr.path)"))
        XCTAssertTrue(status.detail.contains("method=defaults(masters.asr.method)"))
        XCTAssertTrue(status.detail.contains("auth=未注入"))
    }

    func testMasterASRConfigurationStatusReportsInjectedLiveCandidateConfiguration() {
        let suiteName = "master-asr-status-live-candidate-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated user defaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let status = MasterASRConfiguration.currentStatus(
            environment: [
                "MASTER_ASR_URL": "https://asr.example.com/live/speech/transcribe",
                "MASTER_ASR_METHOD": "post",
                "MASTER_ASR_AUTH_HEADER": "X-ClawDB-Token",
                "MASTER_ASR_AUTH_SCHEME": "Token",
                "MASTER_ASR_API_KEY": "env-secret"
            ],
            userDefaults: defaults
        )

        XCTAssertEqual(status.tone, .ready)
        XCTAssertEqual(status.title, "ASR live 候选配置已注入")
        XCTAssertTrue(status.detail.contains("POST https://asr.example.com/live/speech/transcribe"))
        XCTAssertTrue(status.detail.contains("X-ClawDB-Token"))
        XCTAssertTrue(status.detail.contains("Token"))
        XCTAssertTrue(status.detail.contains("endpoint=env(MASTER_ASR_URL)"))
        XCTAssertTrue(status.detail.contains("authHeader=env(MASTER_ASR_AUTH_HEADER)"))
        XCTAssertTrue(status.detail.contains("authScheme=env(MASTER_ASR_AUTH_SCHEME)"))
        XCTAssertTrue(status.detail.contains("apiKey=env(MASTER_ASR_API_KEY)"))
        XCTAssertFalse(status.detail.contains("env-secret"))
    }

    func testMasterASRConfigurationReadsCustomMethodAndTokenAliasFromEnvironment() throws {
        let suiteName = "master-asr-env-config-tests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated user defaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let configuration = try MasterASRConfiguration.current(
            environment: [
                "MASTER_ASR_BASE_URL": "https://asr.example.com/live",
                "MASTER_ASR_PATH": "speech/transcribe",
                "MASTER_ASR_METHOD": "put",
                "MASTER_ASR_AUTH_HEADER": "X-ClawDB-Token",
                "MASTER_ASR_AUTH_SCHEME": "Token",
                "MASTER_ASR_AUTH_TOKEN": "env-secret"
            ],
            userDefaults: defaults
        )

        XCTAssertEqual(configuration.url.absoluteString, "https://asr.example.com/live/speech/transcribe")
        XCTAssertEqual(configuration.method, "PUT")
        XCTAssertEqual(configuration.authHeaderName, "X-ClawDB-Token")
        XCTAssertEqual(configuration.authScheme, "Token")
        XCTAssertEqual(configuration.apiKey, "env-secret")
    }

    func testMasterASRConfigurationBuildsURLAndAuthFromUserDefaults() throws {
        let suiteName = "master-asr-config-tests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated user defaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set("http://127.0.0.1:19090", forKey: "masters.asr.baseURL")
        defaults.set("/speech/transcribe", forKey: "masters.asr.path")
        defaults.set("X-ASR-Key", forKey: "masters.asr.authHeader")
        defaults.set("Bearer", forKey: "masters.asr.authScheme")
        defaults.set("local-secret", forKey: "masters.asr.apiKey")
        defaults.set("asr-v1", forKey: "masters.asr.model")
        defaults.set("zh", forKey: "masters.asr.language")
        defaults.set("verbose_json", forKey: "masters.asr.responseFormat")

        let configuration = try MasterASRConfiguration.current(environment: [:], userDefaults: defaults)

        XCTAssertEqual(configuration.url.absoluteString, "http://127.0.0.1:19090/speech/transcribe")
        XCTAssertEqual(configuration.method, "POST")
        XCTAssertEqual(configuration.authHeaderName, "X-ASR-Key")
        XCTAssertEqual(configuration.authScheme, "Bearer")
        XCTAssertEqual(configuration.apiKey, "local-secret")
        XCTAssertEqual(configuration.model, "asr-v1")
        XCTAssertEqual(configuration.language, "zh")
        XCTAssertEqual(configuration.responseFormat, "verbose_json")
    }

    func testClawDBMasterASRServiceBuildsMultipartRequestAndDecodesTranscript() async throws {
        let fileURL = try makeAudioFixture(named: "multipart-request", contents: "test-audio")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let capture = RequestCapture()
        let configuration = MasterASRConfiguration(
            url: URL(string: "https://example.com/v1/audio/transcriptions")!,
            method: "POST",
            authHeaderName: "Authorization",
            authScheme: "Bearer",
            apiKey: "secret-token",
            model: "whisper-1",
            language: "zh",
            responseFormat: nil
        )

        let service = ClawDBMasterASRService(configuration: configuration) { request in
            await capture.store(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (#"{"text":"你好，世界"}"#.data(using: .utf8)!, response)
        }

        let transcript = try await service.transcribeAudio(at: fileURL)
        let request = await capture.request

        XCTAssertEqual(transcript, "你好，世界")
        XCTAssertEqual(request?.httpMethod, "POST")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "Authorization"), "Bearer secret-token")
        XCTAssertTrue(request?.value(forHTTPHeaderField: "content-type")?.contains("multipart/form-data") == true)

        let body = try XCTUnwrap(request?.httpBody)
        let bodyText = try XCTUnwrap(String(data: body, encoding: .utf8))
        XCTAssertTrue(bodyText.contains("name=\"file\"; filename=\"multipart-request.m4a\""))
        XCTAssertTrue(bodyText.contains("name=\"model\""))
        XCTAssertTrue(bodyText.contains("whisper-1"))
        XCTAssertTrue(bodyText.contains("name=\"language\""))
        XCTAssertTrue(bodyText.contains("zh"))
    }

    func testClawDBMasterASRServiceUsesConfiguredCustomAuthHeader() async throws {
        let fileURL = try makeAudioFixture(named: "custom-auth-header", contents: "test-audio")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let capture = RequestCapture()
        let configuration = MasterASRConfiguration(
            url: URL(string: "https://example.com/v1/audio/transcriptions")!,
            method: "POST",
            authHeaderName: "X-ClawDB-Token",
            authScheme: nil,
            apiKey: "raw-secret",
            model: "whisper-1",
            language: nil,
            responseFormat: nil
        )

        let service = ClawDBMasterASRService(configuration: configuration) { request in
            await capture.store(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (#"{"transcript":"自定义鉴权通过"}"#.data(using: .utf8)!, response)
        }

        let transcript = try await service.transcribeAudio(at: fileURL)
        let request = await capture.request

        XCTAssertEqual(transcript, "自定义鉴权通过")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "X-ClawDB-Token"), "raw-secret")
    }

    func testClawDBMasterASRServiceSurfacesMethodNotAllowedProbe() async throws {
        let fileURL = try makeAudioFixture(named: "method-not-allowed", contents: "test-audio")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let configuration = MasterASRConfiguration(
            url: URL(string: "http://100.82.60.69:17880/v1/audio/transcriptions")!,
            method: "POST",
            authHeaderName: nil,
            authScheme: nil,
            apiKey: nil,
            model: "whisper-1",
            language: nil,
            responseFormat: nil
        )

        let service = ClawDBMasterASRService(configuration: configuration) { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 405,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (#"{"ok":false,"error":"method_not_allowed"}"#.data(using: .utf8)!, response)
        }

        do {
            _ = try await service.transcribeAudio(at: fileURL)
            XCTFail("Expected method_not_allowed error")
        } catch let error as MasterASRServiceError {
            guard case .methodNotAllowed(let detail) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertTrue(detail.contains("POST"))
            XCTAssertTrue(detail.contains("/v1/audio/transcriptions"))
        }
    }

    func testClawDBMasterASRServiceLiveSmokeRunsWhenExplicitlyEnabled() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["MASTER_ASR_LIVE_SMOKE"] == "1" else {
            throw XCTSkip("Set MASTER_ASR_LIVE_SMOKE=1 to run the live ASR smoke test.")
        }

        let status = MasterASRConfiguration.currentStatus(environment: environment, userDefaults: .standard)
        guard status.tone == .ready else {
            throw XCTSkip("Live ASR smoke blocked: \(status.title) - \(status.detail)")
        }

        let audioPath = try requiredLiveSmokeValue(
            for: "MASTER_ASR_SMOKE_AUDIO_FILE",
            environment: environment,
            guidance: "Point it to a readable local audio file with real speech."
        )
        let audioURL = URL(fileURLWithPath: audioPath)
        guard FileManager.default.isReadableFile(atPath: audioURL.path) else {
            XCTFail("Smoke audio file is not readable: \(audioPath)")
            return
        }

        let transcript = try await ClawDBMasterASRService(
            processInfo: .processInfo,
            userDefaults: .standard
        ).transcribeAudio(at: audioURL)
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertFalse(trimmedTranscript.isEmpty)

        if let expectedSubstring = environment["MASTER_ASR_SMOKE_EXPECT_SUBSTRING"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !expectedSubstring.isEmpty {
            XCTAssertTrue(
                trimmedTranscript.localizedCaseInsensitiveContains(expectedSubstring),
                "Expected transcript to contain '\(expectedSubstring)', got '\(trimmedTranscript)'"
            )
        }
    }

    private func makeAudioFixture(named name: String, contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(name)
            .appendingPathExtension("m4a")
        try Data(contents.utf8).write(to: url)
        return url
    }

    private func requiredLiveSmokeValue(
        for key: String,
        environment: [String: String],
        guidance: String
    ) throws -> String {
        guard let value = environment[key]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty else {
            throw XCTSkip("Set \(key) before running the live ASR smoke test. \(guidance)")
        }
        return value
    }
}

private actor RequestCapture {
    private(set) var request: URLRequest?

    func store(_ request: URLRequest) {
        self.request = request
    }
}
