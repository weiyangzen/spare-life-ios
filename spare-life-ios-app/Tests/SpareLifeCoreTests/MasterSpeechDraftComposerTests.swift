import XCTest
@testable import SpareLifeCore

final class MasterSpeechDraftComposerTests: XCTestCase {
    func testMergedDraftUsesTranscriptWhenDraftIsEmpty() {
        let merged = MasterSpeechDraftComposer.mergedDraft(
            existingDraft: "   ",
            transcript: "  我想先聊聊转岗节奏。  "
        )

        XCTAssertEqual(merged, "我想先聊聊转岗节奏。")
    }

    func testMergedDraftAppendsTranscriptOnNewLine() {
        let merged = MasterSpeechDraftComposer.mergedDraft(
            existingDraft: "先看现金流还能扛多久",
            transcript: "如果三个月内还没结果，我就得回到上一份工作。"
        )

        XCTAssertEqual(merged, "先看现金流还能扛多久\n如果三个月内还没结果，我就得回到上一份工作。")
    }

    @MainActor
    func testMergedDraftFlowsThroughSameConversationSendChain() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("master-speech-draft-tests-\(UUID().uuidString)", isDirectory: true)
        let archiveURL = tempDirectory.appendingPathComponent("master-conversations.json", isDirectory: false)
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        let service = StubConversationService()
        let store = MasterExperienceStore(
            catalogLoader: { try MasterCatalogLoader.load() },
            conversationService: service,
            localStateStore: MasterConversationLocalStateStore(archiveURL: archiveURL)
        )

        await store.refreshCatalog()

        let profile = try XCTUnwrap(store.visibleDirectoryMasters.first)
        store.openConversation(for: profile)

        let mergedDraft = MasterSpeechDraftComposer.mergedDraft(
            existingDraft: "先帮我看现金流和风险窗口",
            transcript: "我想在三个月内完成 AI 产品转岗。"
        )
        await store.sendMessage(mergedDraft)

        let request = try XCTUnwrap(service.requests.last)
        XCTAssertEqual(request.recentMessages.last?.role, .user)
        XCTAssertEqual(request.recentMessages.last?.text, mergedDraft)

        let conversation = try XCTUnwrap(store.conversation)
        XCTAssertEqual(conversation.messages.last?.role, .assistant)
        XCTAssertEqual(conversation.messages[conversation.messages.count - 2].text, mergedDraft)
    }
}

@MainActor
private final class StubConversationService: MasterConversationReplying {
    private(set) var requests: [MasterConversationRequest] = []

    var status: MasterConversationServiceStatus = .live(
        modelName: "stub-k2p5",
        credentialSource: .environmentFallback
    )

    func generateReply(for request: MasterConversationRequest) async throws -> MasterConversationServiceResult {
        requests.append(request)
        return MasterConversationServiceResult(
            text: "我听见你的补充了，我们继续按同一条发送链路往下聊。",
            status: status
        )
    }
}
