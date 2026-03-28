// XianxiaHomeView.swift
// Spare Life – 闲虾 Stage 1 topic feed

import SwiftUI

struct XianxiaHomeView: View {
    @StateObject private var vm = XianxiaHomeViewModel()
    @StateObject private var scrollState = WaterfallScrollState()

    private static let feedTopAnchor = "xianxia_topic_feed_top"

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                    Divider()
                    feedBody
                }
            }
            .spareNavigationBarHidden(true)
            .navigationDestination(isPresented: Binding(
                get: { vm.activeTopic != nil },
                set: { if !$0 { vm.activeTopic = nil } }
            )) {
                if let topic = vm.activeTopic {
                    SceneTopicView(topic: topic, repository: vm.repository)
                }
            }
            .task {
                vm.loadIfNeeded()
            }
        }
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("闲虾")
                        .font(.spareTitle1)
                        .foregroundColor(.primary)

                    Text("Stage 1 首页只保留 topic feed。")
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    vm.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 40, height: 40)
                        .background(Color(.secondarySystemGroupedBackground), in: Circle())
                }
                .accessibilityLabel("刷新话题流")
                .accessibilityIdentifier("xianxia.feed.refresh")
            }

            HStack(spacing: Spacing.sm) {
                Image(systemName: "tray.full")
                    .foregroundColor(.secondary)
                Text("统一 topic 数据源 · 双列瀑布流 · 本地缓存回退")
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.md)
    }

    @ViewBuilder
    private var feedBody: some View {
        switch vm.feedState {
        case .idle, .loading:
            WaterfallSkeleton(count: 8)
                .transition(.opacity)

        case .empty:
            ScrollView {
                EmptyStateView(
                    icon: "tray",
                    title: "还没有可浏览的话题",
                    message: "当前 topic 数据源没有返回内容，稍后下拉刷新再试。",
                    actionLabel: "重新拉取",
                    action: { vm.refresh() }
                )
                .padding(.top, Spacing.xxxl)
            }

        case .error(let message):
            ScrollView {
                ErrorStateView(
                    message: message,
                    cached: false,
                    retry: { vm.refresh() }
                )
                .padding(.top, Spacing.xxxl)
            }

        case .loadedFromCache, .loaded:
            feedList(showCacheBanner: vm.feedState == .loadedFromCache)
        }
    }

    private func feedList(showCacheBanner: Bool) -> some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: XianxiaScrollOffsetKey.self,
                                value: geometry.frame(in: .named("xianxiaTopicFeed")).minY
                            )
                        }
                        .frame(height: 0)
                        .id(Self.feedTopAnchor)

                        if showCacheBanner {
                            TopicFeedCacheBanner(
                                text: "已复用本地 topics 缓存，网络恢复后会自动刷新。"
                            )
                            .padding(.horizontal, Spacing.lg)
                            .padding(.top, Spacing.sm)
                        }

                        FeedSectionHeader(
                            title: "Topic Feed",
                            subtitle: "\(vm.topics.count) 个话题",
                            trailingLabel: vm.nextCursor == nil ? "已到底部" : "持续分页"
                        )
                        .padding(.top, Spacing.md)
                        .padding(.bottom, Spacing.xs)

                        GeometryReader { geometry in
                            WaterfallLayout(
                                columns: WaterfallColumns.count(for: geometry.size.width),
                                spacing: Spacing.md
                            ) {
                                ForEach(vm.topics) { topic in
                                    TopicFeedCardView(topic: topic) {
                                        vm.open(topic)
                                    }
                                    .onAppear {
                                        vm.loadMoreIfNeeded(after: topic)
                                    }
                                }
                            }
                            .padding(.horizontal, Spacing.lg)
                            .padding(.top, Spacing.md)
                        }
                        .frame(minHeight: CGFloat(max(vm.topics.count / 2 + 1, 1)) * 216)

                        if vm.isLoadingMore {
                            ProgressView("加载更多 topics…")
                                .font(.spareCaption)
                                .padding(.vertical, Spacing.xl)
                        }

                        Color.clear
                            .frame(height: 96)
                    }
                }
                .accessibilityIdentifier("xianxia.feed.scrollView")
                .coordinateSpace(name: "xianxiaTopicFeed")
                .onPreferenceChange(XianxiaScrollOffsetKey.self) { offset in
                    scrollState.offsetY = offset
                    scrollState.isAtTop = offset > -40
                }
                .refreshable {
                    await vm.refreshFromPullToRefresh()
                }

                if !scrollState.isAtTop {
                    ScrollToTopButton(isVisible: true) {
                        withAnimation(.spareSpring) {
                            proxy.scrollTo(Self.feedTopAnchor, anchor: .top)
                        }
                    }
                    .padding(.trailing, Spacing.lg)
                    .padding(.bottom, Spacing.xl)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spareSpring, value: scrollState.isAtTop)
        }
    }
}

