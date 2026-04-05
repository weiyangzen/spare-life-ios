// GroupAgentPlayView.swift
// Spare Life – 群聊 + Agent 玩法（做局、投票、总结）
// Blueprint §消息 功能点 群聊 + Agent 玩法 (line:1142)
// UIUX lane – slot 2

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Group Agent Play Models

enum GroupAgentRole: String, CaseIterable, Identifiable {
    case host
    case scribe
    case vibe
    case proposer

    var id: String { rawValue }

    var label: String {
        switch self {
        case .host: return "主持人"
        case .scribe: return "书记员"
        case .vibe: return "气氛组"
        case .proposer: return "提案器"
        }
    }

    var icon: String {
        switch self {
        case .host: return "person.wave.2.fill"
        case .scribe: return "list.bullet.rectangle.portrait.fill"
        case .vibe: return "sparkles"
        case .proposer: return "lightbulb.fill"
        }
    }

    var tint: Color {
        switch self {
        case .host: return .spareYellowInk
        case .scribe: return .spareYellowInk
        case .vibe: return .emotionPositive
        case .proposer: return .spareYellowInk
        }
    }

    var summaryHint: String {
        switch self {
        case .host:
            return "负责控节奏、拉齐规则并收口结论"
        case .scribe:
            return "负责提炼共识、自动整理纪要与行动项"
        case .vibe:
            return "负责暖场、降噪，避免讨论变成刷屏"
        case .proposer:
            return "负责发起议题、补全候选方案"
        }
    }
}

struct GroupPlayMessage: Identifiable, Hashable {
    let id: String
    let sender: String
    let role: GroupAgentRole?
    let content: String
    let timestamp: Date
    let isSuppressed: Bool
}

struct GroupVoteChoice: Identifiable, Hashable {
    let id: String
    let title: String
    var count: Int
    var selectedByMe: Bool
}

struct GroupVoteSession: Identifiable, Hashable {
    enum Status: String {
        case open
        case closed
    }

    let id: String
    let question: String
    var choices: [GroupVoteChoice]
    var status: Status
    let createdAt: Date
    let deadline: Date?
}

struct GroupSummaryRecord: Identifiable, Hashable {
    let id: String
    let headline: String
    let body: String
    let actionCount: Int
    let suppressedCount: Int
    let timestamp: Date
}

struct GroupActionItem: Identifiable, Hashable {
    let id: String
    let title: String
    let owner: String
    let dueAt: Date?
    var done: Bool
}

struct GroupPlaySnapshot: Hashable {
    let groupTitle: String
    let memberNames: [String]
    var residentAgentEnabled: Bool
    let noiseThreshold: Int
    var messages: [GroupPlayMessage]
    var votes: [GroupVoteSession]
    var summaries: [GroupSummaryRecord]
    var actionItems: [GroupActionItem]
}

enum GroupPlayLoadState: Equatable {
    case idle
    case loading
    case loaded
    case error(String)
}

// MARK: - Store

@MainActor
final class GroupAgentPlayStore: ObservableObject {
    let thread: ConversationThread

    @Published private(set) var loadState: GroupPlayLoadState = .idle
    @Published private(set) var snapshot: GroupPlaySnapshot?
    @Published var selectedAgentRole: GroupAgentRole = .host
    @Published var noiseControlEnabled = true

    @Published var showLaunchVoteSheet = false
    @Published var draftQuestion = ""
    @Published var draftOptionA = ""
    @Published var draftOptionB = ""
    @Published var draftOptionC = ""

    init(thread: ConversationThread) {
        self.thread = thread
    }

    var visibleMessages: [GroupPlayMessage] {
        guard let snapshot else { return [] }
        return snapshot.messages.filter { message in
            !noiseControlEnabled || !message.isSuppressed
        }
    }

    var suppressedCount: Int {
        guard let snapshot else { return 0 }
        return snapshot.messages.filter { $0.isSuppressed }.count
    }

    var isGroupThread: Bool {
        thread.kind == .group
    }

