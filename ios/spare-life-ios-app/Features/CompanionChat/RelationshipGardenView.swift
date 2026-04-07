// RelationshipGardenView.swift
// Spare Life – 熟人关系养成（双人任务、纪念卡、回忆线）
// Blueprint §消息 功能点 熟人关系养成 (line:1141)
// UIUX lane – slot 2

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Relationship Garden Store

@MainActor
final class RelationshipGardenStore: ObservableObject {
    @Published private(set) var profile: RelationshipProfile
    @Published private(set) var isLoading = true
    @Published var selectedTab: GardenTab = .tasks
    @Published var showAddAnniversary = false
    @Published var draftAnniversaryTitle = ""
    @Published var draftAnniversaryDate = Date()
    @Published var draftAnniversaryEmoji = "🎉"
    @Published var draftAnniversaryNote = ""

    enum GardenTab: String, CaseIterable, Identifiable {
        case tasks    = "tasks"
        case memories = "memories"
        case calendar = "calendar"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .tasks:    return "羁绊任务"
            case .memories: return "回忆线"
            case .calendar: return "纪念卡"
            }
        }

        var icon: String {
            switch self {
            case .tasks:    return "figure.2.arms.open"
            case .memories: return "clock.arrow.circlepath"
            case .calendar: return "calendar.badge.plus"
            }
        }
    }

    init(profile: RelationshipProfile) {
        self.profile = profile
    }

    func load() {
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            profile = Self.mockProfile(base: profile)
            isLoading = false
        }
    }

    func completeTask(id: String) {
        if let idx = profile.bondTasks.firstIndex(where: { $0.id == id }) {
            profile.bondTasks[idx].status = .done
        }
    }

    func toggleMemoryHighlight(id: String) {
        if let idx = profile.memoryThread.firstIndex(where: { $0.id == id }) {
            profile.memoryThread[idx].isHighlighted.toggle()
        }
    }

    func addAnniversary() {
        let card = AnniversaryCard(
            id: UUID().uuidString,
            title: draftAnniversaryTitle,
            date: draftAnniversaryDate,
            note: draftAnniversaryNote,
            emoji: draftAnniversaryEmoji
        )
        profile.anniversaries.append(card)
        profile.anniversaries.sort { $0.date < $1.date }
        showAddAnniversary = false
        draftAnniversaryTitle = ""
        draftAnniversaryNote = ""
    }

    private static func mockProfile(base: RelationshipProfile) -> RelationshipProfile {
        let now = Date()
        let tasks = [
            BondTask(id: "b1", title: "一起完成一件从未做过的事",
                     description: "两人共同体验一个全新的活动，比如陶艺、攀岩或桌游。",
                     status: .inProgress, rewardEnergy: 20, dueDate: now + 86400 * 7),
            BondTask(id: "b2", title: "分享三段只有对方知道的记忆",
                     description: "各自分享一段对对方特别的回忆，加深情感连接。",
                     status: .pending, rewardEnergy: 15, dueDate: now + 86400 * 14),
            BondTask(id: "b3", title: "一起完成一次 24 小时无手机挑战",
                     description: "放下手机，专注相处。",
                     status: .done, rewardEnergy: 30, dueDate: now - 86400 * 3),
        ]
        let anniversaries = [
            AnniversaryCard(id: "a1", title: "第一次见面", date: now - 86400 * 180,
                            note: "咖啡馆里的那个下午", emoji: "☕"),
            AnniversaryCard(id: "a2", title: "一起爬香山", date: now - 86400 * 90,
                            note: "天气很好，山顶拍了很多照片", emoji: "⛰️"),
            AnniversaryCard(id: "a3", title: "认识一周年", date: now + 86400 * 5,
                            note: "快到了！", emoji: "🎉"),
        ]
        let memories = [
            MemorySnippet(id: "m1", summary: "聊到了对时间感知的不同看法，对方有很独特的视角",
                          emotionTag: .positive, timestamp: now - 3600 * 2, isHighlighted: true),
            MemorySnippet(id: "m2", summary: "一起讨论了最近看的那本关于记忆的书",
                          emotionTag: .positive, timestamp: now - 86400, isHighlighted: false),
            MemorySnippet(id: "m3", summary: "发现了共同喜欢的导演：是枝裕和",
                          emotionTag: .positive, timestamp: now - 86400 * 3, isHighlighted: true),
            MemorySnippet(id: "m4", summary: "谈到了各自的工作压力，情绪有些低落",
                          emotionTag: .neutral, timestamp: now - 86400 * 5, isHighlighted: false),
        ]
        return RelationshipProfile(
            id: base.id,
            contactName: base.contactName,
            temperature: base.temperature,
            bondLevel: 68,
            bondTasks: tasks,
            anniversaries: anniversaries,
            memoryThread: memories
        )
    }
}

