// MyProfileView.swift
// Spare Life – 我的 · My Profile & Avatar Public Profile
// Blueprint §7 我的 · [UIUX] My Profile (id: 37f88205febb)
// Blueprint §统一UI 我的首页卡片化 (line:1154) [UIUX]
// UIUX lane – slot 2

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Models

struct UserProfile: Identifiable {
    var id: String = "me"
    var displayName: String
    var handle: String
    var bio: String
    var avatarSeed: Int
    var energyBalance: Int
    var socialScore: Int
    var joinedDate: Date
    var isVerified: Bool = false
}

struct AvatarPublicProfile: Identifiable {
    var id: String
    var nickname: String
    var tagline: String
    var personalityTraits: [String]
    var isPubliclyVisible: Bool
    var visibleFields: Set<VisibilityField>

    enum VisibilityField: String, CaseIterable {
        case name        = "昵称"
        case bio         = "简介"
        case personality = "人格特征"
        case syncScore   = "同步度"
        case memories    = "记忆"
        case socialStats = "社交数据"
    }
}

enum ProfileLoadState {
    case idle, loading, loaded, error(String)
}

// MARK: - Store

@MainActor
final class MyProfileStore: ObservableObject {
    @Published var loadState: ProfileLoadState = .idle
    @Published var profile: UserProfile? = nil
    @Published var avatarProfile: AvatarPublicProfile? = nil
    @Published var editingProfile = false
    @Published var editingAvatar = false
    @Published var shareSheetActive = false
    @Published private(set) var xianrenLoadState: MyProfileXianrenLoadState = .idle
    @Published private(set) var masterStats: MyProfileMasterStats = .empty
    @Published private(set) var earnSocialStats: MyProfileEarnSocialStats = .mock
    @Published private(set) var messageStats: MyProfileMessageStats = .mock

    private let xianrenStatsRepository = MyProfileXianrenStatsRepository()
    private let masterStatsProvider = MyProfileMasterStatsProvider()

    func load() {
        guard case .idle = loadState else { return }
        loadState = .loading
        masterStats = masterStatsProvider.load()
        earnSocialStats = .mock
        messageStats = .mock
        xianrenLoadState = .loading
        Task {
            async let xianrenRefresh: Void = refreshXianrenStats()
            try? await Task.sleep(nanoseconds: 600_000_000)
            profile = UserProfile(
                displayName: "陈一帆",
                handle: "@yifan_chen",
                bio: "热爱生活，探索 AI 陪伴与社交的边界。",
                avatarSeed: 42,
                energyBalance: 2_480,
                socialScore: 87,
                joinedDate: Calendar.current.date(byAdding: .month, value: -4, to: .now) ?? .now
            )
            avatarProfile = AvatarPublicProfile(
                id: "avatar-me",
                nickname: "分身・一帆",
                tagline: "我的 AI 延伸，负责替我破冰。",
                personalityTraits: ["好奇", "直率", "创意"],
                isPubliclyVisible: true,
                visibleFields: [.name, .bio, .personality, .syncScore]
            )
            loadState = .loaded
            await xianrenRefresh
        }
    }

    func reload() {
        loadState = .idle
        load()
    }

    private func refreshXianrenStats() async {
        do {
            let stats = try await xianrenStatsRepository.loadLiveStats()
            xianrenLoadState = .live(stats)
        } catch {
            let message = error.xianxiaUserFacingMessage
            if let cachedStats = await xianrenStatsRepository.loadCachedStats() {
                xianrenLoadState = .cached(cachedStats, message: message)
            } else {
                xianrenLoadState = .failure(message)
            }
        }
    }
}

// MARK: - Root View

