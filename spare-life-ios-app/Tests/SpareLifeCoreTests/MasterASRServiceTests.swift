import XCTest
@testable import SpareLifeCore

final class MasterASRServiceTests: XCTestCase {
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

    private func makeAudioFixture(named name: String, contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(name)
            .appendingPathExtension("m4a")
        try Data(contents.utf8).write(to: url)
        return url
    }
}

private actor RequestCapture {
    private(set) var request: URLRequest?

    func store(_ request: URLRequest) {
        self.request = request
    }
}
