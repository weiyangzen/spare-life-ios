// EarnSocialHomeView.swift
// Spare Life – 赚闲能 A2A home and secondary surfaces
// Blueprint §3.3 功能点 1-7
// UIUX lane – slot 2

import SwiftUI

struct EarnSocialHomeView: View {
    @StateObject private var store = EarnSocialExperienceStore()

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.95, blue: 0.90),
                        Color(red: 0.97, green: 0.98, blue: 1.00),
                        Color(.systemGroupedBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: Spacing.lg) {
                            heroCard

                            laneChipStrip

                            quickFilterStrip

                            feedBody
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, Spacing.xxxl)
                    }
                    .refreshable {
                        await store.refresh()
                    }
                }
            }
            .navigationBarHidden(true)
            .task {
                store.loadIfNeeded()
            }
            .sheet(item: $store.activeSheet) { sheet in
                sheetView(for: sheet)
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var topBar: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("赚闲能")
                    .font(.spareTitle1)

                Text("六条 A2A 赛道混排成一条能逛、能赚、能破冰的陌生社交主战场。")
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                store.openWallet()
            } label: {
                VStack(alignment: .trailing, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.circle.fill")
                            .foregroundColor(.spareYellow)
                        Text("\(store.wallet.balance)")
                            .font(.spareTitle3)
                            .foregroundColor(.primary)
                    }

                    Text("看账本")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(Color.white.opacity(0.84), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .stroke(Color.cardStroke, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.sm)
    }

    private var heroCard: some View {
        let lane = store.selectedLane
        let laneChip = store.selectedLaneChip
        let laneTrend = store.selectedLaneTrend

        return VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: lane.symbol)
                            .foregroundColor(lane.accentColor)
                        Text(lane.title)
                            .font(.spareTitle2)
                    }

                    Text(lane.summary)
                        .font(.spareBody)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("今日可赚")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                    Text("+\(store.wallet.todayEarnable)")
                        .font(.spareTitle3)
                        .foregroundColor(lane.accentColor)
                }
            }

            HStack(spacing: Spacing.sm) {
                EarnMetricCapsule(
                    title: "闲能余额",
                    value: "\(store.wallet.balance)",
                    footnote: "冻结 \(store.wallet.frozenBalance)",
                    tint: .spareYellow
                )
                EarnMetricCapsule(
                    title: "赛道热度",
                    value: laneChip.map { String(format: "%.1f", $0.heatScore) } ?? "--",
                    footnote: "\(laneChip?.openIntentCount ?? 0) 条机会",
                    tint: lane.accentColor
                )
                EarnMetricCapsule(
                    title: "奖励",
                    value: "+\(laneChip?.rewardAmount ?? 0)",
                    footnote: laneTrend?.eventTitle ?? "热点任务",
                    tint: .emotionPositive
                )
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("为什么这条赛道值得刷")
                    .font(.spareCaptionSB)
                    .foregroundColor(.secondary)

                Text(lane.savedSteps)
                    .font(.spareBodySB)
                    .foregroundColor(.primary)

                if let laneTrend {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text(laneTrend.eventTitle)
                            .font(.spareCaptionSB)
                        Text("· \(laneTrend.eventSummary)")
                            .font(.spareCaption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            VStack(spacing: Spacing.sm) {
                Button {
                    store.openMarket()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("在 \(lane.title) 发一个意图")
                                .font(.spareTitle3)
                                .foregroundColor(.spareDark)
                            Text("让分身先筛掉不值得真人投入的那部分沟通")
                                .font(.spareCaptionSB)
                                .foregroundColor(.spareDark.opacity(0.75))
                        }

                        Spacer()

                        Image(systemName: "arrow.up.right.circle.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.spareDark)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.xl)
                            .fill(Color.spareYellow)
                    )
                }
                .buttonStyle(.plain)

                HStack(spacing: Spacing.sm) {
                    SecondaryActionButton(
                        title: "看趋势热点",
                        subtitle: "探索奖励",
                        symbol: "chart.bar.fill",
                        tint: lane.accentColor
                    ) {
                        store.openTrends()
                    }

                    SecondaryActionButton(
                        title: "围观竞技场",
                        subtitle: "赢闲能",
                        symbol: "figure.boxing",
                        tint: .emotionSplit
                    ) {
                        store.openArena()
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .fill(Color.white.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .stroke(lane.accentColor.opacity(0.18), lineWidth: 1)
        )
        .cardShadow(prominent: true)
    }

    private var laneChipStrip: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("六条赛道入口")
                .font(.spareCaptionSB)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(store.laneChips) { chip in
                        EarnLaneChipButton(
                            chip: chip,
                            isSelected: chip.lane == store.selectedLane
                        ) {
                            withAnimation(.spareSpring) {
                                store.selectLane(chip.lane)
                            }
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    private var quickFilterStrip: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("快捷筛选")
                    .font(.spareCaptionSB)
                    .foregroundColor(.secondary)

                Spacer()

                Text(store.lastRefreshAt, style: .time)
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(store.quickFilters) { filter in
                        FilterButton(
                            filter: filter,
                            isSelected: filter == store.selectedFilter
                        ) {
                            UISelectionFeedbackGenerator().selectionChanged()
                            withAnimation(.spareFast) {
                                store.selectQuickFilter(filter)
                            }
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    @ViewBuilder
    private var feedBody: some View {
        switch store.homeState {
        case .idle, .loading:
            VStack(spacing: Spacing.md) {
                FeedSectionHeader(title: "混排 feed")
                WaterfallSkeleton(count: 8)
                    .frame(height: 860)
            }

        case .error(let message):
            VStack(spacing: Spacing.md) {
                FeedSectionHeader(title: "混排 feed")

                ErrorStateView(
                    message: message,
                    retry: { Task { await store.refresh() } }
                )
                .padding(.top, Spacing.xl)
            }

        case .loaded:
            let cards = store.visibleFeedCards
            VStack(alignment: .leading, spacing: Spacing.md) {
                FeedSectionHeader(
                    title: "混排 feed",
                    subtitle: "\(cards.count) 张卡"
                )

                if let toastMessage = store.toastMessage {
                    EarnInlineToast(message: toastMessage) {
                        store.closeToast()
                    }
                }

                if cards.isEmpty {
                    EmptyStateView(
                        icon: "rectangle.on.rectangle.slash",
                        title: "这一档筛选已经刷空了",
                        message: store.selectedFilter == .bestMatch
                            ? "你已经把当前赛道的公开分身都略过或屏蔽了，可以清空缓存重新刷一轮。"
                            : "换一条赛道，或者切回“机会最多”，让卡片重新混排回来。",
                        actionLabel: store.selectedFilter == .bestMatch ? "清空缓存" : "切回机会最多",
                        action: {
                            if store.selectedFilter == .bestMatch {
                                store.resetPersonaCache()
                            } else {
                                store.selectQuickFilter(.opportunities)
                            }
                        }
                    )
                    .padding(.top, Spacing.xl)
                } else {
                    WaterfallLayout(columns: 2, spacing: Spacing.md) {
                        ForEach(cards) { card in
                            feedCard(for: card)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.92).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func feedCard(for card: EarnSocialFeedCard) -> some View {
        switch card {
        case .wallet(let wallet):
            WalletEnergyCard(wallet: wallet, ledgerEntries: Array(store.ledgerEntries.prefix(3))) {
                store.openWallet()
            }

        case .opportunity(let intent):
            LaneOpportunityCardView(intent: intent) {
                store.selectLane(intent.lane)
                store.openMarket()
            }

        case .persona(let persona):
            PersonaDiscoveryCardView(persona: persona, isLiked: store.likedPersonaIDs.contains(persona.id)) {
                store.selectLane(persona.lane)
                store.openPersonaDeck()
            } primaryAction: {
                store.startIcebreak(with: persona)
            }

        case .icebreakPrompt(let prompt):
            IcebreakPromptCardView(prompt: prompt) {
                store.openIcebreak()
            }

        case .icebreak(let session):
            IcebreakProgressCardView(session: session) {
                store.openIcebreak()
            }

        case .trend(let trend):
            TrendSnapshotCardView(trend: trend) {
                store.selectLane(trend.lane)
                store.openTrends()
            }

        case .arena(let match):
            ArenaBattleCardView(match: match) {
                store.openArena()
            }

        case .bondPrompt(let prompt):
            BondPromptCardView(prompt: prompt) {
                store.openBond()
            }

        case .bond(let story):
            BondStoryCardView(story: story) {
                store.openBond()
            }
        }
    }

    @ViewBuilder
    private func sheetView(for sheet: EarnSocialSheet) -> some View {
        switch sheet {
        case .market:
            EarnIntentMarketView(store: store)
        case .personas:
            EarnPersonaDeckView(store: store)
        case .icebreak:
            EarnIcebreakView(store: store)
        case .trends:
            EarnTrendExplorerView(store: store)
        case .arena:
            EarnArenaExperienceView(store: store)
        case .bond:
            EarnBondJourneyView(store: store)
        case .wallet:
            EarnWalletLedgerView(store: store)
        }
    }
}

// MARK: - Home Components

private struct EarnLaneChipButton: View {
    let chip: EarnSocialLaneChip
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: chip.lane.symbol)
                        .foregroundColor(isSelected ? .white : chip.lane.accentColor)
                    Text(chip.lane.title)
                        .font(.spareCaptionSB)
                        .foregroundColor(isSelected ? .white : .primary)
                }

                Text(chip.lane.shortcut)
                    .font(.spareMicro)
                    .foregroundColor(isSelected ? .white.opacity(0.84) : .secondary)

                HStack(spacing: Spacing.sm) {
                    Label("\(chip.openIntentCount)", systemImage: "sparkles")
                        .font(.spareMicro)
                    Label(String(format: "%.1f", chip.heatScore), systemImage: "flame.fill")
                        .font(.spareMicro)
                }
                .foregroundColor(isSelected ? .white : .secondary)
            }
            .frame(width: 156, alignment: .leading)
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(isSelected ? chip.lane.accentGradient : LinearGradient(colors: [Color.white.opacity(0.92), Color.white.opacity(0.82)], startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .stroke(isSelected ? Color.clear : chip.lane.accentColor.opacity(0.18), lineWidth: 1)
            )
            .cardShadow()
        }
        .buttonStyle(.plain)
    }
}

private struct FilterButton: View {
    let filter: EarnSocialQuickFilter
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: filter.symbol)
                Text(filter.title)
            }
            .font(.spareCaptionSB)
            .foregroundColor(isSelected ? .spareDark : .primary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? Color.spareYellow : Color.white.opacity(0.84))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.cardStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SecondaryActionButton: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.14))
                        .frame(width: 36, height: 36)
                    Image(systemName: symbol)
                        .foregroundColor(tint)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.spareCaptionSB)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
            .background(Color.white.opacity(0.86), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .stroke(Color.cardStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct EarnMetricCapsule: View {
    let title: String
    let value: String
    let footnote: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.spareMicro)
                .foregroundColor(.secondary)
            Text(value)
                .font(.spareTitle3)
                .foregroundColor(.primary)
            Text(footnote)
                .font(.spareMicro)
                .foregroundColor(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(tint.opacity(0.10))
        )
    }
}

private struct EarnInlineToast: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "sparkles")
                .foregroundColor(.spareYellow)
            Text(message)
                .font(.spareCaptionSB)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button(action: dismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.md)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(Color.spareYellow.opacity(0.3), lineWidth: 1)
        )
    }
}

