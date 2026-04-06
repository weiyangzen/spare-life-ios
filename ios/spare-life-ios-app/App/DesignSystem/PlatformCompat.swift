// PlatformCompat.swift
// Spare Life – cross-platform shims for SwiftUI package indexing/building.
// Keep conditional compilation here or in explicit shell/container/interaction wrappers.
// Shared feature/business views should consume these helpers instead of scattering #if os(...)
// checks across runtime logic.

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit) && !canImport(UIKit)
import AppKit

extension NSColor {
    static var systemBackground: NSColor { .windowBackgroundColor }
    static var systemGroupedBackground: NSColor { NSColor(calibratedWhite: 0.95, alpha: 1.0) }
    static var secondarySystemGroupedBackground: NSColor { NSColor(calibratedWhite: 0.98, alpha: 1.0) }
    static var tertiarySystemGroupedBackground: NSColor { .controlBackgroundColor }
    static var separator: NSColor { .separatorColor }
    static var systemGray: NSColor { .gray }
    static var systemGray3: NSColor { NSColor(calibratedWhite: 0.66, alpha: 1.0) }
    static var systemGray4: NSColor { NSColor(calibratedWhite: 0.76, alpha: 1.0) }
    static var systemGray5: NSColor { NSColor(calibratedWhite: 0.84, alpha: 1.0) }
    static var systemGray6: NSColor { NSColor(calibratedWhite: 0.92, alpha: 1.0) }
    static var systemYellow: NSColor { NSColor(calibratedRed: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) }
}

struct UIEdgeInsets {
    var top: CGFloat = 0
    var left: CGFloat = 0
    var bottom: CGFloat = 0
    var right: CGFloat = 0
}

final class UIWindow {
    var safeAreaInsets = UIEdgeInsets()
}

final class UIWindowScene {
    var windows: [UIWindow] = []
}

@MainActor
final class UIApplication {
    static let shared = UIApplication()
    static let openSettingsURLString = "app-settings:"

    var connectedScenes: [Any] = []

    func open(_ url: URL) {}
}

final class UIImpactFeedbackGenerator {
    enum FeedbackStyle {
        case light
        case medium
    }

    init(style: FeedbackStyle) {}

    func impactOccurred() {}
}

final class UISelectionFeedbackGenerator {
    init() {}

    func selectionChanged() {}
}

final class UINotificationFeedbackGenerator {
    enum FeedbackType {
        case success
        case error
    }

    init() {}

    func notificationOccurred(_ feedbackType: FeedbackType) {}
}
#endif

enum SpareImpactFeedbackStyle {
    case light
    case medium
}

@MainActor
func spareBottomSafeAreaInset() -> CGFloat {
    #if canImport(UIKit)
    let scenes = UIApplication.shared.connectedScenes
    let windowScene = scenes.first as? UIWindowScene
    return windowScene?.windows.first?.safeAreaInsets.bottom ?? 0
    #else
    return 0
    #endif
}

@MainActor
func spareImpactFeedback(_ style: SpareImpactFeedbackStyle) {
    #if canImport(UIKit)
    let uiStyle: UIImpactFeedbackGenerator.FeedbackStyle = switch style {
    case .light: .light
    case .medium: .medium
    }
    UIImpactFeedbackGenerator(style: uiStyle).impactOccurred()
    #endif
}

enum SpareNavigationBarTitleDisplayMode {
    case automatic
    case inline
    case large
}

extension ToolbarItemPlacement {
    static var spareNavigationLeading: ToolbarItemPlacement {
        #if os(macOS)
        .cancellationAction
        #else
        .navigationBarLeading
        #endif
    }

    static var spareNavigationTrailing: ToolbarItemPlacement {
        #if os(macOS)
        .primaryAction
        #else
        .navigationBarTrailing
        #endif
    }

    static var spareTopBarTrailing: ToolbarItemPlacement {
        #if os(macOS)
        .primaryAction
        #else
        .topBarTrailing
        #endif
    }
}

private struct SpareNavigationBarTitleDisplayModeModifier: ViewModifier {
    let mode: SpareNavigationBarTitleDisplayMode

    func body(content: Content) -> some View {
        #if os(macOS)
        AnyView(content)
        #else
        switch mode {
        case .automatic:
            AnyView(content.navigationBarTitleDisplayMode(.automatic))
        case .inline:
            AnyView(content.navigationBarTitleDisplayMode(.inline))
        case .large:
            AnyView(content.navigationBarTitleDisplayMode(.large))
        }
        #endif
    }
}

private struct SpareNavigationBarHiddenModifier: ViewModifier {
    let hidden: Bool

    func body(content: Content) -> some View {
        #if os(macOS)
        AnyView(content)
        #else
        AnyView(content.navigationBarHidden(hidden))
        #endif
    }
}

private struct SpareNavigationBarClearBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
        AnyView(content)
        #else
        AnyView(content.toolbarBackground(.clear, for: .navigationBar))
        #endif
    }
}

private struct SpareNavigationSearchableModifier: ViewModifier {
    let text: Binding<String>
    let prompt: String

    func body(content: Content) -> some View {
        #if os(macOS)
        AnyView(content.searchable(text: text, prompt: prompt))
        #else
        AnyView(
            content.searchable(
                text: text,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: prompt
            )
        )
        #endif
    }
}

private struct SpareTextInputAutocapitalizationNeverModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
        AnyView(content)
        #else
        AnyView(content.textInputAutocapitalization(.never))
        #endif
    }
}

private struct SpareDisableAutocorrectionModifier: ViewModifier {
    let disabled: Bool

    func body(content: Content) -> some View {
        #if os(macOS)
        AnyView(content)
        #else
        AnyView(content.disableAutocorrection(disabled))
        #endif
    }
}

extension View {
    func spareNavigationBarTitleDisplayMode(_ mode: SpareNavigationBarTitleDisplayMode) -> some View {
        modifier(SpareNavigationBarTitleDisplayModeModifier(mode: mode))
    }

    func spareNavigationBarHidden(_ hidden: Bool) -> some View {
        modifier(SpareNavigationBarHiddenModifier(hidden: hidden))
    }

    func spareNavigationBarClearBackground() -> some View {
        modifier(SpareNavigationBarClearBackgroundModifier())
    }

    func spareNavigationSearchable(text: Binding<String>, prompt: String) -> some View {
        modifier(SpareNavigationSearchableModifier(text: text, prompt: prompt))
    }

    func spareTextInputAutocapitalizationNever() -> some View {
        modifier(SpareTextInputAutocapitalizationNeverModifier())
    }

    func spareDisableAutocorrection(_ disabled: Bool) -> some View {
        modifier(SpareDisableAutocorrectionModifier(disabled: disabled))
    }
}
