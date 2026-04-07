import SwiftUI

public struct Stage3MacOSDiagnosticWorkspaceSnapshot: Equatable, Sendable {
    public let pageID: String
    public let layoutStyle: String
    public let columnKinds: [String]
    public let surfacedViews: [String]
    public let entryKinds: [String]

    public init(
        pageID: String,
        layoutStyle: String,
        columnKinds: [String],
        surfacedViews: [String],
        entryKinds: [String]
    ) {
        self.pageID = pageID
        self.layoutStyle = layoutStyle
        self.columnKinds = columnKinds
        self.surfacedViews = surfacedViews
        self.entryKinds = entryKinds
    }
}

extension Stage3MacOSRuntime {
    public static func diagnosticSnapshot(for pageID: String) -> Stage3MacOSDiagnosticWorkspaceSnapshot? {
        switch resolvedDiagnosticPageID(pageID) {
        case infrastructureWorkspacePageID:
            return Stage3MacOSDiagnosticWorkspaceSnapshot(
                pageID: infrastructureWorkspacePageID,
                layoutStyle: "tool-detail-inspector",
                columnKinds: ["diagnostic catalog", "diagnostic detail", "workspace inspector"],
                surfacedViews: ["OpenClaw / SQLite / Security / AI Memory tools", "selected diagnostic surface", "route + root view inspector"],
                entryKinds: ["tool switch", "standalone window open", "surface smoke"]
            )
        case openClawDiagnosticPageID:
            return Stage3MacOSDiagnosticWorkspaceSnapshot(
                pageID: openClawDiagnosticPageID,
                layoutStyle: "transport-events-inspector",
                columnKinds: ["adapter catalog", "event stream", "schema and handler inspector"],
                surfacedViews: ["summary metrics", "channel events", "schema contracts + handlers"],
                entryKinds: ["adapter select", "direction filter", "status filter"]
            )
        case sqliteDiagnosticPageID:
            return Stage3MacOSDiagnosticWorkspaceSnapshot(
                pageID: sqliteDiagnosticPageID,
                layoutStyle: "repository-detail-timeline",
                columnKinds: ["repository catalog", "repository detail", "migration timeline"],
                surfacedViews: ["integrity stats", "table metrics", "migration history"],
                entryKinds: ["repository select", "reload", "timeline inspect"]
            )
        case securityDiagnosticPageID:
            return Stage3MacOSDiagnosticWorkspaceSnapshot(
                pageID: securityDiagnosticPageID,
                layoutStyle: "embedded-diagnostic-workspace",
                columnKinds: ["diagnostic catalog", "embedded risk view", "workspace inspector"],
                surfacedViews: ["SecurityRiskControlView", "workspace metadata"],
                entryKinds: ["tool switch", "standalone window open"]
            )
        case memoryMatchingDiagnosticPageID:
            return Stage3MacOSDiagnosticWorkspaceSnapshot(
                pageID: memoryMatchingDiagnosticPageID,
                layoutStyle: "embedded-diagnostic-workspace",
                columnKinds: ["diagnostic catalog", "embedded memory view", "workspace inspector"],
                surfacedViews: ["AIMemoryMatchingView", "workspace metadata"],
                entryKinds: ["tool switch", "standalone window open"]
            )
        default:
            return nil
        }
    }
}

public struct Stage3MacOSDiagnosticPageView: View {
    let pageID: String

    private var resolvedPageID: String {
        Stage3MacOSRuntime.resolvedDiagnosticPageID(pageID)
    }

    public init(pageID: String) {
        self.pageID = pageID
    }

    public var body: some View {
        switch resolvedPageID {
        case Stage3MacOSRuntime.infrastructureWorkspacePageID:
            Stage3MacOSInfrastructureWorkspaceView()
        case Stage3MacOSRuntime.openClawDiagnosticPageID:
            Stage3MacOSOpenClawWorkspaceView()
        case Stage3MacOSRuntime.sqliteDiagnosticPageID:
            Stage3MacOSSQLiteWorkspaceView()
        case Stage3MacOSRuntime.securityDiagnosticPageID:
            SecurityRiskControlView()
        case Stage3MacOSRuntime.memoryMatchingDiagnosticPageID:
            AIMemoryMatchingView()
        default:
            Stage3MacOSWorkspacePlaceholder(
                icon: "questionmark.app",
                title: "Unsupported diagnostic surface",
                message: resolvedPageID
            )
        }
    }
}