private struct InlineErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.octagon.fill")
                .foregroundColor(.emotionNegative)
            Text(message)
                .font(.spareCaptionSB)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(Spacing.md)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(Color.emotionNegative.opacity(0.24), lineWidth: 1)
        )
    }
}

// MARK: - Feed Cards

private struct LaneOpportunityCardView: View {
    let intent: EarnIntentCard
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: intent.lane.symbol)
                            .foregroundColor(intent.lane.accentColor)
                        Text(intent.lane.title)
                            .font(.spareMicro)
                            .foregroundColor(.secondary)
                    }
                    Text(intent.title)
                        .font(.spareTitle3)
                        .foregroundColor(.primary)
                }

                Spacer()

                IntentModeBadge(mode: intent.mode)
            }

            Text(intent.summary)
                .font(.spareBody)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Text("A2A 省掉哪几步")
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
                Text(intent.reason)
                    .font(.spareCaptionSB)
                    .foregroundColor(intent.lane.accentColor)
            }

            FlowTagCloud(tags: Array(intent.tags.prefix(4)), tint: intent.lane.accentColor)

            Button("发同类意图") {
                action()
            }
            .font(.spareCaptionSB)
            .buttonStyle(.plain)
            .foregroundColor(.primary)
        }
        .padding(Spacing.md)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(intent.lane.accentColor.opacity(0.18), lineWidth: 1)
        )
        .cardShadow()
    }
}

private struct PersonaDiscoveryCardView: View {
    let persona: EarnPersonaCard
    let isLiked: Bool
    let action: () -> Void
    let primaryAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                AvatarView(name: persona.displayName, size: 48)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(persona.displayName)
                            .font(.spareTitle3)
                        if isLiked {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                        }
                    }

                    Text(persona.publicBio)
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            HStack(spacing: Spacing.sm) {
                ScoreChip(label: "匹配 \(Int(persona.matchScore))", tint: persona.lane.accentColor)
                ScoreChip(label: "信任 \(persona.trustScore)", tint: .emotionPositive)
            }

            FlowTagCloud(tags: Array((persona.personaTags + persona.expertiseTags).prefix(5)), tint: persona.lane.accentColor)

            if let explanation = persona.explanationTags.first {
                Text(explanation)
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: Spacing.sm) {
                Button("看公开卡") {
                    action()
                }
                .buttonStyle(.plain)
                .font(.spareCaptionSB)

                Spacer()

                Button(persona.allowsAgentIntro ? "双方分身先聊" : "仅看资料") {
                    primaryAction()
                }
                .buttonStyle(.plain)
                .font(.spareCaptionSB)
                .foregroundColor(persona.lane.accentColor)
            }
        }
        .padding(Spacing.md)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(persona.lane.accentColor.opacity(0.18), lineWidth: 1)
        )
        .cardShadow()
    }
}

