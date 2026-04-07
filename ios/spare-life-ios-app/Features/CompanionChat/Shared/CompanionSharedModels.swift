import SwiftUI

enum RelationTemperature: String, CaseIterable, Identifiable {
    case cold = "cold"
    case warming = "warming"
    case warm = "warm"
    case close = "close"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cold:
            return "陌生"
        case .warming:
            return "升温"
        case .warm:
            return "熟悉"
        case .close:
            return "亲近"
        }
    }

    var color: Color {
        switch self {
        case .cold:
            return .emotionNeutral
        case .warming:
            return .emotionSplit
        case .warm:
            return .spareYellow
        case .close:
            return .emotionPositive
        }
    }

    var icon: String {
        switch self {
        case .cold:
            return "thermometer.snowflake"
        case .warming:
            return "flame"
        case .warm:
            return "sun.max.fill"
        case .close:
            return "heart.fill"
        }
    }
}