struct MyProfileView: View {
    @StateObject private var store = MyProfileStore()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                contentBody
            }
            .spareNavigationBarHidden(true)
        }
        .task { store.load() }
    }

    @ViewBuilder
    private var contentBody: some View {
        switch store.loadState {
        case .idle, .loading:
            ProfileSkeletonView()
        case .loaded:
            if let profile = store.profile {
                ProfileScrollView(store: store, profile: profile)
            }
        case .error(let msg):
            ErrorStateView(message: msg, retry: { store.reload() })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Loaded Scroll View

private struct ProfileScrollView: View {
    @ObservedObject var store: MyProfileStore
    let profile: UserProfile

    var body: some View {
        GeometryReader { proxy in
            let layout = MyProfileDashboardLayout.shared(for: proxy.size.width)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ProfileHeroSection(store: store, profile: profile)
                        .padding(.bottom, Spacing.lg)

                    VStack(spacing: Spacing.md) {
                        statsRow(layout: layout)
                        overviewSection(layout: layout)

                        if let avatar = store.avatarProfile {
                            AvatarPublicProfileCard(avatar: avatar) {
                                store.editingAvatar = true
                            }
                        }

                        // Feature card grid: SyncScore / Personality / Memory / Privacy
                        featureCardGrid(layout: layout)

                        actionButtons
                    }
                    .padding(.horizontal, layout.horizontalPadding)
                    .padding(.bottom, Spacing.xxxl + 32)
                }
            }
        }
        .refreshable { store.reload() }
        .sheet(isPresented: $store.editingProfile) {
            EditProfileSheet(profile: profile)
                .presentationDragIndicator(.visible)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $store.editingAvatar) {
            if let avatar = store.avatarProfile {
                EditAvatarVisibilitySheet(avatar: avatar)
                    .presentationDragIndicator(.visible)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private func statsRow(layout: MyProfileDashboardLayout) -> some View {
        LazyVGrid(columns: layout.gridItems, alignment: .leading, spacing: layout.cardSpacing) {
            ProfileStatCard(
                icon: "bolt.circle.fill",
                iconColor: .spareYellow,
                value: "\(profile.energyBalance)",
                label: "闲能",
                minimumHeight: layout.minimumCardHeight
            )
            ProfileStatCard(
                icon: "person.2.fill",
                iconColor: .blue,
                value: "\(profile.socialScore)",
                label: "社交分",
                minimumHeight: layout.minimumCardHeight
            )
            ProfileStatCard(
                icon: "calendar",
                iconColor: .secondary,
                value: daysSince(profile.joinedDate),
                label: "入驻天",
                minimumHeight: layout.minimumCardHeight
            )
        }
    }

    private func overviewSection(layout: MyProfileDashboardLayout) -> some View {
        ProfileOverviewSection(
            layout: layout,
            xianrenLoadState: store.xianrenLoadState,
            masterStats: store.masterStats,
            earnSocialStats: store.earnSocialStats,
            messageStats: store.messageStats
        )
    }

    // MARK: - Feature Card Grid (同步度卡 / 人格卡 / 记忆卡 / 隐私卡)

    private func featureCardGrid(layout: MyProfileDashboardLayout) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("我的功能")
                .font(.spareTitle3)
                .padding(.top, Spacing.xs)

            LazyVGrid(columns: layout.gridItems, alignment: .leading, spacing: layout.cardSpacing) {
                syncScoreCard(minimumHeight: layout.minimumCardHeight)
                personalityCard(minimumHeight: layout.minimumCardHeight)
                memoryCard(minimumHeight: layout.minimumCardHeight)
                privacyCard(minimumHeight: layout.minimumCardHeight)
            }
        }
    }

    // MARK: Sync Score Card (同步度卡)

    private func syncScoreCard(minimumHeight: CGFloat) -> some View {
        NavigationLink(destination: SyncScoreDashboardView()) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 18))
                    Text("同步度")
                        .font(.spareCaptionSB)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }

                // Circular progress indicator (72%)
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: 0.72)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 1) {
                        Text("72%")
                            .font(.spareTitle3)
                        Text("像我度")
                            .font(.spareMicro)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 64, height: 64)
                .frame(maxWidth: .infinity)

                Text("3 个训练任务待完成")
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(Spacing.md)
            .myProfileStage2CardChrome(minimumHeight: minimumHeight)
        }
        .buttonStyle(CardPressStyle())
    }

    // MARK: Personality Card (人格卡)

    private func personalityCard(minimumHeight: CGFloat) -> some View {
        NavigationLink(destination: AwakeningPersonalityView()) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)
                        .font(.system(size: 18))
                    Text("人格")
                        .font(.spareCaptionSB)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }

                // Awakening level badge
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 13))
                    Text("觉醒 Lv.3")
                        .font(.spareCaption)
                        .foregroundColor(.primary)
                }

                // Trait pills
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xs) {
                        PillTag(label: "好奇", color: .purple)
                        PillTag(label: "直率", color: .purple)
                    }
                    PillTag(label: "创意", color: .purple)
                }

                Text("2 个面具已配置")
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }
            .padding(Spacing.md)
            .myProfileStage2CardChrome(minimumHeight: minimumHeight)
        }
        .buttonStyle(CardPressStyle())
    }

    // MARK: Memory Card (记忆卡)

    private func memoryCard(minimumHeight: CGFloat) -> some View {
        NavigationLink(destination: MemoryPalaceView()) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "brain")
                        .foregroundColor(.teal)
                        .font(.system(size: 18))
                    Text("记忆宫殿")
                        .font(.spareCaptionSB)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }

                HStack(alignment: .lastTextBaseline, spacing: Spacing.xs) {
                    Text("248")
                        .font(.spareTitle2)
                        .foregroundColor(.teal)
                    Text("条记忆")
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                }

                // Category breakdown
                VStack(alignment: .leading, spacing: 3) {
                    memoryBar(label: "对话", fraction: 0.6, color: .teal)
                    memoryBar(label: "行动", fraction: 0.25, color: .blue)
                    memoryBar(label: "情绪", fraction: 0.15, color: .pink)
                }
            }
            .padding(Spacing.md)
            .myProfileStage2CardChrome(minimumHeight: minimumHeight)
        }
        .buttonStyle(CardPressStyle())
    }

    private func memoryBar(label: String, fraction: CGFloat, color: Color) -> some View {
        HStack(spacing: Spacing.xs) {
            Text(label)
                .font(.spareMicro)
                .foregroundColor(.secondary)
                .frame(width: 28, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5)).frame(height: 4)
                    Capsule().fill(color).frame(width: geo.size.width * fraction, height: 4)
                }
            }
            .frame(height: 4)
        }
    }

    // MARK: Privacy Card (隐私卡)

    private func privacyCard(minimumHeight: CGFloat) -> some View {
        NavigationLink(destination: PrivacyLocalBackendView()) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 18))
                    Text("隐私")
                        .font(.spareCaptionSB)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }

                // Local backend status badge
                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(Color.emotionPositive)
                        .frame(width: 6, height: 6)
                    Text("本地后端运行中")
                        .font(.spareMicro)
                        .foregroundColor(.emotionPositive)
                }

                // Storage used
                HStack(alignment: .lastTextBaseline, spacing: Spacing.xs) {
                    Text("12.4")
                        .font(.spareTitle3)
                    Text("MB")
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(.systemGray5)).frame(height: 4)
                        Capsule().fill(Color.emotionPositive)
                            .frame(width: geo.size.width * 0.12, height: 4)
                    }
                }
                .frame(height: 4)

                Text("无云端上传")
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }
            .padding(Spacing.md)
            .myProfileStage2CardChrome(minimumHeight: minimumHeight)
        }
        .buttonStyle(CardPressStyle())
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: Spacing.sm) {
            Button {
                store.editingProfile = true
            } label: {
                Label("编辑资料", systemImage: "pencil")
                    .font(.spareBodySB)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(Color.spareYellow, in: RoundedRectangle(cornerRadius: CornerRadius.md))
                    .foregroundColor(.black)
            }

            Button {
                store.shareSheetActive = true
            } label: {
                Label("分享主页", systemImage: "square.and.arrow.up")
                    .font(.spareBodySB)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
                    .foregroundColor(.primary)
            }
        }
    }

    private func daysSince(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: .now).day ?? 0
        return "\(days)"
    }
}

