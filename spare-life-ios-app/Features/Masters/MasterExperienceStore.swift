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
            return "优先展示通过服务端目录索引到本地角色资产的 Stage 1 大师目录。"
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

enum MasterCatalogAccessPolicy: String, Equatable {
    case browseAndChatOnly

    var title: String {
        switch self {
        case .browseAndChatOnly:
            return "大师目录只读"
        }
    }

    var detail: String {
        switch self {
        case .browseAndChatOnly:
            return "Stage 1 只允许浏览目录并进入一对一对话。字段固定来自 ./assets/char，图片固定来自 ./assets/assets；不能在端侧新建、删除或编辑大师资产。"
        }
    }

    var allowsMasterMutation: Bool {
        false
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
    let directoryManifestPath: String
    let characterFields: [String]
    let storyFields: [String]
    let manifestFields: [String]
    let importNote: String
    let isOfficial: Bool
    let characterAssetPath: String
    let imageDirectoryPath: String
    let mappedImageFiles: [String]
}

struct MasterImageSet: Hashable {
    let assetID: String
    let avatarPath: String
    let portraitPath: String
    let backgroundPath: String
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
    var memoryNotes: [MasterMemoryNote]
    var goalSnapshots: [MasterGoalSnapshot]
    let assetBundle: MasterAssetBundleInfo
    let portraitSymbol: String
    let palette: [Color]
    let promptPreview: String
    let imageSet: MasterImageSet
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
    var serviceStatus: MasterConversationServiceStatus
    var messages: [MasterMessage]
    var prefilledPrompt: String
    var isReplying: Bool
    var inlineError: String?
}

struct MasterRoutePreview: Identifiable, Hashable {
    let id: String
    let action: MasterActionRecommendation
    let sourceTitle: String
}

struct MasterCatalogCoverage: Hashable {
    let directoryManifestPath: String
    let characterRootPath: String
    let imageRootPath: String
    let serviceDirectoryAssetIDs: [String]
    let localCharacterAssetIDs: [String]
    let localImageAssetIDs: [String]
    let matchedAssetIDs: [String]
    let mappedImageFiles: [String]

    var directoryManifestName: String {
        URL(fileURLWithPath: directoryManifestPath).lastPathComponent
    }

    var fieldSourceDisplayPath: String {
        "./assets/char"
    }

    var imageSourceDisplayPath: String {
        "./assets/assets"
    }

    var imageIndexDisplayPath: String {
        "./assets/assets/char"
    }

    var matchedAssetCount: Int {
        matchedAssetIDs.count
    }

    var serviceDirectoryAssetCount: Int {
        serviceDirectoryAssetIDs.count
    }

    var localCharacterAssetCount: Int {
        localCharacterAssetIDs.count
    }

    var localImageAssetCount: Int {
        localImageAssetIDs.count
    }

    var hasExactStage1Coverage: Bool {
        serviceDirectoryAssetIDs == matchedAssetIDs &&
        localCharacterAssetIDs == matchedAssetIDs &&
        localImageAssetIDs == matchedAssetIDs
    }

    var indexCoverageSummary: String {
        "目录\(serviceDirectoryAssetCount) · 字段\(localCharacterAssetCount) · 图片\(localImageAssetCount)"
    }

    var mappingSummary: String {
        "\(matchedAssetCount)/\(serviceDirectoryAssetCount) 已匹配"
    }
}

@MainActor
final class MasterExperienceStore: ObservableObject {
    private static let directoryPageSize = 8

    @Published var query = ""
    @Published var selectedDomainID: String? = nil
    @Published var catalogSourceMode: MasterCatalogSourceMode = .synced
    @Published private(set) var isLoading = false
    @Published private(set) var degradedMessage: String? = nil
    @Published private(set) var fatalErrorMessage: String? = nil
    @Published private(set) var domains: [MasterDomain] = []
    @Published private(set) var domainIndex: [String: MasterDomain] = [:]
    @Published private(set) var masters: [MasterProfile] = []
    @Published private(set) var masterIndex: [String: Int] = [:]
    @Published private(set) var catalogCoverage: MasterCatalogCoverage? = nil
    @Published private(set) var recentSessions: [MasterRecentSession] = []
    @Published private(set) var conversationServiceStatus: MasterConversationServiceStatus = .fallback(
        detail: "当前还没有加载到大师对话服务状态。"
    )
    @Published private(set) var visibleDirectoryMasterCount = 0
    @Published var conversation: MasterConversationDraft? = nil
    @Published var consultation: MasterConsultationDraft? = nil
    @Published var routePreview: MasterRoutePreview? = nil

    private var hasLoaded = false
    private let catalogLoader: () throws -> MasterCatalogSnapshot
    private let conversationService: MasterConversationReplying
    private let localStateStore: MasterConversationLocalStateStore
    let catalogAccessPolicy: MasterCatalogAccessPolicy = .browseAndChatOnly
    private var sessionTranscripts: [String: [MasterMessage]] = [:]

    init(
        catalogLoader: @escaping () throws -> MasterCatalogSnapshot = { try MasterCatalogLoader.load() },
        conversationService: MasterConversationReplying? = nil,
        localStateStore: MasterConversationLocalStateStore = MasterConversationLocalStateStore()
    ) {
        self.catalogLoader = catalogLoader
        let resolvedConversationService = conversationService ?? AnthropicMasterConversationService()
        self.conversationService = resolvedConversationService
        self.localStateStore = localStateStore
        self.conversationServiceStatus = resolvedConversationService.status
    }

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

