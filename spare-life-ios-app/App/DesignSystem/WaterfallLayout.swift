// WaterfallLayout.swift
// Spare Life – Responsive dual-column waterfall card layout
// iPhone/iPad portrait: 2 columns, iPad landscape: 5 columns
// Design: yellow+white, light mode only

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Responsive Column Count

enum WaterfallColumns {
    /// Returns column count based on available width.
    /// iPhone (any orientation): 2
    /// iPad portrait: 2
    /// iPad landscape: 5
    static func count(for width: CGFloat) -> Int {
        if width >= 900 { return 5 }   // iPad landscape
        return 2                         // iPhone & iPad portrait
    }
}

// MARK: - WaterfallGrid (Scroll + Layout container)

struct WaterfallGrid<Data: RandomAccessCollection, Content: View>: View
where Data.Element: Identifiable {
    let data: Data
    let spacing: CGFloat
    @ViewBuilder let content: (Data.Element) -> Content

    init(
        _ data: Data,
        columns: Int = 2,
        spacing: CGFloat = Spacing.md,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            let cols = WaterfallColumns.count(for: proxy.size.width)
            let totalSpacing = spacing * CGFloat(cols - 1)
            let horizontalPadding = Spacing.lg * 2
            let columnWidth = max(120, floor((proxy.size.width - horizontalPadding - totalSpacing) / CGFloat(cols)))

            ScrollView(.vertical, showsIndicators: false) {
                ResponsiveMasonryLayout(columns: cols, spacing: spacing) {
                    ForEach(data) { item in
                        content(item)
                            .frame(width: columnWidth)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.xxxl)
            }
        }
    }
}

// MARK: - ResponsiveMasonryLayout (iOS 16 Layout protocol)

/// Height-balanced masonry layout. Each item goes into the shortest column.
/// Inspired by alphane-mobile-ios HomeMasonryGrid.
struct ResponsiveMasonryLayout: Layout {
    var columns: Int = 2
    var spacing: CGFloat = Spacing.md

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        let (_, totalHeight) = distribute(subviews: subviews, availableWidth: width)
        return CGSize(width: width, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (positions, _) = distribute(subviews: subviews, availableWidth: bounds.width)
        let colCount = max(columns, 1)
        let colWidth = (bounds.width - spacing * CGFloat(colCount - 1)) / CGFloat(colCount)

        for (index, subview) in subviews.enumerated() {
            guard index < positions.count else { break }
            subview.place(
                at: CGPoint(x: bounds.minX + positions[index].x, y: bounds.minY + positions[index].y),
                proposal: ProposedViewSize(width: colWidth, height: nil)
            )
        }
    }

    private func distribute(subviews: Subviews, availableWidth: CGFloat) -> ([CGPoint], CGFloat) {
        let colCount = max(columns, 1)
        let colWidth = (availableWidth - spacing * CGFloat(colCount - 1)) / CGFloat(colCount)
        var columnHeights = [CGFloat](repeating: 0, count: colCount)
        var positions: [CGPoint] = []

        for subview in subviews {
            let shortestCol = columnHeights.enumerated().min { $0.element < $1.element }?.offset ?? 0
            let x = CGFloat(shortestCol) * (colWidth + spacing)
            let y = columnHeights[shortestCol]
            positions.append(CGPoint(x: x, y: y))

            let itemSize = subview.sizeThatFits(ProposedViewSize(width: colWidth, height: nil))
            columnHeights[shortestCol] += itemSize.height + spacing
        }

        let totalHeight = columnHeights.max() ?? 0
        return (positions, totalHeight)
    }
}

// MARK: - WaterfallLayout (alias for backward compatibility)

typealias WaterfallLayout = ResponsiveMasonryLayout

// MARK: - Skeleton Card

struct SkeletonCard: View {
    var height: CGFloat
    var body: some View {
        RoundedRectangle(cornerRadius: CornerRadius.md)
            .fill(Color(.systemGray6))
            .frame(height: height)
            .shimmer()
    }
}

// MARK: - WaterfallFeed Skeleton

struct WaterfallSkeleton: View {
    var count: Int = 6
    var body: some View {
        let heights: [CGFloat] = [140, 180, 120, 160, 200, 130, 170, 110]
        GeometryReader { proxy in
            let cols = WaterfallColumns.count(for: proxy.size.width)
            ScrollView(.vertical, showsIndicators: false) {
                ResponsiveMasonryLayout(columns: cols, spacing: Spacing.md) {
                    ForEach(0..<count, id: \.self) { i in
                        SkeletonCard(height: heights[i % heights.count])
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
            }
            .allowsHitTesting(false)
        }
    }
}
