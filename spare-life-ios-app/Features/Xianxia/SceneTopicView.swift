// SceneTopicView.swift
// Spare Life – 咸虾 场景话题页 (scene public discussion layer)
// Blueprint §3.1 功能点1-4: scene topic feed, AI summaries, avatar radar, social intent
// UIUX lane – slot 2

import SwiftUI

// MARK: - SceneTopicView

struct SceneTopicView: View {
    let scene: Scene
    let isFromScan: Bool
    @StateObject private var vm: SceneTopicViewModel
    @State private var showSocialIntent = false
    @State private var showAvatarRadar = false
    @State private var selectedSegment: Segment = .feed
    @State private var showScanBanner = false
    @State private var activeClusterFilter: TopicCluster? = nil
    @Environment(\.dismiss) private var dismiss

    init(scene: Scene, isFromScan: Bool = false) {
        self.scene = scene
        self.isFromScan = isFromScan
        _vm = StateObject(wrappedValue: SceneTopicViewModel(sceneID: scene.id))
    }

    enum Segment: String, CaseIterable, Identifiable {
        case feed     = "大家说什么"
        case avatars  = "活跃分身"
        case hot      = "热点话题"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .feed:    return "bubble.left.and.bubble.right"
            case .avatars: return "person.2.wave.2"
            case .hot:     return "flame"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Custom nav header ─────────────────────────────────
                sceneHeader

                // ── Scan entry banner (auto-dismiss after 3 s) ────────
                if showScanBanner {
                    ScanEntryBanner(sceneName: scene.name, category: scene.category)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, Spacing.xs)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // ── Scene AI summary strip ────────────────────────────
                if case .loaded = vm.feedState, let summary = vm.primarySummary {
                    SceneSummaryBanner(summary: summary)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // ── Segment switcher ──────────────────────────────────
                segmentSwitcher
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.sm)

                Divider()

                // ── Content area ──────────────────────────────────────
                contentArea
            }

