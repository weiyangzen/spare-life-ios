// AIMemoryMatchingView.swift
// Spare Life – 底层 · AI 记忆与匹配能力 管理面板
// Blueprint §7 底层 · [UIUX] AI 记忆与匹配能力 (line:1157)
// UIUX lane – slot 2

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Models

struct AIMemoryEntry: Identifiable {
    let id: String
    let type: MemoryType
    let content: String
    let source: String
    let createdAt: Date
    let relevanceScore: Double
    let hasEmbedding: Bool

    enum MemoryType: String, CaseIterable, Identifiable {
        case conversation = "对话"
        case action       = "行动"
        case emotion      = "情绪"
        case preference   = "偏好"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .conversation: return "bubble.left.fill"
            case .action:       return "figure.walk"
            case .emotion:      return "heart.fill"
            case .preference:   return "star.fill"
            }
        }

        var color: Color {
            switch self {
            case .conversation: return .blue
            case .action:       return .orange
            case .emotion:      return .pink
            case .preference:   return .purple
            }
        }
    }
}

struct IntentMatch: Identifiable {
    let id: String
    let intentLabel: String
    let confidence: Double
    let matchedMemoryCount: Int
    let timestamp: Date
    let status: MatchStatus

    enum MatchStatus: String {
        case active   = "活跃"
        case resolved = "已处理"
        case expired  = "已过期"

        var color: Color {
            switch self {
            case .active:   return .green
            case .resolved: return .blue
            case .expired:  return .secondary
            }
        }
    }
}

struct PromptTemplate: Identifiable {
    let id: String
    let name: String
    let category: String
    let tokenEstimate: Int
    let lastUsed: Date?
    let usageCount: Int
}

enum AIMemoryLoadState {
    case idle, loading, loaded, error(String)
}

// MARK: - Store

@MainActor
final class AIMemoryMatchingStore: ObservableObject {
    @Published var loadState: AIMemoryLoadState = .idle
    @Published var memories: [AIMemoryEntry] = []
    @Published var recentMatches: [IntentMatch] = []
    @Published var promptTemplates: [PromptTemplate] = []
    @Published var selectedTab: Tab = .memories
    @Published var filterType: AIMemoryEntry.MemoryType? = nil
    @Published var totalRecallRequests: Int = 0
    @Published var avgRecallLatencyMs: Double = 0
    @Published var recallHitRate: Double = 0
    @Published var summaryCount: Int = 0

    enum Tab: String, CaseIterable {
        case memories  = "记忆库"
        case intent    = "意图引擎"
        case prompts   = "Prompt"
    }

    var filteredMemories: [AIMemoryEntry] {
        guard let type = filterType else { return memories }
        return memories.filter { $0.type == type }
    }

