// SecurityRiskControlView.swift
// Spare Life – 底层 · 安全与风控 管理面板
// Blueprint §7 底层 · [UIUX] 安全与风控 (line:1158)
// UIUX lane – slot 2

import SwiftUI

// MARK: - Models

struct AuditLogEntry: Identifiable {
    let id: String
    let action: AuditAction
    let description: String
    let actor: String
    let timestamp: Date
    let severity: Severity

    enum AuditAction: String, CaseIterable, Identifiable {
        case access    = "访问"
        case modify    = "修改"
        case block     = "拦截"
        case report    = "举报"
        case grant     = "授权"
        case revoke    = "撤销"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .access:  return "eye.fill"
            case .modify:  return "pencil"
            case .block:   return "hand.raised.fill"
            case .report:  return "flag.fill"
            case .grant:   return "checkmark.shield.fill"
            case .revoke:  return "xmark.shield.fill"
            }
        }

        var color: Color {
            switch self {
            case .access:  return .blue
            case .modify:  return .orange
            case .block:   return .red
            case .report:  return .pink
            case .grant:   return .green
            case .revoke:  return .purple
            }
        }
    }

    enum Severity: String, CaseIterable, Identifiable {
        case info    = "信息"
        case warning = "警告"
        case critical = "严重"

        var id: String { rawValue }

        var color: Color {
            switch self {
            case .info:     return .blue
            case .warning:  return .orange
            case .critical: return .red
            }
        }

        var icon: String {
            switch self {
            case .info:     return "info.circle.fill"
            case .warning:  return "exclamationmark.triangle.fill"
            case .critical: return "xmark.octagon.fill"
            }
        }
    }
}

struct BlockRule: Identifiable {
    let id: String
    let ruleType: RuleType
    let target: String
    let reason: String
    let createdAt: Date
    var isActive: Bool

    enum RuleType: String {
        case keyword   = "关键词"
        case user      = "用户"
        case pattern   = "模式"
        case threshold = "阈值"

        var icon: String {
            switch self {
            case .keyword:   return "text.magnifyingglass"
            case .user:      return "person.crop.circle.badge.xmark"
            case .pattern:   return "curlybraces"
            case .threshold: return "gauge.with.dots.needle.67percent"
            }
        }

        var color: Color {
            switch self {
            case .keyword:   return .orange
            case .user:      return .red
            case .pattern:   return .purple
            case .threshold: return .teal
            }
        }
    }
}

struct ReportItem: Identifiable {
    let id: String
    let type: ReportType
    let targetName: String
    let reason: String
    let submittedAt: Date
    let status: ReportStatus

    enum ReportType: String {
        case content = "内容"
        case user    = "用户"
        case bug     = "异常"

        var icon: String {
            switch self {
            case .content: return "doc.text.fill"
            case .user:    return "person.fill.xmark"
            case .bug:     return "ladybug.fill"
            }
        }
    }

    enum ReportStatus: String {
        case pending  = "待审核"
        case reviewed = "已审核"
        case resolved = "已处理"

        var color: Color {
            switch self {
            case .pending:  return .orange
            case .reviewed: return .blue
            case .resolved: return .green
            }
        }
    }
}

struct PrivacyBoundary: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    var isEnabled: Bool
    let category: String
}

enum SecurityLoadState {
    case idle, loading, loaded, error(String)
}

// MARK: - Store

@MainActor
final class SecurityRiskControlStore: ObservableObject {
    @Published var loadState: SecurityLoadState = .idle
    @Published var auditLogs: [AuditLogEntry] = []
    @Published var blockRules: [BlockRule] = []
    @Published var reports: [ReportItem] = []
    @Published var privacyBoundaries: [PrivacyBoundary] = []
    @Published var selectedTab: Tab = .audit
    @Published var filterAction: AuditLogEntry.AuditAction? = nil
    @Published var filterSeverity: AuditLogEntry.Severity? = nil
    @Published var blockedCount24h: Int = 0
    @Published var reportsPending: Int = 0
    @Published var privacyScore: Int = 0

