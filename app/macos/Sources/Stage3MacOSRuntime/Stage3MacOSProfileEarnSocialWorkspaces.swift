import SwiftUI

struct Stage3MacOSEarnSocialWorkspaceView: View {
    private let categories = Stage3MacOSEarnSocialCategoryDescriptor.currentSurface

    var body: some View {
        HSplitView {
            catalogColumn
                .frame(minWidth: 272, idealWidth: 304, maxWidth: 336)

            canvasColumn
                .frame(minWidth: 560, idealWidth: 700, maxWidth: .infinity)

            inspectorColumn
                .frame(minWidth: 272, idealWidth: 304, maxWidth: 340)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var catalogColumn: some View {
        VStack(spacing: 0) {
            Stage3MacOSWorkspaceColumnHeader(
                title: "闲能分类目录",
                subtitle: "保持 iOS 的七个交易分类与双向身份提示，但在桌面端先把分类语义稳定摆在左侧。"
            )

            Divider()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    ForEach(categories) { category in
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: category.symbol)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.spareYellowInk)
                                    .frame(width: 30, height: 30)
                                    .background(Color.spareYellow.opacity(0.14), in: Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(category.title)
                                        .font(.spareBodySB)
                                        .foregroundColor(.primary)

                                    Text(category.directionHint)
                                        .font(.spareMicro)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Text(category.summary)
                                .font(.spareCaption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Stage3MacOSTagCloud(tags: category.tags)
                        }
                        .padding(Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                                .fill(Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                                .stroke(Color.cardStroke, lineWidth: 1)
                        )
                    }
                }
                .padding(Spacing.md)
            }
        }
        .workspacePaneBackground()
    }

    private var canvasColumn: some View {
        VStack(spacing: 0) {
            Stage3MacOSWorkspaceColumnHeader(
                title: "市场工作区",
                subtitle: "中栏继续跑共享 `EarnSocialHomeView` 的 category tabs、waterfall cards、card chat sheet 与偏好入口。"
            )

            Divider()

            EarnSocialHomeView()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .workspacePaneBackground()
    }

    private var inspectorColumn: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Stage3MacOSInspectorChip(
                    title: "Workspace",
                    value: "market-canvas-inspector"
                )

                Stage3MacOSInspectorSection(
                    title: "当前 runtime truth",
                    subtitle: "共享 earnSocial surface 仍是本地 mock market"
                ) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("当前代码里，分类卡片和对话承接都来自 `EarnSocialHomeView.swift` 内的本地 fixtures，而不是已接入 live 市场后端。桌面端只做空间组织，不额外把 mock surface 伪装成已接线 runtime。")
                            .font(.spareCaption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Stage3MacOSMetadataRow(label: "category_count", value: "\(categories.count)")
                        Stage3MacOSMetadataRow(label: "card_surface", value: "shared waterfall cards")
                        Stage3MacOSMetadataRow(label: "detail_entry", value: "card tap -> chat sheet")
                        Stage3MacOSMetadataRow(label: "preference_entry", value: "toolbar button -> preference sheet")
                    }
                }

                Stage3MacOSInspectorSection(
                    title: "桌面承接",
                    subtitle: "不再只是把移动端页面放大居中"
                ) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("左侧固定分类与交易方向索引，中栏保留原始 feed 语义，右侧把联调事实、入口规则和 mock truth 固定出来，避免在单列里来回滚动确认页面语义。")
                            .font(.spareCaption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Stage3MacOSMetadataRow(label: "shared_surface", value: "EarnSocialHomeView")
                        Stage3MacOSMetadataRow(label: "desktop_delta", value: "catalog + canvas + inspector")
                    }
                }
            }
            .padding(Spacing.md)
        }
        .workspacePaneBackground(tint: Color.spareYellow.opacity(0.05))
    }
}