            // ── Floating "发起社交" button ────────────────────────────
            floatingSocialButton
                .padding(.bottom, Spacing.xl)
        }
        .navigationBarHidden(true)
        .onAppear {
            vm.loadFeed()
            if isFromScan {
                withAnimation(.spareSpring) { showScanBanner = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(.spareEase) { showScanBanner = false }
                }
            }
        }
        .sheet(isPresented: $showSocialIntent) {
            SceneSocialIntentView(scene: scene)
        }
        .sheet(isPresented: $showAvatarRadar) {
            SceneAvatarRadarView(
                scene: scene,
                avatars: vm.avatarCards,
                isLoading: vm.avatarsLoading
            )
        }
    }

    // MARK: - Scene Header

    private var sceneHeader: some View {
        ZStack {
            // Background gradient based on scene category
            Color.avatarGradient(seed: abs(scene.id.hashValue))
                .opacity(0.15)
                .ignoresSafeArea(edges: .top)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 36, height: 36)
                            .background(Color(.systemBackground).opacity(0.8), in: Circle())
                    }
                    .accessibilityLabel("返回")

                    Spacer()

                    shareButton
                }

                HStack(alignment: .bottom, spacing: Spacing.sm) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: scene.category.icon)
                                .font(.spareMicro)
                                .foregroundColor(.secondary)
                            Text(scene.category.rawValue)
                                .font(.spareMicro)
                                .foregroundColor(.secondary)
                        }

                        Text(scene.name)
                            .font(.spareTitle2)
                            .lineLimit(2)
                    }

                    Spacer()

                    // Participant count badge
                    if scene.participantCount > 0 {
                        VStack(spacing: 2) {
                            Text("\(scene.participantCount)")
                                .font(.spareBodySB)
                            Text("在场")
                                .font(.spareMicro)
                                .foregroundColor(.secondary)
                        }
                        .padding(Spacing.sm)
                        .background(Color(.systemBackground).opacity(0.8), in: RoundedRectangle(cornerRadius: CornerRadius.sm))
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.md)
        }
    }

    private var shareButton: some View {
        Menu {
            Button(action: {}) {
                Label("分享场景码", systemImage: "qrcode")
            }
            Button(action: {}) {
                Label("复制场景链接", systemImage: "link")
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 36, height: 36)
                .background(Color(.systemBackground).opacity(0.8), in: Circle())
        }
    }

    // MARK: - Segment Switcher

    private var segmentSwitcher: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(Segment.allCases) { seg in
                Button {
                    withAnimation(.spareSpring) {
                        selectedSegment = seg
                    }
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: seg.icon)
                            .font(.system(size: 12, weight: .medium))
                        Text(seg.rawValue)
                            .font(.spareCaption)
                    }
                    .foregroundColor(selectedSegment == seg ? .spareDark : .secondary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        Capsule()
                            .fill(selectedSegment == seg ? Color.spareYellow : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        switch vm.feedState {
        case .loading, .idle:
            WaterfallSkeleton(count: 6)
                .transition(.opacity)

        case .empty:
            ScrollView {
                EmptyStateView(
                    icon: "bubble.left.and.bubble.right",
                    title: "这里还很安静",
                    message: "还没有人讨论这个场景。\n成为第一个发起话题的人！",
                    actionLabel: "发起话题",
                    action: { showSocialIntent = true }
                )
                .padding(.top, Spacing.xxxl)
            }

        case .error(let msg):
            ScrollView {
                ErrorStateView(
                    message: msg,
                    cached: false,
                    retry: { vm.loadFeed() }
                )
                .padding(.top, Spacing.xxxl)
            }

        case .loadedFromCache(let items):
            feedScrollView(items: items, showCacheBanner: true)

        case .loaded(let items):
            let segmentItems = vm.items(
                for: selectedSegment,
                from: items,
                clusterFilter: selectedSegment == .hot ? activeClusterFilter : nil
            )
            feedScrollView(items: segmentItems, showCacheBanner: false)
        }
    }

    private func feedScrollView(items: [SceneFeedItem], showCacheBanner: Bool) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                if showCacheBanner {
                    CachedContentBanner()
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, Spacing.sm)
                }

                // Hot segment: show AI cluster overview before card waterfall
                if selectedSegment == .hot {
                    let hotItems = items.filter {
                        if case .hotTake = $0 { return true }
                        if case .summary = $0 { return true }
                        return false
                    }
                    SceneHotOverviewSection(
                        summary: vm.primarySummary,
                        hotTakeCount: hotItems.count,
                        onClusterTap: { cluster in
                            withAnimation(.spareSpring) {
                                activeClusterFilter = (activeClusterFilter?.id == cluster.id) ? nil : cluster
                            }
                        }
                    )
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.sm)
                    .transition(.opacity)

                    // Active cluster filter banner
                    if let cluster = activeClusterFilter {
                        ClusterFilterBanner(cluster: cluster) {
                            withAnimation(.spareSpring) { activeClusterFilter = nil }
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, Spacing.sm)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }

                if items.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "暂无内容",
                        message: "切换到其他分类试试看。"
                    )
                    .padding(.top, Spacing.xxxl)
                } else {
                    WaterfallLayout(columns: 2, spacing: Spacing.md) {
                        ForEach(items) { item in
                            sceneCard(for: item)
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, 100)   // leave room for FAB
                }
            }
        }
        .refreshable {
            await vm.refreshAsync()
        }
    }

    @ViewBuilder
    private func sceneCard(for item: SceneFeedItem) -> some View {
        switch item {
        case .summary(let c):     SceneSummaryCardView(card: c) {}
        case .hotTake(let c):     HotTakeCardView(card: c)
        case .avatarRadar(let c): AvatarRadarCardView(card: c) { showSocialIntent = true }
        case .socialPrompt(let c): SceneSocialPromptCardView(card: c) { showSocialIntent = true }
        }
    }

    // MARK: - Floating Social Button

    private var floatingSocialButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showSocialIntent = true
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .bold))
                Text("发起社交")
                    .font(.spareBodySB)
            }
            .foregroundColor(.spareDark)
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.md)
            .background(Color.spareYellow, in: Capsule())
            .cardShadow(prominent: true)
        }
    }
}

// MARK: - ClusterFilterBanner
// Shown when a specific AI topic cluster is selected for filtering.