    enum Tab: String, CaseIterable {
        case audit   = "审计日志"
        case rules   = "拦截规则"
        case reports = "举报"
        case privacy = "隐私边界"
    }

    var filteredLogs: [AuditLogEntry] {
        var result = auditLogs
        if let action = filterAction {
            result = result.filter { $0.action == action }
        }
        if let severity = filterSeverity {
            result = result.filter { $0.severity == severity }
        }
        return result
    }

    func load() {
        guard case .idle = loadState else { return }
        loadState = .loading
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            blockedCount24h = 3
            reportsPending = 1
            privacyScore = 92

            auditLogs = [
                .init(id: "a1", action: .access,  description: "分身代理访问消息上下文 (聊天:小明)", actor: "分身代理", timestamp: date(-0.01), severity: .info),
                .init(id: "a2", action: .block,   description: "拦截敏感关键词: 用户发送内容触发风控规则 #K3", actor: "风控引擎", timestamp: date(-0.05), severity: .warning),
                .init(id: "a3", action: .modify,  description: "用户修改分身面具: 从「严肃」改为「轻松幽默」", actor: "用户", timestamp: date(-0.1), severity: .info),
                .init(id: "a4", action: .grant,   description: "用户授权 AI 记忆摘要 读写记忆表", actor: "用户", timestamp: date(-0.3), severity: .info),
                .init(id: "a5", action: .report,  description: "用户举报陌生社交匹配对象发送不当内容", actor: "用户", timestamp: date(-0.5), severity: .warning),
                .init(id: "a6", action: .block,   description: "阈值规则触发: 10 分钟内 15 条消息被自动限速", actor: "风控引擎", timestamp: date(-0.8), severity: .warning),
                .init(id: "a7", action: .revoke,  description: "用户撤销云端同步服务的上传授权", actor: "用户", timestamp: date(-1), severity: .info),
                .init(id: "a8", action: .block,   description: "拦截异常登录尝试: IP 地址不在常用范围", actor: "风控引擎", timestamp: date(-1.5), severity: .critical),
                .init(id: "a9", action: .access,  description: "意图引擎读取用户偏好数据用于匹配排序", actor: "意图引擎", timestamp: date(-2), severity: .info),
                .init(id: "a10", action: .modify, description: "分身同步训练任务完成，更新同步度评分", actor: "系统", timestamp: date(-2.5), severity: .info),
            ]

            blockRules = [
                .init(id: "br1", ruleType: .keyword,   target: "敏感词库 v3.2", reason: "匹配 1,247 个关键词模式", createdAt: date(-30), isActive: true),
                .init(id: "br2", ruleType: .threshold,  target: "消息频率限制",   reason: "10 分钟内 > 20 条触发限速", createdAt: date(-25), isActive: true),
                .init(id: "br3", ruleType: .pattern,    target: "URL 过滤器",     reason: "拦截已知恶意 URL 模式",   createdAt: date(-20), isActive: true),
                .init(id: "br4", ruleType: .user,       target: "异常 IP 拦截",   reason: "非常用 IP 段登录需二次验证", createdAt: date(-15), isActive: true),
                .init(id: "br5", ruleType: .threshold,  target: "举报累计阈值",   reason: "被举报 >= 3 次自动限制功能", createdAt: date(-10), isActive: false),
            ]

            reports = [
                .init(id: "rp1", type: .content, targetName: "匿名用户#8291", reason: "陌生社交中发送不当内容", submittedAt: date(-0.5), status: .pending),
                .init(id: "rp2", type: .user,    targetName: "测试用户_XZ",   reason: "疑似机器人行为", submittedAt: date(-3), status: .reviewed),
                .init(id: "rp3", type: .bug,     targetName: "分身回复异常",   reason: "分身多次重复相同回复", submittedAt: date(-5), status: .resolved),
            ]

            privacyBoundaries = [
                .init(id: "pb1", name: "消息端到端本地存储", description: "所有消息仅存储在本设备 SQLite，不上传云端", icon: "lock.shield.fill", isEnabled: true, category: "存储"),
                .init(id: "pb2", name: "记忆加密存储", description: "记忆向量和内容使用设备密钥加密", icon: "key.fill", isEnabled: true, category: "加密"),
                .init(id: "pb3", name: "分身授权边界", description: "分身代理只能在显式授权范围内访问数据", icon: "person.badge.shield.checkmark.fill", isEnabled: true, category: "授权"),
                .init(id: "pb4", name: "陌生社交隐私模式", description: "陌生社交中不暴露真实姓名和联系方式", icon: "eye.slash.fill", isEnabled: true, category: "社交"),
                .init(id: "pb5", name: "审计日志不可删除", description: "安全审计日志保留 90 天且用户不可修改", icon: "doc.badge.gearshape.fill", isEnabled: true, category: "审计"),
                .init(id: "pb6", name: "大师会话数据隔离", description: "不同大师的会话数据相互隔离", icon: "rectangle.split.3x1.fill", isEnabled: true, category: "隔离"),
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

struct SecurityRiskControlView: View {
    @StateObject private var store = SecurityRiskControlStore()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                Group {
                    switch store.loadState {
                    case .idle, .loading:
                        SecuritySkeleton()
                    case .loaded:
                        SecurityContent(store: store)
                    case .error(let msg):
                        ErrorStateView(message: msg, retry: { store.reload() })
                    }
                }
            }
            .navigationTitle("安全与风控")
            .navigationBarTitleDisplayMode(.large)
            .task { store.load() }
        }
    }
}