    func load() {
        guard case .idle = loadState else { return }
        loadState = .loading

        Task {
            try? await Task.sleep(nanoseconds: 550_000_000)
            guard isGroupThread else {
                self.loadState = .error("当前会话不是群聊，无法进入群聊玩法面板。")
                return
            }
            self.snapshot = Self.mockSnapshot(groupName: thread.contactName)
            self.loadState = .loaded
        }
    }

    func retry() {
        snapshot = nil
        loadState = .idle
        load()
    }

    func toggleResidentAgent(_ enabled: Bool) {
        guard var snapshot else { return }
        snapshot.residentAgentEnabled = enabled
        self.snapshot = snapshot
    }

    func castVote(voteID: String, choiceID: String) {
        guard var snapshot else { return }
        guard let voteIndex = snapshot.votes.firstIndex(where: { $0.id == voteID }) else { return }

        var vote = snapshot.votes[voteIndex]
        guard vote.status == .open else { return }

        for index in vote.choices.indices {
            if vote.choices[index].selectedByMe {
                vote.choices[index].selectedByMe = false
                vote.choices[index].count = max(0, vote.choices[index].count - 1)
            }
        }

        if let selectedIndex = vote.choices.firstIndex(where: { $0.id == choiceID }) {
            vote.choices[selectedIndex].selectedByMe = true
            vote.choices[selectedIndex].count += 1
        }

        snapshot.votes[voteIndex] = vote
        self.snapshot = snapshot
    }

    func launchVote() {
        guard var snapshot else { return }
        let question = draftQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        let options = [draftOptionA, draftOptionB, draftOptionC]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !question.isEmpty, options.count >= 2 else { return }

        let vote = GroupVoteSession(
            id: UUID().uuidString,
            question: question,
            choices: options.map {
                GroupVoteChoice(id: UUID().uuidString, title: $0, count: 0, selectedByMe: false)
            },
            status: .open,
            createdAt: Date(),
            deadline: Date() + 3600 * 8
        )
        snapshot.votes.insert(vote, at: 0)
        snapshot.messages.append(
            GroupPlayMessage(
                id: UUID().uuidString,
                sender: "群 Agent",
                role: .proposer,
                content: "发起新投票：\(question)",
                timestamp: Date(),
                isSuppressed: false
            )
        )
        self.snapshot = snapshot

        showLaunchVoteSheet = false
        draftQuestion = ""
        draftOptionA = ""
        draftOptionB = ""
        draftOptionC = ""
    }

    func generateSummary() {
        guard var snapshot else { return }
        let visible = visibleMessages
        guard !visible.isEmpty else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let headline = "\(selectedAgentRole.label)纪要 · \(formatter.string(from: Date()))"
        let summary = GroupSummaryRecord(
            id: UUID().uuidString,
            headline: headline,
            body: "共识已形成：先锁定今晚聚餐地点，再由书记员同步预算与到场确认。",
            actionCount: min(3, max(1, snapshot.actionItems.count)),
            suppressedCount: suppressedCount,
            timestamp: Date()
        )
        snapshot.summaries.insert(summary, at: 0)
        snapshot.messages.append(
            GroupPlayMessage(
                id: UUID().uuidString,
                sender: "群 Agent",
                role: .scribe,
                content: "我已完成本轮总结并提取行动项，点击纪要卡查看。",
                timestamp: Date(),
                isSuppressed: false
            )
        )
        self.snapshot = snapshot
    }

    func toggleActionDone(actionID: String) {
        guard var snapshot else { return }
        guard let index = snapshot.actionItems.firstIndex(where: { $0.id == actionID }) else { return }
        snapshot.actionItems[index].done.toggle()
        self.snapshot = snapshot
    }

