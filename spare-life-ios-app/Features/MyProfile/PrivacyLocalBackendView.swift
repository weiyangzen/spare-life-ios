// PrivacyLocalBackendView.swift
// Spare Life – 我的 · 隐私与本地后端控制
// Blueprint §7 我的 · [UIUX] 隐私与本地后端控制 (id: 5b311fc8953d)
// UIUX lane – slot 2

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Models

struct DBStatus {
    var sizeBytes: Int64
    var tableCount: Int
    var lastMigration: String
    var migrationVersion: Int
    var isHealthy: Bool
    var lastBackupDate: Date?
    var tables: [TableInfo]

    struct TableInfo: Identifiable {
        let id: String
        let name: String
        let rowCount: Int
        let sizeBytes: Int64
    }

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

struct AuthGrant: Identifiable {
    let id: String
    let serviceName: String
    let permissionLabel: String
    let grantedAt: Date
    var isActive: Bool
    let scope: String
    let icon: String
}

struct CleanupOption: Identifiable {
    let id: String
    let label: String
    let description: String
    let icon: String
    let color: Color
    var isDestructive: Bool = false
}

enum PrivacyLoadState {
    case idle, loading, loaded, error(String)
}

// MARK: - Store

@MainActor
final class PrivacyLocalBackendStore: ObservableObject {
    @Published var loadState: PrivacyLoadState = .idle
    @Published var dbStatus: DBStatus? = nil
    @Published var authGrants: [AuthGrant] = []
    @Published var selectedTab: Tab = .database
    @Published var showConfirmBackup = false
    @Published var showConfirmClean = false
    @Published var pendingCleanup: CleanupOption? = nil
    @Published var backupInProgress = false
    @Published var lastActionResult: ActionResult? = nil

    enum Tab: String, CaseIterable {
        case database  = "数据库"
        case backup    = "备份清理"
        case auth      = "授权面板"
    }

    struct ActionResult: Identifiable {
        let id = UUID()
        let message: String
        let isSuccess: Bool
    }

    let cleanupOptions: [CleanupOption] = [
        .init(id: "c1", label: "清理过期消息缓存", description: "删除 30 天前已读消息的本地副本，释放存储空间。", icon: "message.badge.circle", color: .blue),
        .init(id: "c2", label: "压缩记忆向量索引", description: "重建向量索引以减小体积，不影响记忆内容。", icon: "cylinder.split.1x2", color: .purple),
        .init(id: "c3", label: "清除调试日志", description: "删除所有本地调试和性能日志。", icon: "doc.text.badge.minus", color: .orange),
        .init(id: "c4", label: "重置本地数据库", description: "删除全部本地数据，恢复到初始状态。此操作不可撤销。", icon: "trash.fill", color: .red, isDestructive: true),
    ]

    func load() {
        guard case .idle = loadState else { return }
        loadState = .loading
        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            dbStatus = DBStatus(
                sizeBytes: 4_823_040,
                tableCount: 12,
                lastMigration: "v8_add_memory_vectors",
                migrationVersion: 8,
                isHealthy: true,
                lastBackupDate: Date().addingTimeInterval(-86400 * 3),
                tables: [
                    .init(id: "t1", name: "users",              rowCount: 1,     sizeBytes: 4_096),
                    .init(id: "t2", name: "memories",           rowCount: 128,   sizeBytes: 921_600),
                    .init(id: "t3", name: "messages",           rowCount: 3_412, sizeBytes: 2_048_000),
                    .init(id: "t4", name: "personas",           rowCount: 3,     sizeBytes: 16_384),
                    .init(id: "t5", name: "sync_tasks",         rowCount: 47,    sizeBytes: 65_536),
                    .init(id: "t6", name: "auth_grants",        rowCount: 4,     sizeBytes: 4_096),
                    .init(id: "t7", name: "feed_events",        rowCount: 892,   sizeBytes: 524_288),
                    .init(id: "t8", name: "growth_stats",       rowCount: 26,    sizeBytes: 32_768),
                ]
            )
            authGrants = [
                .init(id: "g1", serviceName: "分身代理回复",    permissionLabel: "读取消息上下文", grantedAt: Date().addingTimeInterval(-86400 * 20), isActive: true,  scope: "messages.read",         icon: "person.crop.circle.badge.fill"),
                .init(id: "g2", serviceName: "AI 记忆摘要",     permissionLabel: "读写记忆表",     grantedAt: Date().addingTimeInterval(-86400 * 15), isActive: true,  scope: "memories.readwrite",    icon: "brain.fill"),
                .init(id: "g3", serviceName: "陌生社交意图引擎", permissionLabel: "读取偏好数据",   grantedAt: Date().addingTimeInterval(-86400 * 8),  isActive: true,  scope: "preferences.read",      icon: "magnifyingglass.circle.fill"),
                .init(id: "g4", serviceName: "云端同步 (已停用)", permissionLabel: "上传本地数据",  grantedAt: Date().addingTimeInterval(-86400 * 60), isActive: false, scope: "all.readwrite",         icon: "icloud.slash"),
            ]
            loadState = .loaded
        }
    }

