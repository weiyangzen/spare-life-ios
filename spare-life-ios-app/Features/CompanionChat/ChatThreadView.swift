// ChatThreadView.swift
// Spare Life – 熟人聊天主线程 + Agent 辅助线程
// Blueprint §消息 功能点 熟人聊天主线程 (line:1138)
// Blueprint §统一UI 消息详情卡片化 (line:1153) [UIUX]
// UIUX lane – slot 2

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum ChatSendMode: String, CaseIterable, Identifiable {
    case human = "真人模式"
    case aiAuto = "AI 全自动"

    var id: String { rawValue }

    var senderRole: ChatSenderRole {
        switch self {
        case .human: return .myHuman
        case .aiAuto: return .myPersona
        }
    }

    var icon: String {
        switch self {
        case .human: return "person.fill"
        case .aiAuto: return "sparkles"
        }
    }

    func placeholder(for contactName: String) -> String {
        switch self {
        case .human:
            return "发消息给 \(contactName)…"
        case .aiAuto:
            return "让分身代你回复 \(contactName)…"
        }
    }
}

// MARK: - Chat Thread Store

@MainActor
final class ChatThreadStore: ObservableObject {
    let thread: ConversationThread

    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var agentMessages: [ChatMessage] = []  // Agent 辅助线程
    @Published private(set) var isLoading = true
    @Published var showAgentPanel = false
    @Published var draftText: String = ""
    @Published var sendMode: ChatSendMode = .human
    @Published var showContactMask = false
    @Published var showRelationship = false
    @Published var showQuadRole = false
    @Published var showGroupPlay = false
    @Published var showCrossSessionMemory = false

    init(thread: ConversationThread) {
        self.thread = thread
    }

