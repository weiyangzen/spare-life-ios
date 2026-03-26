// XianxiaHomeView.swift
// Spare Life – 咸虾 tab main page
// Blueprint §3.1: 扫码进场景、双列瀑布流、分类 chips
// UIUX lane – slot 2

import SwiftUI

// MARK: - XianxiaHomeView

struct XianxiaHomeView: View {
    @StateObject private var vm = XianxiaHomeViewModel()
    @State private var showScanner = false
    @State private var selectedCategory: SceneCategory = .all
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    // ── Top nav ──────────────────────────────────────────
                    topBar

                    // ── Search + category chips ──────────────────────────
                    filterRow
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)

                    // ── "最近扫过" or "现在最热场景" horizontal strip ──────
                    if !vm.recentScenes.isEmpty {
                        recentScenesStrip
                            .padding(.bottom, Spacing.sm)
                    }

                    Divider()

                    // ── Main waterfall feed ──────────────────────────────
                    feedBody
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showScanner) {
                QRScanView { target in
                    showScanner = false
                    vm.handleScanTarget(target)
                }
            }
            .navigationDestination(item: $vm.activeScene) { scene in
                SceneTopicView(scene: scene,
                               isFromScan: vm.scannedSceneIDs.contains(scene.id))
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(alignment: .center) {
            Text("咸虾")
                .font(.spareTitle1)
                .foregroundColor(.primary)

            Spacer()

            Button {
                showScanner = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.spareYellow)
                        .frame(width: 40, height: 40)
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.spareDark)
                }
            }
            .accessibilityLabel("扫码进入场景")
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.sm)
    }

    // MARK: - Search + Filter Row

    private var filterRow: some View {
        VStack(spacing: Spacing.sm) {
            // Search bar
            HStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索场景、话题或人物", text: $searchText)
                    .font(.spareBody)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(Spacing.md)
            .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: CornerRadius.md))

            // Category chip strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(SceneCategory.allCases) { cat in
                        CategoryChip(
                            category: cat,
                            isSelected: selectedCategory == cat
                        ) {
                            UISelectionFeedbackGenerator().selectionChanged()
                            withAnimation(.spareFast) {
                                selectedCategory = cat
                            }
                        }
                    }
                }
                .padding(.horizontal, 1)   // allow shadow breathing room
            }
        }
    }

    // MARK: - Recent Scenes Horizontal Strip

    private var recentScenesStrip: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("最近扫过")
                .font(.spareCaptionSB)
                .foregroundColor(.secondary)
                .padding(.horizontal, Spacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.md) {
                    ForEach(vm.recentScenes) { scene in
                        RecentScenePill(scene: scene) {
                            vm.activeScene = scene
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }
        }
    }

    // MARK: - Feed Body

    @ViewBuilder
    private var feedBody: some View {
        let filtered = vm.filteredFeed(category: selectedCategory, search: searchText)

        switch vm.feedState {
        case .loading:
            WaterfallSkeleton(count: 8)
                .transition(.opacity)

        case .empty:
            ScrollView {
                EmptyStateView(
                    icon: "qrcode.viewfinder",
                    title: "扫码探索周边场景",
                    message: "扫一扫"龙虾码"，进入餐厅、活动、品牌等场景，看大家都在说什么。",
                    actionLabel: "扫码试试",
                    action: { showScanner = true }
                )
                .padding(.top, Spacing.xxxl)
            }

        case .error(let msg):
            ScrollView {
                ErrorStateView(
                    message: msg,
                    cached: false,
                    retry: { vm.refresh() }
                )
                .padding(.top, Spacing.xxxl)
            }

        case .loadedFromCache(let items):
            feedList(items: items, showCacheBanner: true)

        case .loaded(let items):
            feedList(items: filtered, showCacheBanner: false)

        case .idle:
            WaterfallSkeleton(count: 6)
                .transition(.opacity)
                .onAppear { vm.loadFeed() }
        }
    }

    private func feedList(items: [SceneFeedItem], showCacheBanner: Bool) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                if showCacheBanner {
                    CacheBanner()
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                }

                FeedSectionHeader(
                    title: "场景卡片流",
                    subtitle: "\(items.count) 条内容",
                    trailingLabel: nil
                )
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.xs)

                WaterfallLayout(columns: 2, spacing: Spacing.md) {
                    ForEach(items) { item in
                        feedCard(for: item)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.92).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.xxxl)
            }
        }
        .refreshable {
            await vm.refreshAsync()
        }
    }

    @ViewBuilder
    private func feedCard(for item: SceneFeedItem) -> some View {
        switch item {
        case .summary(let card):
            SceneSummaryCardView(card: card) {
                vm.openSceneForSummary(card)
            }

        case .hotTake(let card):
            HotTakeCardView(card: card)

        case .avatarRadar(let card):
            AvatarRadarCardView(card: card) {
                vm.initiateStrangerSocial(from: card.sceneID)
            }

        case .socialPrompt(let card):
            SceneSocialPromptCardView(card: card) {
                vm.initiateStrangerSocial(from: card.sceneID)
            }
        }
    }
}

