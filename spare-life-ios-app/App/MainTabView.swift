// MainTabView.swift
// Spare Life – Root tab bar with 5 buttons (center prominent)
// Blueprint §7 统一 UI · 4个首页双列瀑布流 (line:1150)
// Design: yellow (#FFCF12) + white, light mode only

import SwiftUI

// MARK: - Tab Identity

enum MainTab: String, CaseIterable, Identifiable {
    case xianxia    = "xianxia"
    case master     = "master"
    case earnSocial = "earn_social"
    case messages   = "messages"
    case myProfile  = "my_profile"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .xianxia:    return "闲虾"
        case .master:     return "闲聊"
        case .earnSocial: return "赚闲能"
        case .messages:   return "消息"
        case .myProfile:  return "我的"
        }
    }

    var icon: String {
        switch self {
        case .xianxia:    return "rectangle.grid.1x2"
        case .master:     return "graduationcap"
        case .earnSocial: return "bolt.circle.fill"
        case .messages:   return "message"
        case .myProfile:  return "person.crop.circle"
        }
    }

    var selectedIcon: String {
        switch self {
        case .xianxia:    return "rectangle.grid.1x2.fill"
        case .master:     return "graduationcap.fill"
        case .earnSocial: return "bolt.circle.fill"
        case .messages:   return "message.fill"
        case .myProfile:  return "person.crop.circle.fill"
        }
    }

    /// The center tab (赚闲能) is the prominent one with a larger icon.
    var isProminent: Bool { self == .earnSocial }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @State private var selectedTab: MainTab = .xianxia
    @StateObject private var badgeStore = TabBadgeStore()

    var body: some View {
        TabView(selection: $selectedTab) {
            XianxiaHomeView()
                .tag(MainTab.xianxia)
                .tabItem { Label("闲虾", systemImage: "rectangle.grid.1x2") }
            MasterChatHomeView()
                .tag(MainTab.master)
                .tabItem { Label("闲聊", systemImage: "graduationcap") }
            EarnSocialHomeView()
                .tag(MainTab.earnSocial)
                .tabItem { Label("赚闲能", systemImage: "bolt.circle.fill") }
            ConversationHubView()
                .tag(MainTab.messages)
                .tabItem { Label("消息", systemImage: "message") }
            MyProfileView()
                .tag(MainTab.myProfile)
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
        }
        .spareHideSystemTabBar()
        .safeAreaInset(edge: .bottom) {
            Color.clear
                .frame(height: tabBarReservedHeight)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottom) {
            SpareTabBar(
                selectedTab: $selectedTab,
                badges: badgeStore.badges
            )
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, bottomSafeArea > 0 ? bottomSafeArea - 8 : Spacing.sm)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(.spareSpring, value: selectedTab)
    }

    private var bottomSafeArea: CGFloat {
        spareBottomSafeAreaInset()
    }

    private var tabBarReservedHeight: CGFloat {
        82 + max(bottomSafeArea, 8)
    }

}

// MARK: - Glass-Style Tab Bar

/// Floating tab bar with glass morphism, yellow accent, and a prominent center button.
/// Inspired by alphane-mobile-ios GlassTabBarView pattern.
private struct SpareTabBar: View {
    @Binding var selectedTab: MainTab
    var badges: [MainTab: Int]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.spareYellow.opacity(0.18), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.10), radius: 20, y: 8)
        )
    }

    private func tabButton(_ tab: MainTab) -> some View {
        let isSelected = selectedTab == tab
        let badge = badges[tab] ?? 0

        return Button {
            guard selectedTab != tab else { return }
            spareImpactFeedback(.light)
            withAnimation(.spareSpring) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    if tab.isProminent {
                        prominentIcon(tab, isSelected: isSelected)
                    } else {
                        regularIcon(tab, isSelected: isSelected)
                    }

                    if badge > 0 {
                        badgeView(badge)
                            .offset(x: tab.isProminent ? 8 : 6, y: tab.isProminent ? -4 : -3)
                    }
                }

                Text(tab.label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .spareYellow : Color(.systemGray))
                    .lineLimit(1)

                if !tab.isProminent {
                    Circle()
                        .fill(isSelected ? Color.spareYellow : Color.clear)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("main-tab-\(tab.rawValue)")
    }

    // Regular tab icon
    private func regularIcon(_ tab: MainTab, isSelected: Bool) -> some View {
        Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
            .font(.system(size: 20, weight: .medium))
            .foregroundColor(isSelected ? .spareYellow : Color(.systemGray))
            .frame(width: 36, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.spareYellow.opacity(0.12) : Color.clear)
            )
    }

    // Prominent center tab icon (larger, gradient background)
    private func prominentIcon(_ tab: MainTab, isSelected: Bool) -> some View {
        Image(systemName: tab.icon)
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 44, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.spareYellow, Color.spareOrange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .opacity(isSelected ? 1.0 : 0.80)
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .shadow(color: Color.spareYellow.opacity(isSelected ? 0.40 : 0.20), radius: isSelected ? 14 : 8, y: 4)
            .animation(.spareSpring, value: isSelected)
    }

    private func badgeView(_ count: Int) -> some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, count > 9 ? 4 : 3)
            .padding(.vertical, 1)
            .background(Capsule().fill(Color.emotionNegative))
    }
}

// MARK: - Tab Badge Store

@MainActor
final class TabBadgeStore: ObservableObject {
    @Published var badges: [MainTab: Int] = [
        .messages: 3
    ]
}

// MARK: - Hide System Tab Bar

private extension View {
    @ViewBuilder
    func spareHideSystemTabBar() -> some View {
        #if os(iOS)
        if #available(iOS 16.0, *) {
            self.toolbar(.hidden, for: .tabBar)
        } else {
            self
        }
        #else
        self
        #endif
    }
}