private struct Stage3MacOSEarnSocialCategoryDescriptor: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let directionHint: String
    let summary: String
    let tags: [String]

    static let currentSurface: [Stage3MacOSEarnSocialCategoryDescriptor] = [
        .init(
            id: "errand",
            title: "跑腿",
            symbol: "figure.run",
            directionHint: "双向身份：发需求 / 可接单",
            summary: "有人发需求，也有人接单。桌面端先把时间、地点、预算的分类语义稳定放在左侧目录。",
            tags: ["时间", "地点", "预算"]
        ),
        .init(
            id: "mouthpiece",
            title: "嘴替",
            symbol: "bubble.left.and.bubble.right.fill",
            directionHint: "双向身份：求嘴替 / 做嘴替",
            summary: "本类核心是边界、表达和关系场景。原始卡片仍在中栏，左栏只负责固定语义索引。",
            tags: ["边界", "表达", "关系"]
        ),
        .init(
            id: "buddy",
            title: "搭子",
            symbol: "person.2.fill",
            directionHint: "双向身份：找搭子 / 可搭",
            summary: "桌面端把兴趣、城市、时间窗口先行暴露出来，减少在单列 feed 里反复筛读。",
            tags: ["兴趣", "城市", "时间"]
        ),
        .init(
            id: "romance",
            title: "两性",
            symbol: "heart.fill",
            directionHint: "双向身份：想认识 / 愿意聊",
            summary: "这类场景强调边界和期待。macOS 只提升可读密度，不改变原始卡片与承接方式。",
            tags: ["边界", "期待", "安全感"]
        ),
        .init(
            id: "career",
            title: "求职招聘",
            symbol: "briefcase.fill",
            directionHint: "双向身份：找工作 / 招人",
            summary: "岗位、履历、合作方式依旧在共享卡片中展示，左栏只把导航从移动端 tab 条件里解耦出来。",
            tags: ["岗位", "履历", "合作方式"]
        ),
        .init(
            id: "funding",
            title: "投融资",
            symbol: "banknote.fill",
            directionHint: "双向身份：找钱 / 找项目",
            summary: "阶段、金额和决策窗口仍是原页面语义，桌面端只增加联调可见性。",
            tags: ["阶段", "金额", "决策窗口"]
        ),
        .init(
            id: "idle",
            title: "闲置",
            symbol: "shippingbox.fill",
            directionHint: "双向身份：求购 / 求售",
            summary: "成色、价格和交易方式继续留在共享卡片里，中栏保留原始 waterfall 结构。",
            tags: ["成色", "价格", "交易方式"]
        )
    ]
}

private enum Stage3MacOSProfileSurface: String, CaseIterable, Identifiable {
    case dashboard
    case sync
    case personality
    case memories
    case growth
    case privacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:
            return "桌面总览"
        case .sync:
            return "同步度"
        case .personality:
            return "人格觉醒"
        case .memories:
            return "记忆宫殿"
        case .growth:
            return "成长统计"
        case .privacy:
            return "隐私与本地后端"
        }
    }

    var subtitle: String {
        switch self {
        case .dashboard:
            return "把 profile、分身、隐私与诊断入口并排承接，而不是继续把 iOS 首页当单列长卷。"
        case .sync:
            return "继续跑共享 `SyncScoreDashboardView`，但用桌面工作区固定上下文。"
        case .personality:
            return "继续跑共享 `AwakeningPersonalityView`。"
        case .memories:
            return "继续跑共享 `MemoryPalaceView`。"
        case .growth:
            return "继续跑共享 `GrowthStatsView`。"
        case .privacy:
            return "继续跑共享 `PrivacyLocalBackendView`，并与右栏 backend inspector 并排。"
        }
    }

    var icon: String {
        switch self {
        case .dashboard:
            return "rectangle.grid.2x2.fill"
        case .sync:
            return "arrow.triangle.2.circlepath.circle.fill"
        case .personality:
            return "brain.head.profile"
        case .memories:
            return "building.columns.fill"
        case .growth:
            return "chart.line.uptrend.xyaxis"
        case .privacy:
            return "lock.shield.fill"
        }
    }
}