struct Stage3MacOSInfrastructureWorkspaceView: View {
    @Environment(\.openWindow) private var openWindow
    @State private var selectedToolID = Stage3MacOSRuntime.openClawDiagnosticPageID

    private var toolPages: [Stage3MacOSDiagnosticPageDescriptor] {
        Stage3MacOSRuntime.diagnosticPages.filter { $0.id != Stage3MacOSRuntime.infrastructureWorkspacePageID }
    }

    private var selectedTool: Stage3MacOSDiagnosticPageDescriptor {
        Stage3MacOSRuntime.diagnosticPageDescriptor(for: selectedToolID)
            ?? toolPages.first
            ?? Stage3MacOSDiagnosticPageDescriptor(
                id: Stage3MacOSRuntime.openClawDiagnosticPageID,
                label: "OpenClaw 插件",
                rootView: "Stage3MacOSOpenClawWorkspaceView"
            )
    }

    private var selectedSnapshot: Stage3MacOSDiagnosticWorkspaceSnapshot? {
        Stage3MacOSRuntime.diagnosticSnapshot(for: selectedTool.id)
    }

    var body: some View {
        HSplitView {
            catalogColumn
                .frame(minWidth: 248, idealWidth: 280, maxWidth: 320)

            detailColumn
                .frame(minWidth: 620, idealWidth: 780, maxWidth: .infinity)

            inspectorColumn
                .frame(minWidth: 272, idealWidth: 304, maxWidth: 340)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var catalogColumn: some View {
        VStack(spacing: 0) {
            Stage3MacOSWorkspaceColumnHeader(
                title: "Infrastructure",
                subtitle: "把内部工具从隐藏 support surface 提到桌面工作区，继续承认它们是诊断/预览面，而不是已接线业务 runtime。"
            )

            Divider()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    ForEach(toolPages) { tool in
                        Button {
                            withAnimation(.spareSpring) {
                                selectedToolID = tool.id
                            }
                        } label: {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: Stage3MacOSInfrastructureToolCatalogItem.icon(for: tool.id))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(selectedTool.id == tool.id ? .spareYellowInk : .secondary)
                                    .frame(width: 28, height: 28)
                                    .background(
                                        (selectedTool.id == tool.id ? Color.spareYellow.opacity(0.16) : Color.white),
                                        in: Circle()
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tool.label)
                                        .font(.spareBodySB)
                                        .foregroundColor(.primary)

                                    Text(Stage3MacOSInfrastructureToolCatalogItem.summary(for: tool.id))
                                        .font(.spareMicro)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }

                                Spacer(minLength: 0)
                            }
                            .padding(Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                                    .fill(selectedTool.id == tool.id ? Color.spareYellow.opacity(0.14) : Color.white)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                                    .stroke(selectedTool.id == tool.id ? Color.spareYellow.opacity(0.28) : Color.cardStroke, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
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
                title: selectedTool.label,
                subtitle: Stage3MacOSInfrastructureToolCatalogItem.detailSubtitle(for: selectedTool.id)
            ) {
                Button("打开独立窗口") {
                    openWindow(id: selectedTool.id)
                }
                .buttonStyle(.borderedProminent)
                .tint(.spareYellow)
            }

            Divider()

            Stage3MacOSDiagnosticPageView(pageID: selectedTool.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .workspacePaneBackground()
    }

    private var inspectorColumn: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Stage3MacOSInspectorChip(
                    title: "Workspace",
                    value: "tool-detail-inspector"
                )

                Stage3MacOSInspectorSection(
                    title: "当前工具",
                    subtitle: selectedTool.label
                ) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Stage3MacOSMetadataRow(label: "root_view", value: selectedTool.rootView)
                        Stage3MacOSMetadataRow(label: "surface_kind", value: Stage3MacOSInfrastructureToolCatalogItem.surfaceKind(for: selectedTool.id))
                        Stage3MacOSMetadataRow(label: "truth_boundary", value: "diagnostic / preview surface")
                    }
                }

                if let selectedSnapshot {
                    Stage3MacOSInspectorSection(
                        title: "桌面布局",
                        subtitle: selectedSnapshot.layoutStyle
                    ) {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Stage3MacOSTagCloud(tags: selectedSnapshot.columnKinds)
                            Stage3MacOSTagCloud(tags: selectedSnapshot.entryKinds)
                        }
                    }
                }

                Stage3MacOSInspectorSection(
                    title: "接线口径",
                    subtitle: "避免把 support code 误写成已接线 runtime"
                ) {
                    Text("这些页面可以在 macOS 上真实打开并承接联调，但它们的内容仍以当前共享源码为真。页面可见，不等于对应 backend、plugin 或 local runtime 已完成真实接线。")
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(Spacing.md)
        }
        .workspacePaneBackground(tint: Color.spareYellow.opacity(0.05))
    }
}

