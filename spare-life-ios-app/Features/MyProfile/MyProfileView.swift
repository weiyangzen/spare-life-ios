// MyProfileView.swift
// Spare Life – 我的 · My Profile & Avatar Public Profile
// Blueprint §7 我的 · [UIUX] My Profile (id: 37f88205febb)
// UIUX lane – slot 2

import SwiftUI
import UIKit

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

    func load() {
        guard case .idle = loadState else { return }
        loadState = .loading
        Task {
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
        }
    }

    func reload() {
        loadState = .idle
        load()
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
            .navigationBarHidden(true)
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
    @StateObject private var scrollState = WaterfallScrollState()

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Scroll offset tracker + anchor
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: ProfileScrollOffsetKey.self,
                                value: geo.frame(in: .named("profileScroll")).minY
                            )
                        }
                        .frame(height: 0)
                        .id("profile_top")

                        ProfileHeroSection(store: store, profile: profile)
                            .padding(.bottom, Spacing.lg)

                        VStack(spacing: Spacing.md) {
                            statsRow

                            if let avatar = store.avatarProfile {
                                AvatarPublicProfileCard(avatar: avatar) {
                                    store.editingAvatar = true
                                }
                            }

                            // Feature cards in waterfall grid – avoids degenerating
                            // into a plain settings page (blueprint §7 line:1154).
                            featureCardGrid

                            actionButtons
                        }
                        .padding(.horizontal, Spacing.lg)

                        // Cross-domain discover section – demonstrates mixed card
                        // rendering with FeedSorter + FeedKindFilterBar (line:1151).
                        DiscoverMixedFeedSection(
                            cards: DiscoverMixedFeedDemo.sampleCards()
                        )
                        .padding(.top, Spacing.xl)
                        .padding(.bottom, Spacing.xxxl + 32)
                    }
                }
                .coordinateSpace(name: "profileScroll")
                .onPreferenceChange(ProfileScrollOffsetKey.self) { offset in
                    scrollState.offsetY = offset
                    scrollState.isAtTop = offset > -40
                }
                .refreshable { store.reload() }

                // Scroll-to-top FAB
                if !scrollState.isAtTop {
                    ScrollToTopButton {
                        withAnimation(.spareSpring) {
                            proxy.scrollTo("profile_top", anchor: .top)
                        }
                    }
                    .padding(.trailing, Spacing.lg)
                    .padding(.bottom, Spacing.xl)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spareSpring, value: scrollState.isAtTop)
        }
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

    private var statsRow: some View {
        HStack(spacing: Spacing.md) {
            ProfileStatCard(
                icon: "bolt.circle.fill",
                iconColor: .spareYellow,
                value: "\(profile.energyBalance)",
                label: "闲能"
            )
            ProfileStatCard(
                icon: "person.2.fill",
                iconColor: .blue,
                value: "\(profile.socialScore)",
                label: "社交分"
            )
            ProfileStatCard(
                icon: "calendar",
                iconColor: .secondary,
                value: daysSince(profile.joinedDate),
                label: "入驻天"
            )
        }
    }

    // MARK: - Feature Card Waterfall Grid

    private var featureCardGrid: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            FeedSectionHeader(
                title: "我的面板",
                subtitle: "点击进入各子系统"
            )

            WaterfallLayout(columns: 2, spacing: Spacing.md) {
                // Sync Score card
                NavigationLink {
                    SyncScoreDashboardView()
                } label: {
                    ProfileFeatureCard(
                        icon: "gauge.open.with.lines.needle.33percent",
                        iconColor: .emotionPositive,
                        title: "同步度",
                        value: "72%",
                        subtitle: "3 个待训练任务",
                        accentColor: .emotionPositive,
                        height: 168
                    )
                }
                .buttonStyle(CardPressStyle())

                // Personality / Awakening card
                NavigationLink {
                    AwakeningPersonalityView()
                } label: {
                    ProfileFeatureCard(
                        icon: "sparkles.rectangle.stack.fill",
                        iconColor: .purple,
                        title: "人格觉醒",
                        value: "Lv.4",
                        subtitle: "5 项特征 · 2 个面具",
                        accentColor: .purple,
                        height: 148
                    )
                }
                .buttonStyle(CardPressStyle())

                // Memory Palace card
                NavigationLink {
                    MemoryPalaceView()
                } label: {
                    ProfileFeatureCard(
                        icon: "brain.head.profile",
                        iconColor: .blue,
                        title: "记忆宫殿",
                        value: "42",
                        subtitle: "对话 18 · 行动 12 · 情绪 12",
                        accentColor: .blue,
                        height: 156
                    )
                }
                .buttonStyle(CardPressStyle())

                // Privacy & Local Backend card
                NavigationLink {
                    PrivacyLocalBackendView()
                } label: {
                    ProfileFeatureCard(
                        icon: "lock.shield.fill",
                        iconColor: .secondary,
                        title: "隐私后端",
                        value: "本地",
                        subtitle: "SQLite · 12.4 MB · 已加密",
                        accentColor: .secondary,
                        height: 140
                    )
                }
                .buttonStyle(CardPressStyle())

                // Growth Stats card
                NavigationLink {
                    GrowthStatsView()
                } label: {
                    ProfileFeatureCard(
                        icon: "chart.line.uptrend.xyaxis",
                        iconColor: .spareYellow,
                        title: "成长回顾",
                        value: "",
                        subtitle: "近 7 天闲能 +340 · 社交分 +5",
                        accentColor: .spareYellow,
                        height: 130
                    )
                }
                .buttonStyle(CardPressStyle())
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: Spacing.sm) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
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

