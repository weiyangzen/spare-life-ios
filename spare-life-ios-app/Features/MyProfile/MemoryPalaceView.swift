// MemoryPalaceView.swift
// Spare Life – 我的 · 记忆宫殿管理
// Blueprint §7 我的 · [UIUX] 记忆宫殿管理 (id: 340e7a9da6d9)
// UIUX lane – slot 2

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Models

struct MemoryEntry: Identifiable {
    let id: String
    var title: String
    var content: String
    var category: Category
    var importance: Importance
    var isEncrypted: Bool
    var permission: Permission
    let createdAt: Date
    var updatedAt: Date

    enum Category: String, CaseIterable {
        case preference  = "偏好"
        case experience  = "经历"
        case belief      = "信念"
        case relationship = "关系"
        case goal        = "目标"
        case knowledge   = "知识"

        var icon: String {
            switch self {
            case .preference:   return "heart"
            case .experience:   return "clock.arrow.circlepath"
            case .belief:       return "sparkles"
            case .relationship: return "person.2"
            case .goal:         return "target"
            case .knowledge:    return "book"
            }
        }

        var color: Color {
            switch self {
            case .preference:   return .pink
            case .experience:   return .blue
            case .belief:       return .purple
            case .relationship: return .green
            case .goal:         return .orange
            case .knowledge:    return .teal
            }
        }
    }

    enum Importance: String, CaseIterable {
        case core      = "核心"
        case important = "重要"
        case ordinary  = "普通"

        var color: Color {
            switch self {
            case .core:      return .red
            case .important: return .orange
            case .ordinary:  return .secondary
            }
        }
    }

    enum Permission: String, CaseIterable {
        case `private`  = "仅自己"
        case avatar     = "分身可见"
        case `public`   = "公开"

        var icon: String {
            switch self {
            case .private:  return "lock.fill"
            case .avatar:   return "person.crop.circle.badge.checkmark"
            case .public:   return "globe"
            }
        }
    }
}

enum MemoryLoadState {
    case idle, loading, loaded, error(String)
}

// MARK: - Store

@MainActor
final class MemoryPalaceStore: ObservableObject {
    @Published var loadState: MemoryLoadState = .idle
    @Published var entries: [MemoryEntry] = []
    @Published var selectedCategory: MemoryEntry.Category? = nil
    @Published var searchText = ""
    @Published var editingEntry: MemoryEntry? = nil
    @Published var showAddEntry = false
    @Published var pendingDeleteID: String? = nil

    var filteredEntries: [MemoryEntry] {
        var result = entries
        if let cat = selectedCategory {
            result = result.filter { $0.category == cat }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(q) || $0.content.lowercased().contains(q)
            }
        }
        return result.sorted { $0.importance.rawValue < $1.importance.rawValue }
    }

    func load() {
        guard case .idle = loadState else { return }
        loadState = .loading
        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            entries = [
                .init(id: "m1", title: "讨厌被人催", content: "对给出 deadline 催促的语气极度反感，尤其是在创意工作上。", category: .preference, importance: .core, isEncrypted: false, permission: .avatar, createdAt: Date().addingTimeInterval(-86400 * 30), updatedAt: Date().addingTimeInterval(-3600)),
                .init(id: "m2", title: "2023 年底辞职创业", content: "从大厂离开，开始第一次创业之旅，心境的转变是最大收获。", category: .experience, importance: .important, isEncrypted: false, permission: .avatar, createdAt: Date().addingTimeInterval(-86400 * 120), updatedAt: Date().addingTimeInterval(-86400 * 5)),
                .init(id: "m3", title: "相信成长型心态", content: "核心信念：人的能力不是固定的，通过刻意练习可以持续突破。", category: .belief, importance: .core, isEncrypted: false, permission: .avatar, createdAt: Date().addingTimeInterval(-86400 * 60), updatedAt: Date().addingTimeInterval(-86400 * 10)),
                .init(id: "m4", title: "家庭联系人敏感信息", content: "（已加密，仅本地存储）", category: .relationship, importance: .core, isEncrypted: true, permission: .private, createdAt: Date().addingTimeInterval(-86400 * 90), updatedAt: Date().addingTimeInterval(-86400 * 2)),
                .init(id: "m5", title: "今年目标：发布 MMP", content: "在 2026 年 Q3 前完成 spare-life 第一版公测。", category: .goal, importance: .important, isEncrypted: false, permission: .avatar, createdAt: Date().addingTimeInterval(-86400 * 20), updatedAt: Date()),
                .init(id: "m6", title: "SwiftUI 状态管理偏好", content: "倾向 @StateObject + Combine，避免过度使用 @EnvironmentObject。", category: .knowledge, importance: .ordinary, isEncrypted: false, permission: .avatar, createdAt: Date().addingTimeInterval(-86400 * 15), updatedAt: Date().addingTimeInterval(-86400)),
            ]
            loadState = .loaded
        }
    }

    func reload() { loadState = .idle; load() }

    func delete(id: String) {
        entries.removeAll { $0.id == id }
    }
}

