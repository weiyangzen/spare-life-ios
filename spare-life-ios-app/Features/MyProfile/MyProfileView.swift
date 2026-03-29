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
    var avatarAnimal: ProfileAnimalAvatar
    var energyBalance: Int
    var socialConnections: Int
    var joinedDate: Date
    var isVerified: Bool = false
}

enum ProfileAnimalAvatar: String, CaseIterable, Identifiable {
    case bird
    case hare
    case tortoise
    case fish
    case ladybug
    case ant

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bird: return "小鸟"
        case .hare: return "野兔"
        case .tortoise: return "乌龟"
        case .fish: return "小鱼"
        case .ladybug: return "瓢虫"
        case .ant: return "蚂蚁"
        }
    }

    var symbolName: String {
        switch self {
        case .bird: return "bird.fill"
        case .hare: return "hare.fill"
        case .tortoise: return "tortoise.fill"
        case .fish: return "fish.fill"
        case .ladybug: return "ladybug.fill"
        case .ant: return "ant.fill"
        }
    }
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
    @Published var editingProfileAvatar = false
    @Published var editingAvatar = false
    @Published var shareSheetActive = false

    func load() {
        guard case .idle = loadState else { return }
        loadState = .loading
        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            profile = UserProfile(
                displayName: "王威扬",
                handle: "@the_usual_intp",
                bio: "热爱生活，探索 AI 陪伴与社交的边界。",
                avatarSeed: 42,
                avatarAnimal: .bird,
                energyBalance: 2_480,
                socialConnections: 87,
                joinedDate: Calendar.current.date(byAdding: .month, value: -4, to: .now) ?? .now
            )
            avatarProfile = AvatarPublicProfile(
                id: "avatar-me",
                nickname: "Shadow Sebastian",
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

    func updateAvatarAnimal(_ animal: ProfileAnimalAvatar) {
        guard var profile else { return }
        profile.avatarAnimal = animal
        self.profile = profile
    }
}

// MARK: - Root View

struct MyProfileView: View {
    @StateObject private var store = MyProfileStore()

    var body: some View {
        NavigationStack {
            ZStack {
                ProfileAmbientBackground()
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
    @State private var showsAgentProfile = false

    var body: some View {
        GeometryReader { proxy in
            let viewportWidth = proxy.size.width

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    ProfileHeroSection(
                        profile: profile,
                        avatarProfile: store.avatarProfile,
                        showsAgentProfile: $showsAgentProfile,
                        onEditAvatar: {
                            store.editingProfileAvatar = true
                        },
                        onEditAgentProfile: {
                            store.editingAvatar = true
                        }
                    )

                    featureCardGrid(viewportWidth: viewportWidth)
                    actionButtons
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xxxl + 44)
            }
        }
        .refreshable { store.reload() }
        .sheet(isPresented: $store.editingProfileAvatar) {
            if let liveProfile = store.profile {
                EditProfileAvatarSheet(selectedAnimal: liveProfile.avatarAnimal) { animal in
                    store.updateAvatarAnimal(animal)
                }
                .presentationDragIndicator(.visible)
                .presentationDetents([.medium, .large])
            }
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

    private func featureCardGrid(viewportWidth: CGFloat) -> some View {
        let layout = MyProfileDashboardLayout.shared(for: viewportWidth)
        let cardHeight: CGFloat = viewportWidth < 520 ? 180 : 184
        let wideColumns = Array(
            repeating: GridItem(.flexible(), spacing: layout.cardSpacing, alignment: .top),
            count: 4
        )

        return VStack(alignment: .leading, spacing: Spacing.md) {
            if viewportWidth < 520 {
                VStack(spacing: layout.cardSpacing) {
                    featureRow(
                        left: syncScoreCard,
                        right: personalityCard,
                        cardHeight: cardHeight
                    )

                    featureRow(
                        left: privacyCard,
                        right: memoryCard,
                        cardHeight: cardHeight
                    )
                }
            } else {
                LazyVGrid(columns: wideColumns, alignment: .leading, spacing: layout.cardSpacing) {
                    syncScoreCard
                        .frame(minHeight: cardHeight, alignment: .top)

                    personalityCard
                        .frame(minHeight: cardHeight, alignment: .top)

                    privacyCard
                        .frame(minHeight: cardHeight, alignment: .top)

                    memoryCard
                        .frame(minHeight: cardHeight, alignment: .top)
                }
            }
        }
    }

    private func featureRow<Left: View, Right: View>(
        left: Left,
        right: Right,
        cardHeight: CGFloat
    ) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            left
                .frame(maxWidth: .infinity, minHeight: cardHeight, alignment: .top)

            right
                .frame(maxWidth: .infinity, minHeight: cardHeight, alignment: .top)
        }
    }

    private var syncScoreCard: some View {
        NavigationLink(destination: SyncScoreDashboardView()) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                featureHeader(
                    icon: "arrow.triangle.2.circlepath.circle.fill",
                    title: "同步度"
                )

                ZStack {
                    Circle()
                        .stroke(Color.spareYellow.opacity(0.18), lineWidth: 10)

                    Circle()
                        .trim(from: 0, to: 0.72)
                        .stroke(
                            Color.spareYellow,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    Text("72%")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(ProfilePalette.ink)
                }
                .frame(width: 92, height: 92)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .profileSurface(prominent: true)
        }
        .buttonStyle(.plain)
    }

    private var personalityCard: some View {
        NavigationLink(destination: AwakeningPersonalityView()) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                featureHeader(icon: "brain.head.profile", title: "MBTI")

                HStack(alignment: .lastTextBaseline, spacing: Spacing.xs) {
                    Text("INTP")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(ProfilePalette.ink)

                    Text("逻辑学家")
                        .font(.spareMicro)
                        .foregroundColor(ProfilePalette.secondaryText)
                }

                Text("偏好独立思考、抽象建模和延迟定论。")
                    .font(.spareCaption)
                    .foregroundColor(ProfilePalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                Text("INTP 人格指南已生成 · 2 个面具已配置")
                    .font(.spareMicro)
                    .foregroundColor(ProfilePalette.secondaryText)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .profileSurface()
        }
        .buttonStyle(.plain)
    }

    private var memoryCard: some View {
        NavigationLink(destination: MemoryPalaceView()) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                featureHeader(icon: "brain", title: "记忆宫殿")

                HStack(alignment: .lastTextBaseline, spacing: Spacing.sm) {
                    Text("248")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(ProfilePalette.ink)
                    Text("条记忆")
                        .font(.spareCaption)
                        .foregroundColor(ProfilePalette.secondaryText)
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    memoryBar(label: "对话", fraction: 0.6)
                    memoryBar(label: "行动", fraction: 0.25)
                    memoryBar(label: "情绪", fraction: 0.15)
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .profileSurface()
        }
        .buttonStyle(.plain)
    }

    private func memoryBar(label: String, fraction: CGFloat) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(label)
                .font(.spareMicro)
                .foregroundColor(ProfilePalette.secondaryText)
                .frame(width: 28, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.spareYellow.opacity(0.14))
                        .frame(height: 6)

                    Capsule()
                        .fill(Color.spareYellow)
                        .frame(width: max(geo.size.width * fraction, 8), height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private var privacyCard: some View {
        NavigationLink(destination: PrivacyLocalBackendView()) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                featureHeader(icon: "lock.shield.fill", title: "隐私")

                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(Color.emotionPositive)
                        .frame(width: 6, height: 6)
                    Text("本地后端运行中")
                        .font(.spareMicro)
                        .foregroundColor(.emotionPositive)
                }

                HStack(alignment: .lastTextBaseline, spacing: Spacing.xs) {
                    Text("12.4")
                        .font(.spareTitle3)
                        .foregroundColor(ProfilePalette.ink)
                    Text("MB")
                        .font(.spareCaption)
                        .foregroundColor(ProfilePalette.secondaryText)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.spareYellow.opacity(0.14))
                            .frame(height: 6)

                        Capsule()
                            .fill(Color.spareYellow)
                            .frame(width: geo.size.width * 0.12, height: 6)
                    }
                }
                .frame(height: 6)

                Spacer(minLength: 0)

                Text("无云端上传")
                    .font(.spareMicro)
                    .foregroundColor(ProfilePalette.secondaryText)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .profileSurface()
        }
        .buttonStyle(.plain)
    }

    private var actionButtons: some View {
        ViewThatFits {
            HStack(spacing: Spacing.md) {
                editProfileButton
                shareProfileButton
            }

            VStack(spacing: Spacing.sm) {
                editProfileButton
                shareProfileButton
            }
        }
    }

    private var editProfileButton: some View {
        Button {
            store.editingProfile = true
        } label: {
            Label("编辑资料", systemImage: "pencil")
                .font(.spareBodySB)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .foregroundColor(ProfilePalette.ink)
                .background(
                    LinearGradient(
                        colors: [Color.spareYellow.opacity(0.95), Color.spareYellowLight],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .shadow(color: Color.spareYellow.opacity(0.18), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var shareProfileButton: some View {
        Button {
            store.shareSheetActive = true
        } label: {
            Label("分享主页", systemImage: "square.and.arrow.up")
                .font(.spareBodySB)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .foregroundColor(ProfilePalette.ink)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.spareYellow.opacity(0.45), lineWidth: 1)
                        )
                )
                .shadow(color: Color.black.opacity(0.03), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Background

private enum ProfilePalette {
    static let pageTop = Color(red: 1.00, green: 0.98, blue: 0.90)
    static let pageBottom = Color.white
    static let ink = Color(red: 0.10, green: 0.12, blue: 0.17)
    static let secondaryText = Color(red: 0.42, green: 0.45, blue: 0.53)
}

private struct ProfileAmbientBackground: View {
    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [ProfilePalette.pageTop, ProfilePalette.pageBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(Color.spareYellow.opacity(0.18))
                .frame(height: 220)
                .padding(.horizontal, -24)
                .offset(y: -110)
        }
    }
}

// MARK: - Hero Section

private struct ProfileHeroSection: View {
    let profile: UserProfile
    let avatarProfile: AvatarPublicProfile?
    @Binding var showsAgentProfile: Bool
    let onEditAvatar: () -> Void
    let onEditAgentProfile: () -> Void

    private var isShowingAgent: Bool {
        showsAgentProfile && avatarProfile != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(alignment: .top, spacing: Spacing.lg) {
                Button(action: onEditAvatar) {
                    ProfileAnimalAvatarView(animal: profile.avatarAnimal, size: 84)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "pencil")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(ProfilePalette.ink)
                                .frame(width: 26, height: 26)
                                .background(Color.white, in: Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.spareYellow.opacity(0.35), lineWidth: 1)
                                )
                                .offset(x: 4, y: 4)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("修改头像")

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(alignment: .center, spacing: Spacing.xs) {
                        Text(profile.displayName)
                            .font(.spareTitle2)
                            .foregroundColor(ProfilePalette.ink)

                        if profile.isVerified {
                            VerifiedBadge()
                        }

                        AgentModeToggle(
                            isOn: $showsAgentProfile,
                            isEnabled: avatarProfile != nil
                        )
                    }

                    if isShowingAgent, let avatarProfile {
                        HStack(spacing: Spacing.sm) {
                            Text(avatarProfile.nickname)
                                .font(.spareCaptionSB)
                                .foregroundColor(ProfilePalette.ink)

                            VisibilityBadge(isPublic: avatarProfile.isPubliclyVisible)

                            Button(action: onEditAgentProfile) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.spareYellow)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, Spacing.xs)

                        HStack(spacing: Spacing.xs) {
                            ForEach(avatarProfile.personalityTraits, id: \.self) { trait in
                                PillTag(label: trait, color: .spareYellow, filled: false)
                            }
                        }
                        .padding(.top, Spacing.sm)
                    } else {
                        Text(profile.handle)
                            .font(.spareCaption)
                            .foregroundColor(ProfilePalette.secondaryText)

                        if !profile.bio.isEmpty {
                            Text(profile.bio)
                                .font(.spareBody)
                                .foregroundColor(ProfilePalette.secondaryText)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, Spacing.sm)
                        }
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(alignment: .top, spacing: Spacing.sm) {
                ProfileStatCard(
                    icon: "bolt.circle.fill",
                    iconColor: .spareYellow,
                    value: "\(profile.energyBalance)",
                    label: "闲能",
                    intro: "当前可调度的闲能余额"
                )

                ProfileStatCard(
                    icon: "person.2.fill",
                    iconColor: .spareYellowInk,
                    value: "\(profile.socialConnections)",
                    label: "社交连接",
                    intro: "当前已建立的社交连接数"
                )

                ProfileStatCard(
                    icon: "calendar",
                    iconColor: .secondary,
                    value: daysSince(profile.joinedDate),
                    label: "入驻天",
                    intro: "加入 Spare Life 的累计天数"
                )
            }
        }
        .padding(Spacing.xxl)
        .profileSurface(prominent: true, cornerRadius: 32)
    }

    private func daysSince(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: .now).day ?? 0
        return "\(days)"
    }
}

private struct AgentModeToggle: View {
    @Binding var isOn: Bool
    let isEnabled: Bool

    var body: some View {
        Button {
            guard isEnabled else { return }
            withAnimation(.spareEase) {
                isOn.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Text("Agent")
                    .font(.spareMicro)
                    .foregroundColor(isEnabled ? ProfilePalette.ink : ProfilePalette.secondaryText)

                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(isOn ? Color.spareYellow : Color(.systemGray5))
                        .frame(width: 34, height: 20)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .padding(3)
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.72))
                    .overlay(
                        Capsule()
                            .stroke(Color.spareYellow.opacity(0.16), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.55)
    }
}

private struct ProfileAnimalAvatarView: View {
    let animal: ProfileAnimalAvatar
    var size: CGFloat = 84

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.spareYellow)

            Circle()
                .fill(Color.white.opacity(0.16))
                .frame(width: size * 0.78, height: size * 0.78)
                .offset(x: size * 0.08, y: size * 0.06)

            Capsule()
                .fill(Color.white.opacity(0.42))
                .frame(width: size * 0.52, height: size * 0.14)
                .offset(y: size * 0.22)

            Image(systemName: animal.symbolName)
                .font(.system(size: size * 0.34, weight: .semibold))
                .foregroundColor(ProfilePalette.ink)
                .offset(y: size * 0.01)
        }
        .frame(width: size, height: size)
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.9), lineWidth: 3)
        )
        .shadow(color: Color.spareYellow.opacity(0.20), radius: 16, y: 8)
    }
}

