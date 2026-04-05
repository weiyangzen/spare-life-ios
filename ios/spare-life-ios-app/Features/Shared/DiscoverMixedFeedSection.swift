// DiscoverMixedFeedSection.swift
// Spare Life – cross-domain discover section using the unified mixed card pipeline
// Blueprint §7 统一 UI · [UIUX] 卡片混排与排序规则 (line:1151)
// UIUX lane – slot 2

import SwiftUI

// MARK: - Discover Mixed Feed Section

/// A reusable "发现推荐" section that renders cards from multiple domains
/// (summary, person, action, status) in a single mixed waterfall feed.
/// Uses FeedSorter for ordering and FeedKindFilterBar for category filtering.
///
/// Embed this in any tab's ScrollView to add a cross-domain discover strip.
struct DiscoverMixedFeedSection: View {
    let cards: [AnyFeedCard]
    var onCardTap: ((AnyFeedCard) -> Void)? = nil

    @State private var selectedKind: FeedCardKind? = nil

    var body: some View {
        let filtered = filteredCards
        let sorted = FeedSorter.sort(filtered)
        let counts = Dictionary(grouping: cards, by: \.cardKind)
            .mapValues(\.count)

        VStack(alignment: .leading, spacing: Spacing.md) {
            FeedSectionHeader(
                title: "发现推荐",
                subtitle: "来自全域的精选内容"
            )

            FeedKindFilterBar(selectedKind: $selectedKind, counts: counts)

            if sorted.isEmpty {
                EmptyStateView(
                    icon: "sparkles",
                    title: "暂无推荐",
                    message: "试试切换分类看看？"
                )
                .padding(.vertical, Spacing.lg)
            } else {
                GeometryReader { proxy in
                    WaterfallLayout(columns: WaterfallColumns.count(for: proxy.size.width), spacing: Spacing.md) {
                        ForEach(sorted) { card in
                            MixedFeedCardView(card: card) {
                                onCardTap?(card)
                            }
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.92).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }
                    }
                }
                .frame(minHeight: CGFloat(sorted.count / 2 + 1) * 200)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .animation(.spareSpring, value: selectedKind)
    }

    private var filteredCards: [AnyFeedCard] {
        guard let kind = selectedKind else { return cards }
        return cards.filter { $0.cardKind == kind }
    }
}

// MARK: - Demo / Preview Cards

/// Generates sample mixed cards for UIUX preview and design review.
/// FUNC lane will replace these with real repository-backed cards.
enum DiscoverMixedFeedDemo {
    static func sampleCards() -> [AnyFeedCard] {
        let now = Date()
        return [
            .summary(SummaryFeedCard(
                id: "disc-s1", sortPriority: 80, pinnedAt: nil, createdAt: now - 3600,
                title: "周末好去处：3 个适合深度对话的咖啡馆",
                excerpt: "有些空间天然适合慢聊。这三家咖啡馆被分身们选为最佳对话场景。",
                thumbnailSeed: 7, tag: "场景"
            )),
            .person(PersonFeedCard(
                id: "disc-p1", sortPriority: 70, pinnedAt: nil, createdAt: now - 7200,
                personName: "林小语", tagline: "INFP · 喜欢哲学和诗歌",
                traits: ["哲学", "诗歌", "安静", "创意"],
                actionLabel: "发起破冰"
            )),
            .action(ActionFeedCard(
                id: "disc-a1", sortPriority: 90, pinnedAt: now, createdAt: now - 1800,
                headline: "每日闲能任务",
                subtext: "完成 3 次有效对话可获双倍闲能",
                ctaLabel: "去完成", rewardBadge: "+60 闲能"
            )),
            .status(StatusFeedCard(
                id: "disc-st1", sortPriority: 50, pinnedAt: nil, createdAt: now - 5400,
                value: "87", unit: "社交分",
                trend: 0.12, sparkline: [72, 74, 76, 78, 82, 85, 87]
            )),
            .summary(SummaryFeedCard(
                id: "disc-s2", sortPriority: 60, pinnedAt: nil, createdAt: now - 10800,
                title: "AI 记忆如何让陌生人破冰更自然",
                excerpt: "当分身记住了你上次聊过的话题，下一次开场白会更有温度。",
                thumbnailSeed: 22, tag: "洞察"
            )),
            .person(PersonFeedCard(
                id: "disc-p2", sortPriority: 65, pinnedAt: nil, createdAt: now - 14400,
                personName: "张大师", tagline: "职业规划 · 10年经验",
                traits: ["职业", "规划", "指导"],
                actionLabel: "查看详情"
            )),
            .action(ActionFeedCard(
                id: "disc-a2", sortPriority: 55, pinnedAt: nil, createdAt: now - 21600,
                headline: "分身同步训练",
                subtext: "教分身模仿你的说话风格",
                ctaLabel: "开始训练", rewardBadge: nil
            )),
            .status(StatusFeedCard(
                id: "disc-st2", sortPriority: 45, pinnedAt: nil, createdAt: now - 28800,
                value: "72%", unit: "同步度",
                trend: 0.05, sparkline: [60, 63, 65, 68, 70, 71, 72]
            )),
        ]
    }
}