// MARK: - CategoryChip

private struct CategoryChip: View {
    let category: SceneCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: category.icon)
                    .font(.system(size: 12, weight: .medium))
                Text(category.rawValue)
                    .font(.spareCaption)
            }
            .foregroundColor(isSelected ? .spareDark : .primary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? Color.spareYellow : Color(.systemGray5))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - RecentScenePill

private struct RecentScenePill: View {
    let scene: Scene
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                ZStack {
                    Color.avatarGradient(seed: abs(scene.id.hashValue))
                    Image(systemName: scene.category.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                }
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                .cardShadow()

                Text(scene.name)
                    .font(.spareMicro)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(width: 60)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CacheBanner

private struct CacheBanner: View {
    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(.emotionNeutral)
            Text("网络不佳，已显示上次缓存内容")
                .font(.spareCaption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(Spacing.md)
        .background(Color(.systemYellow).opacity(0.12), in: RoundedRectangle(cornerRadius: CornerRadius.sm))
    }
}

// MARK: - XianxiaHomeViewModel

@MainActor
final class XianxiaHomeViewModel: ObservableObject {
    @Published var feedState: SceneFeedState = .idle
    @Published var recentScenes: [Scene] = []
    @Published var activeScene: Scene? = nil
    /// Tracks scene IDs entered via QR scan so SceneTopicView can show
    /// the scan-entry banner on first arrival.
    var scannedSceneIDs: Set<String> = []

    // Inject real repository here once FUNC lane wires it up.
    // For now the VM exposes the full state machine so UI is driven correctly.

    func loadFeed() {
        guard case .idle = feedState else { return }
        feedState = .loading
        // Will be replaced by real repository call when FUNC lane implements SceneRepository.
        // Show empty state by default so UI path is exercised without fake data.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.feedState = .empty
        }
    }

    func refresh() {
        feedState = .loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.feedState = .empty
        }
    }

    func refreshAsync() async {
        feedState = .loading
        try? await Task.sleep(nanoseconds: 600_000_000)
        feedState = .empty
    }

    func handleScanTarget(_ target: ScanTarget) {
        // Add to recent scenes and navigate
        let scene = Scene(
            id: target.sceneID,
            name: target.displayName,
            category: target.sceneCategory,
            description: nil,
            coverImageURL: nil,
            participantCount: 0,
            activeAvatarCount: 0,
            lastActivityAt: Date()
        )
        if !recentScenes.contains(scene) {
            recentScenes.insert(scene, at: 0)
            if recentScenes.count > 8 { recentScenes = Array(recentScenes.prefix(8)) }
        }
        // Mark this scene as entered via scan so the topic view shows entry banner.
        scannedSceneIDs.insert(scene.id)
        activeScene = scene
    }

    func openSceneForSummary(_ card: SceneSummaryCard) {
        // FUNC lane will resolve the scene by sceneID from the repository.
        // Placeholder navigation state for now.
    }

    func initiateStrangerSocial(from sceneID: String) {
        // Navigation handled by SceneTopicView; parent VM just needs to know.
    }

    func filteredFeed(category: SceneCategory, search: String) -> [SceneFeedItem] {
        guard case .loaded(let items) = feedState else { return [] }
        return items // FUNC lane will add real filtering when items are real.
    }
}