private struct TopicFeedCacheBanner: View {
    let text: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "externaldrive.badge.checkmark")
                .foregroundColor(.emotionNeutral)
            Text(text)
                .font(.spareCaption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(Spacing.md)
        .background(Color(.systemYellow).opacity(0.10), in: RoundedRectangle(cornerRadius: CornerRadius.sm))
        .accessibilityIdentifier("xianxia.feed.cacheBanner")
    }
}

private struct XianxiaScrollOffsetKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

@MainActor
final class XianxiaHomeViewModel: ObservableObject {
    @Published private(set) var feedState: XianxiaTopicFeedState = .idle
    @Published private(set) var topics: [XianxiaTopic] = []
    @Published private(set) var isLoadingMore = false
    @Published var activeTopic: XianxiaTopic? = nil

    let repository: XianxiaTopicRepository
    private(set) var nextCursor: String?
    private var hasStartedInitialLoad = false

    init(repository: XianxiaTopicRepository = XianxiaTopicRepository()) {
        self.repository = repository
    }

    func loadIfNeeded() {
        guard !hasStartedInitialLoad else { return }
        hasStartedInitialLoad = true
        Task {
            await loadInitial()
        }
    }

    func refresh() {
        Task {
            await loadInitial(forceRefresh: true)
        }
    }

    func refreshFromPullToRefresh() async {
        await loadInitial(forceRefresh: true)
    }

    func loadInitial(forceRefresh: Bool = false) async {
        if !forceRefresh {
            await hydrateFeedFromCacheIfPresent()
        } else if topics.isEmpty {
            feedState = .loading
        }

        do {
            let batch = try await repository.fetchTopics(cursor: nil)
            topics = batch.items
            nextCursor = batch.nextCursor
            feedState = batch.items.isEmpty ? .empty : .loaded
        } catch {
            if !topics.isEmpty {
                feedState = .loadedFromCache
                return
            }

            await hydrateFeedFromCacheIfPresent()
            if topics.isEmpty {
                feedState = .error(error.xianxiaUserFacingMessage)
            } else {
                feedState = .loadedFromCache
            }
        }
    }

    func loadMoreIfNeeded(after topic: XianxiaTopic) {
        guard shouldPrefetch(after: topic) else { return }
        Task {
            await loadMore()
        }
    }

    func open(_ topic: XianxiaTopic) {
        activeTopic = topic
    }

    func loadMore() async {
        guard let nextCursor, !nextCursor.isEmpty else { return }
        guard !isLoadingMore else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let batch = try await repository.fetchTopics(cursor: nextCursor)
            topics = batch.items
            self.nextCursor = batch.nextCursor
            feedState = batch.items.isEmpty ? .empty : .loaded
        } catch {
            if topics.isEmpty {
                feedState = .error(error.xianxiaUserFacingMessage)
            } else {
                feedState = .loadedFromCache
            }
        }
    }

    private func shouldPrefetch(after topic: XianxiaTopic) -> Bool {
        guard let nextCursor, !nextCursor.isEmpty else { return false }
        let threshold = Set(topics.suffix(4).map(\.id))
        return threshold.contains(topic.id)
    }

    private func hydrateFeedFromCacheIfPresent() async {
        do {
            guard let snapshot = try await repository.cachedTopics(), !snapshot.items.isEmpty else {
                if topics.isEmpty {
                    feedState = .loading
                }
                return
            }

            topics = snapshot.items
            nextCursor = snapshot.nextCursor
            feedState = .loadedFromCache
        } catch {
            if topics.isEmpty {
                feedState = .loading
            }
        }
    }
}
