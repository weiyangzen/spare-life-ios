// LeadResultView.swift
// Spare Life – 赛道撮合结果与结算
// Blueprint §3.3 功能点 赛道撮合结果与结算 (line:1136)
// UIUX lane – slot 2

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Lead Result Models

enum LeadOutcomeStatus: String, CaseIterable, Identifiable {
    case pending     = "pending"
    case matched     = "matched"
    case inProgress  = "in_progress"
    case completed   = "completed"
    case disputed    = "disputed"
    case cancelled   = "cancelled"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pending:    return "等待确认"
        case .matched:    return "撮合成功"
        case .inProgress: return "进行中"
        case .completed:  return "已完成"
        case .disputed:   return "争议中"
        case .cancelled:  return "已取消"
        }
    }

    var icon: String {
        switch self {
        case .pending:    return "clock.fill"
        case .matched:    return "sparkles"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .completed:  return "checkmark.seal.fill"
        case .disputed:   return "exclamationmark.triangle.fill"
        case .cancelled:  return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .pending:    return .emotionNeutral
        case .matched:    return .spareYellow
        case .inProgress: return .spareYellowInk
        case .completed:  return .emotionPositive
        case .disputed:   return .emotionNegative
        case .cancelled:  return .secondary
        }
    }
}

struct LeadAuditEvent: Identifiable, Hashable {
    let id: String
    let timestamp: Date
    let actor: String     // "你的分身" / "对方分身" / "系统"
    let action: String    // human-readable
    let detail: String?
}

struct LeadResultSnapshot: Identifiable {
    let id: String
    let lane: EarnSocialLaneID
    let counterpartName: String
    let counterpartAvatarSeed: Int
    let status: LeadOutcomeStatus
    let matchedAt: Date?
    let completedAt: Date?
    let agentSummary: String   // what the agents negotiated
    let agreedTerms: [String]  // bullet list of agreed terms
    let earnedEnergy: Int      // positive = earned, negative = spent
    let auditTrail: [LeadAuditEvent]
    var reviewText: String?
    var reviewRating: Int?     // 1-5

    static func empty(lane: EarnSocialLaneID) -> LeadResultSnapshot {
        LeadResultSnapshot(
            id: UUID().uuidString,
            lane: lane,
            counterpartName: "—",
            counterpartAvatarSeed: 0,
            status: .pending,
            matchedAt: nil,
            completedAt: nil,
            agentSummary: "",
            agreedTerms: [],
            earnedEnergy: 0,
            auditTrail: []
        )
    }
}

// MARK: - Lead Result Store

enum LeadResultLoadState {
    case idle, loading, loaded, error(String)
}

@MainActor
final class LeadResultStore: ObservableObject {
    @Published private(set) var loadState: LeadResultLoadState = .idle
    @Published private(set) var result: LeadResultSnapshot?
    @Published var showReviewSheet = false
    @Published var draftReviewText: String = ""
    @Published var draftRating: Int = 0

    private let leadID: String
    private let lane: EarnSocialLaneID

    init(leadID: String, lane: EarnSocialLaneID) {
        self.leadID = leadID
        self.lane = lane
    }

