import Foundation

enum MasterRoleplayReplyComposer {
    static func remoteReply(from rawText: String, for request: MasterConversationRequest) -> String {
        let sanitized = sanitize(rawText)
        guard shouldRewrite(sanitized) else {
            return sanitized
        }
        return composeDialogue(for: request, seedText: sanitized)
    }

    static func fallbackReply(for request: MasterConversationRequest) -> String {
        composeDialogue(for: request, seedText: nil)
    }

    private static func composeDialogue(
        for request: MasterConversationRequest,
        seedText: String?
    ) -> String {
        let profile = request.profile
        let extractedLines = extractedSeedLines(from: seedText)
        let opening = openingLine(for: request.mode)
        let context = contextLine(for: request)
        let judgement = extractedLines.first ?? defaultJudgement(for: profile, latestUserMessage: latestUserMessage(in: request))
        let action = extractedLines.dropFirst().first ?? defaultAction(for: profile)
        let boundary = boundaryLine(for: profile)

        return [
            opening,
            context,
            judgement,
            action,
            boundary
        ]
        .compactMap { normalizedSentence($0) }
        .joined(separator: " ")
    }

    private static func latestUserMessage(in request: MasterConversationRequest) -> String {
        request.recentMessages
            .reversed()
            .first(where: { $0.role == .user })?
            .text
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func contextLine(for request: MasterConversationRequest) -> String {
        let latestUserMessage = latestUserMessage(in: request)
        if let story = request.relevantStories.first {
            return "你现在这个卡点，让我想到“\(story.title)”。那次真正起作用的，不是把话说满，而是抓住最先能撬动局面的那一下。"
        }

        if let memory = request.authorizedMemories.first {
            return "你授权我记住的“\(memory.label)”我还按着，所以这句判断不会跟你前面的处境断开。"
        }

        if !latestUserMessage.isEmpty {
            return "你刚才把问题点在“\(clipped(latestUserMessage, limit: 22))”，那我就顺着这根线往下说。"
        }

        return "我不跟你说空话，我们只沿着眼下这件事往前推。"
    }

    private static func openingLine(for mode: MasterConversationMode) -> String {
        switch mode {
        case .storyFirst:
            return "这件事我先不绕。"
        case .adviceFirst:
            return "我先把结论放前面。"
        case .companion:
            return "先别让慌乱替你做决定。"
        case .mentor:
            return "别再绕背景了，我们直接下判断。"
        }
    }

    private static func defaultJudgement(
        for profile: MasterProfile,
        latestUserMessage: String
    ) -> String {
        let issue = latestUserMessage.isEmpty ? "眼前这件事" : clipped(latestUserMessage, limit: 28)

        switch profile.decisionStyle {
        case "steady_execution":
            return "围着“\(issue)”这件事，我的判断是先把节奏和底盘稳住，再推进，不要一口气把所有战线都拉开。"
        case "act_then_reflect":
            return "围着“\(issue)”这件事，我的判断是先动手，不要再拿准备感冒充推进。"
        case "small_bets_profit":
            return "围着“\(issue)”这件事，我的判断是先做小赌注、先算止损，不要情绪上头就加码。"
        default:
            return "围着“\(issue)”这件事，我的判断是先把心气和边界站稳，再决定下一句该怎么说、下一步该怎么做。"
        }
    }

    private static func defaultAction(for profile: MasterProfile) -> String {
        switch profile.decisionStyle {
        case "steady_execution":
            return "今天只做一件事：定一条底线、一个周目标、一个明天就能开始的动作，别三线并行。"
        case "act_then_reflect":
            return "现在就去做一个会逼你拿反馈的小动作，别继续靠想象拖时间。"
        case "small_bets_profit":
            return "把动作压成一个七天内能算账、能止损的小实验，结果出来前别急着 all in。"
        default:
            return "先把那句真正想说的话写准，再决定要不要发出去，不要在情绪最满的时候开口。"
        }
    }

    private static func boundaryLine(for profile: MasterProfile) -> String? {
        guard let boundary = profile.boundaries.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              !boundary.isEmpty else {
            return nil
        }
        return "有条线你别越：\(boundary)。"
    }

    private static func shouldRewrite(_ text: String) -> Bool {
        let lowered = text.lowercased()
        if assistantMetaMarkers.contains(where: lowered.contains) {
            return true
        }

        return text.contains("\n-") ||
            text.contains("\n•") ||
            text.contains("\n1.") ||
            text.contains("\n2.") ||
            text.contains("首先") ||
            text.contains("其次") ||
            text.contains("最后")
    }

    private static func extractedSeedLines(from seedText: String?) -> [String] {
        guard let seedText,
              !seedText.isEmpty else {
            return []
        }

        return seedText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: CharacterSet(charactersIn: "\n。！？!?；;"))
            .map(normalizeSeedLine)
            .compactMap { $0 }
            .filter { !$0.isEmpty }
    }

    private static func normalizeSeedLine(_ rawLine: String) -> String? {
        var line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return nil }

        line = line.replacingOccurrences(
            of: #"^[\-\*\•\d一二三四五六七八九十]+[\.、:：\)]*\s*"#,
            with: "",
            options: .regularExpression
        )

        let removablePrefixes = [
            "作为 AI 助手，",
            "作为AI助手，",
            "作为一个 AI 助手，",
            "作为一个AI助手，",
            "作为 AI，",
            "作为AI，",
            "以下是我的建议：",
            "以下建议供你参考：",
            "我的建议是：",
            "建议如下：",
            "我建议你：",
            "我建议你:",
            "建议你：",
            "建议你:"
        ]

        for prefix in removablePrefixes where line.hasPrefix(prefix) {
            line.removeFirst(prefix.count)
            line = line.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard !line.isEmpty else { return nil }
        return normalizedSentence(line)
    }

    private static func sanitize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedSentence(_ text: String?) -> String? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if sentenceTerminators.contains(where: { trimmed.hasSuffix($0) }) {
            return trimmed
        }
        return trimmed + "。"
    }

    private static func clipped(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit)) + "…"
    }

    private static let sentenceTerminators = ["。", "！", "？", ".", "!", "?"]
    private static let assistantMetaMarkers = [
        "作为ai",
        "作为一个ai",
        "作为 ai",
        "language model",
        "语言模型",
        "ai 助手",
        "ai assistant",
        "以下是",
        "建议如下"
    ]
}
