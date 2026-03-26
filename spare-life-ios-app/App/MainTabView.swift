// MainTabView.swift
// Spare Life – Root tab bar connecting all 4 home feeds
// Blueprint §7 统一 UI · [UIUX] 4个首页双列瀑布流 (line:1150)
// UIUX lane – slot 2
//
// This is the app's primary navigation container. Each tab presents a
// unified dual-column waterfall feed with consistent scroll-to-top FAB,
// loading/empty/error states, and card flow design.

import SwiftUI
import UIKit

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
        case .xianxia:    return "咸虾"
        case .master:     return "大师"
        case .earnSocial: return "赚闲能"
        case .messages:   return "消息"
        case .myProfile:  return "我的"
        }
    }

    var icon: String {
        switch self {
        case .xianxia:    return "qrcode.viewfinder"
        case .master:     return "graduationcap.fill"
        case .earnSocial: return "bolt.circle.fill"
        case .messages:   return "message.fill"
        case .myProfile:  return "person.crop.circle.fill"
        }
    }

    var selectedIcon: String {
        switch self {
        case .xianxia:    return "qrcode.viewfinder"
        case .master:     return "graduationcap.fill"
        case .earnSocial: return "bolt.circle.fill"
        case .messages:   return "message.fill"
        case .myProfile:  return "person.crop.circle.fill"
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @State private var selectedTab: MainTab = .xianxia
    @State private var tabBarVisible = true
    @StateObject private var badgeStore = TabBadgeStore()

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            Group {
                switch selectedTab {
                case .xianxia:
                    XianxiaHomeView()
                case .master:
                    MasterHomeView()
                case .earnSocial:
                    EarnSocialHomeView()
                case .messages:
                    ConversationHubView()
                case .myProfile:
                    MyProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom tab bar
            if tabBarVisible {
                SpareTabBar(
                    selectedTab: $selectedTab,
                    badges: badgeStore.badges
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

// MARK: - Custom Tab Bar

/// A custom tab bar styled with Spare Life design tokens.
/// Uses spareYellow accent, card background, and spring animations.
private struct SpareTabBar: View {
    @Binding var selectedTab: MainTab
    var badges: [MainTab: Int]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.top, Spacing.sm)
        .padding(.bottom, bottomSafeArea)
        .background(
            Color(.secondarySystemGroupedBackground)
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: -4)
        )
    }

    private func tabButton(_ tab: MainTab) -> some View {
        let isSelected = selectedTab == tab
        let badge = badges[tab] ?? 0

        return Button {
            if selectedTab == tab { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spareSpring) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: Spacing.xxs) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                        .font(.system(size: 20, weight: isSelected ? .bold : .regular))
                        .foregroundColor(isSelected ? .spareYellow : .secondary)
                        .symbolEffect(.bounce, value: isSelected)

                    if badge > 0 {
                        Text(badge > 99 ? "99+" : "\(badge)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, badge > 9 ? 4 : 3)
                            .padding(.vertical, 1)
                            .background(Color.emotionNegative, in: Capsule())
                            .offset(x: 10, y: -6)
                    }
                }
                .frame(height: 24)

                Text(tab.label)
                    .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? .spareYellow : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var bottomSafeArea: CGFloat {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        return windowScene?.windows.first?.safeAreaInsets.bottom ?? 0
    }
}

// MARK: - Tab Badge Store

@MainActor
final class TabBadgeStore: ObservableObject {
    @Published var badges: [MainTab: Int] = [
        .messages: 3
    ]
}
