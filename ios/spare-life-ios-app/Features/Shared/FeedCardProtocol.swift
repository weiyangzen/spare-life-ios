// FeedCardProtocol.swift
// Spare Life – unified FeedCard protocol, mixed-card renderer, and feed sorter
// Blueprint §统一UI 卡片混排与排序规则 (line:1151) [UIUX]
// UIUX lane – slot 2

import SwiftUI

// MARK: - FeedCard Protocol

/// Unified protocol for all mixed-feed card types.
/// Each card must declare its kind (determines visual treatment) and a sort priority.
protocol FeedCard: Identifiable where ID == String {
    var id: String { get }
    var cardKind: FeedCardKind { get }
    /// Higher priority = shown earlier after ranking. Range 0-100.
    var sortPriority: Int { get }
    /// Non-nil = card is pinned and always floats to top.
    var pinnedAt: Date? { get }
    /// ISO timestamp used for recency-decay in ranking.
    var createdAt: Date { get }
}

// MARK: - Card Kind

enum FeedCardKind: String, CaseIterable {
    case summary  = "摘要卡"
    case person   = "人物卡"
    case action   = "行动卡"
    case status   = "状态卡"

    var icon: String {
        switch self {
        case .summary: return "doc.text.fill"
        case .person:  return "person.crop.circle.fill"
        case .action:  return "bolt.fill"
        case .status:  return "chart.bar.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .summary: return .spareYellowInk
        case .person:  return .spareYellowInk
        case .action:  return .spareYellow
        case .status:  return .emotionPositive
        }
    }
}

// MARK: - Concrete card types

struct SummaryFeedCard: FeedCard {
    let id: String
    let cardKind: FeedCardKind = .summary
    let sortPriority: Int
    let pinnedAt: Date?
    let createdAt: Date
    let title: String
    let excerpt: String
    let tagLabel: String?
    let thumbnailSeed: Int

    init(id: String, sortPriority: Int, pinnedAt: Date?, createdAt: Date,
         title: String, excerpt: String, tagLabel: String? = nil, thumbnailSeed: Int = 0, tag: String? = nil) {
        self.id = id; self.sortPriority = sortPriority; self.pinnedAt = pinnedAt
        self.createdAt = createdAt; self.title = title; self.excerpt = excerpt
        self.tagLabel = tagLabel ?? tag; self.thumbnailSeed = thumbnailSeed
    }
}

struct PersonFeedCard: FeedCard {
    let id: String
    let cardKind: FeedCardKind = .person
    let sortPriority: Int
    let pinnedAt: Date?
    let createdAt: Date
    let personName: String
    let tagline: String
    let traits: [String]
    let avatarSeed: Int
    let actionLabel: String?

    init(id: String, sortPriority: Int, pinnedAt: Date? = nil, createdAt: Date = .now,
         personName: String = "", tagline: String = "", traits: [String] = [],
         avatarSeed: Int = 0, actionLabel: String? = nil,
         name: String? = nil) {
        self.id = id; self.sortPriority = sortPriority; self.pinnedAt = pinnedAt
        self.createdAt = createdAt; self.personName = name ?? personName
        self.tagline = tagline; self.traits = traits; self.avatarSeed = avatarSeed
        self.actionLabel = actionLabel
    }
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
    let reward: String?
    var ctaTapped: Bool = false

    init(id: String, sortPriority: Int, pinnedAt: Date? = nil, createdAt: Date = .now,
         headline: String, subtext: String, ctaLabel: String,
         reward: String? = nil, rewardBadge: String? = nil, ctaTapped: Bool = false) {
        self.id = id; self.sortPriority = sortPriority; self.pinnedAt = pinnedAt
        self.createdAt = createdAt; self.headline = headline; self.subtext = subtext
        self.ctaLabel = ctaLabel; self.reward = reward ?? rewardBadge
        self.ctaTapped = ctaTapped
    }
}

struct StatusFeedCard: FeedCard {
    let id: String
    let cardKind: FeedCardKind = .status
    let sortPriority: Int
    let pinnedAt: Date?
    let createdAt: Date
    let headline: String
    let value: String
    let unit: String
    let trend: Trend
    let sparkline: [Double]

    enum Trend: String {
        case up = "↑", down = "↓", flat = "—"
        var color: Color {
            switch self {
            case .up:   return .emotionPositive
            case .down: return .emotionNegative
            case .flat: return .emotionNeutral
            }
        }
    }