// MARK: - Content

private struct SecurityContent: View {
    @ObservedObject var store: SecurityRiskControlStore

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                summaryCards
                tabPicker
                tabContent
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.xxxl + 32)
        }
        .refreshable { store.reload() }
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        HStack(spacing: Spacing.sm) {
            SecuritySummaryCard(
                label: "24h 拦截", value: "\(store.blockedCount24h)",
                icon: "hand.raised.fill", color: .red
            )
            SecuritySummaryCard(
                label: "待审举报", value: "\(store.reportsPending)",
                icon: "flag.fill", color: .orange
            )
            SecuritySummaryCard(
                label: "隐私得分", value: "\(store.privacyScore)",
                icon: "shield.checkered", color: .green
            )
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(SecurityRiskControlStore.Tab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spareEase) { store.selectedTab = tab }
                    } label: {
                        Text(tab.rawValue)
                            .font(store.selectedTab == tab ? .spareCaptionSB : .spareCaption)
                            .foregroundColor(store.selectedTab == tab ? .black : .secondary)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.sm)
                            .background(
                                store.selectedTab == tab
                                    ? Color.spareYellow
                                    : Color(.secondarySystemGroupedBackground),
                                in: Capsule()
                            )
                    }
                }
            }
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch store.selectedTab {
        case .audit:
            AuditLogTab(store: store)
        case .rules:
            BlockRulesTab(rules: store.blockRules)
        case .reports:
            ReportsTab(reports: store.reports)
        case .privacy:
            PrivacyBoundaryTab(boundaries: store.privacyBoundaries)
        }
    }
}

// MARK: - Summary Card

private struct SecuritySummaryCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            Text(value)
                .font(.spareTitle3)
                .foregroundColor(.primary)
            Text(label)
                .font(.spareMicro)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
    }
}

// MARK: - Audit Log Tab

