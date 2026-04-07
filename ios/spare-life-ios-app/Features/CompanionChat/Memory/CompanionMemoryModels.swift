import Foundation

struct MemorySnippet: Identifiable, Hashable {
    let id: String
    let summary: String
    let emotionTag: EmotionBadge.Emotion
    let timestamp: Date
    var isHighlighted: Bool
}
