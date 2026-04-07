import SwiftUI

private enum EarnSocialPalette {
    static func white(_ opacity: Double = 1) -> Color {
        let base: Color = .white
        return base.opacity(opacity)
    }

    static func yellow(_ opacity: Double = 1) -> Color {
        let base: Color = .spareYellow
        return base.opacity(opacity)
    }

    static func black(_ opacity: Double = 1) -> Color {
        let base: Color = .black
        return base.opacity(opacity)
    }
}

struct EarnSocialHomeView: View {
    @StateObject private var store = EarnSocialExperienceStore()

    var body: some View {
        NavigationStack {
            ZStack {
                background

                VStack(spacing: 0) {
                    header
                    content
                }
            }
            .spareNavigationBarHidden(true)
        }
        .task {
            store.loadIfNeeded()
        }
        .sheet(item: $store.activeSheet) { sheet in
            EarnSocialSheetHostView(sheet: sheet, store: store)
        }
        .overlay(alignment: .top) {
            if let toast = store.toastMessage {
                EarnSocialToastBanner(message: toast) {
                    store.closeToast()
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spareEase, value: store.toastMessage)
    }

    private var background: some View {
        LinearGradient(
            colors: [
                EarnSocialPalette.yellow(0.12),
                Color.white,
                Color.white
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Spacer()
                Text("赚闲能")
                    .font(.spareTitle2)
                    .foregroundColor(.primary)
                Spacer()
            }

            HStack(spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.selectedLane.title)
                        .font(.spareBodySB)
                        .foregroundColor(.primary)
                    Text("首页 runtime 现在只认这一套：`EarnSocialHomeView + EarnSocialExperienceStore`。")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 0)

                Button {
                    store.openWallet()
                } label: {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("闲能 \(store.wallet.balance)")
                            .font(.spareCaptionSB)
                            .foregroundColor(.primary)
                        Text("连登 \(store.wallet.streakDays) 天")
                            .font(.spareMicro)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, 10)
                    .background(Color.white, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(EarnSocialPalette.yellow(0.24), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.md)
    }

    @ViewBuilder
    private var content: some View {
        switch store.homeState {
        case .idle, .loading:
            EarnSocialLoadingStateView()
        case .error(let message):
            ErrorStateView(
                message: message,
                retry: {
                    Task {
                        await store.refresh(simulateLoading: false)
                    }
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, Spacing.lg)
        case .loaded:
            GeometryReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        runtimeSummaryCard
                        laneRail
                        filterRail
                        actionRail
                        feedGrid(containerWidth: proxy.size.width)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.xxxl)
                }
                .refreshable {
                    await store.refresh()
                }
            }
        }
    }

    private var runtimeSummaryCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.selectedLane.title)
                        .font(.spareBodySB)
                        .foregroundColor(.primary)

