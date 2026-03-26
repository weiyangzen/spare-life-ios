// OpenClawPluginView.swift
// Spare Life – 底层 · OpenClaw 渠道插件管理面板
// Blueprint §7 底层 · [UIUX] OpenClaw 插件 (line:1156)
// UIUX lane – slot 2

import SwiftUI

// MARK: - Models

/// Direction of a channel message flow.
enum ChannelDirection: String, CaseIterable, Identifiable {
    case inbound  = "传入"
    case outbound = "传出"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .inbound:  return "arrow.down.circle.fill"
        case .outbound: return "arrow.up.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .inbound:  return .blue
        case .outbound: return .purple
        }
    }
}

/// A registered channel adapter (e.g. WeChat, LINE, SMS).
struct ChannelAdapter: Identifiable {
    let id: String
    let name: String
    let icon: String
    let isEnabled: Bool
    let inboundCount: Int
    let outboundCount: Int
    let errorCount: Int
    let lastActiveAt: Date
    let accentColor: Color
}

/// An individual message event flowing through the plugin pipeline.
struct ChannelEvent: Identifiable {
    let id: String
    let direction: ChannelDirection
    let adapterName: String
    let eventType: String
    let payloadPreview: String
    let timestamp: Date
    let status: EventStatus

    enum EventStatus: String, CaseIterable, Identifiable {
        case success   = "成功"
        case pending   = "处理中"
        case failed    = "失败"
        case rejected  = "拒绝"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .success:  return "checkmark.circle.fill"
            case .pending:  return "clock.arrow.circlepath"
            case .failed:   return "xmark.circle.fill"
            case .rejected: return "hand.raised.fill"
            }
        }

        var color: Color {
            switch self {
            case .success:  return .green
            case .pending:  return .orange
            case .failed:   return .red
            case .rejected: return .gray
            }
        }
    }
}

/// A registered schema contract used for payload validation.
struct SchemaContract: Identifiable {
    let id: String
    let name: String
    let version: Int
    let fieldCount: Int
    let validationsPassed: Int
    let validationsFailed: Int
    let lastValidatedAt: Date
}

/// A pipeline handler that processes events.
struct PipelineHandler: Identifiable {
    let id: String
    let name: String
    let handlerType: HandlerType
    let processedCount: Int
    let avgLatencyMs: Int
    let errorRate: Double
    let isActive: Bool

    enum HandlerType: String, CaseIterable, Identifiable {
        case sceneScan      = "场景扫码"
        case icebreaker     = "破冰分身"
        case threadSync     = "线程同步"
        case masterFlow     = "大师流"
        case earnSocial     = "闲能流"
        case companionChat  = "陪伴聊天"
        case unifiedChannel = "统一渠道"
        case unifiedUI      = "统一 UI"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .sceneScan:      return "qrcode.viewfinder"
            case .icebreaker:     return "person.badge.plus"
            case .threadSync:     return "arrow.triangle.2.circlepath"
            case .masterFlow:     return "graduationcap.fill"
            case .earnSocial:     return "sparkles"
            case .companionChat:  return "bubble.left.and.bubble.right.fill"
            case .unifiedChannel: return "antenna.radiowaves.left.and.right"
            case .unifiedUI:      return "rectangle.grid.2x2.fill"
            }
        }
    }
}

enum OpenClawLoadState {
    case idle, loading, loaded, error(String)
}

// MARK: - Store

@MainActor
final class OpenClawPluginStore: ObservableObject {
    @Published var loadState: OpenClawLoadState = .idle
    @Published var adapters: [ChannelAdapter] = []
    @Published var recentEvents: [ChannelEvent] = []
    @Published var schemas: [SchemaContract] = []
    @Published var handlers: [PipelineHandler] = []

    // Filters
    @Published var selectedTab: OpenClawTab = .adapters
    @Published var directionFilter: ChannelDirection? = nil
    @Published var statusFilter: ChannelEvent.EventStatus? = nil
    @Published var selectedAdapter: ChannelAdapter? = nil
    @Published var showAdapterDetail = false

    // Aggregates
    var totalInbound: Int { adapters.reduce(0) { $0 + $1.inboundCount } }
    var totalOutbound: Int { adapters.reduce(0) { $0 + $1.outboundCount } }
    var totalErrors: Int { adapters.reduce(0) { $0 + $1.errorCount } }
    var activeAdapters: Int { adapters.filter(\.isEnabled).count }

