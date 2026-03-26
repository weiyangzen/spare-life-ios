// FeedCardProtocol.swift
// Spare Life – unified feed card protocol, concrete types, sorting, and renderers
// Blueprint §7 统一 UI · [UIUX] 卡片混排与排序规则 (line:1151)
// UIUX lane – slot 2

import SwiftUI
import UIKit

// MARK: - FeedCard Protocol

/// Every card type shown in the unified waterfall feed conforms to FeedCard.
/// This enables mixed-type feeds where summary, person, action, and status
/// cards coexist in a single scrollable layout.
protocol FeedCard: Identifiable {
    var id: String { get }
    var cardKind: FeedCardKind { get }
    /// Higher = sorted earlier when priority is equal. Range 0-100.
    var sortPriority: Int { get }
    /// Non-nil pins the card to the top of the feed.
    var pinnedAt: Date? { get }
    var createdAt: Date { get }
}

// MARK: - Card Kinds

enum FeedCardKind: String, CaseIterable, Identifiable {
    case summary  = "摘要"
    case person   = "人物"
    case action   = "行动"
    case status   = "状态"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .summary: return "doc.text.fill"
        case .person:  return "person.fill"
        case .action:  return "bolt.fill"
        case .status:  return "chart.bar.fill"
        }
    }

    var tint: Color {
        switch self {
        case .summary: return .blue
        case .person:  return .purple
        case .action:  return .spareYellow
        case .status:  return .emotionPositive
        }
    }
}

// MARK: - Concrete Card Types

struct SummaryFeedCard: FeedCard {
    let id: String
    let cardKind: FeedCardKind = .summary
    let sortPriority: Int
    let pinnedAt: Date?
    let createdAt: Date

    let title: String
    let excerpt: String
    let thumbnailSeed: Int
    let tag: String?
}

struct PersonFeedCard: FeedCard {
    let id: String
    let cardKind: FeedCardKind = .person
    let sortPriority: Int
    let pinnedAt: Date?
    let createdAt: Date

    let name: String
    let tagline: String
    let traits: [String]
    let actionLabel: String
}

struct ActionFeedCard: FeedCard {
    let id: String
    let cardKind: FeedCardKind = .action
    let sortPriority: Int
    let pinnedAt: Date?
    let createdAt: Date

    let headline: String
    let subtext: String
    let ctaLabel: String
    let rewardBadge: String?
}

struct StatusFeedCard: FeedCard {
    let id: String
    let cardKind: FeedCardKind = .status
    let sortPriority: Int
    let pinnedAt: Date?
    let createdAt: Date

    let value: String
    let unit: String
    let trend: Double      // -1.0 to +1.0
    let sparkline: [CGFloat]
}

// MARK: - Type-erased Wrapper

/// Wraps any concrete FeedCard so mixed-type arrays work in SwiftUI ForEach.
enum AnyFeedCard: Identifiable {
    case summary(SummaryFeedCard)
    case person(PersonFeedCard)
    case action(ActionFeedCard)
    case status(StatusFeedCard)

    var id: String {
        switch self {
        case .summary(let c): return c.id
        case .person(let c):  return c.id
        case .action(let c):  return c.id
        case .status(let c):  return c.id
        }
    }

    var cardKind: FeedCardKind {
        switch self {
        case .summary: return .summary
        case .person:  return .person
        case .action:  return .action
        case .status:  return .status
        }
    }

    var sortPriority: Int {
        switch self {
        case .summary(let c): return c.sortPriority
        case .person(let c):  return c.sortPriority
        case .action(let c):  return c.sortPriority
        case .status(let c):  return c.sortPriority
        }
    }

    var pinnedAt: Date? {
        switch self {
        case .summary(let c): return c.pinnedAt
        case .person(let c):  return c.pinnedAt
        case .action(let c):  return c.pinnedAt
        case .status(let c):  return c.pinnedAt
        }
    }

