import AppKit
import SwiftUI

public struct Stage3MacOSWorkspaceSnapshot: Equatable, Sendable {
    public let tabID: String
    public let layoutStyle: String
    public let columnKinds: [String]
    public let mirroredContentKinds: [String]
    public let mirroredEntryKinds: [String]

    public init(
        tabID: String,
        layoutStyle: String,
        columnKinds: [String],
        mirroredContentKinds: [String],
        mirroredEntryKinds: [String]
    ) {
        self.tabID = tabID
        self.layoutStyle = layoutStyle
        self.columnKinds = columnKinds
        self.mirroredContentKinds = mirroredContentKinds
        self.mirroredEntryKinds = mirroredEntryKinds
    }
}

extension Stage3MacOSRuntime {
    public static func workspaceSnapshot(for tabID: String) -> Stage3MacOSWorkspaceSnapshot? {
        switch resolvedTabID(tabID) {
        case "xianxia":
            return Stage3MacOSWorkspaceSnapshot(
                tabID: "xianxia",
                layoutStyle: "list-detail-inspector",
                columnKinds: ["topic catalog", "topic detail", "topic inspector"],
                mirroredContentKinds: ["topic feed cards", "topic shard cards", "topic metadata"],
                mirroredEntryKinds: ["topic open", "feed refresh", "detail refresh"]
            )
        case "messages":
            return Stage3MacOSWorkspaceSnapshot(
                tabID: "messages",
                layoutStyle: "hub-thread-detail",
                columnKinds: ["message hub", "route detail", "thread inspector"],
                mirroredContentKinds: ["recent contacts", "conversation threads", "thread subpages"],
                mirroredEntryKinds: [
                    "thread open",
                    "mask open",
                    "relationship open",
                    "memory open",
                    "quad role open",
                    "group play open"
                ]
            )
        case "master":
            return Stage3MacOSWorkspaceSnapshot(
                tabID: "master",
                layoutStyle: "directory-session-inspector",
                columnKinds: ["master directory", "conversation session", "supporting inspector"],
                mirroredContentKinds: ["master cards", "master conversation", "recent sessions"],
                mirroredEntryKinds: ["directory search", "domain filter", "session restore", "conversation open"]
            )
        case "earnSocial":
            return Stage3MacOSWorkspaceSnapshot(
                tabID: "earnSocial",
                layoutStyle: "market-canvas-inspector",
                columnKinds: ["category catalog", "market canvas", "engagement inspector"],
                mirroredContentKinds: ["category rails", "waterfall cards", "preference and chat entry"],
                mirroredEntryKinds: ["category index", "card open", "preference open"]
            )
        case "myProfile":
            return Stage3MacOSWorkspaceSnapshot(
                tabID: "myProfile",
                layoutStyle: "identity-dashboard-inspector",
                columnKinds: ["identity summary", "feature dashboard", "avatar and backend inspector"],
                mirroredContentKinds: ["profile metrics", "dashboard surfaces", "visibility and backend state"],
                mirroredEntryKinds: ["surface switch", "diagnostic open", "backend open"]
            )
        default:
            return nil
        }
    }
}

struct Stage3MacOSXianxiaWorkspaceView: View {
    @StateObject private var viewModel = XianxiaHomeViewModel()
    @State private var selectedTopicID: String?

    private var selectedTopic: XianxiaTopic? {
        let candidates = viewModel.topics
        guard !candidates.isEmpty else { return nil }
        return candidates.first(where: { $0.id == selectedTopicID }) ?? candidates.first
    }

    var body: some View {
        HSplitView {
            catalogColumn
                .frame(minWidth: 320, idealWidth: 344, maxWidth: 396)

            detailColumn
                .frame(minWidth: 480, idealWidth: 620, maxWidth: .infinity)

            inspectorColumn
                .frame(minWidth: 260, idealWidth: 292, maxWidth: 332)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            viewModel.loadIfNeeded()
        }
        .onChange(of: viewModel.topics) { topics in
            guard !topics.isEmpty else {
                selectedTopicID = nil
                return
            }

            guard let selectedTopicID else {
                self.selectedTopicID = topics.first?.id
                return
            }

            if topics.contains(where: { $0.id == selectedTopicID }) {
                return
            }

            self.selectedTopicID = topics.first?.id
        }
    }