    var filteredEvents: [ChannelEvent] {
        var result = recentEvents
        if let dir = directionFilter { result = result.filter { $0.direction == dir } }
        if let st = statusFilter { result = result.filter { $0.status == st } }
        return result
    }

    func load() {
        guard case .idle = loadState else { return }
        loadState = .loading
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)

            adapters = [
                .init(id: "wechat", name: "微信", icon: "message.fill",
                      isEnabled: true, inboundCount: 342, outboundCount: 298,
                      errorCount: 3, lastActiveAt: date(-0.01), accentColor: .green),
                .init(id: "line", name: "LINE", icon: "bubble.left.fill",
                      isEnabled: true, inboundCount: 156, outboundCount: 143,
                      errorCount: 1, lastActiveAt: date(-0.05), accentColor: .green),
                .init(id: "sms", name: "SMS", icon: "phone.fill",
                      isEnabled: true, inboundCount: 28, outboundCount: 24,
                      errorCount: 0, lastActiveAt: date(-0.5), accentColor: .blue),
                .init(id: "email", name: "Email", icon: "envelope.fill",
                      isEnabled: false, inboundCount: 0, outboundCount: 0,
                      errorCount: 0, lastActiveAt: date(-30), accentColor: .gray),
                .init(id: "webhook", name: "Webhook", icon: "link",
                      isEnabled: true, inboundCount: 89, outboundCount: 76,
                      errorCount: 2, lastActiveAt: date(-0.1), accentColor: .orange),
            ]

            recentEvents = [
                .init(id: "e1", direction: .inbound, adapterName: "微信", eventType: "scene_scan",
                      payloadPreview: "{ rawCode: \"qr://cafe_hub_07\", posts: 4 }",
                      timestamp: date(-0.01), status: .success),
                .init(id: "e2", direction: .outbound, adapterName: "微信", eventType: "scene_discussion_reply",
                      payloadPreview: "{ threadId: \"t_9a2\", message: \"分身已回复\" }",
                      timestamp: date(-0.02), status: .success),
                .init(id: "e3", direction: .inbound, adapterName: "LINE", eventType: "intent_exchange",
                      payloadPreview: "{ mode: \"friend\", message: \"想认识...\" }",
                      timestamp: date(-0.05), status: .success),
                .init(id: "e4", direction: .inbound, adapterName: "Webhook", eventType: "agent_handoff",
                      payloadPreview: "{ from: \"bot_001\", reason: \"escalation\" }",
                      timestamp: date(-0.1), status: .pending),
                .init(id: "e5", direction: .outbound, adapterName: "LINE", eventType: "companion_response",
                      payloadPreview: "{ contactId: \"c_8f1\", tone: \"warm\" }",
                      timestamp: date(-0.12), status: .success),
                .init(id: "e6", direction: .inbound, adapterName: "微信", eventType: "scene_scan",
                      payloadPreview: "{ rawCode: \"qr://expo_hall_02\", posts: 1 }",
                      timestamp: date(-0.2), status: .failed),
                .init(id: "e7", direction: .outbound, adapterName: "Webhook", eventType: "master_catalog_sync",
                      payloadPreview: "{ masters: 4, stories: 12 }",
                      timestamp: date(-0.3), status: .success),
                .init(id: "e8", direction: .inbound, adapterName: "SMS", eventType: "verification_code",
                      payloadPreview: "{ phone: \"138****1234\", code: \"****\" }",
                      timestamp: date(-0.5), status: .rejected),
                .init(id: "e9", direction: .outbound, adapterName: "微信", eventType: "earn_social_reward",
                      payloadPreview: "{ userId: \"u_3c\", energy: 5 }",
                      timestamp: date(-0.6), status: .success),
                .init(id: "e10", direction: .inbound, adapterName: "微信", eventType: "companion_message",
                      payloadPreview: "{ threadId: \"t_ab3\", text: \"今天好吗\" }",
                      timestamp: date(-0.8), status: .success),
            ]

