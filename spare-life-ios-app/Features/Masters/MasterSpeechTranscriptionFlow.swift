import Foundation

struct MasterSpeechTranscriptionResolution: Equatable {
    let draft: String
    let errorMessage: String?
}

struct MasterSpeechTranscriptionFlow {
    typealias Transcribe = @Sendable (URL) async throws -> String
    typealias MergeDraft = @Sendable (String, String) -> String
    typealias RemoveFile = @Sendable (URL) -> Void

    private let transcribe: Transcribe
    private let mergeDraft: MergeDraft
    private let removeFile: RemoveFile

    init(
        transcribe: @escaping Transcribe,
        mergeDraft: @escaping MergeDraft = { existingDraft, transcript in
            MasterSpeechDraftComposer.mergedDraft(
                existingDraft: existingDraft,
                transcript: transcript
            )
        },
        removeFile: @escaping RemoveFile = { url in
            try? FileManager.default.removeItem(at: url)
        }
    ) {
        self.transcribe = transcribe
        self.mergeDraft = mergeDraft
        self.removeFile = removeFile
    }

    func resolve(
        fileURL: URL,
        existingDraft: String,
        cleanupAfterTranscription: Bool
    ) async -> MasterSpeechTranscriptionResolution {
        defer {
            if cleanupAfterTranscription {
                removeFile(fileURL)
            }
        }

        do {
            let transcript = try await transcribe(fileURL)
            return MasterSpeechTranscriptionResolution(
                draft: mergeDraft(existingDraft, transcript),
                errorMessage: nil
            )
        } catch {
            return MasterSpeechTranscriptionResolution(
                draft: existingDraft,
                errorMessage: "语音识别失败：\(error.localizedDescription)"
            )
        }
    }
}