// MARK: - Cards

private struct ProfileStatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    let intro: String

    @State private var showsInfo = false

    var body: some View {
        Button {
            withAnimation(.spareEase) {
                showsInfo.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(iconColor)
                        .frame(width: 30, height: 30)
                        .background(iconColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Spacer(minLength: 0)
                }

                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(ProfilePalette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.spareYellow.opacity(0.18), lineWidth: 1)
                    )
            )
            .overlay(alignment: .top) {
                if showsInfo {
                    statInfoPopover
                        .offset(y: -78)
                        .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .bottom)))
                }
            }
        }
        .buttonStyle(.plain)
        .zIndex(showsInfo ? 10 : 0)
    }

    private var statInfoPopover: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.spareCaptionSB)
                .foregroundColor(ProfilePalette.ink)

            Text(intro)
                .font(.spareMicro)
                .foregroundColor(ProfilePalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: 170, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.spareYellow.opacity(0.22), lineWidth: 1)
        )
    }
}

private struct AvatarPublicProfileCard: View {
    let avatar: AvatarPublicProfile
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "person.crop.circle.badge.fill")
                            .foregroundColor(ProfilePalette.ink)
                        Text("分身公开资料")
                            .font(.spareBodySB)
                            .foregroundColor(ProfilePalette.ink)
                    }

                    Text(avatar.nickname)
                        .font(.spareCaption)
                        .foregroundColor(ProfilePalette.secondaryText)

                    Text(avatar.tagline)
                        .font(.spareMicro)
                        .foregroundColor(ProfilePalette.secondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                VisibilityBadge(isPublic: avatar.isPubliclyVisible)

                Button(action: onEdit) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.spareYellow)
                }
                .buttonStyle(.plain)
            }

            FlowTagsView(tags: avatar.personalityTraits, color: .spareYellow)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("公开字段")
                        .font(.spareCaptionSB)
                        .foregroundColor(ProfilePalette.secondaryText)
                    Spacer()
                    Text("\(visibleFieldLabels.count) 项")
                        .font(.spareMicro)
                        .foregroundColor(ProfilePalette.secondaryText)
                }

                FlowTagsView(tags: visibleFieldLabels, color: .spareYellowInk)
            }
        }
        .padding(Spacing.xxl)
        .profileSurface(cornerRadius: 28)
    }

    private var visibleFieldLabels: [String] {
        AvatarPublicProfile.VisibilityField.allCases
            .filter { avatar.visibleFields.contains($0) }
            .map(\.rawValue)
    }
}

