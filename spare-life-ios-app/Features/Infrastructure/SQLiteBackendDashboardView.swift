// SQLiteBackendDashboardView.swift
// Spare Life – 底层 · iOS 本地 SQLite 后端 管理面板
// Blueprint §7 底层 · [UIUX] iOS 本地 SQLite 后端 (line:1155)
// UIUX lane – slot 2

import SwiftUI

// MARK: - Models

struct MigrationRecord: Identifiable {
    let id: String
    let version: Int
    let name: String
    let appliedAt: Date
    let status: MigrationStatus
    let changesSummary: String

    enum MigrationStatus: String {
        case applied    = "已执行"
        case pending    = "待执行"
        case failed     = "失败"

        var icon: String {
            switch self {
            case .applied: return "checkmark.circle.fill"
            case .pending: return "clock.fill"
            case .failed:  return "xmark.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .applied: return .green
            case .pending: return .orange
            case .failed:  return .red
            }
        }
    }
}

struct DomainRepository: Identifiable {
    let id: String
    let name: String
    let icon: String
    let tableName: String
    let rowCount: Int
    let lastWrite: Date
    let readCount: Int
    let writeCount: Int
    let isHealthy: Bool
    let accentColor: Color
}

enum SQLiteDashboardLoadState {
    case idle, loading, loaded, error(String)
}

// MARK: - Store

@MainActor
final class SQLiteBackendDashboardStore: ObservableObject {
    @Published var loadState: SQLiteDashboardLoadState = .idle
    @Published var migrations: [MigrationRecord] = []
    @Published var repositories: [DomainRepository] = []
    @Published var dbVersion: Int = 0
    @Published var totalSizeBytes: Int64 = 0
    @Published var walSizeBytes: Int64 = 0
    @Published var integrityOK: Bool = true
    @Published var selectedRepo: DomainRepository? = nil
    @Published var showRepoDetail = false
    @Published var showMigrationHistory = false

    func load() {
        guard case .idle = loadState else { return }
        loadState = .loading
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            dbVersion = 8
            totalSizeBytes = 4_823_040
            walSizeBytes = 102_400
            integrityOK = true

            migrations = [
                .init(id: "m1", version: 1, name: "create_users", appliedAt: date(-90), status: .applied,
                      changesSummary: "CREATE TABLE users (id, display_name, handle, bio, avatar_seed)"),
                .init(id: "m2", version: 2, name: "create_messages", appliedAt: date(-85), status: .applied,
                      changesSummary: "CREATE TABLE messages (id, thread_id, sender_role, content, timestamp)"),
                .init(id: "m3", version: 3, name: "create_personas", appliedAt: date(-80), status: .applied,
                      changesSummary: "CREATE TABLE personas (id, nickname, personality_traits, visibility)"),
                .init(id: "m4", version: 4, name: "create_memories", appliedAt: date(-70), status: .applied,
                      changesSummary: "CREATE TABLE memories (id, type, content, embedding, created_at)"),
                .init(id: "m5", version: 5, name: "add_sync_tasks", appliedAt: date(-55), status: .applied,
                      changesSummary: "CREATE TABLE sync_tasks (id, kind, status, progress, due_at)"),
                .init(id: "m6", version: 6, name: "add_feed_events", appliedAt: date(-40), status: .applied,
                      changesSummary: "CREATE TABLE feed_events (id, card_id, card_kind, action, ts)"),
                .init(id: "m7", version: 7, name: "add_growth_stats", appliedAt: date(-20), status: .applied,
                      changesSummary: "CREATE TABLE growth_stats (id, period, energy_delta, social_delta)"),
                .init(id: "m8", version: 8, name: "add_memory_vectors", appliedAt: date(-5), status: .applied,
                      changesSummary: "ALTER TABLE memories ADD COLUMN vector BLOB; CREATE INDEX idx_memory_vector"),
            ]

            repositories = [
                .init(id: "r1", name: "会话消息",   icon: "bubble.left.and.bubble.right.fill", tableName: "messages",
                      rowCount: 3412, lastWrite: date(-0.02), readCount: 18_940, writeCount: 3_412, isHealthy: true, accentColor: .blue),
                .init(id: "r2", name: "记忆存储",   icon: "brain.fill",           tableName: "memories",
                      rowCount: 128,  lastWrite: date(-0.1),  readCount: 4_560,  writeCount: 128,   isHealthy: true, accentColor: .purple),
                .init(id: "r3", name: "人格分身",   icon: "sparkles",             tableName: "personas",
                      rowCount: 3,    lastWrite: date(-2),    readCount: 890,    writeCount: 3,     isHealthy: true, accentColor: .pink),
                .init(id: "r4", name: "同步任务",   icon: "arrow.triangle.2.circlepath", tableName: "sync_tasks",
                      rowCount: 47,   lastWrite: date(-0.5),  readCount: 1_240,  writeCount: 47,    isHealthy: true, accentColor: .orange),
                .init(id: "r5", name: "Feed 事件", icon: "rectangle.stack.fill", tableName: "feed_events",
                      rowCount: 892,  lastWrite: date(-0.01), readCount: 6_780,  writeCount: 892,   isHealthy: true, accentColor: .spareYellow),
                .init(id: "r6", name: "成长统计",   icon: "chart.line.uptrend.xyaxis", tableName: "growth_stats",
                      rowCount: 26,   lastWrite: date(-1),    readCount: 340,    writeCount: 26,    isHealthy: true, accentColor: .teal),
            ]
            loadState = .loaded
        }
    }

    func reload() { loadState = .idle; load() }

    private func date(_ daysAgo: Double) -> Date {
        Date().addingTimeInterval(-86400 * daysAgo)
    }
}

