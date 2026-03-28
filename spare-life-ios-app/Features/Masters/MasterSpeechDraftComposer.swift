import Foundation

enum MasterSpeechDraftComposer {
    static func mergedDraft(existingDraft: String, transcript: String) -> String {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscript.isEmpty else {
            return existingDraft
        }

        let trimmedDraft = existingDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDraft.isEmpty else {
            return trimmedTranscript
        }

        return "\(trimmedDraft)\n\(trimmedTranscript)"
    }
}