private struct ClusterFilterBanner: View {
    let cluster: TopicCluster
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Circle()
                .fill(cluster.sentiment.asBadgeEmotion.color)
                .frame(width: 7, height: 7)
            Text("# \(cluster.label)")
                .font(.spareCaptionSB)
                .foregroundColor(.primary)
                .lineLimit(1)
            Text("·")
                .foregroundColor(.secondary)
            Text("\(cluster.postCount) 条")
                .font(.spareMicro)
                .foregroundColor(.secondary)
            Spacer()
            Button {
                onClear()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(.systemGray3))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            cluster.sentiment.asBadgeEmotion.color.opacity(0.08),
            in: RoundedRectangle(cornerRadius: CornerRadius.sm)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .strokeBorder(cluster.sentiment.asBadgeEmotion.color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - SceneSummaryBanner
// Compact top-of-page AI overview strip

private struct SceneSummaryBanner: View {
    let summary: SceneSummaryCard
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.spareYellow)
                Text("AI 场景摘要")
                    .font(.spareCaptionSB)
                    .foregroundColor(.secondary)
                Spacer()
                EmotionBadge(emotion: summary.emotionLabel.asBadgeEmotion)
            }

            Text(summary.oneLiner)
                .font(.spareBodySB)
                .lineLimit(expanded ? nil : 2)

            if !summary.topicClusters.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.xs) {
                        ForEach(summary.topicClusters.prefix(4)) { cluster in
                            PillTag(
                                label: "\(cluster.label)·\(cluster.postCount)",
                                color: cluster.sentiment.asBadgeEmotion.color
                            )
                        }
                    }
                }
            }

            if summary.topicClusters.count > 1 || summary.oneLiner.count > 60 {
                Button {
                    withAnimation(.spareEase) { expanded.toggle() }
                } label: {
                    Text(expanded ? "收起" : "查看更多")
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(Spacing.md)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
        .cardShadow()
    }
}

// MARK: - CachedContentBanner

private struct CachedContentBanner: View {
    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(.emotionNeutral)
            Text("已显示缓存内容，网络恢复后将自动刷新")
                .font(.spareCaption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(Spacing.md)
        .background(Color(.systemYellow).opacity(0.10), in: RoundedRectangle(cornerRadius: CornerRadius.sm))
    }
}

// MARK: - SceneTopicViewModel

@MainActor
final class SceneTopicViewModel: ObservableObject {
    let sceneID: String
    @Published var feedState: SceneFeedState = .idle
    @Published var avatarCards: [SceneAvatarCard] = []
    @Published var primarySummary: SceneSummaryCard? = nil

    init(sceneID: String) {
        self.sceneID = sceneID
    }

    /// True while feed is loading (avatar data has not yet arrived).
    var avatarsLoading: Bool {
        if case .loading = feedState { return true }
        if case .idle    = feedState { return true }
        return false
    }

    func loadFeed() {
        guard case .idle = feedState else { return }
        feedState = .loading
        // FUNC lane will inject a real SceneRepository call here.
        // Present empty state so the full UI path is exercised.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            self?.feedState = .empty
        }
    }

    func refreshAsync() async {
        feedState = .loading
        try? await Task.sleep(nanoseconds: 700_000_000)
        feedState = .empty
    }

    /// Filters feed items for the chosen segment tab.
    /// When `clusterFilter` is non-nil, further filters hot-take items by matching cluster label.
    func items(
        for segment: SceneTopicView.Segment,
        from all: [SceneFeedItem],
        clusterFilter: TopicCluster? = nil
    ) -> [SceneFeedItem] {
        switch segment {
        case .feed:
            return all
        case .avatars:
            return all.filter { if case .avatarRadar = $0 { return true }; return false }
        case .hot:
            let hotItems = all.filter { if case .hotTake = $0 { return true }; return false }
            guard let cluster = clusterFilter else { return hotItems }
            return hotItems.filter { item in
                guard case .hotTake(let card) = item else { return false }
                return card.tags.contains(cluster.label) || card.emotionLabel == cluster.sentiment
            }
        }
    }
}