struct Stage3MacOSOpenClawWorkspaceView: View {
    @StateObject private var store = OpenClawPluginStore()
    @State private var selectedAdapterID: String?

    private var selectedAdapter: ChannelAdapter? {
        guard let selectedAdapterID else { return store.adapters.first }
        return store.adapters.first(where: { $0.id == selectedAdapterID }) ?? store.adapters.first
    }

    private var visibleEvents: [ChannelEvent] {
        let base = store.filteredEvents
        guard let adapterName = selectedAdapter?.name else { return base }
        return base.filter { $0.adapterName == adapterName }
    }

    var body: some View {
        HSplitView {
            adapterColumn
                .frame(minWidth: 300, idealWidth: 336, maxWidth: 380)

            eventsColumn
                .frame(minWidth: 500, idealWidth: 620, maxWidth: .infinity)

            inspectorColumn
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 360)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            store.load()
        }
        .onChange(of: store.adapters.map(\.id)) { ids in
            guard !ids.isEmpty else {
                selectedAdapterID = nil
                return
            }

            guard let selectedAdapterID else {
                self.selectedAdapterID = ids.first
                return
            }

            if ids.contains(selectedAdapterID) {
                return
            }

            self.selectedAdapterID = ids.first
        }
    }

    private var adapterColumn: some View {
        VStack(spacing: 0) {
            Stage3MacOSWorkspaceColumnHeader(
                title: "渠道与适配器",
                subtitle: "左栏固定 transport summary 与 adapter 目录，桌面端不再靠单一 tab 在长列表里来回切。"
            )

            Divider()

            Group {
                switch store.loadState {
                case .idle, .loading:
                    Stage3MacOSDiagnosticLoadingPlaceholder(count: 5)
                case .error(let message):
                    ErrorStateView(message: message, retry: store.retry)
                case .loaded:
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Stage3MacOSDiagnosticMetricGrid(items: [
                                .init(label: "传入", value: "\(store.totalInbound)", icon: "arrow.down.circle.fill"),
                                .init(label: "传出", value: "\(store.totalOutbound)", icon: "arrow.up.circle.fill"),
                                .init(label: "活跃适配器", value: "\(store.activeAdapters)", icon: "link.circle.fill"),
                                .init(label: "异常", value: "\(store.totalErrors)", icon: "exclamationmark.triangle.fill")
                            ])

                            ForEach(store.adapters) { adapter in
                                Button {
                                    selectedAdapterID = adapter.id
                                } label: {
                                    HStack(spacing: Spacing.sm) {
                                        Image(systemName: adapter.icon)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(adapter.accentColor)
                                            .frame(width: 30, height: 30)
                                            .background(adapter.accentColor.opacity(0.14), in: Circle())

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(adapter.name)
                                                .font(.spareBodySB)
                                                .foregroundColor(.primary)

                                            Text("入 \(adapter.inboundCount) · 出 \(adapter.outboundCount) · 异常 \(adapter.errorCount)")
                                                .font(.spareMicro)
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer(minLength: 0)

                                        Circle()
                                            .fill(adapter.isEnabled ? Color.spareYellowInk : Color.gray)
                                            .frame(width: 8, height: 8)
                                    }
                                    .padding(Spacing.md)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                                            .fill(selectedAdapter?.id == adapter.id ? Color.spareYellow.opacity(0.14) : Color.white)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                                            .stroke(selectedAdapter?.id == adapter.id ? Color.spareYellow.opacity(0.28) : Color.cardStroke, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(Spacing.md)
                    }
                }
            }
        }
        .workspacePaneBackground()
    }

    private var eventsColumn: some View {
        VStack(spacing: 0) {
            Stage3MacOSWorkspaceColumnHeader(
                title: "事件流",
                subtitle: "中栏固定 recent events，并直接暴露 direction/status filter 便于桌面联调。"
            )

            Divider()

            Group {
                switch store.loadState {
                case .idle, .loading:
                    Stage3MacOSDiagnosticLoadingPlaceholder(count: 6)
                case .error(let message):
                    ErrorStateView(message: message, retry: store.retry)
                case .loaded:
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                Text("方向筛选")
                                    .font(.spareCaptionSB)
                                    .foregroundColor(.secondary)

                                HStack(spacing: Spacing.sm) {
                                    Stage3MacOSFilterChip(
                                        title: "全部",
                                        isSelected: store.directionFilter == nil
                                    ) {
                                        store.directionFilter = nil
                                    }

                                    ForEach(ChannelDirection.allCases) { direction in
                                        Stage3MacOSFilterChip(
                                            title: direction.rawValue,
                                            isSelected: store.directionFilter == direction
                                        ) {
                                            store.directionFilter = store.directionFilter == direction ? nil : direction
                                        }
                                    }
                                }

                                Text("状态筛选")
                                    .font(.spareCaptionSB)
                                    .foregroundColor(.secondary)

                                HStack(spacing: Spacing.sm) {
                                    ForEach(ChannelEvent.EventStatus.allCases) { status in
                                        Stage3MacOSFilterChip(
                                            title: status.rawValue,
                                            isSelected: store.statusFilter == status
                                        ) {
                                            store.statusFilter = store.statusFilter == status ? nil : status
                                        }
                                    }
                                }
                            }

                            if visibleEvents.isEmpty {
                                Stage3MacOSWorkspacePlaceholder(
                                    icon: "tray.fill",
                                    title: "当前筛选没有事件",
                                    message: "换一个 adapter、方向或状态筛选后再看。"
                                )
                                .frame(height: 320)
                            } else {
                                ForEach(visibleEvents) { event in
                                    VStack(alignment: .leading, spacing: Spacing.sm) {
                                        HStack(spacing: Spacing.sm) {
                                            Image(systemName: event.direction.icon)
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(event.direction.color)

                                            Text(event.adapterName)
                                                .font(.spareCaptionSB)
                                                .foregroundColor(.secondary)

                                            Spacer()

                                            Text(event.timestamp, style: .relative)
                                                .font(.spareMicro)
                                                .foregroundColor(.secondary)
                                        }

                                        Text(event.eventType)
                                            .font(.spareBodySB)
                                            .foregroundColor(.primary)

                                        Text(event.payloadPreview)
                                            .font(.spareCaption)
                                            .foregroundColor(.secondary)
                                            .textSelection(.enabled)
                                            .fixedSize(horizontal: false, vertical: true)

                                        HStack(spacing: Spacing.sm) {
                                            PillTag(label: event.direction.rawValue, color: .spareYellowInk, filled: true)
                                            PillTag(label: event.status.rawValue, color: event.status.color, filled: false)
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
                                }
                            }
                        }
                        .padding(Spacing.md)
                    }
                }
            }
        }
        .workspacePaneBackground()
    }

    private var inspectorColumn: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Stage3MacOSInspectorChip(
                    title: "Workspace",
                    value: "transport-events-inspector"
                )

                if let adapter = selectedAdapter {
                    Stage3MacOSInspectorSection(
                        title: "当前适配器",
                        subtitle: adapter.name
                    ) {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Stage3MacOSMetadataRow(label: "adapter_id", value: adapter.id)
                            Stage3MacOSMetadataRow(label: "enabled", value: adapter.isEnabled ? "yes" : "no")
                            Stage3MacOSMetadataRow(label: "last_active", value: adapter.lastActiveAt.formatted(date: .abbreviated, time: .shortened))
                            Stage3MacOSMetadataRow(label: "inbound/outbound", value: "\(adapter.inboundCount) / \(adapter.outboundCount)")
                        }
                    }
                }

                Stage3MacOSInspectorSection(
                    title: "Schema 合约",
                    subtitle: "\(store.schemas.count) 个共享合约"
                ) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        ForEach(store.schemas.prefix(4)) { schema in
                            Stage3MacOSMetadataRow(
                                label: "\(schema.name) v\(schema.version)",
                                value: "fields \(schema.fieldCount) · pass \(schema.validationsPassed) · fail \(schema.validationsFailed)"
                            )
                        }
                    }
                }

                Stage3MacOSInspectorSection(
                    title: "Pipeline Handlers",
                    subtitle: "\(store.handlers.count) 条处理链"
                ) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        ForEach(store.handlers.prefix(5)) { handler in
                            Stage3MacOSMetadataRow(
                                label: handler.name,
                                value: "\(handler.handlerType.rawValue) · \(handler.processedCount) 次 · \(handler.avgLatencyMs)ms"
                            )
                        }
                    }
                }
            }
            .padding(Spacing.md)
        }
        .workspacePaneBackground(tint: Color.spareYellow.opacity(0.05))
    }
}