// MARK: - Root View

struct MemoryPalaceView: View {
    @StateObject private var store = MemoryPalaceStore()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                contentBody
            }
            .navigationTitle("记忆宫殿")
            .spareNavigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.showAddEntry = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .task { store.load() }
    }

    @ViewBuilder
    private var contentBody: some View {
        switch store.loadState {
        case .idle, .loading:
            MemorySkeletonView()
        case .loaded:
            MemoryScrollView(store: store)
        case .error(let msg):
            ErrorStateView(message: msg, retry: { store.reload() })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Scroll View

private struct MemoryScrollView: View {
    @ObservedObject var store: MemoryPalaceStore

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索记忆…", text: $store.searchText)
                    .font(.spareBody)
                if !store.searchText.isEmpty {
                    Button { store.searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)

            // Category filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    CategoryChip(label: "全部", icon: "square.grid.2x2", isSelected: store.selectedCategory == nil) {
                        withAnimation(.spareEase) { store.selectedCategory = nil }
                    }
                    ForEach(MemoryEntry.Category.allCases, id: \.self) { cat in
                        CategoryChip(label: cat.rawValue, icon: cat.icon, color: cat.color, isSelected: store.selectedCategory == cat) {
                            withAnimation(.spareEase) {
                                store.selectedCategory = (store.selectedCategory == cat) ? nil : cat
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }
            .padding(.vertical, Spacing.xs)

            // Memory list
            if store.filteredEntries.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "brain",
                    title: store.searchText.isEmpty ? "记忆宫殿是空的" : "没有匹配的记忆",
                    message: store.searchText.isEmpty ? "点击右上角 + 添加第一条记忆。" : "换个关键词试试。",
                    actionLabel: store.searchText.isEmpty ? "添加记忆" : nil,
                    action: { store.showAddEntry = true }
                )
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: Spacing.sm) {
                        ForEach(store.filteredEntries) { entry in
                            MemoryEntryRow(entry: entry, onEdit: {
                                store.editingEntry = entry
                            }, onDelete: {
                                store.delete(id: entry.id)
                            })
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.xxxl + 32)
                }
                .refreshable { store.reload() }
            }
        }
        .sheet(item: $store.editingEntry) { entry in
            MemoryEditSheet(entry: entry)
                .presentationDragIndicator(.visible)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $store.showAddEntry) {
            MemoryAddSheet()
                .presentationDragIndicator(.visible)
                .presentationDetents([.large])
        }
    }
}

// MARK: - Category Chip

private struct CategoryChip: View {
    let label: String
    let icon: String
    var color: Color = .secondary
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.spareMicro)
                Text(label)
                    .font(.spareCaptionSB)
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(isSelected ? color : Color(.secondarySystemGroupedBackground), in: Capsule())
        }
    }
}

// MARK: - Memory Entry Row