            schemas = [
                .init(id: "s1", name: "InboundEvent", version: 3, fieldCount: 8,
                      validationsPassed: 615, validationsFailed: 4, lastValidatedAt: date(-0.01)),
                .init(id: "s2", name: "OutboundEvent", version: 2, fieldCount: 7,
                      validationsPassed: 541, validationsFailed: 2, lastValidatedAt: date(-0.02)),
                .init(id: "s3", name: "AgentHandoffRequest", version: 1, fieldCount: 5,
                      validationsPassed: 89, validationsFailed: 1, lastValidatedAt: date(-0.1)),
                .init(id: "s4", name: "AgentHandoffResult", version: 1, fieldCount: 6,
                      validationsPassed: 87, validationsFailed: 0, lastValidatedAt: date(-0.12)),
                .init(id: "s5", name: "SceneScanPayload", version: 2, fieldCount: 6,
                      validationsPassed: 342, validationsFailed: 3, lastValidatedAt: date(-0.01)),
                .init(id: "s6", name: "IntentExchangePayload", version: 1, fieldCount: 4,
                      validationsPassed: 156, validationsFailed: 0, lastValidatedAt: date(-0.05)),
            ]

            handlers = [
                .init(id: "h1", name: "sceneScanHandler", handlerType: .sceneScan,
                      processedCount: 342, avgLatencyMs: 45, errorRate: 0.009, isActive: true),
                .init(id: "h2", name: "sceneIntentHandler", handlerType: .icebreaker,
                      processedCount: 156, avgLatencyMs: 62, errorRate: 0.006, isActive: true),
                .init(id: "h3", name: "companionChatHandler", handlerType: .companionChat,
                      processedCount: 498, avgLatencyMs: 38, errorRate: 0.004, isActive: true),
                .init(id: "h4", name: "masterFlowHandler", handlerType: .masterFlow,
                      processedCount: 87, avgLatencyMs: 71, errorRate: 0.011, isActive: true),
                .init(id: "h5", name: "earnSocialFlowHandler", handlerType: .earnSocial,
                      processedCount: 203, avgLatencyMs: 55, errorRate: 0.005, isActive: true),
                .init(id: "h6", name: "myDashboardHandler", handlerType: .unifiedUI,
                      processedCount: 144, avgLatencyMs: 33, errorRate: 0.0, isActive: true),
                .init(id: "h7", name: "unifiedChannelHandler", handlerType: .unifiedChannel,
                      processedCount: 89, avgLatencyMs: 48, errorRate: 0.022, isActive: true),
                .init(id: "h8", name: "unifiedUIHandler", handlerType: .unifiedUI,
                      processedCount: 67, avgLatencyMs: 29, errorRate: 0.0, isActive: true),
            ]

            loadState = .loaded
        }
    }

    func retry() {
        loadState = .idle
        load()
    }

    private func date(_ daysOffset: Double) -> Date {
        Date().addingTimeInterval(daysOffset * 86_400)
    }
}

enum OpenClawTab: String, CaseIterable, Identifiable {
    case adapters  = "渠道"
    case events    = "消息流"
    case schemas   = "Schema"
    case handlers  = "Handler"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .adapters: return "antenna.radiowaves.left.and.right"
        case .events:   return "arrow.left.arrow.right"
        case .schemas:  return "doc.text.magnifyingglass"
        case .handlers: return "gearshape.2.fill"
        }
    }
}

// MARK: - Main View

