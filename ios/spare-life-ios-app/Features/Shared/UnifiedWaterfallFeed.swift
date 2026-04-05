// UnifiedWaterfallFeed.swift
// Spare Life – unified two-column waterfall feed with loading / empty / error states
// Blueprint §统一UI 4 个首页双列瀑布流 (line:1150) [UIUX]
// UIUX lane – slot 2

import SwiftUI

// MARK: - Load State

enum FeedLoadState {
    case idle
    case loading
    case loaded
    case error(String)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

// MARK: - Scroll State

/// Published by the feed container so parent views can react (e.g. hide/show nav bar).
final class WaterfallScrollState: ObservableObject {
    @Published var offsetY: CGFloat = 0
    @Published var isAtTop: Bool = true
}

// MARK: - UnifiedWaterfallFeed

/// A two-column waterfall feed container used by all four home pages.
/// Handles loading skeletons, empty state, error state, and pull-to-refresh.
struct UnifiedWaterfallFeed<Card: Identifiable, CardView: View>: View {
    let loadState: FeedLoadState
    let cards: [Card]
    let emptyIcon: String
    let emptyTitle: String
    let emptyMessage: String
    var emptyActionLabel: String? = nil
    var emptyAction: (() -> Void)? = nil
    var onRefresh: (() async -> Void)? = nil
    var onRetry: (() -> Void)? = nil
    var skeletonCount: Int = 6
    @ViewBuilder var cardView: (Card) -> CardView

    // Scroll state exposed to parent
    @StateObject private var scrollState = WaterfallScrollState()

    var body: some View {
        switch loadState {
        case .idle, .loading:
            skeletonBody
        case .loaded:
            if cards.isEmpty {
                emptyBody
            } else {
                loadedBody
            }
        case .error(let msg):
            errorBody(msg)
        }
    }

    // MARK: Skeleton

    private var skeletonBody: some View {
        let heights: [CGFloat] = [130, 175, 120, 165, 195, 140, 160, 115]
        return GeometryReader { proxy in
            let cols = WaterfallColumns.count(for: proxy.size.width)
            ScrollView(.vertical, showsIndicators: false) {
                ResponsiveMasonryLayout(columns: cols, spacing: Spacing.md) {
                    ForEach(0..<skeletonCount, id: \.self) { i in
                        SkeletonCard(height: heights[i % heights.count])
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
            }
            .allowsHitTesting(false)
        }
    }

    // MARK: Empty

    private var emptyBody: some View {
        ScrollView {
            EmptyStateView(
                icon: emptyIcon,
                title: emptyTitle,
                message: emptyMessage,
                actionLabel: emptyActionLabel,
                action: emptyAction
            )
            .frame(maxWidth: .infinity)
            .padding(.top, 80)
        }
        .refreshable {
            await onRefresh?()
        }
    }

    // MARK: Error

    private func errorBody(_ message: String) -> some View {
        ScrollView {
            ErrorStateView(
                message: message,
                cached: false,
                retry: {
                    Task { await onRefresh?() }
                }
            )
            .frame(maxWidth: .infinity)
            .padding(.top, 80)
        }
    }

    // MARK: Loaded

    private var loadedBody: some View {
        GeometryReader { outer in
            let cols = WaterfallColumns.count(for: outer.size.width)
            let colWidth = columnWidth(proxy: outer, columns: cols)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    GeometryReader { inner in
                        Color.clear.preference(
                            key: ScrollOffsetKey.self,
                            value: inner.frame(in: .named("waterfallScroll")).minY
                        )
                    }
                    .frame(height: 0)

                    ResponsiveMasonryLayout(columns: cols, spacing: Spacing.md) {
                        ForEach(cards) { card in
                            cardView(card)
                                .frame(width: colWidth)
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.xxxl)
                }
            }
            .coordinateSpace(name: "waterfallScroll")
            .onPreferenceChange(ScrollOffsetKey.self) { offset in
                scrollState.offsetY = offset
                scrollState.isAtTop = offset >= -10
            }
            .refreshable {
                await onRefresh?()
            }
        }
    }

    private func columnWidth(proxy: GeometryProxy, columns: Int = 2) -> CGFloat {
        let total = proxy.size.width
        let horizontalPadding = Spacing.lg * 2
        let totalSpacing = Spacing.md * CGFloat(columns - 1)
        return max(120, floor((total - horizontalPadding - totalSpacing) / CGFloat(columns)))
    }
}

// MARK: - Scroll Offset Preference Key

private struct ScrollOffsetKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Scroll-to-Top Button

/// Floating FAB that snaps user back to top when they scroll down.
struct ScrollToTopButton: View {
    let isVisible: Bool
    let action: () -> Void

    var body: some View {
        if isVisible {
            Button(action: action) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(.spareYellow)
                    .shadow(radius: 8)
            }
            .transition(.scale.combined(with: .opacity))
            .padding(.trailing, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
        }
    }
}

// MARK: - Section Header

/// Reusable section header used above feed segments.
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
            if let label = trailingLabel {
                Button {
                    trailingAction?()
                } label: {
                    Text(label)
                        .font(.spareCaptionSB)
                        .foregroundColor(.spareYellow)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.xs)
    }
}

// MARK: - Pinned Banner

/// Shown at top of feed for pinned action cards.
struct FeedPinnedBanner: View {
    let card: ActionFeedCard

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "pin.circle.fill")
                .foregroundColor(.spareYellow)
                .font(.system(size: 24))

            VStack(alignment: .leading, spacing: 2) {
                Text(card.headline)
                    .font(.spareBodySB)
                    .lineLimit(1)
                Text(card.subtext)
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(card.ctaLabel)
                .font(.spareCaptionSB)
                .foregroundColor(.black)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(Color.spareYellow, in: Capsule())
        }
        .padding(Spacing.md)
        .background(Color.spareYellow.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(Color.spareYellow.opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
    }
}
