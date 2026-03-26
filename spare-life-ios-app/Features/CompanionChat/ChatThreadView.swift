// ChatThreadView.swift
// Spare Life – 熟人聊天主线程 + Agent 辅助线程
// Blueprint §消息 功能点 熟人聊天主线程 (line:1138)
// Blueprint §统一UI 消息详情卡片化 (line:1153) [UIUX]
// UIUX lane – slot 2

import SwiftUI

// MARK: - Chat Thread Store

@MainActor
final class ChatThreadStore: ObservableObject {
    let thread: ConversationThread

    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var agentMessages: [ChatMessage] = []  // Agent 辅助线程
    @Published private(set) var isLoading = true
    @Published var showAgentPanel = false
    @Published var draftText: String = ""
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
            self.messages = Self.mockMessages(contactName: thread.contactName)
            self.agentMessages = Self.mockAgentMessages(contactName: thread.contactName)
            self.isLoading = false
        }
    }

    func send() {
        guard !draftText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let msg = ChatMessage(
            id: UUID().uuidString,
            senderRole: .myHuman,
            senderName: "我",
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

    private static func mockMessages(contactName: String) -> [ChatMessage] {
        let now = Date()
        return [
            ChatMessage(id: "m1", senderRole: .theirHuman, senderName: contactName,
                        content: "嗨！你昨天推荐的那本书真的很有意思", timestamp: now - 7200,
                        isAgentThread: false),
            ChatMessage(id: "m2", senderRole: .myHuman, senderName: "我",
                        content: "哈哈是吧，我也觉得第三章写得特别好", timestamp: now - 7100,
                        isAgentThread: false),
            ChatMessage(id: "m3", senderRole: .theirHuman, senderName: contactName,
                        content: "对！尤其是那段关于时间感知的论述", timestamp: now - 7050,
                        isAgentThread: false),
            ChatMessage(id: "m4", senderRole: .system, senderName: "系统",
                        content: "Agent 助手已整理昨日对话摘要", timestamp: now - 3600,
                        isAgentThread: false),
            ChatMessage(id: "m5", senderRole: .myHuman, senderName: "我",
                        content: "下午去那个咖啡馆？", timestamp: now - 1800,
                        isAgentThread: false),
            ChatMessage(id: "m6", senderRole: .theirHuman, senderName: contactName,
                        content: "好啊，3 点见？", timestamp: now - 1700,
                        isAgentThread: false),
        ]
    }

    private static func mockAgentMessages(contactName: String) -> [ChatMessage] {
        let now = Date()
        return [
            ChatMessage(id: "a1", senderRole: .myPersona, senderName: "你的分身",
                        content: "已为你整理今日与\(contactName)的约定：下午 3 点，咖啡馆。",
                        timestamp: now - 1600, isAgentThread: true),
            ChatMessage(id: "a2", senderRole: .agentHelper, senderName: "Agent 助手",
                        content: "关系温度：亲近。上次聊天提到了「时间感知」，可以延续这个话题。",
                        timestamp: now - 900, isAgentThread: true),
            ChatMessage(id: "a3", senderRole: .agentHelper, senderName: "Agent 助手",
                        content: "建议开场白：「你那本书读完了没？我刚看到一篇相关的论文」",
                        timestamp: now - 300, isAgentThread: true),
        ]
    }
}

// MARK: - Chat Thread View

struct ChatThreadView: View {
    let thread: ConversationThread
    @StateObject private var store: ChatThreadStore
    @State private var contextCardsExpanded = true

    init(thread: ConversationThread) {
        self.thread = thread
        _store = StateObject(wrappedValue: ChatThreadStore(thread: thread))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.systemGroupedBackground).ignoresSafeArea()

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
        .navigationBarTitleDisplayMode(.inline)
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
        .background(Color(.secondarySystemGroupedBackground))
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
                    .foregroundColor(.blue)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.blue.opacity(0.10), in: Capsule())
            }

            Spacer()

            // Agent toggle
            Button {
                withAnimation(.spareSpring) { store.showAgentPanel.toggle() }
            } label: {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(store.showAgentPanel ? .spareYellow : .secondary)
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
                        .foregroundColor(.pink)
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
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
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
                        .foregroundColor(.blue)
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

                        PillTag(label: "激活中", color: .blue, filled: true)

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
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
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
                        .foregroundColor(.purple)
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
                        .foregroundColor(.purple)
                        .lineLimit(2)
                }

                Text("查看记忆 →")
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }
            .padding(Spacing.md)
            .frame(width: 150, alignment: .leading)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
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
                        .foregroundColor(.indigo)
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
                    PillTag(label: "群聊玩法可用", color: .indigo)
                }

                Text("查看群玩法 →")
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }
            .padding(Spacing.md)
            .frame(width: 150, alignment: .leading)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
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
                AvatarView(name: msg.senderName, size: 32)
            }
            VStack(alignment: isLocal ? .trailing : .leading, spacing: Spacing.xxs) {
                if !isLocal {
                    Text(msg.senderName)
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }
                Text(msg.content)
                    .font(.spareBody)
                    .foregroundColor(isLocal ? .spareDark : .primary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        msg.senderRole.bubbleColor,
                        in: RoundedRectangle(cornerRadius: CornerRadius.lg)
                    )
                Text(msg.timestamp, style: .time)
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }
            if isLocal {
                AvatarView(name: "我", size: 32)
            }
            if !isLocal { Spacer(minLength: 60) }
        }
        .padding(.vertical, Spacing.xs)
    }

    private func systemBubble(_ msg: ChatMessage) -> some View {
        Text(msg.content)
            .font(.spareMicro)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: Spacing.sm) {
            // Voice / camera menu
            Button { } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.secondary)
            }

            // Text field
            HStack(alignment: .bottom) {
                TextField("发消息给 \(thread.contactName)…", text: $store.draftText, axis: .vertical)
                    .font(.spareBody)
                    .lineLimit(1...5)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
            }
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: CornerRadius.lg))

            // Send
            Button { store.send() } label: {
                Image(systemName: store.draftText.isEmpty ? "mic.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(store.draftText.isEmpty ? .secondary : .spareYellow)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(Color(.secondarySystemGroupedBackground))
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
            .background(Color(.secondarySystemGroupedBackground))

            Divider()

            // Agent messages scroll
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
        }
        .frame(maxWidth: .infinity)
        .frame(height: 260)
        .background(
            Color(.systemGroupedBackground)
                .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: -4)
        )
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
    }

    private func agentMessageRow(_ msg: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: msg.senderRole == .myPersona ? "person.crop.circle.fill.badge.checkmark" : "sparkles")
                .foregroundColor(msg.senderRole == .myPersona ? .spareYellow : .blue)
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
        .background(msg.senderRole.bubbleColor, in: RoundedRectangle(cornerRadius: CornerRadius.md))
    }
}
