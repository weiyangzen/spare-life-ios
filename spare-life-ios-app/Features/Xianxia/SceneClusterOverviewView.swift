// SceneClusterOverviewView.swift
// Spare Life – 大家都在说什么 AI clustering & sentiment overview
// Blueprint §3.1 功能点2: AI 聚类和摘要热点观点
// Covers: sentiment distribution bar, cluster topic list, analysis meta header
// UIUX lane – slot 2

import SwiftUI

// MARK: - SceneHotOverviewSection
// Pinned header shown at the top of the "热点话题" segment.
// Surfaces the AI analysis meta and sentiment distribution derived from
// the scene's primary summary card (built from backend clustering output).

struct SceneHotOverviewSection: View {
    let summary: SceneSummaryCard?
    let hotTakeCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // ── Analysis meta row ─────────────────────────────────────
            HStack(spacing: Spacing.sm) {
                Image(systemName: "cpu")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.spareYellow)

                if let summary {
                    Text("AI 分析 · \(summary.topicClusters.count) 个热点聚类")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                } else {
                    Text("AI 热点分析")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let summary {
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.spareMicro)
                        Text(summary.generatedAt, style: .relative)
                            .font(.spareMicro)
                        Text("前")
                            .font(.spareMicro)
                    }
                    .foregroundColor(.secondary)
                } else if hotTakeCount > 0 {
                    Text("\(hotTakeCount) 条热点观点")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }
            }

            // ── Sentiment distribution bar ────────────────────────────
            if let summary, !summary.topicClusters.isEmpty {
                SentimentDistributionBar(clusters: summary.topicClusters)

                Divider()
                    .padding(.vertical, Spacing.xs)

                // ── Cluster chip list (up to 4) ───────────────────────
                VStack(spacing: Spacing.xs) {
                    ForEach(summary.topicClusters.prefix(4)) { cluster in
                        ClusterChipRow(cluster: cluster)
                    }
                }
            } else if summary == nil && hotTakeCount > 0 {
                // No summary yet – show generic hot indicator
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.emotionSplit)
                    Text("正在热议中，AI 摘要生成中…")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, Spacing.xs)
            }
        }
        .padding(Spacing.md)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: CornerRadius.md))
        .cardShadow()
    }
}

// MARK: - SentimentDistributionBar
// Horizontal multi-segment bar showing proportional sentiment distribution
// across all topic clusters. Segments sized by post count.

struct SentimentDistributionBar: View {
    let clusters: [TopicCluster]

    private var total: Int { max(1, clusters.reduce(0) { $0 + $1.postCount }) }

    private struct Segment: Identifiable {
        let id: Int
        let emotion: EmotionBadge.Emotion
        let count: Int
        let fraction: CGFloat
    }

    private var segments: [Segment] {
        var grouped: [EmotionBadge.Emotion: Int] = [:]
        for cluster in clusters {
            grouped[cluster.sentiment.asBadgeEmotion, default: 0] += cluster.postCount
        }
        return grouped
            .sorted { $0.value > $1.value }
            .enumerated()
            .map { idx, pair in
                Segment(
                    id: idx,
                    emotion: pair.key,
                    count: pair.value,
                    fraction: CGFloat(pair.value) / CGFloat(total)
                )
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Proportional bar
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(segments) { seg in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(seg.emotion.color)
                            .frame(
                                width: max(6, geo.size.width * seg.fraction - 2),
                                height: 8
                            )
                            .animation(.spareEase.delay(Double(seg.id) * 0.06), value: seg.fraction)
                    }
                }
            }
            .frame(height: 8)

            // Legend row
            HStack(spacing: Spacing.md) {
                ForEach(segments) { seg in
                    HStack(spacing: 3) {
                        Circle()
                            .fill(seg.emotion.color)
                            .frame(width: 5, height: 5)
                        Text("\(seg.emotion.rawValue) \(Int(seg.fraction * 100))%")
                            .font(.spareMicro)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - ClusterChipRow
// Compact row for a single AI-identified topic cluster.
// Shows sentiment dot, label, post count, and first key phrase.

struct ClusterChipRow: View {
    let cluster: TopicCluster

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Sentiment dot
            Circle()
                .fill(cluster.sentiment.asBadgeEmotion.color)
                .frame(width: 7, height: 7)

            // Cluster label
            Text("# \(cluster.label)")
                .font(.spareCaptionSB)
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer()

            // Post count
            Text("\(cluster.postCount)")
                .font(.spareMicro)
                .foregroundColor(.secondary)
            Image(systemName: "bubble.right")
                .font(.spareMicro)
                .foregroundColor(.secondary)

            // First key phrase pill
            if let phrase = cluster.keyPhrases.first {
                PillTag(label: phrase, color: cluster.sentiment.asBadgeEmotion.color)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .background(Color(.systemGray6),
                    in: RoundedRectangle(cornerRadius: CornerRadius.sm))
    }
}

// MARK: - ScanEntryBanner
// Contextual "刚通过龙虾码进入" toast shown at the top of SceneTopicView
// for 3 seconds after a QR-code-triggered navigation.

struct ScanEntryBanner: View {
    let sceneName: String
    let category: SceneCategory

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.spareYellow)

            VStack(alignment: .leading, spacing: 1) {
                Text("通过龙虾码进入")
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
                HStack(spacing: Spacing.xs) {
                    Image(systemName: category.icon)
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                    Text(sceneName)
                        .font(.spareCaptionSB)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.emotionPositive)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: CornerRadius.md)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .strokeBorder(Color.spareYellow.opacity(0.3), lineWidth: 1)
        )
        .cardShadow()
    }
}