private struct IcebreakPromptCardView: View {
    let prompt: EarnIcebreakPrompt
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: 8) {
                StepGlyph(symbol: "person.fill", isActive: true, tint: .emotionPositive)
                StepGlyph(symbol: "person.crop.circle.badge.questionmark", isActive: true, tint: .spareYellow)
                StepGlyph(symbol: "person.crop.circle.badge.questionmark", isActive: true, tint: .orange)
                StepGlyph(symbol: "person.2.fill", isActive: false, tint: .emotionPositive)
            }

            Text(prompt.headline)
                .font(.spareTitle3)

            Text(prompt.body)
                .font(.spareBody)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("打开破冰面板") {
                action()
            }
            .font(.spareCaptionSB)
            .buttonStyle(.plain)
            .foregroundColor(.primary)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.spareYellowLight.opacity(0.62),
                            Color.white.opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .cardShadow()
    }
}

private struct IcebreakProgressCardView: View {
    let session: EarnIcebreakSession
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("双 Agent 破冰")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                    Text(session.intentTitle)
                        .font(.spareTitle3)
                }
                Spacer()
                StatusBadge(label: session.stage.label, tint: session.stage.tintColor)
            }

            Text("目标分身：\(session.counterpartName)")
                .font(.spareCaptionSB)

            HStack(spacing: Spacing.sm) {
                EarnMetricCapsule(
                    title: "兼容度",
                    value: "\(Int(session.compatibilityScore))",
                    footnote: "审计 \(session.audits.count) 条",
                    tint: session.lane.accentColor
                )
                EarnMetricCapsule(
                    title: "授权",
                    value: "\(session.initiatorGranted ? 1 : 0)/\(session.counterpartGranted ? 1 : 0)",
                    footnote: "双方都要点头",
                    tint: .emotionPositive
                )
            }

            Text(session.summary)
                .font(.spareBody)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(session.messages.prefix(2)) { message in
                    HStack(alignment: .top, spacing: 6) {
                        Circle()
                            .fill(message.actor == .counterpartAgent ? Color.orange : Color.spareYellow)
                            .frame(width: 7, height: 7)
                            .padding(.top, 6)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(message.actor.displayName)
                                .font(.spareMicro)
                                .foregroundColor(.secondary)
                            Text(message.content)
                                .font(.spareCaption)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            Button("继续破冰") {
                action()
            }
            .font(.spareCaptionSB)
            .buttonStyle(.plain)
            .foregroundColor(.primary)
        }
        .padding(Spacing.md)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(session.stage.tintColor.opacity(0.18), lineWidth: 1)
        )
        .cardShadow()
    }
}

private struct TrendSnapshotCardView: View {
    let trend: EarnTrendSnapshot
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trend.lane.title)
                        .font(.spareTitle3)
                    Text(trend.eventTitle)
                        .font(.spareCaptionSB)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if trend.isClaimed {
                    StatusBadge(label: "已领取", tint: .emotionPositive)
                } else {
                    StatusBadge(label: "+\(trend.rewardAmount)", tint: .spareYellow)
                }
            }

            Text(trend.eventSummary)
                .font(.spareBody)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            EarnMiniBar(label: "热度", value: trend.heatScore / 50, tint: trend.lane.accentColor)
            EarnMiniBar(label: "响应速度", value: trend.responseSpeedScore / 50, tint: .emotionPositive)
            EarnMiniBar(label: "供需缺口", value: trend.supplyGapScore / 50, tint: .emotionSplit)

            Button("看趋势层") {
                action()
            }
            .font(.spareCaptionSB)
            .buttonStyle(.plain)
            .foregroundColor(.primary)
        }
        .padding(Spacing.md)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(trend.lane.accentColor.opacity(0.18), lineWidth: 1)
        )
        .cardShadow()
    }
}

private struct ArenaBattleCardView: View {
    let match: EarnArenaMatch
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("A2A 竞技场")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                    Text(match.theme)
                        .font(.spareTitle3)
                }
                Spacer()
                StatusBadge(label: match.status == .active ? "投票中" : "已结算", tint: match.status == .active ? .emotionSplit : .emotionPositive)
            }

            VStack(spacing: Spacing.sm) {
                ArenaContenderRow(title: "挑战方", contender: match.challenger, score: match.challengerScore, tint: .emotionSplit)
                ArenaContenderRow(title: "守擂方", contender: match.opponent, score: match.opponentScore, tint: .emotionPositive)
            }

            HStack(spacing: Spacing.sm) {
                ScoreChip(label: "围观 \(match.votes.count)", tint: .emotionSplit)
                ScoreChip(label: "奖励 +\(match.rewardAmount)", tint: .spareYellow)
            }

            Text(match.summary)
                .font(.spareCaption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("去围观") {
                action()
            }
            .font(.spareCaptionSB)
            .buttonStyle(.plain)
            .foregroundColor(.primary)
        }
        .padding(Spacing.md)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(Color.emotionSplit.opacity(0.18), lineWidth: 1)
        )
        .cardShadow()
    }
}

private struct BondPromptCardView: View {
    let prompt: EarnBondPromptCard
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("关系升温与羁绊任务")
                .font(.spareTitle3)
            Text(prompt.message)
                .font(.spareBody)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("打开羁绊面板") {
                action()
            }
            .font(.spareCaptionSB)
            .buttonStyle(.plain)
        }
        .padding(Spacing.md)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(Color.emotionPositive.opacity(0.18), lineWidth: 1)
        )
        .cardShadow()
    }
}

private struct BondStoryCardView: View {
    let story: EarnBondStory
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(story.memorialTitle)
                        .font(.spareTitle3)
                    Text(story.memorialSummary)
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                StatusBadge(label: story.level.title, tint: .emotionPositive)
            }

            EarnMiniBar(label: "关系强度 \(story.strengthScore)", value: Double(story.strengthScore) / 100, tint: .emotionPositive)

            ForEach(story.tasks.prefix(2)) { task in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(task.title)
                            .font(.spareCaptionSB)
                        Spacer()
                        Text("\(task.progressCount)/\(task.targetCount)")
                            .font(.spareMicro)
                            .foregroundColor(.secondary)
                    }
                    EarnMiniBar(label: "", value: Double(task.progressCount) / Double(max(1, task.targetCount)), tint: story.lane.accentColor, showLabel: false)
                }
            }

            Button("看任务") {
                action()
            }
            .font(.spareCaptionSB)
            .buttonStyle(.plain)
            .foregroundColor(.primary)
        }
        .padding(Spacing.md)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(Color.emotionPositive.opacity(0.18), lineWidth: 1)
        )
        .cardShadow()
    }
}