private struct VisibilityBadge: View {
    let isPublic: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isPublic ? "globe" : "lock.fill")
                .font(.spareMicro)
            Text(isPublic ? "公开" : "私密")
                .font(.spareMicro)
        }
        .foregroundColor(ProfilePalette.ink)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 6)
        .background((isPublic ? Color.spareYellow : Color.gray).opacity(0.16), in: Capsule())
    }
}

private struct VerifiedBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(ProfilePalette.ink)
            Text("已认证")
                .font(.spareMicro)
                .foregroundColor(ProfilePalette.ink)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 6)
        .background(Color.spareYellow.opacity(0.22), in: Capsule())
    }
}

private struct FlowTagsView: View {
    let tags: [String]
    let color: Color

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 68, maximum: 120), spacing: Spacing.sm)],
            alignment: .leading,
            spacing: Spacing.sm
        ) {
            ForEach(tags, id: \.self) { tag in
                PillTag(label: tag, color: color, filled: false)
            }
        }
    }
}

// MARK: - Surfaces

private struct ProfileSurfaceModifier: ViewModifier {
    let prominent: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.white)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.spareYellow.opacity(prominent ? 0.12 : 0.05))

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.spareYellow.opacity(prominent ? 0.36 : 0.20), lineWidth: 1)
                }
            )
            .shadow(color: Color.spareYellow.opacity(prominent ? 0.10 : 0.05), radius: prominent ? 18 : 10, y: prominent ? 8 : 4)
            .shadow(color: Color.black.opacity(0.03), radius: prominent ? 8 : 4, y: 2)
    }
}