    private static func mockSnapshot(groupName: String) -> GroupPlaySnapshot {
        let now = Date()
        return GroupPlaySnapshot(
            groupTitle: groupName,
            memberNames: ["我", "周游", "王芳", "工具 Agent"],
            residentAgentEnabled: true,
            noiseThreshold: 60,
            messages: [
                GroupPlayMessage(
                    id: "gm1",
                    sender: "周游",
                    role: nil,
                    content: "周末做个小局吧，先定地点还是先定人数？",
                    timestamp: now - 3600,
                    isSuppressed: false
                ),
                GroupPlayMessage(
                    id: "gm2",
                    sender: "工具 Agent",
                    role: .vibe,
                    content: "我建议先投票地点，再按地点反推人数上限。",
                    timestamp: now - 3400,
                    isSuppressed: false
                ),
                GroupPlayMessage(
                    id: "gm3",
                    sender: "王芳",
                    role: nil,
                    content: "哈哈哈哈哈哈哈哈哈哈哈哈哈",
                    timestamp: now - 3200,
                    isSuppressed: true
                ),
                GroupPlayMessage(
                    id: "gm4",
                    sender: "工具 Agent",
                    role: .scribe,
                    content: "当前分歧：预算 200 以内 or 300 以内，需要补一轮确认。",
                    timestamp: now - 2400,
                    isSuppressed: false
                )
            ],
            votes: [
                GroupVoteSession(
                    id: "gv1",
                    question: "周末聚餐地点选哪？",
                    choices: [
                        GroupVoteChoice(id: "gvc1", title: "鼓楼日料", count: 2, selectedByMe: true),
                        GroupVoteChoice(id: "gvc2", title: "朝阳烤肉", count: 1, selectedByMe: false),
                        GroupVoteChoice(id: "gvc3", title: "望京川菜", count: 0, selectedByMe: false)
                    ],
                    status: .open,
                    createdAt: now - 1800,
                    deadline: now + 3600 * 5
                )
            ],
            summaries: [
                GroupSummaryRecord(
                    id: "gs1",
                    headline: "主持纪要 · 预算先行",
                    body: "预算范围先锁在 200-260，再看地点与人数，避免反复横跳。",
                    actionCount: 2,
                    suppressedCount: 1,
                    timestamp: now - 1200
                )
            ],
            actionItems: [
                GroupActionItem(id: "ga1", title: "王芳补充可到场时间", owner: "王芳", dueAt: now + 3600 * 3, done: false),
                GroupActionItem(id: "ga2", title: "周游确认餐厅可预订人数", owner: "周游", dueAt: now + 3600 * 4, done: false),
                GroupActionItem(id: "ga3", title: "我在晚 9 点前确认最终地点", owner: "我", dueAt: now + 3600 * 6, done: true)
            ]
        )
    }
}

// MARK: - View

struct GroupAgentPlayView: View {
    let thread: ConversationThread
    @StateObject private var store: GroupAgentPlayStore
    @Environment(\.dismiss) private var dismiss