private struct WalletEnergyCard: View {
    let wallet: EarnWalletSnapshot
    let ledgerEntries: [EarnLedgerEntry]
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("闲能经济系统")
                        .font(.spareTitle3)
                    Text("收入、消耗、冻结、结算都在这里可视化。")
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(wallet.balance)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.spareYellow)
            }

            HStack(spacing: Spacing.sm) {
                EarnMetricCapsule(title: "累计赚到", value: "\(wallet.lifetimeEarned)", footnote: "连续 \(wallet.streakDays) 天", tint: .emotionPositive)
                EarnMetricCapsule(title: "冻结中", value: "\(wallet.frozenBalance)", footnote: "竞技场 / 结算", tint: .emotionSplit)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(ledgerEntries) { entry in
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        Circle()
                            .fill(entry.kind.tintColor)
                            .frame(width: 8, height: 8)
                            .padding(.top, 5)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title)
                                .font(.spareCaptionSB)
                            Text(entry.detail)
                                .font(.spareMicro)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(entry.amount >= 0 ? "+\(entry.amount)" : "\(entry.amount)")
                            .font(.spareCaptionSB)
                            .foregroundColor(entry.amount >= 0 ? .emotionPositive : .primary)
                    }
                }
            }

            Button("看完整账本") {
                action()
            }
            .font(.spareCaptionSB)
            .buttonStyle(.plain)
            .foregroundColor(.primary)
        }
        .padding(Spacing.md)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(Color.spareYellow.opacity(0.18), lineWidth: 1)
        )
        .cardShadow()
    }
}

private struct ArenaContenderRow: View {
    let title: String
    let contender: EarnArenaContender
    let score: Double
    let tint: Color

    var body: some View {
        HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
                Text(contender.displayName)
                    .font(.spareCaptionSB)
                Text(contender.subtitle)
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f", score))
                    .font(.spareCaptionSB)
                    .foregroundColor(tint)
                Text("综合分")
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct IntentModeBadge: View {
    let mode: EarnIntentVisibilityMode

    var body: some View {
        Label(mode.title, systemImage: mode.symbol)
            .font(.spareMicro)
            .foregroundColor(mode.tintColor)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule()
                    .fill(mode.tintColor.opacity(0.12))
            )
    }
}

private struct ScoreChip: View {
    let label: String
    let tint: Color

    var body: some View {
        Text(label)
            .font(.spareMicro)
            .foregroundColor(tint)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
    }
}

private struct FlowTagCloud: View {
    let tags: [String]
    let tint: Color

    var body: some View {
        FlexibleTagCloud(tags: tags, tint: tint)
    }
}

private struct FlexibleTagCloud: View {
    let tags: [String]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(chunked(tags, size: 2), id: \.self) { row in
                HStack(spacing: Spacing.xs) {
                    ForEach(row, id: \.self) { tag in
                        Text(tag)
                            .font(.spareMicro)
                            .foregroundColor(tint)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(
                                Capsule()
                                    .fill(tint.opacity(0.10))
                            )
                    }
                }
            }
        }
    }
}

private struct EarnMiniBar: View {
    let label: String
    let value: Double
    let tint: Color
    var showLabel: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showLabel {
                Text(label)
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                    Capsule()
                        .fill(tint)
                        .frame(width: geo.size.width * min(max(value, 0.02), 1))
                }
            }
            .frame(height: 8)
        }
    }
}

private struct StepGlyph: View {
    let symbol: String
    let isActive: Bool
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(isActive ? tint.opacity(0.18) : Color(.systemGray5))
                .frame(width: 30, height: 30)
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isActive ? tint : .secondary)
        }
    }
}

private struct StatusBadge: View {
    let label: String
    let tint: Color

    var body: some View {
        Text(label)
            .font(.spareMicro)
            .foregroundColor(tint)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
    }
}

// MARK: - Market Sheet

private struct EarnIntentMarketView: View {
    @ObservedObject var store: EarnSocialExperienceStore

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    marketHeader

                    laneSelector

                    templateSection

                    if let validation = store.marketValidationMessage {
                        InlineErrorBanner(message: validation)
                    }

                    if let success = store.marketSuccessMessage {
                        EarnInlineToast(message: success) {
                            store.clearMarketMessages()
                        }
                    }

                    draftSection

                    recentIntentSection

