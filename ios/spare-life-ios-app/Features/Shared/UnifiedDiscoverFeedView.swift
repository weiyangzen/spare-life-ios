// UnifiedDiscoverFeedView.swift
// Spare Life – cross-domain "发现" feed using the unified card system
// Blueprint §7 统一 UI · [UIUX] 4个首页双列瀑布流 (line:1150) + 卡片混排 (line:1151)
// UIUX lane – slot 2
//
// This view exercises the full shared card pipeline end-to-end:
//   FeedCard protocol → AnyFeedCard → FeedSorter → FeedKindFilterBar → MixedFeedCardView → UnifiedWaterfallFeed
// It serves as the "发现 / For You" surface that mixes summary, person, action, and status
// cards from all four domains (咸虾, 大师, 赚闲能, 我的) in a single waterfall feed.

import SwiftUI

// MARK: - Discover Feed Store

@MainActor
final class DiscoverFeedViewModel: ObservableObject {
    @Published private(set) var loadState: FeedLoadState = .idle
    @Published private(set) var allCards: [AnyFeedCard] = []
    @Published var selectedKind: FeedCardKind? = nil

    /// Filtered + sorted cards for display.
    var displayCards: [AnyFeedCard] {
        let filtered: [AnyFeedCard]
        if let kind = selectedKind {
            filtered = allCards.filter { $0.cardKind == kind }
        } else {
            filtered = allCards
        }
        return FeedSorter.sorted(filtered)
    }

    /// Count per kind for the filter bar badges.
    var kindCounts: [FeedCardKind: Int] {
        var out: [FeedCardKind: Int] = [:]
        for card in allCards {
            out[card.cardKind, default: 0] += 1
        }
        return out
    }

    /// The single highest-priority pinned action card, for the top banner.
    var pinnedBannerCard: ActionFeedCard? {
        for card in FeedSorter.sorted(allCards) {
            if case .action(let a) = card, a.pinnedAt != nil {
                return a
            }
        }
        return nil
    }

    func loadIfNeeded() {
        guard case .idle = loadState else { return }
        loadState = .loading
        Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            self.allCards = Self.buildCards()
            self.loadState = .loaded
        }
    }

    func refresh() async {
        try? await Task.sleep(nanoseconds: 400_000_000)
        self.allCards = Self.buildCards()
    }

    func retry() {
        loadState = .idle
        loadIfNeeded()
    }

    // MARK: - Card Factory (production: assembled from repositories)

    private static func buildCards() -> [AnyFeedCard] {
        let now = Date()
        return [
            // --- 咸虾 summaries ---
            .summary(SummaryFeedCard(
                id: "d-sum-1", sortPriority: 70, pinnedAt: nil,
                createdAt: now - 1200,
                title: "龙虾主题餐厅 · 热门观点",
                excerpt: "大家都在讨论新菜品搭配和环境氛围，正向情绪占比 72%。",
                thumbnailSeed: 3, tag: "热门"
            )),
            .summary(SummaryFeedCard(
                id: "d-sum-2", sortPriority: 50, pinnedAt: nil,
                createdAt: now - 7200,
                title: "周末读书会 · AI 讨论",
                excerpt: "围绕「AI 社交的边界」展开了 42 条观点碰撞。",
                thumbnailSeed: 7, tag: nil
            )),
            .summary(SummaryFeedCard(
                id: "d-sum-3", sortPriority: 40, pinnedAt: nil,
                createdAt: now - 14400,
                title: "咖啡馆现场 · 陌生人破冰",
                excerpt: "3 组配对完成了 A2A 分身破冰，平均关系温度升至「升温」。",
                thumbnailSeed: 11, tag: "破冰"
            )),

            // --- 大师 persons ---
            .person(PersonFeedCard(
                id: "d-per-1", sortPriority: 80, pinnedAt: nil,
                createdAt: now - 900,
                personName: "王阳明",
                tagline: "心即理，知行合一",
                traits: ["哲学", "修行", "领导力", "自省"],
                actionLabel: "请教"
            )),
            .person(PersonFeedCard(
                id: "d-per-2", sortPriority: 60, pinnedAt: nil,
                createdAt: now - 5400,
                personName: "芒格",
                tagline: "多元思维模型的践行者",
                traits: ["投资", "理性", "跨学科"],
                actionLabel: "对话"
            )),
            .person(PersonFeedCard(
                id: "d-per-3", sortPriority: 45, pinnedAt: nil,
                createdAt: now - 18000,
                personName: "苏格拉底",
                tagline: "未经审视的人生不值得过",
                traits: ["辩证", "伦理", "提问"],
                actionLabel: "提问"
            )),

            // --- 赚闲能 actions ---
            .action(ActionFeedCard(
                id: "d-act-1", sortPriority: 90,
                pinnedAt: now - 60,
                createdAt: now - 600,
                headline: "技能问答赛道开放",
                subtext: "回答 3 题即可获得 50 闲能奖励",
                ctaLabel: "参与答题",
                rewardBadge: "+50"
            )),
            .action(ActionFeedCard(
                id: "d-act-2", sortPriority: 55, pinnedAt: nil,
                createdAt: now - 3600,
                headline: "新破冰任务",
                subtext: "附近有 2 位分身与你兴趣匹配度 > 80%",
                ctaLabel: "开始破冰",
                rewardBadge: "+30"
            )),
            .action(ActionFeedCard(
                id: "d-act-3", sortPriority: 35, pinnedAt: nil,
                createdAt: now - 21600,
                headline: "情绪擂台：今日辩题",
                subtext: "「效率至上 vs 享受过程」，选边站！",
                ctaLabel: "参战",
                rewardBadge: nil
            )),

            // --- 我的 status ---
            .status(StatusFeedCard(
                id: "d-sta-1", sortPriority: 65, pinnedAt: nil,
                createdAt: now - 300,
                value: "72%", unit: "同步度",
                trend: 0.05,
                sparkline: [0.58, 0.62, 0.65, 0.68, 0.70, 0.71, 0.72]
            )),
            .status(StatusFeedCard(
                id: "d-sta-2", sortPriority: 48, pinnedAt: nil,
                createdAt: now - 10800,
                value: "2,480", unit: "闲能",
                trend: 0.12,
                sparkline: [2100, 2200, 2280, 2350, 2400, 2440, 2480]
            )),
            .status(StatusFeedCard(
                id: "d-sta-3", sortPriority: 30, pinnedAt: nil,
                createdAt: now - 28800,
                value: "87", unit: "社交分",
                trend: -0.02,
                sparkline: [89, 88, 88, 87, 87, 87, 87]
            )),
        ]
    }
}