    private var catalogColumn: some View {
        VStack(spacing: 0) {
            Stage3MacOSWorkspaceColumnHeader(
                title: "话题目录",
                subtitle: "保留闲虾原始卡片语言，并在桌面侧稳定承接列表选择与刷新。"
            ) {
                Button("刷新目录") {
                    viewModel.refresh()
                }
                .buttonStyle(.borderedProminent)
                .tint(.spareYellow)
            }

            Divider()

            Group {
                switch viewModel.feedState {
                case .idle, .loading:
                    ScrollView {
                        WaterfallSkeleton(count: 6)
                            .padding(Spacing.md)
                    }
                case .empty:
                    ScrollView {
                        EmptyStateView(
                            icon: "tray",
                            title: "还没有可浏览的话题",
                            message: "当前 topic 数据源没有返回内容，稍后刷新再试。",
                            actionLabel: "重新拉取",
                            action: { viewModel.refresh() }
                        )
                        .padding(.top, Spacing.xxxl)
                        .padding(.horizontal, Spacing.md)
                    }
                case .error(let message):
                    ScrollView {
                        ErrorStateView(
                            message: message,
                            cached: false,
                            retry: { viewModel.refresh() }
                        )
                        .padding(.top, Spacing.xxxl)
                        .padding(.horizontal, Spacing.md)
                    }
                case .loadedFromCache, .loaded:
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: Spacing.md) {
                            ForEach(viewModel.topics) { topic in
                                TopicFeedCardView(topic: topic) {
                                    withAnimation(.spareSpring) {
                                        selectedTopicID = topic.id
                                    }
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                                        .stroke(
                                            selectedTopic?.id == topic.id ? Color.spareYellowInk.opacity(0.42) : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                                .onAppear {
                                    viewModel.loadMoreIfNeeded(after: topic)
                                }
                            }

                            if viewModel.isLoadingMore {
                                HStack(spacing: Spacing.sm) {
                                    ProgressView()
                                    Text("继续加载更多话题…")
                                        .font(.spareCaption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, Spacing.sm)
                            }
                        }
                        .padding(Spacing.md)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .workspacePaneBackground()
    }

    private var detailColumn: some View {
        Group {
            if let selectedTopic {
                Stage3MacOSXianxiaDetailColumn(topic: selectedTopic, repository: viewModel.repository)
                    .id(selectedTopic.id)
            } else {
                Stage3MacOSWorkspacePlaceholder(
                    icon: "rectangle.stack",
                    title: "从左侧打开一个话题",
                    message: "桌面端保留原始话题卡片内容，但把正文与元信息拆成并排工作区，避免在单列里来回进出。"
                )
            }
        }
        .workspacePaneBackground()
    }

    private var inspectorColumn: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Stage3MacOSInspectorChip(
                    title: "Workspace",
                    value: "list-detail-inspector"
                )

                if let selectedTopic {
                    Stage3MacOSInspectorSection(
                        title: "当前话题",
                        subtitle: selectedTopic.title
                    ) {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Stage3MacOSMetadataRow(label: "topic_id", value: selectedTopic.topicId)
                            Stage3MacOSMetadataRow(label: "status", value: selectedTopic.status)
                            Stage3MacOSMetadataRow(label: "topic_path", value: selectedTopic.topicPath)
                            Stage3MacOSMetadataRow(label: "sender_tail", value: selectedTopic.senderTailDisplay)
                            Stage3MacOSMetadataRow(label: "消息数", value: "\(selectedTopic.messageCount)")
                            Stage3MacOSMetadataRow(label: "分片数", value: "\(selectedTopic.shardCount)")
                            Stage3MacOSMetadataRow(label: "updated_at", value: selectedTopic.updatedAt.stage3RelativeTimestamp)
                        }
                    }

                    Stage3MacOSInspectorSection(
                        title: "话题摘要",
                        subtitle: "与 iOS 详情页保持同样正文密度"
                    ) {
                        Text(selectedTopic.summaryText)
                            .font(.spareBody)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Stage3MacOSInspectorSection(
                        title: "当前状态",
                        subtitle: "未选中话题"
                    ) {
                        Text("目录与详情已经拆成三栏，但只会在你显式选择话题后加载右侧元信息。")
                            .font(.spareCaption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Stage3MacOSInspectorSection(
                    title: "Feed 状态",
                    subtitle: "\(max(viewModel.totalTopicsCount, viewModel.topics.count)) 个话题"
                ) {
                    Stage3MacOSMetadataRow(label: "load_state", value: viewModel.feedState.stage3Label)
                    Stage3MacOSMetadataRow(label: "next_cursor", value: viewModel.nextCursor ?? "none")
                    Stage3MacOSMetadataRow(
                        label: "api_base",
                        value: viewModel.repository.configuration.baseURL.absoluteString
                    )
                }
            }
            .padding(Spacing.md)
        }
        .workspacePaneBackground(tint: Color.spareYellow.opacity(0.05))
    }
}

private struct Stage3MacOSXianxiaDetailColumn: View {
    let topic: XianxiaTopic
    let repository: XianxiaTopicRepository

    @StateObject private var viewModel: SceneTopicViewModel

    init(topic: XianxiaTopic, repository: XianxiaTopicRepository) {
        self.topic = topic
        self.repository = repository
        _viewModel = StateObject(wrappedValue: SceneTopicViewModel(topic: topic, repository: repository))
    }

    var body: some View {
        VStack(spacing: 0) {
            Stage3MacOSWorkspaceColumnHeader(
                title: topic.title,
                subtitle: "正文与 shard 延续 iOS 详情页，只把返回式导航改成桌面常驻详情列。"
            ) {
                Button("刷新详情") {
                    viewModel.refresh()
                }
                .buttonStyle(.bordered)
            }

            Divider()

            Group {
                switch viewModel.loadState {
                case .idle, .loading:
                    ScrollView {
                        Stage3MacOSTopicShardSkeleton()
                            .padding(Spacing.md)
                    }
                case .empty:
                    ScrollView {
                        EmptyStateView(
                            icon: "text.bubble",
                            title: "这个话题暂时没有内容",
                            message: "当前数据源没有返回可展示的原始文字。",
                            actionLabel: "重新拉取",
                            action: { viewModel.refresh() }
                        )
                        .padding(.top, Spacing.xxxl)
                        .padding(.horizontal, Spacing.md)
                    }
                case .error(let message):
                    ScrollView {
                        ErrorStateView(
                            message: message,
                            cached: false,
                            retry: { viewModel.refresh() }
                        )
                        .padding(.top, Spacing.xxxl)
                        .padding(.horizontal, Spacing.md)
                    }
                case .loadedFromCache, .loaded:
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: Spacing.md) {
                            Stage3MacOSInspectorChip(
                                title: "Shard 数量",
                                value: "\(viewModel.shards.count)"
                            )

                            ForEach(viewModel.shards) { shard in
                                TopicShardCardView(shard: shard)
                                    .onAppear {
                                        viewModel.loadMoreIfNeeded(after: shard)
                                    }
                            }

                            if viewModel.isLoadingMore {
                                HStack(spacing: Spacing.sm) {
                                    ProgressView()
                                    Text("继续加载更多内容…")
                                        .font(.spareCaption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(Spacing.md)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .task {
            viewModel.loadIfNeeded()
        }
    }
}

struct Stage3MacOSMessagesWorkspaceView: View {
    @EnvironmentObject private var router: ConversationRouter
    @StateObject private var store = ConversationHubStore()
    @State private var sortMode: ConversationSortMode = .byTime
    @State private var focusedThreadID: String?

    private var activeRoute: MessagesRoute {
        router.currentRoute
    }

    private var focusedThread: ConversationThread? {
        if let context = activeRoute.threadContext {
            return context.thread
        }

        guard let focusedThreadID else { return store.recentContacts.first }
        return store.threads.first(where: { $0.canonicalThreadID == focusedThreadID }) ?? store.recentContacts.first
    }

    private var sortedThreads: [ConversationThread] {
        switch sortMode {
        case .byTime:
            return store.filteredThreads.sorted { $0.lastTimestamp > $1.lastTimestamp }
        case .byUnread:
            return store.filteredThreads.sorted {
                if $0.unreadCount == $1.unreadCount {
                    return $0.lastTimestamp > $1.lastTimestamp
                }
                return $0.unreadCount > $1.unreadCount
            }
        }
    }

    var body: some View {
        HSplitView {
            hubColumn
                .frame(minWidth: 328, idealWidth: 360, maxWidth: 420)

            detailColumn
                .frame(minWidth: 520, idealWidth: 640, maxWidth: .infinity)

            inspectorColumn
                .frame(minWidth: 260, idealWidth: 296, maxWidth: 336)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            store.load()
        }
        .onChange(of: store.threads) { threads in
            guard !threads.isEmpty else {
                focusedThreadID = nil
                return
            }

            guard let focusedThreadID else {
                self.focusedThreadID = threads.first?.canonicalThreadID
                return
            }

            if threads.contains(where: { $0.canonicalThreadID == focusedThreadID }) {
                return
            }

            self.focusedThreadID = threads.first?.canonicalThreadID
        }
        .onChange(of: activeRoute) { route in
            if let context = route.threadContext {
                focusedThreadID = context.canonicalThreadID
            }
        }
    }

    private var hubColumn: some View {
        VStack(spacing: 0) {
            Stage3MacOSWorkspaceColumnHeader(
                title: "消息中心",
                subtitle: "左侧保留 recent contacts + thread 语义，桌面端只把进入与承接拆成 hub workspace。"
            ) {
                Button("刷新消息") {
                    Task { await store.refresh() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.spareYellow)
            }

            Divider()

            VStack(alignment: .leading, spacing: Spacing.md) {
                TextField("搜索联系人或消息", text: $store.searchQuery)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: Spacing.sm) {
                    Menu {
                        Button("全部会话") {
                            store.selectedKind = nil
                        }
                        Button("熟人") {
                            store.selectedKind = .human
                        }
                        Button("四人场") {
                            store.selectedKind = .quadRole
                        }
                        Button("群聊") {
                            store.selectedKind = .group
                        }
                        Button("分身") {
                            store.selectedKind = .agentDirect
                        }
                    } label: {
                        Label(store.selectedKind?.rawValue ?? "全部会话", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    .buttonStyle(.bordered)

                    Picker("排序", selection: $sortMode) {
                        ForEach(ConversationSortMode.allCases) { mode in
                            Text(mode.label)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .font(.spareCaption)
            }
            .padding(Spacing.md)

            Divider()

            Group {
                switch store.loadState {
                case .idle, .loading:
                    List {
                        ForEach(0..<6, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(Color.white)
                                .frame(height: 72)
                                .shimmer()
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                case .error(let message):
                    ScrollView {
                        ErrorStateView(message: message, retry: store.retry)
                            .padding(.top, Spacing.xxxl)
                            .padding(.horizontal, Spacing.md)
                    }
                case .loaded:
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            if !store.recentContacts.isEmpty {
                                VStack(alignment: .leading, spacing: Spacing.sm) {
                                    Text("最近联系人")
                                        .font(.spareCaptionSB)
                                        .foregroundColor(.secondary)

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: Spacing.sm) {
                                            ForEach(store.recentContacts) { thread in
                                                Button {
                                                    openThread(thread)
                                                } label: {
                                                    VStack(spacing: Spacing.xs) {
                                                        AvatarView(name: thread.contactName, size: 44)
                                                        Text(thread.contactName)
                                                            .font(.spareMicro)
                                                            .foregroundColor(.primary)
                                                            .lineLimit(1)
                                                    }
                                                    .padding(.horizontal, Spacing.sm)
                                                    .padding(.vertical, Spacing.sm)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                                                            .fill(Color.white)
                                                    )
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                                                            .stroke(
                                                                focusedThread?.canonicalThreadID == thread.canonicalThreadID
                                                                    ? Color.spareYellow.opacity(0.40)
                                                                    : Color.cardStroke,
                                                                lineWidth: 1
                                                            )
                                                    )
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text("会话线程")
                                    .font(.spareCaptionSB)
                                    .foregroundColor(.secondary)

                                if sortedThreads.isEmpty {
                                    EmptyStateView(
                                        icon: "magnifyingglass",
                                        title: "无匹配结果",
                                        message: "换个关键词或筛选条件试试。"
                                    )
                                    .padding(.top, Spacing.xl)
                                } else {
                                    ForEach(sortedThreads) { thread in
                                        Stage3MacOSMessagesThreadRow(
                                            thread: thread,
                                            isSelected: focusedThread?.canonicalThreadID == thread.canonicalThreadID,
                                            onOpen: { openThread(thread) },
                                            onMarkRead: { store.markRead(threadID: thread.id) },
                                            onPinToggle: { store.pin(threadID: thread.id) }
                                        )
                                    }
                                }
                            }
                        }
                        .padding(Spacing.md)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .workspacePaneBackground()
    }

    private var detailColumn: some View {
        VStack(spacing: 0) {
            Stage3MacOSWorkspaceColumnHeader(
                title: activeRoute.title,
                subtitle: "中栏只负责承接当前 route，线程、面具、关系、记忆等子页与 iOS 使用同一 typed route。"
            )

            Divider()

            Group {
                switch activeRoute {
                case .home:
                    Stage3MacOSMessagesHomePlaceholderView(
                        focusedThread: focusedThread,
                        openFocusedThread: {
                            if let focusedThread {
                                openThread(focusedThread)
                            }
                        }
                    )
                case .thread(let context):
                    ChatThreadView(thread: context.thread)
                case .mask(let context):
                    ContactMaskView(
                        contactID: context.thread.routePrimaryKey,
                        contactName: context.thread.contactName,
                        presentation: .embedded
                    )
                case .relationship(let context):
                    RelationshipGardenView(
                        profile: .routeSeed(for: context.thread),
                        presentation: .embedded
                    )
                case .memory(let context):
                    CrossSessionMemoryView(
                        thread: context.thread,
                        presentation: .embedded
                    )
                case .quadRole(let context):
                    QuadRoleChatView(
                        thread: context.thread,
                        presentation: .embedded
                    )
                case .groupPlay(let context):
                    GroupAgentPlayView(
                        thread: context.thread,
                        presentation: .embedded
                    )
                case .groupVote, .composeDraft:
                    Stage3MacOSMessagesPendingSurfaceView(route: activeRoute)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .workspacePaneBackground()
    }

    private var inspectorColumn: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Stage3MacOSInspectorChip(
                    title: "Workspace",
                    value: "hub-thread-detail"
                )

                Stage3MacOSInspectorSection(
                    title: "当前 route",
                    subtitle: activeRoute.title
                ) {
                    Stage3MacOSMetadataRow(label: "breadcrumb", value: activeRoute.stage3InspectorPath)
                    Stage3MacOSMetadataRow(label: "handoff", value: router.lastHandoff.map(\.id) ?? "none")
                }

                if let focusedThread {
                    Stage3MacOSInspectorSection(
                        title: "线程语义",
                        subtitle: focusedThread.contactName
                    ) {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Stage3MacOSMetadataRow(label: "locator", value: focusedThread.locator.legacyThreadRoute)
                            Stage3MacOSMetadataRow(label: "kind", value: focusedThread.kind.rawValue)
                            Stage3MacOSMetadataRow(label: "unread", value: "\(focusedThread.unreadCount)")
                            Stage3MacOSMetadataRow(label: "temperature", value: focusedThread.relationTemperature.label)
                            Stage3MacOSMetadataRow(label: "mask", value: focusedThread.activeMaskName ?? "默认")
                            Stage3MacOSMetadataRow(label: "online", value: focusedThread.isOnline ? "yes" : "no")
                        }
                    }

                    Stage3MacOSInspectorSection(
                        title: "子页入口",
                        subtitle: "与 iOS 保持同一 typed route"
                    ) {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Stage3MacOSInspectorActionButton(title: "打开线程", icon: "message") {
                                router.openChat(focusedThread)
                            }
                            Stage3MacOSInspectorActionButton(title: "面具设置", icon: "theatermasks.fill") {
                                router.openMask(for: focusedThread)
                            }
                            Stage3MacOSInspectorActionButton(title: "关系养成", icon: "heart.circle.fill") {
                                router.openRelationship(for: focusedThread)
                            }
                            Stage3MacOSInspectorActionButton(title: "跨会话记忆", icon: "brain") {
                                router.openMemory(for: focusedThread)
                            }
                            Stage3MacOSInspectorActionButton(title: "四人场", icon: "person.3.fill") {
                                router.openQuadRole(for: focusedThread)
                            }
                            if focusedThread.kind == .group {
                                Stage3MacOSInspectorActionButton(title: "群聊玩法", icon: "person.2.circle.fill") {
                                    router.openGroupPlay(for: focusedThread)
                                }
                            }
                        }
                    }
                } else {
                    Stage3MacOSInspectorSection(
                        title: "线程语义",
                        subtitle: "暂无焦点线程"
                    ) {
                        Text("先从左侧消息中心选择一个线程，右栏才会固定显示 locator、上下文卡和子页入口。")
                            .font(.spareCaption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(Spacing.md)
        }
        .workspacePaneBackground(tint: Color.spareYellow.opacity(0.05))
    }

    private func openThread(_ thread: ConversationThread) {
        focusedThreadID = thread.canonicalThreadID
        router.openChat(thread)
    }
}

private struct Stage3MacOSMessagesThreadRow: View {
    let thread: ConversationThread
    let isSelected: Bool
    let onOpen: () -> Void
    let onMarkRead: () -> Void
    let onPinToggle: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: Spacing.md) {
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(name: thread.contactName, size: 44)

                    if thread.kind != .human {
                        Image(systemName: thread.kind.stage3Symbol)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.spareYellowInk, in: Circle())
                            .offset(x: 4, y: 4)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: Spacing.xs) {
                        Text(thread.contactName)
                            .font(thread.unreadCount > 0 ? .spareBodySB : .spareBody)
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        if thread.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.spareYellowInk)
                        }
                    }

                    Text(thread.lastMessage)
                        .font(.spareCaption)
                        .foregroundColor(thread.unreadCount > 0 ? .primary : .secondary)
                        .lineLimit(2)

                    HStack(spacing: Spacing.sm) {
                        Label(thread.relationTemperature.label, systemImage: thread.relationTemperature.icon)
                            .font(.spareMicro)
                            .foregroundColor(thread.relationTemperature.color)

                        if let activeMaskName = thread.activeMaskName {
                            Text(activeMaskName)
                                .font(.spareMicro)
                                .foregroundColor(.spareYellowInk)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Color.spareYellow.opacity(0.14), in: Capsule())
                        }
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: Spacing.xs) {
                    Text(thread.lastTimestamp, style: .relative)
                        .font(.spareMicro)
                        .foregroundColor(.secondary)

                    if thread.unreadCount > 0 {
                        Text("\(thread.unreadCount)")
                            .font(.spareMicro)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.emotionNegative, in: Capsule())
                    }
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                    .fill(isSelected ? Color.spareYellow.opacity(0.14) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                    .stroke(isSelected ? Color.spareYellow.opacity(0.28) : Color.cardStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(thread.unreadCount > 0 ? "标记已读" : "保持已读") {
                onMarkRead()
            }
            Button(thread.isPinned ? "取消置顶" : "置顶") {
                onPinToggle()
            }
        }
    }
}

private struct Stage3MacOSMessagesHomePlaceholderView: View {
    let focusedThread: ConversationThread?
    let openFocusedThread: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Stage3MacOSWorkspacePlaceholder(
                icon: "message.badge.circle",
                title: "从左侧消息中心打开一个线程",
                message: "桌面端把 hub、当前 route 和线程上下文并排摆开，但 `home -> thread -> subpage` 的 route 仍与 iOS 完全一致。"
            )

            if let focusedThread {
                Stage3MacOSInspectorSection(
                    title: "推荐继续",
                    subtitle: focusedThread.contactName
                ) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(focusedThread.lastMessage)
                            .font(.spareBody)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button("打开这个线程") {
                            openFocusedThread()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.spareYellow)
                    }
                }
                .padding(.horizontal, Spacing.xl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, Spacing.xl)
    }
}

private struct Stage3MacOSMessagesPendingSurfaceView: View {
    let route: MessagesRoute

    var body: some View {
        Stage3MacOSWorkspacePlaceholder(
            icon: route.stage3PendingIcon,
            title: route.title,
            message: route.stage3PendingMessage
        )
    }
}

struct Stage3MacOSMastersWorkspaceView: View {
    @StateObject private var store = MasterExperienceStore()
    @State private var selectedMasterID: String?

    private var selectedMaster: MasterProfile? {
        if let conversationMasterID = store.conversation?.masterID,
           let profile = store.master(withID: conversationMasterID) {
            return profile
        }

        if let selectedMasterID,
           let profile = store.master(withID: selectedMasterID) {
            return profile
        }

        return store.visibleDirectoryMasters.first ?? store.directoryMasters.first
    }

    var body: some View {
        HSplitView {
            directoryColumn
                .frame(minWidth: 340, idealWidth: 372, maxWidth: 440)

            sessionColumn
                .frame(minWidth: 520, idealWidth: 640, maxWidth: .infinity)

            inspectorColumn
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 360)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            store.loadIfNeeded()
        }
        .onChange(of: store.directoryMasters.map(\.id)) { ids in
            guard !ids.isEmpty else {
                selectedMasterID = nil
                return
            }

            guard let selectedMasterID else {
                self.selectedMasterID = ids.first
                return
            }

            if ids.contains(selectedMasterID) {
                return
            }

            self.selectedMasterID = ids.first
        }
        .onChange(of: store.conversation?.masterID) { masterID in
            if let masterID {
                selectedMasterID = masterID
            }
        }
    }

    private var directoryColumn: some View {
        VStack(spacing: 0) {
            Stage3MacOSWorkspaceColumnHeader(
                title: "大师目录",
                subtitle: "左侧保留目录搜索、domain 过滤与卡片浏览，桌面端不再把会话挤成单列 push。"
            ) {
                Button("刷新目录") {
                    Task { await store.refreshCatalog() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.spareYellow)
            }

            Divider()

            VStack(alignment: .leading, spacing: Spacing.md) {
                TextField("搜索大师或关键词", text: $store.query)
                    .textFieldStyle(.roundedBorder)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        Stage3MacOSFilterChip(
                            title: "全部领域",
                            isSelected: store.selectedDomainID == nil
                        ) {
                            store.selectedDomainID = nil
                        }

                        ForEach(store.domains) { domain in
                            Stage3MacOSFilterChip(
                                title: domain.title,
                                isSelected: store.selectedDomainID == domain.id
                            ) {
                                store.selectedDomainID = domain.id
                            }
                        }
                    }
                }
            }
            .padding(Spacing.md)

            Divider()

            Group {
                if store.isLoading {
                    ScrollView {
                        VStack(spacing: Spacing.md) {
                            ForEach(0..<4, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                                    .fill(Color.white)
                                    .frame(height: 168)
                                    .shimmer()
                            }
                        }
                        .padding(Spacing.md)
                    }
                } else if let fatalErrorMessage = store.fatalErrorMessage {
                    ScrollView {
                        ErrorStateView(
                            message: fatalErrorMessage,
                            retry: { Task { await store.refreshCatalog() } }
                        )
                        .padding(.top, Spacing.xxxl)
                        .padding(.horizontal, Spacing.md)
                    }
                } else if store.directoryMasters.isEmpty {
                    ScrollView {
                        EmptyStateView(
                            icon: "person.crop.rectangle.stack",
                            title: "暂时没有可闲聊的大师",
                            message: "试试清空筛选，或者等本地资源目录更新后再来。",
                            actionLabel: "清空筛选",
                            action: {
                                store.query = ""
                                store.selectedDomainID = nil
                            }
                        )
                        .padding(.top, Spacing.xxxl)
                        .padding(.horizontal, Spacing.md)
                    }
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: Spacing.md) {
                            ForEach(store.visibleDirectoryMasters) { profile in
                                Stage3MacOSMasterDirectoryCard(
                                    profile: profile,
                                    isSelected: selectedMaster?.id == profile.id,
                                    onSelect: {
                                        withAnimation(.spareSpring) {
                                            selectedMasterID = profile.id
                                        }
                                    },
                                    onOpenConversation: {
                                        selectedMasterID = profile.id
                                        store.openConversation(for: profile)
                                    }
                                )
                                .onAppear {
                                    store.loadNextDirectoryBatchIfNeeded(after: profile)
                                }
                            }

                            if store.hasMoreDirectoryMastersToLoad {
                                HStack(spacing: Spacing.sm) {
                                    ProgressView()
                                    Text("继续加载更多大师…")
                                        .font(.spareCaption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(Spacing.md)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .workspacePaneBackground()
    }

    private var sessionColumn: some View {
        VStack(spacing: 0) {
            Stage3MacOSWorkspaceColumnHeader(
                title: store.conversation == nil ? "会话区" : "会话进行中",
                subtitle: "中栏常驻大师会话；目录与近期 session 不再通过全屏 cover 来回切换。"
            )

            Divider()

            Group {
                if let conversation = store.conversation,
                   store.master(withID: conversation.masterID) != nil {
                    MasterConversationView(store: store) {
                        store.conversation = nil
                    }
                } else if let selectedMaster {
                    Stage3MacOSMasterSessionPlaceholder(
                        profile: selectedMaster,
                        openConversation: {
                            store.openConversation(for: selectedMaster)
                        }
                    )
                } else {
                    Stage3MacOSWorkspacePlaceholder(
                        icon: "book.pages",
                        title: "从左侧目录选择一位大师",
                        message: "桌面端把目录、会话和辅助信息拆开承接，但不会改变你在 iOS 上看到的角色信息、模板和一对一闲聊语义。"
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .workspacePaneBackground()
    }

    private var inspectorColumn: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Stage3MacOSInspectorChip(
                    title: "Workspace",
                    value: "directory-session-inspector"
                )

                Stage3MacOSInspectorSection(
                    title: "目录状态",
                    subtitle: store.catalogSourceMode.title
                ) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(store.catalogSourceMode.subtitle)
                            .font(.spareCaption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Stage3MacOSMetadataRow(label: "access_policy", value: store.catalogAccessPolicy.title)
                        Stage3MacOSMetadataRow(label: "mapping", value: store.resourceMappingSummary)
                        if let catalogCoverage = store.catalogCoverage {
                            Stage3MacOSMetadataRow(label: "coverage", value: catalogCoverage.indexCoverageSummary)
                            Stage3MacOSMetadataRow(label: "manifest", value: catalogCoverage.directoryManifestName)
                        }
                    }
                }

                if let selectedMaster {
                    Stage3MacOSInspectorSection(
                        title: "当前大师",
                        subtitle: selectedMaster.displayName
                    ) {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Stage3MacOSMetadataRow(label: "title", value: selectedMaster.title)
                            Stage3MacOSMetadataRow(label: "domain", value: selectedMaster.domainTitle)
                            Stage3MacOSMetadataRow(label: "voice", value: selectedMaster.voice)
                            Stage3MacOSMetadataRow(label: "style", value: selectedMaster.adviceStyle)

                            if !selectedMaster.expertiseTags.isEmpty {
                                Stage3MacOSTagCloud(tags: selectedMaster.expertiseTags)
                            }

                            if !selectedMaster.boundaries.isEmpty {
                                Text("边界")
                                    .font(.spareCaptionSB)
                                    .foregroundColor(.secondary)
                                ForEach(selectedMaster.boundaries, id: \.self) { boundary in
                                    Text("• \(boundary)")
                                        .font(.spareCaption)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }

                Stage3MacOSInspectorSection(
                    title: "近期会话",
                    subtitle: "\(store.prioritizedSessions.count) 条 session"
                ) {
                    if store.prioritizedSessions.isEmpty {
                        Text("当前还没有可恢复的会话记录。")
                            .font(.spareCaption)
                            .foregroundColor(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            ForEach(store.prioritizedSessions) { session in
                                Stage3MacOSMasterRecentSessionRow(
                                    session: session,
                                    restore: {
                                        store.restoreSession(session)
                                    },
                                    togglePin: {
                                        store.togglePinned(session)
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .padding(Spacing.md)
        }
        .workspacePaneBackground(tint: Color.spareYellow.opacity(0.05))
    }
}

private struct Stage3MacOSMasterDirectoryCard: View {
    let profile: MasterProfile
    let isSelected: Bool
    let onSelect: () -> Void
    let onOpenConversation: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ZStack(alignment: .bottomLeading) {
                Stage3MacOSMasterArtworkView(profile: profile)
                    .frame(height: 168)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous))

                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.74)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous))

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(profile.displayName)
                        .font(.spareTitle3)
                        .foregroundColor(.white)
                    Text(profile.title)
                        .font(.spareCaptionSB)
                        .foregroundColor(.white.opacity(0.82))
                    Text(profile.promptPreview.isEmpty ? profile.tagline : profile.promptPreview)
                        .font(.spareCaption)
                        .foregroundColor(.white.opacity(0.90))
                        .lineLimit(3)
                }
                .padding(Spacing.md)
            }

            HStack(alignment: .top, spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(profile.domainTitle)
                        .font(.spareCaptionSB)
                        .foregroundColor(.spareYellowInk)
                    Text(profile.tagline)
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }

                Spacer(minLength: 0)

                Button("继续聊") {
                    onOpenConversation()
                }
                .buttonStyle(.borderedProminent)
                .tint(.spareYellow)
                .controlSize(.small)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                .stroke(isSelected ? Color.spareYellow.opacity(0.36) : Color.cardStroke, lineWidth: 1)
        )
        .cardShadow()
        .contentShape(RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous))
        .onTapGesture {
            onSelect()
        }
    }
}

private struct Stage3MacOSMasterArtworkView: View {
    let profile: MasterProfile

    var body: some View {
        Group {
            if let image = Stage3MacOSImageLoader.image(at: profile.imageSet.portraitPath) {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: profile.palette.nonEmpty ?? [Color.spareYellow.opacity(0.36), Color.white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
                    AvatarView(
                        name: profile.displayName,
                        size: 72,
                        avatarURL: profile.portraitURL ?? profile.avatarURL
                    )
                )
            }
        }
    }
}

private struct Stage3MacOSMasterSessionPlaceholder: View {
    let profile: MasterProfile
    let openConversation: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                HStack(spacing: Spacing.lg) {
                    AvatarView(
                        name: profile.displayName,
                        size: 72,
                        avatarURL: profile.portraitURL ?? profile.avatarURL
                    )

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(profile.displayName)
                            .font(.spareTitle2)
                            .foregroundColor(.primary)
                        Text(profile.title)
                            .font(.spareBodySB)
                            .foregroundColor(.spareYellowInk)
                        Text(profile.headline)
                            .font(.spareBody)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                Stage3MacOSInspectorSection(
                    title: "开场文案",
                    subtitle: "与 iOS 一致"
                ) {
                    Text(profile.openingMessage)
                        .font(.spareBody)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !profile.featuredTemplates.isEmpty {
                    Stage3MacOSInspectorSection(
                        title: "推荐开题模板",
                        subtitle: "\(profile.featuredTemplates.count) 条"
                    ) {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            ForEach(profile.featuredTemplates) { template in
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    Text(template.title)
                                        .font(.spareCaptionSB)
                                        .foregroundColor(.primary)
                                    Text(template.prompt)
                                        .font(.spareCaption)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.vertical, Spacing.xs)
                            }
                        }
                    }
                }

                Button("打开一对一闲聊") {
                    openConversation()
                }
                .buttonStyle(.borderedProminent)
                .tint(.spareYellow)
            }
            .padding(Spacing.xl)
        }
    }
}

private struct Stage3MacOSMasterRecentSessionRow: View {
    let session: MasterRecentSession
    let restore: () -> Void
    let togglePin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.displayName)
                        .font(.spareBodySB)
                        .foregroundColor(.primary)
                    Text(session.topic)
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Button {
                    togglePin()
                } label: {
                    Image(systemName: session.isPinned ? "pin.fill" : "pin")
                        .foregroundColor(.spareYellowInk)
                }
                .buttonStyle(.plain)
            }

            Text(session.preview)
                .font(.spareCaption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack(spacing: Spacing.sm) {
                Text(session.lastMessageAt)
                    .font(.spareMicro)
                    .foregroundColor(.secondary)

                if session.unreadCount > 0 {
                    Text("\(session.unreadCount) 未读")
                        .font(.spareMicro)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.emotionNegative, in: Capsule())
                }

                Spacer(minLength: 0)

                Button("恢复会话") {
                    restore()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
    }
}

struct Stage3MacOSWorkspaceColumnHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: Trailing

    init(
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(.spareTitle3)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            trailing
        }
        .padding(Spacing.md)
    }
}

struct Stage3MacOSWorkspacePlaceholder: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(.spareYellowInk)

            VStack(spacing: Spacing.sm) {
                Text(title)
                    .font(.spareTitle3)
                    .foregroundColor(.primary)

                Text(message)
                    .font(.spareBody)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.xl)
        .background(
            LinearGradient(
                colors: [
                    Color.spareYellow.opacity(0.10),
                    Color.white,
                    Color.white
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

struct Stage3MacOSInspectorSection<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    init(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(.spareCaptionSB)
                .foregroundColor(.secondary)

            Text(subtitle)
                .font(.spareBodySB)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            content
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
    }
}

struct Stage3MacOSInspectorChip: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(title)
                .font(.spareCaptionSB)
                .foregroundColor(.spareYellowInk)
            Text(value)
                .font(.spareCaption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(Color.spareYellow.opacity(0.12), in: Capsule())
    }
}

struct Stage3MacOSMetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.spareMicro)
                .foregroundColor(.secondary)
            Text(value)
                .font(.spareCaption)
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct Stage3MacOSTopicShardSkeleton: View {
    var body: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                    .fill(Color.white)
                    .frame(height: 96)
                    .shimmer()
            }
        }
    }
}

struct Stage3MacOSInspectorActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

struct Stage3MacOSFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.spareCaption)
                .foregroundColor(isSelected ? .spareYellowInk : .secondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.spareYellow.opacity(0.16) : Color.white)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.spareYellow.opacity(0.30) : Color.cardStroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct Stage3MacOSTagCloud: View {
    let tags: [String]

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(minimum: 72), spacing: Spacing.xs, alignment: .leading),
                GridItem(.flexible(minimum: 72), spacing: Spacing.xs, alignment: .leading)
            ],
            alignment: .leading,
            spacing: Spacing.xs
        ) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.spareMicro)
                    .foregroundColor(.spareYellowInk)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.spareYellow.opacity(0.10), in: Capsule())
            }
        }
    }
}

private enum Stage3MacOSImageLoader {
    static func image(at path: String) -> Image? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let image = NSImage(contentsOfFile: trimmed) else {
            return nil
        }
        return Image(nsImage: image)
    }
}

extension View {
    func workspacePaneBackground(tint: Color = Color.white.opacity(0.92)) -> some View {
        background(
            LinearGradient(
                colors: [
                    tint,
                    Color.white.opacity(0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

private extension XianxiaTopicFeedState {
    var stage3Label: String {
        switch self {
        case .idle:
            return "idle"
        case .loading:
            return "loading"
        case .loaded:
            return "loaded"
        case .loadedFromCache:
            return "loaded_from_cache"
        case .empty:
            return "empty"
        case .error:
            return "error"
        }
    }
}

private extension ConversationKind {
    var stage3Symbol: String {
        switch self {
        case .human:
            return "person.fill"
        case .quadRole:
            return "person.3.fill"
        case .group:
            return "person.2.fill"
        case .agentDirect:
            return "sparkles"
        }
    }
}

private extension MessagesRoute {
    var threadContext: MessagesThreadContext? {
        switch self {
        case .thread(let context),
             .mask(let context),
             .relationship(let context),
             .memory(let context),
             .quadRole(let context),
             .groupPlay(let context):
            return context
        case .groupVote(let context):
            return context.thread
        case .composeDraft(let context):
            return context.recipient
        case .home:
            return nil
        }
    }

    var stage3InspectorPath: String {
        switch self {
        case .home:
            return "messages / home"
        case .thread(let context):
            return "messages / \(context.thread.contactName)"
        case .mask(let context):
            return "messages / \(context.thread.contactName) / mask"
        case .relationship(let context):
            return "messages / \(context.thread.contactName) / relationship"
        case .memory(let context):
            return "messages / \(context.thread.contactName) / memory"
        case .quadRole(let context):
            return "messages / \(context.thread.contactName) / quad-role"
        case .groupPlay(let context):
            return "messages / \(context.thread.contactName) / group-play"
        case .groupVote(let context):
            return "messages / \(context.thread.thread.contactName) / group-vote"
        case .composeDraft(let context):
            return "messages / draft / \(context.draftID)"
        }
    }

    var stage3PendingIcon: String {
        switch self {
        case .groupVote:
            return "checklist.checked"
        case .composeDraft:
            return "square.and.pencil"
        case .home, .thread:
            return "message"
        case .mask:
            return "theatermasks.fill"
        case .relationship:
            return "heart.circle.fill"
        case .memory:
            return "brain"
        case .quadRole:
            return "person.3.fill"
        case .groupPlay:
            return "person.2.circle.fill"
        }
    }

    var stage3PendingMessage: String {
        switch self {
        case .groupVote:
            return "group vote 已有 typed route，但当前仍停留在群玩法总面板，独立投票详情还没拆成 runtime surface。"
        case .composeDraft:
            return "该草稿路由已纳入统一 messages route，但 compose surface 仍未接成独立 runtime。"
        case .home, .thread, .mask, .relationship, .memory, .quadRole, .groupPlay:
            return "该页面没有 pending 状态。"
        }
    }
}

private extension Date? {
    var stage3RelativeTimestamp: String {
        guard let value = self else { return "unknown" }
        return DateFormatter.localizedString(from: value, dateStyle: .medium, timeStyle: .short)
    }
}

private extension Array {
    var nonEmpty: Self? {
        isEmpty ? nil : self
    }
}