                    Text(store.selectedLane.summary)
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Text("single runtime truth")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.spareYellowInk)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(EarnSocialPalette.yellow(0.16), in: Capsule())
            }

            HStack(spacing: Spacing.sm) {
                if let chip = store.selectedLaneChip {
                    EarnSocialMetricBlock(
                        title: "赛道热度",
                        value: String(format: "%.1f", chip.heatScore),
                        detail: "开放意图 \(chip.openIntentCount)"
                    )
                }

                if let trend = store.selectedLaneTrend {
                    EarnSocialMetricBlock(
                        title: "热点奖励",
                        value: "+\(trend.rewardAmount)",
                        detail: trend.eventTitle
                    )
                }

                EarnSocialMetricBlock(
                    title: "最新刷新",
                    value: EarnSocialDateFormatting.timeString(store.lastRefreshAt),
                    detail: store.selectedFilter.title
                )
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .opacity(0.92)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(EarnSocialPalette.yellow(0.20), lineWidth: 1)
                )
        )
        .shadow(color: EarnSocialPalette.yellow(0.10), radius: 16, y: 8)
    }

    private var laneRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(store.laneChips) { chip in
                    Button {
                        store.selectLane(chip.lane)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: chip.lane.symbol)
                                    .font(.system(size: 14, weight: .semibold))
                                Text(chip.lane.title)
                                    .font(.spareCaptionSB)
                            }
                            .foregroundColor(store.selectedLane == chip.lane ? .spareYellowInk : .primary)

                            Text(chip.lane.shortcut)
                                .font(.spareMicro)
                                .foregroundColor(.secondary)

                            Text("热度 \(String(format: "%.1f", chip.heatScore)) · 奖励 +\(chip.rewardAmount)")
                                .font(.spareMicro)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(store.selectedLane == chip.lane ? Color.spareYellow : Color.white)
                                .opacity(store.selectedLane == chip.lane ? 0.18 : 0.88)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(store.selectedLane == chip.lane ? Color.spareYellow : EarnSocialPalette.yellow(0.14), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 1)
        }
    }

    private var filterRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(store.quickFilters) { filter in
                    Button {
                        store.selectQuickFilter(filter)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: filter.symbol)
                                .font(.system(size: 13, weight: .semibold))
                            Text(filter.title)
                                .font(.spareCaptionSB)
                        }
                        .foregroundColor(store.selectedFilter == filter ? .spareYellowInk : .primary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(store.selectedFilter == filter ? Color.spareYellow : Color.white)
                                .opacity(store.selectedFilter == filter ? 0.18 : 0.84)
                        )
                        .overlay(
                            Capsule()
                                .stroke(store.selectedFilter == filter ? Color.spareYellow : EarnSocialPalette.yellow(0.18), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 1)
        }
    }

    private var actionRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                EarnSocialActionButton(title: "发意图", symbol: "square.and.pencil") {
                    store.openMarket()
                }
                EarnSocialActionButton(title: "看分身", symbol: "person.2.badge.gearshape") {
                    store.openPersonaDeck()
                }
                EarnSocialActionButton(title: "双 Agent 破冰", symbol: "bubble.left.and.text.bubble.right.fill") {
                    store.openIcebreak()
                }
                EarnSocialActionButton(title: "热点趋势", symbol: "chart.line.uptrend.xyaxis") {
                    store.openTrends()
                }
                EarnSocialActionButton(title: "竞技场", symbol: "figure.boxing") {
                    store.openArena()
                }
                EarnSocialActionButton(title: "关系任务", symbol: "sparkles") {
                    store.openBond()
                }
            }
            .padding(.vertical, 1)
        }
    }

    private func feedGrid(containerWidth: CGFloat) -> some View {
        let minimumWidth = containerWidth < 620 ? max(240, containerWidth - Spacing.lg * 2) : 280
        let columns = [GridItem(.adaptive(minimum: minimumWidth, maximum: 420), spacing: Spacing.md, alignment: .top)]

        return LazyVGrid(columns: columns, alignment: .leading, spacing: Spacing.md) {
            ForEach(store.visibleFeedCards) { card in
                Button(action: action(for: card)) {
                    EarnSocialRuntimeFeedCard(card: card)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func action(for card: EarnSocialFeedCard) -> () -> Void {
        switch card {
        case .wallet:
            return { store.openWallet() }
        case .opportunity:
            return { store.openMarket() }
        case .persona(let persona):
            return { store.startIcebreak(with: persona) }
        case .icebreakPrompt, .icebreak:
            return { store.openIcebreak() }
        case .trend:
            return { store.openTrends() }
        case .arena:
            return { store.openArena() }
        case .bondPrompt, .bond:
            return { store.openBond() }
        }
    }
}

private struct EarnSocialRuntimeFeedCard: View {
    let card: EarnSocialFeedCard

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            switch card {
            case .wallet(let wallet):
                header(title: "钱包快照", symbol: "creditcard.fill", badge: "余额")

                HStack(alignment: .lastTextBaseline, spacing: Spacing.xs) {
                    Text("\(wallet.balance)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("闲能")
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: Spacing.sm) {
                    EarnSocialMetricBlock(title: "今日可赚", value: "\(wallet.todayEarnable)", detail: "连登 \(wallet.streakDays) 天")
                    EarnSocialMetricBlock(title: "累计赚得", value: "\(wallet.lifetimeEarned)", detail: "累计支出 \(wallet.lifetimeSpent)")
                }

            case .opportunity(let intent):
                header(title: intent.title, symbol: intent.lane.symbol, badge: intent.mode.title)

                Text(intent.summary)
                    .font(.spareBody)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                tagRow(Array(intent.tags.prefix(4)))

                HStack(spacing: Spacing.sm) {
                    EarnSocialMetricBlock(title: "赛道", value: intent.lane.title, detail: intent.reason)
                    EarnSocialMetricBlock(title: "排序分", value: "\(intent.rankingScore)", detail: "点开继续编辑意图")
                }

            case .persona(let persona):
                header(title: persona.displayName, symbol: "person.crop.circle.badge.checkmark", badge: "match \(Int(persona.matchScore * 100))")

                Text(persona.publicBio)
                    .font(.spareBody)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                tagRow(persona.personaTags + Array(persona.expertiseTags.prefix(2)))

                HStack(spacing: Spacing.sm) {
                    EarnSocialMetricBlock(title: "信用", value: "\(persona.trustScore)", detail: persona.lane.title)
                    EarnSocialMetricBlock(title: "开放时段", value: persona.openHours.first ?? "随时", detail: "点击直接发起破冰")
                }

            case .icebreakPrompt(let prompt):
                header(title: prompt.headline, symbol: "bubble.left.and.text.bubble.right.fill", badge: "待启动")

                Text(prompt.body)
                    .font(.spareBody)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("当前选中的赛道会复用同一套 `activeIcebreak` runtime，不再走页面内临时聊天状态。")
                    .font(.spareMicro)
                    .foregroundColor(.secondary)

            case .icebreak(let session):
                header(title: "破冰进度 · \(session.counterpartName)", symbol: "person.2.wave.2.fill", badge: session.stage.label)

                Text(session.summary)
                    .font(.spareBody)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: Spacing.sm) {
                    EarnSocialMetricBlock(
                        title: "双方授权",
                        value: "\(session.initiatorGranted ? 1 : 0)/\(session.counterpartGranted ? 1 : 0)",
                        detail: session.auditPassed ? "审计通过" : "待审计"
                    )
                    EarnSocialMetricBlock(
                        title: "兼容度",
                        value: "\(Int(session.compatibilityScore * 100))",
                        detail: session.lane.title
                    )
                }

            case .trend(let trend):
                header(title: trend.eventTitle, symbol: "chart.line.uptrend.xyaxis", badge: trend.isClaimed ? "已领取" : "+\(trend.rewardAmount)")

                Text(trend.eventSummary)
                    .font(.spareBody)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: Spacing.sm) {
                    EarnSocialMetricBlock(title: "热度", value: String(format: "%.1f", trend.heatScore), detail: trend.lane.title)
                    EarnSocialMetricBlock(title: "供需差", value: String(format: "%.1f", trend.supplyGapScore), detail: "点开领取奖励")
                }

            case .arena(let match):
                header(title: match.theme, symbol: "figure.boxing", badge: match.status == .active ? "对战中" : "已结算")

                Text(match.summary)
                    .font(.spareBody)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: Spacing.sm) {
                    EarnSocialMetricBlock(title: match.challenger.displayName, value: String(format: "%.1f", match.challengerScore), detail: match.challenger.subtitle)
                    EarnSocialMetricBlock(title: match.opponent.displayName, value: String(format: "%.1f", match.opponentScore), detail: match.opponent.subtitle)
                }

            case .bondPrompt(let prompt):
                header(title: prompt.title, symbol: "sparkles", badge: "待生成")

                Text(prompt.message)
                    .font(.spareBody)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

            case .bond(let story):
                header(title: story.memorialTitle, symbol: "heart.text.square.fill", badge: story.level.title)

                Text(story.memorialSummary)
                    .font(.spareBody)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: Spacing.sm) {
                    EarnSocialMetricBlock(title: "对象", value: story.counterpartName, detail: "强度 \(story.strengthScore)")
                    EarnSocialMetricBlock(title: "任务", value: "\(story.tasks.filter(\.isCompleted).count)/\(story.tasks.count)", detail: "点开推进关系")
                }
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .opacity(0.92)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(EarnSocialPalette.yellow(0.20), lineWidth: 1)
                )
        )
        .shadow(color: EarnSocialPalette.yellow(0.08), radius: 12, y: 6)
    }

    private func header(title: String, symbol: String, badge: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.spareYellowInk)
                .frame(width: 36, height: 36)
                .background(EarnSocialPalette.yellow(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.spareCaptionSB)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("当前点击动作统一走 store.activeSheet / store.activeIcebreak / store.selectedLane。")
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Text(badge)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.spareYellowInk)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(EarnSocialPalette.yellow(0.16), in: Capsule())
        }
    }

    private func tagRow<S: Sequence>(_ tags: S) -> some View where S.Element == String {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(Array(tags), id: \.self) { tag in
                    Text(tag)
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(EarnSocialPalette.yellow(0.12), in: Capsule())
                }
            }
        }
    }
}