    var createdAt: Date {
        switch self {
        case .summary(let c): return c.createdAt
        case .person(let c):  return c.createdAt
        case .action(let c):  return c.createdAt
        case .status(let c):  return c.createdAt
        }
    }
}

// MARK: - Feed Sorter

/// Sorts mixed cards: pinned first (newest pin date wins), then by
/// composite score = priority + recency bonus. Recency bonus peaks at
/// creation and decays over 48 hours using an exponential curve.
enum FeedSorter {
    static func sorted(_ cards: [AnyFeedCard]) -> [AnyFeedCard] {
        let now = Date()
        let pinned = cards.filter { $0.pinnedAt != nil }
            .sorted { ($0.pinnedAt ?? .distantPast) > ($1.pinnedAt ?? .distantPast) }
        let unpinned = cards.filter { $0.pinnedAt == nil }
            .sorted { score(for: $0, now: now) > score(for: $1, now: now) }
        return pinned + unpinned
    }

    private static func score(for card: AnyFeedCard, now: Date) -> Double {
        let age = now.timeIntervalSince(card.createdAt)
        let halfLife: TimeInterval = 48 * 3600
        let recencyBonus = 50.0 * exp(-age / halfLife)
        return Double(card.sortPriority) + recencyBonus
    }
}

// MARK: - Analytics Event

struct FeedCardEvent {
    enum Action: String { case impression, tap, ctaTap, swipeAway }
    let cardID: String
    let cardKind: FeedCardKind
    let action: Action
    let timestamp: Date = Date()
}

// MARK: - Card Renderers

/// Routes any AnyFeedCard to the correct card view.
struct MixedFeedCardView: View {
    let card: AnyFeedCard
    var onTap: (() -> Void)? = nil

    var body: some View {
        Group {
            switch card {
            case .summary(let c):
                SummaryCardView(card: c, onTap: onTap)
            case .person(let c):
                PersonCardView(card: c, onTap: onTap)
            case .action(let c):
                ActionCardView(card: c, onTap: onTap)
            case .status(let c):
                StatusCardView(card: c)
            }
        }
    }
}

// MARK: - Summary Card View

struct SummaryCardView: View {
    let card: SummaryFeedCard
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Thumbnail area
                ZStack(alignment: .topTrailing) {
                    Color.avatarGradient(seed: card.thumbnailSeed)
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))

                    if let tag = card.tag {
                        PillTag(label: tag, color: .white, filled: false)
                            .padding(Spacing.sm)
                    }
                }

                Text(card.title)
                    .font(.spareBodySB)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Text(card.excerpt)
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            .padding(Spacing.md)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
            .cardShadow()
        }
        .buttonStyle(CardPressStyle())
    }
}

// MARK: - Person Card View

struct PersonCardView: View {
    let card: PersonFeedCard
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    AvatarView(name: card.name, size: 44)
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(card.name)
                            .font(.spareBodySB)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Text(card.tagline)
                            .font(.spareCaption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                // Trait pills
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 48), spacing: 4, alignment: .leading)],
                    alignment: .leading,
                    spacing: 4
                ) {
                    ForEach(card.traits.prefix(4), id: \.self) { trait in
                        PillTag(label: trait, color: .purple, filled: false)
                    }
                }

                Text(card.actionLabel)
                    .font(.spareCaptionSB)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.primary, in: Capsule())
            }
            .padding(Spacing.md)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
            .cardShadow()
        }
        .buttonStyle(CardPressStyle())
    }
}

// MARK: - Action Card View

struct ActionCardView: View {
    let card: ActionFeedCard
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.spareYellow)
                    Spacer()
                    if let badge = card.rewardBadge {
                        PillTag(label: badge, color: .spareYellow, filled: true)
                    }
                }

                Text(card.headline)
                    .font(.spareBodySB)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Text(card.subtext)
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                Text(card.ctaLabel)
                    .font(.spareCaptionSB)
                    .foregroundColor(.spareDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.spareYellow, in: Capsule())
            }
            .padding(Spacing.md)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
            .cardShadow()
        }
        .buttonStyle(CardPressStyle())
    }
}