// MARK: - Root View

struct SQLiteBackendDashboardView: View {
    @StateObject private var store = SQLiteBackendDashboardStore()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                Group {
                    switch store.loadState {
                    case .idle, .loading:
                        SQLiteDashboardSkeleton()
                    case .loaded:
                        SQLiteDashboardContent(store: store)
                    case .error(let msg):
                        ErrorStateView(message: msg, retry: { store.reload() })
                    }
                }
            }
            .navigationTitle("SQLite 后端")
            .navigationBarTitleDisplayMode(.large)
            .task { store.load() }
        }
    }
}

// MARK: - Dashboard Content

private struct SQLiteDashboardContent: View {
    @ObservedObject var store: SQLiteBackendDashboardStore

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                integrityBanner
                dbStatsRow
                repositoryGrid
                migrationTimeline
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.xxxl + 32)
        }
        .refreshable { store.reload() }
        .sheet(isPresented: $store.showRepoDetail) {
            if let repo = store.selectedRepo {
                RepoDetailSheet(repo: repo)
            }
        }
    }

    // MARK: - Integrity Banner

    private var integrityBanner: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: store.integrityOK ? "cylinder.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(store.integrityOK ? .teal : .red)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(store.integrityOK ? "PRAGMA integrity_check: OK" : "完整性校验异常")
                    .font(.spareCaptionSB)
                    .foregroundColor(store.integrityOK ? .teal : .red)
                HStack(spacing: Spacing.md) {
                    Label("v\(store.dbVersion)", systemImage: "tag")
                    Label(ByteCountFormatter.string(fromByteCount: store.totalSizeBytes, countStyle: .file), systemImage: "internaldrive")
                    Label("WAL \(ByteCountFormatter.string(fromByteCount: store.walSizeBytes, countStyle: .file))", systemImage: "doc.on.doc")
                }
                .font(.spareMicro)
                .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(Spacing.lg)
        .background(
            (store.integrityOK ? Color.teal : Color.red).opacity(0.08),
            in: RoundedRectangle(cornerRadius: CornerRadius.lg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke((store.integrityOK ? Color.teal : Color.red).opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - DB Stats Row

    private var dbStatsRow: some View {
        HStack(spacing: Spacing.sm) {
            StatMiniCard(label: "表",   value: "\(store.repositories.count)", icon: "tablecells", color: .blue)
            StatMiniCard(label: "总行数", value: "\(store.repositories.map(\.rowCount).reduce(0, +))", icon: "number", color: .purple)
            StatMiniCard(label: "迁移",  value: "v\(store.dbVersion)", icon: "arrow.triangle.merge", color: .orange)
        }
    }

    // MARK: - Repository Grid

    private var repositoryGrid: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            FeedSectionHeader(title: "Domain Repositories", subtitle: "按领域聚合的数据仓库")

            WaterfallLayout(columns: 2, spacing: Spacing.md) {
                ForEach(store.repositories) { repo in
                    RepoCard(repo: repo) {
                        store.selectedRepo = repo
                        store.showRepoDetail = true
                    }
                }
            }
        }
    }

    // MARK: - Migration Timeline

    private var migrationTimeline: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            FeedSectionHeader(title: "迁移历史", subtitle: "\(store.migrations.count) 个版本")

            VStack(spacing: 0) {
                ForEach(Array(store.migrations.reversed().enumerated()), id: \.element.id) { index, migration in
                    MigrationTimelineRow(migration: migration, isLast: index == store.migrations.count - 1)
                }
            }
            .padding(Spacing.md)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        }
    }
}

// MARK: - Stat Mini Card

private struct StatMiniCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
            Text(value)
                .font(.spareBodySB)
                .foregroundColor(.primary)
            Text(label)
                .font(.spareMicro)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
    }
}

// MARK: - Repo Card