private struct EarnSocialMetricBlock: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.spareMicro)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(detail)
                .font(.spareMicro)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(EarnSocialPalette.yellow(0.10), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct EarnSocialActionButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.spareCaptionSB)
            }
            .foregroundColor(.primary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 10)
            .background(EarnSocialPalette.white(0.88), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(EarnSocialPalette.yellow(0.20), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct EarnSocialToastBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.spareYellowInk)

            Text(message)
                .font(.spareCaption)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(EarnSocialPalette.white(0.94), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(EarnSocialPalette.yellow(0.20), lineWidth: 1)
        )
        .shadow(color: EarnSocialPalette.black(0.08), radius: 12, y: 6)
    }
}

private struct EarnSocialLoadingStateView: View {
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.md) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.white)
                        .frame(height: 168)
                        .shimmer()
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xxxl)
        }
    }
}

private struct EarnSocialSheetHostView: View {
    let sheet: EarnSocialSheet
    @ObservedObject var store: EarnSocialExperienceStore

    var body: some View {
        switch sheet {
        case .market:
            EarnSocialMarketSheetView(store: store)
        case .personas:
            EarnSocialPersonaDeckSheetView(store: store)
        case .icebreak:
            EarnSocialIcebreakSheetView(store: store)
        case .trends:
            EarnSocialTrendBoardSheetView(store: store)
        case .arena:
            EarnSocialArenaSheetView(store: store)
        case .bond:
            EarnSocialBondSheetView(store: store)
        case .wallet:
            EarnSocialWalletSheetView(store: store)
        }
    }
}

