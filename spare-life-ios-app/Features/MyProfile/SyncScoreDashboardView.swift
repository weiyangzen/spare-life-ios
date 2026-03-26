// SyncScoreDashboardView.swift
// Spare Life – 我的 · 分身同步度仪表盘
// Blueprint §7 我的 · [UIUX] 分身同步度仪表盘 (id: 494b73befc1e)
// UIUX lane – slot 2

import SwiftUI

// MARK: - Models

struct SyncScore {
    /// 0-100
    var overall: Int
    var dimensions: [Dimension]

    struct Dimension: Identifiable {
        var id: String { name }
        let name: String
        let score: Int          // 0-100
        let icon: String
        let color: Color
    }
}

struct TrainingTask: Identifiable {
    let id: String
    let title: String
    let description: String
    let reward: Int
    var status: Status
    let priority: Priority

    enum Status: String {
        case pending   = "待完成"
        case inReview  = "审核中"
        case done      = "已完成"
    }
    enum Priority: String {
        case high   = "高"
        case medium = "中"
        case low    = "低"
    }
}

struct ErrorReplay: Identifiable {
    let id: String
    let scenario: String
    let expectedResponse: String
    let actualResponse: String
    let timestamp: Date
    let impactDelta: Int   // negative = regression
}

enum SyncLoadState {
    case idle, loading, loaded, error(String)
}

// MARK: - Store

@MainActor
final class SyncScoreStore: ObservableObject {
    @Published var loadState: SyncLoadState = .idle
    @Published var syncScore: SyncScore? = nil
    @Published var trainingTasks: [TrainingTask] = []
    @Published var errorReplays: [ErrorReplay] = []
    @Published var selectedTab: Tab = .overview

    enum Tab: String, CaseIterable {
        case overview  = "概览"
        case training  = "训练任务"
        case replays   = "错误回放"
    }

    func load() {
        guard case .idle = loadState else { return }
        loadState = .loading
        Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            syncScore = SyncScore(
                overall: 73,
                dimensions: [
                    .init(name: "语言风格", score: 81, icon: "text.bubble.fill",     color: .blue),
                    .init(name: "价值观",   score: 68, icon: "heart.circle.fill",     color: .pink),
                    .init(name: "决策模式", score: 74, icon: "arrow.triangle.branch", color: .orange),
                    .init(name: "情绪反应", score: 65, icon: "bolt.heart.fill",        color: .yellow),
                    .init(name: "知识领域", score: 79, icon: "book.fill",              color: .green),
                ]
            )
            trainingTasks = [
                .init(id: "t1", title: "完善价值观选择题", description: "回答 10 道偏好情景题，帮分身理解你的道德优先序。", reward: 50, status: .pending, priority: .high),
                .init(id: "t2", title: "纠正情绪回应样本", description: "标注 3 条分身给出的情绪回应，指出你更期待的回应方式。", reward: 30, status: .pending, priority: .high),
                .init(id: "t3", title: "补充兴趣领域知识", description: "上传或粘贴你最近关注的 3 篇文章。", reward: 20, status: .inReview, priority: .medium),
                .init(id: "t4", title: "审阅决策模拟场景", description: "浏览分身上周的 5 次代理决策，标出你不认同的。", reward: 40, status: .done, priority: .medium),
            ]
            errorReplays = [
                .init(id: "e1", scenario: "朋友约出来聊失恋", expectedResponse: "先倾听，再共情，不急于给建议", actualResponse: "立即给出了 3 条分手疗愈步骤", timestamp: Date().addingTimeInterval(-3600), impactDelta: -4),
                .init(id: "e2", scenario: "陌生人请求职业建议", expectedResponse: "谦虚声明局限性", actualResponse: "以专家口吻直接给建议", timestamp: Date().addingTimeInterval(-86400), impactDelta: -2),
            ]
            loadState = .loaded
        }
    }

    func reload() { loadState = .idle; load() }
}