    func load() {
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            self.messages = Self.mockMessages(thread: thread)
            self.agentMessages = Self.mockAgentMessages(thread: thread)
            self.isLoading = false
        }
    }

    func send() {
        guard !draftText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let senderRole = sendMode.senderRole
        let msg = ChatMessage(
            id: UUID().uuidString,
            senderRole: senderRole,
            senderName: senderRole.displayName,
            content: draftText,
            timestamp: Date(),
            isAgentThread: false
        )
        withAnimation(.spareEase) {
            messages.append(msg)
        }
        draftText = ""
    }

    // MARK: Mock

    private static func mockMessages(thread: ConversationThread) -> [ChatMessage] {
        let now = Date()

        switch thread.id {
        case "t1":
            return [
                ChatMessage(id: "m1", senderRole: .theirHuman, senderName: "Dubi",
                            content: "我刚出门，十分钟内能到那家咖啡馆。", timestamp: now - 3600,
                            isAgentThread: false),
                ChatMessage(id: "m2", senderRole: .myHuman, senderName: "我",
                            content: "好，我也在路上，今天还是坐窗边吧。", timestamp: now - 3300,
                            isAgentThread: false),
                ChatMessage(id: "m3", senderRole: .theirHuman, senderName: "Dubi",
                            content: "可以，我记得你上次说下午那边的光线最好。", timestamp: now - 3000,
                            isAgentThread: false),
                ChatMessage(id: "m4", senderRole: .myHuman, senderName: "我",
                            content: "对，顺便帮我点一杯热美式。", timestamp: now - 1200,
                            isAgentThread: false),
                ChatMessage(id: "m5", senderRole: .theirHuman, senderName: "Dubi",
                            content: "没问题，我到了就先帮你点。", timestamp: now - 720,
                            isAgentThread: false),
                ChatMessage(id: "m6", senderRole: .theirHuman, senderName: "Dubi",
                            content: "那我先去占窗边的位置。", timestamp: now - 300,
                            isAgentThread: false),
            ]

        case "t2":
            return [
                ChatMessage(id: "m1", senderRole: .theirHuman, senderName: "Sophie",
                            content: "今晚那个展我看了一下，7 点以后人会少一点。", timestamp: now - 5400,
                            isAgentThread: false),
                ChatMessage(id: "m2", senderRole: .myHuman, senderName: "我",
                            content: "那正好，我 6 点半下班，过去差不多。", timestamp: now - 5000,
                            isAgentThread: false),
                ChatMessage(id: "m3", senderRole: .myPersona, senderName: "我的分身",
                            content: "按照你们之前的偏好，先看摄影单元再看装置单元会更顺。", timestamp: now - 4600,
                            isAgentThread: false),
                ChatMessage(id: "m4", senderRole: .theirHuman, senderName: "Sophie",
                            content: "好，那我就不自己乱绕了。", timestamp: now - 4300,
                            isAgentThread: false),
                ChatMessage(id: "m5", senderRole: .myHuman, senderName: "我",
                            content: "我本来想自己做路线，你要是已经顺手了也行。", timestamp: now - 2200,
                            isAgentThread: false),
                ChatMessage(id: "m6", senderRole: .theirHuman, senderName: "Sophie",
                            content: "我让分身先把今晚的路线发你。", timestamp: now - 1800,
                            isAgentThread: false),
            ]

        case "t3":
            return [
                ChatMessage(id: "m1", senderRole: .theirHuman, senderName: "Omar",
                            content: "周五那场桌游局还继续吗？我这边可以早点去。", timestamp: now - 7200,
                            isAgentThread: false),
                ChatMessage(id: "m2", senderRole: .myHuman, senderName: "我",
                            content: "继续，我负责把清单再过一遍。", timestamp: now - 6800,
                            isAgentThread: false),
                ChatMessage(id: "m3", senderRole: .theirHuman, senderName: "Aris",
                            content: "投影和音箱我都能带。", timestamp: now - 6300,
                            isAgentThread: false),
                ChatMessage(id: "m4", senderRole: .theirHuman, senderName: "Omar",
                            content: "那我去问问老地方明晚还能不能留给我们。", timestamp: now - 4200,
                            isAgentThread: false),
                ChatMessage(id: "m5", senderRole: .myHuman, senderName: "我",
                            content: "如果能留就还是老地方，省得大家重新找。", timestamp: now - 3900,
                            isAgentThread: false),
                ChatMessage(id: "m6", senderRole: .theirHuman, senderName: "Aris",
                            content: "明晚先把场地定下来？", timestamp: now - 3600,
                            isAgentThread: false),
            ]

        case "t4":
            return [
                ChatMessage(id: "m1", senderRole: .myHuman, senderName: "我",
                            content: "昨晚提到的那几本书，你要不要我帮你整理成一个顺序？", timestamp: now - 9600,
                            isAgentThread: false),
                ChatMessage(id: "m2", senderRole: .theirHuman, senderName: "Mia",
                            content: "要，我怕自己回头就记混了。", timestamp: now - 9300,
                            isAgentThread: false),
                ChatMessage(id: "m3", senderRole: .myHuman, senderName: "我",
                            content: "我先列了三本最适合入门的，晚上发你。", timestamp: now - 9000,
                            isAgentThread: false),
                ChatMessage(id: "m4", senderRole: .theirHuman, senderName: "Mia",
                            content: "好，我开个共享文档，你直接往里补。", timestamp: now - 8700,
                            isAgentThread: false),
                ChatMessage(id: "m5", senderRole: .myHuman, senderName: "我",
                            content: "你补完告诉我，下周我们就按那个顺序聊。", timestamp: now - 7600,
                            isAgentThread: false),
                ChatMessage(id: "m6", senderRole: .theirHuman, senderName: "Mia",
                            content: "我把那份书单补在共享文档里了。", timestamp: now - 7200,
                            isAgentThread: false),
            ]

        case "t5":
            return [
                ChatMessage(id: "m1", senderRole: .myHuman, senderName: "我",
                            content: "Hannah，我今天事情有点乱，帮我顺一下优先级。", timestamp: now - 87200,
                            isAgentThread: false),
                ChatMessage(id: "m2", senderRole: .theirPersona, senderName: "Hannah",
                            content: "可以，你先告诉我哪些事今天必须完成。", timestamp: now - 87000,
                            isAgentThread: false),
                ChatMessage(id: "m3", senderRole: .myHuman, senderName: "我",
                            content: "产品稿、给 Dubi 回消息、还有明早的周会准备。", timestamp: now - 86800,
                            isAgentThread: false),
                ChatMessage(id: "m4", senderRole: .theirPersona, senderName: "Hannah",
                            content: "收到，我先按截止时间和切换成本帮你拆开。", timestamp: now - 86600,
                            isAgentThread: false),
                ChatMessage(id: "m5", senderRole: .myHuman, senderName: "我",
                            content: "顺便帮我留一段晚上复盘时间。", timestamp: now - 86500,
                            isAgentThread: false),
                ChatMessage(id: "m6", senderRole: .theirPersona, senderName: "Hannah",
                            content: "我已经把你的待办拆成 3 个优先级。", timestamp: now - 86400,
                            isAgentThread: false),
            ]

        default:
            return [
                ChatMessage(id: "m1", senderRole: .theirHuman, senderName: thread.contactName,
                            content: thread.lastMessage, timestamp: now - 300,
                            isAgentThread: false)
            ]
        }
    }

    private static func mockAgentMessages(thread: ConversationThread) -> [ChatMessage] {
        let now = Date()

        switch thread.id {
        case "t1":
            return [
                ChatMessage(id: "a1", senderRole: .myPersona, senderName: "你的分身",
                            content: "Dubi 已经先到店里，当前话题适合延续轻松见面节奏。",
                            timestamp: now - 260, isAgentThread: true),
                ChatMessage(id: "a2", senderRole: .agentHelper, senderName: "Agent 助手",
                            content: "建议你到场后先接 Dubi 的“窗边位置”话题，再自然转去今天的安排。",
                            timestamp: now - 220, isAgentThread: true),
            ]

        case "t2":
            return [
                ChatMessage(id: "a1", senderRole: .myPersona, senderName: "你的分身",
                            content: "我已根据你和 Sophie 的路线偏好整理出一条 90 分钟观展顺序。",
                            timestamp: now - 1200, isAgentThread: true),
                ChatMessage(id: "a2", senderRole: .agentHelper, senderName: "Agent 助手",
                            content: "当前更适合把路线作为附件发出，不必在主线程里解释太多细节。",
                            timestamp: now - 900, isAgentThread: true),
            ]

        case "t3":
            return [
                ChatMessage(id: "a1", senderRole: .agentHelper, senderName: "Agent 助手",
                            content: "群里当前共识是先定场地，再确认设备和到场时间。",
                            timestamp: now - 3000, isAgentThread: true),
                ChatMessage(id: "a2", senderRole: .agentHelper, senderName: "Agent 助手",
                            content: "如果你要回，可以直接确认“老地方可行就锁定”。",
                            timestamp: now - 2500, isAgentThread: true),
            ]

        case "t4":
            return [
                ChatMessage(id: "a1", senderRole: .myPersona, senderName: "你的分身",
                            content: "Mia 刚补完书单，下一轮对话可以直接切到第一本书的讨论。",
                            timestamp: now - 6800, isAgentThread: true),
                ChatMessage(id: "a2", senderRole: .agentHelper, senderName: "Agent 助手",
                            content: "建议开场问题：为什么她把第一本放在最前面。",
                            timestamp: now - 6500, isAgentThread: true),
            ]

        case "t5":
            return [
                ChatMessage(id: "a1", senderRole: .theirPersona, senderName: "Hannah",
                            content: "高优先级：产品稿；中优先级：周会准备；低优先级：整理回复消息。",
                            timestamp: now - 5400, isAgentThread: true),
                ChatMessage(id: "a2", senderRole: .agentHelper, senderName: "Agent 助手",
                            content: "今晚 21:30 之后预留 20 分钟复盘，会比现在插入更稳。",
                            timestamp: now - 5000, isAgentThread: true),
            ]

        default:
            return []
        }
    }
}