    func reload() { loadState = .idle; load() }

    func startBackup() async {
        backupInProgress = true
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        backupInProgress = false
        lastActionResult = .init(message: "本地备份完成", isSuccess: true)
        dbStatus?.lastBackupDate = .now
    }

    func runCleanup(_ option: CleanupOption) async {
        try? await Task.sleep(nanoseconds: 800_000_000)
        lastActionResult = .init(message: "\(option.label)完成", isSuccess: true)
    }
}

// MARK: - Root View

struct PrivacyLocalBackendView: View {
    @StateObject private var store = PrivacyLocalBackendStore()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                contentBody
            }
            .navigationTitle("隐私与本地控制")
            .spareNavigationBarTitleDisplayMode(.large)
        }
        .task { store.load() }
        .toast(item: $store.lastActionResult)
    }

    @ViewBuilder
    private var contentBody: some View {
        switch store.loadState {
        case .idle, .loading:
            PrivacySkeletonView()
        case .loaded:
            PrivacyScrollView(store: store)
        case .error(let msg):
            ErrorStateView(message: msg, retry: { store.reload() })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Scroll View

private struct PrivacyScrollView: View {
    @ObservedObject var store: PrivacyLocalBackendStore

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                // Status banner
                if let db = store.dbStatus {
                    DBHealthBanner(db: db)
                        .padding(.horizontal, Spacing.lg)
                }

                // Tab picker
                tabPicker
                    .padding(.horizontal, Spacing.lg)

                // Tab content
                tabContent
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.xxxl + 32)
            }
            .padding(.top, Spacing.lg)
        }
        .refreshable { store.reload() }
    }

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(PrivacyLocalBackendStore.Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spareEase) { store.selectedTab = tab }
                } label: {
                    Text(tab.rawValue)
                        .font(store.selectedTab == tab ? .spareCaptionSB : .spareCaption)
                        .foregroundColor(store.selectedTab == tab ? .black : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            store.selectedTab == tab
                                ? Color.spareYellow
                                : Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: CornerRadius.sm)
                        )
                }
            }
        }
        .padding(3)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
    }

    @ViewBuilder
    private var tabContent: some View {
        switch store.selectedTab {
        case .database:
            if let db = store.dbStatus {
                DBTabView(db: db)
            }
        case .backup:
            BackupTabView(store: store)
        case .auth:
            AuthTabView(store: store)
        }
    }
}

// MARK: - DB Health Banner

private struct DBHealthBanner: View {
    let db: DBStatus

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: db.isHealthy ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                .font(.system(size: 28))
                .foregroundColor(db.isHealthy ? .green : .red)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(db.isHealthy ? "本地数据库正常" : "数据库异常")
                    .font(.spareBodySB)
                    .foregroundColor(db.isHealthy ? .green : .red)
                HStack(spacing: Spacing.md) {
                    Label(db.sizeFormatted,          systemImage: "internaldrive")
                    Label("v\(db.migrationVersion)", systemImage: "tag")
                }
                .font(.spareMicro)
                .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(Spacing.lg)
        .background(
            (db.isHealthy ? Color.green : Color.red).opacity(0.08),
            in: RoundedRectangle(cornerRadius: CornerRadius.lg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke((db.isHealthy ? Color.green : Color.red).opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - DB Tab

private struct DBTabView: View {
    let db: DBStatus

    var body: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                Text("数据表一览")
                    .font(.spareBodySB)
                Spacer()
                Text("\(db.tableCount) 张表")
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
            }

            ForEach(db.tables) { table in
                TableRow(table: table, totalSize: db.sizeBytes)
            }

            // Migration info
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Image(systemName: "arrow.triangle.merge")
                        .foregroundColor(.purple)
                    Text("迁移状态").font(.spareBodySB)
                    Spacer()
                    PillTag(label: "已同步", color: .green, filled: true)
                }
                Text("最后执行：\(db.lastMigration)")
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
            }
            .padding(Spacing.md)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
        }
    }
}

private struct TableRow: View {
    let table: DBStatus.TableInfo
    let totalSize: Int64

    private var fraction: Double {
        guard totalSize > 0 else { return 0 }
        return Double(table.sizeBytes) / Double(totalSize)
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "tablecells")
                .foregroundColor(.teal)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(table.name)
                        .font(.spareCaptionSB)
                        .lineLimit(1)
                    Spacer()
                    Text("\(table.rowCount) 行")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                    Text(ByteCountFormatter.string(fromByteCount: table.sizeBytes, countStyle: .file))
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(Color(.systemGray5)).frame(height: 4)
                        RoundedRectangle(cornerRadius: 2).fill(Color.teal.opacity(0.7)).frame(width: fraction * geo.size.width, height: 4)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(Spacing.sm)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.sm))
    }
}

// MARK: - Backup Tab

