// DesignTokens.swift
// Spare Life – unified design system primitives
// UIUX lane – slot 2

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Color Palette

extension Color {
    // Brand
    static let spareYellow      = Color(red: 1.00, green: 0.82, blue: 0.07)   // primary CTA / tab highlight
    static let spareYellowLight = Color(red: 1.00, green: 0.94, blue: 0.60)
    static let spareDark        = Color(red: 0.08, green: 0.08, blue: 0.10)   // near-black surface

    // Emotion tags
    static let emotionPositive  = Color(red: 0.20, green: 0.78, blue: 0.49)
    static let emotionNegative  = Color(red: 0.94, green: 0.32, blue: 0.32)
    static let emotionSplit     = Color(red: 0.97, green: 0.62, blue: 0.22)
    static let emotionNeutral   = Color(red: 0.60, green: 0.60, blue: 0.65)

    // Scene category chips
    static let chipSelected     = Color.spareYellow
    static let chipUnselected   = Color(.systemGray5)

    // Card surfaces
    static let cardBackground   = Color(.secondarySystemGroupedBackground)
    static let cardStroke       = Color(.separator).opacity(0.5)

    // Avatar gradient pair (for placeholder avatars)
    static func avatarGradient(seed: Int) -> LinearGradient {
        let pairs: [(Color, Color)] = [
            (.purple, .pink),
            (.blue, .cyan),
            (.green, .teal),
            (.orange, .yellow),
            (.indigo, .blue),
        ]
        let pair = pairs[abs(seed) % pairs.count]
        return LinearGradient(colors: [pair.0, pair.1], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Spacing Scale

enum Spacing {
    static let xxs: CGFloat = 2
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 12
    static let lg:  CGFloat = 16
    static let xl:  CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
}

// MARK: - Corner Radius

enum CornerRadius {
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 12
    static let lg:  CGFloat = 16
    static let xl:  CGFloat = 20
    static let pill: CGFloat = 999
}

// MARK: - Typography

extension Font {
    // Display
    static let spareTitle1  = Font.system(size: 28, weight: .bold, design: .rounded)
    static let spareTitle2  = Font.system(size: 22, weight: .bold, design: .rounded)
    static let spareTitle3  = Font.system(size: 18, weight: .semibold, design: .rounded)

    // Body
    static let spareBody    = Font.system(size: 15, weight: .regular, design: .default)
    static let spareBodySB  = Font.system(size: 15, weight: .semibold, design: .default)
    static let spareCaption = Font.system(size: 13, weight: .regular, design: .default)
    static let spareCaptionSB = Font.system(size: 13, weight: .semibold, design: .default)
    static let spareMicro   = Font.system(size: 11, weight: .medium, design: .default)
}

// MARK: - Animation Presets

extension Animation {
    static let spareSpring = Animation.spring(response: 0.38, dampingFraction: 0.72)
    static let spareEase   = Animation.easeInOut(duration: 0.22)
    static let spareFast   = Animation.easeOut(duration: 0.15)
}

// MARK: - Shadow Style

struct CardShadow: ViewModifier {
    var prominent: Bool = false
    func body(content: Content) -> some View {
        content
            .shadow(
                color: Color.black.opacity(prominent ? 0.12 : 0.06),
                radius: prominent ? 12 : 6,
                x: 0,
                y: prominent ? 4 : 2
            )
    }
}

extension View {
    func cardShadow(prominent: Bool = false) -> some View {
        modifier(CardShadow(prominent: prominent))
    }
}

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.35),
                            Color.white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: -geo.size.width + geo.size.width * 2 * phase)
                }
                .clipped()
            )
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Pill Tag

struct PillTag: View {
    let label: String
    var color: Color = .secondary
    var filled: Bool = false

    var body: some View {
        Text(label)
            .font(.spareMicro)
            .foregroundColor(filled ? .white : color)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule()
                    .fill(filled ? color : color.opacity(0.12))
            )
    }
}

// MARK: - Emotion Badge

struct EmotionBadge: View {
    enum Emotion: String, CaseIterable {
        case positive = "正向"
        case negative = "负向"
        case split    = "分裂"
        case neutral  = "中性"

        var color: Color {
            switch self {
            case .positive: return .emotionPositive
            case .negative: return .emotionNegative
            case .split:    return .emotionSplit
            case .neutral:  return .emotionNeutral
            }
        }

        var icon: String {
            switch self {
            case .positive: return "arrow.up.circle.fill"
            case .negative: return "arrow.down.circle.fill"
            case .split:    return "bolt.circle.fill"
            case .neutral:  return "minus.circle.fill"
            }
        }
    }

    let emotion: Emotion

    var body: some View {
        Label(emotion.rawValue, systemImage: emotion.icon)
            .font(.spareMicro)
            .foregroundColor(emotion.color)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(Capsule().fill(emotion.color.opacity(0.12)))
    }
}

// MARK: - Avatar View

struct AvatarView: View {
    let name: String
    var size: CGFloat = 40
    var avatarURL: URL? = nil

    private var seed: Int {
        abs(name.hashValue)
    }

    var body: some View {
        ZStack {
            Color.avatarGradient(seed: seed)
            Text(String(name.prefix(1)))
                .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary)

            VStack(spacing: Spacing.sm) {
                Text(title)
                    .font(.spareTitle3)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let label = actionLabel, let action {
                Button(action: action) {
                    Text(label)
                        .font(.spareBodySB)
                        .foregroundColor(.white)
                        .padding(.horizontal, Spacing.xl)
                        .padding(.vertical, Spacing.md)
                        .background(Color.spareYellow, in: Capsule())
                }
            }
        }
        .padding(Spacing.xxxl)
    }
}

// MARK: - Error State View

struct ErrorStateView: View {
    let message: String
    var cached: Bool = false
    var retry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(.emotionNegative)

            VStack(spacing: Spacing.sm) {
                Text("加载出错了")
                    .font(.spareTitle3)
                if cached {
                    Text("已显示上次缓存内容")
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                }
                Text(message)
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let retry {
                Button(action: retry) {
                    Label("重试", systemImage: "arrow.clockwise")
                        .font(.spareBodySB)
                        .foregroundColor(.white)
                        .padding(.horizontal, Spacing.xl)
                        .padding(.vertical, Spacing.md)
                        .background(Color.primary, in: Capsule())
                }
            }
        }
        .padding(Spacing.xxxl)
    }
}

// MARK: - CardPressStyle

/// Reusable press-scale button style for tappable cards.
struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spareFast, value: configuration.isPressed)
    }
}