// MARK: - Chat Thread View

struct ChatThreadView: View {
    let thread: ConversationThread
    @StateObject private var store: ChatThreadStore
    @State private var contextCardsExpanded = false

    init(thread: ConversationThread) {
        self.thread = thread
        _store = StateObject(wrappedValue: ChatThreadStore(thread: thread))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            backgroundLayer

            VStack(spacing: 0) {
                // Context cards section: relationship / mask / memory cards + timeline entry
                contextSection

                Divider()

                // Message list
                if store.isLoading {
                    loadingBody
                } else if store.messages.isEmpty {
                    emptyBody
                } else {
                    messageList
                }

                // Input bar
                inputBar
            }

            // Agent aux panel overlay
            if store.showAgentPanel {
                agentPanelOverlay
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle(thread.contactName)
        .spareNavigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .task { store.load() }
        .sheet(isPresented: $store.showContactMask) {
            ContactMaskView(contactID: thread.id, contactName: thread.contactName)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $store.showRelationship) {
            RelationshipGardenView(
                profile: RelationshipProfile(
                    id: thread.id, contactName: thread.contactName,
                    temperature: thread.relationTemperature,
                    bondLevel: 68, bondTasks: [], anniversaries: [], memoryThread: []
                )
            )
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $store.showQuadRole) {
            QuadRoleChatView(thread: thread)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $store.showCrossSessionMemory) {
            CrossSessionMemoryView(thread: thread)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $store.showGroupPlay) {
            GroupAgentPlayView(thread: thread)
                .presentationDragIndicator(.visible)
        }
    }

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [
                Color.spareYellow.opacity(0.10),
                Color.white,
                Color.white
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button { store.showContactMask = true } label: {
                    Label("面具设置", systemImage: "theatermasks.fill")
                }
                Button { store.showRelationship = true } label: {
                    Label("关系养成", systemImage: "heart.circle.fill")
                }
                Button { store.showCrossSessionMemory = true } label: {
                    Label("跨会话记忆", systemImage: "brain")
                }
                if thread.kind == .group {
                    Button { store.showGroupPlay = true } label: {
                        Label("群聊玩法", systemImage: "person.3.fill")
                    }
                }
                Button { store.showQuadRole = true } label: {
                    Label("开启四人场", systemImage: "person.3.fill")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Context Section (卡片化: 关系卡 + 面具卡 + 记忆卡)

    private var contextSection: some View {
        VStack(spacing: 0) {
            // Compact header strip: temperature + mask + quick actions
            compactContextBar

            // Expanded card deck (shown when contextCardsExpanded = true)
            if contextCardsExpanded {
                contextCardDeck
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(Color.white)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.spareYellow.opacity(0.14))
                .frame(height: 1)
        }
        .animation(.spareSpring, value: contextCardsExpanded)
    }

    /// Single-line compact bar with summary chips and expand toggle.
    private var compactContextBar: some View {
        HStack(spacing: Spacing.sm) {
            // Temperature
            Label(thread.relationTemperature.label, systemImage: thread.relationTemperature.icon)
                .font(.spareMicro)
                .foregroundColor(thread.relationTemperature.color)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(thread.relationTemperature.color.opacity(0.12), in: Capsule())

            // Mask
            if let mask = thread.activeMaskName {
                Label(mask, systemImage: "theatermasks.fill")
                    .font(.spareMicro)
                    .foregroundColor(.spareYellowInk)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.spareYellowInk.opacity(0.10), in: Capsule())
            }

            Spacer()

            // Agent toggle
            Button {
                withAnimation(.spareSpring) { store.showAgentPanel.toggle() }
            } label: {
                Label("AI 助手", systemImage: "sparkles")
                    .font(.spareMicro)
                    .foregroundColor(store.showAgentPanel ? .spareDark : .secondary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(
                        Capsule()
                            .fill(store.showAgentPanel ? Color.spareYellow.opacity(0.9) : Color(.secondarySystemGroupedBackground))
                    )
            }
            .buttonStyle(.plain)

            // Expand/collapse cards button
            Button {
                withAnimation(.spareSpring) { contextCardsExpanded.toggle() }
            } label: {
                Image(systemName: contextCardsExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(Spacing.xs)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    /// Horizontal scrolling deck of relationship / mask / memory context cards.
    private var contextCardDeck: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: Spacing.md) {
                // Relationship card
                relationshipContextCard

                // Mask card
                maskContextCard

                // Memory card
                memoryContextCard

                // Group play card (only for group threads)
                if thread.kind == .group {
                    groupContextCard
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.md)
            .padding(.top, Spacing.xs)
        }
    }

    // MARK: - Relationship Context Card

    private var relationshipContextCard: some View {
        Button {
            store.showRelationship = true
        } label: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "heart.circle.fill")
                        .foregroundColor(.spareYellowInk)
                        .font(.system(size: 16))
                    Text("关系")
                        .font(.spareCaptionSB)
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Label(thread.relationTemperature.label,
                          systemImage: thread.relationTemperature.icon)
                        .font(.spareCaption)
                        .foregroundColor(thread.relationTemperature.color)

                    Text("认识 24 天")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)

                    // Bond progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(.systemGray5))
                                .frame(height: 4)
                            Capsule()
                                .fill(thread.relationTemperature.color)
                                .frame(width: geo.size.width * 0.62, height: 4)
                        }
                    }
                    .frame(height: 4)
                }

                Text("查看关系详情 →")
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }
            .padding(Spacing.md)
            .frame(width: 150, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(Color.spareYellow.opacity(0.18), lineWidth: 1)
            )
            .cardShadow()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mask Context Card