    init(thread: ConversationThread) {
        self.thread = thread
        _store = StateObject(wrappedValue: GroupAgentPlayStore(thread: thread))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                Group {
                    switch store.loadState {
                    case .idle, .loading:
                        loadingBody
                    case .loaded:
                        loadedBody
                    case .error(let message):
                        ErrorStateView(message: message, retry: store.retry)
                    }
                }
            }
            .navigationTitle("群聊玩法")
            .spareNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.showLaunchVoteSheet = true
                    } label: {
                        Image(systemName: "chart.bar.doc.horizontal.fill")
                            .foregroundColor(.spareYellow)
                    }
                    .disabled(!store.isGroupThread)
                }
            }
            .task { store.load() }
            .sheet(isPresented: $store.showLaunchVoteSheet) {
                launchVoteSheet
                    .presentationDragIndicator(.visible)
                    .presentationDetents([.medium])
            }
        }
    }

    private var loadingBody: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.md) {
                ForEach(0..<5, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .fill(Color.cardBackground)
                        .frame(height: 86)
                        .shimmer()
                }
            }
            .padding(Spacing.lg)
        }
    }

    private var loadedBody: some View {
        guard let snapshot = store.snapshot else {
            return AnyView(
                EmptyStateView(
                    icon: "person.3.fill",
                    title: "群玩法还没开启",
                    message: "开启常驻 Agent 后，你可以发起投票、总结和行动项追踪。"
                )
            )
        }

        return AnyView(
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    headerCard(snapshot)
                    roleSelectorCard
                    messageBoardCard(snapshot)
                    voteBoard(snapshot)
                    summaryBoard(snapshot)
                    actionBoard(snapshot)
                }
                .padding(Spacing.lg)
                .padding(.bottom, Spacing.xxxl)
            }
        )
    }

    private func headerCard(_ snapshot: GroupPlaySnapshot) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(snapshot.groupTitle)
                        .font(.spareTitle3)
                    Text("\(snapshot.memberNames.count) 人参与 · 群级 Agent 可控")
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                PillTag(label: snapshot.residentAgentEnabled ? "Agent 常驻中" : "Agent 已暂停",
                        color: snapshot.residentAgentEnabled ? .emotionPositive : .secondary)
            }

            Toggle(isOn: Binding(
                get: { snapshot.residentAgentEnabled },
                set: { store.toggleResidentAgent($0) }
            )) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("群级 Agent 常驻")
                        .font(.spareCaptionSB)
                    Text("由群主统一控制主持、纪要与提案能力")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }
            }
            .tint(.spareYellow)

            Toggle(isOn: $store.noiseControlEnabled) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("噪音控制")
                        .font(.spareCaptionSB)
                    Text("已识别 \(store.suppressedCount) 条低信号刷屏消息")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }
            }
            .tint(.emotionPositive)
        }
        .padding(Spacing.lg)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .cardShadow()
    }

    private var roleSelectorCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("工具型 Agent 角色")
                .font(.spareCaptionSB)
                .foregroundColor(.secondary)

            HStack(spacing: Spacing.sm) {
                ForEach(GroupAgentRole.allCases) { role in
                    roleChip(role)
                }
            }

            Text(store.selectedAgentRole.summaryHint)
                .font(.spareCaption)
                .foregroundColor(.secondary)
        }
        .padding(Spacing.lg)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .cardShadow()
    }

    private func roleChip(_ role: GroupAgentRole) -> some View {
        let selected = store.selectedAgentRole == role
        return Button {
            withAnimation(.spareEase) {
                store.selectedAgentRole = role
            }
        } label: {
            VStack(spacing: Spacing.xxs) {
                Image(systemName: role.icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(role.label)
                    .font(.spareMicro)
            }
            .foregroundColor(selected ? .white : role.tint)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity)
            .background(selected ? role.tint : role.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: CornerRadius.md))
        }
        .buttonStyle(.plain)
    }

    private func messageBoardCard(_ snapshot: GroupPlaySnapshot) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("群内讨论")
                    .font(.spareCaptionSB)
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    withAnimation(.spareEase) {
                        store.generateSummary()
                    }
                } label: {
                    Label("一键总结", systemImage: "text.append")
                        .font(.spareMicro)
                        .foregroundColor(.spareDark)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(Color.spareYellow, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            if store.visibleMessages.isEmpty {
                EmptyStateView(
                    icon: "speaker.slash",
                    title: "当前没有可展示消息",
                    message: "你已开启噪音控制，低信号刷屏消息已被自动收起。"
                )
            } else {
                ForEach(store.visibleMessages) { message in
                    groupMessageRow(message)
                }
            }
        }
        .padding(Spacing.lg)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .cardShadow()
    }

    private func groupMessageRow(_ message: GroupPlayMessage) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xs) {
                Text(message.sender)
                    .font(.spareCaptionSB)
                if let role = message.role {
                    PillTag(label: role.label, color: role.tint)
                }
                Spacer()
                Text(message.timestamp, style: .time)
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }
            Text(message.content)
                .font(.spareCaption)
                .foregroundColor(.primary)
        }
        .padding(Spacing.md)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
    }

    private func voteBoard(_ snapshot: GroupPlaySnapshot) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("群投票")
                    .font(.spareCaptionSB)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(snapshot.votes.count) 轮")
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }

            if snapshot.votes.isEmpty {
                EmptyStateView(
                    icon: "chart.bar.xaxis",
                    title: "还没有投票",
                    message: "点右上角发起第一轮投票，快速收敛分歧。"
                )
            } else {
                ForEach(snapshot.votes) { vote in
                    voteCard(vote)
                }
            }
        }
        .padding(Spacing.lg)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .cardShadow()
    }

    private func voteCard(_ vote: GroupVoteSession) -> some View {
        let total = max(1, vote.choices.reduce(0) { $0 + $1.count })

        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top) {
                Text(vote.question)
                    .font(.spareBodySB)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                PillTag(label: vote.status == .open ? "进行中" : "已结束",
                        color: vote.status == .open ? .emotionPositive : .secondary)
            }

            ForEach(vote.choices) { choice in
                Button {
                    withAnimation(.spareEase) {
                        store.castVote(voteID: vote.id, choiceID: choice.id)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        HStack {
                            Text(choice.title)
                                .font(.spareCaption)
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(choice.count) 票")
                                .font(.spareMicro)
                                .foregroundColor(choice.selectedByMe ? .spareDark : .secondary)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.secondary.opacity(0.14))
                                Capsule()
                                    .fill(choice.selectedByMe ? Color.spareYellow : Color.spareYellowInk.opacity(0.45))
                                    .frame(width: geo.size.width * CGFloat(choice.count) / CGFloat(total))
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(Spacing.sm)
                    .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
                }
                .buttonStyle(.plain)
                .disabled(vote.status == .closed)
            }

            if let deadline = vote.deadline {
                Text("截止 \(deadline, style: .relative)")
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }
        }
        .padding(Spacing.md)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
    }

    private func summaryBoard(_ snapshot: GroupPlaySnapshot) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("自动纪要")
                .font(.spareCaptionSB)
                .foregroundColor(.secondary)

            if snapshot.summaries.isEmpty {
                EmptyStateView(
                    icon: "text.quote",
                    title: "还没有纪要",
                    message: "点击一键总结后，Agent 会输出压缩纪要和行动项。"
                )
            } else {
                ForEach(snapshot.summaries) { summary in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack {
                            Text(summary.headline)
                                .font(.spareBodySB)
                            Spacer()
                            Text(summary.timestamp, style: .time)
                                .font(.spareMicro)
                                .foregroundColor(.secondary)
                        }
                        Text(summary.body)
                            .font(.spareCaption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: Spacing.sm) {
                            PillTag(label: "行动项 \(summary.actionCount)", color: .emotionPositive)
                            PillTag(label: "降噪 \(summary.suppressedCount)", color: .emotionSplit)
                        }
                    }
                    .padding(Spacing.md)
                    .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
                }
            }
        }
        .padding(Spacing.lg)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .cardShadow()
    }

    private func actionBoard(_ snapshot: GroupPlaySnapshot) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("行动项")
                .font(.spareCaptionSB)
                .foregroundColor(.secondary)

            if snapshot.actionItems.isEmpty {
                EmptyStateView(
                    icon: "checklist",
                    title: "暂无行动项",
                    message: "Agent 总结后会自动提取可执行任务。"
                )
            } else {
                ForEach(snapshot.actionItems) { item in
                    Button {
                        withAnimation(.spareEase) {
                            store.toggleActionDone(actionID: item.id)
                        }
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(item.done ? .emotionPositive : .secondary)

                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(item.title)
                                    .font(.spareCaptionSB)
                                    .foregroundColor(item.done ? .secondary : .primary)
                                    .strikethrough(item.done, color: .secondary)
                                HStack(spacing: Spacing.xs) {
                                    Text("负责人：\(item.owner)")
                                        .font(.spareMicro)
                                    if let due = item.dueAt {
                                        Text("·")
                                            .font(.spareMicro)
                                        Text(due, style: .relative)
                                            .font(.spareMicro)
                                    }
                                }
                                .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                        .padding(Spacing.md)
                        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(Spacing.lg)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .cardShadow()
    }

    private var launchVoteSheet: some View {
        NavigationStack {
            Form {
                Section("投票问题") {
                    TextField("例如：周末聚餐地点选哪？", text: $store.draftQuestion)
                }

                Section("选项") {
                    TextField("选项 A", text: $store.draftOptionA)
                    TextField("选项 B", text: $store.draftOptionB)
                    TextField("选项 C（可选）", text: $store.draftOptionC)
                }
            }
            .navigationTitle("发起投票")
            .spareNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { store.showLaunchVoteSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("发布") { store.launchVote() }
                        .disabled(
                            store.draftQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            store.draftOptionA.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            store.draftOptionB.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                }
            }
        }
    }
}