                    recommendedPersonaSection
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.lg)
                .padding(.bottom, 120)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("陌生社交意图市场")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: Spacing.sm) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("完成度 \(Int(store.marketDraft.completionScore * 100))%")
                                .font(.spareCaptionSB)
                            Text(store.marketDraft.visibility.detail)
                                .font(.spareMicro)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("发布让分身先筛") {
                            store.publishDraft()
                        }
                        .font(.spareCaptionSB)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                        .background(Color.spareYellow, in: Capsule())
                        .foregroundColor(.spareDark)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.sm)
                    .padding(.bottom, Spacing.sm)
                }
                .background(.thinMaterial)
            }
        }
    }

    private var marketHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.marketDraft.lane.title)
                        .font(.spareTitle2)
                    Text("先选赛道，再选模板，再决定公开范围。不是先找人。")
                        .font(.spareBody)
                        .foregroundColor(.secondary)
                }
                Spacer()
                StatusBadge(label: store.marketDraft.visibility.title, tint: store.marketDraft.visibility.tintColor)
            }

            EarnMiniBar(label: "模板填写进度", value: store.marketDraft.completionScore, tint: store.marketDraft.lane.accentColor)
        }
        .padding(Spacing.lg)
        .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.xl))
        .cardShadow()
    }

    private var laneSelector: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("切赛道")
                .font(.spareCaptionSB)
                .foregroundColor(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(store.laneChips) { chip in
                        EarnLaneChipButton(chip: chip, isSelected: store.marketDraft.lane == chip.lane) {
                            withAnimation(.spareFast) {
                                store.updateDraftLane(chip.lane)
                            }
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("模板")
                .font(.spareCaptionSB)
                .foregroundColor(.secondary)

            ForEach(store.templatesByLane[store.marketDraft.lane] ?? []) { template in
                Button {
                    store.updateDraftTemplate(template)
                } label: {
                    HStack(alignment: .top, spacing: Spacing.md) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(template.title)
                                .font(.spareTitle3)
                            Text(template.summary)
                                .font(.spareCaption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            FlowTagCloud(tags: template.tags, tint: template.lane.accentColor)
                        }
                        Spacer()
                        if template.id == store.marketDraft.template.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(template.lane.accentColor)
                        }
                    }
                    .padding(Spacing.md)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.lg)
                            .stroke(template.id == store.marketDraft.template.id ? template.lane.accentColor.opacity(0.3) : Color.cardStroke, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var draftSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("填写意图")
                .font(.spareCaptionSB)
                .foregroundColor(.secondary)

            VStack(spacing: Spacing.md) {
                ForEach(store.marketDraft.fields) { field in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Text(field.label)
                                .font(.spareCaptionSB)
                            if field.isRequired {
                                Text("*")
                                    .font(.spareCaptionSB)
                                    .foregroundColor(.red)
                            }
                        }
                        TextField(field.placeholder, text: binding(for: field.id))
                            .font(.spareBody)
                            .padding(Spacing.md)
                            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: CornerRadius.md))
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("补充说明")
                        .font(.spareCaptionSB)
                    TextEditor(text: Binding(
                        get: { store.marketDraft.note },
                        set: { store.updateDraftNote($0) }
                    ))
                    .frame(minHeight: 96)
                    .padding(Spacing.sm)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: CornerRadius.md))
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("公开范围")
                        .font(.spareCaptionSB)
                    ForEach(EarnIntentVisibilityMode.allCases) { mode in
                        Button {
                            store.updateDraftVisibility(mode)
                        } label: {
                            HStack(alignment: .top, spacing: Spacing.md) {
                                Image(systemName: mode.symbol)
                                    .foregroundColor(mode.tintColor)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(mode.title)
                                        .font(.spareCaptionSB)
                                    Text(mode.detail)
                                        .font(.spareCaption)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                                if store.marketDraft.visibility == mode {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(mode.tintColor)
                                }
                            }
                            .padding(Spacing.md)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.lg)
                                    .stroke(store.marketDraft.visibility == mode ? mode.tintColor.opacity(0.28) : Color.cardStroke, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(Spacing.md)
            .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.xl))
            .cardShadow()
        }
    }

    private var recentIntentSection: some View {
        let intents = store.visibleRecentIntents(for: store.marketDraft.lane)
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("最近意图")
                .font(.spareCaptionSB)
                .foregroundColor(.secondary)

            if intents.isEmpty {
                EmptyStateView(
                    icon: "tray",
                    title: "这条赛道还没有意图",
                    message: "先发一个，让系统开始给你出推荐。",
                    actionLabel: nil,
                    action: nil
                )
            } else {
                ForEach(intents.prefix(3)) { intent in
                    LaneOpportunityCardView(intent: intent) {
                        store.updateDraftLane(intent.lane)
                        if let template = store.templatesByLane[intent.lane]?.first(where: { $0.id == intent.templateID }) {
                            store.updateDraftTemplate(template)
                        }
                    }
                }
            }
        }
    }

    private var recommendedPersonaSection: some View {
        let personas = store.visiblePersonas(for: store.marketDraft.lane)
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("推荐分身")
                    .font(.spareCaptionSB)
                    .foregroundColor(.secondary)
                Spacer()
                Button("看完整卡组") {
                    store.openPersonaDeck()
                }
                .font(.spareMicro)
                .buttonStyle(.plain)
            }

            ForEach(personas.prefix(2)) { persona in
                PersonaDiscoveryCardView(persona: persona, isLiked: store.likedPersonaIDs.contains(persona.id)) {
                    store.openPersonaDeck()
                } primaryAction: {
                    store.startIcebreak(with: persona)
                }
            }
        }
    }

    private func binding(for fieldID: String) -> Binding<String> {
        Binding(
            get: {
                store.marketDraft.fields.first(where: { $0.id == fieldID })?.value ?? ""
            },
            set: { newValue in
                store.updateDraftField(id: fieldID, value: newValue)
            }
        )
    }
}

// MARK: - Persona Deck

private struct EarnPersonaDeckView: View {
    @ObservedObject var store: EarnSocialExperienceStore

    private var personas: [EarnPersonaCard] {
        store.visiblePersonas(for: store.selectedLane)
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header

                    if let message = store.personaDeckMessage {
                        EarnInlineToast(message: message) {
                            store.clearPersonaDeckMessage()
                        }
                    }

                    if personas.isEmpty {
                        EmptyStateView(
                            icon: "person.crop.rectangle.stack",
                            title: "公开分身已经刷完了",
                            message: "你把这条赛道的分身都略过、屏蔽或举报了。本地缓存已经生效，减少重复曝光。",
                            actionLabel: "清空缓存",
                            action: { store.resetPersonaCache() }
                        )
                        .padding(.top, Spacing.xl)
                    } else {
                        ForEach(personas) { persona in
                            PersonaDeckRow(
                                persona: persona,
                                isLiked: store.likedPersonaIDs.contains(persona.id),
                                onLike: { store.likePersona(persona) },
                                onSkip: { store.skipPersona(persona) },
                                onReport: { store.reportPersona(persona) },
                                onStart: { store.startIcebreak(with: persona) }
                            )
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xxxl)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("发现别人的分身")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("\(store.selectedLane.title) · 公共分身卡")
                .font(.spareTitle2)

            Text("看到的不是传统个人资料页，而是别人愿意拿出来社交的分身卡。每张卡都有可解释理由和可控曝光反馈。")
                .font(.spareBody)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Spacing.sm) {
                EarnMetricCapsule(title: "喜欢", value: "\(store.likedPersonaIDs.count)", footnote: "会更早推荐", tint: .emotionPositive)
                EarnMetricCapsule(title: "已缓存", value: "\(store.blockedPersonaIDs.count)", footnote: "减少重复曝光", tint: store.selectedLane.accentColor)
            }
        }
        .padding(Spacing.lg)
        .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.xl))
        .cardShadow()
    }
}

private struct PersonaDeckRow: View {
    let persona: EarnPersonaCard
    let isLiked: Bool
    let onLike: () -> Void
    let onSkip: () -> Void
    let onReport: () -> Void
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top, spacing: Spacing.md) {
                AvatarView(name: persona.displayName, size: 56)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(persona.displayName)
                            .font(.spareTitle3)
                        if isLiked {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                        }
                    }
                    Text(persona.publicBio)
                        .font(.spareBody)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            HStack(spacing: Spacing.sm) {
                ScoreChip(label: "匹配 \(Int(persona.matchScore))", tint: persona.lane.accentColor)
                ScoreChip(label: "信任 \(persona.trustScore)", tint: .emotionPositive)
                if persona.allowsAgentIntro {
                    ScoreChip(label: "允许先聊", tint: .spareYellow)
                }
            }

            FlowTagCloud(tags: persona.personaTags + persona.expertiseTags, tint: persona.lane.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text("开放时段：\(persona.openHours.joined(separator: " / "))")
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
                Text("期望对象：\(persona.expectedPartner.joined(separator: " / "))")
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
                Text(persona.explanationTags.joined(separator: " · "))
                    .font(.spareMicro)
                    .foregroundColor(persona.lane.accentColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: Spacing.sm) {
                SmallActionButton(title: "喜欢", tint: .emotionPositive, action: onLike)
                SmallActionButton(title: "略过", tint: .secondary, action: onSkip)
                SmallActionButton(title: "举报", tint: .emotionNegative, action: onReport)
            }

            Button("让双方分身先聊") {
                onStart()
            }
            .font(.spareCaptionSB)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity)
            .background(persona.lane.accentGradient, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
            .foregroundColor(.white)
        }
        .padding(Spacing.md)
        .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .stroke(persona.lane.accentColor.opacity(0.18), lineWidth: 1)
        )
        .cardShadow()
    }
}