private struct MemoryEntryRow: View {
    let entry: MemoryEntry
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top) {
                Image(systemName: entry.category.icon)
                    .foregroundColor(entry.category.color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xs) {
                        Text(entry.title)
                            .font(.spareBodySB)
                        if entry.isEncrypted {
                            Image(systemName: "lock.fill")
                                .font(.spareMicro)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        ImportanceDot(importance: entry.importance)
                    }
                    HStack(spacing: Spacing.xs) {
                        PillTag(label: entry.category.rawValue, color: entry.category.color)
                        PermissionBadge(permission: entry.permission)
                        Spacer()
                        Text(entry.updatedAt, style: .relative)
                            .font(.spareMicro)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if !entry.isEncrypted {
                Button {
                    withAnimation(.spareSpring) { expanded.toggle() }
                } label: {
                    HStack {
                        Text(entry.content)
                            .font(.spareCaption)
                            .foregroundColor(.secondary)
                            .lineLimit(expanded ? nil : 2)
                        Spacer()
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.spareMicro)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if expanded {
                    HStack(spacing: Spacing.md) {
                        Button("编辑") { onEdit() }
                            .font(.spareCaptionSB)
                            .foregroundColor(.blue)
                        Spacer()
                        Button(role: .destructive) { onDelete() } label: {
                            Label("删除", systemImage: "trash")
                                .font(.spareCaptionSB)
                        }
                    }
                    .padding(.top, Spacing.xs)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            } else {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "lock.fill")
                        .font(.spareMicro)
                    Text("内容已加密，仅本地可读")
                        .font(.spareCaption)
                }
                .foregroundColor(.secondary)
                .padding(.vertical, Spacing.xs)
            }
        }
        .padding(Spacing.md)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
        .cardShadow()
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(entry.importance == .core ? entry.category.color.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

private struct ImportanceDot: View {
    let importance: MemoryEntry.Importance
    var body: some View {
        Circle()
            .fill(importance.color)
            .frame(width: 8, height: 8)
    }
}

private struct PermissionBadge: View {
    let permission: MemoryEntry.Permission
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: permission.icon)
                .font(.spareMicro)
            Text(permission.rawValue)
                .font(.spareMicro)
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
    }
}

// MARK: - Sheets

private struct MemoryEditSheet: View {
    let entry: MemoryEntry
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var content: String
    @State private var permission: MemoryEntry.Permission

    init(entry: MemoryEntry) {
        self.entry = entry
        _title      = State(initialValue: entry.title)
        _content    = State(initialValue: entry.content)
        _permission = State(initialValue: entry.permission)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("内容") {
                    TextField("标题", text: $title)
                    TextField("详细内容", text: $content, axis: .vertical).lineLimit(3...8)
                }
                Section("权限") {
                    Picker("可见范围", selection: $permission) {
                        ForEach(MemoryEntry.Permission.allCases, id: \.self) { p in
                            Label(p.rawValue, systemImage: p.icon).tag(p)
                        }
                    }
                }
                Section { Button("保存") { dismiss() }.frame(maxWidth: .infinity, alignment: .center) }
            }
            .navigationTitle("编辑记忆")
            .spareNavigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        }
    }
}

private struct MemoryAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var content = ""
    @State private var category = MemoryEntry.Category.preference
    @State private var importance = MemoryEntry.Importance.ordinary
    @State private var permission = MemoryEntry.Permission.avatar

    var body: some View {
        NavigationStack {
            Form {
                Section("内容") {
                    TextField("标题", text: $title)
                    TextField("详细内容", text: $content, axis: .vertical).lineLimit(3...8)
                }
                Section("分类与重要性") {
                    Picker("分类", selection: $category) {
                        ForEach(MemoryEntry.Category.allCases, id: \.self) { c in Label(c.rawValue, systemImage: c.icon).tag(c) }
                    }
                    Picker("重要性", selection: $importance) {
                        ForEach(MemoryEntry.Importance.allCases, id: \.self) { i in Text(i.rawValue).tag(i) }
                    }
                }
                Section("权限") {
                    Picker("可见范围", selection: $permission) {
                        ForEach(MemoryEntry.Permission.allCases, id: \.self) { p in Label(p.rawValue, systemImage: p.icon).tag(p) }
                    }
                }
                Section { Button("添加") { dismiss() }.frame(maxWidth: .infinity, alignment: .center).disabled(title.isEmpty) }
            }
            .navigationTitle("添加记忆")
            .spareNavigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        }
    }
}

// MARK: - Skeleton

private struct MemorySkeletonView: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            RoundedRectangle(cornerRadius: CornerRadius.md).fill(Color(.systemGray5)).frame(height: 40).shimmer()
            RoundedRectangle(cornerRadius: CornerRadius.pill).fill(Color(.systemGray5)).frame(height: 32).shimmer()
            ForEach(0..<4) { _ in
                RoundedRectangle(cornerRadius: CornerRadius.md).fill(Color(.systemGray5)).frame(height: 80).shimmer()
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg)
    }
}

#if DEBUG
#Preview {
    MemoryPalaceView()
}
#endif