    func load() {
        guard case .idle = loadState else { return }
        loadState = .loading
        Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            self.result = Self.mockResult(leadID: leadID, lane: lane)
            self.loadState = .loaded
        }
    }

    func openReview() { showReviewSheet = true }
    func closeReview() { showReviewSheet = false; draftReviewText = ""; draftRating = 0 }

    func submitReview() {
        guard draftRating > 0 else { return }
        result = result.map { snap in
            LeadResultSnapshot(
                id: snap.id, lane: snap.lane,
                counterpartName: snap.counterpartName,
                counterpartAvatarSeed: snap.counterpartAvatarSeed,
                status: snap.status, matchedAt: snap.matchedAt,
                completedAt: snap.completedAt, agentSummary: snap.agentSummary,
                agreedTerms: snap.agreedTerms, earnedEnergy: snap.earnedEnergy,
                auditTrail: snap.auditTrail,
                reviewText: draftReviewText, reviewRating: draftRating
            )
        }
        closeReview()
    }

    func dispute() {
        result = result.map { snap in
            LeadResultSnapshot(
                id: snap.id, lane: snap.lane,
                counterpartName: snap.counterpartName,
                counterpartAvatarSeed: snap.counterpartAvatarSeed,
                status: .disputed, matchedAt: snap.matchedAt,
                completedAt: snap.completedAt, agentSummary: snap.agentSummary,
                agreedTerms: snap.agreedTerms, earnedEnergy: snap.earnedEnergy,
                auditTrail: snap.auditTrail + [
                    LeadAuditEvent(
                        id: UUID().uuidString,
                        timestamp: Date(),
                        actor: "你",
                        action: "发起争议",
                        detail: nil
                    )
                ],
                reviewText: snap.reviewText, reviewRating: snap.reviewRating
            )
        }
    }

    func retry() {
        loadState = .idle
        load()
    }

    // MARK: - Mock

    private static func mockResult(leadID: String, lane: EarnSocialLaneID) -> LeadResultSnapshot {
        let now = Date()
        let events: [LeadAuditEvent] = [
            LeadAuditEvent(id: "e1", timestamp: now - 3600 * 3, actor: "你的分身",
                           action: "发布需求意图", detail: lane.summary),
            LeadAuditEvent(id: "e2", timestamp: now - 3600 * 2, actor: "对方分身",
                           action: "应答并确认边界", detail: "确认预算与交付方式"),
            LeadAuditEvent(id: "e3", timestamp: now - 3600, actor: "系统",
                           action: "双方 Agent 完成预撮合", detail: "进入结算环节"),
            LeadAuditEvent(id: "e4", timestamp: now - 1800, actor: "你",
                           action: "真人确认接手", detail: nil),
        ]
        let terms: [String]
        let energy: Int
        let status: LeadOutcomeStatus
        switch lane {
        case .idleGoods:
            terms = ["成交价：闲能 80", "验货：无争议", "7 天内交付"]
            energy = 80; status = .completed
        case .skillQA:
            terms = ["问题范围：Swift 并发", "交付：1,500 字文档", "报酬：闲能 40"]
            energy = 40; status = .completed
        case .romance:
            terms = ["双方同意线下初见", "地点：咖啡馆", "时间：本周末"]
            energy = -10; status = .matched
        case .friendship:
            terms = ["共同爱好：桌游、电影", "加入搭子群", "本月活动优先通知"]
            energy = 5; status = .inProgress
        case .jobHiring:
            terms = ["岗位：iOS 工程师", "薪资范围确认", "简历进入下一轮"]
            energy = 0; status = .matched
        case .errandHelp:
            terms = ["任务：代购奶茶", "时间：今晚 6pm", "报酬：闲能 15 + 实物"]
            energy = 15; status = .completed
        }
        return LeadResultSnapshot(
            id: leadID,
            lane: lane,
            counterpartName: "林熙",
            counterpartAvatarSeed: 7,
            status: status,
            matchedAt: now - 3600 * 2,
            completedAt: status == .completed ? now - 30 * 60 : nil,
            agentSummary: "双方 Agent 经过 \(events.count) 轮协商，完成了「\(lane.shortcut)」的核心条件对齐，真人只需在最终环节确认即可。",
            agreedTerms: terms,
            earnedEnergy: energy,
            auditTrail: events
        )
    }
}

// MARK: - Lead Result View

struct LeadResultView: View {
    let leadID: String
    let lane: EarnSocialLaneID

    @StateObject private var store: LeadResultStore

    init(leadID: String, lane: EarnSocialLaneID) {
        self.leadID = leadID
        self.lane = lane
        _store = StateObject(wrappedValue: LeadResultStore(leadID: leadID, lane: lane))
    }