    var directoryMasters: [MasterProfile] {
        filteredMasters
    }

    var visibleDirectoryMasters: [MasterProfile] {
        Array(filteredMasters.prefix(visibleDirectoryMasterCount))
    }

    var hasMoreDirectoryMastersToLoad: Bool {
        visibleDirectoryMasterCount < filteredMasters.count
    }

    var recentStripSessions: [MasterRecentSession] {
        Array(prioritizedSessions.prefix(6))
    }

    var showCacheBanner: Bool {
        degradedMessage != nil || catalogSourceMode == .cached
    }

    var directoryManifestName: String {
        if let catalogCoverage {
            return catalogCoverage.directoryManifestName
        }
        guard let path = masters.first?.assetBundle.directoryManifestPath else {
            return "master_service_directory.json"
        }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    var resourceMappingSummary: String {
        catalogCoverage?.mappingSummary ?? "\(masters.count)/8 已匹配"
    }

    func master(withID id: String) -> MasterProfile? {
        guard let position = masterIndex[id], masters.indices.contains(position) else {
            return nil
        }
        return masters[position]
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
        conversationServiceStatus = conversationService.status

        let previousMasters = Dictionary(uniqueKeysWithValues: masters.map { ($0.id, $0) })
        let previousSessions = recentSessions
        let previousTranscripts = sessionTranscripts
        let persistedState: MasterConversationLocalState
        do {
            persistedState = try localStateStore.load()
        } catch {
            persistedState = .empty
        }

        do {
            let snapshot = try catalogLoader()
            catalogSourceMode = .synced
            domains = snapshot.domains
            domainIndex = snapshot.domainIndex
            let mergedMasters = snapshot.masters.map { incoming -> MasterProfile in
                var merged = incoming
                if let existing = previousMasters[incoming.id] {
                    if !existing.memoryNotes.isEmpty {
                        merged.memoryNotes = existing.memoryNotes
                    }
                    if !existing.goalSnapshots.isEmpty {
                        merged.goalSnapshots = existing.goalSnapshots
                    }
                } else if let persistedNotes = persistedState.memoryNotesByMasterID[incoming.id], !persistedNotes.isEmpty {
                    merged.memoryNotes = persistedNotes
                }

                return merged
            }
            masters = mergedMasters
            masterIndex = Dictionary(uniqueKeysWithValues: mergedMasters.enumerated().map { ($1.id, $0) })
            catalogCoverage = snapshot.catalogCoverage
            let persistedSessions = persistedState.recentSessions.compactMap { session -> MasterRecentSession? in
                guard let position = masterIndex[session.masterID], masters.indices.contains(position) else {
                    return nil
                }
                return session.materialize(seedMessages: seedMessages(for: masters[position]))
            }
            let preferredSessions = snapshot.sessions.isEmpty
                ? (previousSessions.isEmpty ? persistedSessions : previousSessions)
                : snapshot.sessions
            recentSessions = preferredSessions.filter { masterIndex[$0.masterID] != nil }
            sessionTranscripts = previousTranscripts
            let validSessionIDs = Set(recentSessions.map(\.id))
            for (sessionID, messages) in persistedState.sessionTranscripts where validSessionIDs.contains(sessionID) {
                if sessionTranscripts[sessionID] == nil || sessionTranscripts[sessionID]?.isEmpty == true {
                    sessionTranscripts[sessionID] = messages
                }
            }
        } catch {
            catalogSourceMode = .unavailable
            domains = []
            domainIndex = [:]
            masters = []
            masterIndex = [:]
            catalogCoverage = nil
            recentSessions = previousSessions
            sessionTranscripts = previousTranscripts
            visibleDirectoryMasterCount = 0
            fatalErrorMessage = error.localizedDescription
        }

        if let selectedDomainID, domainIndex[selectedDomainID] == nil {
            self.selectedDomainID = nil
        }

        resetDirectoryPagination()

        isLoading = false
        persistLocalState()
    }

    func applyCatalogSourceMode(_ mode: MasterCatalogSourceMode) {
        catalogSourceMode = mode
        Task { await refreshCatalog() }
    }

    func togglePinned(_ session: MasterRecentSession) {
        guard let index = recentSessions.firstIndex(where: { $0.id == session.id }) else { return }
        recentSessions[index].isPinned.toggle()
        syncConversationSession(recentSessions[index])
        persistLocalState()
    }

    func resetDirectoryPagination() {
        visibleDirectoryMasterCount = min(filteredMasters.count, Self.directoryPageSize)
    }

    func loadNextDirectoryBatchIfNeeded(after profile: MasterProfile) {
        guard hasMoreDirectoryMastersToLoad,
              visibleDirectoryMasters.last?.id == profile.id else {
            return
        }

        visibleDirectoryMasterCount = min(
            filteredMasters.count,
            visibleDirectoryMasterCount + Self.directoryPageSize
        )
    }

    func openConversation(for profile: MasterProfile, template: MasterQuestionTemplate? = nil) {
        let existingSession = recentSessions.first(where: { $0.masterID == profile.id })
        let defaultSeedMessages = seedMessages(for: profile)
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
            seedMessages: defaultSeedMessages
        )

        conversation = MasterConversationDraft(
            id: session.id,
            masterID: profile.id,
            session: session,
            mode: template?.mode ?? .storyFirst,
            memoryScope: .masterOnly,
            serviceStatus: conversationServiceStatus,
            messages: sessionTranscripts[session.id] ?? session.seedMessages.nonEmpty ?? defaultSeedMessages,
            prefilledPrompt: template?.prompt ?? "",
            isReplying: false,
            inlineError: nil
        )
    }

