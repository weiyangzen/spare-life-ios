// QuadRoleChatView.swift
// Spare Life – 真人 + 双方分身同场（四角色共同聊天）
// Blueprint §消息 功能点 真人+双方分身同场 (line:1140)
// UIUX lane – slot 2

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Quad Role Chat Store

@MainActor
final class QuadRoleChatStore: ObservableObject {
    let thread: ConversationThread

    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isLoading = true
    @Published var draftText: String = ""
    @Published var selectedRole: ChatSenderRole = .myHuman
    @Published var showRoleGuide = false

    // Permission model: which roles can the local user activate?
    let localRoles: [ChatSenderRole] = [.myHuman, .myPersona]
    // Remote roles are theirHuman, theirPersona — rendered but not selectable
    let remoteRoles: [ChatSenderRole] = [.theirHuman, .theirPersona]

    init(thread: ConversationThread) {
        self.thread = thread
    }

    func load() {
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            self.messages = Self.mockQuadMessages(contactName: thread.contactName)
            self.isLoading = false
        }
    }

    func send() {
        guard !draftText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let msg = ChatMessage(
            id: UUID().uuidString,
            senderRole: selectedRole,
            senderName: selectedRole.displayName,
            content: draftText,
            timestamp: Date(),
            isAgentThread: false
        )
        withAnimation(.spareEase) {
            messages.append(msg)
        }
        draftText = ""
    }

    private static func mockQuadMessages(contactName: String) -> [ChatMessage] {
        let now = Date()
        return [
            ChatMessage(id: "q1", senderRole: .myHuman, senderName: "我",
                        content: "我来开启四人场，大家都来说说对这次活动的想法？",
                        timestamp: now - 1800, isAgentThread: false),
            ChatMessage(id: "q2", senderRole: .theirHuman, senderName: contactName,
                        content: "好主意！我也想听听各方的看法。",
                        timestamp: now - 1750, isAgentThread: false),
            ChatMessage(id: "q3", senderRole: .myPersona, senderName: "我的分身",
                        content: "从我们共同的偏好来看，户外活动最合适——上次\(contactName)提到喜欢爬山。",
                        timestamp: now - 1680, isAgentThread: false),
            ChatMessage(id: "q4", senderRole: .theirPersona, senderName: "\(contactName)的分身",
                        content: "没错，\(contactName)最近体力状态很好，周末爬山完全没问题，建议上午出发。",
                        timestamp: now - 1620, isAgentThread: false),
            ChatMessage(id: "q5", senderRole: .system, senderName: "系统",
                        content: "双方分身已完成背景对齐，真人可以直接讨论具体方案。",
                        timestamp: now - 1500, isAgentThread: false),
            ChatMessage(id: "q6", senderRole: .theirHuman, senderName: contactName,
                        content: "那就这周六早上 8 点，香山见？",
                        timestamp: now - 1440, isAgentThread: false),
        ]
    }
}

// MARK: - Quad Role Chat View

struct QuadRoleChatView: View {
    let thread: ConversationThread
    let presentation: CompanionSurfacePresentationMode
    @StateObject private var store: QuadRoleChatStore
    @Environment(\.dismiss) private var dismiss

