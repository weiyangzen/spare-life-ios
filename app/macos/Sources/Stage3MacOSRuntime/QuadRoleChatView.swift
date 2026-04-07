import SwiftUI

@MainActor
final class QuadRoleChatStore: ObservableObject {
    let thread: ConversationThread

    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isLoading = true
    @Published var draftText = ""
    @Published var selectedRole: ChatSenderRole = .myHuman
    @Published var showRoleGuide = false

    let localRoles: [ChatSenderRole] = [.myHuman, .myPersona]

    init(thread: ConversationThread) {
        self.thread = thread
    }

    func load() {
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            messages = Self.mockQuadMessages(contactName: thread.contactName)
            isLoading = false
        }
    }

    func send() {
        guard !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let message = ChatMessage(
            id: UUID().uuidString,
            senderRole: selectedRole,
            senderName: selectedRole.displayName,
            content: draftText,
            timestamp: Date(),
            isAgentThread: false
        )

        withAnimation(.spareEase) {
            messages.append(message)
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
                        content: "从共同偏好看，户外活动最合适，上次 \(contactName) 也提到最近想多走动。",
                        timestamp: now - 1680, isAgentThread: false),
            ChatMessage(id: "q4", senderRole: .theirPersona, senderName: "\(contactName) 的分身",
                        content: "建议上午出发，留出午饭前回程的余量，双方节奏都更稳。",
                        timestamp: now - 1620, isAgentThread: false),
            ChatMessage(id: "q5", senderRole: .system, senderName: "系统",
                        content: "双方分身已完成背景对齐，真人可以直接讨论具体方案。",
                        timestamp: now - 1500, isAgentThread: false),
            ChatMessage(id: "q6", senderRole: .theirHuman, senderName: contactName,
                        content: "那就这周六早上 8 点，香山见？",
                        timestamp: now - 1440, isAgentThread: false)
        ]
    }
}

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

    @ViewBuilder
    private var surfaceContent: some View {
        if presentation == .embedded {
            Stage3MacOSAccessoryWorkspaceSplit(
                isPresented: store.showRoleGuide,
                autosaveName: "quadRoleAccessory"
            ) {
                surfaceContentBody
            } panelContent: {
                if store.showRoleGuide {
                    Stage3MacOSQuadRoleGuideSheet()
                }
            }
        } else {
            surfaceContentBody
                .sheet(isPresented: $store.showRoleGuide) {
                    Stage3MacOSQuadRoleGuideSheet()
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                }
        }
    }

    private var surfaceContentBody: some View {
        ZStack(alignment: .bottom) {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                roleHeader
                Divider()

                if store.isLoading {
                    loadingBody
                } else {
                    messageArea
                }

                inputBar
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
        .task {
            store.load()
        }
    }

    private var roleHeader: some View {
        HStack(spacing: 0) {
            ForEach([ChatSenderRole.myHuman, .myPersona, .theirPersona, .theirHuman], id: \.self) { role in
                VStack(spacing: Spacing.xs) {
                    ZStack {
                        Circle()
                            .fill(role.bubbleColor)
                            .frame(width: 42, height: 42)
                        Text(String(role.displayName.prefix(1)))
                            .font(.spareBodySB)
                            .foregroundColor(role.isLocal ? .spareDark : .primary)
                    }
                    .overlay(
                        Circle()
                            .stroke(role.isLocal ? Color.spareYellow : Color.clear, lineWidth: 2)
                    )

                    Text(role.displayName)
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, Spacing.sm)
        .background(Color(.secondarySystemGroupedBackground))
    }

    private var loadingBody: some View {
        VStack(spacing: Spacing.lg) {
            ForEach(0..<4, id: \.self) { index in
                HStack {
                    if index.isMultiple(of: 2) { Spacer() }
                    RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                        .fill(Color.white)
                        .frame(width: CGFloat(index.isMultiple(of: 2) ? 220 : 180), height: 56)
                        .shimmer()
                    if !index.isMultiple(of: 2) { Spacer() }
                }
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var messageArea: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: Spacing.sm) {
                    ForEach(store.messages) { message in
                        messageBubble(message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, Spacing.md)
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
    }

    private func messageBubble(_ message: ChatMessage) -> some View {
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
                if isLocal { Spacer(minLength: 40) }

                VStack(alignment: isLocal ? .trailing : .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xs) {
                        if message.senderRole.isAgent {
                            Image(systemName: "sparkles")
                                .font(.spareMicro)
                                .foregroundColor(.secondary)
                        }
                        Text(message.senderRole.displayName)
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

                if !isLocal { Spacer(minLength: 40) }
            }
        )
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.sm) {
                Text("以")
                    .font(.spareCaption)
                    .foregroundColor(.secondary)

                ForEach(store.localRoles, id: \.self) { role in
                    Button {
                        withAnimation(.spareEase) {
                            store.selectedRole = role
                        }
                    } label: {
                        Label(role.displayName, systemImage: role == .myPersona ? "sparkles" : "person.fill")
                            .font(.spareMicro)
                            .foregroundColor(store.selectedRole == role ? .spareYellowInk : .secondary)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(
                                Capsule()
                                    .fill(store.selectedRole == role ? Color.spareYellow.opacity(0.16) : Color(.secondarySystemGroupedBackground))
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)

            HStack(alignment: .bottom, spacing: Spacing.sm) {
                TextField("让真人或分身继续推进四人场…", text: $store.draftText, axis: .vertical)
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
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .background(Color(.secondarySystemGroupedBackground))
    }
}

private struct Stage3MacOSQuadRoleGuideSheet: View {
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("四人场说明")
                    .font(.spareTitle3)
                    .foregroundColor(.primary)

                Stage3MacOSInspectorSection(
                    title: "角色分工",
                    subtitle: "真人与双方分身共用一条线程"
                ) {
                    Text("本地仅允许切换“我 / 我的分身”，远端真人与远端分身只展示不直接控制。")
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Stage3MacOSInspectorSection(
                    title: "使用建议",
                    subtitle: "先让分身铺背景，再由真人拍板"
                ) {
                    Text("当双方已经有共同偏好或历史上下文时，让分身先做对齐，再由真人确认时间、预算和边界，会更稳定。")
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(Spacing.xl)
        }
    }
}