// MARK: - Status Card View

struct StatusCardView: View {
    let card: StatusFeedCard

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(card.value)
                    .font(.spareTitle2)
                    .foregroundColor(.primary)
                Text(card.unit)
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
                Spacer()
                trendIndicator
            }

            if card.sparkline.count >= 2 {
                SparklineView(data: card.sparkline, color: trendColor)
                    .frame(height: 36)
            }
        }
        .padding(Spacing.md)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .cardShadow()
    }

    private var trendColor: Color {
        card.trend > 0 ? .emotionPositive : card.trend < 0 ? .emotionNegative : .emotionNeutral
    }

    private var trendIndicator: some View {
        HStack(spacing: 2) {
            Image(systemName: card.trend > 0 ? "arrow.up.right" : card.trend < 0 ? "arrow.down.right" : "arrow.right")
                .font(.spareMicro)
            Text(String(format: "%+.0f%%", card.trend * 100))
                .font(.spareMicro)
        }
        .foregroundColor(trendColor)
    }
}

// MARK: - Sparkline

struct SparklineView: View {
    let data: [CGFloat]
    var color: Color = .blue

    var body: some View {
        GeometryReader { geo in
            let minVal = data.min() ?? 0
            let maxVal = data.max() ?? 1
            let range = max(maxVal - minVal, 0.001)
            let step = geo.size.width / CGFloat(data.count - 1)

            Path { path in
                for (i, val) in data.enumerated() {
                    let x = CGFloat(i) * step
                    let y = geo.size.height * (1 - (val - minVal) / range)
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - Feed Kind Filter Bar

/// Horizontal chip bar for filtering a mixed feed by card kind.
struct FeedKindFilterBar: View {
    @Binding var selected: FeedCardKind?
    var counts: [FeedCardKind: Int] = [:]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                filterChip(kind: nil, label: "全部", icon: "square.grid.2x2")

                ForEach(FeedCardKind.allCases) { kind in
                    filterChip(kind: kind, label: kind.rawValue, icon: kind.icon)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.xs)
        }
    }

    private func filterChip(kind: FeedCardKind?, label: String, icon: String) -> some View {
        let isSelected = selected == kind
        let count = kind.flatMap { counts[$0] }
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spareFast) { selected = isSelected ? nil : kind }
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(label)
                    .font(.spareCaptionSB)
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.spareMicro)
                        .foregroundColor(isSelected ? .spareDark.opacity(0.6) : .secondary)
                }
            }
            .foregroundColor(isSelected ? .spareDark : .primary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(isSelected ? Color.spareYellow : Color.cardBackground, in: Capsule())
            .cardShadow()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Feed Section Header

struct FeedSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var trailingLabel: String? = nil
    var trailingAction: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.spareTitle3)
                if let sub = subtitle {
                    Text(sub)
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if let label = trailingLabel, let action = trailingAction {
                Button(action: action) {
                    Text(label)
                        .font(.spareCaptionSB)
                        .foregroundColor(.spareYellow)
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
    }
}

// MARK: - Feed Pinned Banner

struct FeedPinnedBanner: View {
    let card: ActionFeedCard
    var onTap: (() -> Void)?

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "pin.fill")
                    .foregroundColor(.spareYellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.headline)
                        .font(.spareBodySB)
                        .foregroundColor(.primary)
                    Text(card.subtext)
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(card.ctaLabel)
                    .font(.spareCaptionSB)
                    .foregroundColor(.spareDark)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.spareYellow, in: Capsule())
            }
            .padding(Spacing.md)
            .background(Color.spareYellowLight.opacity(0.3), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .stroke(Color.spareYellow.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(CardPressStyle())
        .padding(.horizontal, Spacing.lg)
    }
}

// MARK: - Card Press Button Style

/// Provides a subtle scale-down + shadow lift on press for all feed cards.
struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spareFast, value: configuration.isPressed)
    }
}