private struct AuditLogTab: View {
    @ObservedObject var store: SecurityRiskControlStore

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Action filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    AuditFilterChip(label: "全部", isSelected: store.filterAction == nil) {
                        withAnimation(.spareEase) { store.filterAction = nil }
                    }
                    ForEach(AuditLogEntry.AuditAction.allCases) { action in
                        AuditFilterChip(
                            label: action.rawValue,
                            icon: action.icon,
                            color: action.color,
                            isSelected: store.filterAction == action
                        ) {
                            withAnimation(.spareEase) { store.filterAction = action }
                        }
                    }
                }
            }

            // Severity filter
            HStack(spacing: Spacing.xs) {
                Text("严重度:").font(.spareMicro).foregroundColor(.secondary)
                ForEach(AuditLogEntry.Severity.allCases) { severity in
                    Button {
                        withAnimation(.spareEase) {
                            store.filterSeverity = store.filterSeverity == severity ? nil : severity
                        }
                    } label: {
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: severity.icon).font(.system(size: 10))
                            Text(severity.rawValue).font(.spareMicro)
                        }
                        .foregroundColor(store.filterSeverity == severity ? .white : severity.color)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(
                            store.filterSeverity == severity ? severity.color : severity.color.opacity(0.12),
                            in: Capsule()
                        )
                    }
                }
                Spacer()
            }

            if store.filteredLogs.isEmpty {
                EmptyStateView(
                    icon: "doc.text.magnifyingglass",
                    title: "无匹配日志",
                    message: "调整筛选条件查看更多日志。"
                )
                .frame(minHeight: 200)
            } else {
                ForEach(store.filteredLogs) { entry in
                    AuditLogRow(entry: entry)
                }
            }
        }
    }
}

private struct AuditFilterChip: View {
    let label: String
    var icon: String? = nil
    var color: Color = .spareYellow
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.xxs) {
                if let icon { Image(systemName: icon).font(.system(size: 10)) }
                Text(label).font(.spareMicro)
            }
            .foregroundColor(isSelected ? .black : .secondary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(
                isSelected ? color.opacity(0.9) : Color(.secondarySystemGroupedBackground),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }
}

private struct AuditLogRow: View {
    let entry: AuditLogEntry

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: entry.action.icon)
                .foregroundColor(entry.action.color)
                .font(.system(size: 14))
                .frame(width: 24, height: 24)
                .background(entry.action.color.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text(entry.description)
                        .font(.spareCaption)
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    Image(systemName: entry.severity.icon)
                        .foregroundColor(entry.severity.color)
                        .font(.system(size: 10))
                }

                HStack(spacing: Spacing.md) {
                    Label(entry.actor, systemImage: "person.circle")
                    PillTag(label: entry.action.rawValue, color: entry.action.color, filled: false)
                    Spacer()
                    Text(entry.timestamp, style: .relative)
                }
                .font(.spareMicro)
                .foregroundColor(.secondary)
            }
        }
        .padding(Spacing.md)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
    }
}

// MARK: - Block Rules Tab

private struct BlockRulesTab: View {
    let rules: [BlockRule]

    var body: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundColor(.red)
                Text("风控规则引擎").font(.spareBodySB)
                Spacer()
                Text("\(rules.filter(\.isActive).count) / \(rules.count) 活跃")
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }

            if rules.isEmpty {
                EmptyStateView(
                    icon: "shield.slash",
                    title: "暂无风控规则",
                    message: "系统会根据安全策略自动配置规则。"
                )
                .frame(minHeight: 200)
            } else {
                ForEach(rules) { rule in
                    BlockRuleRow(rule: rule)
                }
            }
        }
    }
}

private struct BlockRuleRow: View {
    let rule: BlockRule

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: rule.ruleType.icon)
                .foregroundColor(rule.ruleType.color)
                .font(.system(size: 18))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text(rule.target)
                        .font(.spareCaption)
                        .foregroundColor(rule.isActive ? .primary : .secondary)
                    Spacer()
                    PillTag(
                        label: rule.isActive ? "启用" : "停用",
                        color: rule.isActive ? .green : .secondary,
                        filled: rule.isActive
                    )
                }
                Text(rule.reason)
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                HStack {
                    PillTag(label: rule.ruleType.rawValue, color: rule.ruleType.color, filled: false)
                    Spacer()
                    Text(rule.createdAt, style: .date)
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(Spacing.md)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
        .opacity(rule.isActive ? 1 : 0.6)
    }
}