    init(id: String, sortPriority: Int, pinnedAt: Date? = nil, createdAt: Date = .now,
         headline: String = "", value: String, unit: String,
         trend: Trend, sparkline: [Double] = []) {
        self.id = id; self.sortPriority = sortPriority; self.pinnedAt = pinnedAt
        self.createdAt = createdAt; self.headline = headline; self.value = value
        self.unit = unit; self.trend = trend; self.sparkline = sparkline
    }

    /// Convenience init accepting a Double trend value
    init(id: String, sortPriority: Int, pinnedAt: Date? = nil, createdAt: Date = .now,
         headline: String = "", value: String, unit: String,
         trend trendValue: Double, sparkline: [Double] = []) {
        let t: Trend = trendValue > 0 ? .up : (trendValue < 0 ? .down : .flat)
        self.init(id: id, sortPriority: sortPriority, pinnedAt: pinnedAt,
                  createdAt: createdAt, headline: headline, value: value,
                  unit: unit, trend: t, sparkline: sparkline)
    }
}

// MARK: - Type-erased wrapper

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

/// Sorts a mixed array of AnyFeedCard by:
/// 1. Pinned cards first (sorted by pinnedAt descending)
/// 2. Then by score = sortPriority * recencyBoost
enum FeedSorter {
    static func sorted(_ cards: [AnyFeedCard]) -> [AnyFeedCard] {
        sort(cards)
    }
    static func sort(_ cards: [AnyFeedCard]) -> [AnyFeedCard] {
        let now = Date()
        let pinned  = cards.filter { $0.pinnedAt != nil }.sorted {
            ($0.pinnedAt ?? now) > ($1.pinnedAt ?? now)
        }
        let unpinned = cards.filter { $0.pinnedAt == nil }.sorted { a, b in
            score(a, now: now) > score(b, now: now)
        }
        return pinned + unpinned
    }

    /// Score = priority + recency bonus (decays over 48 h)
    private static func score(_ card: AnyFeedCard, now: Date) -> Double {
        let ageHours = now.timeIntervalSince(card.createdAt) / 3600
        let recencyBoost = max(0, 10 - ageHours * 0.2)
        return Double(card.sortPriority) + recencyBoost
    }
}

// MARK: - Analytics Event

/// Minimal埋点 event emitted by card interactions.
struct FeedCardEvent {
    enum Action: String {
        case impression, tap, ctaTap, swipeAway
    }
    let cardID: String
    let kind: FeedCardKind
    let action: Action
    let timestamp: Date = .now
}

// MARK: - Mixed Card Renderer

/// Renders any AnyFeedCard with the correct card view.
struct MixedFeedCardView: View {
    let card: AnyFeedCard
    var onEvent: ((FeedCardEvent) -> Void)? = nil
    var onTap: (() -> Void)? = nil

    init(card: AnyFeedCard, onEvent: ((FeedCardEvent) -> Void)? = nil) {
        self.card = card; self.onEvent = onEvent; self.onTap = nil
    }

    init(card: AnyFeedCard, onTap: @escaping () -> Void) {
        self.card = card; self.onTap = onTap; self.onEvent = nil
    }

    var body: some View {
        Group {
            switch card {
            case .summary(let c):
                SummaryCardView(card: c)
            case .person(let c):
                PersonCardView(card: c)
            case .action(let c):
                ActionCardView(card: c)
            case .status(let c):
                StatusCardView(card: c)
            }
        }
        .onTapGesture {
            onTap?()
            onEvent?(FeedCardEvent(cardID: card.id, kind: card.cardKind, action: .tap))
        }
        .onAppear {
            onEvent?(FeedCardEvent(cardID: card.id, kind: card.cardKind, action: .impression))
        }
    }
}

// MARK: - Summary Card View

struct SummaryCardView: View {
    let card: SummaryFeedCard

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail strip (gradient placeholder)
            Color.avatarGradient(seed: card.thumbnailSeed)
                .frame(height: 80)
                .overlay(alignment: .topLeading) {
                    kindPill(card.cardKind)
                        .padding(Spacing.sm)
                }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(card.title)
                    .font(.spareBodySB)
                    .lineLimit(2)

                Text(card.excerpt)
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)

                if let tag = card.tagLabel {
                    PillTag(label: tag, color: FeedCardKind.summary.accentColor)
                }
            }
            .padding(Spacing.md)
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .cardShadow()
    }
}

// MARK: - Person Card View