    var body: some View {
        Group {
            switch store.loadState {
            case .idle, .loading:
                loadingBody
            case .loaded:
                if let result = store.result {
                    loadedBody(result: result)
                } else {
                    emptyBody
                }
            case .error(let msg):
                ErrorStateView(message: msg, retry: store.retry)
            }
        }
        .navigationTitle("撮合结果")
        .spareNavigationBarTitleDisplayMode(.inline)
        .task { store.load() }
        .sheet(isPresented: $store.showReviewSheet) {
            reviewSheet
                .presentationDragIndicator(.visible)
                .presentationDetents([.medium])
        }
    }

    // MARK: - Loading

    private var loadingBody: some View {
        VStack(spacing: Spacing.xl) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(Color.cardBackground)
                    .frame(height: 80)
                    .shimmer()
            }
        }
        .padding(Spacing.lg)
    }

    // MARK: - Empty

    private var emptyBody: some View {
        EmptyStateView(
            icon: "doc.questionmark",
            title: "暂无结果",
            message: "当前赛道尚无撮合记录，发起一次 A2A 匹配试试。",
            actionLabel: nil
        )
    }

    // MARK: - Loaded

    private func loadedBody(result: LeadResultSnapshot) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                statusHeaderCard(result: result)
                agentSummaryCard(result: result)
                agreedTermsCard(result: result)
                settlementCard(result: result)
                auditTrailCard(result: result)
                if result.reviewRating == nil && result.status == .completed {
                    reviewPromptCard(result: result)
                } else if let rating = result.reviewRating {
                    reviewedCard(result: result, rating: rating)
                }
                if result.status == .completed || result.status == .matched {
                    disputeButton(result: result)
                }
            }
            .padding(Spacing.lg)
            .padding(.bottom, Spacing.xxxl)
        }
    }

    // MARK: - Status Header Card

    private func statusHeaderCard(result: LeadResultSnapshot) -> some View {
        HStack(alignment: .center, spacing: Spacing.lg) {
            AvatarView(name: result.counterpartName, size: 54,
                       avatarURL: nil)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(result.counterpartName)
                    .font(.spareTitle3)

                Text(result.lane.shortcut)
                    .font(.spareCaption)
                    .foregroundColor(.secondary)

                HStack(spacing: Spacing.xs) {
                    Image(systemName: result.status.icon)
                        .foregroundColor(result.status.color)
                    Text(result.status.label)
                        .font(.spareCaptionSB)
                        .foregroundColor(result.status.color)
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(
                    Capsule().fill(result.status.color.opacity(0.12))
                )
            }

            Spacer()

            Image(systemName: result.lane.symbol)
                .font(.system(size: 28))
                .foregroundColor(.spareYellow)
        }
        .padding(Spacing.lg)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .cardShadow()
    }

    // MARK: - Agent Summary Card

    private func agentSummaryCard(result: LeadResultSnapshot) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label("Agent 协商摘要", systemImage: "sparkles.rectangle.stack")
                .font(.spareBodySB)

            Text(result.agentSummary)
                .font(.spareBody)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let matched = result.matchedAt {
                Text("撮合时间：\(matched, style: .relative)前")
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(Color.cardBackground)
        )
        .cardShadow()
    }

    // MARK: - Agreed Terms Card

    private func agreedTermsCard(result: LeadResultSnapshot) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label("约定条款", systemImage: "list.bullet.clipboard.fill")
                .font(.spareBodySB)

            if result.agreedTerms.isEmpty {
                Text("暂无约定条款")
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    ForEach(result.agreedTerms, id: \.self) { term in
                        HStack(alignment: .top, spacing: Spacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.emotionPositive)
                                .font(.system(size: 14))
                            Text(term)
                                .font(.spareBody)
                        }
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .cardShadow()
    }

    // MARK: - Settlement Card

    private func settlementCard(result: LeadResultSnapshot) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Label("结算", systemImage: "bolt.circle.fill")
                    .font(.spareBodySB)
                if result.earnedEnergy == 0 {
                    Text("本次无闲能结算")
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if result.earnedEnergy != 0 {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: result.earnedEnergy > 0
                          ? "plus.circle.fill" : "minus.circle.fill")
                        .foregroundColor(result.earnedEnergy > 0
                                         ? .emotionPositive : .emotionNegative)
                    Text("\(abs(result.earnedEnergy)) 闲能")
                        .font(.spareTitle3)
                        .foregroundColor(result.earnedEnergy > 0
                                         ? .emotionPositive : .emotionNegative)
                }
            }
        }
        .padding(Spacing.lg)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .cardShadow()
    }

    // MARK: - Audit Trail Card

    private func auditTrailCard(result: LeadResultSnapshot) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label("审计链", systemImage: "clock.badge.checkmark.fill")
                .font(.spareBodySB)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(result.auditTrail.enumerated()), id: \.element.id) { idx, event in
                    auditRow(event: event, isLast: idx == result.auditTrail.count - 1)
                }
            }
        }
        .padding(Spacing.lg)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .cardShadow()
    }

    private func auditRow(event: LeadAuditEvent, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            VStack(spacing: 0) {
                Circle()
                    .fill(Color.spareYellow)
                    .frame(width: 8, height: 8)
                    .padding(.top, 5)
                if !isLast {
                    Rectangle()
                        .fill(Color.cardStroke)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, Spacing.xxs)
                }
            }
            .frame(width: 8)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack {
                    Text(event.actor)
                        .font(.spareCaptionSB)
                    Spacer()
                    Text(event.timestamp, style: .relative)
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }
                Text(event.action)
                    .font(.spareBody)
                if let detail = event.detail {
                    Text(detail)
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, isLast ? 0 : Spacing.lg)
        }
    }

    // MARK: - Review Cards

    private func reviewPromptCard(result: LeadResultSnapshot) -> some View {
        Button { store.openReview() } label: {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("对这次撮合打个分")
                        .font(.spareBodySB)
                    Text("帮助我们优化 Agent 匹配质量")
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(Spacing.lg)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
            .cardShadow()
        }
        .buttonStyle(.plain)
    }

    private func reviewedCard(result: LeadResultSnapshot, rating: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("你的评价", systemImage: "star.fill")
                .font(.spareBodySB)
                .foregroundColor(.spareYellow)

            starRow(rating: rating)

            if let text = result.reviewText, !text.isEmpty {
                Text(text)
                    .font(.spareBody)
                    .foregroundColor(.secondary)
            }
        }
        .padding(Spacing.lg)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .cardShadow()
    }

    private func disputeButton(result: LeadResultSnapshot) -> some View {
        Button { store.dispute() } label: {
            Label("对结果有异议", systemImage: "exclamationmark.triangle")
                .font(.spareCaptionSB)
                .foregroundColor(.emotionNegative)
        }
        .frame(maxWidth: .infinity)
        .disabled(result.status == .disputed)
    }

    // MARK: - Review Sheet

    private var reviewSheet: some View {
        NavigationStack {
            VStack(spacing: Spacing.xl) {
                Text("这次撮合体验如何？")
                    .font(.spareTitle3)

                starRow(rating: store.draftRating, interactive: true)

                TextField("可选：说说你的感受", text: $store.draftReviewText, axis: .vertical)
                    .font(.spareBody)
                    .padding(Spacing.md)
                    .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
                    .lineLimit(3...6)

                Spacer()

                Button {
                    store.submitReview()
                } label: {
                    Text("提交评价")
                        .font(.spareBodySB)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(store.draftRating > 0 ? Color.spareYellow : Color.secondary,
                                    in: RoundedRectangle(cornerRadius: CornerRadius.pill))
                }
                .disabled(store.draftRating == 0)
            }
            .padding(Spacing.xl)
            .navigationTitle("评价撮合")
            .spareNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { store.closeReview() }
                }
            }
        }
    }

    private func starRow(rating: Int, interactive: Bool = false) -> some View {
        HStack(spacing: Spacing.sm) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: interactive ? 32 : 20))
                    .foregroundColor(.spareYellow)
                    .onTapGesture {
                        if interactive { store.draftRating = star }
                    }
            }
        }
    }
}