// MARK: - Root View

struct SyncScoreDashboardView: View {
    @StateObject private var store = SyncScoreStore()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                contentBody
            }
            .navigationTitle("同步度仪表盘")
            .navigationBarTitleDisplayMode(.large)
        }
        .task { store.load() }
    }

    @ViewBuilder
    private var contentBody: some View {
        switch store.loadState {
        case .idle, .loading:
            SyncScoreSkeletonView()
        case .loaded:
            SyncScrollView(store: store)
        case .error(let msg):
            ErrorStateView(message: msg, retry: { store.reload() })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Loaded Scroll View

private struct SyncScrollView: View {
    @ObservedObject var store: SyncScoreStore

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                if let score = store.syncScore {
                    SyncGaugeCard(score: score)
                        .padding(.horizontal, Spacing.lg)
                }

                tabPicker
                    .padding(.horizontal, Spacing.lg)

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
            ForEach(SyncScoreStore.Tab.allCases, id: \.self) { tab in
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
        case .overview:
            if let score = store.syncScore {
                DimensionsGrid(dimensions: score.dimensions)
            }
        case .training:
            if store.trainingTasks.isEmpty {
                EmptyStateView(icon: "checkmark.circle", title: "训练任务已全部完成", message: "赶快去体验你的分身吧！")
            } else {
                TrainingTasksList(tasks: store.trainingTasks)
            }
        case .replays:
            if store.errorReplays.isEmpty {
                EmptyStateView(icon: "checkmark.shield", title: "暂无错误回放", message: "你的分身最近表现不错！")
            } else {
                ErrorReplayList(replays: store.errorReplays)
            }
        }
    }
}

// MARK: - Sync Gauge Card

private struct SyncGaugeCard: View {
    let score: SyncScore
    @State private var animatedScore: CGFloat = 0

    var body: some View {
        VStack(spacing: Spacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("综合同步度")
                        .font(.spareBodySB)
                    Text("分身与你的相似程度评估")
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                scoreRing
            }

            // Score interpretation
            ScoreInterpretationBanner(score: score.overall)
        }
        .padding(Spacing.lg)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .cardShadow()
        .onAppear {
            withAnimation(.spring(response: 1.2, dampingFraction: 0.75)) {
                animatedScore = CGFloat(score.overall) / 100
            }
        }
    }

    private var scoreRing: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 10)
                .frame(width: 90, height: 90)

            Circle()
                .trim(from: 0, to: animatedScore)
                .stroke(
                    score.overall >= 80 ? Color.green : score.overall >= 60 ? Color.spareYellow : Color.orange,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 90, height: 90)

            VStack(spacing: 0) {
                Text("\(score.overall)")
                    .font(.spareTitle2)
                Text("分")
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct ScoreInterpretationBanner: View {
    let score: Int

    private var interpretation: (icon: String, label: String, color: Color) {
        switch score {
        case 85...:   return ("star.fill",             "非常接近我本人",   .green)
        case 70..<85: return ("checkmark.circle.fill", "大部分时间像我",   .blue)
        case 55..<70: return ("exclamationmark.circle", "偶尔判断有偏差",  .orange)
        default:      return ("xmark.circle",          "差异较大，需训练", .red)
        }
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: interpretation.icon)
                .foregroundColor(interpretation.color)
            Text(interpretation.label)
                .font(.spareCaption)
                .foregroundColor(interpretation.color)
            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(interpretation.color.opacity(0.10), in: RoundedRectangle(cornerRadius: CornerRadius.sm))
    }
}

// MARK: - Dimensions Grid

private struct DimensionsGrid: View {
    let dimensions: [SyncScore.Dimension]

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(dimensions) { dim in
                DimensionRow(dimension: dim)
            }
        }
    }
}

