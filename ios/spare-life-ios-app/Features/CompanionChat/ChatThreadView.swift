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

// MARK: - Chat Thread View

struct ChatThreadView: View {
    let thread: ConversationThread
    @EnvironmentObject private var router: ConversationRouter
    @StateObject private var store: ChatThreadStore
    @State private var contextCardsExpanded = false
    @FocusState private var isComposerFocused: Bool

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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            inputBar
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
                Button { router.openMask(for: thread) } label: {
                    Label("面具设置", systemImage: "theatermasks.fill")
                }
                Button { router.openRelationship(for: thread) } label: {
                    Label("关系养成", systemImage: "heart.circle.fill")
                }
                Button { router.openMemory(for: thread) } label: {
                    Label("跨会话记忆", systemImage: "brain")
                }
                if thread.kind == .group {
                    Button { router.openGroupPlay(for: thread) } label: {
                        Label("群聊玩法", systemImage: "person.3.fill")
                    }
                }
                Button { router.openQuadRole(for: thread) } label: {
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
        .contentShape(Rectangle())
        .onTapGesture {
            dismissKeyboard()
        }
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
            router.openRelationship(for: thread)
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
            router.openMask(for: thread)
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
            router.openMemory(for: thread)
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
            router.openGroupPlay(for: thread)
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
                .padding(.bottom, store.showAgentPanel ? 260 : 0)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                dismissKeyboard()
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
                        .focused($isComposerFocused)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .submitLabel(.send)
                        .onSubmit {
                            store.send()
                        }
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
        .padding(.bottom, max(spareBottomSafeAreaInset(), Spacing.sm))
        .frame(maxWidth: .infinity)
        .background(
            Rectangle()
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 10, y: -4)
        )
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

    private func dismissKeyboard() {
        isComposerFocused = false
        #if canImport(UIKit)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
        #endif
    }
}