    func load() {
        guard case .idle = loadState else { return }
        loadState = .loading
        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            totalRecallRequests = 4560
            avgRecallLatencyMs = 23.4
            recallHitRate = 0.87
            summaryCount = 42

            memories = [
                .init(id: "mem1", type: .conversation, content: "用户与小明讨论了周末爬山的计划，提到膝盖不太好", source: "聊天:小明", createdAt: date(-0.5), relevanceScore: 0.92, hasEmbedding: true),
                .init(id: "mem2", type: .emotion, content: "用户在收到加薪通知后情绪积极，表达了对团队的感谢", source: "聊天:工作群", createdAt: date(-1), relevanceScore: 0.88, hasEmbedding: true),
                .init(id: "mem3", type: .action, content: "用户完成了「每日冥想 10 分钟」任务，连续 7 天", source: "成长任务", createdAt: date(-0.3), relevanceScore: 0.95, hasEmbedding: true),
                .init(id: "mem4", type: .preference, content: "用户偏好晚上 9 点后不接收消息通知", source: "设置", createdAt: date(-5), relevanceScore: 0.76, hasEmbedding: true),
                .init(id: "mem5", type: .conversation, content: "用户咨询了李大师关于职业规划的建议", source: "大师:李大师", createdAt: date(-2), relevanceScore: 0.84, hasEmbedding: true),
                .init(id: "mem6", type: .emotion, content: "用户对陌生社交匹配结果表达了期待", source: "赚闲能:匹配", createdAt: date(-0.8), relevanceScore: 0.79, hasEmbedding: true),
                .init(id: "mem7", type: .action, content: "用户在技能问答赛道发布了 Python 教学意图", source: "赚闲能:意图", createdAt: date(-3), relevanceScore: 0.91, hasEmbedding: true),
                .init(id: "mem8", type: .preference, content: "用户将分身面具设为「轻松幽默」风格", source: "分身设置", createdAt: date(-10), relevanceScore: 0.68, hasEmbedding: true),
                .init(id: "mem9", type: .conversation, content: "用户和张三在四人场聊天中讨论了旅行目的地", source: "四人场:张三", createdAt: date(-1.5), relevanceScore: 0.82, hasEmbedding: false),
                .init(id: "mem10", type: .action, content: "用户与小红完成了「共同目标:读完一本书」的羁绊任务", source: "羁绊:小红", createdAt: date(-4), relevanceScore: 0.86, hasEmbedding: true),
            ]

            recentMatches = [
                .init(id: "im1", intentLabel: "用户想找人讨论周末计划", confidence: 0.93, matchedMemoryCount: 3, timestamp: date(-0.01), status: .active),
                .init(id: "im2", intentLabel: "用户对职业发展感兴趣", confidence: 0.87, matchedMemoryCount: 2, timestamp: date(-0.1), status: .resolved),
                .init(id: "im3", intentLabel: "用户可能需要情绪支持", confidence: 0.72, matchedMemoryCount: 4, timestamp: date(-0.3), status: .resolved),
                .init(id: "im4", intentLabel: "用户偏好安静的社交风格", confidence: 0.81, matchedMemoryCount: 2, timestamp: date(-1), status: .expired),
            ]

            promptTemplates = [
                .init(id: "p1", name: "记忆摘要器",         category: "摘要", tokenEstimate: 340, lastUsed: date(-0.01), usageCount: 1820),
                .init(id: "p2", name: "意图识别器",         category: "意图", tokenEstimate: 280, lastUsed: date(-0.02), usageCount: 4560),
                .init(id: "p3", name: "情绪分析器",         category: "情绪", tokenEstimate: 220, lastUsed: date(-0.1),  usageCount: 890),
                .init(id: "p4", name: "匹配排序器",         category: "匹配", tokenEstimate: 410, lastUsed: date(-0.05), usageCount: 2340),
                .init(id: "p5", name: "关系温度计算器",     category: "关系", tokenEstimate: 180, lastUsed: date(-0.2),  usageCount: 560),
                .init(id: "p6", name: "分身回复装配器",     category: "回复", tokenEstimate: 520, lastUsed: date(-0.01), usageCount: 3100),
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

struct AIMemoryMatchingView: View {
    @StateObject private var store = AIMemoryMatchingStore()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                Group {
                    switch store.loadState {
                    case .idle, .loading:
                        AIMemorySkeleton()
                    case .loaded:
                        AIMemoryContent(store: store)
                    case .error(let msg):
                        ErrorStateView(message: msg, retry: { store.reload() })
                    }
                }
            }
            .navigationTitle("AI 记忆与匹配")
            .spareNavigationBarTitleDisplayMode(.large)
            .task { store.load() }
        }
    }
}

// MARK: - Content

private struct AIMemoryContent: View {
    @ObservedObject var store: AIMemoryMatchingStore

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                recallStatsRow
                tabPicker
                tabContent
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.xxxl + 32)
        }
        .refreshable { store.reload() }
    }

    // MARK: - Recall Stats

    private var recallStatsRow: some View {
        HStack(spacing: Spacing.sm) {
            RecallStatCard(label: "召回请求", value: "\(store.totalRecallRequests)", icon: "magnifyingglass", color: .blue)
            RecallStatCard(label: "命中率", value: String(format: "%.0f%%", store.recallHitRate * 100), icon: "target", color: .green)
            RecallStatCard(label: "延迟", value: String(format: "%.1fms", store.avgRecallLatencyMs), icon: "timer", color: .orange)
            RecallStatCard(label: "摘要", value: "\(store.summaryCount)", icon: "doc.text.fill", color: .purple)
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(AIMemoryMatchingStore.Tab.allCases, id: \.self) { tab in
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

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch store.selectedTab {
        case .memories:
            MemoriesTab(store: store)
        case .intent:
            IntentTab(matches: store.recentMatches)
        case .prompts:
            PromptsTab(templates: store.promptTemplates)
        }
    }
}

// MARK: - Recall Stat Card

private struct RecallStatCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text(value)
                .font(.spareCaptionSB)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.spareMicro)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
    }
}

// MARK: - Memories Tab

private struct MemoriesTab: View {
    @ObservedObject var store: AIMemoryMatchingStore

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Type filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    FilterChip(label: "全部", isSelected: store.filterType == nil) {
                        withAnimation(.spareEase) { store.filterType = nil }
                    }
                    ForEach(AIMemoryEntry.MemoryType.allCases) { type in
                        FilterChip(
                            label: type.rawValue,
                            icon: type.icon,
                            color: type.color,
                            isSelected: store.filterType == type
                        ) {
                            withAnimation(.spareEase) { store.filterType = type }
                        }
                    }
                }
            }

            if store.filteredMemories.isEmpty {
                EmptyStateView(
                    icon: "brain",
                    title: "暂无记忆",
                    message: "当分身与你互动后，记忆会自动积累。"
                )
                .frame(minHeight: 200)
            } else {
                ForEach(store.filteredMemories) { memory in
                    AIMemoryEntryRow(memory: memory)
                }
            }
        }
    }
}

