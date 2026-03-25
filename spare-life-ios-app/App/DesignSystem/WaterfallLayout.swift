// WaterfallLayout.swift
// Spare Life – dual-column waterfall card layout
// UIUX lane – slot 2

import SwiftUI

// MARK: - WaterfallGrid
// A two-column layout that places each item into the shorter column,
// producing the Pinterest / 小红书 style staggered grid.

struct WaterfallGrid<Data: RandomAccessCollection, Content: View>: View
where Data.Element: Identifiable {
    let data: Data
    let columns: Int
    let spacing: CGFloat
    @ViewBuilder let content: (Data.Element) -> Content

    init(
        _ data: Data,
        columns: Int = 2,
        spacing: CGFloat = Spacing.md,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.columns = columns
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            let totalSpacing = spacing * CGFloat(columns - 1)
            let columnWidth = (proxy.size.width - totalSpacing) / CGFloat(columns)

            ScrollView(.vertical, showsIndicators: false) {
                WaterfallLayout(columns: columns, spacing: spacing) {
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

// MARK: - WaterfallLayout (custom Layout)
// Requires iOS 16+ Layout protocol. Automatically fills shorter column first.

struct WaterfallLayout: Layout {
    var columns: Int = 2
    var spacing: CGFloat = Spacing.md

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        let (_, totalHeight) = distribute(subviews: subviews, availableWidth: width)
        return CGSize(width: width, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (positions, _) = distribute(subviews: subviews, availableWidth: bounds.width)
        for (index, subview) in subviews.enumerated() {
            guard index < positions.count else { break }
            subview.place(at: CGPoint(
                x: bounds.minX + positions[index].x,
                y: bounds.minY + positions[index].y
            ), proposal: .unspecified)
        }
    }

    private func distribute(subviews: Subviews, availableWidth: CGFloat) -> ([CGPoint], CGFloat) {
        guard columns > 0 else { return ([], 0) }
        let columnWidth = (availableWidth - spacing * CGFloat(columns - 1)) / CGFloat(columns)
        var columnHeights = [CGFloat](repeating: 0, count: columns)
        var positions: [CGPoint] = []

        for subview in subviews {
            // Pick the shortest column
            let shortestCol = columnHeights.enumerated().min { $0.element < $1.element }?.offset ?? 0
            let x = CGFloat(shortestCol) * (columnWidth + spacing)
            let y = columnHeights[shortestCol]
            positions.append(CGPoint(x: x, y: y))

            let itemSize = subview.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil))
            columnHeights[shortestCol] += itemSize.height + spacing
        }

        let totalHeight = columnHeights.max() ?? 0
        return (positions, totalHeight)
    }
}

// MARK: - Skeleton Card
// Universal shimmer placeholder for any card size.

struct SkeletonCard: View {
    var height: CGFloat
    var body: some View {
        RoundedRectangle(cornerRadius: CornerRadius.md)
            .fill(Color(.systemGray5))
            .frame(height: height)
            .shimmer()
    }
}

// MARK: - WaterfallFeed Skeleton
// Renders shimmer placeholders while content loads.

struct WaterfallSkeleton: View {
    var count: Int = 6
    var body: some View {
        let heights: [CGFloat] = [140, 180, 120, 160, 200, 130, 170, 110]
        ScrollView(.vertical, showsIndicators: false) {
            WaterfallLayout(columns: 2, spacing: Spacing.md) {
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