private struct EarnSocialSheetScaffold<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content()
                .navigationTitle(title)
                .spareNavigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("关闭") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

private struct EarnSocialMarketSheetView: View {
    @ObservedObject var store: EarnSocialExperienceStore

    var body: some View {
        EarnSocialSheetScaffold(title: "意图市场") {
            Form {
                Section("Runtime 说明") {
                    Text("首页、草稿和发布动作现在都由 `EarnSocialExperienceStore.marketDraft` / `marketValidationMessage` / `marketSuccessMessage` 承接。")
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                }

                Section("赛道与模板") {
                    Picker("赛道", selection: Binding(
                        get: { store.marketDraft.lane },
                        set: { store.updateDraftLane($0) }
                    )) {
                        ForEach(EarnSocialLaneID.allCases) { lane in
                            Text(lane.title).tag(lane)
                        }
                    }

                    Picker("模板", selection: Binding(
                        get: { store.marketDraft.template.id },
                        set: { templateID in
                            guard let template = store.templatesByLane[store.marketDraft.lane]?.first(where: { $0.id == templateID }) else {
                                return
                            }
                            store.updateDraftTemplate(template)
                        }
                    )) {
                        ForEach(store.templatesByLane[store.marketDraft.lane] ?? []) { template in
                            Text(template.title).tag(template.id)
                        }
                    }

                    Picker("曝光方式", selection: Binding(
                        get: { store.marketDraft.visibility },
                        set: { store.updateDraftVisibility($0) }
                    )) {
                        ForEach(EarnIntentVisibilityMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }

                    Text(store.marketDraft.template.summary)
                        .font(.spareCaption)
                        .foregroundColor(.secondary)

                    Text(store.marketDraft.visibility.detail)
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                }

                Section("必填字段") {
                    ForEach(store.marketDraft.fields) { field in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(field.isRequired ? "\(field.label) *" : field.label)
                                .font(.spareCaptionSB)
                            TextField(field.placeholder, text: Binding(
                                get: { field.value },
                                set: { store.updateDraftField(id: field.id, value: $0) }
                            ))
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("补充说明")
                            .font(.spareCaptionSB)
                        TextField("把边界、节奏或补充要求写在这里", text: Binding(
                            get: { store.marketDraft.note },
                            set: { store.updateDraftNote($0) }
                        ), axis: .vertical)
                        .lineLimit(3...5)
                    }
                }

                if let validation = store.marketValidationMessage {
                    Section("校验") {
                        Text(validation)
                            .font(.spareCaption)
                            .foregroundColor(.red)
                    }
                }

                if let success = store.marketSuccessMessage {
                    Section("发布结果") {
                        Text(success)
                            .font(.spareCaption)
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Button("发布意图") {
                        store.publishDraft()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    Button("清空提示") {
                        store.clearMarketMessages()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }
}

private struct EarnSocialPersonaDeckSheetView: View {
    @ObservedObject var store: EarnSocialExperienceStore

    private var personas: [EarnPersonaCard] {
        store.visiblePersonas(for: store.selectedLane)
    }

    var body: some View {
        EarnSocialSheetScaffold(title: "推荐分身") {
            List {
                Section {
                    Text("当前只消费 `EarnSocialExperienceStore.visiblePersonas(for:)`，不再保留页面内另一套假卡池。")
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                }

                Section("当前赛道：\(store.selectedLane.title)") {
                    ForEach(personas) { persona in
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(persona.displayName)
                                        .font(.spareBodySB)
                                    Text(persona.publicBio)
                                        .font(.spareCaption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer(minLength: 0)

                                Text("match \(Int(persona.matchScore * 100))")
                                    .font(.spareMicro)
                                    .foregroundColor(.spareYellowInk)
                            }

                            Text(persona.expertiseTags.joined(separator: " · "))
                                .font(.spareMicro)
                                .foregroundColor(.secondary)

                            HStack {
                                Button("喜欢") {
                                    store.likePersona(persona)
                                }
                                Button("略过") {
                                    store.skipPersona(persona)
                                }
                                Button("发起破冰") {
                                    store.startIcebreak(with: persona)
                                }
                            }
                            .font(.spareCaptionSB)
                        }
                        .padding(.vertical, 6)
                    }
                }

                if let message = store.personaDeckMessage {
                    Section("结果") {
                        Text(message)
                            .font(.spareCaption)
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Button("重置已看缓存") {
                        store.resetPersonaCache()
                    }
                }
            }
        }
    }
}

private struct EarnSocialIcebreakSheetView: View {
    @ObservedObject var store: EarnSocialExperienceStore

    var body: some View {
        EarnSocialSheetScaffold(title: "双 Agent 破冰") {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    if let session = store.activeIcebreak {
                        EarnSocialSheetCard(title: "当前会话", subtitle: session.stage.label) {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                Text(session.summary)
                                    .font(.spareBody)
                                Text("对象：\(session.counterpartName) · 兼容度 \(Int(session.compatibilityScore * 100))")
                                    .font(.spareCaption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        EarnSocialSheetCard(title: "授权状态", subtitle: session.auditPassed ? "审计已通过" : "审计待通过") {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                HStack {
                                    Button(session.initiatorGranted ? "撤回我的授权" : "我同意真人接手") {
                                        store.updateConsent(side: .initiator, granted: !session.initiatorGranted)
                                    }
                                    Button(session.counterpartGranted ? "撤回对方授权" : "标记对方已授权") {
                                        store.updateConsent(side: .counterpart, granted: !session.counterpartGranted)
                                    }
                                }
                                .font(.spareCaptionSB)

                                Button("拦截并停留在分身层") {
                                    store.updateConsent(side: .initiator, granted: false)
                                }
                                .font(.spareCaptionSB)
                            }
                        }

                        EarnSocialSheetCard(title: "对话记录", subtitle: "runtime feed") {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                ForEach(session.messages) { message in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(message.actor.displayName)
                                            .font(.spareCaptionSB)
                                        Text(message.content)
                                            .font(.spareCaption)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    } else {
                        EarnSocialSheetCard(title: "尚未发起破冰", subtitle: store.icebreakPrompt.headline) {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                Text(store.icebreakPrompt.body)
                                    .font(.spareBody)
                                if let firstPersona = store.visiblePersonas(for: store.selectedLane).first {
                                    Button("用 \(firstPersona.displayName) 试一轮") {
                                        store.startIcebreak(with: firstPersona)
                                    }
                                    .font(.spareCaptionSB)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.lg)
            }
        }
    }
}

private struct EarnSocialTrendBoardSheetView: View {
    @ObservedObject var store: EarnSocialExperienceStore

    var body: some View {
        EarnSocialSheetScaffold(title: "热点趋势") {
            List {
                Section {
                    Text("趋势奖励、领取状态和 lane 选择都由 `trendBoard + selectedLane` 统一承接。")
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                }

                ForEach(store.trendBoard) { trend in
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack {
                            Text(trend.eventTitle)
                                .font(.spareBodySB)
                            Spacer()
                            Text(trend.lane.title)
                                .font(.spareMicro)
                                .foregroundColor(.secondary)
                        }

                        Text(trend.eventSummary)
                            .font(.spareCaption)
                            .foregroundColor(.secondary)

                        HStack {
                            Text("热度 \(String(format: "%.1f", trend.heatScore))")
                            Text("供需差 \(String(format: "%.1f", trend.supplyGapScore))")
                            Text("奖励 +\(trend.rewardAmount)")
                        }
                        .font(.spareMicro)
                        .foregroundColor(.secondary)

                        Button(trend.isClaimed ? "已领取" : "领取奖励") {
                            store.claimTrendReward(for: trend.lane)
                        }
                        .disabled(trend.isClaimed)
                        .font(.spareCaptionSB)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }
}

private struct EarnSocialArenaSheetView: View {
    @ObservedObject var store: EarnSocialExperienceStore

    var body: some View {
        EarnSocialSheetScaffold(title: "竞技场") {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    if let match = store.arenaMatch {
                        EarnSocialSheetCard(title: match.theme, subtitle: match.status == .active ? "对战中" : "已结算") {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                Text(match.summary)
                                    .font(.spareBody)
                                Text("\(match.challenger.displayName) vs \(match.opponent.displayName)")
                                    .font(.spareCaption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        EarnSocialSheetCard(title: "投票", subtitle: "当前只写回 `selectedArenaVote + arenaMatch.votes`") {
                            HStack {
                                Button("投 \(match.challenger.displayName)") {
                                    store.castArenaVote(.challenger)
                                }
                                Button("投 \(match.opponent.displayName)") {
                                    store.castArenaVote(.opponent)
                                }
                                Button("结算") {
                                    store.resolveArenaIfNeeded()
                                }
                            }
                            .font(.spareCaptionSB)
                        }

                        EarnSocialSheetCard(title: "回合记录", subtitle: "共 \(match.rounds.count) 轮") {
                            VStack(alignment: .leading, spacing: Spacing.md) {
                                ForEach(match.rounds) { round in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("第 \(round.index) 轮 · \(round.prompt)")
                                            .font(.spareCaptionSB)
                                        Text(round.summary)
                                            .font(.spareCaption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    } else {
                        EarnSocialSheetCard(title: "当前没有竞技场", subtitle: "arena filter 会因此报错并阻止进入空路由。") {
                            Text("切回其它 quick filter，或者等 store 注入新的 arenaMatch。")
                                .font(.spareBody)
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.lg)
            }
        }
    }
}

private struct EarnSocialBondSheetView: View {
    @ObservedObject var store: EarnSocialExperienceStore

    var body: some View {
        EarnSocialSheetScaffold(title: "关系任务") {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    if let story = store.bondStory {
                        EarnSocialSheetCard(title: story.memorialTitle, subtitle: story.level.title) {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                Text(story.memorialSummary)
                                    .font(.spareBody)
                                Text("目标对象：\(story.counterpartName) · 强度 \(story.strengthScore)")
                                    .font(.spareCaption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        EarnSocialSheetCard(title: "任务推进", subtitle: "点击会直接调用 `advanceBondTask(_:)`") {
                            VStack(alignment: .leading, spacing: Spacing.md) {
                                ForEach(story.tasks) { task in
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(task.title)
                                                .font(.spareCaptionSB)
                                            Spacer()
                                            Text("\(min(task.progressCount, task.targetCount))/\(task.targetCount)")
                                                .font(.spareMicro)
                                                .foregroundColor(.secondary)
                                        }
                                        Text(task.summary)
                                            .font(.spareCaption)
                                            .foregroundColor(.secondary)
                                        Button(task.isCompleted ? "已完成" : "推进一次") {
                                            store.advanceBondTask(task)
                                        }
                                        .disabled(task.isCompleted)
                                        .font(.spareCaptionSB)
                                    }
                                }
                            }
                        }

                        if !story.milestones.isEmpty {
                            EarnSocialSheetCard(title: "里程碑", subtitle: "已完成 \(story.milestones.count) 项") {
                                VStack(alignment: .leading, spacing: Spacing.sm) {
                                    ForEach(story.milestones) { milestone in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(milestone.title)
                                                .font(.spareCaptionSB)
                                            Text(milestone.summary)
                                                .font(.spareCaption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        EarnSocialSheetCard(title: "关系任务未生成", subtitle: "需要先完成双 Agent 授权") {
                            Text("只有当 `activeIcebreak` 进入真人可接手阶段，store 才会创建 `bondStory`。")
                                .font(.spareBody)
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.lg)
            }
        }
    }
}

private struct EarnSocialWalletSheetView: View {
    @ObservedObject var store: EarnSocialExperienceStore

    var body: some View {
        EarnSocialSheetScaffold(title: "钱包与流水") {
            List {
                Section("余额") {
                    Text("当前余额：\(store.wallet.balance)")
                    Text("冻结余额：\(store.wallet.frozenBalance)")
                    Text("累计赚得：\(store.wallet.lifetimeEarned)")
                    Text("累计支出：\(store.wallet.lifetimeSpent)")
                    Text("今日可赚：\(store.wallet.todayEarnable)")
                    Text("连续活跃：\(store.wallet.streakDays) 天")
                }

                Section("流水") {
                    ForEach(store.ledgerEntries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(entry.title)
                                    .font(.spareBodySB)
                                Spacer()
                                Text(entry.amount >= 0 ? "+\(entry.amount)" : "\(entry.amount)")
                                    .font(.spareCaptionSB)
                            }
                            Text(entry.detail)
                                .font(.spareCaption)
                                .foregroundColor(.secondary)
                            Text("\(EarnSocialDateFormatting.dayTimeString(entry.timestamp)) · \(entry.statusLabel)")
                                .font(.spareMicro)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
}

private struct EarnSocialSheetCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.spareBodySB)
                    Text(subtitle)
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 0)
            }

            content()
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
                .opacity(0.92)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(EarnSocialPalette.yellow(0.18), lineWidth: 1)
                )
        )
    }
}

private enum EarnSocialDateFormatting {
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dayTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter
    }()

    static func timeString(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    static func dayTimeString(_ date: Date) -> String {
        dayTimeFormatter.string(from: date)
    }
}

#if DEBUG
#Preview {
    EarnSocialHomeView()
}
#endif
