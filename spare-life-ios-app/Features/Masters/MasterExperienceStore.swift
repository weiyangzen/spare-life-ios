// MasterExperienceStore.swift
// Spare Life – 大师页 UI state, seeded catalog, and interaction logic
// Blueprint §3.2 功能点 1-7
// UIUX lane – slot 2

import Foundation
import SwiftUI

enum MasterCatalogSourceMode: String, CaseIterable, Identifiable {
    case synced
    case cached
    case degraded
    case unavailable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .synced: return "实时目录"
        case .cached: return "缓存目录"
        case .degraded: return "异常降级"
        case .unavailable: return "目录不可用"
        }
    }

    var subtitle: String {
        switch self {
        case .synced:
            return "优先展示最新导入的大师目录和最近上下文。"
        case .cached:
            return "只读本地缓存，适合弱网或离线继续找大师。"
        case .degraded:
            return "请求异常时保留上次缓存，并把异常透出给用户。"
        case .unavailable:
            return "没有可用缓存时，完整展示错误态和重试入口。"
        }
    }

    var icon: String {
        switch self {
        case .synced: return "checkmark.seal.fill"
        case .cached: return "externaldrive.fill.badge.checkmark"
        case .degraded: return "wifi.exclamationmark"
        case .unavailable: return "exclamationmark.octagon.fill"
        }
    }

    var tint: Color {
        switch self {
        case .synced: return .emotionPositive
        case .cached: return .blue
        case .degraded: return .orange
        case .unavailable: return .emotionNegative
        }
    }
}

enum MasterConversationMode: String, CaseIterable, Identifiable, Hashable {
    case storyFirst = "故事优先"
    case adviceFirst = "建议优先"
    case companion = "陪伴模式"
    case mentor = "导师模式"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .storyFirst: return "先用最相关人生故事托住可信感。"
        case .adviceFirst: return "先给结论，再补故事与边界。"
        case .companion: return "更柔和，适合情绪与关系场景。"
        case .mentor: return "更直接，适合决断与推进场景。"
        }
    }
}

enum MasterMemoryScope: String, CaseIterable, Identifiable, Hashable {
    case sessionOnly = "仅本次"
    case masterOnly = "只给这位大师"
    case crossMaster = "会诊共享"

    var id: String { rawValue }

    var detail: String {
        switch self {
        case .sessionOnly:
            return "本次聊完即止，不进入长期记忆。"
        case .masterOnly:
            return "只让当前大师记住，不跨大师共享。"
        case .crossMaster:
            return "只在会诊里共享必要上下文，不共享全部隐私。"
        }
    }
}

enum MasterActionTarget: String, Hashable {
    case messages
    case earnSocial
    case profile
    case masters

    var title: String {
        switch self {
        case .messages: return "消息页"
        case .earnSocial: return "赚闲能"
        case .profile: return "我的页"
        case .masters: return "大师页"
        }
    }

    var icon: String {
        switch self {
        case .messages: return "bubble.left.and.bubble.right.fill"
        case .earnSocial: return "bolt.circle.fill"
        case .profile: return "person.crop.circle.fill"
        case .masters: return "book.pages.fill"
        }
    }
}

enum MasterMessageRole: String, Hashable {
    case user
    case assistant
    case system
}

struct MasterDomain: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let symbol: String
}

struct MasterQuestionTemplate: Identifiable, Hashable {
    let id: String
    let title: String
    let prompt: String
    let mode: MasterConversationMode
}

struct MasterStory: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let beats: [String]
    let tags: [String]
}

struct MasterMemoryNote: Identifiable, Hashable {
    let id: String
    let label: String
    let summary: String
    let scope: MasterMemoryScope
    let updatedAt: String
    let isSensitive: Bool
}

struct MasterGoalSnapshot: Identifiable, Hashable {
    let id: String
    let title: String
    let nextAction: String
    let status: String
    let updatedAt: String
}

struct MasterAssetBundleInfo: Hashable {
    let bundleID: String
    let version: String
    let portraitPackage: String
    let characterFields: [String]
    let storyFields: [String]
    let manifestFields: [String]
    let importNote: String
    let isOfficial: Bool
}

struct MasterActionRecommendation: Identifiable, Hashable {
    let id: String
    let label: String
    let reason: String
    let route: String
    let target: MasterActionTarget
}

struct MasterMessage: Identifiable, Hashable {
    let id: String
    let role: MasterMessageRole
    let text: String
    let timestamp: String
    let referencedStoryTitles: [String]
    let referencedMemoryLabels: [String]
    let ctas: [MasterActionRecommendation]
}

struct MasterProfile: Identifiable {
    let id: String
    let displayName: String
    let title: String
    let tagline: String
    let headline: String
    let domainID: String
    let domainTitle: String
    let sourceLabel: String
    let voice: String
    let adviceStyle: String
    let decisionStyle: String
    let riskAppetite: String
    let expertiseTags: [String]
    let focusTags: [String]
    let boundaries: [String]
    let featuredTemplates: [MasterQuestionTemplate]
    let stories: [MasterStory]
    let memoryNotes: [MasterMemoryNote]
    let goalSnapshots: [MasterGoalSnapshot]
    let assetBundle: MasterAssetBundleInfo
    let portraitSymbol: String
    let palette: [Color]
    let promptPreview: String
}

struct MasterRecentSession: Identifiable, Hashable {
    let id: String
    let masterID: String
    let displayName: String
    let title: String
    var topic: String
    var preview: String
    var unreadCount: Int
    var lastMessageAt: String
    var isPinned: Bool
    let seedMessages: [MasterMessage]
}

enum MasterConsultationPhase: Hashable {
    case drafting
    case loading
    case loaded(MasterConsultationResult)
    case error(String)
}

struct MasterConsultationMember: Identifiable, Hashable {
    let id: String
    let masterID: String
    let displayName: String
    let title: String
    let stance: String
    let advice: String
    let storyTitles: [String]
    let ctas: [MasterActionRecommendation]
}

