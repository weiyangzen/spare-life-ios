// SceneFeedCardViews.swift
// Spare Life – 咸虾 feed card components
// Blueprint §3.1 功能点1-4: all four card types used in the scene waterfall feed
// Covers: scene summary, hot takes, avatar radar card, social prompt card
// UIUX lane – slot 2

import SwiftUI

// MARK: - SceneSummaryCardView
// Displays the AI-generated scene summary with emotion indicator and topic cluster pills.

struct SceneSummaryCardView: View {
    let card: SceneSummaryCard
    var onTap: () -> Void

    var body: some View {
        Button(action: { UIImpactFeedbackGenerator(style: .light).impactOccurred(); onTap() }) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Header row: sparkles icon + emotion badge
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.spareYellow)
                    Text("AI 热点摘要")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                    Spacer()
                    EmotionBadge(emotion: card.emotionLabel.asBadgeEmotion)
                }

                // One-liner headline
                Text(card.oneLiner)
                    .font(.spareBodySB)
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                // Topic cluster pills (up to 3)
                if !card.topicClusters.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.xs) {
                            ForEach(card.topicClusters.prefix(3)) { cluster in
                                PillTag(
                                    label: "# \(cluster.label) \(cluster.postCount)+",
                                    color: cluster.sentiment.asBadgeEmotion.color
                                )
                            }
                        }
                    }
                }

                // Footer: participant count + staleness indicator
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "person.2")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                    Text("\(card.participantCount) 人在场")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                    Spacer()
                    if card.isStale {
                        Label("缓存", systemImage: "clock.arrow.circlepath")
                            .font(.spareMicro)
                            .foregroundColor(.emotionNeutral)
                    }
                }
            }
            .padding(Spacing.md)
            .background(
                ZStack {
                    Color.cardBackground
                    // Subtle tinted gradient from emotion colour
                    LinearGradient(
                        colors: [card.emotionLabel.asBadgeEmotion.color.opacity(0.06), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .strokeBorder(Color.cardStroke, lineWidth: 0.5)
            )
            .cardShadow()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - HotTakeCardView
// Displays a high-engagement opinion clustered by the AI ("大家都在说什么").

struct HotTakeCardView: View {
    let card: HotTakeCard
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Emotion indicator stripe at top
            HStack(spacing: Spacing.xs) {
                Circle()
                    .fill(card.emotionLabel.asBadgeEmotion.color)
                    .frame(width: 6, height: 6)
                Text("热点观点")
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
                Spacer()
                EmotionBadge(emotion: card.emotionLabel.asBadgeEmotion)
            }

            // Quote body
            Text(card.content)
                .font(.spareBody)
                .foregroundColor(.primary)
                .lineLimit(expanded ? nil : 4)
                .fixedSize(horizontal: false, vertical: true)

            if card.content.count > 100 {
                Button {
                    withAnimation(.spareEase) { expanded.toggle() }
                } label: {
                    Text(expanded ? "收起" : "展开全文")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Tags
            if !card.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.xs) {
                        ForEach(card.tags.prefix(3), id: \.self) { tag in
                            PillTag(label: tag, color: .secondary)
                        }
                    }
                }
            }

            Divider()

            // Footer: avatar + author + engagement
            HStack(spacing: Spacing.sm) {
                // Author avatar placeholder
                ZStack {
                    Color.avatarGradient(seed: abs(card.authorAvatarName.hashValue))
                    Text(card.authorIsAnonymous ? "?" : String(card.authorAvatarName.prefix(1)))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 22, height: 22)
                .clipShape(Circle())

                Text(card.authorIsAnonymous ? "匿名分身" : card.authorAvatarName)
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer()

                // Like count
                HStack(spacing: 3) {
                    Image(systemName: "hand.thumbsup")
                        .font(.spareMicro)
                    Text("\(card.likeCount)")
                        .font(.spareMicro)
                }
                .foregroundColor(.secondary)

                // Reply count
                HStack(spacing: 3) {
                    Image(systemName: "bubble.right")
                        .font(.spareMicro)
                    Text("\(card.replyCount)")
                        .font(.spareMicro)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(Spacing.md)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .strokeBorder(Color.cardStroke, lineWidth: 0.5)
        )
        .cardShadow()
    }
}

// MARK: - AvatarRadarCardView
// Shows a single active avatar in the feed with intent tags and a social CTA.

struct AvatarRadarCardView: View {
    let card: SceneAvatarCard
    var onInitiateSocial: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Header: avatar + name + privacy badge
            HStack(alignment: .top, spacing: Spacing.sm) {
                AvatarView(name: card.displayName, size: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(card.displayName)
                        .font(.spareBodySB)
                        .lineLimit(1)
                    Text(card.tagline)
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Activity score pill
                ActivityScoreBadge(score: card.activityScore)
            }

            // Intent tags
            if !card.intentTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.xs) {
                        ForEach(card.intentTags.prefix(3), id: \.self) { tag in
                            PillTag(label: tag, color: .spareYellow)
                        }
                    }
                }
            }

            // Talkable topics (first 1)
            if let topic = card.talkableTopics.first {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "bubble.left.fill")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                    Text("想聊：\(topic)")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            // CTA or privacy-blocked indicator
            if card.allowsStrangerInit {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onInitiateSocial()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("发起对话")
                            .font(.spareCaptionSB)
                    }
                    .foregroundColor(.spareDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.spareYellow, in: RoundedRectangle(cornerRadius: CornerRadius.sm))
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "lock.fill")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                    Text("当前不接受陌生人发起对话")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: CornerRadius.sm))
            }
        }
        .padding(Spacing.md)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .strokeBorder(Color.cardStroke, lineWidth: 0.5)
        )
        .cardShadow()
    }
}

// MARK: - SceneSocialPromptCardView
// Contextual CTA card prompting user to initiate stranger social in the current scene.

struct SceneSocialPromptCardView: View {
    let card: SceneSocialPromptCard
    var onTap: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Lane icon + badge
                HStack(spacing: Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(Color.spareYellow.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: card.lane.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.spareYellow)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.lane.rawValue)
                            .font(.spareCaptionSB)
                            .foregroundColor(.secondary)
                        Text(card.headline)
                            .font(.spareBodySB)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                }

                // CTA button strip
                HStack {
                    Spacer()
                    Text(card.ctaLabel)
                        .font(.spareCaptionSB)
                        .foregroundColor(.spareDark)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                        .background(Color.spareYellow, in: Capsule())
                }
            }
            .padding(Spacing.md)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .strokeBorder(Color.spareYellow.opacity(0.3), lineWidth: 1)
            )
            .cardShadow()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ActivityScoreBadge
// Visual dot-grid representation of an avatar's activity level (0–100).

private struct ActivityScoreBadge: View {
    let score: Int   // 0–100

    private var filledDots: Int { max(0, min(5, Int((Double(score) / 100.0) * 5.0 + 0.5))) }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(i < filledDots ? Color.emotionPositive : Color(.systemGray5))
                    .frame(width: 5, height: 5)
            }
        }
    }
}