private struct BackupTabView: View {
    @ObservedObject var store: PrivacyLocalBackendStore

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Backup status card
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Image(systemName: "externaldrive.fill.badge.checkmark")
                        .foregroundColor(.blue)
                    Text("本地备份").font(.spareBodySB)
                    Spacer()
                    if let date = store.dbStatus?.lastBackupDate {
                        Text(date, style: .relative).font(.spareMicro).foregroundColor(.secondary)
                    } else {
                        Text("从未备份").font(.spareMicro).foregroundColor(.red)
                    }
                }

                Button {
                    Task { await store.startBackup() }
                } label: {
                    HStack {
                        if store.backupInProgress {
                            ProgressView().scaleEffect(0.8)
                            Text("备份中…")
                        } else {
                            Image(systemName: "arrow.clockwise.icloud")
                            Text("立即备份")
                        }
                    }
                    .font(.spareBodySB)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(store.backupInProgress ? Color.secondary : Color.blue, in: RoundedRectangle(cornerRadius: CornerRadius.md))
                }
                .disabled(store.backupInProgress)
            }
            .padding(Spacing.lg)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
            .cardShadow()

            // Cleanup options
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("清理选项").font(.spareBodySB).padding(.bottom, Spacing.xs)

                ForEach(store.cleanupOptions) { option in
                    CleanupOptionRow(option: option) {
                        store.pendingCleanup = option
                        store.showConfirmClean = true
                    }
                }
            }
        }
        .confirmationDialog(
            store.pendingCleanup?.label ?? "",
            isPresented: $store.showConfirmClean,
            titleVisibility: .visible
        ) {
            if let option = store.pendingCleanup {
                Button(option.isDestructive ? "确认删除" : "确认执行",
                       role: option.isDestructive ? .destructive : .none) {
                    Task { await store.runCleanup(option) }
                }
                Button("取消", role: .cancel) { }
            }
        } message: {
            if let option = store.pendingCleanup {
                Text(option.description)
            }
        }
    }
}

private struct CleanupOptionRow: View {
    let option: CleanupOption
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                Image(systemName: option.icon)
                    .foregroundColor(option.color)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(option.label)
                        .font(.spareCaption)
                        .foregroundColor(option.isDestructive ? .red : .primary)
                    Text(option.description)
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }
            .padding(Spacing.md)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Auth Tab

private struct AuthTabView: View {
    @ObservedObject var store: PrivacyLocalBackendStore

    var body: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                Image(systemName: "checkmark.shield").foregroundColor(.green)
                Text("授权面板").font(.spareBodySB)
                Spacer()
                Text("\(store.authGrants.filter(\.isActive).count) 项活跃授权")
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }

            ForEach($store.authGrants) { $grant in
                AuthGrantRow(grant: $grant)
            }

            // Privacy notice
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: "info.circle").foregroundColor(.blue).font(.spareCaptionSB)
                Text("所有授权仅在本设备生效。关闭授权后，对应服务将无法访问相关本地数据，不影响历史数据。")
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }
            .padding(Spacing.md)
            .background(Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: CornerRadius.sm))
        }
    }
}

private struct AuthGrantRow: View {
    @Binding var grant: AuthGrant

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: grant.icon)
                .foregroundColor(grant.isActive ? .blue : .secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text(grant.serviceName)
                        .font(.spareCaption)
                        .foregroundColor(grant.isActive ? .primary : .secondary)
                    Spacer()
                    Toggle("", isOn: $grant.isActive)
                        .labelsHidden()
                        .tint(.blue)
                        .scaleEffect(0.85)
                }
                Text(grant.permissionLabel)
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
                HStack(spacing: Spacing.xs) {
                    Text("范围: \(grant.scope)")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(grant.grantedAt, style: .date)
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(Spacing.md)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
        .opacity(grant.isActive ? 1 : 0.6)
        .animation(.spareEase, value: grant.isActive)
    }
}

// MARK: - Toast Modifier

struct ToastModifier: ViewModifier {
    @Binding var item: PrivacyLocalBackendStore.ActionResult?

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
            if let result = item {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(result.isSuccess ? .green : .red)
                    Text(result.message)
                        .font(.spareCaption)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(.regularMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                .padding(.bottom, Spacing.xxxl)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation(.spareEase) { item = nil }
                    }
                }
            }
        }
        .animation(.spareSpring, value: item?.id)
    }
}

extension View {
    func toast(item: Binding<PrivacyLocalBackendStore.ActionResult?>) -> some View {
        modifier(ToastModifier(item: item))
    }
}

// MARK: - Skeleton

private struct PrivacySkeletonView: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            RoundedRectangle(cornerRadius: CornerRadius.lg).fill(Color(.systemGray5)).frame(height: 80).shimmer()
            RoundedRectangle(cornerRadius: CornerRadius.md).fill(Color(.systemGray5)).frame(height: 40).shimmer()
            ForEach(0..<5) { _ in
                RoundedRectangle(cornerRadius: CornerRadius.sm).fill(Color(.systemGray5)).frame(height: 52).shimmer()
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg)
    }
}

#if DEBUG
#Preview {
    PrivacyLocalBackendView()
}
#endif
