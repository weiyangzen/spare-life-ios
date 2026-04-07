import SwiftUI

enum ChatSendMode: String, CaseIterable, Identifiable {
    case human = "真人模式"
    case aiAuto = "AI 全自动"

    var id: String { rawValue }

    var senderRole: ChatSenderRole {
        switch self {
        case .human:
            return .myHuman
        case .aiAuto:
            return .myPersona
        }
    }

    var icon: String {
        switch self {
        case .human:
            return "person.fill"
        case .aiAuto:
            return "sparkles"
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

struct ChatThreadView: View {
    let thread: ConversationThread

    @EnvironmentObject private var router: ConversationRouter
    @StateObject private var store: ChatThreadStore
    @State private var showContextCards = true

    init(thread: ConversationThread) {
        self.thread = thread
        _store = StateObject(wrappedValue: ChatThreadStore(thread: thread))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if store.isLoading {
                loadingBody
            } else {
                messageWorkspace
            }
        }
        .background(
            LinearGradient(
                colors: [
                    Color.spareYellow.opacity(0.08),
                    Color.white,
                    Color.white
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .task {
            store.load()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composer
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: Spacing.md) {
                AvatarView(name: thread.contactName, size: 46)

                VStack(alignment: .leading, spacing: 3) {
                    Text(thread.contactName)
                        .font(.spareTitle3)
                        .foregroundColor(.primary)

                    HStack(spacing: Spacing.sm) {
                        Label(thread.relationTemperature.label, systemImage: thread.relationTemperature.icon)
                            .font(.spareMicro)
                            .foregroundColor(thread.relationTemperature.color)

                        if let mask = thread.activeMaskName {
                            Label(mask, systemImage: "theatermasks.fill")
                                .font(.spareMicro)
                                .foregroundColor(.spareYellowInk)
                        }

                        if thread.isTyping {
                            Text("正在输入…")
                                .font(.spareMicro)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer(minLength: 0)

                Button {
                    withAnimation(.spareSpring) {
                        showContextCards.toggle()
                    }
                } label: {
                    Label(showContextCards ? "收起上下文" : "展开上下文", systemImage: showContextCards ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                }
                .buttonStyle(.bordered)

                Button {
                    withAnimation(.spareSpring) {
                        store.showAgentPanel.toggle()
                    }
                } label: {
                    Label("AI 助手", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .tint(store.showAgentPanel ? .spareYellow : .gray.opacity(0.3))
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)

            if showContextCards {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: Spacing.md) {
                        routeCard(
                            title: "面具设置",
                            subtitle: thread.activeMaskName ?? "默认面具",
                            icon: "theatermasks.fill",
                            action: { router.openMask(for: thread) }
                        )
                        routeCard(
                            title: "关系养成",
                            subtitle: thread.relationTemperature.label,
                            icon: "heart.circle.fill",
                            action: { router.openRelationship(for: thread) }
                        )
                        routeCard(
                            title: "跨会话记忆",
                            subtitle: "查看摘要、长期记忆与待跟进事项",
                            icon: "brain",
                            action: { router.openMemory(for: thread) }
                        )
                        routeCard(
                            title: "四人场",
                            subtitle: "真人 + 双方分身同场",
                            icon: "person.3.fill",
                            action: { router.openQuadRole(for: thread) }
                        )

                        if thread.kind == .group {
                            routeCard(
                                title: "群聊玩法",
                                subtitle: "群投票、群内规则与协作节奏",
                                icon: "person.2.circle.fill",
                                action: { router.openGroupPlay(for: thread) }
                            )
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.md)
                }
            }
        }
        .background(Color.white.opacity(0.92))
    }

    private func routeCard(
        title: String,
        subtitle: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label(title, systemImage: icon)
                    .font(.spareCaptionSB)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(Spacing.md)
            .frame(width: 212, alignment: .topLeading)
            .frame(minHeight: 108, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                    .fill(Color.spareYellow.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                    .stroke(Color.spareYellow.opacity(0.24), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var loadingBody: some View {
        VStack(spacing: Spacing.lg) {
            ForEach(0..<5, id: \.self) { index in
                HStack {
                    if index.isMultiple(of: 2) { Spacer() }
                    RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                        .fill(Color.white)
                        .frame(width: CGFloat(index.isMultiple(of: 2) ? 240 : 200), height: 66)
                        .shimmer()
                    if !index.isMultiple(of: 2) { Spacer() }
                }
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var messageWorkspace: some View {
        HStack(spacing: 0) {
            timelineColumn

            if store.showAgentPanel {
                Divider()

                agentPanel
                    .frame(minWidth: 260, idealWidth: 300, maxWidth: 340)
                    .background(Color.white.opacity(0.92))
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }

    private var timelineColumn: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: Spacing.sm) {
                    ForEach(store.messages) { message in
                        chatBubble(message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
            }
            .onChange(of: store.messages.count) { _ in
                if let last = store.messages.last {
                    withAnimation(.spareEase) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func chatBubble(_ message: ChatMessage) -> some View {
        if message.senderRole == .system {
            return AnyView(
                Text(message.content)
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
            )
        }

        let isLocal = message.senderRole.isLocal
        return AnyView(
            HStack(alignment: .bottom, spacing: Spacing.sm) {
                if isLocal { Spacer(minLength: 60) }

                VStack(alignment: isLocal ? .trailing : .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xs) {
                        if message.senderRole.isAgent {
                            Image(systemName: "sparkles")
                                .font(.spareMicro)
                                .foregroundColor(.secondary)
                        }

                        Text(message.senderName)
                            .font(.spareMicro)
                            .foregroundColor(.secondary)
                    }

                    Text(message.content)
                        .font(.spareBody)
                        .foregroundColor(isLocal ? .spareDark : .primary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                                .fill(message.senderRole.bubbleColor)
                        )

                    Text(message.timestamp, style: .time)
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }

                if !isLocal { Spacer(minLength: 60) }
            }
        )
    }

    private var agentPanel: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("AI 助手线程")
                    .font(.spareCaptionSB)
                    .foregroundColor(.secondary)
                    .padding(.top, Spacing.md)

                ForEach(store.agentMessages) { message in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: message.senderRole == .agentHelper ? "brain.head.profile" : "sparkles")
                                .font(.spareMicro)
                                .foregroundColor(.spareYellowInk)
                            Text(message.senderName)
                                .font(.spareCaptionSB)
                                .foregroundColor(.primary)
                        }

                        Text(message.content)
                            .font(.spareCaption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                            .fill(Color.spareYellow.opacity(0.12))
                    )
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xxxl)
        }
    }

    private var composer: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                ForEach(ChatSendMode.allCases) { mode in
                    Button {
                        withAnimation(.spareEase) {
                            store.sendMode = mode
                        }
                    } label: {
                        Label(mode.rawValue, systemImage: mode.icon)
                            .font(.spareMicro)
                            .foregroundColor(store.sendMode == mode ? .spareYellowInk : .secondary)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(
                                Capsule()
                                    .fill(store.sendMode == mode ? Color.spareYellow.opacity(0.16) : Color(.secondarySystemGroupedBackground))
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }

            HStack(alignment: .bottom, spacing: Spacing.sm) {
                TextField(store.sendMode.placeholder(for: thread.contactName), text: $store.draftText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)

                Button {
                    store.send()
                } label: {
                    Image(systemName: store.draftText.isEmpty ? "mic.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(store.draftText.isEmpty ? .secondary : .spareYellowInk)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.md)
        .background(Color.white.opacity(0.94))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.spareYellow.opacity(0.14))
                .frame(height: 1)
        }
    }
}