private extension View {
    func profileSurface(
        prominent: Bool = false,
        cornerRadius: CGFloat = 24
    ) -> some View {
        modifier(
            ProfileSurfaceModifier(
                prominent: prominent,
                cornerRadius: cornerRadius
            )
        )
    }
}

private extension ProfileScrollView {
    func featureHeader(icon: String, title: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ProfilePalette.ink)
                .frame(width: 36, height: 36)
                .background(Color.spareYellow.opacity(0.22), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(title)
                .font(.spareCaptionSB)
                .foregroundColor(ProfilePalette.ink)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.spareMicro)
                .foregroundColor(ProfilePalette.secondaryText)
        }
    }
}

// MARK: - Skeleton Loading

private struct ProfileSkeletonView: View {
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color.white)
                    .frame(height: 250)
                    .overlay(
                        VStack(alignment: .leading, spacing: Spacing.lg) {
                            HStack(spacing: Spacing.md) {
                                Circle()
                                    .fill(Color(.systemGray4))
                                    .frame(width: 84, height: 84)
                                VStack(alignment: .leading, spacing: Spacing.sm) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.systemGray4))
                                        .frame(width: 120, height: 22)
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.systemGray5))
                                        .frame(width: 180, height: 14)
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.systemGray5))
                                        .frame(width: 200, height: 14)
                                }
                            }

                            HStack(spacing: Spacing.sm) {
                                ForEach(0..<3) { _ in
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(Color(.systemGray5))
                                        .frame(height: 118)
                                }
                            }
                        }
                        .padding(Spacing.xxl)
                    )
                    .shimmer()

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white)
                    .frame(height: 188)
                    .shimmer()

                HStack(alignment: .top, spacing: Spacing.md) {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.white)
                        .frame(height: 208)
                        .shimmer()

                    VStack(spacing: Spacing.md) {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white)
                            .frame(height: 154)
                            .shimmer()
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white)
                            .frame(height: 154)
                            .shimmer()
                    }
                }

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white)
                    .frame(height: 150)
                    .shimmer()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.xxxl + 44)
        }
        .background(ProfileAmbientBackground())
    }
}

