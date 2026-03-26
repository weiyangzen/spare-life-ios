// CrossSessionMemoryView.swift
// Spare Life – 情感连续性与跨会话记忆
// Blueprint §消息 功能点 情感连续性与跨会话记忆 (line:1143)
// UIUX lane – slot 2

import SwiftUI

// MARK: - Models

enum MemoryLayer: String, CaseIterable, Identifiable {
    case session = "session"
    case summary = "summary"
    case longTerm = "long_term"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .session: return "会话片段"
        case .summary: return "摘要层"
        case .longTerm: return "长期记忆"
        }
    }

    var icon: String {
        switch self {
        case .session: return "message"
        case .summary: return "text.quote"
        case .longTerm: return "archivebox.fill"
        }
    }
}

struct EmotionSnapshotPoint: Identifiable, Hashable {
    let id: String
    let timestamp: Date
    let temperature: RelationTemperature
    let emotion: EmotionBadge.Emotion
    let note: String
}

struct LayeredMemoryEntry: Identifiable, Hashable {
    let id: String
    let layer: MemoryLayer
    let title: String
    var body: String
    let emotion: EmotionBadge.Emotion
    let updatedAt: Date
    var pendingFollowup: Bool
    var corrected: Bool
}

struct ConversationDigest: Identifiable, Hashable {
    let id: String
    let title: String
    let content: String
    let timestamp: Date
}

struct CrossSessionSnapshot: Hashable {
    let contactName: String
    let relationshipTemperature: RelationTemperature
    let lastConversationAt: Date
    let continuityHint: String
    let snapshots: [EmotionSnapshotPoint]
    var digests: [ConversationDigest]
    var memories: [LayeredMemoryEntry]
}

enum CrossSessionLoadState: Equatable {
    case idle
    case loading
    case loaded
    case error(String)
}

// MARK: - Store

@MainActor
final class CrossSessionMemoryStore: ObservableObject {
    let thread: ConversationThread

    @Published private(set) var loadState: CrossSessionLoadState = .idle
    @Published private(set) var snapshot: CrossSessionSnapshot?

    @Published var selectedLayer: MemoryLayer = .summary
    @Published var searchQuery = ""
    @Published var onlyPendingFollowup = false
    @Published var selectedSnapshotID: String?

    @Published var showCorrectionSheet = false
    @Published var correctionDraft = ""
    @Published private(set) var correctionTargetID: String?

    init(thread: ConversationThread) {
        self.thread = thread
    }

    var filteredMemories: [LayeredMemoryEntry] {
        guard let snapshot else { return [] }

        return snapshot.memories.filter { item in
            if item.layer != selectedLayer {
                return false
            }

            if onlyPendingFollowup && !item.pendingFollowup {
                return false
            }

            if searchQuery.isEmpty {
                return true
            }

            let query = searchQuery.lowercased()
            return item.title.lowercased().contains(query) || item.body.lowercased().contains(query)
        }
    }

    var selectedSnapshot: EmotionSnapshotPoint? {
        guard let snapshot else { return nil }
        let currentID = selectedSnapshotID ?? snapshot.snapshots.first?.id
        return snapshot.snapshots.first(where: { $0.id == currentID })
    }

    func load() {
        guard case .idle = loadState else { return }
        loadState = .loading

        Task {
            try? await Task.sleep(nanoseconds: 520_000_000)
            self.snapshot = Self.mockSnapshot(thread: thread)
            self.selectedSnapshotID = self.snapshot?.snapshots.first?.id
            self.loadState = .loaded
        }
    }

    func retry() {
        snapshot = nil
        selectedSnapshotID = nil
        loadState = .idle
        load()
    }

    func markFollowupDone(memoryID: String) {
        guard var snapshot else { return }
        guard let index = snapshot.memories.firstIndex(where: { $0.id == memoryID }) else { return }

        snapshot.memories[index].pendingFollowup = false
        self.snapshot = snapshot
    }

    func beginCorrection(memoryID: String) {
        guard let snapshot,
              let entry = snapshot.memories.first(where: { $0.id == memoryID }) else { return }

        correctionTargetID = memoryID
        correctionDraft = entry.body
        showCorrectionSheet = true
    }

    func submitCorrection() {
        let trimmed = correctionDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let targetID = correctionTargetID,
              var snapshot,
              let index = snapshot.memories.firstIndex(where: { $0.id == targetID }) else { return }

        snapshot.memories[index].body = trimmed
        snapshot.memories[index].corrected = true
        self.snapshot = snapshot

        correctionTargetID = nil
        correctionDraft = ""
        showCorrectionSheet = false
    }