// MARK: - Reports Tab

private struct ReportsTab: View {
    let reports: [ReportItem]

    var body: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Image(systemName: "flag.fill").foregroundColor(.pink)
                Text("我的举报").font(.spareBodySB)
                Spacer()
                Text("\(reports.filter { $0.status == .pending }.count) 待审核")
                    .font(.spareMicro)
                    .foregroundColor(.orange)
            }

            if reports.isEmpty {
                EmptyStateView(
                    icon: "flag",
                    title: "暂无举报记录",
                    message: "如果你遇到违规内容或行为，可以通过聊天界面发起举报。"
                )
                .frame(minHeight: 200)
            } else {
                ForEach(reports) { report in
                    ReportRow(report: report)
                }
            }
        }
    }
}

private struct ReportRow: View {
    let report: ReportItem

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: report.type.icon)
                .foregroundColor(.pink)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text(report.targetName).font(.spareCaptionSB)
                    Spacer()
                    PillTag(label: report.status.rawValue, color: report.status.color, filled: report.status == .pending)
                }
                Text(report.reason)
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                Text(report.submittedAt, style: .relative)
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }
        }
        .padding(Spacing.md)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
    }
}

// MARK: - Privacy Boundary Tab

private struct PrivacyBoundaryTab: View {
    let boundaries: [PrivacyBoundary]

    var body: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Image(systemName: "lock.shield.fill").foregroundColor(.green)
                Text("隐私边界").font(.spareBodySB)
                Spacer()
                Text("\(boundaries.filter(\.isEnabled).count) / \(boundaries.count) 已开启")
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }

            // Privacy score ring
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 8)
                    .frame(width: 80, height: 80)
                Circle()
                    .trim(from: 0, to: Double(boundaries.filter(\.isEnabled).count) / max(1, Double(boundaries.count)))
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(boundaries.filter(\.isEnabled).count)/\(boundaries.count)")
                        .font(.spareCaptionSB)
                    Text("边界")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, Spacing.sm)

            if boundaries.isEmpty {
                EmptyStateView(
                    icon: "lock.open",
                    title: "暂无隐私边界",
                    message: "系统会自动配置基础隐私保护。"
                )
                .frame(minHeight: 200)
            } else {
                ForEach(boundaries) { boundary in
                    PrivacyBoundaryRow(boundary: boundary)
                }
            }
        }
    }
}

private struct PrivacyBoundaryRow: View {
    let boundary: PrivacyBoundary

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: boundary.icon)
                .foregroundColor(boundary.isEnabled ? .green : .secondary)
                .font(.system(size: 18))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text(boundary.name)
                        .font(.spareCaption)
                        .foregroundColor(boundary.isEnabled ? .primary : .secondary)
                    Spacer()
                    Image(systemName: boundary.isEnabled ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(boundary.isEnabled ? .green : .secondary)
                }
                Text(boundary.description)
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(Spacing.md)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
        .opacity(boundary.isEnabled ? 1 : 0.65)
    }
}

// MARK: - Skeleton

private struct SecuritySkeleton: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            HStack(spacing: Spacing.sm) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .fill(Color(.systemGray5)).frame(height: 80).shimmer()
                }
            }
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(Color(.systemGray5)).frame(height: 36).shimmer()
            ForEach(0..<6, id: \.self) { _ in
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(Color(.systemGray5)).frame(height: 72).shimmer()
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg)
    }
}

#if DEBUG
#Preview {
    SecurityRiskControlView()
}
#endif