private struct FilterChip: View {
    let label: String
    var icon: String? = nil
    var color: Color = .spareYellow
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.xs) {
                if let icon { Image(systemName: icon).font(.spareMicro) }
                Text(label).font(.spareCaptionSB)
            }
            .foregroundColor(isSelected ? .black : .secondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                isSelected ? color.opacity(0.9) : Color(.secondarySystemGroupedBackground),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }
}

private struct AIMemoryEntryRow: View {
    let memory: AIMemoryEntry

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: memory.type.icon)
                .foregroundColor(memory.type.color)
                .font(.system(size: 16))
                .frame(width: 28, height: 28)
                .background(memory.type.color.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text(memory.content)
                        .font(.spareCaption)
                        .lineLimit(3)
                    Spacer(minLength: 4)
                }

                HStack(spacing: Spacing.md) {
                    Label(memory.source, systemImage: "tag")
                    Label(String(format: "%.0f%%", memory.relevanceScore * 100), systemImage: "scope")
                    if memory.hasEmbedding {
                        Image(systemName: "cube.fill")
                            .foregroundColor(.purple)
                    }
                    Spacer()
                    Text(memory.createdAt, style: .relative)
                }
                .font(.spareMicro)
                .foregroundColor(.secondary)
            }
        }
        .padding(Spacing.md)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
    }
}

// MARK: - Intent Tab

private struct IntentTab: View {
    let matches: [IntentMatch]

    var body: some View {
        VStack(spacing: Spacing.md) {
            if matches.isEmpty {
                EmptyStateView(
                    icon: "sparkle.magnifyingglass",
                    title: "暂无意图匹配",
                    message: "意图引擎会在你使用 App 时自动识别需求。"
                )
                .frame(minHeight: 200)
            } else {
                ForEach(matches) { match in
                    IntentMatchRow(match: match)
                }
            }
        }
    }
}

private struct IntentMatchRow: View {
    let match: IntentMatch

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.spareYellow)
                Text(match.intentLabel)
                    .font(.spareCaption)
                    .lineLimit(2)
                Spacer()
                PillTag(label: match.status.rawValue, color: match.status.color, filled: match.status == .active)
            }

            HStack(spacing: Spacing.lg) {
                // Confidence bar
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("置信度").font(.spareMicro).foregroundColor(.secondary)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(Color(.systemGray5)).frame(height: 6)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(confidenceColor)
                                .frame(width: match.confidence * geo.size.width, height: 6)
                        }
                    }
                    .frame(height: 6)
                    Text(String(format: "%.0f%%", match.confidence * 100))
                        .font(.spareMicro)
                        .foregroundColor(confidenceColor)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .center, spacing: Spacing.xxs) {
                    Text("关联记忆").font(.spareMicro).foregroundColor(.secondary)
                    Text("\(match.matchedMemoryCount)")
                        .font(.spareBodySB)
                        .foregroundColor(.purple)
                }
                .frame(width: 60)
            }

            Text(match.timestamp, style: .relative)
                .font(.spareMicro)
                .foregroundColor(.secondary)
        }
        .padding(Spacing.md)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
    }

    private var confidenceColor: Color {
        if match.confidence >= 0.85 { return .green }
        if match.confidence >= 0.6  { return .orange }
        return .red
    }
}

// MARK: - Prompts Tab

private struct PromptsTab: View {
    let templates: [PromptTemplate]

    var body: some View {
        VStack(spacing: Spacing.md) {
            if templates.isEmpty {
                EmptyStateView(
                    icon: "text.badge.star",
                    title: "暂无 Prompt 模板",
                    message: "系统内置的 Prompt 模板会在此显示。"
                )
                .frame(minHeight: 200)
            } else {
                ForEach(templates) { template in
                    PromptTemplateRow(template: template)
                }
            }
        }
    }
}

private struct PromptTemplateRow: View {
    let template: PromptTemplate

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "text.badge.star")
                .foregroundColor(.spareYellow)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text(template.name).font(.spareCaption)
                    Spacer()
                    PillTag(label: template.category, color: .blue, filled: false)
                }
                HStack(spacing: Spacing.lg) {
                    Label("~\(template.tokenEstimate) tokens", systemImage: "number.square")
                    Label("\(template.usageCount) 次", systemImage: "arrow.counterclockwise")
                    Spacer()
                    if let lastUsed = template.lastUsed {
                        Text(lastUsed, style: .relative)
                    }
                }
                .font(.spareMicro)
                .foregroundColor(.secondary)
            }
        }
        .padding(Spacing.md)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
    }
}

// MARK: - Skeleton

private struct AIMemorySkeleton: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            HStack(spacing: Spacing.sm) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .fill(Color(.systemGray5)).frame(height: 64).shimmer()
                }
            }
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(Color(.systemGray5)).frame(height: 40).shimmer()
            ForEach(0..<5, id: \.self) { _ in
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(Color(.systemGray5)).frame(height: 80).shimmer()
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg)
    }
}

#if DEBUG
#Preview {
    AIMemoryMatchingView()
}
#endif