struct Stage3MacOSSQLiteWorkspaceView: View {
    @StateObject private var store = SQLiteBackendDashboardStore()
    @State private var selectedRepositoryID: String?

    private var selectedRepository: DomainRepository? {
        guard let selectedRepositoryID else { return store.repositories.first }
        return store.repositories.first(where: { $0.id == selectedRepositoryID }) ?? store.repositories.first
    }

    var body: some View {
        HSplitView {
            repositoryColumn
                .frame(minWidth: 300, idealWidth: 336, maxWidth: 380)

            detailColumn
                .frame(minWidth: 500, idealWidth: 620, maxWidth: .infinity)

            timelineColumn
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 360)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            store.load()
        }
        .onChange(of: store.repositories.map(\.id)) { ids in
            guard !ids.isEmpty else {
                selectedRepositoryID = nil
                return
            }

            guard let selectedRepositoryID else {
                self.selectedRepositoryID = ids.first
                return
            }

            if ids.contains(selectedRepositoryID) {
                return
            }

            self.selectedRepositoryID = ids.first
        }
    }

    private var repositoryColumn: some View {
        VStack(spacing: 0) {
            Stage3MacOSWorkspaceColumnHeader(
                title: "仓库目录",
                subtitle: "左栏固定 repository 列表与 DB integrity 摘要，桌面端先稳定主键与表级语义。"
            ) {
                Button("刷新") {
                    store.reload()
                }
                .buttonStyle(.borderedProminent)
                .tint(.spareYellow)
            }

            Divider()

            Group {
                switch store.loadState {
                case .idle, .loading:
                    Stage3MacOSDiagnosticLoadingPlaceholder(count: 5)
                case .error(let message):
                    ErrorStateView(message: message, retry: store.reload)
                case .loaded:
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                Stage3MacOSDiagnosticMetricGrid(items: [
                                    .init(label: "DB 版本", value: "v\(store.dbVersion)", icon: "cylinder.fill"),
                                    .init(label: "仓库数", value: "\(store.repositories.count)", icon: "tablecells.fill"),
                                    .init(label: "DB 大小", value: ByteCountFormatter.string(fromByteCount: store.totalSizeBytes, countStyle: .file), icon: "internaldrive.fill"),
                                    .init(label: "WAL", value: ByteCountFormatter.string(fromByteCount: store.walSizeBytes, countStyle: .file), icon: "doc.on.doc.fill")
                                ])
                            }

                            ForEach(store.repositories) { repository in
                                Button {
                                    selectedRepositoryID = repository.id
                                } label: {
                                    HStack(spacing: Spacing.sm) {
                                        Image(systemName: repository.icon)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(repository.accentColor)
                                            .frame(width: 30, height: 30)
                                            .background(repository.accentColor.opacity(0.14), in: Circle())

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(repository.name)
                                                .font(.spareBodySB)
                                                .foregroundColor(.primary)
                                            Text("\(repository.tableName) · \(repository.rowCount) 行")
                                                .font(.spareMicro)
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer(minLength: 0)

                                        Circle()
                                            .fill(repository.isHealthy ? Color.spareYellowInk : Color.red)
                                            .frame(width: 8, height: 8)
                                    }
                                    .padding(Spacing.md)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                                            .fill(selectedRepository?.id == repository.id ? Color.spareYellow.opacity(0.14) : Color.white)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                                            .stroke(selectedRepository?.id == repository.id ? Color.spareYellow.opacity(0.28) : Color.cardStroke, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(Spacing.md)
                    }
                }
            }
        }
        .workspacePaneBackground()
    }

    private var detailColumn: some View {
        VStack(spacing: 0) {
            Stage3MacOSWorkspaceColumnHeader(
                title: selectedRepository?.name ?? "Repository 详情",
                subtitle: "中栏固定表级详情、读写量与 schema 提示，减少从 sheet 来回切换。"
            )

            Divider()

            Group {
                switch store.loadState {
                case .idle, .loading:
                    Stage3MacOSDiagnosticLoadingPlaceholder(count: 4)
                case .error(let message):
                    ErrorStateView(message: message, retry: store.reload)
                case .loaded:
                    if let repository = selectedRepository {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: Spacing.md) {
                                Stage3MacOSInspectorSection(
                                    title: "当前仓库",
                                    subtitle: repository.tableName
                                ) {
                                    VStack(alignment: .leading, spacing: Spacing.sm) {
                                        Stage3MacOSMetadataRow(label: "row_count", value: "\(repository.rowCount)")
                                        Stage3MacOSMetadataRow(label: "reads", value: "\(repository.readCount)")
                                        Stage3MacOSMetadataRow(label: "writes", value: "\(repository.writeCount)")
                                        Stage3MacOSMetadataRow(
                                            label: "last_write",
                                            value: repository.lastWrite.formatted(date: .abbreviated, time: .shortened)
                                        )
                                    }
                                }

                                Stage3MacOSDiagnosticMetricGrid(items: [
                                    .init(label: "总行数", value: "\(repository.rowCount)", icon: "number"),
                                    .init(label: "读取", value: stage3CompactCount(repository.readCount), icon: "eye.fill"),
                                    .init(label: "写入", value: stage3CompactCount(repository.writeCount), icon: "pencil.line"),
                                    .init(label: "健康状态", value: repository.isHealthy ? "正常" : "异常", icon: "heart.text.square.fill")
                                ])

                                Stage3MacOSInspectorSection(
                                    title: "Schema 提示",
                                    subtitle: "当前页面仍是 mock diagnostics"
                                ) {
                                    Text("CREATE TABLE \(repository.tableName) (...)")
                                        .font(.spareMicro)
                                        .foregroundColor(.secondary)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(Spacing.md)
                                        .background(Color.spareYellow.opacity(0.10), in: RoundedRectangle(cornerRadius: CornerRadius.md))
                                }
                            }
                            .padding(Spacing.md)
                        }
                    } else {
                        Stage3MacOSWorkspacePlaceholder(
                            icon: "tablecells",
                            title: "选择一个 repository",
                            message: "左侧选中后，中栏会固定显示该表的读写与 schema 摘要。"
                        )
                    }
                }
            }
        }
        .workspacePaneBackground()
    }

    private var timelineColumn: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Stage3MacOSInspectorChip(
                    title: "Workspace",
                    value: "repository-detail-timeline"
                )

                Stage3MacOSInspectorSection(
                    title: "DB 状态",
                    subtitle: store.integrityOK ? "PRAGMA integrity_check: OK" : "完整性校验异常"
                ) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Stage3MacOSMetadataRow(label: "db_version", value: "v\(store.dbVersion)")
                        Stage3MacOSMetadataRow(
                            label: "db_size",
                            value: ByteCountFormatter.string(fromByteCount: store.totalSizeBytes, countStyle: .file)
                        )
                        Stage3MacOSMetadataRow(
                            label: "wal_size",
                            value: ByteCountFormatter.string(fromByteCount: store.walSizeBytes, countStyle: .file)
                        )
                    }
                }

                Stage3MacOSInspectorSection(
                    title: "迁移时间线",
                    subtitle: "\(store.migrations.count) 个版本"
                ) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        ForEach(Array(store.migrations.reversed().prefix(6))) { migration in
                            Stage3MacOSMetadataRow(
                                label: "v\(migration.version) · \(migration.name)",
                                value: "\(migration.status.rawValue) · \(migration.appliedAt.formatted(date: .abbreviated, time: .omitted))"
                            )
                        }
                    }
                }
            }
            .padding(Spacing.md)
        }
        .workspacePaneBackground(tint: Color.spareYellow.opacity(0.05))
    }
}

