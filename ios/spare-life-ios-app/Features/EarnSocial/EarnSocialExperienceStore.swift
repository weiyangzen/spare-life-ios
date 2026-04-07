// EarnSocialExperienceStore.swift
// Spare Life – 赚闲能 A2A experience store
// Blueprint §3.3 功能点 1-7
// UIUX lane – slot 2

import Foundation
import SwiftUI

// MARK: - Lane

enum EarnSocialLaneID: String, CaseIterable, Identifiable, Hashable, Sendable {
    case idleGoods = "idle_goods"
    case skillQA = "skill_qa"
    case romance = "romance"
    case friendship = "friendship"
    case jobHiring = "job_hiring"
    case errandHelp = "errand_help"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .idleGoods: return "闲置物品"
        case .skillQA: return "技能问答"
        case .romance: return "婚恋"
        case .friendship: return "交友"
        case .jobHiring: return "求职招人"
        case .errandHelp: return "跑腿求助"
        }
    }

    var shortcut: String {
        switch self {
        case .idleGoods: return "捡漏买卖"
        case .skillQA: return "问答撮合"
        case .romance: return "认真匹配"
        case .friendship: return "找搭子"
        case .jobHiring: return "工作机会"
        case .errandHelp: return "任务应答"
        }
    }

    var symbol: String {
        switch self {
        case .idleGoods: return "shippingbox.fill"
        case .skillQA: return "sparkles.rectangle.stack.fill"
        case .romance: return "heart.circle.fill"
        case .friendship: return "person.2.wave.2.fill"
        case .jobHiring: return "briefcase.circle.fill"
        case .errandHelp: return "figure.run.circle.fill"
        }
    }

    var summary: String {
        switch self {
        case .idleGoods:
            return "买家 Agent 和卖家 Agent 先问价、验货、议价，真人只接最后一段。"
        case .skillQA:
            return "提问者和技能方先对齐问题边界、交付方式和是否值得继续聊。"
        case .romance:
            return "双方 Agent 先筛价值观、边界和见面节奏，再决定是否见面。"
        case .friendship:
            return "先看兴趣、情绪和相处氛围，再让真人进来，减少尬聊。"
        case .jobHiring:
            return "候选人和招聘方 Agent 先完成岗位理解、履历解释和意向确认。"
        case .errandHelp:
            return "需求发布者和应答者先确认时间、预算、地点和可靠性。"
        }
    }

    var savedSteps: String {
        switch self {
        case .idleGoods:
            return "省掉反复问价、验货和无效砍价"
        case .skillQA:
            return "省掉问题边界不清和交付方式对不齐"
        case .romance:
            return "省掉价值观错配和风险感知不足"
        case .friendship:
            return "省掉浅聊尬聊和节奏不合"
        case .jobHiring:
            return "省掉岗位理解偏差和履历来回解释"
        case .errandHelp:
            return "省掉任务条件没说清导致的临时加价"
        }
    }
}

struct EarnSocialLaneChip: Identifiable, Hashable {
    let lane: EarnSocialLaneID
    let openIntentCount: Int
    let heatScore: Double
    let rewardAmount: Int

    var id: EarnSocialLaneID { lane }
}

// MARK: - Wallet / Ledger

struct EarnWalletSnapshot: Identifiable, Hashable {
    let id = UUID()
    var balance: Int
    var frozenBalance: Int
    var lifetimeEarned: Int
    var lifetimeSpent: Int
    var todayEarnable: Int
    var streakDays: Int
}

enum EarnLedgerEntryKind: String, Hashable {
    case income
    case expense
    case freeze
    case settlement
}

struct EarnLedgerEntry: Identifiable, Hashable {
    let id: String
    let lane: EarnSocialLaneID?
    let title: String
    let detail: String
    let amount: Int
    let kind: EarnLedgerEntryKind
    let statusLabel: String
    let timestamp: Date
}

// MARK: - Feed / Filters

enum EarnSocialQuickFilter: String, CaseIterable, Identifiable {
    case opportunities
    case bestMatch
    case trends
    case arena

    var id: String { rawValue }

    var title: String {
        switch self {
        case .opportunities: return "机会最多"
        case .bestMatch: return "最匹配分身"
        case .trends: return "热度趋势"
        case .arena: return "竞技场"
        }
    }

    var symbol: String {
        switch self {
        case .opportunities: return "bolt.fill"
        case .bestMatch: return "person.crop.circle.badge.checkmark"
        case .trends: return "chart.line.uptrend.xyaxis"
        case .arena: return "figure.boxing"
        }
    }
}

enum EarnSocialHomeState: Equatable {
    case idle
    case loading
    case loaded
    case error(String)
}

struct EarnBondPromptCard: Identifiable, Hashable {
    let id = "bond-prompt"
    let title: String
    let message: String
}

enum EarnSocialFeedCard: Identifiable, Hashable {
    case wallet(EarnWalletSnapshot)
    case opportunity(EarnIntentCard)
    case persona(EarnPersonaCard)
    case icebreakPrompt(EarnIcebreakPrompt)
    case icebreak(EarnIcebreakSession)
    case trend(EarnTrendSnapshot)
    case arena(EarnArenaMatch)
    case bondPrompt(EarnBondPromptCard)
    case bond(EarnBondStory)

    var id: String {
        switch self {
        case .wallet(let card): return "wallet-\(card.id)"
        case .opportunity(let card): return "opportunity-\(card.id)"
        case .persona(let card): return "persona-\(card.id)"
        case .icebreakPrompt(let card): return "icebreak-prompt-\(card.id)"
        case .icebreak(let card): return "icebreak-\(card.id)"
        case .trend(let card): return "trend-\(card.id)"
        case .arena(let card): return "arena-\(card.id)"
        case .bondPrompt(let card): return "bond-prompt-\(card.id)"
        case .bond(let card): return "bond-\(card.id)"
        }
    }
}

// MARK: - Intent Market

enum EarnIntentVisibilityMode: String, CaseIterable, Identifiable, Hashable {
    case `public`
    case semiPublic = "semi_public"
    case direct

    var id: String { rawValue }

    var title: String {
        switch self {
        case .public: return "公开投放"
        case .semiPublic: return "半公开匹配"
        case .direct: return "定向投递"
        }
    }

    var detail: String {
        switch self {
        case .public: return "让系统按赛道推荐，适合机会探索"
        case .semiPublic: return "只向更像的人曝光，减少噪音"
        case .direct: return "直接给目标分身，消耗 3 闲能"
        }
    }

    var symbol: String {
        switch self {
        case .public: return "globe.asia.australia.fill"
        case .semiPublic: return "line.3.horizontal.decrease.circle.fill"
        case .direct: return "paperplane.circle.fill"
        }
    }
}

struct EarnIntentFieldTemplate: Identifiable, Hashable {
    let key: String
    let label: String
    let placeholder: String
    let isRequired: Bool

    var id: String { key }
}

struct EarnIntentTemplate: Identifiable, Hashable {
    let id: String
    let lane: EarnSocialLaneID
    let title: String
    let summary: String
    let tags: [String]
    let fields: [EarnIntentFieldTemplate]
}

struct EarnIntentFieldValue: Identifiable, Hashable {
    let key: String
    let label: String
    let placeholder: String
    let isRequired: Bool
    var value: String

    var id: String { key }
}

struct EarnIntentDraft: Identifiable, Hashable {
    let id = UUID()
    var lane: EarnSocialLaneID
    var template: EarnIntentTemplate
    var visibility: EarnIntentVisibilityMode
    var fields: [EarnIntentFieldValue]
    var note: String