private struct SmallActionButton: View {
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.spareMicro)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(tint.opacity(0.12), in: Capsule())
            .foregroundColor(tint)
            .buttonStyle(.plain)
    }
}

// MARK: - Icebreak Sheet

private struct EarnIcebreakView: View {
    @ObservedObject var store: EarnSocialExperienceStore

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header

                    if let session = store.activeIcebreak {
                        sessionView(session)
                    } else {
                        emptyView
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xxxl)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("双 Agent 破冰")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("human → agent → agent → human")
                .font(.spareTitle2)

            HStack(spacing: Spacing.sm) {
                StepGlyph(symbol: "person.fill", isActive: true, tint: .emotionPositive)
                StepGlyph(symbol: "person.crop.circle.badge.questionmark", isActive: true, tint: .spareYellow)
                StepGlyph(symbol: "person.crop.circle.badge.questionmark", isActive: true, tint: .orange)
                StepGlyph(symbol: "person.2.fill", isActive: store.activeIcebreak?.stage == .humanTakeover, tint: .emotionPositive)
            }

            Text("陌生社交不直接真人对真人，先让双方分身摸底、过滤、暖场、探边界，再决定要不要真人接手。")
                .font(.spareBody)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.lg)
        .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.xl))
        .cardShadow()
    }

    @ViewBuilder
    private func sessionView(_ session: EarnIcebreakSession) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.intentTitle)
                        .font(.spareTitle3)
                    Text("目标分身：\(session.counterpartName)")
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                StatusBadge(label: session.stage.label, tint: session.stage.tintColor)
            }

            HStack(spacing: Spacing.sm) {
                EarnMetricCapsule(title: "兼容度", value: "\(Int(session.compatibilityScore))", footnote: "\(session.lane.title)", tint: session.lane.accentColor)
                EarnMetricCapsule(title: "审计", value: "\(session.audits.count)", footnote: session.auditPassed ? "全部通过" : "存在风险", tint: .emotionPositive)
            }

            Text(session.summary)
                .font(.spareBody)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("对话审计")
                    .font(.spareCaptionSB)
                    .foregroundColor(.secondary)

                ForEach(session.messages) { message in
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        Circle()
                            .fill(message.actor == .counterpartAgent ? Color.orange : message.actor == .system ? Color.emotionNeutral : Color.spareYellow)
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(message.actor.displayName)
                                    .font(.spareMicro)
                                    .foregroundColor(.secondary)
                                StatusBadge(label: message.auditPassed ? "审计通过" : "需复核", tint: message.auditPassed ? .emotionPositive : .emotionNegative)
                            }
                            Text(message.content)
                                .font(.spareBody)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.bottom, Spacing.xs)
                }
            }
            .padding(Spacing.md)
            .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.lg))

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("接手规则")
                    .font(.spareCaptionSB)
                    .foregroundColor(.secondary)
                ForEach(session.handoffRules, id: \.self) { rule in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(session.lane.accentColor)
                            .padding(.top, 2)
                        Text(rule)
                            .font(.spareCaption)
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(Spacing.md)
            .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.lg))

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("双方授权")
                    .font(.spareCaptionSB)
                    .foregroundColor(.secondary)

                consentRow(
                    title: "我方真人接手",
                    granted: session.initiatorGranted,
                    allow: { store.updateConsent(side: .initiator, granted: true) },
                    hold: { store.updateConsent(side: .initiator, granted: false) }
                )
                consentRow(
                    title: "对方真人接手",
                    granted: session.counterpartGranted,
                    allow: { store.updateConsent(side: .counterpart, granted: true) },
                    hold: { store.updateConsent(side: .counterpart, granted: false) }
                )
            }
            .padding(Spacing.md)
            .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.lg))

            if session.stage == .humanTakeover, store.bondStory != nil {
                Button {
                    store.openBond()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("真人接手入口已生成")
                                .font(.spareCaptionSB)
                                .foregroundColor(.primary)
                            Text("初遇纪念卡和羁绊任务已经挂到消息线程前。")
                                .font(.spareCaption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(.emotionPositive)
                    }
                    .padding(Spacing.md)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: Spacing.md) {
            EmptyStateView(
                icon: "person.crop.circle.badge.questionmark",
                title: "先挑一个分身开始破冰",
                message: "从公开分身卡进入，让双方分身先做边界确认和意图筛选，再决定真人要不要出现。",
                actionLabel: "去看分身卡",
                action: { store.openPersonaDeck() }
            )

            if let topPersona = store.visiblePersonas(for: store.selectedLane).first {
                PersonaDiscoveryCardView(persona: topPersona, isLiked: store.likedPersonaIDs.contains(topPersona.id)) {
                    store.openPersonaDeck()
                } primaryAction: {
                    store.startIcebreak(with: topPersona)
                }
            }
        }
    }

    private func consentRow(title: String, granted: Bool, allow: @escaping () -> Void, hold: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.spareCaptionSB)
                Text(granted ? "已授权" : "尚未授权")
                    .font(.spareMicro)
                    .foregroundColor(granted ? .emotionPositive : .secondary)
            }
            Spacer()
            SmallActionButton(title: "允许", tint: .emotionPositive, action: allow)
            SmallActionButton(title: "停在分身层", tint: .emotionNegative, action: hold)
        }
    }
}

// MARK: - Trend Sheet

private struct EarnTrendExplorerView: View {
    @ObservedObject var store: EarnSocialExperienceStore

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header

                    ForEach(store.trendBoard.sorted { $0.heatScore > $1.heatScore }) { trend in
                        TrendExplorerRow(trend: trend) {
                            store.claimTrendReward(for: trend.lane)
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xxxl)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("六赛道趋势与热点")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("看哪里最热、响应最快、最赚钱、最缺供给。")
                .font(.spareBody)
                .foregroundColor(.secondary)

            HStack(spacing: Spacing.sm) {
                if let hottest = store.trendBoard.max(by: { $0.heatScore < $1.heatScore }) {
                    EarnMetricCapsule(title: "最热", value: hottest.lane.title, footnote: hottest.eventTitle, tint: hottest.lane.accentColor)
                }
                if let fastest = store.trendBoard.max(by: { $0.responseSpeedScore < $1.responseSpeedScore }) {
                    EarnMetricCapsule(title: "最快响应", value: fastest.lane.title, footnote: "抢占高回复窗口", tint: .emotionPositive)
                }
            }
        }
        .padding(Spacing.lg)
        .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.xl))
        .cardShadow()
    }
}