private struct Stage3MacOSInfrastructureToolCatalogItem {
    static func icon(for id: String) -> String {
        switch id {
        case Stage3MacOSRuntime.openClawDiagnosticPageID:
            return "link.circle.fill"
        case Stage3MacOSRuntime.sqliteDiagnosticPageID:
            return "internaldrive.fill"
        case Stage3MacOSRuntime.securityDiagnosticPageID:
            return "lock.shield.fill"
        case Stage3MacOSRuntime.memoryMatchingDiagnosticPageID:
            return "brain.head.profile"
        default:
            return "wrench.and.screwdriver.fill"
        }
    }

    static func summary(for id: String) -> String {
        switch id {
        case Stage3MacOSRuntime.openClawDiagnosticPageID:
            return "adapter / event / schema"
        case Stage3MacOSRuntime.sqliteDiagnosticPageID:
            return "repository / detail / migration"
        case Stage3MacOSRuntime.securityDiagnosticPageID:
            return "共享风险控制页"
        case Stage3MacOSRuntime.memoryMatchingDiagnosticPageID:
            return "共享记忆匹配页"
        default:
            return "基础诊断面"
        }
    }

    static func detailSubtitle(for id: String) -> String {
        switch id {
        case Stage3MacOSRuntime.openClawDiagnosticPageID:
            return "把 transport、events 与 schema/handler 拆成并排工作区。"
        case Stage3MacOSRuntime.sqliteDiagnosticPageID:
            return "把 repository、表详情与 migration timeline 拆成并排工作区。"
        case Stage3MacOSRuntime.securityDiagnosticPageID:
            return "继续承接共享 `SecurityRiskControlView`，但放进桌面工具目录。"
        case Stage3MacOSRuntime.memoryMatchingDiagnosticPageID:
            return "继续承接共享 `AIMemoryMatchingView`，但放进桌面工具目录。"
        default:
            return "桌面诊断工作区"
        }
    }