    init(
        thread: ConversationThread,
        presentation: CompanionSurfacePresentationMode = .modal
    ) {
        self.thread = thread
        self.presentation = presentation
        _store = StateObject(wrappedValue: QuadRoleChatStore(thread: thread))
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
        ZStack(alignment: .bottom) {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                roleHeaderBar
                Divider()

                if store.isLoading {
                    loadingBody
                } else {
                    messageArea
                }

                roleInputBar
            }
        }
        .navigationTitle("四人场")
        .spareNavigationBarTitleDisplayMode(.inline)
        .toolbar {
            if presentation == .modal {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.showRoleGuide = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                }
            }
        }
        .task { store.load() }
        .sheet(isPresented: $store.showRoleGuide) {
            roleGuideSheet
                .presentationDragIndicator(.visible)
                .presentationDetents([.medium])
        }
    }

    // MARK: - Role Header

    private var roleHeaderBar: some View {
        HStack(spacing: 0) {
            ForEach([ChatSenderRole.myHuman, .myPersona, .theirPersona, .theirHuman], id: \.self) { role in
                roleHeaderItem(role)
            }
        }
        .padding(.vertical, Spacing.sm)
        .background(Color(.secondarySystemGroupedBackground))
    }

    private func roleHeaderItem(_ role: ChatSenderRole) -> some View {
        VStack(spacing: Spacing.xs) {
            ZStack {
                Circle()
                    .fill(role.bubbleColor)
                    .frame(width: 44, height: 44)
                Text(String(role.displayName.prefix(1)))
                    .font(.spareBodySB)
                    .foregroundColor(role.isLocal ? .spareDark : .primary)
            }
            .overlay(
                Circle()
                    .stroke(role.isLocal ? Color.spareYellow : Color.clear, lineWidth: 2)
            )
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

            Text(role.displayName)
                .font(.spareMicro)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Loading

    private var loadingBody: some View {
        VStack(spacing: Spacing.lg) {
            ForEach(0..<4, id: \.self) { i in
                HStack {
                    if i % 2 == 0 { Spacer() }
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .fill(Color.cardBackground)
                        .frame(width: CGFloat.random(in: 140...240), height: 56)
                        .shimmer()
                    if i % 2 != 0 { Spacer() }
                }
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Message Area

    private var messageArea: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: Spacing.xs) {
                    ForEach(store.messages) { msg in
                        quadRoleBubble(msg)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)
            }
            .onChange(of: store.messages.count) { _, _ in
                if let last = store.messages.last {
                    withAnimation(.spareEase) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func quadRoleBubble(_ msg: ChatMessage) -> some View {
        let isLocal = msg.senderRole.isLocal
        let isSystem = msg.senderRole == .system

        return Group {
            if isSystem {
                systemBubble(msg)
            } else {
                HStack(alignment: .bottom, spacing: Spacing.sm) {
                    if isLocal { Spacer(minLength: 40) }

                    VStack(alignment: isLocal ? .trailing : .leading, spacing: Spacing.xxs) {
                        // Role label
                        HStack(spacing: Spacing.xs) {
                            if msg.senderRole.isAgent {
                                Image(systemName: "sparkles")
                                    .font(.spareMicro)
                                    .foregroundColor(.secondary)
                            }
                            Text(msg.senderRole.displayName)
                                .font(.spareMicro)
                                .foregroundColor(.secondary)
                        }
                        // Bubble
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

                    if !isLocal { Spacer(minLength: 40) }
                }
                .padding(.vertical, Spacing.xxs)
            }
        }
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

    // MARK: - Role Input Bar

    private var roleInputBar: some View {
        VStack(spacing: 0) {
            // Role selector
            HStack(spacing: Spacing.sm) {
                Text("以")
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
                ForEach(store.localRoles, id: \.self) { role in
                    roleSelectorChip(role)
                }
                Text("身份发言")
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)

            // Input
            HStack(alignment: .bottom, spacing: Spacing.sm) {
                TextField("说话…", text: $store.draftText, axis: .vertical)
                    .font(.spareBody)
                    .lineLimit(1...4)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: CornerRadius.lg))

                Button { store.send() } label: {
                    Image(systemName: store.draftText.isEmpty ? "mic.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(store.draftText.isEmpty ? .secondary : store.selectedRole.bubbleColor)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .background(Color(.secondarySystemGroupedBackground))
    }

    private func roleSelectorChip(_ role: ChatSenderRole) -> some View {
        let isSelected = store.selectedRole == role
        return Button {
            withAnimation(.spareEase) {
                store.selectedRole = role
            }
        } label: {
            Text(role.displayName)
                .font(.spareCaptionSB)
                .foregroundColor(isSelected ? .spareDark : .primary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(
                    isSelected ? role.bubbleColor : Color(.tertiarySystemGroupedBackground),
                    in: Capsule()
                )
                .overlay(
                    Capsule().stroke(isSelected ? role.bubbleColor : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Role Guide Sheet

    private var roleGuideSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Text("四人场由四个角色共同参与对话：")
                        .font(.spareBody)
                        .foregroundColor(.secondary)

                    ForEach([ChatSenderRole.myHuman, .myPersona, .theirPersona, .theirHuman], id: \.self) { role in
                        HStack(alignment: .top, spacing: Spacing.md) {
                            ZStack {
                                Circle()
                                    .fill(role.bubbleColor)
                                    .frame(width: 36, height: 36)
                                Text(String(role.displayName.prefix(1)))
                                    .font(.spareBodySB)
                                    .foregroundColor(role.isLocal ? .spareDark : .primary)
                            }
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text(role.displayName)
                                    .font(.spareBodySB)
                                Text(roleDescription(role))
                                    .font(.spareCaption)
                                    .foregroundColor(.secondary)
                                if role.isLocal {
                                    PillTag(label: "你可控制", color: .emotionPositive, filled: true)
                                } else {
                                    PillTag(label: "对方控制", color: .secondary)
                                }
                            }
                        }
                    }

                    Divider()

                    Text("分身发言不计入主聊天记录，但会影响 Agent 的建议和关系分析。")
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                }
                .padding(Spacing.lg)
            }
            .navigationTitle("四人场说明")
            .spareNavigationBarTitleDisplayMode(.inline)
        }
    }

    private func roleDescription(_ role: ChatSenderRole) -> String {
        switch role {
        case .myHuman:      return "就是你自己，说真实的话。"
        case .myPersona:    return "你的分身，代替你处理背景信息、给出建议。"
        case .theirPersona: return "对方的分身，能说出对方的倾向和背景。"
        case .theirHuman:   return "对方本人，真实发言。"
        default:            return ""
        }
    }
}