    func restoreSession(_ session: MasterRecentSession) {
        guard let profile = master(withID: session.masterID) else { return }
        let defaultSeedMessages = seedMessages(for: profile)
        conversation = MasterConversationDraft(
            id: session.id,
            masterID: profile.id,
            session: session,
            mode: .storyFirst,
            memoryScope: .masterOnly,
            serviceStatus: conversationServiceStatus,
            messages: sessionTranscripts[session.id] ?? session.seedMessages.nonEmpty ?? defaultSeedMessages,
            prefilledPrompt: "",
            isReplying: false,
            inlineError: nil
        )
        markSessionRead(session.id)
    }

    func clearMemories(for masterID: String) {
        guard let index = masterIndex[masterID], masters.indices.contains(index) else { return }
        masters[index].memoryNotes = []

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
            if let conversation {
                sessionTranscripts[conversation.session.id] = conversation.messages
                persistLocalState()
            }
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
        sessionTranscripts[conversation.session.id] = conversation.messages
        persistLocalState()

        try? await Task.sleep(nanoseconds: 420_000_000)

        if catalogSourceMode == .unavailable {
            conversation.isReplying = false
            conversation.inlineError = "这次请求没能发出去，因为目录同步失败且没有缓存。请先回到首页恢复内容源。"
            self.conversation = conversation
            return
        }

        let relevantStories = rankedStories(for: profile, query: text)
        let authorizedMemories = Array(profile.memoryNotes.prefix(conversation.memoryScope == .sessionOnly ? 0 : 3))
        let reply: MasterMessage
        do {
            let remoteReply = try await conversationService.generateReply(
                for: MasterConversationRequest(
                    profile: profile,
                    mode: conversation.mode,
                    memoryScope: conversation.memoryScope,
                    authorizedMemories: authorizedMemories,
                    relevantStories: relevantStories,
                    recentMessages: conversation.messages
                )
            )
            conversation.serviceStatus = remoteReply.status
            conversationServiceStatus = remoteReply.status
            reply = MasterMessage(
                id: "assistant-\(UUID().uuidString)",
                role: .assistant,
                text: remoteReply.text,
                timestamp: "刚刚",
                referencedStoryTitles: relevantStories.map(\.title),
                referencedMemoryLabels: authorizedMemories.map(\.label),
                ctas: recommendedActions(for: profile, message: text)
            )
        } catch {
            let fallbackStatus = MasterConversationServiceStatus.fallback(
                detail: "实时大师服务这轮不可用，已回退到本地故事与记忆引擎继续回复。原因：\(error.localizedDescription)"
            )
            conversation.serviceStatus = fallbackStatus
            conversationServiceStatus = fallbackStatus
            reply = composeReply(
                for: profile,
                message: text,
                mode: conversation.mode,
                memoryScope: conversation.memoryScope
            )
        }

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
        sessionTranscripts[conversation.session.id] = conversation.messages
        persistLocalState()
    }

    func presentRoutePreview(_ action: MasterActionRecommendation, sourceTitle: String) {
        routePreview = MasterRoutePreview(id: action.id, action: action, sourceTitle: sourceTitle)
    }

    func isActionAdopted(_ actionID: String) -> Bool {
        adoptedActionIDs.contains(actionID)
    }

    func markActionAdopted(_ actionID: String) {
        adoptedActionIDs.insert(actionID)
    }

    private var adoptedActionIDs: Set<String> = []