    private static func mockSnapshot(thread: ConversationThread) -> CrossSessionSnapshot {
        let now = Date()

        return CrossSessionSnapshot(
            contactName: thread.contactName,
            relationshipTemperature: thread.relationTemperature,
            lastConversationAt: now - 1700,
            continuityHint: "上次你们停在“周末线下见面预算”这个话题，对方情绪偏中性，建议先确认时间窗口再推进地点。",
            snapshots: [
                EmotionSnapshotPoint(
                    id: "es1",
                    timestamp: now - 86400 * 5,
                    temperature: .warming,
                    emotion: .neutral,
                    note: "讨论工作压力，语气克制"
                ),
                EmotionSnapshotPoint(
                    id: "es2",
                    timestamp: now - 86400 * 3,
                    temperature: .warm,
                    emotion: .positive,
                    note: "共同话题增多，互动频率上升"
                ),
                EmotionSnapshotPoint(
                    id: "es3",
                    timestamp: now - 86400,
                    temperature: thread.relationTemperature,
                    emotion: .split,
                    note: "出现预算分歧，需要收敛方案"
                )
            ],
            digests: [
                ConversationDigest(
                    id: "dg1",
                    title: "最近一次会话摘要",
                    content: "双方认可周末见面，但地点和预算未达成一致；Agent 已建议先定预算上限。",
                    timestamp: now - 2400
                ),
                ConversationDigest(
                    id: "dg2",
                    title: "七日关系摘要",
                    content: "关系温度从“升温”提升到“熟悉”，互动由浅层寒暄转向可执行计划。",
                    timestamp: now - 86400
                )
            ],
            memories: [
                LayeredMemoryEntry(
                    id: "me1",
                    layer: .session,
                    title: "上次结尾问题",
                    body: "是否能接受人均 220 左右预算？",
                    emotion: .neutral,
                    updatedAt: now - 1600,
                    pendingFollowup: true,
                    corrected: false
                ),
                LayeredMemoryEntry(
                    id: "me2",
                    layer: .summary,
                    title: "偏好摘要",
                    body: "对方更倾向安静餐厅，且希望 2 小时内结束。",
                    emotion: .positive,
                    updatedAt: now - 6000,
                    pendingFollowup: false,
                    corrected: false
                ),
                LayeredMemoryEntry(
                    id: "me3",
                    layer: .summary,
                    title: "风险提示",
                    body: "若直接推进地点，可能再次触发预算争论。",
                    emotion: .split,
                    updatedAt: now - 5400,
                    pendingFollowup: true,
                    corrected: false
                ),
                LayeredMemoryEntry(
                    id: "me4",
                    layer: .longTerm,
                    title: "长期偏好",
                    body: "更看重“提前确认计划”而不是临时决定。",
                    emotion: .positive,
                    updatedAt: now - 86400 * 7,
                    pendingFollowup: false,
                    corrected: true
                )
            ]
        )
    }
}

// MARK: - View

struct CrossSessionMemoryView: View {
    let thread: ConversationThread
    @StateObject private var store: CrossSessionMemoryStore
    @Environment(\.dismiss) private var dismiss