// MARK: - Scroll Offset Key

private struct ProfileScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Profile Feature Card

/// A rich, card-style entry point for each "我的" subsystem.
/// Uses varied heights in the waterfall grid to avoid a flat settings feel.
private struct ProfileFeatureCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let subtitle: String
    let accentColor: Color
    var height: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(iconColor)
                Spacer()
                if !value.isEmpty {
                    Text(value)
                        .font(.spareTitle2)
                        .foregroundColor(.primary)
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(.spareBodySB)
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            // Subtle accent bar at bottom
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor.opacity(0.3))
                .frame(height: 3)
        }
        .padding(Spacing.lg)
        .frame(height: height)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(accentColor.opacity(0.15), lineWidth: 1)
        )
        .cardShadow()
    }
}

// MARK: - Hero Section

private struct ProfileHeroSection: View {
    @ObservedObject var store: MyProfileStore
    let profile: UserProfile
    var scrollOffset: CGFloat = 0

    /// Sync score progress for the activity ring (0...1).
    private let syncProgress: CGFloat = 0.72

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Parallax banner gradient – moves at half scroll speed
            GeometryReader { geo in
                let minY = geo.frame(in: .global).minY
                let parallaxOffset = minY > 0 ? -minY * 0.5 : 0
                LinearGradient(
                    colors: [Color.spareYellow.opacity(0.6), Color.blue.opacity(0.35)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 160 + (minY > 0 ? minY : 0))
                .offset(y: parallaxOffset)
                .clipped()
            }
            .frame(height: 160)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .bottom) {
                    // Avatar with sync activity ring
                    ZStack {
                        // Activity ring: syncing progress
                        Circle()
                            .stroke(Color(.systemGray5), lineWidth: 3.5)
                            .frame(width: 88, height: 88)
                        Circle()
                            .trim(from: 0, to: syncProgress)
                            .stroke(
                                AngularGradient(
                                    colors: [.spareYellow, .emotionPositive, .spareYellow],
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                            )
                            .frame(width: 88, height: 88)
                            .rotationEffect(.degrees(-90))

                        AvatarView(name: profile.displayName, size: 80)
                            .overlay(
                                Circle()
                                    .stroke(Color(.systemBackground), lineWidth: 3)
                            )
                    }
                    .offset(y: 32)

                    Spacer()

                    VStack(alignment: .trailing, spacing: Spacing.xxs) {
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
                        }

                        // Sync percentage label
                        Text("同步 \(Int(syncProgress * 100))%")
                            .font(.spareMicro)
                            .foregroundColor(.spareYellow)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .padding(.bottom, 4)
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
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
        .cardShadow()
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
            .navigationBarTitleDisplayMode(.inline)
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
            .navigationBarTitleDisplayMode(.inline)
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