struct OpenClawPluginView: View {
    @StateObject private var store = OpenClawPluginStore()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                Group {
                    switch store.loadState {
                    case .idle, .loading:
                        loadingBody
                    case .loaded:
                        loadedBody
                    case .error(let msg):
                        ErrorStateView(message: msg, retry: store.retry)
                    }
                }
            }
            .navigationTitle("OpenClaw 插件")
            .navigationBarTitleDisplayMode(.large)
            .task { store.load() }
            .sheet(isPresented: $store.showAdapterDetail) {
                if let adapter = store.selectedAdapter {
                    AdapterDetailSheet(adapter: adapter, events: store.recentEvents)
                }
            }
        }
    }

    // MARK: - Loading

    private var loadingBody: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Summary skeleton
                HStack(spacing: Spacing.md) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .fill(Color(.systemGray5))
                            .frame(height: 72)
                            .modifier(ShimmerModifier())
                    }
                }
                .padding(.horizontal, Spacing.lg)

                // Tab skeleton
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .fill(Color(.systemGray5))
                    .frame(height: 36)
                    .padding(.horizontal, Spacing.lg)
                    .modifier(ShimmerModifier())

                // Cards skeleton
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .fill(Color(.systemGray5))
                        .frame(height: 88)
                        .padding(.horizontal, Spacing.lg)
                        .modifier(ShimmerModifier())
                }
            }
            .padding(.top, Spacing.lg)
        }
    }

    // MARK: - Loaded

    private var loadedBody: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                summaryRow
                tabBar
                tabContent
            }
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xxxl)
        }
    }

    // MARK: - Summary Row

    private var summaryRow: some View {
        HStack(spacing: Spacing.md) {
            summaryCard(
                icon: "arrow.down.circle.fill",
                label: "传入",
                value: "\(store.totalInbound)",
                color: .blue
            )
            summaryCard(
                icon: "arrow.up.circle.fill",
                label: "传出",
                value: "\(store.totalOutbound)",
                color: .purple
            )
            summaryCard(
                icon: "exclamationmark.triangle.fill",
                label: "异常",
                value: "\(store.totalErrors)",
                color: store.totalErrors > 0 ? .red : .green
            )
        }
        .padding(.horizontal, Spacing.lg)
    }

    private func summaryCard(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.spareTitle2)
                .foregroundColor(.primary)
            Text(label)
                .font(.spareCaption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.md))
        .modifier(CardShadow())
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(OpenClawTab.allCases) { tab in
                    Button {
                        withAnimation(.spareEase) { store.selectedTab = tab }
                    } label: {
                        Label(tab.rawValue, systemImage: tab.icon)
                            .font(.spareCaptionSB)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .background(
                                Capsule().fill(store.selectedTab == tab ? Color.spareYellow : Color.chipUnselected)
                            )
                            .foregroundColor(store.selectedTab == tab ? Color.spareDark : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch store.selectedTab {
        case .adapters: adaptersSection
        case .events:   eventsSection
        case .schemas:  schemasSection
        case .handlers: handlersSection
        }
    }

    // MARK: - Adapters Tab

    private var adaptersSection: some View {
        VStack(spacing: Spacing.md) {
            FeedSectionHeader(title: "渠道适配器", subtitle: "\(store.activeAdapters) 个活跃")
                .padding(.horizontal, Spacing.lg)

            if store.adapters.isEmpty {
                EmptyStateView(icon: "antenna.radiowaves.left.and.right.slash",
                               title: "暂无渠道",
                               message: "尚未注册任何渠道适配器")
                    .padding(.horizontal, Spacing.lg)
            } else {
                ForEach(store.adapters) { adapter in
                    adapterRow(adapter)
                        .padding(.horizontal, Spacing.lg)
                }
            }
        }
    }

    private func adapterRow(_ adapter: ChannelAdapter) -> some View {
        Button {
            store.selectedAdapter = adapter
            store.showAdapterDetail = true
        } label: {
            HStack(spacing: Spacing.md) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(adapter.accentColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: adapter.icon)
                        .font(.body)
                        .foregroundColor(adapter.accentColor)
                }

                // Name + status
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xs) {
                        Text(adapter.name)
                            .font(.spareBodySB)
                            .foregroundColor(.primary)
                        Circle()
                            .fill(adapter.isEnabled ? Color.green : Color.gray)
                            .frame(width: 6, height: 6)
                    }
                    Text("入 \(adapter.inboundCount) · 出 \(adapter.outboundCount)")
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Error badge + chevron
                if adapter.errorCount > 0 {
                    PillTag(label: "\(adapter.errorCount) 异常", color: .red, filled: true)
                }

                Image(systemName: "chevron.right")
                    .font(.spareCaption)
                    .foregroundColor(.gray)
            }
            .padding(Spacing.md)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.md))
            .modifier(CardShadow())
        }
        .buttonStyle(CardPressStyle())
    }

    // MARK: - Events Tab

    private var eventsSection: some View {
        VStack(spacing: Spacing.md) {
            // Direction filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    filterChip(label: "全部", selected: store.directionFilter == nil) {
                        store.directionFilter = nil
                    }
                    ForEach(ChannelDirection.allCases) { dir in
                        filterChip(label: dir.rawValue, selected: store.directionFilter == dir) {
                            store.directionFilter = dir
                        }
                    }
                    Divider().frame(height: 20)
                    ForEach(ChannelEvent.EventStatus.allCases) { st in
                        filterChip(label: st.rawValue, selected: store.statusFilter == st) {
                            store.statusFilter = store.statusFilter == st ? nil : st
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }

            FeedSectionHeader(title: "消息流", subtitle: "\(store.filteredEvents.count) 条")
                .padding(.horizontal, Spacing.lg)

            if store.filteredEvents.isEmpty {
                EmptyStateView(icon: "tray",
                               title: "暂无消息",
                               message: "没有匹配当前筛选条件的消息事件")
                    .padding(.horizontal, Spacing.lg)
            } else {
                ForEach(store.filteredEvents) { event in
                    eventRow(event)
                        .padding(.horizontal, Spacing.lg)
                }
            }
        }
    }

    private func eventRow(_ event: ChannelEvent) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: event.direction.icon)
                    .font(.caption)
                    .foregroundColor(event.direction.color)
                Text(event.adapterName)
                    .font(.spareCaptionSB)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: event.status.icon)
                    .font(.caption)
                    .foregroundColor(event.status.color)
                Text(event.status.rawValue)
                    .font(.spareMicro)
                    .foregroundColor(event.status.color)
            }
            Text(event.eventType)
                .font(.spareBodySB)
                .foregroundColor(.primary)
            Text(event.payloadPreview)
                .font(.spareCaption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            Text(event.timestamp, style: .relative)
                .font(.spareMicro)
                .foregroundColor(.gray)
        }
        .padding(Spacing.md)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.md))
        .modifier(CardShadow())
    }

    // MARK: - Schemas Tab

    private var schemasSection: some View {
        VStack(spacing: Spacing.md) {
            FeedSectionHeader(title: "Schema 合约", subtitle: "\(store.schemas.count) 个")
                .padding(.horizontal, Spacing.lg)

            if store.schemas.isEmpty {
                EmptyStateView(icon: "doc.text.magnifyingglass",
                               title: "暂无 Schema",
                               message: "尚未注册任何合约 Schema")
                    .padding(.horizontal, Spacing.lg)
            } else {
                ForEach(store.schemas) { schema in
                    schemaRow(schema)
                        .padding(.horizontal, Spacing.lg)
                }
            }
        }
    }

    private func schemaRow(_ schema: SchemaContract) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(schema.name)
                    .font(.spareBodySB)
                    .foregroundColor(.primary)
                Spacer()
                PillTag(label: "v\(schema.version)", color: .blue)
            }

            HStack(spacing: Spacing.lg) {
                Label("\(schema.fieldCount) 字段", systemImage: "list.bullet")
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
                Label("\(schema.validationsPassed) 通过", systemImage: "checkmark")
                    .font(.spareCaption)
                    .foregroundColor(.green)
                if schema.validationsFailed > 0 {
                    Label("\(schema.validationsFailed) 失败", systemImage: "xmark")
                        .font(.spareCaption)
                        .foregroundColor(.red)
                }
            }

            // Pass rate bar
            let total = schema.validationsPassed + schema.validationsFailed
            let rate = total > 0 ? Double(schema.validationsPassed) / Double(total) : 1.0
            VStack(alignment: .leading, spacing: 2) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.systemGray5))
                            .frame(height: 6)
                        Capsule()
                            .fill(rate > 0.95 ? Color.green : (rate > 0.8 ? Color.orange : Color.red))
                            .frame(width: geo.size.width * rate, height: 6)
                    }
                }
                .frame(height: 6)
                Text(String(format: "%.1f%% 验证通过率", rate * 100))
                    .font(.spareMicro)
                    .foregroundColor(.gray)
            }
        }
        .padding(Spacing.md)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.md))
        .modifier(CardShadow())
    }

    // MARK: - Handlers Tab

    private var handlersSection: some View {
        VStack(spacing: Spacing.md) {
            FeedSectionHeader(title: "Pipeline Handler", subtitle: "\(store.handlers.filter(\.isActive).count) 个活跃")
                .padding(.horizontal, Spacing.lg)

            if store.handlers.isEmpty {
                EmptyStateView(icon: "gearshape.2",
                               title: "暂无 Handler",
                               message: "尚未注册任何管线处理器")
                    .padding(.horizontal, Spacing.lg)
            } else {
                ForEach(store.handlers) { handler in
                    handlerRow(handler)
                        .padding(.horizontal, Spacing.lg)
                }
            }
        }
    }

    private func handlerRow(_ handler: PipelineHandler) -> some View {
        HStack(spacing: Spacing.md) {
            // Type icon
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .fill(handler.isActive ? Color.spareYellow.opacity(0.15) : Color(.systemGray5))
                    .frame(width: 40, height: 40)
                Image(systemName: handler.handlerType.icon)
                    .font(.body)
                    .foregroundColor(handler.isActive ? .spareYellow : .gray)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(handler.name)
                    .font(.spareBodySB)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                HStack(spacing: Spacing.sm) {
                    PillTag(label: handler.handlerType.rawValue, color: .spareYellow)
                    if !handler.isActive {
                        PillTag(label: "停用", color: .gray, filled: true)
                    }
                }
            }

            Spacer()

            // Stats column
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(handler.processedCount)")
                    .font(.spareBodySB)
                    .foregroundColor(.primary)
                Text("\(handler.avgLatencyMs)ms · \(String(format: "%.1f%%", handler.errorRate * 100)) err")
                    .font(.spareMicro)
                    .foregroundColor(handler.errorRate > 0.01 ? .red : .secondary)
            }
        }
        .padding(Spacing.md)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.md))
        .modifier(CardShadow())
    }

    // MARK: - Helpers

    private func filterChip(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.spareCaptionSB)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(
                    Capsule().fill(selected ? Color.spareYellow : Color.chipUnselected)
                )
                .foregroundColor(selected ? Color.spareDark : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Adapter Detail Sheet

struct AdapterDetailSheet: View {
    let adapter: ChannelAdapter
    let events: [ChannelEvent]

    @Environment(\.dismiss) private var dismiss

    private var adapterEvents: [ChannelEvent] {
        events.filter { $0.adapterName == adapter.name }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    headerSection
                    statsGrid
                    recentEventsSection
                }
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xxxl)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(adapter.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private var headerSection: some View {
        HStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .fill(adapter.accentColor.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: adapter.icon)
                    .font(.title2)
                    .foregroundColor(adapter.accentColor)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Text(adapter.name)
                        .font(.spareTitle2)
                    Circle()
                        .fill(adapter.isEnabled ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    Text(adapter.isEnabled ? "运行中" : "已停用")
                        .font(.spareCaption)
                        .foregroundColor(adapter.isEnabled ? .green : .gray)
                }
                Text("最近活跃: ")
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
                + Text(adapter.lastActiveAt, style: .relative)
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: Spacing.md) {
            statCell(icon: "arrow.down.circle.fill", label: "传入", value: "\(adapter.inboundCount)", color: .blue)
            statCell(icon: "arrow.up.circle.fill", label: "传出", value: "\(adapter.outboundCount)", color: .purple)
            statCell(icon: "exclamationmark.triangle.fill", label: "异常", value: "\(adapter.errorCount)",
                     color: adapter.errorCount > 0 ? .red : .green)
            statCell(icon: "percent", label: "成功率",
                     value: String(format: "%.1f%%", successRate * 100), color: .green)
        }
        .padding(.horizontal, Spacing.lg)
    }

    private var successRate: Double {
        let total = adapter.inboundCount + adapter.outboundCount
        guard total > 0 else { return 1.0 }
        return Double(total - adapter.errorCount) / Double(total)
    }

    private func statCell(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.spareTitle3)
                .foregroundColor(.primary)
            Text(label)
                .font(.spareMicro)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.md))
        .modifier(CardShadow())
    }

    private var recentEventsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            FeedSectionHeader(title: "最近消息", subtitle: "\(adapterEvents.count) 条")
                .padding(.horizontal, Spacing.lg)

            if adapterEvents.isEmpty {
                EmptyStateView(icon: "tray",
                               title: "暂无记录",
                               message: "该渠道暂无最近消息事件")
                    .padding(.horizontal, Spacing.lg)
            } else {
                ForEach(adapterEvents) { event in
                    adapterEventRow(event)
                        .padding(.horizontal, Spacing.lg)
                }
            }
        }
    }

    private func adapterEventRow(_ event: ChannelEvent) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: event.direction.icon)
                .font(.body)
                .foregroundColor(event.direction.color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(event.eventType)
                        .font(.spareBodySB)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: event.status.icon)
                        .font(.caption)
                        .foregroundColor(event.status.color)
                }
                Text(event.payloadPreview)
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(Spacing.sm)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.sm))
    }
}