private struct TrendExplorerRow: View {
    let trend: EarnTrendSnapshot
    let onClaim: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trend.lane.title)
                        .font(.spareTitle3)
                    Text(trend.eventTitle)
                        .font(.spareCaptionSB)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if trend.isClaimed {
                    StatusBadge(label: "已领奖励", tint: .emotionPositive)
                } else {
                    Button("+\(trend.rewardAmount) 领取") {
                        onClaim()
                    }
                    .font(.spareMicro)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.spareYellow, in: Capsule())
                    .foregroundColor(.spareDark)
                    .buttonStyle(.plain)
                }
            }

            Text(trend.eventSummary)
                .font(.spareBody)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            EarnMiniBar(label: "热度 \(String(format: "%.1f", trend.heatScore))", value: trend.heatScore / 50, tint: trend.lane.accentColor)
            EarnMiniBar(label: "响应速度 \(Int(trend.responseSpeedScore))", value: trend.responseSpeedScore / 50, tint: .emotionPositive)
            EarnMiniBar(label: "赚钱空间 \(Int(trend.profitScore))", value: trend.profitScore / 50, tint: .spareYellow)
            EarnMiniBar(label: "供需缺口 \(Int(trend.supplyGapScore))", value: trend.supplyGapScore / 50, tint: .emotionSplit)
        }
        .padding(Spacing.md)
        .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .stroke(trend.lane.accentColor.opacity(0.18), lineWidth: 1)
        )
        .cardShadow()
    }
}

// MARK: - Arena Sheet

private struct EarnArenaExperienceView: View {
    @ObservedObject var store: EarnSocialExperienceStore

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    if let match = store.arenaMatch {
                        header(match)
                        rounds(match)
                        votePanel(match)
                    } else {
                        EmptyStateView(
                            icon: "figure.boxing",
                            title: "竞技场暂时空场",
                            message: "等一局新的分身对战发起后，这里会出现辩题、评分和围观投票。",
                            actionLabel: nil,
                            action: nil
                        )
                        .padding(.top, Spacing.xxxl)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xxxl)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("A2A 竞技场")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func header(_ match: EarnArenaMatch) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(match.theme)
                        .font(.spareTitle2)
                    Text("让分身先打擂台，赢了再进入真人阶段。")
                        .font(.spareBody)
                        .foregroundColor(.secondary)
                }
                Spacer()
                StatusBadge(label: match.status == .active ? "围观投票中" : "结算完成", tint: match.status == .active ? .emotionSplit : .emotionPositive)
            }

            ArenaContenderRow(title: "挑战方", contender: match.challenger, score: match.challengerScore, tint: .emotionSplit)
            ArenaContenderRow(title: "守擂方", contender: match.opponent, score: match.opponentScore, tint: .emotionPositive)

            if let winner = match.winnerSide {
                Text("\(winner.title) 已胜出，\(match.summary)")
                    .font(.spareCaptionSB)
                    .foregroundColor(.primary)
            } else {
                Text("当前还未结算，围观票会直接影响综合得分。")
                    .font(.spareCaptionSB)
                    .foregroundColor(.secondary)
            }
        }
        .padding(Spacing.lg)
        .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.xl))
        .cardShadow()
    }

    private func rounds(_ match: EarnArenaMatch) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("回放摘要")
                .font(.spareCaptionSB)
                .foregroundColor(.secondary)

            ForEach(match.rounds) { round in
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("第 \(round.index) 回合 · \(round.prompt)")
                        .font(.spareCaptionSB)

                    ArenaResponseBubble(title: match.challenger.displayName, body: round.challengerReply, score: round.challengerScore, tint: .emotionSplit)
                    ArenaResponseBubble(title: match.opponent.displayName, body: round.opponentReply, score: round.opponentScore, tint: .emotionPositive)

                    Text(round.summary)
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }
                .padding(Spacing.md)
                .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
                .cardShadow()
            }
        }
    }

    private func votePanel(_ match: EarnArenaMatch) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("围观投票")
                .font(.spareCaptionSB)
                .foregroundColor(.secondary)

            HStack(spacing: Spacing.sm) {
                Button("投挑战方") {
                    store.castArenaVote(.challenger)
                }
                .font(.spareCaptionSB)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(Color.emotionSplit.opacity(0.16), in: Capsule())
                .foregroundColor(.primary)
                .buttonStyle(.plain)

                Button("投守擂方") {
                    store.castArenaVote(.opponent)
                }
                .font(.spareCaptionSB)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(Color.emotionPositive.opacity(0.16), in: Capsule())
                .foregroundColor(.primary)
                .buttonStyle(.plain)
            }

            Text("当前你支持：\(store.selectedArenaVote?.title ?? "还没投票")")
                .font(.spareMicro)
                .foregroundColor(.secondary)

            Button(match.status == .active ? "结算本局并发放闲能" : "本局已结算") {
                store.resolveArenaIfNeeded()
            }
            .font(.spareCaptionSB)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity)
            .background(match.status == .active ? Color.spareYellow : Color(.systemGray5), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
            .foregroundColor(match.status == .active ? .spareDark : .secondary)
            .buttonStyle(.plain)
        }
        .padding(Spacing.lg)
        .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.xl))
        .cardShadow()
    }
}

private struct ArenaResponseBubble: View {
    let title: String
    let body: String
    let score: Double
    let tint: Color

    var bodyView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.1f", score))
                    .font(.spareMicro)
                    .foregroundColor(tint)
            }
            Text(body)
                .font(.spareCaption)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
    }

    var body: some View { bodyView }
}

// MARK: - Bond Sheet

private struct EarnBondJourneyView: View {
    @ObservedObject var store: EarnSocialExperienceStore

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    if let story = store.bondStory {
                        header(story)
                        taskList(story)
                        milestoneSection(story)
                    } else {
                        EmptyStateView(
                            icon: "heart.text.square",
                            title: "还没有生成羁绊任务",
                            message: "先完成一次双 Agent 互相授权，系统才会把初遇纪念卡、连续互动任务和线程迁移挂上来。",
                            actionLabel: "去做破冰",
                            action: { store.openIcebreak() }
                        )
                        .padding(.top, Spacing.xxxl)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xxxl)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("关系升温与羁绊任务")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func header(_ story: EarnBondStory) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(story.memorialTitle)
                        .font(.spareTitle2)
                    Text(story.memorialSummary)
                        .font(.spareBody)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                StatusBadge(label: story.level.title, tint: .emotionPositive)
            }

            EarnMiniBar(label: "关系强度 \(story.strengthScore)", value: Double(story.strengthScore) / 100, tint: story.lane.accentColor)

            HStack(spacing: Spacing.sm) {
                EarnMetricCapsule(title: "任务数", value: "\(story.tasks.count)", footnote: "持续从陌生到熟悉", tint: story.lane.accentColor)
                EarnMetricCapsule(title: "里程碑", value: "\(story.milestones.count)", footnote: "自动沉淀到消息页", tint: .emotionPositive)
            }

            HStack(spacing: 6) {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(.emotionPositive)
                Text("线程迁移：\(story.threadRoute)")
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(Spacing.lg)
        .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.xl))
        .cardShadow()
    }

    private func taskList(_ story: EarnBondStory) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("任务清单")
                .font(.spareCaptionSB)
                .foregroundColor(.secondary)

            ForEach(story.tasks) { task in
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title)
                                .font(.spareTitle3)
                            Text(task.summary)
                                .font(.spareCaption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        StatusBadge(label: task.isCompleted ? "已完成" : "+\(task.rewardAmount)", tint: task.isCompleted ? .emotionPositive : story.lane.accentColor)
                    }

                    EarnMiniBar(label: "进度 \(task.progressCount)/\(task.targetCount)", value: Double(task.progressCount) / Double(max(1, task.targetCount)), tint: story.lane.accentColor)

                    Button(task.isCompleted ? "已完成" : "推进一次") {
                        store.advanceBondTask(task)
                    }
                    .font(.spareCaptionSB)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                    .background(task.isCompleted ? Color(.systemGray5) : story.lane.accentGradient, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
                    .foregroundColor(task.isCompleted ? .secondary : .white)
                    .buttonStyle(.plain)
                }
                .padding(Spacing.md)
                .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
                .cardShadow()
            }
        }
    }

    private func milestoneSection(_ story: EarnBondStory) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("里程碑")
                .font(.spareCaptionSB)
                .foregroundColor(.secondary)

            if story.milestones.isEmpty {
                EmptyStateView(
                    icon: "flag.checkered",
                    title: "还没有点亮里程碑",
                    message: "先推进一两个轻量任务，系统就会把关系节点写进纪念卡。",
                    actionLabel: nil,
                    action: nil
                )
            } else {
                ForEach(story.milestones) { milestone in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(milestone.title)
                            .font(.spareCaptionSB)
                        Text(milestone.summary)
                            .font(.spareCaption)
                            .foregroundColor(.secondary)
                        Text(milestone.achievedAt, style: .relative)
                            .font(.spareMicro)
                            .foregroundColor(.secondary)
                    }
                    .padding(Spacing.md)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
                    .cardShadow()
                }
            }
        }
    }
}