    var completionScore: Double {
        let requiredCount = fields.filter(\.isRequired).count
        guard requiredCount > 0 else { return 1 }
        let filledRequired = fields.filter { $0.isRequired && !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        return Double(filledRequired) / Double(requiredCount)
    }
}

struct EarnIntentCard: Identifiable, Hashable {
    let id: String
    let lane: EarnSocialLaneID
    let templateID: String
    let title: String
    let summary: String
    let mode: EarnIntentVisibilityMode
    let rankingScore: Int
    let reason: String
    let tags: [String]
    let route: String
    let createdAt: Date
}

// MARK: - Personas

struct EarnPersonaCard: Identifiable, Hashable {
    let id: String
    let lane: EarnSocialLaneID
    let displayName: String
    let publicBio: String
    let personaTags: [String]
    let expertiseTags: [String]
    let openHours: [String]
    let expectedPartner: [String]
    let explanationTags: [String]
    let allowsAgentIntro: Bool
    let trustScore: Int
    let matchScore: Double
    let route: String
}

// MARK: - Icebreak

enum EarnIcebreakStage: String, Hashable {
    case screening
    case consentPending = "consent_pending"
    case humanTakeover = "human_takeover"
    case blocked

    var label: String {
        switch self {
        case .screening: return "分身互筛中"
        case .consentPending: return "等待双方授权"
        case .humanTakeover: return "真人可接手"
        case .blocked: return "拦截保留在分身层"
        }
    }
}

enum EarnIcebreakActorKind: String, Hashable {
    case human
    case initiatorAgent = "initiator_agent"
    case counterpartAgent = "counterpart_agent"
    case system

    var displayName: String {
        switch self {
        case .human: return "你"
        case .initiatorAgent: return "你的分身"
        case .counterpartAgent: return "对方分身"
        case .system: return "系统"
        }
    }
}

struct EarnIcebreakPrompt: Identifiable, Hashable {
    let id = "icebreak-prompt"
    let headline: String
    let body: String
}

struct EarnIcebreakMessage: Identifiable, Hashable {
    let id: String
    let actor: EarnIcebreakActorKind
    let promptKind: String
    let content: String
    let auditPassed: Bool
}

struct EarnIcebreakAuditLog: Identifiable, Hashable {
    let id: String
    let promptKind: String
    let policyStatus: String
    let summary: String
}

struct EarnIcebreakSession: Identifiable, Hashable {
    let id: String
    let lane: EarnSocialLaneID
    let intentTitle: String
    let counterpartName: String
    var compatibilityScore: Double
    var stage: EarnIcebreakStage
    var summary: String
    var initiatorGranted: Bool
    var counterpartGranted: Bool
    var auditPassed: Bool
    let handoffRules: [String]
    let messages: [EarnIcebreakMessage]
    let audits: [EarnIcebreakAuditLog]
    let route: String
}

enum EarnConsentSide: Hashable {
    case initiator
    case counterpart
}

// MARK: - Trends

struct EarnTrendSnapshot: Identifiable, Hashable {
    let id: String
    let lane: EarnSocialLaneID
    let heatScore: Double
    let responseSpeedScore: Double
    let profitScore: Double
    let supplyGapScore: Double
    let eventTitle: String
    let eventSummary: String
    let rewardAmount: Int
    var isClaimed: Bool
    let route: String
}

// MARK: - Arena

enum EarnArenaMatchStatus: String, Hashable {
    case active
    case resolved
}

enum EarnArenaSide: String, Hashable {
    case challenger
    case opponent

    var title: String {
        switch self {
        case .challenger: return "挑战方"
        case .opponent: return "守擂方"
        }
    }
}

struct EarnArenaContender: Hashable {
    let displayName: String
    let subtitle: String
}

struct EarnArenaRound: Identifiable, Hashable {
    let id: String
    let index: Int
    let prompt: String
    let challengerReply: String
    let opponentReply: String
    let challengerScore: Double
    let opponentScore: Double
    let summary: String
}

struct EarnArenaVote: Identifiable, Hashable {
    let id: String
    let voterName: String
    let preferredSide: EarnArenaSide
    let weight: Int
}

struct EarnArenaMatch: Identifiable, Hashable {
    let id: String
    let lane: EarnSocialLaneID
    let theme: String
    let challenger: EarnArenaContender
    let opponent: EarnArenaContender
    var status: EarnArenaMatchStatus
    var winnerSide: EarnArenaSide?
    var summary: String
    var rounds: [EarnArenaRound]
    var votes: [EarnArenaVote]
    let rewardAmount: Int
    let route: String

    var challengerScore: Double {
        rounds.reduce(0) { $0 + $1.challengerScore } + Double(voteWeight(for: .challenger) * 8)
    }

    var opponentScore: Double {
        rounds.reduce(0) { $0 + $1.opponentScore } + Double(voteWeight(for: .opponent) * 8)
    }

    func voteWeight(for side: EarnArenaSide) -> Int {
        votes.filter { $0.preferredSide == side }.reduce(0) { $0 + $1.weight }
    }
}

// MARK: - Bond

enum EarnBondLevel: String, Hashable {
    case spark
    case warming
    case trusted

    var title: String {
        switch self {
        case .spark: return "火花"
        case .warming: return "升温"
        case .trusted: return "熟悉"
        }
    }
}

struct EarnBondTask: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    var progressCount: Int
    let targetCount: Int
    let rewardAmount: Int
    let milestoneKey: String

    var isCompleted: Bool { progressCount >= targetCount }
}

struct EarnBondMilestone: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let achievedAt: Date
}

struct EarnBondStory: Identifiable, Hashable {
    let id: String
    let lane: EarnSocialLaneID
    let counterpartName: String
    let memorialTitle: String
    let memorialSummary: String
    var level: EarnBondLevel
    var strengthScore: Int
    var tasks: [EarnBondTask]
    var milestones: [EarnBondMilestone]
    let threadRoute: String
}

// MARK: - Sheet

enum EarnSocialSheet: String, Identifiable {
    case market
    case personas
    case icebreak
    case trends
    case arena
    case bond
    case wallet

    var id: String { rawValue }
}

// MARK: - Store

@MainActor
final class EarnSocialExperienceStore: ObservableObject {
    @Published var homeState: EarnSocialHomeState = .idle
    @Published var selectedLane: EarnSocialLaneID = .jobHiring
    @Published var selectedFilter: EarnSocialQuickFilter = .opportunities
    @Published var activeSheet: EarnSocialSheet?
    @Published var wallet = EarnWalletSnapshot(
        balance: 10,
        frozenBalance: 0,
        lifetimeEarned: 10,
        lifetimeSpent: 0,
        todayEarnable: 18,
        streakDays: 4
    )
    @Published var laneChips: [EarnSocialLaneChip] = []
    @Published var seedIntents: [EarnIntentCard] = []
    @Published var publishedIntents: [EarnIntentCard] = []
    @Published var personas: [EarnPersonaCard] = []
    @Published var blockedPersonaIDs: Set<String> = []
    @Published var likedPersonaIDs: Set<String> = []
    @Published var skippedPersonaIDs: Set<String> = []
    @Published var activeIcebreak: EarnIcebreakSession?
    @Published var trendBoard: [EarnTrendSnapshot] = []
    @Published var arenaMatch: EarnArenaMatch?
    @Published var bondStory: EarnBondStory?
    @Published var ledgerEntries: [EarnLedgerEntry] = []
    @Published var marketDraft: EarnIntentDraft
    @Published var marketValidationMessage: String?
    @Published var marketSuccessMessage: String?
    @Published var publishFocusIntentID: String?
    @Published var personaDeckMessage: String?
    @Published var selectedArenaVote: EarnArenaSide?
    @Published var toastMessage: String?
    @Published var lastRefreshAt = Date()

    let quickFilters = EarnSocialQuickFilter.allCases
    let templatesByLane: [EarnSocialLaneID: [EarnIntentTemplate]]
    let icebreakPrompt = EarnIcebreakPrompt(
        headline: "先让双方分身聊，再决定真人接手",
        body: "不是直接把两个人扔进聊天框。先摸底、过滤、暖场、探边界，再拉真人进来。"
    )

    init() {
        let templates = Self.makeTemplates()
        templatesByLane = templates
        marketDraft = Self.makeDraft(for: .jobHiring, templates: templates)
        seedContent()
    }

    func loadIfNeeded() {
        guard case .idle = homeState else { return }
        Task { await refresh(simulateLoading: true) }
    }

    func refresh() async {
        await refresh(simulateLoading: true)
    }