typealias DiscoverFeedStore = DiscoverFeedViewModel

// MARK: - Shared Feed Layout Shell

private struct SharedFeedLayoutShellMetrics {
    let maxContentWidth: CGFloat?
    let outerHorizontalPadding: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let sectionSpacing: CGFloat
    let panelPadding: CGFloat
    let panelCornerRadius: CGFloat

    static var current: Self {
        #if os(macOS)
        SharedFeedLayoutShellMetrics(
            maxContentWidth: 1180,
            outerHorizontalPadding: Spacing.xl,
            topPadding: Spacing.lg,
            bottomPadding: Spacing.lg,
            sectionSpacing: Spacing.lg,
            panelPadding: Spacing.lg,
            panelCornerRadius: 28
        )
        #else
        SharedFeedLayoutShellMetrics(
            maxContentWidth: nil,
            outerHorizontalPadding: 0,
            topPadding: 0,
            bottomPadding: 0,
            sectionSpacing: 0,
            panelPadding: 0,
            panelCornerRadius: 0
        )
        #endif
    }
}

/// Shared content/state stays in the view model; only the outer workspace shell branches by platform.
private struct SharedFeedLayoutShell<Controls: View, Banner: View, Content: View>: View {
    let showsBanner: Bool
    let controls: Controls
    let banner: Banner
    let content: Content

    private let metrics = SharedFeedLayoutShellMetrics.current

    init(
        showsBanner: Bool,
        @ViewBuilder controls: () -> Controls,
        @ViewBuilder banner: () -> Banner,
        @ViewBuilder content: () -> Content
    ) {
        self.showsBanner = showsBanner
        self.controls = controls()
        self.banner = banner()
        self.content = content()
    }

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: metrics.sectionSpacing) {
                controlsPanel
                contentPanel
            }
            .frame(
                maxWidth: metrics.maxContentWidth ?? .infinity,
                maxHeight: .infinity,
                alignment: .top
            )
            .padding(.horizontal, metrics.outerHorizontalPadding)
            .padding(.top, metrics.topPadding)
            .padding(.bottom, metrics.bottomPadding)
        }
    }

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [
                Color.spareYellow.opacity(0.10),
                Color.white,
                Color.white
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var controlsPanel: some View {
        #if os(macOS)
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .center, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("发现工作区")
                        .font(.spareTitle3)
                        .foregroundColor(.primary)
                    Text("共享推荐逻辑，桌面只改壳层密度与编排。")
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                PillTag(label: "shared VM + desktop shell", color: .spareYellowInk)
            }

            controls

            if showsBanner {
                banner
            }
        }
        .padding(metrics.panelPadding)
        .background(
            RoundedRectangle(cornerRadius: metrics.panelCornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: metrics.panelCornerRadius, style: .continuous)
                .stroke(Color.spareYellow.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 18, y: 10)
        #else
        VStack(spacing: 0) {
            controls

            Divider()

            if showsBanner {
                banner
                    .padding(.top, Spacing.sm)
            }
        }
        #endif
    }

    @ViewBuilder
    private var contentPanel: some View {
        #if os(macOS)
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: metrics.panelCornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: metrics.panelCornerRadius, style: .continuous)
                    .stroke(Color.spareYellow.opacity(0.14), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: metrics.panelCornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 18, y: 12)
        #else
        content
        #endif
    }
}

// MARK: - Discover Feed View

struct UnifiedDiscoverFeedView: View {
    @StateObject private var viewModel = DiscoverFeedViewModel()

    private var showsPinnedBanner: Bool {
        viewModel.selectedKind == nil && viewModel.pinnedBannerCard != nil
    }

    var body: some View {
        NavigationStack {
            SharedFeedLayoutShell(showsBanner: showsPinnedBanner) {
                FeedKindFilterBar(
                    selected: $viewModel.selectedKind,
                    counts: viewModel.kindCounts
                )
            } banner: {
                if let pinned = viewModel.pinnedBannerCard {
                    FeedPinnedBanner(card: pinned)
                }
            } content: {
                UnifiedWaterfallFeed(
                    loadState: viewModel.loadState,
                    cards: viewModel.displayCards,
                    emptyIcon: "rectangle.on.rectangle.slash",
                    emptyTitle: "暂无推荐内容",
                    emptyMessage: "系统正在为你收集跨场景内容，稍后再来看看。",
                    emptyActionLabel: "刷新",
                    emptyAction: { viewModel.retry() },
                    onRefresh: { await viewModel.refresh() },
                    onRetry: { viewModel.retry() }
                ) { card in
                    MixedFeedCardView(card: card)
                }
            }
            .navigationTitle("发现")
            .spareNavigationBarTitleDisplayMode(.large)
            .task { viewModel.loadIfNeeded() }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Discover Feed") {
    UnifiedDiscoverFeedView()
}
#endif
