// UnifiedWaterfallFeed.swift
// Spare Life – generic waterfall feed container with full state handling
// Blueprint §7 统一 UI · [UIUX] 4个首页双列瀑布流 (line:1150)
// UIUX lane – slot 2

import SwiftUI
import UIKit

// MARK: - Feed Load State

enum FeedLoadState: Equatable {
    case idle
    case loading
    case loaded
    case error(String)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    static func == (lhs: FeedLoadState, rhs: FeedLoadState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.loaded, .loaded): return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - Scroll State

/// Tracks scroll offset for hide/show nav effects and scroll-to-top.
final class WaterfallScrollState: ObservableObject {
    @Published var offsetY: CGFloat = 0
    @Published var isAtTop: Bool = true
}

// MARK: - Scroll Offset Preference Key

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - UnifiedWaterfallFeed

/// A generic, reusable waterfall feed container used by all four main tabs
/// (咸虾, 大师, 赚闲能, 我的). It handles:
/// - Skeleton loading state with shimmer placeholders
/// - Empty state with customizable icon, title, message, and CTA
/// - Error state with retry
/// - Loaded state with pull-to-refresh, scroll tracking, and scroll-to-top FAB
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
    @ViewBuilder let cardView: (Card) -> CardView

    @StateObject private var scrollState = WaterfallScrollState()
    private static var topAnchorID: String { "waterfall_top" }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                switch loadState {
                case .idle, .loading:
                    WaterfallSkeleton(count: 8)
                        .transition(.opacity)

                case .loaded:
                    if cards.isEmpty {
                        emptyBody
                    } else {
                        loadedBody
                    }

                case .error(let msg):
                    ScrollView {
                        ErrorStateView(message: msg, retry: onRetry)
                            .padding(.top, Spacing.xxxl)
                    }
                }

                // Scroll-to-top FAB
                if !scrollState.isAtTop {
                    ScrollToTopButton {
                        withAnimation(.spareSpring) {
                            proxy.scrollTo(Self.topAnchorID, anchor: .top)
                        }
                    }
                    .padding(.trailing, Spacing.lg)
                    .padding(.bottom, Spacing.xl)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spareSpring, value: scrollState.isAtTop)
        }
    }

    private var emptyBody: some View {
        ScrollView {
            EmptyStateView(
                icon: emptyIcon,
                title: emptyTitle,
                message: emptyMessage,
                actionLabel: emptyActionLabel,
                action: emptyAction
            )
            .padding(.top, Spacing.xxxl)
        }
    }

    private var loadedBody: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // Invisible offset tracker + scroll anchor
                GeometryReader { geo in
                    Color.clear.preference(
                        key: ScrollOffsetKey.self,
                        value: geo.frame(in: .named("waterfallScroll")).minY
                    )
                }
                .frame(height: 0)
                .id(Self.topAnchorID)

                WaterfallLayout(columns: 2, spacing: Spacing.md) {
                    ForEach(cards) { card in
                        cardView(card)
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
        .coordinateSpace(name: "waterfallScroll")
        .onPreferenceChange(ScrollOffsetKey.self) { offset in
            scrollState.offsetY = offset
            scrollState.isAtTop = offset > -40
        }
        .refreshable {
            await onRefresh?()
            hapticNotify()
        }
    }

    private func hapticNotify() {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
    }
}

// MARK: - Scroll To Top Button

struct ScrollToTopButton: View {
    var action: () -> Void

    var body: some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            action()
        } label: {
            Image(systemName: "arrow.up")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Color.primary.opacity(0.8), in: Circle())
                .cardShadow(prominent: true)
        }
    }
}
