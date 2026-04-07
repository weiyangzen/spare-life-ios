// XianxiaHomeView.swift
// Spare Life – 闲虾 Stage 1 topic feed

import SwiftUI

struct XianxiaHomeView: View {
    @StateObject private var vm = XianxiaHomeViewModel()
    private let compactSpacing: CGFloat = 8

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.spareYellow.opacity(0.12),
                        Color.white,
                        Color.white
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
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
        HStack {
            Spacer()

            HStack(alignment: .lastTextBaseline, spacing: Spacing.sm) {
                Text("闲虾")
                    .font(.spareTitle2)
                    .foregroundColor(.primary)

                Text("\(max(vm.totalTopicsCount, vm.topics.count))个话题")
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, compactSpacing)
        .padding(.top, Spacing.md)
        .padding(.bottom, compactSpacing)
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
            feedList()
        }
    }

    private func feedList() -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            GeometryReader { geometry in
                WaterfallLayout(
                    columns: WaterfallColumns.count(for: geometry.size.width),
                    spacing: compactSpacing
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
                .padding(.horizontal, compactSpacing)
                .padding(.top, compactSpacing)
            }
            .frame(minHeight: CGFloat(max(vm.topics.count / 2 + 1, 1)) * 160)

            if vm.isLoadingMore {
                ProgressView("加载更多内容…")
                    .font(.spareCaption)
                    .padding(.vertical, Spacing.md)
            }

            Color.clear
                .frame(height: 32)
        }
        .accessibilityIdentifier("xianxia.feed.scrollView")
        .refreshable {
            await vm.refreshFromPullToRefresh()
        }
    }
}

@MainActor
final class XianxiaHomeViewModel: ObservableObject {
    @Published private(set) var feedState: XianxiaTopicFeedState = .idle
    @Published private(set) var topics: [XianxiaTopic] = []
    @Published private(set) var isLoadingMore = false
    @Published private(set) var totalTopicsCount = 0
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
            totalTopicsCount = batch.total
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
            topics = Self.upsertAppend(existing: topics, incoming: batch.items)
            totalTopicsCount = batch.total
            self.nextCursor = batch.nextCursor
            feedState = topics.isEmpty ? .empty : .loaded
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
            totalTopicsCount = snapshot.total ?? snapshot.items.count
            nextCursor = snapshot.nextCursor
            feedState = .loadedFromCache
        } catch {
            if topics.isEmpty {
                feedState = .loading
            }
        }
    }

    private static func upsertAppend(
        existing: [XianxiaTopic],
        incoming: [XianxiaTopic]
    ) -> [XianxiaTopic] {
        var merged = existing
        var indexByID = Dictionary(uniqueKeysWithValues: merged.enumerated().map { ($1.id, $0) })

        for topic in incoming {
            if let index = indexByID[topic.id] {
                merged[index] = topic
            } else {
                indexByID[topic.id] = merged.count
                merged.append(topic)
            }
        }

        return merged
    }
}