// MARK: - Lead Results List (entry point for a lane's result history)

struct LeadResultsListView: View {
    let lane: EarnSocialLaneID

    @State private var mockLeads: [LeadResultSnapshot] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                loadingBody
            } else if mockLeads.isEmpty {
                emptyBody
            } else {
                listBody
            }
        }
        .navigationTitle("\(lane.shortcut)结果")
        .spareNavigationBarTitleDisplayMode(.inline)
        .task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            mockLeads = Self.buildMockList(lane: lane)
            isLoading = false
        }
    }

    private var loadingBody: some View {
        List {
            ForEach(0..<5, id: \.self) { _ in
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(Color.cardBackground)
                    .frame(height: 72)
                    .shimmer()
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }

    private var emptyBody: some View {
        EmptyStateView(
            icon: "tray",
            title: "暂无撮合记录",
            message: "在赚闲能首页发起 \(lane.shortcut) 后，结果会显示在这里。"
        )
    }

    private var listBody: some View {
        List(mockLeads) { lead in
            NavigationLink {
                LeadResultView(leadID: lead.id, lane: lead.lane)
            } label: {
                leadRow(lead)
            }
            .listRowBackground(Color.cardBackground)
            .listRowSeparatorTint(Color.cardStroke)
        }
        .listStyle(.plain)
    }

    private func leadRow(_ lead: LeadResultSnapshot) -> some View {
        HStack(spacing: Spacing.md) {
            AvatarView(name: lead.counterpartName, size: 44)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(lead.counterpartName)
                    .font(.spareBodySB)
                Text(lead.agentSummary.prefix(40) + "…")
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: Spacing.xs) {
                HStack(spacing: 3) {
                    Image(systemName: lead.status.icon)
                        .foregroundColor(lead.status.color)
                        .font(.spareMicro)
                    Text(lead.status.label)
                        .font(.spareMicro)
                        .foregroundColor(lead.status.color)
                }
                if lead.earnedEnergy != 0 {
                    Text("\(lead.earnedEnergy > 0 ? "+" : "")\(lead.earnedEnergy) ⚡")
                        .font(.spareMicro)
                        .foregroundColor(lead.earnedEnergy > 0 ? .emotionPositive : .emotionNegative)
                }
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private static func buildMockList(lane: EarnSocialLaneID) -> [LeadResultSnapshot] {
        let statuses: [LeadOutcomeStatus] = [.completed, .matched, .inProgress, .disputed, .cancelled]
        let names = ["李雪", "陈明", "王芳", "张伟", "刘洋"]
        let energies: [Int] = [80, -10, 0, 40, 15]
        let summary: String = "双方 Agent 对齐了\(lane.shortcut)核心条件，\(lane.savedSteps)。"
        return (0..<5).map { i -> LeadResultSnapshot in
            let matchedAt: Date = Date().addingTimeInterval(-Double(i + 1) * 3600)
            let completedAt: Date? = statuses[i] == .completed ? Date().addingTimeInterval(-Double(i) * 1800) : nil
            return LeadResultSnapshot(
                id: "lead-\(i)",
                lane: lane,
                counterpartName: names[i],
                counterpartAvatarSeed: i * 3,
                status: statuses[i],
                matchedAt: matchedAt,
                completedAt: completedAt,
                agentSummary: summary,
                agreedTerms: ["条款 A", "条款 B"],
                earnedEnergy: energies[i],
                auditTrail: []
            )
        }
    }
}