    func refresh(simulateLoading: Bool) async {
        if simulateLoading {
            homeState = .loading
            try? await Task.sleep(nanoseconds: 420_000_000)
        }

        if selectedFilter == .arena, arenaMatch == nil {
            homeState = .error("A2A 竞技场当前没有可围观的对战，稍后再拉一局。")
            return
        }

        homeState = .loaded
        lastRefreshAt = Date()
    }

    func selectLane(_ lane: EarnSocialLaneID) {
        selectedLane = lane
        marketDraft = Self.makeDraft(for: lane, templates: templatesByLane)
        marketValidationMessage = nil
        marketSuccessMessage = nil
    }

    func selectQuickFilter(_ filter: EarnSocialQuickFilter) {
        withAnimation(.spareFast) {
            selectedFilter = filter
        }
    }

    func openMarket() {
        marketValidationMessage = nil
        marketSuccessMessage = nil
        activeSheet = .market
    }

    func openPersonaDeck() {
        personaDeckMessage = nil
        activeSheet = .personas
    }

    func openIcebreak() {
        activeSheet = .icebreak
    }

    func openTrends() {
        activeSheet = .trends
    }

    func openArena() {
        activeSheet = .arena
    }

    func openBond() {
        activeSheet = .bond
    }

    func openWallet() {
        activeSheet = .wallet
    }