struct MasterConsultationResult: Hashable {
    let mergedSummary: String
    let conflictSummary: String?
    let members: [MasterConsultationMember]
    let ctas: [MasterActionRecommendation]
}

struct MasterConsultationDraft: Identifiable, Hashable {
    let id: String
    var issue: String
    var selectedMasterIDs: Set<String>
    var shareScope: MasterMemoryScope
    var phase: MasterConsultationPhase
    var inlineError: String?
}

struct MasterConversationDraft: Identifiable, Hashable {
    let id: String
    let masterID: String
    var session: MasterRecentSession
    var mode: MasterConversationMode
    var memoryScope: MasterMemoryScope
    var messages: [MasterMessage]
    var prefilledPrompt: String
    var isReplying: Bool
    var inlineError: String?
}

enum MasterHomeFeedCard: Identifiable {
    case master(MasterProfile)
    case resume(MasterRecentSession)
    case template(masterID: String, template: MasterQuestionTemplate)
    case consultation(featuredMasterIDs: [String])

    var id: String {
        switch self {
        case .master(let profile):
            return "master-\(profile.id)"
        case .resume(let session):
            return "resume-\(session.id)"
        case .template(let masterID, let template):
            return "template-\(masterID)-\(template.id)"
        case .consultation(let featuredMasterIDs):
            return "consult-\(featuredMasterIDs.joined(separator: "-"))"
        }
    }
}

struct MasterRoutePreview: Identifiable, Hashable {
    let id: String
    let action: MasterActionRecommendation
    let sourceTitle: String
}

@MainActor
final class MasterExperienceStore: ObservableObject {
    @Published var query = ""
    @Published var selectedDomainID: String? = nil
    @Published var catalogSourceMode: MasterCatalogSourceMode = .synced
    @Published private(set) var isLoading = false
    @Published private(set) var degradedMessage: String? = nil
    @Published private(set) var fatalErrorMessage: String? = nil
    @Published private(set) var domains: [MasterDomain] = []
    @Published private(set) var masters: [MasterProfile] = []
    @Published private(set) var recentSessions: [MasterRecentSession] = []
    @Published var selectedMasterID: String? = nil
    @Published var conversation: MasterConversationDraft? = nil
    @Published var consultation: MasterConsultationDraft? = nil
    @Published var routePreview: MasterRoutePreview? = nil

    private var hasLoaded = false
    private let seed = MasterSeedCatalog.make()

    var filteredMasters: [MasterProfile] {
        let trimmed = searchable(query)
        return masters
            .filter { selectedDomainID == nil || $0.domainID == selectedDomainID }
            .filter { profile in
                guard !trimmed.isEmpty else { return true }
                let haystack = [
                    profile.displayName,
                    profile.title,
                    profile.tagline,
                    profile.headline,
                    profile.domainTitle,
                    profile.expertiseTags.joined(separator: " "),
                    profile.focusTags.joined(separator: " "),
                    profile.stories.map(\.title).joined(separator: " "),
                    profile.stories.flatMap(\.tags).joined(separator: " ")
                ]
                    .joined(separator: " ")
                    .lowercased()
                return haystack.contains(trimmed)
            }
    }