private struct DimensionRow: View {
    let dimension: SyncScore.Dimension
    @State private var animatedWidth: CGFloat = 0

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: dimension.icon)
                .foregroundColor(dimension.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(dimension.name)
                        .font(.spareCaption)
                    Spacer()
                    Text("\(dimension.score)")
                        .font(.spareCaptionSB)
                        .foregroundColor(dimension.color)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(.systemGray5))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(dimension.color)
                            .frame(width: animatedWidth * geo.size.width, height: 6)
                    }
                    .onAppear {
                        withAnimation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.1)) {
                            animatedWidth = CGFloat(dimension.score) / 100
                        }
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(Spacing.md)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
    }
}

// MARK: - Training Tasks

private struct TrainingTasksList: View {
    let tasks: [TrainingTask]

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(tasks) { task in
                TrainingTaskRow(task: task)
            }
        }
    }
}

private struct TrainingTaskRow: View {
    let task: TrainingTask
    @State private var expanded = false

    var statusColor: Color {
        switch task.status {
        case .pending:  return .orange
        case .inReview: return .blue
        case .done:     return .green
        }
    }

    var priorityColor: Color {
        switch task.priority {
        case .high:   return .red
        case .medium: return .orange
        case .low:    return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(task.title)
                        .font(.spareBodySB)
                    HStack(spacing: Spacing.xs) {
                        PillTag(label: task.status.rawValue, color: statusColor)
                        PillTag(label: "优先级:\(task.priority.rawValue)", color: priorityColor)
                        HStack(spacing: 3) {
                            Image(systemName: "bolt.fill")
                                .font(.spareMicro)
                            Text("+\(task.reward)")
                                .font(.spareMicro)
                        }
                        .foregroundColor(.spareYellow)
                    }
                }
                Spacer()
                Button {
                    withAnimation(.spareSpring) { expanded.toggle() }
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }

            if expanded {
                Text(task.description)
                    .font(.spareCaption)
                    .foregroundColor(.secondary)

                if task.status == .pending {
                    Button {
                        // In production: navigate to task detail
                    } label: {
                        Text("开始任务")
                            .font(.spareCaptionSB)
                            .foregroundColor(.white)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.sm)
                            .background(Color.spareYellow, in: Capsule())
                            .foregroundColor(.black)
                    }
                }
            }
        }
        .padding(Spacing.md)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
        .cardShadow()
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(task.status == .pending ? priorityColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Error Replays

private struct ErrorReplayList: View {
    let replays: [ErrorReplay]

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(replays) { replay in
                ErrorReplayRow(replay: replay)
            }
        }
    }
}

private struct ErrorReplayRow: View {
    let replay: ErrorReplay
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(replay.scenario)
                        .font(.spareBodySB)
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.emotionNegative)
                        Text("同步度 \(replay.impactDelta)")
                            .font(.spareCaptionSB)
                            .foregroundColor(.emotionNegative)
                        Text(replay.timestamp, style: .relative)
                            .font(.spareMicro)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button {
                    withAnimation(.spareSpring) { expanded.toggle() }
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }

            if expanded {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    ComparisonRow(label: "期望回应", text: replay.expectedResponse, color: .green)
                    ComparisonRow(label: "实际回应", text: replay.actualResponse,   color: .emotionNegative)
                }
                .padding(Spacing.sm)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.sm))
            }
        }
        .padding(Spacing.md)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
        .cardShadow()
    }
}

private struct ComparisonRow: View {
    let label: String
    let text: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Text(label)
                .font(.spareMicro)
                .foregroundColor(color)
                .frame(width: 55, alignment: .leading)
            Text(text)
                .font(.spareCaption)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Skeleton

private struct SyncScoreSkeletonView: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(Color(.systemGray5))
                .frame(height: 160)
                .shimmer()

            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(Color(.systemGray5))
                .frame(height: 40)
                .shimmer()

            ForEach(0..<4) { _ in
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(Color(.systemGray5))
                    .frame(height: 56)
                    .shimmer()
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg)
    }
}

#if DEBUG
#Preview {
    SyncScoreDashboardView()
}
#endif