    func applyExternalHandoff(_ handoff: CrossTabHandoff) {
        guard handoff.targetSurface == .earnSocial else { return }
        guard case .earnSocial(let route) = handoff.route else { return }

        switch route {
        case .market(let lane, let topic):
            selectLane(lane)
            if let topic, !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               marketDraft.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                marketDraft.note = topic
            }
            openMarket()
            toastMessage = "已从\(handoff.sourceSurface.title)带入 \(lane.title) 赛道。"
        }
    }

    func updateDraftTemplate(_ template: EarnIntentTemplate) {
        marketDraft = EarnIntentDraft(
            lane: template.lane,
            template: template,
            visibility: marketDraft.visibility,
            fields: template.fields.map {
                EarnIntentFieldValue(
                    key: $0.key,
                    label: $0.label,
                    placeholder: $0.placeholder,
                    isRequired: $0.isRequired,
                    value: ""
                )
            },
            note: ""
        )
        marketValidationMessage = nil
        marketSuccessMessage = nil
    }

    func updateDraftLane(_ lane: EarnSocialLaneID) {
        selectLane(lane)
    }

    func updateDraftVisibility(_ mode: EarnIntentVisibilityMode) {
        marketDraft.visibility = mode
        marketValidationMessage = nil
    }

    func updateDraftField(id: String, value: String) {
        guard let index = marketDraft.fields.firstIndex(where: { $0.id == id }) else { return }
        marketDraft.fields[index].value = value
        marketValidationMessage = nil
    }

    func updateDraftNote(_ value: String) {
        marketDraft.note = value
    }

    func clearMarketMessages() {
        marketValidationMessage = nil
        marketSuccessMessage = nil
    }

    func publishDraft() {
        let missingRequired = marketDraft.fields
            .filter { $0.isRequired && $0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map(\.label)

        guard missingRequired.isEmpty else {
            marketValidationMessage = "还缺少必填字段：\(missingRequired.joined(separator: "、"))。"
            return
        }

        if marketDraft.visibility == .direct, wallet.balance < 3 {
            marketValidationMessage = "当前闲能不足，无法发起定向投递。先完成热点探索或竞技场再回来。"
            return
        }

        let values = marketDraft.fields
            .filter { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { "\($0.key):\($0.value)" }
        let titleValue = marketDraft.fields.first(where: { $0.isRequired })?.value ?? marketDraft.template.title
        let card = EarnIntentCard(
            id: "intent-\(UUID().uuidString.prefix(8))",
            lane: marketDraft.lane,
            templateID: marketDraft.template.id,
            title: "\(marketDraft.template.title) · \(titleValue)",
            summary: values.joined(separator: " / "),
            mode: marketDraft.visibility,
            rankingScore: Int(marketDraft.completionScore * 100),
            reason: marketDraft.lane.savedSteps,
            tags: marketDraft.template.tags + marketDraft.fields.compactMap { value in
                let trimmed = value.value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            },
            route: "sparelife://earn-social/intent?draft=\(UUID().uuidString.lowercased())",
            createdAt: Date()
        )
        publishedIntents.insert(card, at: 0)
        publishFocusIntentID = card.id
        marketSuccessMessage = "意图已进入 \(marketDraft.lane.title) 市场。下一步可以直接看推荐分身，或者让双方分身先摸底。"
        marketValidationMessage = nil

        if marketDraft.visibility == .direct {
            wallet.balance -= 3
            wallet.lifetimeSpent += 3
            addLedgerEntry(
                lane: marketDraft.lane,
                title: "定向投递冷启动",
                detail: "把新意图直接投给更具体的目标分身",
                amount: -3,
                kind: .expense,
                statusLabel: "已扣除"
            )
        }
    }

    func visibleRecentIntents(for lane: EarnSocialLaneID) -> [EarnIntentCard] {
        (publishedIntents + seedIntents)
            .filter { $0.lane == lane }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func visiblePersonas(for lane: EarnSocialLaneID) -> [EarnPersonaCard] {
        personas
            .filter { $0.lane == lane && !blockedPersonaIDs.contains($0.id) }
            .sorted { lhs, rhs in
                if lhs.matchScore == rhs.matchScore {
                    return lhs.trustScore > rhs.trustScore
                }
                return lhs.matchScore > rhs.matchScore
            }
    }

    func likePersona(_ card: EarnPersonaCard) {
        likedPersonaIDs.insert(card.id)
        personaDeckMessage = "已把 \(card.displayName) 标为高意向，后续会更早给你。"
        addEnergy(amount: 2, lane: card.lane, title: "分身偏好反馈", detail: "系统收到一次明确喜欢信号")
    }

    func skipPersona(_ card: EarnPersonaCard) {
        skippedPersonaIDs.insert(card.id)
        blockedPersonaIDs.insert(card.id)
        personaDeckMessage = "已略过 \(card.displayName)，本地缓存会减少重复曝光。"
    }

    func reportPersona(_ card: EarnPersonaCard) {
        blockedPersonaIDs.insert(card.id)
        personaDeckMessage = "已举报并从推荐流移除 \(card.displayName)。"
    }

    func resetPersonaCache() {
        blockedPersonaIDs.removeAll()
        skippedPersonaIDs.removeAll()
        personaDeckMessage = "已清空已看缓存，本轮会重新出牌。"
    }

    func clearPersonaDeckMessage() {
        personaDeckMessage = nil
    }

    func startIcebreak(with card: EarnPersonaCard) {
        let sourceIntent = visibleRecentIntents(for: card.lane).first
        let intentTitle = sourceIntent?.title ?? "\(card.lane.title) · 先让分身探意图"
        activeIcebreak = EarnIcebreakSession(
            id: "icebreak-\(UUID().uuidString.prefix(8))",
            lane: card.lane,
            intentTitle: intentTitle,
            counterpartName: card.displayName,
            compatibilityScore: card.matchScore,
            stage: .screening,
            summary: "双方分身先用一轮边界确认和意图筛选，暂不建议真人立刻接手。",
            initiatorGranted: false,
            counterpartGranted: false,
            auditPassed: true,
            handoffRules: [
                "双方都明确授权真人参与",
                "审计通过，不出现越权承诺与隐私越界",
                "分身已经说清边界、预算或见面节奏"
            ],
            messages: [
                EarnIcebreakMessage(
                    id: "icebreak-msg-1",
                    actor: .initiatorAgent,
                    promptKind: "agent_intro",
                    content: "我先替主人确认关键边界：\(intentTitle)。只聊必要信息，不替真人做承诺。",
                    auditPassed: true
                ),
                EarnIcebreakMessage(
                    id: "icebreak-msg-2",
                    actor: .counterpartAgent,
                    promptKind: "agent_screening",
                    content: "\(card.displayName) 这边可以先说明 \(card.expertiseTags.prefix(2).joined(separator: " / "))，确认匹配后再授权真人接手。",
                    auditPassed: true
                ),
                EarnIcebreakMessage(
                    id: "icebreak-msg-3",
                    actor: .system,
                    promptKind: "agent_summary",
                    content: "系统判断双方已经进入可继续阶段，但还需要双方明确授权真人是否接手。",
                    auditPassed: true
                )
            ],
            audits: [
                EarnIcebreakAuditLog(
                    id: "icebreak-audit-1",
                    promptKind: "agent_intro",
                    policyStatus: "passed",
                    summary: "未越权承诺，边界表达清楚。"
                ),
                EarnIcebreakAuditLog(
                    id: "icebreak-audit-2",
                    promptKind: "agent_screening",
                    policyStatus: "passed",
                    summary: "只暴露公开卡允许的信息，没有泄露隐私字段。"
                )
            ],
            route: "sparelife://earn-social/icebreak?lane=\(card.lane.rawValue)&agent=\(card.id)"
        )
        activeSheet = .icebreak
    }

    func updateConsent(side: EarnConsentSide, granted: Bool) {
        guard var session = activeIcebreak else { return }

        switch side {
        case .initiator:
            session.initiatorGranted = granted
        case .counterpart:
            session.counterpartGranted = granted
        }

        if !granted {
            session.stage = .blocked
            session.summary = "有一方拒绝真人接手，流程会保留在分身层，避免越权推进。"
            activeIcebreak = session
            toastMessage = "本轮破冰停留在分身层，没有把真人硬拉进来。"
            return
        }

        if session.initiatorGranted && session.counterpartGranted && session.auditPassed {
            session.stage = .humanTakeover
            session.summary = "双方都已授权真人接手，同时生成了从陌生过渡到熟人的羁绊任务。"
            activeIcebreak = session

            if bondStory == nil || bondStory?.counterpartName != session.counterpartName {
                bondStory = EarnBondStory(
                    id: "bond-\(UUID().uuidString.prefix(8))",
                    lane: session.lane,
                    counterpartName: session.counterpartName,
                    memorialTitle: "\(session.counterpartName) 初遇纪念卡",
                    memorialSummary: "通过 \(session.lane.title) 赛道完成第一次互相授权，开始从陌生过渡到熟人。",
                    level: .spark,
                    strengthScore: 42,
                    tasks: [
                        EarnBondTask(
                            id: "bond-task-1",
                            title: "连续 2 天轻量报到",
                            summary: "用两次低负担互动确认节奏和回应稳定性。",
                            progressCount: 0,
                            targetCount: 2,
                            rewardAmount: 4,
                            milestoneKey: "first_rhythm"
                        ),
                        EarnBondTask(
                            id: "bond-task-2",
                            title: "共完成 1 个小目标",
                            summary: "一起完成一件小事，验证执行和协同感。",
                            progressCount: 0,
                            targetCount: 1,
                            rewardAmount: 6,
                            milestoneKey: "shared_goal"
                        ),
                        EarnBondTask(
                            id: "bond-task-3",
                            title: "交换 1 次关系回顾",
                            summary: "说清楚彼此舒服的互动方式，避免关系降温误伤。",
                            progressCount: 0,
                            targetCount: 1,
                            rewardAmount: 5,
                            milestoneKey: "reflection"
                        )
                    ],
                    milestones: [],
                    threadRoute: LegacyAppRouteBuilder.messagesThread(
                        lane: session.lane,
                        counterpartName: session.counterpartName
                    )
                )
                addEnergy(
                    amount: 7,
                    lane: session.lane,
                    title: "双 Agent 破冰完成",
                    detail: "双方授权真人接手，生成羁绊任务"
                )
            }

            toastMessage = "真人接手入口已打开，关系任务已经挂到消息线程前。"
            return
        }

        session.stage = .consentPending
        session.summary = "已记录单侧授权，等双方都确认后再把真人拉进来。"
        activeIcebreak = session
    }

    func claimTrendReward(for lane: EarnSocialLaneID) {
        guard let index = trendBoard.firstIndex(where: { $0.lane == lane }) else { return }
        guard !trendBoard[index].isClaimed else { return }
        trendBoard[index].isClaimed = true
        addEnergy(
            amount: trendBoard[index].rewardAmount,
            lane: lane,
            title: "热点探索奖励",
            detail: "领取 \(trendBoard[index].eventTitle) 的探索奖励"
        )
        toastMessage = "已领取 \(lane.title) 热点奖励。"
    }

    func castArenaVote(_ side: EarnArenaSide) {
        guard var match = arenaMatch, match.status == .active else { return }
        selectedArenaVote = side
        match.votes.removeAll { $0.voterName == "你" }
        match.votes.append(
            EarnArenaVote(
                id: "vote-\(UUID().uuidString.prefix(8))",
                voterName: "你",
                preferredSide: side,
                weight: 2
            )
        )
        arenaMatch = match
    }

    func resolveArenaIfNeeded() {
        guard var match = arenaMatch, match.status == .active else { return }
        let winner: EarnArenaSide = match.challengerScore >= match.opponentScore ? .challenger : .opponent
        match.status = .resolved
        match.winnerSide = winner
        match.summary = winner == .challenger
            ? "挑战方赢下对战，原因是对接手时机和边界说得更完整。"
            : "守擂方守住节奏，原因是情绪回应和风险控制更稳。"
        arenaMatch = match
        addEnergy(
            amount: match.rewardAmount,
            lane: match.lane,
            title: "A2A 竞技场结算",
            detail: "\(winner.title) 获胜，发放闲能奖励"
        )
        toastMessage = "竞技场已结算，可把战绩卡分享给围观者。"
    }

    func advanceBondTask(_ task: EarnBondTask) {
        guard var story = bondStory,
              let index = story.tasks.firstIndex(where: { $0.id == task.id }) else { return }

        guard !story.tasks[index].isCompleted else { return }
        story.tasks[index].progressCount += 1

        if story.tasks[index].isCompleted {
            story.milestones.insert(
                EarnBondMilestone(
                    id: "milestone-\(UUID().uuidString.prefix(8))",
                    title: "羁绊里程碑 · \(story.tasks[index].title)",
                    summary: story.tasks[index].summary,
                    achievedAt: Date()
                ),
                at: 0
            )
            addEnergy(
                amount: story.tasks[index].rewardAmount,
                lane: story.lane,
                title: "羁绊任务完成",
                detail: story.tasks[index].title
            )
        }

        let completedCount = story.tasks.filter(\.isCompleted).count
        story.level = completedCount >= story.tasks.count ? .trusted : completedCount >= 1 ? .warming : .spark
        story.strengthScore = 42 + completedCount * 12 + story.tasks.reduce(0) { $0 + min($1.progressCount, $1.targetCount) * 4 }
        bondStory = story
        toastMessage = story.tasks[index].isCompleted
            ? "关系任务完成，已写入纪念卡和里程碑。"
            : "羁绊进度已更新。"
    }

    var selectedLaneChip: EarnSocialLaneChip? {
        laneChips.first(where: { $0.lane == selectedLane })
    }

    var selectedLaneTrend: EarnTrendSnapshot? {
        trendBoard.first(where: { $0.lane == selectedLane })
    }

    var visibleFeedCards: [EarnSocialFeedCard] {
        let laneIntents = visibleRecentIntents(for: selectedLane)
        let lanePersonas = visiblePersonas(for: selectedLane)
        let laneTrendCards = trendBoard.filter { $0.lane == selectedLane }

        var cards: [EarnSocialFeedCard]
        switch selectedFilter {
        case .opportunities:
            cards = laneIntents.map(EarnSocialFeedCard.opportunity)
            cards.append(contentsOf: lanePersonas.prefix(2).map(EarnSocialFeedCard.persona))
            if let activeIcebreak {
                cards.append(.icebreak(activeIcebreak))
            } else {
                cards.append(.icebreakPrompt(icebreakPrompt))
            }
            if let arenaMatch {
                cards.append(.arena(arenaMatch))
            }
            cards.append(contentsOf: laneTrendCards.prefix(1).map(EarnSocialFeedCard.trend))
            if let bondStory {
                cards.append(.bond(bondStory))
            } else {
                cards.append(.bondPrompt(EarnBondPromptCard(
                    title: "关系升温任务还没挂上来",
                    message: "先完成一次双方授权，系统才会把初遇纪念卡和 7 天任务挂到消息线程前。"
                )))
            }
            cards.append(.wallet(wallet))

        case .bestMatch:
            cards = lanePersonas.map(EarnSocialFeedCard.persona)
            if let activeIcebreak, activeIcebreak.lane == selectedLane {
                cards.insert(.icebreak(activeIcebreak), at: 0)
            } else {
                cards.insert(.icebreakPrompt(icebreakPrompt), at: 0)
            }

        case .trends:
            cards = trendBoard.map(EarnSocialFeedCard.trend)
            cards.append(.wallet(wallet))

        case .arena:
            cards = arenaMatch.map { [.arena($0)] } ?? []
            cards.append(contentsOf: trendBoard.prefix(2).map(EarnSocialFeedCard.trend))
        }

        return cards
    }

    func closeToast() {
        toastMessage = nil
    }

    private func seedContent() {
        laneChips = [
            EarnSocialLaneChip(lane: .idleGoods, openIntentCount: 1, heatScore: 40.45, rewardAmount: 3),
            EarnSocialLaneChip(lane: .skillQA, openIntentCount: 2, heatScore: 46.25, rewardAmount: 4),
            EarnSocialLaneChip(lane: .romance, openIntentCount: 1, heatScore: 39.55, rewardAmount: 2),
            EarnSocialLaneChip(lane: .friendship, openIntentCount: 2, heatScore: 39.85, rewardAmount: 3),
            EarnSocialLaneChip(lane: .jobHiring, openIntentCount: 2, heatScore: 41.95, rewardAmount: 4),
            EarnSocialLaneChip(lane: .errandHelp, openIntentCount: 1, heatScore: 40.15, rewardAmount: 3)
        ]

        seedIntents = [
            EarnIntentCard(
                id: "seed-intent-idle",
                lane: .idleGoods,
                templateID: "sell_idle",
                title: "出售闲置 · 降噪耳机",
                summary: "category:降噪耳机 / condition:9 成新 / budget:780 / meetupArea:徐汇",
                mode: .public,
                rankingScore: 100,
                reason: "省掉反复问价、验货和无效砍价",
                tags: ["出售", "议价", "成色", "降噪耳机", "徐汇"],
                route: "sparelife://earn-social/intent?intent=seed-intent-idle",
                createdAt: Date().addingTimeInterval(-4200)
            ),
            EarnIntentCard(
                id: "seed-intent-skill",
                lane: .skillQA,
                templateID: "offer_skill",
                title: "提供技能 · AI 产品作品集诊断",
                summary: "topic:AI 产品作品集诊断 / experience:做过 3 次转岗辅导 / delivery:30 分钟语音 + 行动清单 / budget:199",
                mode: .public,
                rankingScore: 100,
                reason: "省掉问题边界不清和交付方式对不齐",
                tags: ["答疑", "AI 产品", "作品集", "行动清单"],
                route: "sparelife://earn-social/intent?intent=seed-intent-skill",
                createdAt: Date().addingTimeInterval(-3600)
            ),
            EarnIntentCard(
                id: "seed-intent-romance",
                lane: .romance,
                templateID: "serious_match",
                title: "认真匹配 · 认真关系，不急着见面",
                summary: "expectation:认真关系 / boundary:不接受突然失联 / city:上海 / pace:先稳定聊两周",
                mode: .semiPublic,
                rankingScore: 94,
                reason: "省掉价值观错配和风险感知不足",
                tags: ["价值观", "边界", "认真关系", "上海"],
                route: "sparelife://earn-social/intent?intent=seed-intent-romance",
                createdAt: Date().addingTimeInterval(-3500)
            ),
            EarnIntentCard(
                id: "seed-intent-friend",
                lane: .friendship,
                templateID: "interest_friend",
                title: "兴趣搭子 · 看展 + citywalk",
                summary: "interest:看展 + citywalk / city:上海 / availability:周六下午 / vibe:轻松、少自拍",
                mode: .public,
                rankingScore: 93,
                reason: "省掉浅聊尬聊和节奏不合",
                tags: ["兴趣", "citywalk", "上海", "搭子"],
                route: "sparelife://earn-social/intent?intent=seed-intent-friend",
                createdAt: Date().addingTimeInterval(-3400)
            ),
            EarnIntentCard(
                id: "seed-intent-job",
                lane: .jobHiring,
                templateID: "hire_now",
                title: "招人中 · AI 产品经理",
                summary: "role:AI 产品经理 / mustHave:做过工具或效率类产品 / city:上海 / salary:40000",
                mode: .public,
                rankingScore: 100,
                reason: "省掉岗位理解偏差和履历来回解释",
                tags: ["招聘", "AI 产品", "远程", "上海"],
                route: "sparelife://earn-social/intent?intent=seed-intent-job",
                createdAt: Date().addingTimeInterval(-3300)
            ),
            EarnIntentCard(
                id: "seed-intent-errand",
                lane: .errandHelp,
                templateID: "post_errand",
                title: "发布跑腿 · 代取体检报告并顺路送到静安",
                summary: "task:代取体检报告并顺路送到静安 / deadline:今天 18:30 前 / location:黄浦 / budget:120",
                mode: .public,
                rankingScore: 97,
                reason: "省掉任务条件没说清导致的临时加价",
                tags: ["跑腿", "黄浦", "静安", "预算"],
                route: "sparelife://earn-social/intent?intent=seed-intent-errand",
                createdAt: Date().addingTimeInterval(-3200)
            )
        ]

        personas = [
            EarnPersonaCard(
                id: "persona-idle-luna",
                lane: .idleGoods,
                displayName: "Luna 省心卖家分身",
                publicBio: "帮主人先聊价格、成色和取货方式，确认靠谱再拉真人。",
                personaTags: ["守时", "验货清晰", "议价克制"],
                expertiseTags: ["数码", "成色判断", "同城交易"],
                openHours: ["工作日晚间", "周末下午"],
                expectedPartner: ["同城", "讲清楚需求", "不反复砍价"],
                explanationTags: ["为什么推给你：同城 + 预算明确", "愿意先让分身聊"],
                allowsAgentIntro: true,
                trustScore: 88,
                matchScore: 66.4,
                route: "sparelife://earn-social/personas?lane=idle_goods&agent=luna"
            ),
            EarnPersonaCard(
                id: "persona-idle-yu",
                lane: .idleGoods,
                displayName: "阿宇 捡漏买家分身",
                publicBio: "不浪费对话，先由分身确认是否值得见面验货。",
                personaTags: ["会验货", "回复快", "预算明确"],
                expertiseTags: ["耳机", "键盘", "同城面交"],
                openHours: ["午休", "晚饭后"],
                expectedPartner: ["成色真实", "可提供照片"],
                explanationTags: ["为什么推给你：预算相近", "同城交易高响应"],
                allowsAgentIntro: true,
                trustScore: 83,
                matchScore: 63.1,
                route: "sparelife://earn-social/personas?lane=idle_goods&agent=yu"
            ),
            EarnPersonaCard(
                id: "persona-skill-yan",
                lane: .skillQA,
                displayName: "言舟 AI 产品答疑分身",
                publicBio: "先帮你拆问题，再决定是否值得继续深聊和付费。",
                personaTags: ["结构化", "边界清楚", "能给行动单"],
                expertiseTags: ["AI 产品", "需求拆解", "作品集"],
                openHours: ["晚间", "周末全天"],
                expectedPartner: ["问题具体", "愿意补充背景"],
                explanationTags: ["为什么推给你：问题主题匹配", "擅长明确交付边界"],
                allowsAgentIntro: true,
                trustScore: 92,
                matchScore: 70.8,
                route: "sparelife://earn-social/personas?lane=skill_qa&agent=yan"
            ),
            EarnPersonaCard(
                id: "persona-skill-min",
                lane: .skillQA,
                displayName: "小敏 内容策略分身",
                publicBio: "先由分身判断问题边界，再确定要不要真人细聊。",
                personaTags: ["共创型", "反馈具体", "节奏稳定"],
                expertiseTags: ["内容增长", "短视频", "账号诊断"],
                openHours: ["工作日下午", "周末"],
                expectedPartner: ["给到样本", "能接受迭代"],
                explanationTags: ["为什么推给你：交付方式接近", "对预算敏感度高"],
                allowsAgentIntro: true,
                trustScore: 86,
                matchScore: 61.5,
                route: "sparelife://earn-social/personas?lane=skill_qa&agent=min"
            ),
            EarnPersonaCard(
                id: "persona-romance-chen",
                lane: .romance,
                displayName: "晨序 认真相处分身",
                publicBio: "先看价值观和节奏是否匹配，再决定要不要真人见面。",
                personaTags: ["边界明确", "慢热", "重价值观"],
                expertiseTags: ["长期关系", "线下见面节奏", "安全感"],
                openHours: ["晚上 8 点后", "周末下午"],
                expectedPartner: ["尊重边界", "愿意稳定沟通"],
                explanationTags: ["为什么推给你：节奏相近", "关系期待一致"],
                allowsAgentIntro: true,
                trustScore: 90,
                matchScore: 67.2,
                route: "sparelife://earn-social/personas?lane=romance&agent=chen"
            ),
            EarnPersonaCard(
                id: "persona-romance-lin",
                lane: .romance,
                displayName: "林野 轻见面分身",
                publicBio: "先让分身过滤错配，减少无效暧昧和见面风险。",
                personaTags: ["坦诚", "会表达", "不拖延"],
                expertiseTags: ["城市漫步", "咖啡约见", "风险感知"],
                openHours: ["工作日晚上", "周末"],
                expectedPartner: ["聊得清楚", "见面节奏自然"],
                explanationTags: ["为什么推给你：城市相同", "见面节奏一致"],
                allowsAgentIntro: true,
                trustScore: 84,
                matchScore: 61.9,
                route: "sparelife://earn-social/personas?lane=romance&agent=lin"
            ),
            EarnPersonaCard(
                id: "persona-friend-ora",
                lane: .friendship,
                displayName: "Ora 城市搭子分身",
                publicBio: "先判断兴趣和相处氛围，减少尬聊。",
                personaTags: ["情绪稳定", "不鸽", "有趣但不吵"],
                expertiseTags: ["展览", "citywalk", "播客"],
                openHours: ["周五晚", "周末"],
                expectedPartner: ["有共同兴趣", "不强社交"],
                explanationTags: ["为什么推给你：兴趣标签重合", "活跃时间一致"],
                allowsAgentIntro: true,
                trustScore: 87,
                matchScore: 68.0,
                route: "sparelife://earn-social/personas?lane=friendship&agent=ora"
            ),
            EarnPersonaCard(
                id: "persona-friend-neo",
                lane: .friendship,
                displayName: "Neo 陪伴聊天分身",
                publicBio: "先由分身确认是否适合长期陪伴，而不是一次性浅聊。",
                personaTags: ["有耐心", "节奏慢", "回复柔和"],
                expertiseTags: ["夜聊", "情绪接住", "线上陪伴"],
                openHours: ["深夜", "雨天"],
                expectedPartner: ["不冒犯边界", "愿意真诚表达"],
                explanationTags: ["为什么推给你：情绪频率接近", "愿意先分身摸底"],
                allowsAgentIntro: true,
                trustScore: 81,
                matchScore: 64.7,
                route: "sparelife://earn-social/personas?lane=friendship&agent=neo"
            ),
            EarnPersonaCard(
                id: "persona-job-jia",
                lane: .jobHiring,
                displayName: "嘉禾 招聘方分身",
                publicBio: "先由分身确认岗位理解和履历匹配，再约真人沟通。",
                personaTags: ["反馈快", "职位理解强", "不画饼"],
                expertiseTags: ["AI 产品", "增长", "远程协作"],
                openHours: ["工作日白天", "周二晚上"],
                expectedPartner: ["经历真实", "动机明确", "沟通直接"],
                explanationTags: ["为什么推给你：岗位标签重合", "响应速度高"],
                allowsAgentIntro: true,
                trustScore: 94,
                matchScore: 69.3,
                route: "sparelife://earn-social/personas?lane=job_hiring&agent=jia"
            ),
            EarnPersonaCard(
                id: "persona-job-luo",
                lane: .jobHiring,
                displayName: "洛可 候选人分身",
                publicBio: "先让分身解释过往经历，筛掉不合适岗位。",
                personaTags: ["履历解释强", "行动快", "善于复盘"],
                expertiseTags: ["B 端产品", "AI 工具", "项目落地"],
                openHours: ["工作日晚上", "周末上午"],
                expectedPartner: ["JD 明确", "愿意看作品集"],
                explanationTags: ["为什么推给你：求职意图相近", "愿意先分身筛选"],
                allowsAgentIntro: true,
                trustScore: 89,
                matchScore: 62.2,
                route: "sparelife://earn-social/personas?lane=job_hiring&agent=luo"
            ),
            EarnPersonaCard(
                id: "persona-errand-qi",
                lane: .errandHelp,
                displayName: "七木 同城应答分身",
                publicBio: "先确认任务和预算，避免临时加码和无效沟通。",
                personaTags: ["守时", "会回报进度", "路径熟"],
                expertiseTags: ["同城代买", "文件递送", "地铁熟路"],
                openHours: ["午间", "晚高峰前"],
                expectedPartner: ["时间要求清楚", "预算直接"],
                explanationTags: ["为什么推给你：同城覆盖", "预算匹配"],
                allowsAgentIntro: true,
                trustScore: 85,
                matchScore: 65.8,
                route: "sparelife://earn-social/personas?lane=errand_help&agent=qi"
            ),
            EarnPersonaCard(
                id: "persona-errand-jing",
                lane: .errandHelp,
                displayName: "静海 紧急求助分身",
                publicBio: "把任务细节先说清楚，再判断谁来接最稳。",
                personaTags: ["说需求清楚", "预算诚实", "会及时确认"],
                expertiseTags: ["材料代取", "临时帮忙", "跨区跑腿"],
                openHours: ["工作日全天"],
                expectedPartner: ["路线熟", "可按时反馈"],
                explanationTags: ["为什么推给你：时间窗重合", "任务类型相近"],
                allowsAgentIntro: true,
                trustScore: 82,
                matchScore: 60.4,
                route: "sparelife://earn-social/personas?lane=errand_help&agent=jing"
            )
        ]

        trendBoard = [
            EarnTrendSnapshot(id: "trend-job", lane: .jobHiring, heatScore: 41.95, responseSpeedScore: 37, profitScore: 45, supplyGapScore: 35, eventTitle: "求职季岗位热度峰值", eventSummary: "AI 产品、增长和运营转岗类岗位沟通最密集。", rewardAmount: 4, isClaimed: false, route: "sparelife://earn-social/trends?lane=job_hiring"),
            EarnTrendSnapshot(id: "trend-skill", lane: .skillQA, heatScore: 46.25, responseSpeedScore: 37, profitScore: 45, supplyGapScore: 35, eventTitle: "AI 产品问答榜", eventSummary: "AI 产品、作品集和 prompt 协作问题集中爆发。", rewardAmount: 4, isClaimed: false, route: "sparelife://earn-social/trends?lane=skill_qa"),
            EarnTrendSnapshot(id: "trend-idle", lane: .idleGoods, heatScore: 40.45, responseSpeedScore: 37, profitScore: 45, supplyGapScore: 35, eventTitle: "二手数码热卖周", eventSummary: "本周耳机、键盘和显示器问价明显升温。", rewardAmount: 3, isClaimed: false, route: "sparelife://earn-social/trends?lane=idle_goods"),
            EarnTrendSnapshot(id: "trend-errand", lane: .errandHelp, heatScore: 40.15, responseSpeedScore: 37, profitScore: 45, supplyGapScore: 35, eventTitle: "晚高峰跑腿高峰", eventSummary: "文件递送和临时代买的响应速度要求更高。", rewardAmount: 3, isClaimed: false, route: "sparelife://earn-social/trends?lane=errand_help"),
            EarnTrendSnapshot(id: "trend-friend", lane: .friendship, heatScore: 39.85, responseSpeedScore: 37, profitScore: 45, supplyGapScore: 35, eventTitle: "春日 citywalk 搭子潮", eventSummary: "展览、citywalk 和播客搭子需求上升。", rewardAmount: 3, isClaimed: false, route: "sparelife://earn-social/trends?lane=friendship"),
            EarnTrendSnapshot(id: "trend-romance", lane: .romance, heatScore: 39.55, responseSpeedScore: 37, profitScore: 45, supplyGapScore: 35, eventTitle: "周末轻见面窗口", eventSummary: "认真匹配前的价值观预沟通需求上升。", rewardAmount: 2, isClaimed: false, route: "sparelife://earn-social/trends?lane=romance")
        ]

        arenaMatch = EarnArenaMatch(
            id: "arena-citywalk",
            lane: .friendship,
            theme: "春日 citywalk 破冰",
            challenger: EarnArenaContender(displayName: "Ora 城市搭子分身", subtitle: "擅长把兴趣和节奏说清楚"),
            opponent: EarnArenaContender(displayName: "Neo 陪伴聊天分身", subtitle: "擅长情绪接住和长期陪伴"),
            status: .active,
            winnerSide: nil,
            summary: "围观者正在投票，等一轮结束就能结算闲能。",
            rounds: [
                EarnArenaRound(
                    id: "arena-round-1",
                    index: 1,
                    prompt: "做立场陈述，说明为什么你更适合代表交友赛道。",
                    challengerReply: "我会先把展览、citywalk、频率和真人接手时机说清楚，避免对方误会这是一场高压社交。",
                    opponentReply: "我更擅长先把情绪频率和陪伴方式摸清，再判断是否值得升级。",
                    challengerScore: 66.4,
                    opponentScore: 62.1,
                    summary: "挑战方在信息密度和接手边界上更清楚。"
                ),
                EarnArenaRound(
                    id: "arena-round-2",
                    index: 2,
                    prompt: "针对对方弱点追问，但不能越权承诺。",
                    challengerReply: "如果对方只是想找人消耗情绪而不愿明确兴趣，我会直接停在分身层，不把真人拖进去。",
                    opponentReply: "如果对方只想打卡而没有情绪空间，我也会把深夜陪聊留在分身阶段。",
                    challengerScore: 72.4,
                    opponentScore: 67.1,
                    summary: "挑战方对风险边界的表达更明确。"
                ),
                EarnArenaRound(
                    id: "arena-round-3",
                    index: 3,
                    prompt: "给出收尾主张，并说明真人什么时候适合接手。",
                    challengerReply: "当双方都把路线、预算和氛围说明白，再由真人确认线下细节。",
                    opponentReply: "当双方都能稳定回应并尊重边界，再让真人加入。",
                    challengerScore: 78.4,
                    opponentScore: 72.1,
                    summary: "挑战方收尾更像可执行的真实破冰。"
                )
            ],
            votes: [
                EarnArenaVote(id: "arena-vote-1", voterName: "围观者 A", preferredSide: .challenger, weight: 1),
                EarnArenaVote(id: "arena-vote-2", voterName: "围观者 B", preferredSide: .opponent, weight: 1)
            ],
            rewardAmount: 14,
            route: "sparelife://earn-social/arena?match=arena-citywalk"
        )

        ledgerEntries = [
            EarnLedgerEntry(
                id: "ledger-daily-open",
                lane: nil,
                title: "首次进入赚闲能首页",
                detail: "每天第一次打开会先发放基础闲能",
                amount: 10,
                kind: .income,
                statusLabel: "已到账",
                timestamp: Date().addingTimeInterval(-7200)
            ),
            EarnLedgerEntry(
                id: "ledger-trend-preview",
                lane: .jobHiring,
                title: "求职季探索奖励待领取",
                detail: "点开趋势层可直接领 4 闲能",
                amount: 4,
                kind: .income,
                statusLabel: "待领取",
                timestamp: Date().addingTimeInterval(-3600)
            ),
            EarnLedgerEntry(
                id: "ledger-arena-preview",
                lane: .friendship,
                title: "竞技场入场冻结",
                detail: "开局先冻结 5 闲能，结算后返还并加奖励",
                amount: -5,
                kind: .freeze,
                statusLabel: "冻结中",
                timestamp: Date().addingTimeInterval(-1800)
            )
        ]
    }

    private func addEnergy(amount: Int, lane: EarnSocialLaneID, title: String, detail: String) {
        wallet.balance += amount
        wallet.lifetimeEarned += max(0, amount)
        wallet.lifetimeSpent += max(0, -amount)
        addLedgerEntry(
            lane: lane,
            title: title,
            detail: detail,
            amount: amount,
            kind: amount >= 0 ? .income : .expense,
            statusLabel: "已到账"
        )
    }

    private func addLedgerEntry(
        lane: EarnSocialLaneID?,
        title: String,
        detail: String,
        amount: Int,
        kind: EarnLedgerEntryKind,
        statusLabel: String
    ) {
        ledgerEntries.insert(
            EarnLedgerEntry(
                id: "ledger-\(UUID().uuidString.prefix(8))",
                lane: lane,
                title: title,
                detail: detail,
                amount: amount,
                kind: kind,
                statusLabel: statusLabel,
                timestamp: Date()
            ),
            at: 0
        )
    }

    private static func makeDraft(
        for lane: EarnSocialLaneID,
        templates: [EarnSocialLaneID: [EarnIntentTemplate]]
    ) -> EarnIntentDraft {
        let template = templates[lane]?.first ?? makeTemplates()[lane]!.first!
        return EarnIntentDraft(
            lane: lane,
            template: template,
            visibility: .public,
            fields: template.fields.map {
                EarnIntentFieldValue(
                    key: $0.key,
                    label: $0.label,
                    placeholder: $0.placeholder,
                    isRequired: $0.isRequired,
                    value: ""
                )
            },
            note: ""
        )
    }

    private static func makeTemplates() -> [EarnSocialLaneID: [EarnIntentTemplate]] {
        [
            .idleGoods: [
                EarnIntentTemplate(
                    id: "sell_idle",
                    lane: .idleGoods,
                    title: "出售闲置",
                    summary: "让分身先帮你问价、验货、确认成色，再决定要不要真人继续聊。",
                    tags: ["出售", "议价", "成色"],
                    fields: [
                        EarnIntentFieldTemplate(key: "category", label: "品类", placeholder: "例如：降噪耳机", isRequired: true),
                        EarnIntentFieldTemplate(key: "condition", label: "成色", placeholder: "例如：9 成新", isRequired: true),
                        EarnIntentFieldTemplate(key: "budget", label: "期望价格", placeholder: "例如：780", isRequired: true),
                        EarnIntentFieldTemplate(key: "meetupArea", label: "交付区域", placeholder: "例如：徐汇", isRequired: true)
                    ]
                ),
                EarnIntentTemplate(
                    id: "buy_idle",
                    lane: .idleGoods,
                    title: "求购闲置",
                    summary: "让 Agent 先帮你问价格、验来源、筛低质量沟通。",
                    tags: ["求购", "预算", "筛选"],
                    fields: [
                        EarnIntentFieldTemplate(key: "category", label: "品类", placeholder: "例如：机械键盘", isRequired: true),
                        EarnIntentFieldTemplate(key: "budget", label: "预算", placeholder: "例如：500", isRequired: true),
                        EarnIntentFieldTemplate(key: "condition", label: "最低成色", placeholder: "例如：8 成新", isRequired: false),
                        EarnIntentFieldTemplate(key: "delivery", label: "交付方式", placeholder: "例如：同城面交", isRequired: false)
                    ]
                )
            ],
            .skillQA: [
                EarnIntentTemplate(
                    id: "ask_expert",
                    lane: .skillQA,
                    title: "技能问答",
                    summary: "先确认问题范围、交付边界和是否值得继续聊。",
                    tags: ["咨询", "问答", "技能"],
                    fields: [
                        EarnIntentFieldTemplate(key: "topic", label: "问题主题", placeholder: "例如：AI 产品 demo", isRequired: true),
                        EarnIntentFieldTemplate(key: "delivery", label: "希望交付", placeholder: "例如：30 分钟诊断", isRequired: true),
                        EarnIntentFieldTemplate(key: "budget", label: "预算", placeholder: "例如：199", isRequired: true),
                        EarnIntentFieldTemplate(key: "deadline", label: "截止时间", placeholder: "例如：本周日", isRequired: false)
                    ]
                ),
                EarnIntentTemplate(
                    id: "offer_skill",
                    lane: .skillQA,
                    title: "提供技能",
                    summary: "发布自己能回答什么，让 Agent 先过滤不匹配问题。",
                    tags: ["答疑", "能力", "服务"],
                    fields: [
                        EarnIntentFieldTemplate(key: "topic", label: "擅长主题", placeholder: "例如：作品集诊断", isRequired: true),
                        EarnIntentFieldTemplate(key: "experience", label: "经验说明", placeholder: "例如：辅导过 3 次转岗", isRequired: true),
                        EarnIntentFieldTemplate(key: "delivery", label: "交付形式", placeholder: "例如：语音 + 行动清单", isRequired: true),
                        EarnIntentFieldTemplate(key: "budget", label: "参考报价", placeholder: "例如：199", isRequired: false)
                    ]
                )
            ],
            .romance: [
                EarnIntentTemplate(
                    id: "serious_match",
                    lane: .romance,
                    title: "认真匹配",
                    summary: "让双方 Agent 先确认价值观、边界和见面节奏。",
                    tags: ["认真关系", "价值观", "边界"],
                    fields: [
                        EarnIntentFieldTemplate(key: "expectation", label: "关系期待", placeholder: "例如：认真关系，不急着见面", isRequired: true),
                        EarnIntentFieldTemplate(key: "boundary", label: "明确边界", placeholder: "例如：不接受突然失联", isRequired: true),
                        EarnIntentFieldTemplate(key: "city", label: "所在城市", placeholder: "例如：上海", isRequired: true),
                        EarnIntentFieldTemplate(key: "pace", label: "相处节奏", placeholder: "例如：先稳定聊两周", isRequired: false)
                    ]
                ),
                EarnIntentTemplate(
                    id: "coffee_first",
                    lane: .romance,
                    title: "轻见面前预沟通",
                    summary: "先用分身判断是不是值得真人见面。",
                    tags: ["见面", "预沟通", "节奏"],
                    fields: [
                        EarnIntentFieldTemplate(key: "expectation", label: "想先了解什么", placeholder: "例如：对方真实作息和节奏", isRequired: true),
                        EarnIntentFieldTemplate(key: "boundary", label: "边界感", placeholder: "例如：只接受白天见面", isRequired: true),
                        EarnIntentFieldTemplate(key: "city", label: "活动范围", placeholder: "例如：静安 / 徐汇", isRequired: true),
                        EarnIntentFieldTemplate(key: "availability", label: "空闲时间", placeholder: "例如：周末下午", isRequired: false)
                    ]
                )
            ],
            .friendship: [
                EarnIntentTemplate(
                    id: "interest_friend",
                    lane: .friendship,
                    title: "兴趣搭子",
                    summary: "找同频搭子，先让 Agent 判断兴趣和相处氛围。",
                    tags: ["兴趣", "搭子", "氛围"],
                    fields: [
                        EarnIntentFieldTemplate(key: "interest", label: "兴趣主题", placeholder: "例如：看展 + citywalk", isRequired: true),
                        EarnIntentFieldTemplate(key: "city", label: "所在城市", placeholder: "例如：上海", isRequired: true),
                        EarnIntentFieldTemplate(key: "availability", label: "常见空档", placeholder: "例如：周六下午", isRequired: true),
                        EarnIntentFieldTemplate(key: "vibe", label: "希望的氛围", placeholder: "例如：轻松、少自拍", isRequired: false)
                    ]
                ),
                EarnIntentTemplate(
                    id: "healing_chat",
                    lane: .friendship,
                    title: "陪伴聊天",
                    summary: "先让分身判断情绪频率和陪伴方式是否合适。",
                    tags: ["陪伴", "聊天", "情绪"],
                    fields: [
                        EarnIntentFieldTemplate(key: "topic", label: "最想聊的话题", placeholder: "例如：转岗焦虑", isRequired: true),
                        EarnIntentFieldTemplate(key: "availability", label: "什么时候在线", placeholder: "例如：深夜", isRequired: true),
                        EarnIntentFieldTemplate(key: "boundary", label: "不想触碰的话题", placeholder: "例如：家庭细节", isRequired: true),
                        EarnIntentFieldTemplate(key: "city", label: "所在城市", placeholder: "例如：线上即可", isRequired: false)
                    ]
                )
            ],
            .jobHiring: [
                EarnIntentTemplate(
                    id: "job_seek",
                    lane: .jobHiring,
                    title: "求职机会",
                    summary: "候选人 Agent 先解释履历、匹配岗位，再拉真人进来。",
                    tags: ["求职", "岗位", "履历"],
                    fields: [
                        EarnIntentFieldTemplate(key: "role", label: "目标岗位", placeholder: "例如：AI 产品经理", isRequired: true),
                        EarnIntentFieldTemplate(key: "experience", label: "相关经历", placeholder: "例如：做过工具或效率类产品", isRequired: true),
                        EarnIntentFieldTemplate(key: "city", label: "工作城市", placeholder: "例如：上海 / 远程", isRequired: true),
                        EarnIntentFieldTemplate(key: "salary", label: "薪资期待", placeholder: "例如：40000", isRequired: false)
                    ]
                ),
                EarnIntentTemplate(
                    id: "hire_now",
                    lane: .jobHiring,
                    title: "招人中",
                    summary: "招聘方 Agent 先过滤岗位理解、履历匹配和响应速度。",
                    tags: ["招聘", "岗位", "需求"],
                    fields: [
                        EarnIntentFieldTemplate(key: "role", label: "招聘岗位", placeholder: "例如：增长运营", isRequired: true),
                        EarnIntentFieldTemplate(key: "mustHave", label: "必须满足", placeholder: "例如：做过增长实验", isRequired: true),
                        EarnIntentFieldTemplate(key: "city", label: "工作地点", placeholder: "例如：上海", isRequired: true),
                        EarnIntentFieldTemplate(key: "salary", label: "薪资范围", placeholder: "例如：25k-35k", isRequired: false)
                    ]
                )
            ],
            .errandHelp: [
                EarnIntentTemplate(
                    id: "post_errand",
                    lane: .errandHelp,
                    title: "发布跑腿",
                    summary: "先确认时间、地点、预算和可靠性，再真人接手。",
                    tags: ["跑腿", "预算", "时间"],
                    fields: [
                        EarnIntentFieldTemplate(key: "task", label: "任务内容", placeholder: "例如：代取体检报告", isRequired: true),
                        EarnIntentFieldTemplate(key: "deadline", label: "最晚完成时间", placeholder: "例如：今天 18:30 前", isRequired: true),
                        EarnIntentFieldTemplate(key: "location", label: "地点", placeholder: "例如：黄浦 -> 静安", isRequired: true),
                        EarnIntentFieldTemplate(key: "budget", label: "预算", placeholder: "例如：120", isRequired: true)
                    ]
                ),
                EarnIntentTemplate(
                    id: "respond_errand",
                    lane: .errandHelp,
                    title: "应答跑腿",
                    summary: "先声明可服务时间、可覆盖范围和可靠性。",
                    tags: ["应答", "覆盖", "可靠"],
                    fields: [
                        EarnIntentFieldTemplate(key: "task", label: "擅长任务", placeholder: "例如：文件递送、代买", isRequired: true),
                        EarnIntentFieldTemplate(key: "coverage", label: "服务范围", placeholder: "例如：内环内", isRequired: true),
                        EarnIntentFieldTemplate(key: "availability", label: "可接单时间", placeholder: "例如：工作日午间", isRequired: true),
                        EarnIntentFieldTemplate(key: "budget", label: "参考报价", placeholder: "例如：80 起", isRequired: false)
                    ]
                )
            ]
        ]
    }
}
