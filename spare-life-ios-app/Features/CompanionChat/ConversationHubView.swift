// ConversationHubView.swift
// Spare Life – IM 首页与最近聊天区
// Blueprint §消息 功能点 IM首页 (line:1137)
// UIUX lane – slot 2

import SwiftUI

struct ConversationHubView: View {
    @StateObject private var store = ConversationHubStore()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

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
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $store.searchQuery, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "搜索联系人或消息")
            .toolbar { toolbarContent }
            .task { store.load() }
        }
    }

    private var navTitle: String {
        store.totalUnread > 0 ? "消息（\(store.totalUnread)）" : "消息"
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button { } label: { Label("新建对话", systemImage: "square.and.pencil") }
                Button { } label: { Label("新建群聊", systemImage: "person.3.fill") }
            } label: {
                Image(systemName: "square.and.pencil.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.spareYellow)
            }
        }
    }

    // MARK: - Loading

    private var loadingBody: some View {
        List {
            ForEach(0..<6, id: \.self) { _ in
                HStack(spacing: Spacing.md) {
                    Circle()
                        .fill(Color.cardBackground)
                        .frame(width: 52, height: 52)
                        .shimmer()
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.cardBackground)
                            .frame(width: 120, height: 14)
                            .shimmer()
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.cardBackground)
                            .frame(width: 200, height: 12)
                            .shimmer()
                    }
                }
                .padding(.vertical, Spacing.xs)
                .listRowBackground(Color(.secondarySystemGroupedBackground))
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Empty

    private var emptyBody: some View {
        EmptyStateView(
            icon: "message.circle",
            title: "还没有聊天",
            message: "在赚闲能完成 A2A 破冰后，对话会出现在这里。",
            actionLabel: "去认识新朋友",
            action: {}
        )
    }

    // MARK: - Loaded

    private var loadedBody: some View {
        List {
            // Kind filter chips
            kindFilterSection

            // Pinned section
            let pinned = store.filteredThreads.filter { $0.isPinned }
            if !pinned.isEmpty && store.searchQuery.isEmpty {
                Section {
                    ForEach(pinned) { thread in
                        threadRow(thread)
                    }
                } header: {
                    Text("置顶")
                        .font(.spareCaptionSB)
                        .foregroundColor(.secondary)
                }
            }

            // All / search results
            let others = store.filteredThreads.filter { !$0.isPinned || !store.searchQuery.isEmpty }
            Section {
                if others.isEmpty {
                    noSearchResultRow
                } else {
                    ForEach(others) { thread in
                        threadRow(thread)
                    }
                    .onDelete { indexSet in
                        // Deletion UX stub – production would call store.delete
                        _ = indexSet
                    }
                }
            } header: {
                if store.searchQuery.isEmpty {
                    Text("最近聊天")
                        .font(.spareCaptionSB)
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await store.refresh() }
    }

    // MARK: - Kind Filter Chips

    private var kindFilterSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    kindChip(nil, label: "全部", icon: "bubble.left.and.bubble.right.fill")
                    kindChip(.human, label: "熟人", icon: "person.fill")
                    kindChip(.quadRole, label: "四人场", icon: "person.3.fill")
                    kindChip(.group, label: "群聊", icon: "person.2.wave.2.fill")
                    kindChip(.agentDirect, label: "分身", icon: "sparkles")
                }
                .padding(.vertical, Spacing.xs)
            }
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 0, leading: Spacing.lg, bottom: 0, trailing: Spacing.lg))
    }

    private func kindChip(_ kind: ConversationKind?, label: String, icon: String) -> some View {
        let isSelected = store.selectedKind == kind
        return Button {
            withAnimation(.spareSpring) {
                store.selectedKind = isSelected ? nil : kind
            }
        } label: {
            Label(label, systemImage: icon)
                .font(.spareCaptionSB)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(isSelected ? Color.spareYellow : Color.cardBackground,
                            in: Capsule())
                .cardShadow()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Thread Row

    private func threadRow(_ thread: ConversationThread) -> some View {
        NavigationLink {
            ChatThreadView(thread: thread)
        } label: {
            HStack(alignment: .center, spacing: Spacing.md) {
                // Avatar + kind badge
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(name: thread.contactName, size: 52)
                    kindBadge(thread.kind)
                }

                // Content
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text(thread.contactName)
                            .font(thread.unreadCount > 0 ? .spareBodySB : .spareBody)
                            .lineLimit(1)
                        Spacer()
                        Text(thread.lastTimestamp, style: .relative)
                            .font(.spareMicro)
                            .foregroundColor(.secondary)
                    }

                    HStack(alignment: .center, spacing: Spacing.xs) {
                        Text(thread.lastMessage)
                            .font(.spareCaption)
                            .foregroundColor(thread.unreadCount > 0 ? .primary : .secondary)
                            .lineLimit(1)
                        Spacer()
                        if thread.unreadCount > 0 {
                            unreadBadge(thread.unreadCount)
                        }
                    }

                    // Temperature + mask tags
                    HStack(spacing: Spacing.xs) {
                        Label(thread.relationTemperature.label,
                              systemImage: thread.relationTemperature.icon)
                            .font(.spareMicro)
                            .foregroundColor(thread.relationTemperature.color)

                        if let mask = thread.activeMaskName {
                            PillTag(label: mask, color: .blue)
                        }
                    }
                }
            }
            .padding(.vertical, Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color(.secondarySystemGroupedBackground))
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

    private func kindBadge(_ kind: ConversationKind) -> some View {
        Group {
            switch kind {
            case .human:       EmptyView()
            case .quadRole:
                Image(systemName: "person.3.fill")
                    .badgeStyle(color: .blue)
            case .group:
                Image(systemName: "person.2.wave.2.fill")
                    .badgeStyle(color: .indigo)
            case .agentDirect:
                Image(systemName: "sparkles")
                    .badgeStyle(color: Color.spareYellow)
            }
        }
    }

    private func unreadBadge(_ count: Int) -> some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.spareMicro)
            .foregroundColor(.white)
            .padding(.horizontal, count > 9 ? 6 : 5)
            .padding(.vertical, 2)
            .background(Color.emotionNegative, in: Capsule())
    }

    private var noSearchResultRow: some View {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "无匹配结果",
            message: "换个关键词试试？"
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

// MARK: - View Modifier Helper

private extension Image {
    func badgeStyle(color: Color) -> some View {
        self
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.white)
            .padding(4)
            .background(color, in: Circle())
            .offset(x: 6, y: 6)
    }
}