// MARK: - Relationship Garden View

struct RelationshipGardenView: View {
    let profile: RelationshipProfile
    let presentation: CompanionSurfacePresentationMode
    @StateObject private var store: RelationshipGardenStore
    @Environment(\.dismiss) private var dismiss

    init(
        profile: RelationshipProfile,
        presentation: CompanionSurfacePresentationMode = .modal
    ) {
        self.profile = profile
        self.presentation = presentation
        _store = StateObject(wrappedValue: RelationshipGardenStore(profile: profile))
    }

    var body: some View {
        Group {
            switch presentation {
            case .modal:
                NavigationStack { surfaceContent }
            case .embedded:
                surfaceContent
            }
        }
    }

    private var surfaceContent: some View {
        Group {
            if store.isLoading {
                loadingBody
            } else {
                mainBody
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("与 \(store.profile.contactName) 的关系")
        .spareNavigationBarTitleDisplayMode(.inline)
        .toolbar {
            if presentation == .modal {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.showAddAnniversary = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.spareYellow)
                }
            }
        }
        .task { store.load() }
        .sheet(isPresented: $store.showAddAnniversary) {
            addAnniversarySheet
                .presentationDragIndicator(.visible)
                .presentationDetents([.medium])
        }
    }

    // MARK: - Loading

