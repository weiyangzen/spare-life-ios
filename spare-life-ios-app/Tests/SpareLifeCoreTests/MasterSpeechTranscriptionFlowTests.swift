import XCTest
@testable import SpareLifeCore

final class MasterSpeechTranscriptionFlowTests: XCTestCase {
    func testAvailabilityBlocksTranscriptionUntilASRIsReady() {
        let status = MasterASRConnectionStatus(
            tone: .warning,
            title: "ASR 仍在探测路由",
            detail: "当前仍会请求 POST http://100.82.60.69:17880/v1/audio/transcriptions。"
        )

        XCTAssertEqual(
            MasterSpeechTranscriptionAvailability.blockingMessage(for: status),
            "语音识别暂不可用：ASR 仍在探测路由。当前仍会请求 POST http://100.82.60.69:17880/v1/audio/transcriptions。"
        )
    }

    func testAvailabilityAllowsTranscriptionWhenASRIsReady() {
        let status = MasterASRConnectionStatus(
            tone: .ready,
            title: "ASR live 候选配置已注入",
            detail: "当前会请求 POST https://asr.example.com/v1/audio/transcriptions。"
        )

        XCTAssertNil(MasterSpeechTranscriptionAvailability.blockingMessage(for: status))
    }

    func testResolveSuccessMergesDraftAndCleansUpTemporaryAudio() async throws {
        let fileURL = try makeAudioFixture(named: "success", contents: "audio")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        let flow = MasterSpeechTranscriptionFlow { _ in
            "帮我看下接下来三个月的转岗节奏。"
        }

        let resolution = await flow.resolve(
            fileURL: fileURL,
            existingDraft: "先评估现金流",
            cleanupAfterTranscription: true
        )

        XCTAssertEqual(
            resolution,
            MasterSpeechTranscriptionResolution(
                draft: "先评估现金流\n帮我看下接下来三个月的转岗节奏。",
                errorMessage: nil
            )
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testResolveFailurePreservesDraftSurfacesInlineErrorAndCleansUpTemporaryAudio() async throws {
        let fileURL = try makeAudioFixture(named: "failure", contents: "audio")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        let flow = MasterSpeechTranscriptionFlow { _ in
            throw MasterASRServiceError.methodNotAllowed("POST http://100.82.60.69:17880/v1/audio/transcriptions")
        }

        let resolution = await flow.resolve(
            fileURL: fileURL,
            existingDraft: "我先把背景讲完整",
            cleanupAfterTranscription: true
        )

        XCTAssertEqual(resolution.draft, "我先把背景讲完整")
        XCTAssertEqual(
            resolution.errorMessage,
            "语音识别失败：当前 ASR 路由返回 405，尚不能确认真实写入入口。 POST http://100.82.60.69:17880/v1/audio/transcriptions"
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    private func makeAudioFixture(named name: String, contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("master-speech-flow-\(name)-\(UUID().uuidString)")
            .appendingPathExtension("m4a")
        try Data(contents.utf8).write(to: url)
        return url
    }
}