// MARK: - Hero Section

private struct ProfileHeroSection: View {
    @ObservedObject var store: MyProfileStore
    let profile: UserProfile

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Banner gradient
            LinearGradient(
                colors: [Color.spareYellow.opacity(0.6), Color.blue.opacity(0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 160)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .bottom) {
                    AvatarView(name: profile.displayName, size: 80)
                        .overlay(
                            Circle()
                                .stroke(Color(.systemBackground), lineWidth: 3)
                        )
                        .offset(y: 32)

                    Spacer()

                    if profile.isVerified {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.blue)
                            Text("已认证")
                                .font(.spareMicro)
                        }
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.bottom, 4)
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }
        }
        .padding(.top, 48)

        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Text(profile.displayName)
                    .font(.spareTitle2)
                Text(profile.handle)
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
            }

            if !profile.bio.isEmpty {
                Text(profile.bio)
                    .font(.spareBody)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.top, 40)
        .padding(.horizontal, Spacing.lg)
    }
}

// MARK: - Stat Card

private struct ProfileStatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    let minimumHeight: CGFloat

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(iconColor)
            Text(value)
                .font(.spareTitle3)
            Text(label)
                .font(.spareMicro)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.lg)
        .myProfileStage2CardChrome(minimumHeight: minimumHeight)
    }
}