    var prioritizedSessions: [MasterRecentSession] {
        recentSessions.sorted {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned && !$1.isPinned
            }
            if $0.unreadCount != $1.unreadCount {
                return $0.unreadCount > $1.unreadCount
            }
            return $0.lastMessageAt > $1.lastMessageAt
        }
    }

    var homeCards: [MasterHomeFeedCard] {
        var cards = filteredMasters.map(MasterHomeFeedCard.master)

        if query.isEmpty {
            let resumeCards = prioritizedSessions.prefix(2).map(MasterHomeFeedCard.resume)
            let templateCards = filteredMasters
                .prefix(3)
                .flatMap { profile in
                    profile.featuredTemplates.prefix(1).map { MasterHomeFeedCard.template(masterID: profile.id, template: $0) }
                }
            if !cards.isEmpty {
                cards.insert(contentsOf: resumeCards, at: min(1, cards.count))
            } else {
                cards.append(contentsOf: resumeCards)
            }
            cards.append(contentsOf: templateCards)
            cards.append(.consultation(featuredMasterIDs: filteredMasters.prefix(3).map(\.id)))
        }

        return cards
    }

    var recentStripSessions: [MasterRecentSession] {
        Array(prioritizedSessions.prefix(6))
    }

    var showCacheBanner: Bool {
        degradedMessage != nil || catalogSourceMode == .cached
    }

    func master(withID id: String) -> MasterProfile? {
        masters.first(where: { $0.id == id })
    }

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        Task { await refreshCatalog() }
    }

    func refreshCatalog() async {
        isLoading = true
        degradedMessage = nil
        fatalErrorMessage = nil

        try? await Task.sleep(nanoseconds: 380_000_000)

        domains = seed.domains

        switch catalogSourceMode {
        case .synced:
            masters = seed.masters
            recentSessions = seed.sessions
        case .cached:
            masters = seed.cachedMasters
            recentSessions = seed.cachedSessions
            degradedMessage = "当前展示上次导入缓存，可继续找人、恢复会话与查看故事资产。"
        case .degraded:
            masters = seed.cachedMasters
            recentSessions = seed.cachedSessions
            degradedMessage = "请求异常，已自动退回缓存目录。最近会话、长期记忆和会诊入口仍可继续。"
        case .unavailable:
            masters = []
            recentSessions = []
            fatalErrorMessage = "大师目录暂时不可用，当前也没有可恢复的本地缓存。请稍后重试。"
        }

        if let selectedDomainID, !domains.contains(where: { $0.id == selectedDomainID }) {
            self.selectedDomainID = nil
        }

        isLoading = false
    }

    func applyCatalogSourceMode(_ mode: MasterCatalogSourceMode) {
        catalogSourceMode = mode
        Task { await refreshCatalog() }
    }

    func togglePinned(_ session: MasterRecentSession) {
        guard let index = recentSessions.firstIndex(where: { $0.id == session.id }) else { return }
        recentSessions[index].isPinned.toggle()
        syncConversationSession(recentSessions[index])
    }

    func openMaster(_ profile: MasterProfile) {
        selectedMasterID = profile.id
    }

    func openConversation(for profile: MasterProfile, template: MasterQuestionTemplate? = nil) {
        let existingSession = recentSessions.first(where: { $0.masterID == profile.id })
        let session = existingSession ?? MasterRecentSession(
            id: "session-\(profile.id)",
            masterID: profile.id,
            displayName: profile.displayName,
            title: profile.title,
            topic: template?.title ?? "先聊聊你最近最卡住的点",
            preview: profile.tagline,
            unreadCount: 0,
            lastMessageAt: "刚刚",
            isPinned: false,
            seedMessages: [
                MasterMessage(
                    id: "opening-\(profile.id)",
                    role: .assistant,
                    text: "\(profile.displayName)在这里。你可以直接问问题，也可以先挑一个问题模板，我会沿用你授权的长期记忆，但不会跨大师乱共享。",
                    timestamp: "刚刚",
                    referencedStoryTitles: [],
                    referencedMemoryLabels: [],
                    ctas: [
                        MasterActionRecommendation(
                            id: "profile-memory-\(profile.id)",
                            label: "检查记忆授权",
                            reason: "先确认长期记忆范围，避免把隐私记过头。",
                            route: "sparelife://my/profile?highlight=memory",
                            target: .profile
                        )
                    ]
                )
            ]
        )

        conversation = MasterConversationDraft(
            id: session.id,
            masterID: profile.id,
            session: session,
            mode: template?.mode ?? .storyFirst,
            memoryScope: .masterOnly,
            messages: session.seedMessages,
            prefilledPrompt: template?.prompt ?? "",
            isReplying: false,
            inlineError: nil
        )
    }

    func restoreSession(_ session: MasterRecentSession) {
        guard let profile = master(withID: session.masterID) else { return }
        conversation = MasterConversationDraft(
            id: session.id,
            masterID: profile.id,
            session: session,
            mode: .storyFirst,
            memoryScope: .masterOnly,
            messages: session.seedMessages,
            prefilledPrompt: "",
            isReplying: false,
            inlineError: nil
        )
        markSessionRead(session.id)
    }

    func clearMemories(for masterID: String) {
        guard let index = masters.firstIndex(where: { $0.id == masterID }) else { return }
        let profile = masters[index]
        masters[index] = MasterProfile(
            id: profile.id,
            displayName: profile.displayName,
            title: profile.title,
            tagline: profile.tagline,
            headline: profile.headline,
            domainID: profile.domainID,
            domainTitle: profile.domainTitle,
            sourceLabel: profile.sourceLabel,
            voice: profile.voice,
            adviceStyle: profile.adviceStyle,
            decisionStyle: profile.decisionStyle,
            riskAppetite: profile.riskAppetite,
            expertiseTags: profile.expertiseTags,
            focusTags: profile.focusTags,
            boundaries: profile.boundaries,
            featuredTemplates: profile.featuredTemplates,
            stories: profile.stories,
            memoryNotes: [],
            goalSnapshots: profile.goalSnapshots,
            assetBundle: profile.assetBundle,
            portraitSymbol: profile.portraitSymbol,
            palette: profile.palette,
            promptPreview: profile.promptPreview
        )

        if conversation?.masterID == masterID {
            conversation?.messages.append(
                MasterMessage(
                    id: "memory-cleared-\(masterID)",
                    role: .system,
                    text: "这位大师与你的长期记忆已经清空。后续仍可继续聊天，但需要重新授权记忆范围。",
                    timestamp: "刚刚",
                    referencedStoryTitles: [],
                    referencedMemoryLabels: [],
                    ctas: []
                )
            )
        }
    }

    func presentConsultation(prefill issue: String = "") {
        let featured = filteredMasters.isEmpty ? masters : filteredMasters
        consultation = MasterConsultationDraft(
            id: "consult-draft",
            issue: issue,
            selectedMasterIDs: Set(featured.prefix(3).map(\.id)),
            shareScope: .crossMaster,
            phase: .drafting,
            inlineError: nil
        )
    }

    func toggleConsultSelection(_ masterID: String) {
        guard var consultation else { return }
        if consultation.selectedMasterIDs.contains(masterID) {
            consultation.selectedMasterIDs.remove(masterID)
        } else if consultation.selectedMasterIDs.count < 3 {
            consultation.selectedMasterIDs.insert(masterID)
        }
        self.consultation = consultation
    }

    func runConsultation() async {
        guard var consultation else { return }
        let issue = trimmed(consultation.issue)

        guard !issue.isEmpty else {
            consultation.inlineError = "先把你想讨论的问题写具体，例如“转岗 AI 产品但现金流只够三个月”。"
            self.consultation = consultation
            return
        }

        guard !consultation.selectedMasterIDs.isEmpty else {
            consultation.inlineError = "至少选择一位大师，最好 2-3 位，才能形成会诊。"
            self.consultation = consultation
            return
        }

        consultation.inlineError = nil
        consultation.phase = .loading
        self.consultation = consultation

        try? await Task.sleep(nanoseconds: 480_000_000)

        if catalogSourceMode == .unavailable {
            consultation.phase = .error("目录不可用，当前无法发起会诊。你可以先回到首页重试同步。")
            self.consultation = consultation
            return
        }

        let members = consultation.selectedMasterIDs.compactMap(master(withID:))
        let result = buildConsultationResult(for: members, issue: issue, shareScope: consultation.shareScope)
        consultation.phase = .loaded(result)
        self.consultation = consultation
    }

    func sendMessage(_ rawText: String) async {
        guard var conversation, let profile = master(withID: conversation.masterID) else { return }
        let text = trimmed(rawText)

        guard !text.isEmpty else {
            conversation.inlineError = "先把问题说完整，大师页不是一句“在吗”就能给出好建议的地方。"
            self.conversation = conversation
            return
        }

        conversation.inlineError = nil
        conversation.isReplying = true
        conversation.messages.append(
            MasterMessage(
                id: "user-\(UUID().uuidString)",
                role: .user,
                text: text,
                timestamp: "刚刚",
                referencedStoryTitles: [],
                referencedMemoryLabels: [],
                ctas: []
            )
        )
        self.conversation = conversation

        try? await Task.sleep(nanoseconds: 420_000_000)

        if catalogSourceMode == .unavailable {
            conversation.isReplying = false
            conversation.inlineError = "这次请求没能发出去，因为目录同步失败且没有缓存。请先回到首页恢复内容源。"
            self.conversation = conversation
            return
        }

        let reply = composeReply(
            for: profile,
            message: text,
            mode: conversation.mode,
            memoryScope: conversation.memoryScope
        )
        conversation.messages.append(reply)
        conversation.session.topic = clip(text, limit: 18)
        conversation.session.preview = reply.text
        conversation.session.unreadCount = 0
        conversation.session.lastMessageAt = "刚刚"
        conversation.isReplying = false
        conversation.prefilledPrompt = ""

        upsertSession(conversation.session)
        if conversation.memoryScope != .sessionOnly {
            appendAuthorizedMemory(for: profile.id, from: text, scope: conversation.memoryScope)
        }

        self.conversation = conversation
    }

    func presentRoutePreview(_ action: MasterActionRecommendation, sourceTitle: String) {
        routePreview = MasterRoutePreview(id: action.id, action: action, sourceTitle: sourceTitle)
    }

    func isActionAdopted(_ actionID: String) -> Bool {
        seed.adoptedActionIDs.contains(actionID) || adoptedActionIDs.contains(actionID)
    }

    func markActionAdopted(_ actionID: String) {
        adoptedActionIDs.insert(actionID)
    }

    private var adoptedActionIDs: Set<String> = []

    private func markSessionRead(_ sessionID: String) {
        guard let index = recentSessions.firstIndex(where: { $0.id == sessionID }) else { return }
        recentSessions[index].unreadCount = 0
        syncConversationSession(recentSessions[index])
    }

    private func syncConversationSession(_ session: MasterRecentSession) {
        if conversation?.session.id == session.id {
            conversation?.session = session
        }
    }

    private func upsertSession(_ session: MasterRecentSession) {
        if let index = recentSessions.firstIndex(where: { $0.id == session.id }) {
            recentSessions[index] = session
        } else {
            recentSessions.insert(session, at: 0)
        }
        syncConversationSession(session)
    }

    private func appendAuthorizedMemory(for masterID: String, from message: String, scope: MasterMemoryScope) {
        guard let index = masters.firstIndex(where: { $0.id == masterID }) else { return }
        let newMemory = makeMemoryNote(from: message, scope: scope)
        var profile = masters[index]
        let notes = [newMemory] + profile.memoryNotes.filter { $0.summary != newMemory.summary }
        profile = MasterProfile(
            id: profile.id,
            displayName: profile.displayName,
            title: profile.title,
            tagline: profile.tagline,
            headline: profile.headline,
            domainID: profile.domainID,
            domainTitle: profile.domainTitle,
            sourceLabel: profile.sourceLabel,
            voice: profile.voice,
            adviceStyle: profile.adviceStyle,
            decisionStyle: profile.decisionStyle,
            riskAppetite: profile.riskAppetite,
            expertiseTags: profile.expertiseTags,
            focusTags: profile.focusTags,
            boundaries: profile.boundaries,
            featuredTemplates: profile.featuredTemplates,
            stories: profile.stories,
            memoryNotes: Array(notes.prefix(5)),
            goalSnapshots: profile.goalSnapshots,
            assetBundle: profile.assetBundle,
            portraitSymbol: profile.portraitSymbol,
            palette: profile.palette,
            promptPreview: profile.promptPreview
        )
        masters[index] = profile

    }

    private func buildConsultationResult(
        for members: [MasterProfile],
        issue: String,
        shareScope: MasterMemoryScope
    ) -> MasterConsultationResult {
        let consultationMembers = members.map { profile -> MasterConsultationMember in
            let reply = composeReply(
                for: profile,
                message: issue,
                mode: .mentor,
                memoryScope: shareScope
            )
            return MasterConsultationMember(
                id: "consult-\(profile.id)",
                masterID: profile.id,
                displayName: profile.displayName,
                title: profile.title,
                stance: stanceLabel(for: profile.decisionStyle),
                advice: reply.text,
                storyTitles: reply.referencedStoryTitles,
                ctas: reply.ctas
            )
        }

        let uniqueStances = Array(Set(consultationMembers.map(\.stance))).sorted()
        let conflictSummary: String? = uniqueStances.count > 1
            ? "会诊里同时出现了 \(uniqueStances.joined(separator: " / ")) 两种推进节奏，系统会把冲突显式摊开而不是混成一句空话。"
            : nil

        let mergedSummary = [
            "围绕“\(issue)”，\(members.map(\.displayName).joined(separator: "、"))的共同判断是先把问题写实，再选择一个一周内可验证的小动作。",
            shareScope == .crossMaster
                ? "这次会诊只共享你明确授权的目标、约束与最近状态，不共享全部历史隐私。"
                : "本次会诊没有跨大师共享额外记忆，只基于当前问题和各自故事资产给建议。"
        ]
            .joined(separator: " ")

        let mergedCTAs = uniqueActions(consultationMembers.flatMap(\.ctas))
        return MasterConsultationResult(
            mergedSummary: mergedSummary,
            conflictSummary: conflictSummary,
            members: consultationMembers,
            ctas: mergedCTAs
        )
    }

    private func composeReply(
        for profile: MasterProfile,
        message: String,
        mode: MasterConversationMode,
        memoryScope: MasterMemoryScope
    ) -> MasterMessage {
        let stories = rankedStories(for: profile, query: message)
        let memories = Array(profile.memoryNotes.prefix(memoryScope == .sessionOnly ? 0 : 2))
        let storyLine = stories.isEmpty
            ? "这轮先不强行套故事，而是根据你现在的问题直接拆节奏。"
            : "这让我最先想到“\(stories[0].title)”，因为它正好对应你现在卡住的那根杠杆。"
        let memoryLine = memories.isEmpty
            ? "你这轮还没有授权长期记忆，所以我只根据当前问题给建议。"
            : "我会沿用你授权我记住的 \(memories.map(\.label).joined(separator: "、"))，但不会把它扩散到别的大师。"

        let stance = stanceLabel(for: profile.decisionStyle)
        let opening: String
        switch mode {
        case .storyFirst:
            opening = "\(storyLine) 先借故事搭一个可信的框，再谈动作。"
        case .adviceFirst:
            opening = "我先给结论，再回到故事和边界。你现在最需要的是把问题收成一个可执行动作。"
        case .companion:
            opening = "先别急着证明自己。我们先稳住心气和秩序，再决定下一步向谁表达。"
        case .mentor:
            opening = "别再铺陈背景了，先把这件事拉回到可验证的推进节奏里。"
        }

        let actionLine: String
        switch profile.decisionStyle {
        case "steady_execution":
            actionLine = "今天先定一条底线、一个周目标、一个明天就能开始的动作，不要三线并行。"
        case "act_then_reflect":
            actionLine = "今天就去做一个会带来反馈的小动作，别继续靠想象来拖延。"
        case "small_bets_profit":
            actionLine = "先做一个七天内能算账、能止损的小实验，再决定要不要加大投入。"
        default:
            actionLine = "先稳住表达和关系，再把真正要开口的一句话说出去。"
        }

        let body = [
            "\(profile.displayName)会按“\(profile.adviceStyle)”来回应。",
            opening,
            memoryLine,
            "关于“\(clip(message, limit: 34))”，我的立场是\(stance)。",
            actionLine,
            profile.boundaries.first.map { "别做的是：\($0)。" }
        ]
            .compactMap { $0 }
            .joined(separator: " ")

        return MasterMessage(
            id: "assistant-\(UUID().uuidString)",
            role: .assistant,
            text: body,
            timestamp: "刚刚",
            referencedStoryTitles: stories.map(\.title),
            referencedMemoryLabels: memories.map(\.label),
            ctas: recommendedActions(for: profile, message: message)
        )
    }

    private func rankedStories(for profile: MasterProfile, query: String) -> [MasterStory] {
        let lowered = query.lowercased()
        let scored = profile.stories.map { story in
            let candidates = [story.title, story.summary] + story.beats + story.tags
            let score = candidates.reduce(0) { partial, candidate in
                let normalizedCandidate = candidate.lowercased()
                if lowered.contains(normalizedCandidate) || normalizedCandidate.contains(lowered) {
                    return partial + 4
                }
                let tokens = normalizedCandidate.split(whereSeparator: \.isWhitespace).map(String.init)
                let matchedTokenCount = tokens.filter { !($0.isEmpty) && lowered.contains($0) }.count
                return partial + matchedTokenCount
            }
            return (story, score)
        }

        let sorted = scored.sorted { left, right in
            if left.1 == right.1 { return left.0.title < right.0.title }
            return left.1 > right.1
        }

        return Array(sorted.map(\.0).prefix(2))
    }

    private func recommendedActions(for profile: MasterProfile, message: String) -> [MasterActionRecommendation] {
        let lowered = message.lowercased()
        let primary: MasterActionRecommendation
        if ["求职", "转岗", "简历", "岗位", "招聘", "现金流", "副业"].contains(where: lowered.contains) {
            primary = MasterActionRecommendation(
                id: "cta-earn-\(profile.id)",
                label: "去赚闲能落一个行动",
                reason: "这类问题需要把建议立即转成外部行动或机会撮合。",
                route: "sparelife://earn-social/market?lane=jobSeek&topic=\(profile.displayName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? profile.displayName)",
                target: .earnSocial
            )
        } else if ["关系", "沟通", "朋友", "婚恋", "表达", "消息"].contains(where: lowered.contains) {
            primary = MasterActionRecommendation(
                id: "cta-msg-\(profile.id)",
                label: "去消息页写行动清单",
                reason: "这类问题更适合把要说的话和后续联系节奏落到具体消息里。",
                route: "sparelife://messages/self?draft=\(clip(message, limit: 28).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")",
                target: .messages
            )
        } else {
            primary = MasterActionRecommendation(
                id: "cta-profile-\(profile.id)",
                label: "去我的页检查记忆授权",
                reason: "先把目标、约束和隐私边界写准，后续大师回复会更稳定。",
                route: "sparelife://my/profile?highlight=memory",
                target: .profile
            )
        }

        let secondary = MasterActionRecommendation(
            id: "cta-memory-\(profile.id)",
            label: "回到大师页继续追问",
            reason: "先执行一个动作，再回来继续沿着这位大师的上下文追问。",
            route: "sparelife://masters/home?domain=\(profile.domainID)",
            target: .masters
        )

        return uniqueActions([primary, secondary])
    }

    private func makeMemoryNote(from message: String, scope: MasterMemoryScope) -> MasterMemoryNote {
        let summary: String
        let label: String
        if ["目标", "想", "希望", "计划", "准备", "拿到", "完成"].contains(where: message.contains) {
            label = "目标"
            summary = "目标：\(clip(message, limit: 30))"
        } else if ["之前", "过去", "曾经", "履历", "经历"].contains(where: message.contains) {
            label = "经历"
            summary = "经历：\(clip(message, limit: 30))"
        } else if ["焦虑", "担心", "预算", "压力", "风险", "家里"].contains(where: message.contains) {
            label = "约束"
            summary = "约束：\(clip(message, limit: 30))"
        } else {
            label = "近况"
            summary = "近况：\(clip(message, limit: 30))"
        }

        return MasterMemoryNote(
            id: "memory-\(UUID().uuidString)",
            label: label,
            summary: summary,
            scope: scope,
            updatedAt: "刚刚",
            isSensitive: label == "约束"
        )
    }

    private func uniqueActions(_ actions: [MasterActionRecommendation]) -> [MasterActionRecommendation] {
        var seen = Set<String>()
        return actions.filter { action in
            let key = "\(action.label)|\(action.route)"
            return seen.insert(key).inserted
        }
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func searchable(_ value: String) -> String {
        trimmed(value).lowercased()
    }

    private func clip(_ value: String, limit: Int) -> String {
        guard value.count > limit else { return value }
        return String(value.prefix(limit)) + "…"
    }

    private func stanceLabel(for decisionStyle: String) -> String {
        switch decisionStyle {
        case "act_then_reflect":
            return "先行动后校准"
        case "small_bets_profit":
            return "先算账再放大"
        case "resilient_expression":
            return "先稳情绪再表达"
        default:
            return "先立边界再推进"
        }
    }
}