    private var loadingBody: some View {
        VStack(spacing: Spacing.lg) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(Color.cardBackground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    .shimmer()
            }
        }
        .padding(Spacing.lg)
    }

    // MARK: - Main Body

    private var mainBody: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                relationshipHeaderCard
                tabPicker
                tabContent
            }
            .padding(Spacing.lg)
            .padding(.bottom, Spacing.xxxl)
        }
    }

    // MARK: - Header Card

    private var relationshipHeaderCard: some View {
        HStack(alignment: .center, spacing: Spacing.lg) {
            AvatarView(name: store.profile.contactName, size: 56)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(store.profile.contactName)
                    .font(.spareTitle3)

                // Temperature indicator
                Label(store.profile.temperature.label,
                      systemImage: store.profile.temperature.icon)
                    .font(.spareCaptionSB)
                    .foregroundColor(store.profile.temperature.color)

                // Bond level bar
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text("羁绊值")
                            .font(.spareMicro)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(store.profile.bondLevel) / 100")
                            .font(.spareMicro)
                            .foregroundColor(.secondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.15))
                                .frame(height: 6)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.spareYellow, .emotionPositive],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(store.profile.bondLevel) / 100,
                                       height: 6)
                        }
                    }
                    .frame(height: 6)
                }
                .frame(maxWidth: 160)
            }

            Spacer()
        }
        .padding(Spacing.lg)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .cardShadow()
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(RelationshipGardenStore.GardenTab.allCases) { tab in
                tabChip(tab)
            }
        }
    }

    private func tabChip(_ tab: RelationshipGardenStore.GardenTab) -> some View {
        let isSelected = store.selectedTab == tab
        return Button {
            withAnimation(.spareEase) { store.selectedTab = tab }
        } label: {
            Label(tab.label, systemImage: tab.icon)
                .font(.spareCaptionSB)
                .foregroundColor(isSelected ? .spareDark : .primary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color.spareYellow : Color.cardBackground,
                            in: RoundedRectangle(cornerRadius: CornerRadius.md))
                .cardShadow()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch store.selectedTab {
        case .tasks:    tasksContent
        case .memories: memoriesContent
        case .calendar: anniversariesContent
        }
    }

    // MARK: - Bond Tasks

    private var tasksContent: some View {
        VStack(spacing: Spacing.md) {
            if store.profile.bondTasks.isEmpty {
                EmptyStateView(
                    icon: "figure.2.arms.open",
                    title: "还没有羁绊任务",
                    message: "Agent 会根据你们的关系阶段自动推荐任务。"
                )
            } else {
                ForEach(store.profile.bondTasks) { task in
                    bondTaskCard(task)
                }
            }
        }
    }

    private func bondTaskCard(_ task: BondTask) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Button {
                if task.status != .done {
                    withAnimation(.spareEase) { store.completeTask(id: task.id) }
                }
            } label: {
                Image(systemName: task.status.icon)
                    .font(.system(size: 22))
                    .foregroundColor(task.status.color)
            }
            .buttonStyle(.plain)
            .disabled(task.status == .done || task.status == .expired)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(task.title)
                    .font(task.status == .done ? .spareBody : .spareBodySB)
                    .strikethrough(task.status == .done, color: .secondary)
                    .foregroundColor(task.status == .done ? .secondary : .primary)

                Text(task.description)
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: Spacing.sm) {
                    if let due = task.dueDate {
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "clock")
                                .font(.spareMicro)
                            Text(due, style: .relative)
                                .font(.spareMicro)
                        }
                        .foregroundColor(task.status == .done ? .secondary :
                                         (due < Date() ? .emotionNegative : .secondary))
                    }

                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "bolt.circle.fill")
                            .foregroundColor(.spareYellow)
                            .font(.spareMicro)
                        Text("+\(task.rewardEnergy)")
                            .font(.spareMicro)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .cardShadow()
    }

    // MARK: - Memory Thread

    private var memoriesContent: some View {
        VStack(spacing: Spacing.md) {
            if store.profile.memoryThread.isEmpty {
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: "暂无回忆",
                    message: "聊天中的重要片段会被 Agent 摘要后记录到这里。"
                )
            } else {
                ForEach(store.profile.memoryThread) { memory in
                    memorySnippetCard(memory)
                }
            }
        }
    }

    private func memorySnippetCard(_ memory: MemorySnippet) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            // Timeline dot
            VStack(spacing: 0) {
                Circle()
                    .fill(memory.emotionTag.color)
                    .frame(width: 10, height: 10)
                    .padding(.top, 4)
                Rectangle()
                    .fill(Color.cardStroke)
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
                    .padding(.vertical, 4)
            }
            .frame(width: 10)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    EmotionBadge(emotion: memory.emotionTag)
                    Spacer()
                    Text(memory.timestamp, style: .relative)
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                    Button {
                        withAnimation(.spareEase) {
                            store.toggleMemoryHighlight(id: memory.id)
                        }
                    } label: {
                        Image(systemName: memory.isHighlighted ? "star.fill" : "star")
                            .foregroundColor(memory.isHighlighted ? .spareYellow : .secondary)
                            .font(.system(size: 14))
                    }
                }

                Text(memory.summary)
                    .font(.spareBody)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(memory.isHighlighted ? .primary : .secondary)
            }
            .padding(Spacing.md)
            .background(
                memory.isHighlighted
                    ? Color.spareYellowLight.opacity(0.3)
                    : Color.cardBackground,
                in: RoundedRectangle(cornerRadius: CornerRadius.md)
            )
        }
    }

    // MARK: - Anniversaries

    private var anniversariesContent: some View {
        VStack(spacing: Spacing.md) {
            if store.profile.anniversaries.isEmpty {
                EmptyStateView(
                    icon: "calendar.badge.plus",
                    title: "还没有纪念日",
                    message: "记录下你们的重要时刻，在纪念日前 Agent 会提醒你。",
                    actionLabel: "添加纪念卡",
                    action: { store.showAddAnniversary = true }
                )
            } else {
                ForEach(store.profile.anniversaries) { card in
                    anniversaryCard(card)
                }
            }
        }
    }

    private func anniversaryCard(_ card: AnniversaryCard) -> some View {
        let isPast = card.date < Date()
        let isUpcoming = !isPast && card.date < Date() + 86400 * 7

        return HStack(spacing: Spacing.md) {
            Text(card.emoji)
                .font(.system(size: 32))
                .frame(width: 52, height: 52)
                .background(
                    (isUpcoming ? Color.spareYellow : Color.cardBackground)
                        .opacity(isUpcoming ? 0.2 : 1),
                    in: RoundedRectangle(cornerRadius: CornerRadius.md)
                )

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text(card.title)
                        .font(.spareBodySB)
                    if isUpcoming {
                        PillTag(label: "即将到来", color: .spareYellow, filled: true)
                    }
                }
                Text(card.date, style: .date)
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
                if !card.note.isEmpty {
                    Text(card.note)
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isPast {
                Text(card.date, style: .relative)
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(Spacing.md)
        .background(
            isUpcoming ? Color.spareYellowLight.opacity(0.15) : Color.cardBackground,
            in: RoundedRectangle(cornerRadius: CornerRadius.lg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(isUpcoming ? Color.spareYellow.opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .cardShadow()
    }

    // MARK: - Add Anniversary Sheet

    private var addAnniversarySheet: some View {
        NavigationStack {
            Form {
                Section("纪念日名称") {
                    TextField("第一次见面…", text: $store.draftAnniversaryTitle)
                }
                Section("日期") {
                    DatePicker("日期", selection: $store.draftAnniversaryDate,
                               displayedComponents: [.date])
                        .labelsHidden()
                }
                Section("Emoji") {
                    TextField("🎉", text: $store.draftAnniversaryEmoji)
                }
                Section("备注（可选）") {
                    TextField("添加一些备注…", text: $store.draftAnniversaryNote)
                }
            }
            .navigationTitle("添加纪念卡")
            .spareNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { store.showAddAnniversary = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { store.addAnniversary() }
                        .disabled(store.draftAnniversaryTitle.isEmpty)
                }
            }
        }
    }
}