    private var maskContextCard: some View {
        Button {
            store.showContactMask = true
        } label: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "theatermasks.fill")
                        .foregroundColor(.spareYellowInk)
                        .font(.system(size: 16))
                    Text("面具")
                        .font(.spareCaptionSB)
                }

                if let mask = thread.activeMaskName {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(mask)
                            .font(.spareCaption)
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        PillTag(label: "激活中", color: .spareYellowInk, filled: true)

                        Text("此面具限制了部分个人信息可见度")
                            .font(.spareMicro)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                } else {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("未使用面具")
                            .font(.spareCaption)
                            .foregroundColor(.secondary)
                        Text("裸聊模式")
                            .font(.spareMicro)
                            .foregroundColor(.secondary)
                    }
                }

                Text("管理面具 →")
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }
            .padding(Spacing.md)
            .frame(width: 150, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(Color.spareYellow.opacity(0.18), lineWidth: 1)
            )
            .cardShadow()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Memory Context Card

    private var memoryContextCard: some View {
        Button {
            store.showCrossSessionMemory = true
        } label: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "brain")
                        .foregroundColor(.spareYellowInk)
                        .font(.system(size: 16))
                    Text("记忆")
                        .font(.spareCaptionSB)
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("上次聊天")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                    Text("提到了时间感知和那本书")
                        .font(.spareCaption)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Divider()

                    Text("建议话题：延续阅读讨论")
                        .font(.spareMicro)
                        .foregroundColor(.spareYellowInk)
                        .lineLimit(2)
                }

                Text("查看记忆 →")
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }
            .padding(Spacing.md)
            .frame(width: 150, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(Color.spareYellow.opacity(0.18), lineWidth: 1)
            )
            .cardShadow()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Group Context Card

    private var groupContextCard: some View {
        Button {
            store.showGroupPlay = true
        } label: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "person.3.fill")
                        .foregroundColor(.spareYellowInk)
                        .font(.system(size: 16))
                    Text("群聊")
                        .font(.spareCaptionSB)
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("4 位成员")
                        .font(.spareCaption)
                        .foregroundColor(.primary)
                    Text("2 位 Agent 在线")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                    PillTag(label: "群聊玩法可用", color: .spareYellowInk)
                }

                Text("查看群玩法 →")
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }
            .padding(Spacing.md)
            .frame(width: 150, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(Color.spareYellow.opacity(0.18), lineWidth: 1)
            )
            .cardShadow()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading / Empty

    private var loadingBody: some View {
        VStack(spacing: Spacing.lg) {
            ForEach(0..<5, id: \.self) { i in
                HStack {
                    if i % 2 == 0 { Spacer() }
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .fill(Color.cardBackground)
                        .frame(width: CGFloat.random(in: 140...260), height: 48)
                        .shimmer()
                    if i % 2 != 0 { Spacer() }
                }
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyBody: some View {
        EmptyStateView(
            icon: "message.circle",
            title: "开始聊天",
            message: "和 \(thread.contactName) 发送第一条消息。"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(store.messages) { msg in
                        if msg.senderRole == .system {
                            systemBubble(msg)
                        } else {
                            chatBubble(msg)
                                .id(msg.id)
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)
                .padding(.bottom, store.showAgentPanel ? 240 : 0)
            }
            .onChange(of: store.messages.count) { _ in
                if let last = store.messages.last {
                    withAnimation(.spareEase) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func chatBubble(_ msg: ChatMessage) -> some View {
        let isLocal = msg.senderRole.isLocal
        return HStack(alignment: .bottom, spacing: Spacing.sm) {
            if isLocal { Spacer(minLength: 60) }
            if !isLocal {
                participantAvatar(name: msg.senderName, role: msg.senderRole, size: 32)
            }
            VStack(alignment: isLocal ? .trailing : .leading, spacing: Spacing.xxs) {
                if !isLocal || msg.senderRole.isAgent {
                    HStack(spacing: 4) {
                        if msg.senderRole.isAgent {
                            Image(systemName: "sparkles")
                                .font(.spareMicro)
                                .foregroundColor(.spareYellow)
                        }
                        Text(msg.senderName)
                            .font(.spareMicro)
                            .foregroundColor(.secondary)
                    }
                }
                Text(msg.content)
                    .font(.spareBody)
                    .foregroundColor(.primary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        bubbleFill(for: msg.senderRole),
                        in: RoundedRectangle(cornerRadius: CornerRadius.lg)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.lg)
                            .stroke(
                                msg.senderRole.isLocal
                                    ? Color.clear
                                    : Color.spareYellow.opacity(0.16),
                                lineWidth: 1
                            )
                    )
                Text(msg.timestamp, style: .time)
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }
            if isLocal {
                participantAvatar(name: msg.senderName, role: msg.senderRole, size: 32)
            }
            if !isLocal { Spacer(minLength: 60) }
        }
        .padding(.vertical, Spacing.xs)
    }

    private func participantAvatar(name: String, role: ChatSenderRole, size: CGFloat) -> some View {
        AvatarView(name: name, size: size)
            .overlay(alignment: .bottomTrailing) {
                if role.isAgent {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.spareDark)
                        .padding(4)
                        .background(Color.spareYellow, in: Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 1)
                        )
                }
            }
    }

    private func bubbleFill(for role: ChatSenderRole) -> Color {
        switch role {
        case .myHuman:
            return .spareYellow
        case .myPersona:
            return .spareYellowLight
        case .theirHuman:
            return .white
        case .theirPersona, .agentHelper:
            return Color(red: 1.0, green: 0.98, blue: 0.88)
        case .system:
            return Color.secondary.opacity(0.15)
        }
    }

    private func systemBubble(_ msg: ChatMessage) -> some View {
        Text(msg.content)
            .font(.spareMicro)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.sm)
            .background(Color.white.opacity(0.88), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.spareYellow.opacity(0.18), lineWidth: 1)
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xs)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: Spacing.sm) {
            sendModeSwitcher

            HStack(alignment: .bottom, spacing: Spacing.sm) {
                Button { } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                }

                HStack(alignment: .bottom) {
                    TextField(store.sendMode.placeholder(for: thread.contactName), text: $store.draftText, axis: .vertical)
                        .font(.spareBody)
                        .lineLimit(1...5)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                }
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .fill(Color(.secondarySystemGroupedBackground))
                )

                Button { store.send() } label: {
                    Image(systemName: store.draftText.isEmpty ? store.sendMode.icon : "arrow.up.circle.fill")
                        .font(.system(size: 25))
                        .foregroundColor(store.draftText.isEmpty ? .secondary : .spareYellow)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
        .background(Color.white)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.spareYellow.opacity(0.14))
                .frame(height: 1)
        }
    }

    private var sendModeSwitcher: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(ChatSendMode.allCases) { mode in
                let isSelected = store.sendMode == mode

                Button {
                    withAnimation(.spareEase) { store.sendMode = mode }
                } label: {
                    Label(mode.rawValue, systemImage: mode.icon)
                        .font(.spareMicro)
                        .foregroundColor(isSelected ? .spareDark : .secondary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.spareYellow : Color(.secondarySystemGroupedBackground))
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Text(store.sendMode == .human ? "当前由你发送" : "当前由分身代发")
                .font(.spareMicro)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Agent Panel Overlay

    private var agentPanelOverlay: some View {
        VStack(spacing: 0) {
            // Handle + header
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 36, height: 4)
                    .padding(.top, Spacing.sm)

                HStack {
                    Label("Agent 助手", systemImage: "sparkles")
                        .font(.spareBodySB)
                        .foregroundColor(.primary)
                    Spacer()
                    Button {
                        withAnimation(.spareSpring) { store.showAgentPanel = false }
                    } label: {
                        Image(systemName: "chevron.down.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
            }
            .background(Color.white)

            Divider()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Spacing.sm) {
                    if store.agentMessages.isEmpty {
                        EmptyStateView(
                            icon: "sparkles",
                            title: "助手待命中",
                            message: "Agent 会在合适时机给你提示和建议。"
                        )
                    } else {
                        ForEach(store.agentMessages) { msg in
                            agentMessageRow(msg)
                        }
                    }
                }
                .padding(Spacing.md)
            }
            .background(Color.white)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 260)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                .stroke(Color.spareYellow.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 16, y: -4)
    }

    private func agentMessageRow(_ msg: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: msg.senderRole == .myPersona ? "person.crop.circle.fill.badge.checkmark" : "sparkles")
                .foregroundColor(msg.senderRole == .myPersona ? .spareYellow : .spareYellowInk)
                .font(.system(size: 18))

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(msg.senderName)
                    .font(.spareCaptionSB)
                    .foregroundColor(.secondary)
                Text(msg.content)
                    .font(.spareBody)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(Spacing.md)
        .background(Color(red: 1.0, green: 0.98, blue: 0.88), in: RoundedRectangle(cornerRadius: CornerRadius.md))
    }
}