struct Stage3MacOSProfileWorkspaceView: View {
    @Environment(\.openWindow) private var openWindow
    @StateObject private var store = MyProfileStore()
    @StateObject private var privacyStore = PrivacyLocalBackendStore()
    @State private var selectedSurface: Stage3MacOSProfileSurface = .dashboard

    private var profile: UserProfile? {
        store.profile
    }

    private var avatarProfile: AvatarPublicProfile? {
        store.avatarProfile
    }

    var body: some View {
        HSplitView {
            summaryColumn
                .frame(minWidth: 288, idealWidth: 320, maxWidth: 352)

            detailColumn
                .frame(minWidth: 560, idealWidth: 700, maxWidth: .infinity)

            inspectorColumn
                .frame(minWidth: 280, idealWidth: 312, maxWidth: 344)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            store.load()
            privacyStore.load()
        }
    }

    private var summaryColumn: some View {
        VStack(spacing: 0) {
            Stage3MacOSWorkspaceColumnHeader(
                title: "身份摘要",
                subtitle: "左侧固定个人信息、可切换面板和桌面级入口，不再把所有内容挤进一个滚动页头。"
            )

            Divider()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    if let profile {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            HStack(spacing: Spacing.md) {
                                Image(systemName: profile.avatarAnimal.symbolName)
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundColor(.spareYellowInk)
                                    .frame(width: 64, height: 64)
                                    .background(Color.spareYellow.opacity(0.16), in: Circle())

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(profile.displayName)
                                        .font(.spareTitle3)
                                        .foregroundColor(.primary)

                                    Text(profile.handle)
                                        .font(.spareCaptionSB)
                                        .foregroundColor(.secondary)

                                    Text("加入于 \(profile.joinedDate.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.spareMicro)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Text(profile.bio)
                                .font(.spareCaption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: Spacing.sm) {
                                Stage3MacOSProfileMetricCard(
                                    title: "闲能",
                                    value: "\(profile.energyBalance)",
                                    icon: "bolt.circle.fill"
                                )
                                Stage3MacOSProfileMetricCard(
                                    title: "社交连接",
                                    value: "\(profile.socialConnections)",
                                    icon: "person.2.fill"
                                )
                            }
                        }
                        .padding(Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                                .fill(Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                                .stroke(Color.cardStroke, lineWidth: 1)
                        )
                    } else {
                        ProgressView("加载个人资料…")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Stage3MacOSInspectorSection(
                        title: "桌面面板",
                        subtitle: selectedSurface.title
                    ) {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            ForEach(Stage3MacOSProfileSurface.allCases) { surface in
                                Stage3MacOSProfileSurfaceButton(
                                    title: surface.title,
                                    icon: surface.icon,
                                    isSelected: selectedSurface == surface
                                ) {
                                    withAnimation(.spareSpring) {
                                        selectedSurface = surface
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(Spacing.md)
            }
        }
        .workspacePaneBackground()
    }

    private var detailColumn: some View {
        VStack(spacing: 0) {
            Stage3MacOSWorkspaceColumnHeader(
                title: selectedSurface.title,
                subtitle: selectedSurface.subtitle
            )

            Divider()

            Group {
                switch selectedSurface {
                case .dashboard:
                    Stage3MacOSProfileDashboardSurface(
                        profile: profile,
                        avatarProfile: avatarProfile,
                        onSelectSurface: { selectedSurface = $0 },
                        onOpenInfrastructure: { openWindow(id: Stage3MacOSRuntime.infrastructureWorkspacePageID) },
                        onOpenOpenClaw: { openWindow(id: Stage3MacOSRuntime.openClawDiagnosticPageID) },
                        onOpenSQLite: { openWindow(id: Stage3MacOSRuntime.sqliteDiagnosticPageID) }
                    )
                case .sync:
                    SyncScoreDashboardView()
                case .personality:
                    AwakeningPersonalityView()
                case .memories:
                    MemoryPalaceView()
                case .growth:
                    GrowthStatsView()
                case .privacy:
                    PrivacyLocalBackendView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .workspacePaneBackground()
    }

    private var inspectorColumn: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Stage3MacOSInspectorChip(
                    title: "Workspace",
                    value: "identity-dashboard-inspector"
                )

                if let avatarProfile {
                    Stage3MacOSInspectorSection(
                        title: "AI 分身公开档案",
                        subtitle: avatarProfile.nickname
                    ) {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text(avatarProfile.tagline)
                                .font(.spareCaption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Stage3MacOSTagCloud(tags: avatarProfile.personalityTraits)
                            Stage3MacOSTagCloud(tags: avatarProfile.visibleFields.map(\.rawValue).sorted())
                        }
                    }
                }

                if let dbStatus = privacyStore.dbStatus {
                    Stage3MacOSInspectorSection(
                        title: "本地后端",
                        subtitle: dbStatus.isHealthy ? "PRAGMA integrity_check: OK" : "完整性校验异常"
                    ) {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Stage3MacOSMetadataRow(label: "db_size", value: dbStatus.sizeFormatted)
                            Stage3MacOSMetadataRow(label: "table_count", value: "\(dbStatus.tableCount)")
                            Stage3MacOSMetadataRow(label: "migration", value: "v\(dbStatus.migrationVersion) · \(dbStatus.lastMigration)")
                            if let lastBackupDate = dbStatus.lastBackupDate {
                                Stage3MacOSMetadataRow(
                                    label: "last_backup",
                                    value: lastBackupDate.formatted(date: .abbreviated, time: .shortened)
                                )
                            }
                        }
                    }
                }

                Stage3MacOSInspectorSection(
                    title: "诊断入口",
                    subtitle: "Infrastructure 在桌面端独立成窗口，而不是继续藏在单列页面深处。"
                ) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Stage3MacOSInspectorActionButton(title: "打开 Infrastructure 工作区", icon: "wrench.and.screwdriver.fill") {
                            openWindow(id: Stage3MacOSRuntime.infrastructureWorkspacePageID)
                        }
                        Stage3MacOSInspectorActionButton(title: "打开 OpenClaw 插件页", icon: "link.circle.fill") {
                            openWindow(id: Stage3MacOSRuntime.openClawDiagnosticPageID)
                        }
                        Stage3MacOSInspectorActionButton(title: "打开 SQLite 后端页", icon: "internaldrive.fill") {
                            openWindow(id: Stage3MacOSRuntime.sqliteDiagnosticPageID)
                        }
                    }
                }
            }
            .padding(Spacing.md)
        }
        .workspacePaneBackground(tint: Color.spareYellow.opacity(0.05))
    }
}

private struct Stage3MacOSProfileDashboardSurface: View {
    let profile: UserProfile?
    let avatarProfile: AvatarPublicProfile?
    let onSelectSurface: (Stage3MacOSProfileSurface) -> Void
    let onOpenInfrastructure: () -> Void
    let onOpenOpenClaw: () -> Void
    let onOpenSQLite: () -> Void

    private let columns = [
        GridItem(.flexible(minimum: 220), spacing: Spacing.md, alignment: .top),
        GridItem(.flexible(minimum: 220), spacing: Spacing.md, alignment: .top)
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let profile {
                    Stage3MacOSInspectorSection(
                        title: "桌面总览",
                        subtitle: "\(profile.displayName) 的个人中枢"
                    ) {
                        Text("把同步度、人格、记忆、成长、隐私和基础诊断拆成可并排进入的工作面，避免移动端首页的单列长滚动。")
                            .font(.spareCaption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                LazyVGrid(columns: columns, alignment: .leading, spacing: Spacing.md) {
                    Stage3MacOSDashboardTile(
                        title: "同步度",
                        subtitle: "继续跑共享仪表盘",
                        icon: "arrow.triangle.2.circlepath.circle.fill",
                        actionLabel: "打开同步度",
                        action: { onSelectSurface(.sync) }
                    )
                    Stage3MacOSDashboardTile(
                        title: "人格觉醒",
                        subtitle: "保留 MBTI / 画像训练页",
                        icon: "brain.head.profile",
                        actionLabel: "打开人格页",
                        action: { onSelectSurface(.personality) }
                    )
                    Stage3MacOSDashboardTile(
                        title: "记忆宫殿",
                        subtitle: "把搜索、分类和条目管理切到独立面板",
                        icon: "building.columns.fill",
                        actionLabel: "打开记忆宫殿",
                        action: { onSelectSurface(.memories) }
                    )
                    Stage3MacOSDashboardTile(
                        title: "成长统计",
                        subtitle: "把图表和成长回顾切到独立 detail surface",
                        icon: "chart.line.uptrend.xyaxis",
                        actionLabel: "打开成长统计",
                        action: { onSelectSurface(.growth) }
                    )
                    Stage3MacOSDashboardTile(
                        title: "隐私与本地后端",
                        subtitle: "直接进入共享 privacy / backend control 页面",
                        icon: "lock.shield.fill",
                        actionLabel: "打开后端控制",
                        action: { onSelectSurface(.privacy) }
                    )
                    Stage3MacOSDashboardTile(
                        title: "Infrastructure 工作区",
                        subtitle: "用独立窗口承接 OpenClaw、SQLite 与内部诊断面",
                        icon: "wrench.and.screwdriver.fill",
                        actionLabel: "打开工作区",
                        action: onOpenInfrastructure
                    )
                    Stage3MacOSDashboardTile(
                        title: "OpenClaw 插件",
                        subtitle: "桌面化 transport / event / schema panel",
                        icon: "link.circle.fill",
                        actionLabel: "打开插件页",
                        action: onOpenOpenClaw
                    )
                    Stage3MacOSDashboardTile(
                        title: "SQLite 后端",
                        subtitle: "桌面化 repository / detail / migration panel",
                        icon: "internaldrive.fill",
                        actionLabel: "打开 SQLite 页",
                        action: onOpenSQLite
                    )
                }

                if let avatarProfile {
                    Stage3MacOSInspectorSection(
                        title: "公开分身",
                        subtitle: avatarProfile.nickname
                    ) {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text(avatarProfile.tagline)
                                .font(.spareCaption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Stage3MacOSTagCloud(tags: avatarProfile.personalityTraits)
                        }
                    }
                }
            }
            .padding(Spacing.md)
        }
    }
}

private struct Stage3MacOSProfileMetricCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.spareYellowInk)
            Text(value)
                .font(.spareBodySB)
                .foregroundColor(.primary)
            Text(title)
                .font(.spareMicro)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.sm)
        .background(Color.spareYellow.opacity(0.10), in: RoundedRectangle(cornerRadius: CornerRadius.md))
    }
}

private struct Stage3MacOSProfileSurfaceButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .spareYellowInk : .secondary)
                    .frame(width: 22, height: 22)

                Text(title)
                    .font(.spareBody)
                    .foregroundColor(.primary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                    .fill(isSelected ? Color.spareYellow.opacity(0.16) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                    .stroke(isSelected ? Color.spareYellow.opacity(0.30) : Color.cardStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct Stage3MacOSDashboardTile: View {
    let title: String
    let subtitle: String
    let icon: String
    let actionLabel: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.spareYellowInk)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(.spareBodySB)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button(actionLabel, action: action)
                .buttonStyle(.borderedProminent)
                .tint(.spareYellow)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 176, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
    }
}
