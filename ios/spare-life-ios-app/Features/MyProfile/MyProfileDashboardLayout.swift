import SwiftUI

struct MyProfileDashboardLayout: Equatable {
    let availableWidth: CGFloat
    let columnCount: Int
    let cardSpacing: CGFloat
    let horizontalPadding: CGFloat
    let cardAspectRatio: CGFloat

    static func shared(for width: CGFloat) -> MyProfileDashboardLayout {
        MyProfileDashboardLayout(
            availableWidth: width,
            columnCount: WaterfallColumns.count(for: width),
            cardSpacing: Spacing.sm,
            horizontalPadding: Spacing.lg,
            cardAspectRatio: 8 / 5
        )
    }

    var gridItems: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: cardSpacing, alignment: .top),
            count: max(columnCount, 1)
        )
    }

    var minimumCardHeight: CGFloat {
        let totalSpacing = CGFloat(max(columnCount - 1, 0)) * cardSpacing
        let usableWidth = max(availableWidth - (horizontalPadding * 2) - totalSpacing, 0)
        let columnWidth = usableWidth / CGFloat(max(columnCount, 1))
        let ratioHeight = floor(columnWidth / cardAspectRatio)
        return max(112, ratioHeight)
    }
}