    init(thread: ConversationThread) {
        self.thread = thread
        _store = StateObject(wrappedValue: CrossSessionMemoryStore(thread: thread))
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
            .navigationTitle("跨会话记忆")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task { store.load() }
            .sheet(isPresented: $store.showCorrectionSheet) {
                correctionSheet
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
                        .frame(height: 92)
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
                    icon: "brain",
                    title: "还没有可召回记忆",
                    message: "进入会话后，系统会自动生成情绪快照和关系摘要。"
                )
            )
        }

        return AnyView(
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    continuityHeader(snapshot)
                    emotionTimeline(snapshot)
                    digestSection(snapshot)
                    memoryFilterCard
                    memoryList(snapshot)
                }
                .padding(Spacing.lg)
                .padding(.bottom, Spacing.xxxl)
            }
        )
    }

    private func continuityHeader(_ snapshot: CrossSessionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(snapshot.contactName)
                        .font(.spareTitle3)
                    Label(snapshot.relationshipTemperature.label,
                          systemImage: snapshot.relationshipTemperature.icon)
                        .font(.spareCaptionSB)
                        .foregroundColor(snapshot.relationshipTemperature.color)
                }
                Spacer()
                Text(snapshot.lastConversationAt, style: .relative)
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }

            Text(snapshot.continuityHint)
                .font(.spareCaption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.lg)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .cardShadow()
    }

    private func emotionTimeline(_ snapshot: CrossSessionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("情绪快照")
                .font(.spareCaptionSB)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(snapshot.snapshots) { point in
                        emotionPointCard(point)
                    }
                }
            }

            if let selected = store.selectedSnapshot {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    EmotionBadge(emotion: selected.emotion)
                    Text(selected.note)
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
            }
        }
        .padding(Spacing.lg)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .cardShadow()
    }

    private func emotionPointCard(_ point: EmotionSnapshotPoint) -> some View {
        let selected = store.selectedSnapshotID == point.id

        return Button {
            withAnimation(.spareEase) {
                store.selectedSnapshotID = point.id
            }
        } label: {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Label(point.temperature.label, systemImage: point.temperature.icon)
                    .font(.spareMicro)
                    .foregroundColor(selected ? .spareDark : point.temperature.color)
                Text(point.timestamp, style: .date)
                    .font(.spareMicro)
                    .foregroundColor(selected ? .spareDark.opacity(0.8) : .secondary)
            }
            .padding(Spacing.sm)
            .background(
                selected ? Color.spareYellow : point.temperature.color.opacity(0.12),
                in: RoundedRectangle(cornerRadius: CornerRadius.md)
            )
            .frame(width: 126, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private func digestSection(_ snapshot: CrossSessionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("摘要分层")
                .font(.spareCaptionSB)
                .foregroundColor(.secondary)

            if snapshot.digests.isEmpty {
                EmptyStateView(
                    icon: "text.quote",
                    title: "暂无摘要",
                    message: "本轮会话结束后会自动生成可回看摘要。"
                )
            } else {
                ForEach(snapshot.digests) { digest in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack {
                            Text(digest.title)
                                .font(.spareBodySB)
                            Spacer()
                            Text(digest.timestamp, style: .relative)
                                .font(.spareMicro)
                                .foregroundColor(.secondary)
                        }
                        Text(digest.content)
                            .font(.spareCaption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
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

    private var memoryFilterCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("记忆召回")
                .font(.spareCaptionSB)
                .foregroundColor(.secondary)

            TextField("搜索记忆关键词", text: $store.searchQuery)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .font(.spareCaption)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))

            Toggle("只看待接续", isOn: $store.onlyPendingFollowup)
                .font(.spareCaption)
                .tint(.spareYellow)

            HStack(spacing: Spacing.sm) {
                ForEach(MemoryLayer.allCases) { layer in
                    layerChip(layer)
                }
            }
        }
        .padding(Spacing.lg)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .cardShadow()
    }

    private func layerChip(_ layer: MemoryLayer) -> some View {
        let selected = store.selectedLayer == layer

        return Button {
            withAnimation(.spareEase) {
                store.selectedLayer = layer
            }
        } label: {
            Label(layer.label, systemImage: layer.icon)
                .font(.spareMicro)
                .foregroundColor(selected ? .spareDark : .primary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(selected ? Color.spareYellow : Color(.systemGroupedBackground), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func memoryList(_ snapshot: CrossSessionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("\(store.selectedLayer.label) · \(store.filteredMemories.count) 条")
                    .font(.spareCaptionSB)
                    .foregroundColor(.secondary)
                Spacer()
            }

            if snapshot.memories.isEmpty {
                EmptyStateView(
                    icon: "tray",
                    title: "还没有记忆数据",
                    message: "会话沉淀后会在这里展示可召回内容。"
                )
            } else if store.filteredMemories.isEmpty {
                EmptyStateView(
                    icon: "line.3.horizontal.decrease.circle",
                    title: "没有匹配结果",
                    message: "调整筛选条件，或关闭“只看待接续”。"
                )
            } else {
                ForEach(store.filteredMemories) { memory in
                    memoryCard(memory)
                }
            }
        }
        .padding(Spacing.lg)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .cardShadow()
    }

    private func memoryCard(_ memory: LayeredMemoryEntry) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(memory.title)
                    .font(.spareBodySB)
                Spacer()
                Text(memory.updatedAt, style: .relative)
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }

            Text(memory.body)
                .font(.spareCaption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Spacing.sm) {
                EmotionBadge(emotion: memory.emotion)

                if memory.pendingFollowup {
                    PillTag(label: "待接续", color: .emotionSplit)
                }

                if memory.corrected {
                    PillTag(label: "已纠正", color: .emotionPositive)
                }

                Spacer()
            }

            HStack(spacing: Spacing.sm) {
                if memory.pendingFollowup {
                    Button {
                        withAnimation(.spareEase) {
                            store.markFollowupDone(memoryID: memory.id)
                        }
                    } label: {
                        Label("标记已接续", systemImage: "checkmark.circle")
                            .font(.spareMicro)
                            .foregroundColor(.emotionPositive)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    store.beginCorrection(memoryID: memory.id)
                } label: {
                    Label("纠正记忆", systemImage: "pencil.line")
                        .font(.spareMicro)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.md)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
    }

    private var correctionSheet: some View {
        NavigationStack {
            Form {
                Section("纠正后的记忆内容") {
                    TextEditor(text: $store.correctionDraft)
                        .font(.spareCaption)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("纠正记忆")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        store.showCorrectionSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.submitCorrection()
                    }
                    .disabled(store.correctionDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