private struct MasterSeedCatalog {
    let domains: [MasterDomain]
    let masters: [MasterProfile]
    let sessions: [MasterRecentSession]
    let cachedMasters: [MasterProfile]
    let cachedSessions: [MasterRecentSession]
    let adoptedActionIDs: Set<String>

    static func make() -> MasterSeedCatalog {
        let domains = [
            MasterDomain(id: "career", title: "职业跃迁", description: "帮你拆转岗、求职、现金流与长期职业布局。", symbol: "briefcase.fill"),
            MasterDomain(id: "leadership", title: "统筹执行", description: "把复杂目标拆成稳得住的推进节奏。", symbol: "list.bullet.clipboard.fill"),
            MasterDomain(id: "mindset", title: "决断与校准", description: "当目标模糊或犹豫拖延时，先校准再行动。", symbol: "scope"),
            MasterDomain(id: "life", title: "关系与韧性", description: "处理情绪、表达、关系和人生低谷。", symbol: "heart.text.square.fill")
        ]

        let bundle = MasterAssetBundleInfo(
            bundleID: "sparelife_masters_foundation_cn",
            version: "2026.03.25",
            portraitPackage: "master_portraits/*.svg",
            characterFields: ["name", "description", "good_at", "speech_style", "relationship_with_player"],
            storyFields: ["story_id", "title", "description", "story_beats", "cover_image_portrait"],
            manifestFields: ["master_domain", "master_sort_order", "is_featured", "status"],
            importNote: "资产包由后台幂等导入，App 仅消费、缓存和展示，不提供端侧编辑入口。",
            isOfficial: true
        )

        let zeng = MasterProfile(
            id: "zeng-guofan",
            displayName: "曾国藩",
            title: "统筹与带队顾问",
            tagline: "擅长从混乱中立规矩，把大目标拆成可执行的周节奏。",
            headline: "先结硬寨，后打呆仗。",
            domainID: "leadership",
            domainTitle: "统筹执行",
            sourceLabel: "真专家映射分身",
            voice: "克制、具体、强调边界与节奏。",
            adviceStyle: "先定边界，再把目标拆进周节奏",
            decisionStyle: "steady_execution",
            riskAppetite: "steady",
            expertiseTags: ["带队", "执行", "复盘", "求职", "转岗"],
            focusTags: ["AI 产品", "周计划", "简历叙事"],
            boundaries: ["不要用夸大包装换取短期通过", "不要同时并行三条以上主线"],
            featuredTemplates: [
                MasterQuestionTemplate(id: "z1", title: "把目标拆进周节奏", prompt: "我想在八周内完成转岗准备，请帮我把目标拆成每周节奏。", mode: .adviceFirst),
                MasterQuestionTemplate(id: "z2", title: "带队先立什么规矩", prompt: "我要带一个混乱的小团队，第一周应该先立哪些规矩？", mode: .storyFirst)
            ],
            stories: [
                MasterStory(id: "xiang", title: "湘军重建", summary: "先立军纪，再扩编成可持续作战的队伍。", beats: ["从最可信的一小批人开始", "用军纪和复盘机制替代情绪动员", "打一仗固化一次经验"], tags: ["带队", "执行", "纪律"]),
                MasterStory(id: "letters", title: "家书复盘法", summary: "靠长期书写和复盘修正急躁与失序。", beats: ["先看自己是否越界或贪快", "每天只抓一两个改进点", "让复盘成为长期机制"], tags: ["复盘", "习惯", "节奏"]),
                MasterStory(id: "late", title: "屡败后的迟熟成才", summary: "反复受挫后才逐渐建立系统能力。", beats: ["承认自己不是短跑型选手", "失败先当校准", "长期积累比一次惊艳更重要"], tags: ["挫折", "成长", "长期主义"])
            ],
            memoryNotes: [
                MasterMemoryNote(id: "zm1", label: "目标", summary: "目标：8 周内完成 AI 产品转岗准备。", scope: .masterOnly, updatedAt: "昨天", isSensitive: false),
                MasterMemoryNote(id: "zm2", label: "约束", summary: "约束：现金流只够支撑 3 个月。", scope: .masterOnly, updatedAt: "前天", isSensitive: true)
            ],
            goalSnapshots: [
                MasterGoalSnapshot(id: "zg1", title: "AI 产品转岗", nextAction: "本周完成两段可复用项目叙事。", status: "进行中", updatedAt: "昨天")
            ],
            assetBundle: bundle,
            portraitSymbol: "shield.lefthalf.filled",
            palette: [Color(red: 0.09, green: 0.13, blue: 0.19), Color(red: 0.84, green: 0.69, blue: 0.42)],
            promptPreview: "先复述用户当前目标，再结合记忆和故事材料给出三步执行建议。"
        )

        let yangming = MasterProfile(
            id: "wang-yangming",
            displayName: "王阳明",
            title: "决断与知行顾问",
            tagline: "擅长在焦虑和犹豫里找到那个立刻可做的第一步。",
            headline: "知是行之始，行是知之成。",
            domainID: "mindset",
            domainTitle: "决断与校准",
            sourceLabel: "真专家映射分身",
            voice: "直接、点破犹豫，把抽象念头压成行动。",
            adviceStyle: "先破除自我设限，再要求今天就有动作",
            decisionStyle: "act_then_reflect",
            riskAppetite: "experimental",
            expertiseTags: ["决断", "行动", "拖延", "创业", "转岗"],
            focusTags: ["校准", "AI 学习", "突破犹豫"],
            boundaries: ["不要把思考伪装成行动", "不要靠拖延来维持安全感"],
            featuredTemplates: [
                MasterQuestionTemplate(id: "y1", title: "今天就能开始的一步", prompt: "我已经纠结很久了，请帮我找出今天就能开始的一步。", mode: .mentor),
                MasterQuestionTemplate(id: "y2", title: "破除自我设限", prompt: "我总觉得自己不够格，怎么识别是真风险还是自我设限？", mode: .companion)
            ],
            stories: [
                MasterStory(id: "dragon", title: "龙场悟道", summary: "把外部困局转成内在秩序。", beats: ["环境越差越要收回注意力", "心安来自做正确的事", "先行动，秩序才会长出来"], tags: ["困境", "行动", "心态"]),
                MasterStory(id: "campaign", title: "南赣平乱", summary: "复杂局面先抓关键矛盾。", beats: ["先抓一个关键杠杆", "用行动验证判断", "边做边修正"], tags: ["决断", "杠杆", "实验"]),
                MasterStory(id: "students", title: "给弟子的知行要求", summary: "别把抽象理解当成完成任务。", beats: ["每次卡住都问今天能做什么", "行动会逼出真正问题", "理解不等于完成"], tags: ["拖延", "学习", "行动"])
            ],
            memoryNotes: [
                MasterMemoryNote(id: "ym1", label: "近况", summary: "近况：正在犹豫是否辞职转岗。", scope: .masterOnly, updatedAt: "2 小时前", isSensitive: false)
            ],
            goalSnapshots: [
                MasterGoalSnapshot(id: "yg1", title: "把犹豫压成行动", nextAction: "今天完成 1 次岗位拆解和 1 封请教消息。", status: "待启动", updatedAt: "今天")
            ],
            assetBundle: bundle,
            portraitSymbol: "bolt.heart.fill",
            palette: [Color(red: 0.13, green: 0.20, blue: 0.24), Color(red: 0.84, green: 0.89, blue: 0.72)],
            promptPreview: "指出用户真正卡住的执念，并给出今天就能执行的一步。"
        )

        let daosheng = MasterProfile(
            id: "daosheng-hefu",
            displayName: "稻盛和夫",
            title: "经营与职业跃迁顾问",
            tagline: "擅长把理想、现金流和长期能力放到同一张账里看。",
            headline: "付出不亚于任何人的努力，但先把账算清楚。",
            domainID: "career",
            domainTitle: "职业跃迁",
            sourceLabel: "真专家映射分身",
            voice: "冷静算账，强调可持续、诚实和长期积累。",
            adviceStyle: "先算现金流与验证成本，再扩大投入",
            decisionStyle: "small_bets_profit",
            riskAppetite: "steady",
            expertiseTags: ["经营", "求职", "职业选择", "现金流", "AI 产品经理"],
            focusTags: ["转岗", "作品集", "机会评估"],
            boundaries: ["不要用透支现金流来换虚假的职业跃迁", "不要把短期热闹当成长期壁垒"],
            featuredTemplates: [
                MasterQuestionTemplate(id: "d1", title: "算七天验证账", prompt: "我想转岗 AI 产品，但现金流有限，请帮我先算七天验证账。", mode: .adviceFirst),
                MasterQuestionTemplate(id: "d2", title: "先拿什么小订单", prompt: "如果我想先验证能力，第一批小机会应该怎么选？", mode: .storyFirst)
            ],
            stories: [
                MasterStory(id: "kyocera", title: "京瓷第一批订单", summary: "先拿下能证明团队可靠性的第一批订单。", beats: ["先验证能力的小机会", "交付形成信誉资产", "现金流跟着成长走"], tags: ["创业", "现金流", "作品集"]),
                MasterStory(id: "amoeba", title: "阿米巴经营", summary: "把大组织拆成可核算的小单元。", beats: ["目标越大越要拆单元", "每一步投入都有验证指标", "职责清楚成长才可持续"], tags: ["经营", "指标", "优先级"]),
                MasterStory(id: "jal", title: "日航重整", summary: "先恢复基本秩序和现金安全。", beats: ["先稳住基本盘", "让团队先看到短周期改善", "秩序恢复后再谈升级"], tags: ["止损", "现金流", "秩序"])
            ],
            memoryNotes: [
                MasterMemoryNote(id: "ds1", label: "目标", summary: "目标：3 个月内拿到至少 2 个 AI 产品面试。", scope: .masterOnly, updatedAt: "昨天", isSensitive: false),
                MasterMemoryNote(id: "ds2", label: "经历", summary: "经历：当前在运营岗，缺少完整项目案例。", scope: .masterOnly, updatedAt: "昨天", isSensitive: false)
            ],
            goalSnapshots: [
                MasterGoalSnapshot(id: "dg1", title: "转岗面试", nextAction: "先做 1 个能证明能力的小项目并形成案例页。", status: "进行中", updatedAt: "昨天")
            ],
            assetBundle: bundle,
            portraitSymbol: "chart.line.uptrend.xyaxis",
            palette: [Color(red: 0.11, green: 0.18, blue: 0.27), Color(red: 0.91, green: 0.78, blue: 0.43)],
            promptPreview: "把用户目标、记忆、故事证据放进一张经营账里，给出优先级和止损线。"
        )

        let sushi = MasterProfile(
            id: "su-shi",
            displayName: "苏轼",
            title: "韧性与表达顾问",
            tagline: "擅长在低谷里稳住心气，也帮你把难说的话说得更有人味。",
            headline: "此心安处是吾乡。",
            domainID: "life",
            domainTitle: "关系与韧性",
            sourceLabel: "真专家映射分身",
            voice: "豁达但不空泛，总能把苦处化成可承受的节奏。",
            adviceStyle: "先稳住心气和表达，再安排外部动作",
            decisionStyle: "resilient_expression",
            riskAppetite: "balanced",
            expertiseTags: ["低谷", "表达", "关系", "韧性", "职业低潮"],
            focusTags: ["沟通", "复原力", "生活秩序"],
            boundaries: ["不要在情绪最满的时候做最终决定", "不要把一时失意写成永久身份"],
            featuredTemplates: [
                MasterQuestionTemplate(id: "s1", title: "低谷时怎么开口", prompt: "我最近状态很差，但又需要和重要的人沟通，怎么开这个口？", mode: .companion),
                MasterQuestionTemplate(id: "s2", title: "先稳住心气", prompt: "我有点被一次失败钉住了，怎样先把日常秩序搭起来？", mode: .storyFirst)
            ],
            stories: [
                MasterStory(id: "wutai", title: "乌台诗案后的重建", summary: "重大打击后先重建生活秩序和表达方式。", beats: ["先把生活秩序搭起来", "表达方式可以调整", "低谷不是永久身份"], tags: ["低谷", "韧性", "表达"]),
                MasterStory(id: "chibi", title: "赤壁夜游", summary: "在失意中重建视角。", beats: ["当下成败不必立刻定义人生", "拉长时间尺度", "先稳住心再判断"], tags: ["尺度", "情绪", "关系"]),
                MasterStory(id: "hainan", title: "海南晚年", summary: "继续写作、交往和生活，让自己保持生成感。", beats: ["留下和世界连接的动作", "关系和表达是恢复心气的重要抓手", "只要还在生成就没被彻底打败"], tags: ["连接", "恢复", "表达"])
            ],
            memoryNotes: [
                MasterMemoryNote(id: "ss1", label: "约束", summary: "约束：最近情绪波动大，不想把负面情绪带给伴侣。", scope: .masterOnly, updatedAt: "今天", isSensitive: true)
            ],
            goalSnapshots: [
                MasterGoalSnapshot(id: "sg1", title: "关系修复", nextAction: "先写一段不带指责的真实近况，再约一次轻量沟通。", status: "待启动", updatedAt: "今天")
            ],
            assetBundle: bundle,
            portraitSymbol: "leaf.fill",
            palette: [Color(red: 0.15, green: 0.19, blue: 0.28), Color(red: 0.85, green: 0.76, blue: 0.55)],
            promptPreview: "先帮用户稳住心气，再给一个能向外表达的动作。"
        )

        let sessions = [
            MasterRecentSession(
                id: "recent-daosheng",
                masterID: daosheng.id,
                displayName: daosheng.displayName,
                title: daosheng.title,
                topic: "转岗 AI 产品但现金流紧",
                preview: "先做七天验证账，再决定是否全职投入。",
                unreadCount: 2,
                lastMessageAt: "09:10",
                isPinned: true,
                seedMessages: [
                    MasterMessage(id: "dmsg1", role: .assistant, text: "我们先不急着辞职，先把现金流和验证成本算清楚。", timestamp: "昨天", referencedStoryTitles: ["京瓷第一批订单"], referencedMemoryLabels: ["目标"], ctas: [])
                ]
            ),
            MasterRecentSession(
                id: "recent-sushi",
                masterID: sushi.id,
                displayName: sushi.displayName,
                title: sushi.title,
                topic: "情绪低谷里如何说真话",
                preview: "先把难受写成一句不带指责的话，再决定和谁说。",
                unreadCount: 0,
                lastMessageAt: "昨天",
                isPinned: false,
                seedMessages: [
                    MasterMessage(id: "smsg1", role: .assistant, text: "先别急着解释自己，先把情绪落到一句能对外表达的话。", timestamp: "昨天", referencedStoryTitles: ["乌台诗案后的重建"], referencedMemoryLabels: ["约束"], ctas: [])
                ]
            ),
            MasterRecentSession(
                id: "recent-zeng",
                masterID: zeng.id,
                displayName: zeng.displayName,
                title: zeng.title,
                topic: "把求职准备拆进周计划",
                preview: "一周只抓最关键的两个动作，不要三线并行。",
                unreadCount: 1,
                lastMessageAt: "周二",
                isPinned: false,
                seedMessages: [
                    MasterMessage(id: "zmsg1", role: .assistant, text: "这周先完成项目叙事和 2 次岗位拆解，不求面面俱到。", timestamp: "周二", referencedStoryTitles: ["家书复盘法"], referencedMemoryLabels: ["目标"], ctas: [])
                ]
            )
        ]

        return MasterSeedCatalog(
            domains: domains,
            masters: [zeng, yangming, daosheng, sushi],
            sessions: sessions,
            cachedMasters: [zeng, daosheng, sushi],
            cachedSessions: Array(sessions.prefix(2)),
            adoptedActionIDs: []
        )
    }
}