// MARK: - Stage 2 Overview

private struct ProfileOverviewSection: View {
    let layout: MyProfileDashboardLayout
    let xianrenLoadState: MyProfileXianrenLoadState
    let masterStats: MyProfileMasterStats
    let earnSocialStats: MyProfileEarnSocialStats
    let messageStats: MyProfileMessageStats

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("总览")
                .font(.spareTitle3)
                .padding(.top, Spacing.xs)

            LazyVGrid(columns: layout.gridItems, alignment: .leading, spacing: layout.cardSpacing) {
                xianrenCard
                xianliaoCard
                earnSocialCard
                messageCard
            }
        }
    }

    private var xianrenCard: some View {
        ProfileOverviewCard(
            title: "闲人",
            icon: "person.3.sequence.fill",
            accentColor: .blue,
            minimumHeight: layout.minimumCardHeight,
            footer: xianrenFooter
        ) {
            switch xianrenLoadState {
            case .idle, .loading:
                ProfileOverviewLoadingState(text: "正在拉取 ClawDB topics…")
            case .live(let stats):
                ProfileOverviewMetricGrid(metrics: [
                    .init(value: stats.channelCount.formatted(), label: "渠道数"),
                    .init(value: stats.topicCount.formatted(), label: "话题数"),
                    .init(value: stats.uniqueIDCount.formatted(), label: "独立 ID"),
                    .init(value: stats.mentionCount.formatted(), label: "被 Mention")
                ])
            case .cached(let stats, _):
                ProfileOverviewMetricGrid(metrics: [
                    .init(value: stats.channelCount.formatted(), label: "渠道数"),
                    .init(value: stats.topicCount.formatted(), label: "话题数"),
                    .init(value: stats.uniqueIDCount.formatted(), label: "独立 ID"),
                    .init(value: stats.mentionCount.formatted(), label: "被 Mention")
                ])
            case .failure(let message):
                ProfileOverviewMessageState(icon: "wifi.exclamationmark", text: message)
            }
        }
    }

    private var xianliaoCard: some View {
        ProfileOverviewCard(
            title: "闲聊",
            icon: "bubble.left.and.bubble.right.fill",
            accentColor: .orange,
            minimumHeight: layout.minimumCardHeight,
            footer: xianliaoFooter
        ) {
            ProfileOverviewMetricGrid(metrics: [
                .init(value: masterStats.masterCount.formatted(), label: "交互人数"),
                .init(value: masterStats.interactionCount.formatted(), label: "交互次数")
            ])
        }
    }

    private var earnSocialCard: some View {
        ProfileOverviewCard(
            title: "赚闲能",
            icon: "sparkles.rectangle.stack.fill",
            accentColor: .green,
            minimumHeight: layout.minimumCardHeight,
            footer: "当前批次允许 mock，先承接人数、次数和个人风格描述。"
        ) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ProfileOverviewMetricGrid(metrics: [
                    .init(value: earnSocialStats.participantCount.formatted(), label: "交互人数"),
                    .init(value: earnSocialStats.interactionCount.formatted(), label: "交互次数")
                ])

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("个人赚能风格")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                    Text(earnSocialStats.styleDescription)
                        .font(.spareCaption)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Spacing.sm)
                .background(
                    Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: CornerRadius.sm)
                )
            }
        }
    }

    private var messageCard: some View {
        ProfileOverviewCard(
            title: "消息",
            icon: "message.fill",
            accentColor: .purple,
            minimumHeight: layout.minimumCardHeight,
            footer: "当前批次允许 mock，先承接真人 / 分身互动统计。"
        ) {
            ProfileOverviewMetricGrid(metrics: [
                .init(value: messageStats.selfHumanInteractionCount.formatted(), label: "本人真人互动"),
                .init(value: messageStats.selfAvatarOutboundCount.formatted(), label: "本人分身对外"),
                .init(value: messageStats.outboundHumanInteractionCount.formatted(), label: "对外真人互动"),
                .init(value: messageStats.avatarToAvatarInteractionCount.formatted(), label: "对外分身互聊")
            ])
        }
    }

    private var xianrenFooter: String {
        switch xianrenLoadState {
        case .idle, .loading:
            return "实时读取 ClawDB topics，并基于 topicPath / summary 聚合指标。"
        case .live(let stats):
            if let updated = relativeTimeLabel(for: stats.latestTopicAt) {
                return "实时读取 ClawDB topics · \(updated)"
            }
            return "实时读取 ClawDB topics。"
        case .cached(let stats, let message):
            if let updated = relativeTimeLabel(for: stats.latestTopicAt) {
                return "ClawDB 拉取失败，已回退缓存 · \(updated) · \(message)"
            }
            return "ClawDB 拉取失败，已回退缓存 · \(message)"
        case .failure(let message):
            return message
        }
    }

    private var xianliaoFooter: String {
        guard masterStats.masterCount > 0 || masterStats.interactionCount > 0 else {
            return "来自本地大师会话归档，当前还没有历史交互。"
        }

        if let updated = relativeTimeLabel(for: masterStats.latestInteractionAt) {
            return "来自本地大师会话归档 · \(updated)"
        }
        return "来自本地大师会话归档。"
    }

    private func relativeTimeLabel(for date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "最近更新 \(formatter.localizedString(for: date, relativeTo: Date()))"
    }
}

