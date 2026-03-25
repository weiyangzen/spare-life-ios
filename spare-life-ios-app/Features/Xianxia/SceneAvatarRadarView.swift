// SceneAvatarRadarView.swift
// Spare Life – 咸虾 场景活跃分身雷达 full sheet
// Blueprint §3.1 功能点3: 场景内发现值得私聊的分身
// Covers: avatar list, sort control, privacy indicators, social CTA per avatar
// UIUX lane – slot 2

import SwiftUI

// MARK: - SceneAvatarRadarView
// Full-screen sheet presenting all active avatars in the scene,
// sortable by presence, recency, match, or trust.

struct SceneAvatarRadarView: View {
    let scene: Scene
    let avatars: [SceneAvatarCard]
    var isLoading: Bool = false

    @Environment(\.dismiss) private var dismiss
    @State private var sortOption: AvatarSortOption = .hottest
    @State private var initiatingAvatarID: String? = nil
    @State private var initiatedAvatarIDs: Set<String> = []  // tracks completed initiations
    @State private var showIntentFor: SceneAvatarCard? = nil

    private var sortedAvatars: [SceneAvatarCard] {
        switch sortOption {
        case .hottest:  return avatars.sorted { $0.activityScore > $1.activityScore }
        case .newest:   return avatars.sorted { $0.joinedSceneAt > $1.joinedSceneAt }
        case .matched:  return avatars.sorted { $0.intentTags.count > $1.intentTags.count }
        case .trusted:  return avatars.sorted { $0.reputationScore > $1.reputationScore }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    // ── Sort strip ────────────────────────────────────────
                    sortStrip
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)

                    Divider()

                    // ── Avatar list ───────────────────────────────────────
                    if isLoading {
                        avatarLoadingView
                    } else if avatars.isEmpty {
                        emptyStateView
                    } else {
                        avatarScrollView
                    }
                }
            }
            .navigationTitle("活跃分身 · \(scene.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("\(avatars.count) 人在场")
                        .font(.spareCaptionSB)
                        .foregroundColor(.secondary)
                }
            }
            .sheet(item: $showIntentFor) { avatar in
                SceneSocialIntentView(scene: scene, targetAvatar: avatar)
                    .onDisappear {
                        // Mark as initiated once the intent sheet is dismissed
                        initiatedAvatarIDs.insert(avatar.id)
                    }
            }
        }
    }

    // MARK: - Sort Strip

    private var sortStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(AvatarSortOption.allCases) { option in
                    Button {
                        withAnimation(.spareSpring) { sortOption = option }
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: option.icon)
                                .font(.system(size: 11, weight: .medium))
                            Text(option.rawValue)
                                .font(.spareCaption)
                        }
                        .foregroundColor(sortOption == option ? .spareDark : .primary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            Capsule()
                                .fill(sortOption == option ? Color.spareYellow : Color(.systemGray5))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Avatar Loading View
    // Shown while the feed (and avatar cards within it) are still loading.

    private var avatarLoadingView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: Spacing.sm) {
                ForEach(0..<4, id: \.self) { _ in
                    AvatarSkeletonRow()
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Avatar Scroll View

    private var avatarScrollView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: Spacing.sm) {
                ForEach(sortedAvatars) { avatar in
                    AvatarDetailRow(
                        avatar: avatar,
                        isInitiating: initiatingAvatarID == avatar.id,
                        alreadyInitiated: initiatedAvatarIDs.contains(avatar.id),
                        onInitiate: {
                            guard avatar.allowsStrangerInit else { return }
                            initiatingAvatarID = avatar.id
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showIntentFor = avatar
                            // Reset tap highlight after a moment
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                if initiatingAvatarID == avatar.id { initiatingAvatarID = nil }
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .padding(.bottom, Spacing.xxxl)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ScrollView {
            EmptyStateView(
                icon: "person.2.wave.2",
                title: "暂无活跃分身",
                message: "还没有人公开他们的分身信息。\n扫码进入更多场景或稍后再看。"
            )
            .padding(.top, Spacing.xxxl)
        }
    }
}

// MARK: - AvatarSkeletonRow
// Shimmer placeholder for a single avatar row while loading.

private struct AvatarSkeletonRow: View {
    var body: some View {
        HStack(spacing: Spacing.md) {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 46, height: 46)
                .shimmer()

            VStack(alignment: .leading, spacing: Spacing.xs) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 100, height: 14)
                    .shimmer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 160, height: 11)
                    .shimmer()
            }
            Spacer()
        }
        .padding(Spacing.md)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
    }
}

// MARK: - PulseDot
// Animated green circle indicating an avatar joined the scene very recently.

private struct PulseDot: View {
    @State private var pulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.emotionPositive.opacity(0.35))
                .frame(width: 14, height: 14)
                .scaleEffect(pulsing ? 1.6 : 1.0)
                .opacity(pulsing ? 0 : 0.8)
            Circle()
                .fill(Color.emotionPositive)
                .frame(width: 8, height: 8)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) {
                pulsing = true
            }
        }
    }
}