    static func surfaceKind(for id: String) -> String {
        switch id {
        case Stage3MacOSRuntime.openClawDiagnosticPageID, Stage3MacOSRuntime.sqliteDiagnosticPageID:
            return "panelized desktop diagnostic"
        case Stage3MacOSRuntime.securityDiagnosticPageID, Stage3MacOSRuntime.memoryMatchingDiagnosticPageID:
            return "shared embedded diagnostic"
        default:
            return "workspace"
        }
    }
}

private struct Stage3MacOSDiagnosticMetricItem: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let icon: String
}

private struct Stage3MacOSDiagnosticMetricGrid: View {
    let items: [Stage3MacOSDiagnosticMetricItem]

    private let columns = [
        GridItem(.flexible(minimum: 88), spacing: Spacing.sm, alignment: .top),
        GridItem(.flexible(minimum: 88), spacing: Spacing.sm, alignment: .top)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: Spacing.sm) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Image(systemName: item.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.spareYellowInk)

                    Text(item.value)
                        .font(.spareBodySB)
                        .foregroundColor(.primary)

                    Text(item.label)
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.sm)
                .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(Color.cardStroke, lineWidth: 1)
                )
            }
        }
    }
}

private struct Stage3MacOSDiagnosticLoadingPlaceholder: View {
    let count: Int

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.md) {
                ForEach(0..<count, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                        .fill(Color.white)
                        .frame(height: 92)
                        .shimmer()
                }
            }
            .padding(Spacing.md)
        }
    }
}

private func stage3CompactCount(_ value: Int) -> String {
    if value >= 1000 {
        return String(format: "%.1fk", Double(value) / 1000.0)
    }
    return "\(value)"
}