private struct ProfileOverviewCard<Content: View>: View {
    let title: String
    let icon: String
    let accentColor: Color
    let minimumHeight: CGFloat
    let footer: String?
    private let content: () -> Content

    init(
        title: String,
        icon: String,
        accentColor: Color,
        minimumHeight: CGFloat,
        footer: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.accentColor = accentColor
        self.minimumHeight = minimumHeight
        self.footer = footer
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(accentColor)
                Text(title)
                    .font(.spareCaptionSB)
                Spacer()
            }

            content()

            if let footer, !footer.isEmpty {
                Text(footer)
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.md)
        .myProfileStage2CardChrome(minimumHeight: minimumHeight)
    }
}

private struct ProfileOverviewMetricGrid: View {
    let metrics: [ProfileOverviewMetric]

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.sm),
        GridItem(.flexible(), spacing: Spacing.sm)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Spacing.sm) {
            ForEach(metrics) { metric in
                VStack(alignment: .leading, spacing: 4) {
                    Text(metric.value)
                        .font(.spareTitle3)
                        .foregroundColor(.primary)
                    Text(metric.label)
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Spacing.sm)
                .padding(.horizontal, Spacing.sm)
                .background(
                    Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: CornerRadius.sm)
                )
            }
        }
    }
}

private struct MyProfileStage2CardModifier: ViewModifier {
    let minimumHeight: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .topLeading)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(Color.cardStroke, lineWidth: 0.5)
            )
            .cardShadow()
    }
}

private extension View {
    func myProfileStage2CardChrome(minimumHeight: CGFloat) -> some View {
        modifier(MyProfileStage2CardModifier(minimumHeight: minimumHeight))
    }
}

private struct ProfileOverviewMetric: Identifiable {
    let value: String
    let label: String

    var id: String { label }
}

private struct ProfileOverviewLoadingState: View {
    let text: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ProgressView()
                .controlSize(.small)
            Text(text)
                .font(.spareCaption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Spacing.md)
    }
}