// MARK: - AvatarDetailRow
// A full-featured row representing one active avatar in the radar list.

private struct AvatarDetailRow: View {
    let avatar: SceneAvatarCard
    var isInitiating: Bool
    var alreadyInitiated: Bool = false
    var onInitiate: () -> Void

    /// True if the avatar joined within the past 10 minutes.
    private var isNewlyJoined: Bool {
        Date().timeIntervalSince(avatar.joinedSceneAt) < 600
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // ── Top: avatar circle + identity + activity ──────────────
            HStack(alignment: .top, spacing: Spacing.md) {
                // Avatar with activity ring + optional new-arrival pulse dot
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        AvatarView(name: avatar.displayName, size: 46)
                        ActivityRing(score: avatar.activityScore, size: 46)
                    }
                    if isNewlyJoined {
                        PulseDot()
                            .offset(x: 2, y: -2)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.sm) {
                        Text(avatar.displayName)
                            .font(.spareBodySB)
                            .lineLimit(1)

                        PrivacyBadge(radius: avatar.privacyRadius)
                    }

                    Text(avatar.tagline)
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                // Reputation score badge
                ReputationBadge(score: avatar.reputationScore)
            }

            // ── Intent tags ───────────────────────────────────────────
            if !avatar.intentTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.xs) {
                        ForEach(avatar.intentTags.prefix(4), id: \.self) { tag in
                            PillTag(label: tag, color: .spareYellow)
                        }
                    }
                }
            }

            // ── Talkable topics ───────────────────────────────────────
            if !avatar.talkableTopics.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("想聊的话题")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.xs) {
                            ForEach(avatar.talkableTopics.prefix(3), id: \.self) { topic in
                                PillTag(label: topic, color: .secondary)
                            }
                        }
                    }
                }
            }

            // ── CTA ───────────────────────────────────────────────────
            if alreadyInitiated {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.emotionPositive)
                    Text("已发起对话")
                        .font(.spareBodySB)
                        .foregroundColor(.emotionPositive)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(Color.emotionPositive.opacity(0.10), in: RoundedRectangle(cornerRadius: CornerRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                        .strokeBorder(Color.emotionPositive.opacity(0.25), lineWidth: 1)
                )
            } else if avatar.allowsStrangerInit {
                Button {
                    onInitiate()
                } label: {
                    HStack(spacing: Spacing.sm) {
                        if isInitiating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .spareDark))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 12, weight: .bold))
                        }
                        Text(isInitiating ? "准备中…" : "发起对话")
                            .font(.spareBodySB)
                    }
                    .foregroundColor(.spareDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(Color.spareYellow, in: RoundedRectangle(cornerRadius: CornerRadius.sm))
                }
                .buttonStyle(.plain)
                .disabled(isInitiating)
                .animation(.spareEase, value: isInitiating)
            } else {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "lock.fill")
                        .font(.spareMicro)
                    Text("当前不接受陌生人发起对话")
                        .font(.spareMicro)
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: CornerRadius.sm))
            }
        }
        .padding(Spacing.md)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .strokeBorder(Color.cardStroke, lineWidth: 0.5)
        )
        .cardShadow()
    }
}

// MARK: - ActivityRing
// A thin coloured arc showing the avatar's scene activity score around the avatar circle.

private struct ActivityRing: View {
    let score: Int     // 0–100
    let size: CGFloat

    private var fraction: Double { Double(max(0, min(100, score))) / 100.0 }
    private var ringColor: Color {
        switch score {
        case 75...100: return .emotionPositive
        case 40...74:  return .spareYellow
        default:       return .emotionNeutral
        }
    }

    var body: some View {
        Circle()
            .trim(from: 0, to: fraction)
            .stroke(ringColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .frame(width: size + 5, height: size + 5)
            .rotationEffect(.degrees(-90))
    }
}

// MARK: - PrivacyBadge
// Small chip indicating the avatar's privacy level.

private struct PrivacyBadge: View {
    let radius: SceneAvatarCard.PrivacyRadius

    private var color: Color {
        switch radius {
        case .full:    return .emotionPositive
        case .limited: return .emotionSplit
        case .minimal: return .secondary
        }
    }

    private var icon: String {
        switch radius {
        case .full:    return "eye"
        case .limited: return "eye.slash"
        case .minimal: return "lock"
        }
    }

    var body: some View {
        Label(radius.rawValue, systemImage: icon)
            .font(.spareMicro)
            .foregroundColor(color)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, 2)
            .background(color.opacity(0.1), in: Capsule())
    }
}

// MARK: - ReputationBadge
// Compact shield badge showing reputation score.

private struct ReputationBadge: View {
    let score: Int   // 0–100

    private var tier: (label: String, color: Color) {
        switch score {
        case 80...100: return ("高", .emotionPositive)
        case 50...79:  return ("中", .emotionSplit)
        default:       return ("新", .emotionNeutral)
        }
    }

    var body: some View {
        VStack(spacing: 1) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 14))
                .foregroundColor(tier.color)
            Text(tier.label)
                .font(.spareMicro)
                .foregroundColor(tier.color)
        }
    }
}