// MARK: - Wallet Sheet

private struct EarnWalletLedgerView: View {
    @ObservedObject var store: EarnSocialExperienceStore

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header
                    antiCheat
                    ledgerList
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xxxl)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("闲能经济系统")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(store.wallet.balance)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.spareYellow)
                    Text("收入、支出、冻结、结算都要能解释。")
                        .font(.spareBody)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            HStack(spacing: Spacing.sm) {
                EarnMetricCapsule(title: "累计赚到", value: "\(store.wallet.lifetimeEarned)", footnote: "今日还可赚 \(store.wallet.todayEarnable)", tint: .emotionPositive)
                EarnMetricCapsule(title: "累计花掉", value: "\(store.wallet.lifetimeSpent)", footnote: "冻结 \(store.wallet.frozenBalance)", tint: .emotionSplit)
            }
        }
        .padding(Spacing.lg)
        .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.xl))
        .cardShadow()
    }

    private var antiCheat: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("规则和风控")
                .font(.spareCaptionSB)
                .foregroundColor(.secondary)

            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundColor(.emotionPositive)
                Text("黑客松阶段先用本地规则模拟，但每一笔闲能仍然要写清来源、去向、冻结和结算状态，避免“赚了什么、花到哪了”变成黑盒。")
                    .font(.spareBody)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Spacing.md)
            .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        }
    }

    private var ledgerList: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("账本")
                .font(.spareCaptionSB)
                .foregroundColor(.secondary)

            ForEach(store.ledgerEntries) { entry in
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Circle()
                        .fill(entry.kind.tintColor)
                        .frame(width: 9, height: 9)
                        .padding(.top, 6)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.title)
                                .font(.spareCaptionSB)
                            Spacer()
                            Text(entry.amount >= 0 ? "+\(entry.amount)" : "\(entry.amount)")
                                .font(.spareCaptionSB)
                                .foregroundColor(entry.amount >= 0 ? .emotionPositive : .primary)
                        }

                        Text(entry.detail)
                            .font(.spareCaption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack {
                            if let lane = entry.lane {
                                Text(lane.title)
                                    .font(.spareMicro)
                                    .foregroundColor(lane.accentColor)
                            }
                            Spacer()
                            Text(entry.statusLabel)
                                .font(.spareMicro)
                                .foregroundColor(.secondary)
                            Text(entry.timestamp, style: .relative)
                                .font(.spareMicro)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(Spacing.md)
                .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
                .cardShadow()
            }
        }
    }
}

// MARK: - Helpers

private extension EarnSocialLaneID {
    var accentColor: Color {
        switch self {
        case .idleGoods: return Color(red: 0.95, green: 0.55, blue: 0.20)
        case .skillQA: return Color(red: 0.18, green: 0.47, blue: 0.88)
        case .romance: return Color(red: 0.86, green: 0.32, blue: 0.48)
        case .friendship: return Color(red: 0.24, green: 0.66, blue: 0.58)
        case .jobHiring: return Color(red: 0.25, green: 0.34, blue: 0.66)
        case .errandHelp: return Color(red: 0.68, green: 0.41, blue: 0.18)
        }
    }

    var accentGradient: LinearGradient {
        switch self {
        case .idleGoods:
            return LinearGradient(colors: [Color(red: 0.97, green: 0.66, blue: 0.31), Color(red: 0.91, green: 0.42, blue: 0.16)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .skillQA:
            return LinearGradient(colors: [Color(red: 0.36, green: 0.60, blue: 0.97), Color(red: 0.13, green: 0.39, blue: 0.83)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .romance:
            return LinearGradient(colors: [Color(red: 0.96, green: 0.55, blue: 0.67), Color(red: 0.81, green: 0.23, blue: 0.43)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .friendship:
            return LinearGradient(colors: [Color(red: 0.40, green: 0.76, blue: 0.64), Color(red: 0.18, green: 0.59, blue: 0.50)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .jobHiring:
            return LinearGradient(colors: [Color(red: 0.42, green: 0.51, blue: 0.84), Color(red: 0.22, green: 0.28, blue: 0.63)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .errandHelp:
            return LinearGradient(colors: [Color(red: 0.84, green: 0.57, blue: 0.31), Color(red: 0.63, green: 0.35, blue: 0.14)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

private extension EarnIntentVisibilityMode {
    var tintColor: Color {
        switch self {
        case .public: return .emotionPositive
        case .semiPublic: return .emotionSplit
        case .direct: return .emotionNegative
        }
    }
}

private extension EarnIcebreakStage {
    var tintColor: Color {
        switch self {
        case .screening: return .spareYellow
        case .consentPending: return .emotionSplit
        case .humanTakeover: return .emotionPositive
        case .blocked: return .emotionNegative
        }
    }
}

private extension EarnLedgerEntryKind {
    var tintColor: Color {
        switch self {
        case .income: return .emotionPositive
        case .expense: return .emotionNegative
        case .freeze: return .emotionSplit
        case .settlement: return .spareYellow
        }
    }
}

private func chunked(_ tags: [String], size: Int) -> [[String]] {
    guard size > 0 else { return [tags] }
    var rows: [[String]] = []
    var index = 0
    while index < tags.count {
        rows.append(Array(tags[index..<min(index + size, tags.count)]))
        index += size
    }
    return rows
}