private struct ProfileOverviewMessageState: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
            Text(text)
                .font(.spareCaption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Avatar Public Profile Card

private struct AvatarPublicProfileCard: View {
    let avatar: AvatarPublicProfile
    let onEdit: () -> Void

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "person.crop.circle.badge.fill")
                            .foregroundColor(.purple)
                        Text("分身公开资料")
                            .font(.spareBodySB)
                    }
                    Text(avatar.nickname)
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VisibilityBadge(isPublic: avatar.isPubliclyVisible)

                Button(action: onEdit) {
                    Image(systemName: "pencil.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.spareYellow)
                }
            }

            Text(avatar.tagline)
                .font(.spareBody)

            // Personality traits
            FlowTagsView(tags: avatar.personalityTraits)

            // Visible fields disclosure
            Button {
                withAnimation(.spareSpring) { expanded.toggle() }
            } label: {
                HStack {
                    Text("可见字段")
                        .font(.spareCaptionSB)
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }
            }

            if expanded {
                VStack(spacing: Spacing.sm) {
                    ForEach(AvatarPublicProfile.VisibilityField.allCases, id: \.self) { field in
                        let isOn = avatar.visibleFields.contains(field)
                        HStack {
                            Image(systemName: isOn ? "eye.fill" : "eye.slash")
                                .foregroundColor(isOn ? .blue : .secondary)
                                .frame(width: 20)
                            Text(field.rawValue)
                                .font(.spareCaption)
                            Spacer()
                            if isOn {
                                Text("公开")
                                    .font(.spareMicro)
                                    .foregroundColor(.blue)
                            } else {
                                Text("私密")
                                    .font(.spareMicro)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.top, Spacing.xs)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Spacing.lg)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .cardShadow()
    }
}

// MARK: - Visibility Badge

private struct VisibilityBadge: View {
    let isPublic: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isPublic ? "globe" : "lock.fill")
                .font(.spareMicro)
            Text(isPublic ? "公开" : "私密")
                .font(.spareMicro)
        }
        .foregroundColor(isPublic ? .green : .secondary)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background((isPublic ? Color.green : Color.secondary).opacity(0.12), in: Capsule())
    }
}

// MARK: - Flow Tags

private struct FlowTagsView: View {
    let tags: [String]

    var body: some View {
        // Simple wrapping layout using HStack with line-break approximation
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 60, maximum: 120), spacing: Spacing.sm)],
            alignment: .leading,
            spacing: Spacing.sm
        ) {
            ForEach(tags, id: \.self) { tag in
                PillTag(label: tag, color: .purple, filled: false)
            }
        }
    }
}

// MARK: - Skeleton Loading

private struct ProfileSkeletonView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Banner placeholder
            RoundedRectangle(cornerRadius: 0)
                .fill(Color(.systemGray5))
                .frame(height: 160)
                .shimmer()

            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Avatar + name
                HStack(spacing: Spacing.md) {
                    Circle()
                        .fill(Color(.systemGray4))
                        .frame(width: 80, height: 80)
                        .shimmer()

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray4))
                            .frame(width: 120, height: 20)
                            .shimmer()
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray5))
                            .frame(width: 200, height: 14)
                            .shimmer()
                    }
                }
                .padding(.top, Spacing.lg)

                // Stats row
                HStack(spacing: Spacing.md) {
                    ForEach(0..<3) { _ in
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .fill(Color(.systemGray5))
                            .frame(height: 80)
                            .shimmer()
                    }
                }

                // Card placeholder
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(Color(.systemGray5))
                    .frame(height: 140)
                    .shimmer()
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()
        }
    }
}

// MARK: - Edit Profile Sheet

private struct EditProfileSheet: View {
    let profile: UserProfile
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var bio: String

    init(profile: UserProfile) {
        self.profile = profile
        _name = State(initialValue: profile.displayName)
        _bio  = State(initialValue: profile.bio)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("昵称", text: $name)
                    TextField("简介", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button("保存") {
                        // In production: persist to store / backend
                        dismiss()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("编辑资料")
            .spareNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Edit Avatar Visibility Sheet

private struct EditAvatarVisibilitySheet: View {
    let avatar: AvatarPublicProfile
    @Environment(\.dismiss) private var dismiss

    @State private var isPublic: Bool
    @State private var visibleFields: Set<AvatarPublicProfile.VisibilityField>

    init(avatar: AvatarPublicProfile) {
        self.avatar = avatar
        _isPublic = State(initialValue: avatar.isPubliclyVisible)
        _visibleFields = State(initialValue: avatar.visibleFields)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("公开设置") {
                    Toggle("对外公开分身资料", isOn: $isPublic)
                }

                if isPublic {
                    Section("可见字段") {
                        ForEach(AvatarPublicProfile.VisibilityField.allCases, id: \.self) { field in
                            Toggle(field.rawValue, isOn: Binding(
                                get: { visibleFields.contains(field) },
                                set: { on in
                                    if on { visibleFields.insert(field) }
                                    else  { visibleFields.remove(field) }
                                }
                            ))
                        }
                    }
                }

                Section {
                    Button("保存可见性设置") {
                        dismiss()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("分身可见性")
            .spareNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    MyProfileView()
}
#endif