private struct RepoCard: View {
    let repo: DomainRepository
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Image(systemName: repo.icon)
                        .foregroundColor(repo.accentColor)
                        .font(.system(size: 20))
                    Spacer()
                    Circle()
                        .fill(repo.isHealthy ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                }

                Text(repo.name)
                    .font(.spareBodySB)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(repo.tableName)
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
                    .monospaced()

                Divider()

                HStack(spacing: Spacing.xs) {
                    Label("\(repo.rowCount)", systemImage: "arrow.down.doc")
                    Spacer()
                    Label(repo.lastWrite, format: .relative(presentation: .named))
                }
                .font(.spareMicro)
                .foregroundColor(.secondary)
                .lineLimit(1)

                // Read/Write ratio bar
                GeometryReader { geo in
                    let total = max(1, repo.readCount + repo.writeCount)
                    let readFrac = CGFloat(repo.readCount) / CGFloat(total)
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.orange.opacity(0.4))
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(repo.accentColor)
                            .frame(width: readFrac * geo.size.width, height: 4)
                    }
                }
                .frame(height: 4)

                HStack {
                    Text("R:\(formatCount(repo.readCount))")
                        .foregroundColor(repo.accentColor)
                    Spacer()
                    Text("W:\(formatCount(repo.writeCount))")
                        .foregroundColor(.orange)
                }
                .font(.spareMicro)
            }
            .padding(Spacing.md)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
            .cardShadow()
        }
        .buttonStyle(CardPressStyle())
    }

    private func formatCount(_ n: Int) -> String {
        if n >= 1000 { return String(format: "%.1fk", Double(n) / 1000.0) }
        return "\(n)"
    }
}

// MARK: - Migration Timeline Row

private struct MigrationTimelineRow: View {
    let migration: MigrationRecord
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            // Timeline connector
            VStack(spacing: 0) {
                Circle()
                    .fill(migration.status.color)
                    .frame(width: 12, height: 12)
                if !isLast {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 12)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text("v\(migration.version)")
                        .font(.spareCaptionSB)
                        .foregroundColor(migration.status.color)
                    Text(migration.name)
                        .font(.spareCaptionSB)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: migration.status.icon)
                        .foregroundColor(migration.status.color)
                        .font(.spareMicro)
                }

                Text(migration.changesSummary)
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .monospaced()

                Text(migration.appliedAt, style: .date)
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, isLast ? 0 : Spacing.lg)
        }
    }
}

// MARK: - Repo Detail Sheet

private struct RepoDetailSheet: View {
    let repo: DomainRepository
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Header
                    HStack(spacing: Spacing.md) {
                        Image(systemName: repo.icon)
                            .font(.system(size: 36))
                            .foregroundColor(repo.accentColor)
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(repo.name).font(.spareTitle2)
                            Text(repo.tableName).font(.spareCaption).foregroundColor(.secondary).monospaced()
                        }
                        Spacer()
                        PillTag(label: repo.isHealthy ? "正常" : "异常",
                                color: repo.isHealthy ? .green : .red, filled: true)
                    }

                    // Stats grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.md) {
                        DetailStatCard(title: "总行数",   value: "\(repo.rowCount)",   icon: "number",           color: .blue)
                        DetailStatCard(title: "读取次数", value: "\(repo.readCount)",  icon: "eye",              color: repo.accentColor)
                        DetailStatCard(title: "写入次数", value: "\(repo.writeCount)", icon: "pencil.line",      color: .orange)
                        DetailStatCard(title: "最后写入", value: relativeDate,         icon: "clock.arrow.circlepath", color: .teal)
                    }

                    // Schema hint
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Schema").font(.spareBodySB)
                        Text("CREATE TABLE \(repo.tableName) (...)")
                            .font(.spareMicro)
                            .monospaced()
                            .foregroundColor(.secondary)
                            .padding(Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.sm))
                    }
                }
                .padding(Spacing.lg)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("仓库详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: repo.lastWrite, relativeTo: .now)
    }
}

private struct DetailStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 16))
            Text(value)
                .font(.spareBodySB)
                .lineLimit(1)
            Text(title)
                .font(.spareMicro)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
    }
}

// MARK: - Skeleton

private struct SQLiteDashboardSkeleton: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(Color(.systemGray5)).frame(height: 80).shimmer()
            HStack(spacing: Spacing.sm) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .fill(Color(.systemGray5)).frame(height: 80).shimmer()
                }
            }
            WaterfallLayout(columns: 2, spacing: Spacing.md) {
                ForEach(0..<6, id: \.self) { i in
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .fill(Color(.systemGray5))
                        .frame(height: CGFloat([140, 160, 150, 140, 165, 145][i]))
                        .shimmer()
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg)
    }
}

#if DEBUG
#Preview {
    SQLiteBackendDashboardView()
}
#endif