    private func seedMessages(for profile: MasterProfile) -> [MasterMessage] {
        [
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
    }

    private func persistLocalState() {
        do {
            try localStateStore.save(
                recentSessions: recentSessions,
                sessionTranscripts: sessionTranscripts,
                masters: masters
            )
        } catch {
            // Local persistence is best-effort. UI state should stay usable even if writing fails.
        }
    }

    private func markSessionRead(_ sessionID: String) {
        guard let index = recentSessions.firstIndex(where: { $0.id == sessionID }) else { return }
        recentSessions[index].unreadCount = 0
        syncConversationSession(recentSessions[index])
        persistLocalState()
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
        persistLocalState()
    }

    private func appendAuthorizedMemory(for masterID: String, from message: String, scope: MasterMemoryScope) {
        guard let index = masterIndex[masterID], masters.indices.contains(index) else { return }
        let newMemory = makeMemoryNote(from: message, scope: scope)
        let notes = [newMemory] + masters[index].memoryNotes.filter { $0.summary != newMemory.summary }
        masters[index].memoryNotes = Array(notes.prefix(5))
        persistLocalState()
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

struct MasterCatalogSnapshot {
    let domains: [MasterDomain]
    let domainIndex: [String: MasterDomain]
    let masters: [MasterProfile]
    let masterIndex: [String: Int]
    let catalogCoverage: MasterCatalogCoverage
    let sessions: [MasterRecentSession]
}

private struct MasterDirectoryIndexCoverage {
    let serviceDirectoryAssetIDs: [String]
    let localCharacterAssetIDs: [String]
    let localImageAssetIDs: [String]
}

enum MasterCatalogLoader {
    private static let stage1MasterAssetIDs: Set<String> = [
        "001546",
        "001550",
        "001560",
        "001565",
        "001567",
        "001570",
        "001572",
        "001580"
    ]
    private static let requiredImageFiles = ["avatar.png", "image.png", "background.jpg"]

    static func load() throws -> MasterCatalogSnapshot {
        let roots = try resolveAssetRoots()
        let serviceDirectory = try MasterServiceDirectory.load()
        let domainLookup = Dictionary(uniqueKeysWithValues: serviceDirectory.domains.map { ($0.id, $0) })
        let decoder = JSONDecoder()
        let indexCoverage = try validateStage1AssetCoverage(serviceDirectory: serviceDirectory, roots: roots)

        let masters = try serviceDirectory.entries
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { entry -> MasterProfile in
                guard let domain = domainLookup[entry.domainID] else {
                    throw MasterCatalogLoadError.directory("未知的大师领域：\(entry.domainID)")
                }

                let characterURL = roots.charDirectory.appendingPathComponent("\(entry.assetID).json")
                guard FileManager.default.fileExists(atPath: characterURL.path) else {
                    throw MasterCatalogLoadError.missingCharacter(entry.assetID)
                }

                let imageDirectory = roots.imageDirectory.appendingPathComponent(entry.assetID, isDirectory: true)
                try validateImageDirectory(at: imageDirectory, assetID: entry.assetID)
                let avatarPath = imageDirectory.appendingPathComponent(requiredImageFiles[0]).path
                let portraitPath = imageDirectory.appendingPathComponent(requiredImageFiles[1]).path
                let backgroundPath = imageDirectory.appendingPathComponent(requiredImageFiles[2]).path

                let data = try Data(contentsOf: characterURL)
                let document: MasterCharacterResourceDocument
                do {
                    document = try decoder.decode(MasterCharacterResourceDocument.self, from: data)
                } catch {
                    throw MasterCatalogLoadError.invalidCharacter(entry.assetID, error.localizedDescription)
                }

                let internalAssetID = String(format: "%06d", document.metadata.id)
                guard internalAssetID == entry.assetID else {
                    throw MasterCatalogLoadError.mismatchedCharacterIdentifier(
                        expected: entry.assetID,
                        actual: internalAssetID
                    )
                }

                return makeProfile(
                    entry: entry,
                    domain: domain,
                    document: document,
                    characterURL: characterURL,
                    imageDirectory: imageDirectory,
                    directoryManifestPath: serviceDirectory.sourceURL.path,
                    imageSet: MasterImageSet(
                        assetID: entry.assetID,
                        avatarPath: avatarPath,
                        portraitPath: portraitPath,
                        backgroundPath: backgroundPath
                    )
                )
            }

        let masterIndex = Dictionary(uniqueKeysWithValues: masters.enumerated().map { ($1.id, $0) })
        return MasterCatalogSnapshot(
            domains: serviceDirectory.domains,
            domainIndex: domainLookup,
            masters: masters,
            masterIndex: masterIndex,
            catalogCoverage: MasterCatalogCoverage(
                directoryManifestPath: serviceDirectory.sourceURL.path,
                characterRootPath: roots.charDirectory.path,
                imageRootPath: roots.imageDirectory.path,
                serviceDirectoryAssetIDs: indexCoverage.serviceDirectoryAssetIDs,
                localCharacterAssetIDs: indexCoverage.localCharacterAssetIDs,
                localImageAssetIDs: indexCoverage.localImageAssetIDs,
                matchedAssetIDs: masters.map(\.id).sorted(),
                mappedImageFiles: requiredImageFiles
            ),
            sessions: []
        )
    }

    private static func validateStage1AssetCoverage(
        serviceDirectory: MasterServiceDirectory.DirectorySnapshot,
        roots: MasterAssetRoots
    ) throws -> MasterDirectoryIndexCoverage {
        let directoryAssetIDs = serviceDirectory.entries.map(\.assetID).sorted()
        let directoryAssetIDSet = Set(directoryAssetIDs)
        guard directoryAssetIDSet == stage1MasterAssetIDs else {
            throw MasterCatalogLoadError.directory(
                mismatchMessage(
                    title: "大师目录索引必须固定命中 Stage 1 的 8 位大师",
                    expected: stage1MasterAssetIDs,
                    actual: directoryAssetIDSet
                )
            )
        }

        let localCharacterAssetIDs = Array(try resourceFileIDs(in: roots.charDirectory, pathExtension: "json")).sorted()
        let localCharacterAssetIDSet = Set(localCharacterAssetIDs)
        guard localCharacterAssetIDSet == stage1MasterAssetIDs else {
            throw MasterCatalogLoadError.directory(
                mismatchMessage(
                    title: "./assets/char 与 Stage 1 大师目录不一致",
                    expected: stage1MasterAssetIDs,
                    actual: localCharacterAssetIDSet
                )
            )
        }

        let localImageAssetIDs = Array(try resourceDirectoryIDs(in: roots.imageDirectory)).sorted()
        let localImageAssetIDSet = Set(localImageAssetIDs)
        guard localImageAssetIDSet == stage1MasterAssetIDs else {
            throw MasterCatalogLoadError.directory(
                mismatchMessage(
                    title: "./assets/assets/char 与 Stage 1 大师目录不一致",
                    expected: stage1MasterAssetIDs,
                    actual: localImageAssetIDSet
                )
            )
        }

        for assetID in stage1MasterAssetIDs {
            let imageDirectory = roots.imageDirectory.appendingPathComponent(assetID, isDirectory: true)
            try validateImageDirectory(at: imageDirectory, assetID: assetID)
        }

        return MasterDirectoryIndexCoverage(
            serviceDirectoryAssetIDs: directoryAssetIDs,
            localCharacterAssetIDs: localCharacterAssetIDs,
            localImageAssetIDs: localImageAssetIDs
        )
    }

    private static func resolveAssetRoots() throws -> MasterAssetRoots {
        let fileManager = FileManager.default
        let bundleCandidates: [MasterAssetRoots] = [
            Bundle.main.resourceURL.map {
                MasterAssetRoots(
                    charDirectory: $0.appendingPathComponent("char", isDirectory: true),
                    imageDirectory: $0.appendingPathComponent("assets/char", isDirectory: true)
                )
            },
            Bundle.main.resourceURL.map {
                MasterAssetRoots(
                    charDirectory: $0.appendingPathComponent("MasterCharAssets", isDirectory: true),
                    imageDirectory: $0.appendingPathComponent("MasterImageAssets/char", isDirectory: true)
                )
            }
        ]
        .compactMap { $0 }

        for candidate in bundleCandidates where fileManager.fileExists(atPath: candidate.charDirectory.path) &&
            fileManager.fileExists(atPath: candidate.imageDirectory.path) {
            return candidate
        }

        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let sourceRoots = MasterAssetRoots(
            charDirectory: repoRoot.appendingPathComponent("assets/char", isDirectory: true),
            imageDirectory: repoRoot.appendingPathComponent("assets/assets/char", isDirectory: true)
        )

        guard fileManager.fileExists(atPath: sourceRoots.charDirectory.path),
              fileManager.fileExists(atPath: sourceRoots.imageDirectory.path) else {
            throw MasterCatalogLoadError.assetRootsUnavailable
        }

        return sourceRoots
    }

    private static func resourceFileIDs(in directory: URL, pathExtension: String) throws -> Set<String> {
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        return Set(contents.compactMap { url in
            guard url.pathExtension.lowercased() == pathExtension.lowercased() else { return nil }
            return url.deletingPathExtension().lastPathComponent
        })
    }

    private static func resourceDirectoryIDs(in directory: URL) throws -> Set<String> {
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        return Set(contents.compactMap { url in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return nil }
            return url.lastPathComponent
        })
    }

    private static func validateImageDirectory(at directory: URL, assetID: String) throws {
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        let actualFiles = Set<String>(contents.compactMap { url in
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { return nil }
            return url.lastPathComponent
        })
        let expectedFiles = Set(requiredImageFiles)

        if let missingFile = expectedFiles.subtracting(actualFiles).sorted().first {
            throw MasterCatalogLoadError.missingImage(assetID, missingFile)
        }

        guard actualFiles == expectedFiles else {
            throw MasterCatalogLoadError.directory(
                "大师图片资源目录与映射规则不一致：asset_id=\(assetID)。expected=[\(requiredImageFiles.joined(separator: ", "))] actual=[\(actualFiles.sorted().joined(separator: ", "))]"
            )
        }
    }

    private static func mismatchMessage(title: String, expected: Set<String>, actual: Set<String>) -> String {
        let expectedList = expected.sorted().joined(separator: ", ")
        let actualList = actual.sorted().joined(separator: ", ")
        return "\(title)。expected=[\(expectedList)] actual=[\(actualList)]"
    }

    private static func makeProfile(
        entry: MasterServiceDirectory.Entry,
        domain: MasterDomain,
        document: MasterCharacterResourceDocument,
        characterURL: URL,
        imageDirectory: URL,
        directoryManifestPath: String,
        imageSet: MasterImageSet
    ) -> MasterProfile {
        let description = cleanText(document.metadata.description)
        let expertiseTags = Array(uniqueStrings(document.metadata.tags).prefix(4))
        let focusTags = Array(uniqueStrings([domain.title] + Array(document.metadata.tags.dropFirst(2).prefix(2))).prefix(3))
        let templates = makeTemplates(for: entry, name: document.chinese.name.fullName, domainTitle: domain.title, tags: expertiseTags)
        let stories = makeStories(document: document, entry: entry, expertiseTags: expertiseTags, domain: domain)
        let promptPreview = clip(
            firstNonEmpty(
                document.metadata.openingMessage,
                document.chinese.greetingMessage,
                document.metadata.personalityTraits,
                document.chinese.personality,
                description
            ),
            limit: 100
        )

        return MasterProfile(
            id: entry.assetID,
            displayName: document.chinese.name.fullName,
            title: clip(leadClause(description), limit: 24),
            tagline: clip(
                firstNonEmpty(document.metadata.personalityTraits, document.chinese.personality, description),
                limit: 72
            ),
            headline: clip(
                firstNonEmpty(document.metadata.description, document.metadata.importantPast, document.chinese.background),
                limit: 52
            ),
            domainID: domain.id,
            domainTitle: domain.title,
            sourceLabel: "预置角色资源",
            voice: clip(
                firstNonEmpty(document.metadata.speechStyle, document.chinese.interactionStyleTags, document.chinese.personality),
                limit: 88
            ),
            adviceStyle: adviceStyle(for: entry.domainID),
            decisionStyle: entry.decisionStyle,
            riskAppetite: entry.riskAppetite,
            expertiseTags: expertiseTags,
            focusTags: focusTags,
            boundaries: boundaries(for: entry.domainID),
            featuredTemplates: templates,
            stories: stories,
            memoryNotes: [],
            goalSnapshots: [
                MasterGoalSnapshot(
                    id: "goal-\(entry.assetID)",
                    title: "建议起手式",
                    nextAction: clip(templates.first?.prompt ?? promptPreview, limit: 44),
                    status: "可直接开聊",
                    updatedAt: "本地目录"
                )
            ],
            assetBundle: MasterAssetBundleInfo(
                bundleID: "masters_stage1_local_assets",
                version: "2026-03-27",
                portraitPackage: imageDirectory.path,
                directoryManifestPath: directoryManifestPath,
                characterFields: [
                    "Simplified Chinese.name.full_name",
                    "metadata.description",
                    "metadata.personality_traits",
                    "metadata.speech_style",
                    "metadata.tags",
                    "metadata.opening_message"
                ],
                storyFields: [
                    "metadata.important_past",
                    "Simplified Chinese.background",
                    "Simplified Chinese.world_settings"
                ],
                manifestFields: ["asset_id", "domain_id", "sort_order", "decision_style", "risk_appetite"],
                importNote: "Stage 1 目录索引固定指向 ./assets/char 与 ./assets/assets 的 8 套匹配资源，端侧只读消费。",
                isOfficial: true,
                characterAssetPath: characterURL.path,
                imageDirectoryPath: imageDirectory.path,
                mappedImageFiles: requiredImageFiles
            ),
            portraitSymbol: entry.portraitSymbol,
            palette: entry.palette,
            promptPreview: promptPreview,
            imageSet: imageSet
        )
    }

    private static func makeTemplates(
        for entry: MasterServiceDirectory.Entry,
        name: String,
        domainTitle: String,
        tags: [String]
    ) -> [MasterQuestionTemplate] {
        let firstTag = tags.first ?? domainTitle
        let secondTag = tags.dropFirst().first ?? "当前问题"

        return [
            MasterQuestionTemplate(
                id: "\(entry.assetID)-t1",
                title: "从\(firstTag)切入",
                prompt: "如果我想请\(name)从\(firstTag)角度判断我当前的问题，应该先补充哪些关键背景？",
                mode: .storyFirst
            ),
            MasterQuestionTemplate(
                id: "\(entry.assetID)-t2",
                title: "用\(name)的方法拆解",
                prompt: "请结合你的经历与方法，把这件关于\(secondTag)的事拆成一个今天就能开始的动作。",
                mode: mode(for: entry.decisionStyle)
            )
        ]
    }

    private static func makeStories(
        document: MasterCharacterResourceDocument,
        entry: MasterServiceDirectory.Entry,
        expertiseTags: [String],
        domain: MasterDomain
    ) -> [MasterStory] {
        let backgroundStory = makeStory(
            id: "\(entry.assetID)-background",
            title: "关键生平",
            sourceText: firstNonEmpty(document.metadata.importantPast, document.chinese.background, document.metadata.description),
            fallbackText: document.metadata.description,
            tags: Array(uniqueStrings(expertiseTags + [domain.title]).prefix(4))
        )
        let methodStory = makeStory(
            id: "\(entry.assetID)-method",
            title: "方法与立场",
            sourceText: firstNonEmpty(document.metadata.speechStyle, document.chinese.interactionStyleTags, document.chinese.personality),
            fallbackText: document.metadata.description,
            tags: Array(uniqueStrings(Array(expertiseTags.prefix(2)) + ["方法", "判断"]).prefix(4))
        )
        let worldStory = makeStory(
            id: "\(entry.assetID)-world",
            title: "时代与处境",
            sourceText: firstNonEmpty(document.chinese.worldSettings, document.chinese.setting, document.metadata.worldSettings),
            fallbackText: document.chinese.background,
            tags: Array(uniqueStrings([domain.title, "处境", "时代"] + Array(expertiseTags.prefix(1))).prefix(4))
        )

        return [backgroundStory, methodStory, worldStory]
    }

    private static func makeStory(
        id: String,
        title: String,
        sourceText: String,
        fallbackText: String,
        tags: [String]
    ) -> MasterStory {
        let basis = cleanText(sourceText).isEmpty ? fallbackText : sourceText
        var beats = storyBeats(from: basis)

        if beats.isEmpty {
            beats = [clip(cleanText(basis), limit: 30)]
        }
        while beats.count < 3 {
            beats.append(beats.last ?? clip(cleanText(basis), limit: 30))
        }

        return MasterStory(
            id: id,
            title: title,
            summary: clip(beats[0], limit: 48),
            beats: Array(beats.prefix(3)),
            tags: Array(uniqueStrings(tags).prefix(4))
        )
    }

    private static func storyBeats(from text: String) -> [String] {
        let normalized = cleanText(text)
        guard !normalized.isEmpty else { return [] }

        var segments: [String] = normalized
            .components(separatedBy: .newlines)
            .map(normalizeSegment)
            .filter { $0.count >= 8 }

        if segments.count < 3 {
            let punctuationSeparated = normalized
                .components(separatedBy: CharacterSet(charactersIn: "。！？；;"))
                .map(normalizeSegment)
                .filter { $0.count >= 8 }
            segments.append(contentsOf: punctuationSeparated)
        }

        if segments.count < 3 {
            let commaSeparated = normalized
                .components(separatedBy: CharacterSet(charactersIn: "，,:："))
                .map(normalizeSegment)
                .filter { $0.count >= 8 }
            segments.append(contentsOf: commaSeparated)
        }

        return Array(uniqueStrings(segments).prefix(3))
    }

    private static func mode(for decisionStyle: String) -> MasterConversationMode {
        switch decisionStyle {
        case "act_then_reflect":
            return .mentor
        case "resilient_expression":
            return .companion
        case "small_bets_profit":
            return .adviceFirst
        default:
            return .storyFirst
        }
    }

    private static func adviceStyle(for domainID: String) -> String {
        switch domainID {
        case "theory":
            return "先澄清定义和前提，再把问题压成可论证的一步"
        case "discovery":
            return "先回到证据、实验和可验证现象，再给判断"
        case "invention":
            return "先把收益、风险和代价摆到同一张表上"
        case "humanity":
            return "先对齐处境与价值，再决定如何表达和行动"
        default:
            return "先把问题说实，再给下一步建议"
        }
    }

    private static func boundaries(for domainID: String) -> [String] {
        switch domainID {
        case "theory":
            return ["不要跳过定义与前提直接下结论", "不要把猜想包装成已经证明的答案"]
        case "discovery":
            return ["不要拿单次现象替代重复验证", "不要绕开证据直接诉诸权威"]
        case "invention":
            return ["不要只谈效率不谈代价与安全", "不要把技术成就当成免检通行证"]
        case "humanity":
            return ["不要用宏大叙事掩盖真实处境", "不要急着替自己写终局结论"]
        default:
            return ["不要让情绪抢跑于判断"]
        }
    }

    private static func firstNonEmpty(_ values: String?...) -> String {
        values.map(cleanText).first(where: { !$0.isEmpty }) ?? ""
    }

    private static func leadClause(_ value: String) -> String {
        let candidates = value
            .components(separatedBy: CharacterSet(charactersIn: "，。；;"))
            .map(normalizeSegment)
            .filter { !$0.isEmpty }
        return candidates.first ?? clip(cleanText(value), limit: 24)
    }

    private static func normalizeSegment(_ value: String) -> String {
        cleanText(value)
            .replacingOccurrences(of: "- ", with: "")
            .replacingOccurrences(of: "• ", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-• "))
    }

    private static func cleanText(_ value: String?) -> String {
        guard let value else { return "" }
        return value
            .replacingOccurrences(of: "[English Version] - ", with: "")
            .replacingOccurrences(of: "[日本語版] - ", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func uniqueStrings<S: Sequence>(_ values: S) -> [String] where S.Element == String {
        var seen = Set<String>()
        return values.compactMap { raw in
            let cleaned = cleanText(raw)
            guard !cleaned.isEmpty, seen.insert(cleaned).inserted else { return nil }
            return cleaned
        }
    }

    private static func clip(_ value: String, limit: Int) -> String {
        guard value.count > limit else { return value }
        return String(value.prefix(limit)) + "…"
    }
}

private struct MasterAssetRoots {
    let charDirectory: URL
    let imageDirectory: URL
}

private enum MasterCatalogLoadError: LocalizedError {
    case assetRootsUnavailable
    case missingCharacter(String)
    case missingImage(String, String)
    case invalidCharacter(String, String)
    case mismatchedCharacterIdentifier(expected: String, actual: String)
    case directory(String)

    var errorDescription: String? {
        switch self {
        case .assetRootsUnavailable:
            return "未找到大师本地资源目录。需要 ./assets/char 与 ./assets/assets/char。"
        case .missingCharacter(let assetID):
            return "缺少大师字段资源：./assets/char/\(assetID).json"
        case .missingImage(let assetID, let fileName):
            return "缺少大师图片资源：./assets/assets/char/\(assetID)/\(fileName)"
        case .invalidCharacter(let assetID, let detail):
            return "解析大师字段资源失败：\(assetID).json，\(detail)"
        case .mismatchedCharacterIdentifier(let expected, let actual):
            return "大师字段资源与目录索引不一致：期望 asset_id=\(expected)，实际 metadata.id=\(actual)"
        case .directory(let message):
            return message
        }
    }
}

private struct MasterCharacterResourceDocument: Decodable {
    let chinese: MasterLocalizedCharacter
    let metadata: MasterCharacterMetadata

    enum CodingKeys: String, CodingKey {
        case chinese = "Simplified Chinese"
        case metadata
    }
}

private struct MasterLocalizedCharacter: Decodable {
    let background: String
    let greetingMessage: String
    let interactionStyleTags: String
    let name: MasterLocalizedName
    let personality: String
    let setting: String?
    let worldSettings: String?

    enum CodingKeys: String, CodingKey {
        case background
        case greetingMessage = "greeting_message"
        case interactionStyleTags = "interaction_style_tags"
        case name
        case personality
        case setting
        case worldSettings = "world_settings"
    }
}

private struct MasterLocalizedName: Decodable {
    let fullName: String

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
    }
}

private struct MasterCharacterMetadata: Decodable {
    let description: String
    let id: Int
    let tags: [String]
    let openingMessage: String?
    let personalityTraits: String?
    let speechStyle: String?
    let importantPast: String?
    let worldSettings: String?

    enum CodingKeys: String, CodingKey {
        case description
        case id
        case tags
        case openingMessage = "opening_message"
        case personalityTraits = "personality_traits"
        case speechStyle = "speech_style"
        case importantPast = "important_past"
        case worldSettings = "world_settings"
    }
}

private enum MasterServiceDirectory {
    struct Entry {
        let assetID: String
        let domainID: String
        let sortOrder: Int
        let decisionStyle: String
        let riskAppetite: String
        let portraitSymbol: String
        let palette: [Color]
    }

    struct DirectorySnapshot {
        let sourceURL: URL
        let domains: [MasterDomain]
        let entries: [Entry]
    }

    static func load() throws -> DirectorySnapshot {
        let url = try resolveDirectoryURL()
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw MasterCatalogLoadError.directory("读取大师目录索引失败：\(url.lastPathComponent)，\(error.localizedDescription)")
        }

        let document: MasterServiceDirectoryDocument
        do {
            document = try JSONDecoder().decode(MasterServiceDirectoryDocument.self, from: data)
        } catch {
            throw MasterCatalogLoadError.directory("解析大师目录索引失败：\(url.lastPathComponent)，\(error.localizedDescription)")
        }

        let domains = document.domains.map(\.domain)
        let domainIDs = Set(domains.map(\.id))
        guard domainIDs.count == domains.count else {
            throw MasterCatalogLoadError.directory("大师目录索引存在重复 domain_id。")
        }

        var seenAssetIDs = Set<String>()
        let entries = try document.entries.map { entryRecord -> Entry in
            guard domainIDs.contains(entryRecord.domainID) else {
                throw MasterCatalogLoadError.directory("大师目录索引引用了未知领域：\(entryRecord.domainID)")
            }
            guard seenAssetIDs.insert(entryRecord.assetID).inserted else {
                throw MasterCatalogLoadError.directory("大师目录索引存在重复 asset_id：\(entryRecord.assetID)")
            }
            return try entryRecord.entry
        }

        return DirectorySnapshot(
            sourceURL: url,
            domains: domains,
            entries: entries
        )
    }

    private static func resolveDirectoryURL() throws -> URL {
        if let bundled = Bundle.main.url(forResource: "master_service_directory", withExtension: "json") {
            return bundled
        }

        let supportPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Support/master_service_directory.json")
        guard FileManager.default.fileExists(atPath: supportPath.path) else {
            throw MasterCatalogLoadError.directory("未找到大师目录索引：Features/Masters/Support/master_service_directory.json")
        }
        return supportPath
    }
}

private struct MasterServiceDirectoryDocument: Decodable {
    let domains: [DomainRecord]
    let entries: [EntryRecord]

    struct DomainRecord: Decodable {
        let id: String
        let title: String
        let description: String
        let symbol: String

        var domain: MasterDomain {
            MasterDomain(
                id: id,
                title: title,
                description: description,
                symbol: symbol
            )
        }
    }

    struct EntryRecord: Decodable {
        let assetID: String
        let domainID: String
        let sortOrder: Int
        let decisionStyle: String
        let riskAppetite: String
        let portraitSymbol: String
        let paletteHex: [String]

        enum CodingKeys: String, CodingKey {
            case assetID = "asset_id"
            case domainID = "domain_id"
            case sortOrder = "sort_order"
            case decisionStyle = "decision_style"
            case riskAppetite = "risk_appetite"
            case portraitSymbol = "portrait_symbol"
            case paletteHex = "palette_hex"
        }

        var entry: MasterServiceDirectory.Entry {
            get throws {
                MasterServiceDirectory.Entry(
                    assetID: assetID,
                    domainID: domainID,
                    sortOrder: sortOrder,
                    decisionStyle: decisionStyle,
                    riskAppetite: riskAppetite,
                    portraitSymbol: portraitSymbol,
                    palette: try paletteHex.map(Self.color(fromHex:))
                )
            }
        }

        private static func color(fromHex hex: String) throws -> Color {
            let normalized = hex
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "#", with: "")
            guard normalized.count == 6, let value = Int(normalized, radix: 16) else {
                throw MasterCatalogLoadError.directory("大师目录索引存在非法 palette_hex：\(hex)")
            }

            let red = Double((value >> 16) & 0xFF) / 255.0
            let green = Double((value >> 8) & 0xFF) / 255.0
            let blue = Double(value & 0xFF) / 255.0
            return Color(red: red, green: green, blue: blue)
        }
    }
}

private extension Array where Element == MasterMessage {
    var nonEmpty: [MasterMessage]? {
        isEmpty ? nil : self
    }
}
