// ConversationHubView.swift
// Spare Life – IM 首页与最近聊天区
// Blueprint §消息 功能点 IM首页 (line:1137)
// Blueprint §统一UI 消息首页 IM 列表化 (line:1152) [UIUX]
// UIUX lane – slot 2

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ConversationHubView: View {
    @StateObject private var store = ConversationHubStore()
    @EnvironmentObject private var router: ConversationRouter
    @State private var sortMode: ConversationSortMode = .byTime

    var body: some View {
        ZStack {
            backgroundLayer

            Group {
                switch store.loadState {
                case .idle, .loading:
                    loadingBody
                case .loaded:
                    if store.filteredThreads.isEmpty && store.searchQuery.isEmpty {
                        emptyBody
                    } else {
                        loadedBody
                    }
                case .error(let msg):
                    ErrorStateView(message: msg, retry: store.retry)
                }
            }
        }
        .navigationTitle(navTitle)
        .spareNavigationBarTitleDisplayMode(.inline)
        .spareNavigationSearchable(text: $store.searchQuery, prompt: "搜索联系人或消息")
        .toolbar { toolbarContent }
        .task { store.load() }
    }

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [
                Color.spareYellow.opacity(0.12),
                Color.white,
                Color.white
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var navTitle: String {
        store.totalUnread > 0 ? "消息(\(store.totalUnread))" : "消息"
    }

    private var sortedThreads: [ConversationThread] {
        switch sortMode {
        case .byTime:
            return store.filteredThreads.sorted { $0.lastTimestamp > $1.lastTimestamp }
        case .byUnread:
            return store.filteredThreads.sorted {
                if $0.unreadCount == $1.unreadCount {
                    return $0.lastTimestamp > $1.lastTimestamp
                }
                return $0.unreadCount > $1.unreadCount
            }
        }
    }

    private var pinnedThreads: [ConversationThread] {
        guard store.searchQuery.isEmpty else { return [] }
        return sortedThreads.filter(\.isPinned)
    }

    private var listThreads: [ConversationThread] {
        if store.searchQuery.isEmpty {
            return sortedThreads.filter { !$0.isPinned }
        }
        return sortedThreads
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button { } label: { Label("新建对话", systemImage: "square.and.pencil") }
                Button { } label: { Label("新建群聊", systemImage: "person.3.fill") }

                Divider()

                ForEach(ConversationSortMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.spareSpring) { sortMode = mode }
                    } label: {
                        if sortMode == mode {
                            Label(mode.label, systemImage: "checkmark")
                        } else {
                            Text(mode.label)
                        }
                    }
                }

                Divider()

                filterButton(nil, label: "全部会话")
                filterButton(.human, label: "熟人")
                filterButton(.quadRole, label: "四人场")
                filterButton(.group, label: "群聊")
                filterButton(.agentDirect, label: "分身")
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.spareYellow)
            }
        }
    }

    private func filterButton(_ kind: ConversationKind?, label: String) -> some View {
        Button {
            withAnimation(.spareSpring) { store.selectedKind = kind }
        } label: {
            if store.selectedKind == kind {
                Label(label, systemImage: "checkmark")
            } else {
                Text(label)
            }
        }
    }

    // MARK: - Loading

    private var loadingBody: some View {
        List {
            ForEach(0..<7, id: \.self) { _ in
                HStack(spacing: Spacing.md) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 52, height: 52)
                        .shimmer()

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white)
                            .frame(width: 110, height: 14)
                            .shimmer()
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white)
                            .frame(maxWidth: 220)
                            .frame(height: 12)
                            .shimmer()
                    }

                    Spacer()
                }
                .padding(.vertical, Spacing.xs)
                .listRowBackground(Color.white)
                .listRowSeparatorTint(Color.spareYellow.opacity(0.14))
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Empty

    private var emptyBody: some View {
        VStack(spacing: Spacing.lg) {
            EmptyStateView(
                icon: "message.circle",
                title: "还没有聊天",
                message: "在赚闲能完成 A2A 破冰后，对话会出现在这里。",
                actionLabel: "去认识新朋友",
                action: {}
            )
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.xxxl)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                    .stroke(Color.spareYellow.opacity(0.18), lineWidth: 1)
            )
            .cardShadow()
            .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: - Loaded

    private var loadedBody: some View {
        List {
            if !pinnedThreads.isEmpty {
                ForEach(pinnedThreads) { thread in
                    threadRow(thread)
                }
            }

            if listThreads.isEmpty {
                noSearchResultRow
            } else {
                ForEach(listThreads) { thread in
                    threadRow(thread)
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await store.refresh() }
        .animation(.spareEase, value: sortMode)
        .animation(.spareEase, value: store.selectedKind)
        .animation(.spareEase, value: store.searchQuery)
    }

    private func threadRow(_ thread: ConversationThread) -> some View {
        Button {
            router.openChat(thread)
        } label: {
            HStack(spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(name: thread.contactName, size: 48)
                    listKindBadge(thread.kind)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(thread.contactName)
                        .font(thread.unreadCount > 0 ? .spareBodySB : .spareBody)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(threadPreview(thread))
                        .font(.spareCaption)
                        .foregroundColor(thread.unreadCount > 0 ? .primary : .secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: Spacing.sm)

                VStack(alignment: .trailing, spacing: 6) {
                    Text(thread.lastTimestamp, style: .relative)
                        .font(.spareMicro)
                        .foregroundColor(.secondary)

                    if thread.unreadCount > 0 {
                        unreadDot
                    }
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(thread.isPinned ? Color.spareYellow.opacity(0.08) : Color.white)
        .listRowSeparatorTint(Color.spareYellow.opacity(0.14))
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button { store.pin(threadID: thread.id) } label: {
                Label(thread.isPinned ? "取消置顶" : "置顶",
                      systemImage: thread.isPinned ? "pin.slash" : "pin.fill")
            }
            .tint(.spareYellow)

            Button(role: .destructive) { } label: {
                Label("删除", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button { store.markRead(threadID: thread.id) } label: {
                Label("已读", systemImage: "checkmark.circle.fill")
            }
            .tint(.emotionPositive)
        }
    }

    private func threadPreview(_ thread: ConversationThread) -> String {
        return thread.lastMessage
    }

    @ViewBuilder
    private func listKindBadge(_ kind: ConversationKind) -> some View {
        switch kind {
        case .human:
            EmptyView()
        case .quadRole:
            Image(systemName: "person.3.fill")
                .listBadgeStyle(color: .spareYellowInk)
        case .group:
            Image(systemName: "person.2.fill")
                .listBadgeStyle(color: .spareYellowInk)
        case .agentDirect:
            Image(systemName: "sparkles")
                .listBadgeStyle(color: .spareYellow)
        }
    }

    private var unreadDot: some View {
        Circle()
            .fill(Color.emotionNegative)
            .frame(width: 10, height: 10)
    }

    private var noSearchResultRow: some View {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "无匹配结果",
            message: "换个关键词试试？"
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxxl)
        .listRowBackground(Color.white)
        .listRowSeparator(.hidden)
    }
}

private extension Image {
    func listBadgeStyle(color: Color) -> some View {
        self
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(.white)
            .padding(4)
            .background(color, in: Circle())
            .offset(x: 4, y: 4)
    }
}