struct PersonCardView: View {
    let card: PersonFeedCard

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.md) {
                AvatarView(name: card.personName, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.personName)
                        .font(.spareBodySB)
                        .lineLimit(1)
                    Text(card.tagline)
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                kindPill(card.cardKind)
            }

            // Trait pills
            if !card.traits.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.xs) {
                        ForEach(card.traits, id: \.self) { trait in
                            PillTag(label: trait, color: FeedCardKind.person.accentColor)
                        }
                    }
                }
            }

            if let action = card.actionLabel {
                Text(action)
                    .font(.spareCaptionSB)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(FeedCardKind.person.accentColor, in: RoundedRectangle(cornerRadius: CornerRadius.sm))
            }
        }
        .padding(Spacing.md)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .cardShadow()
    }
}

// MARK: - Action Card View

struct ActionCardView: View {
    let card: ActionFeedCard

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top) {
                Image(systemName: FeedCardKind.action.icon)
                    .foregroundColor(FeedCardKind.action.accentColor)
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                if let reward = card.reward {
                    HStack(spacing: 3) {
                        Image(systemName: "bolt.circle.fill")
                            .foregroundColor(.spareYellow)
                            .font(.spareMicro)
                        Text(reward)
                            .font(.spareMicro)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.spareYellow.opacity(0.15), in: Capsule())
                }
            }

            Text(card.headline)
                .font(.spareBodySB)
                .lineLimit(2)

            Text(card.subtext)
                .font(.spareCaption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            Text(card.ctaLabel)
                .font(.spareCaptionSB)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(FeedCardKind.action.accentColor, in: RoundedRectangle(cornerRadius: CornerRadius.sm))
        }
        .padding(Spacing.md)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .cardShadow()
    }
}

// MARK: - Status Card View

struct StatusCardView: View {
    let card: StatusFeedCard

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                kindPill(card.cardKind)
                Spacer()
                Text(card.trend.rawValue)
                    .font(.spareBodySB)
                    .foregroundColor(card.trend.color)
            }

            HStack(alignment: .lastTextBaseline, spacing: Spacing.xs) {
                Text(card.value)
                    .font(.spareTitle2)
                Text(card.unit)
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
            }

            Text(card.headline)
                .font(.spareCaption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            // Sparkline
            if !card.sparkline.isEmpty {
                SparklineView(values: card.sparkline, color: FeedCardKind.status.accentColor)
                    .frame(height: 32)
            }
        }
        .padding(Spacing.md)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .cardShadow()
    }
}

// MARK: - Sparkline

private struct SparklineView: View {
    let values: [Double]
    var color: Color

    var body: some View {
        GeometryReader { geo in
            let minV = values.min() ?? 0
            let maxV = values.max() ?? 1
            let range = max(maxV - minV, 1)
            let step = geo.size.width / CGFloat(max(values.count - 1, 1))

            Path { path in
                for (i, v) in values.enumerated() {
                    let x = CGFloat(i) * step
                    let y = geo.size.height - (CGFloat(v - minV) / CGFloat(range)) * geo.size.height
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - Kind Pill helper

func kindPill(_ kind: FeedCardKind) -> some View {
    Label(kind.rawValue, systemImage: kind.icon)
        .font(.spareMicro)
        .foregroundColor(kind.accentColor)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 2)
        .background(kind.accentColor.opacity(0.12), in: Capsule())
}

// MARK: - Feed Kind Filter Bar

struct FeedKindFilterBar: View {
    @Binding var selectedKind: FeedCardKind?
    var counts: [FeedCardKind: Int] = [:]

    init(selectedKind: Binding<FeedCardKind?>, counts: [FeedCardKind: Int] = [:]) {
        self._selectedKind = selectedKind
        self.counts = counts
    }

    init(selected: Binding<FeedCardKind?>, counts: [FeedCardKind: Int] = [:]) {
        self._selectedKind = selected
        self.counts = counts
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                kindChip(nil, label: "全部", icon: "square.grid.2x2.fill")
                ForEach(FeedCardKind.allCases, id: \.self) { kind in
                    kindChip(kind, label: kind.rawValue, icon: kind.icon)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.xs)
        }
    }

    private func kindChip(_ kind: FeedCardKind?, label: String, icon: String) -> some View {
        let isSelected = selectedKind == kind
        return Button {
            withAnimation(.spareSpring) {
                selectedKind = isSelected ? nil : kind
            }
        } label: {
            Label(label, systemImage: icon)
                .font(.spareCaptionSB)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    isSelected ? (kind?.accentColor ?? .primary) : Color.cardBackground,
                    in: Capsule()
                )
                .cardShadow()
        }
        .buttonStyle(.plain)
    }
}