// MARK: - Edit Profile Avatar Sheet

private struct EditProfileAvatarSheet: View {
    let onSave: (ProfileAnimalAvatar) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedAnimal: ProfileAnimalAvatar

    init(
        selectedAnimal: ProfileAnimalAvatar,
        onSave: @escaping (ProfileAnimalAvatar) -> Void
    ) {
        self.onSave = onSave
        _selectedAnimal = State(initialValue: selectedAnimal)
    }

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.md),
        GridItem(.flexible(), spacing: Spacing.md)
    ]

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("选择头像")
                            .font(.spareTitle3)
                            .foregroundColor(ProfilePalette.ink)

                        Text("亮黄底色配一个小动物，作为这一页的 mock 头像。")
                            .font(.spareCaption)
                            .foregroundColor(ProfilePalette.secondaryText)
                    }

                    HStack {
                        Spacer()
                        ProfileAnimalAvatarView(animal: selectedAnimal, size: 108)
                        Spacer()
                    }
                    .padding(.vertical, Spacing.sm)

                    LazyVGrid(columns: columns, spacing: Spacing.md) {
                        ForEach(ProfileAnimalAvatar.allCases) { animal in
                            Button {
                                selectedAnimal = animal
                            } label: {
                                VStack(spacing: Spacing.md) {
                                    ProfileAnimalAvatarView(animal: animal, size: 72)

                                    Text(animal.label)
                                        .font(.spareCaptionSB)
                                        .foregroundColor(ProfilePalette.ink)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.lg)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(Color.white)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                                .stroke(
                                                    animal == selectedAnimal
                                                        ? Color.spareYellow
                                                        : Color.spareYellow.opacity(0.20),
                                                    lineWidth: animal == selectedAnimal ? 2 : 1
                                                )
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xxxl)
            }
            .background(ProfileAmbientBackground())
            .navigationTitle("修改头像")
            .spareNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(selectedAnimal)
                        dismiss()
                    }
                    .foregroundColor(ProfilePalette.ink)
                }
            }
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
                        dismiss()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.spareYellowInk)
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
                    .foregroundColor(.spareYellowInk)
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
