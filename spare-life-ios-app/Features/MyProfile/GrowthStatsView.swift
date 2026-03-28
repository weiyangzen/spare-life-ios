// GrowthStatsView.swift
// Spare Life – 我的 · 数据统计与成长回顾
// Blueprint §7 我的 · [UIUX] 数据统计与成长回顾 (id: af9ec29fce80)
// UIUX lane – slot 2

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Models

struct GrowthStats {
    var energyHistory: [DataPoint]
    var socialHistory: [DataPoint]
    var syncHistory: [DataPoint]
    var growthDiary: [DiaryEntry]
    var totals: Totals

    struct DataPoint: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
    }

    struct Totals {
        let totalEnergy: Int
        let socialConnections: Int
        let peakSyncScore: Int
        let daysActive: Int
    }

    struct DiaryEntry: Identifiable {
        let id: String
        let date: Date
        let title: String
        let body: String
        let highlights: [String]
        let energyDelta: Int
        let syncDelta: Int
    }
}

enum StatsRange: String, CaseIterable {
    case week  = "近7天"
    case month = "近30天"
    case all   = "全部"
}

enum StatsLoadState {
    case idle, loading, loaded, error(String)
}

// MARK: - Store

@MainActor
final class GrowthStatsStore: ObservableObject {
    @Published var loadState: StatsLoadState = .idle
    @Published var stats: GrowthStats? = nil
    @Published var selectedRange: StatsRange = .month
    @Published var activeMetric: Metric = .energy

    enum Metric: String, CaseIterable {
        case energy = "闲能"
        case social = "社交"
        case sync   = "同步度"

        var color: Color {
            switch self {
            case .energy: return .spareYellow
            case .social: return .blue
            case .sync:   return .green
            }
        }

        var icon: String {
            switch self {
            case .energy: return "bolt.circle.fill"
            case .social: return "person.2.fill"
            case .sync:   return "arrow.triangle.2.circlepath"
            }
        }
    }

    var activeHistory: [GrowthStats.DataPoint] {
        guard let stats else { return [] }
        switch activeMetric {
        case .energy: return stats.energyHistory
        case .social: return stats.socialHistory
        case .sync:   return stats.syncHistory
        }
    }

    func load() {
        guard case .idle = loadState else { return }
        loadState = .loading
        Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            stats = GrowthStats(
                energyHistory: [
                    .init(label: "3/1",  value: 200),  .init(label: "3/5",  value: 340),
                    .init(label: "3/10", value: 520),  .init(label: "3/15", value: 480),
                    .init(label: "3/20", value: 710),  .init(label: "3/25", value: 950),
                    .init(label: "3/26", value: 1240),
                ],
                socialHistory: [
                    .init(label: "3/1",  value: 5),  .init(label: "3/5",  value: 12),
                    .init(label: "3/10", value: 18), .init(label: "3/15", value: 25),
                    .init(label: "3/20", value: 31), .init(label: "3/25", value: 38),
                    .init(label: "3/26", value: 44),
                ],
                syncHistory: [
                    .init(label: "3/1",  value: 48), .init(label: "3/5",  value: 55),
                    .init(label: "3/10", value: 61), .init(label: "3/15", value: 65),
                    .init(label: "3/20", value: 69), .init(label: "3/25", value: 72),
                    .init(label: "3/26", value: 73),
                ],
                growthDiary: [
                    .init(id: "d1", date: Date().addingTimeInterval(-86400), title: "破冰成功率新高", body: "这周通过分身发起的陌生社交破冰，成功建立稳定聊天的比例达到 62%，比上月提升 18 个百分点。", highlights: ["破冰成功率 62%", "新增联系人 6 位"], energyDelta: 120, syncDelta: 1),
                    .init(id: "d2", date: Date().addingTimeInterval(-86400 * 5), title: "人格训练里程碑", body: "完成了价值观维度的全套训练任务，觉醒度升至 Lv.4，分身在情绪场景的判断准确性提升明显。", highlights: ["觉醒 Lv.3→4", "情绪识别 +12%"], energyDelta: 200, syncDelta: 4),
                    .init(id: "d3", date: Date().addingTimeInterval(-86400 * 14), title: "首次完成群聊场景", body: "参与了一场 4 人群聊，分身在协调角色切换和总结共识方面表现流畅，未出现角色混淆。", highlights: ["群聊完成", "无角色混淆"], energyDelta: 80, syncDelta: 2),
                ],
                totals: .init(
                    totalEnergy: 2_480,
                    socialConnections: 44,
                    peakSyncScore: 73,
                    daysActive: 26
                )
            )
            loadState = .loaded
        }
    }

    func reload() { loadState = .idle; load() }
}

// MARK: - Root View

struct GrowthStatsView: View {
    @StateObject private var store = GrowthStatsStore()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                contentBody
            }
            .navigationTitle("成长统计")
            .spareNavigationBarTitleDisplayMode(.large)
        }
        .task { store.load() }
    }

    @ViewBuilder
    private var contentBody: some View {
        switch store.loadState {
        case .idle, .loading:
            StatsSkeletonView()
        case .loaded:
            if let stats = store.stats {
                StatsScrollView(store: store, stats: stats)
            }
        case .error(let msg):
            ErrorStateView(message: msg, retry: { store.reload() })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Scroll View

private struct StatsScrollView: View {
    @ObservedObject var store: GrowthStatsStore
    let stats: GrowthStats

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                // Totals row
                TotalsRow(totals: stats.totals)
                    .padding(.horizontal, Spacing.lg)

                // Metric selector
                MetricSelector(store: store)
                    .padding(.horizontal, Spacing.lg)

                // Time range selector
                TimeRangeSelector(selectedRange: $store.selectedRange)
                    .padding(.horizontal, Spacing.lg)

                // Chart
                LineChartCard(
                    dataPoints: store.activeHistory,
                    metric: store.activeMetric
                )
                .padding(.horizontal, Spacing.lg)

                // Growth diary
                DiarySection(entries: stats.growthDiary)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.xxxl + 32)
            }
            .padding(.top, Spacing.lg)
        }
        .refreshable { store.reload() }
    }
}

// MARK: - Totals Row

private struct TotalsRow: View {
    let totals: GrowthStats.Totals

    var body: some View {
        HStack(spacing: Spacing.sm) {
            TotalTile(icon: "bolt.circle.fill",  color: .spareYellow, value: "\(totals.totalEnergy)",       label: "累计闲能")
            TotalTile(icon: "person.2.fill",      color: .blue,        value: "\(totals.socialConnections)", label: "社交连接")
            TotalTile(icon: "arrow.triangle.2.circlepath", color: .green, value: "\(totals.peakSyncScore)", label: "最高同步")
            TotalTile(icon: "calendar.badge.checkmark", color: .purple, value: "\(totals.daysActive)",      label: "活跃天数")
        }
    }
}

private struct TotalTile: View {
    let icon: String
    let color: Color
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: icon).font(.system(size: 18)).foregroundColor(color)
            Text(value).font(.spareTitle3)
            Text(label).font(.spareMicro).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
        .cardShadow()
    }
}

// MARK: - Metric Selector

private struct MetricSelector: View {
    @ObservedObject var store: GrowthStatsStore

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(GrowthStatsStore.Metric.allCases, id: \.self) { metric in
                Button {
                    withAnimation(.spareEase) { store.activeMetric = metric }
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: metric.icon)
                            .font(.spareMicro)
                        Text(metric.rawValue)
                            .font(.spareCaptionSB)
                    }
                    .foregroundColor(store.activeMetric == metric ? .white : metric.color)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        store.activeMetric == metric ? metric.color : metric.color.opacity(0.12),
                        in: Capsule()
                    )
                }
            }
            Spacer()
        }
    }
}

// MARK: - Time Range Selector

private struct TimeRangeSelector: View {
    @Binding var selectedRange: StatsRange

    var body: some View {
        HStack(spacing: 0) {
            ForEach(StatsRange.allCases, id: \.self) { range in
                Button {
                    withAnimation(.spareEase) { selectedRange = range }
                } label: {
                    Text(range.rawValue)
                        .font(selectedRange == range ? .spareCaptionSB : .spareCaption)
                        .foregroundColor(selectedRange == range ? .black : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            selectedRange == range
                                ? Color(.secondarySystemGroupedBackground)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: CornerRadius.sm)
                        )
                }
            }
        }
        .padding(3)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
    }
}

// MARK: - Line Chart Card

private struct LineChartCard: View {
    let dataPoints: [GrowthStats.DataPoint]
    let metric: GrowthStatsStore.Metric

    @State private var appeared = false

    private var maxValue: Double { dataPoints.map(\.value).max() ?? 1 }
    private var minValue: Double { dataPoints.map(\.value).min() ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: metric.icon).foregroundColor(metric.color)
                Text("\(metric.rawValue)趋势")
                    .font(.spareBodySB)
                Spacer()
                if let last = dataPoints.last {
                    Text(formattedValue(last.value))
                        .font(.spareTitle3)
                        .foregroundColor(metric.color)
                }
            }

            // Chart canvas
            GeometryReader { geo in
                ZStack(alignment: .bottomLeading) {
                    // Grid lines
                    VStack(spacing: 0) {
                        ForEach(0..<4) { i in
                            Divider()
                                .opacity(0.4)
                            if i < 3 { Spacer() }
                        }
                    }

                    // Area fill
                    if dataPoints.count > 1 {
                        areaPath(in: geo.size)
                            .fill(metric.color.opacity(0.12))
                            .opacity(appeared ? 1 : 0)
                            .animation(.easeInOut(duration: 0.5), value: appeared)

                        // Line
                        linePath(in: geo.size)
                            .trim(from: 0, to: appeared ? 1 : 0)
                            .stroke(metric.color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                            .animation(.easeOut(duration: 0.9), value: appeared)

                        // Data dots
                        ForEach(Array(dataPoints.enumerated()), id: \.offset) { idx, pt in
                            Circle()
                                .fill(metric.color)
                                .frame(width: 6, height: 6)
                                .position(position(for: pt, at: idx, size: geo.size))
                                .opacity(appeared ? 1 : 0)
                                .animation(.easeOut(duration: 0.4).delay(Double(idx) * 0.08), value: appeared)
                        }
                    }
                }
                .onAppear { appeared = true }
            }
            .frame(height: 120)

            // X-axis labels
            HStack(spacing: 0) {
                ForEach(Array(dataPoints.enumerated()), id: \.offset) { _, pt in
                    Text(pt.label)
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(Spacing.lg)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .cardShadow()
    }

    private func normY(_ value: Double, height: CGFloat) -> CGFloat {
        let range = maxValue - minValue
        guard range > 0 else { return height / 2 }
        return height - CGFloat((value - minValue) / range) * (height - 12) - 6
    }

    private func normX(_ index: Int, width: CGFloat) -> CGFloat {
        guard dataPoints.count > 1 else { return width / 2 }
        return CGFloat(index) / CGFloat(dataPoints.count - 1) * width
    }

    private func position(for pt: GrowthStats.DataPoint, at idx: Int, size: CGSize) -> CGPoint {
        CGPoint(x: normX(idx, width: size.width), y: normY(pt.value, height: size.height))
    }

    private func linePath(in size: CGSize) -> Path {
        var path = Path()
        for (idx, pt) in dataPoints.enumerated() {
            let p = position(for: pt, at: idx, size: size)
            if idx == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        return path
    }

    private func areaPath(in size: CGSize) -> Path {
        var path = linePath(in: size)
        if let last = dataPoints.indices.last {
            path.addLine(to: CGPoint(x: normX(last, width: size.width), y: size.height))
        }
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        return path
    }

    private func formattedValue(_ v: Double) -> String {
        if v >= 1000 { return String(format: "%.1fk", v / 1000) }
        return String(Int(v))
    }
}

// MARK: - Growth Diary

private struct DiarySection: View {
    let entries: [GrowthStats.DiaryEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "book.fill").foregroundColor(.purple)
                Text("成长日记").font(.spareBodySB)
                Spacer()
            }

            if entries.isEmpty {
                EmptyStateView(icon: "book", title: "还没有日记", message: "完成成就后会自动生成成长日记。")
            } else {
                ForEach(entries) { entry in
                    DiaryEntryCard(entry: entry)
                }
            }
        }
    }
}

private struct DiaryEntryCard: View {
    let entry: GrowthStats.DiaryEntry
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(entry.title).font(.spareBodySB)
                    Text(entry.date, style: .date)
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: Spacing.sm) {
                    DeltaBadge(icon: "bolt.fill", color: .spareYellow, delta: entry.energyDelta)
                    DeltaBadge(icon: "arrow.triangle.2.circlepath", color: .green, delta: entry.syncDelta)
                }
            }

            if expanded {
                Text(entry.body)
                    .font(.spareCaption)
                    .foregroundColor(.secondary)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 100), spacing: Spacing.sm)],
                    alignment: .leading,
                    spacing: Spacing.sm
                ) {
                    ForEach(entry.highlights, id: \.self) { h in
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.spareMicro)
                            Text(h).font(.spareMicro)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Button {
                withAnimation(.spareSpring) { expanded.toggle() }
            } label: {
                HStack {
                    Text(expanded ? "收起" : "展开详情")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(Spacing.md)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
        .cardShadow()
    }
}

private struct DeltaBadge: View {
    let icon: String
    let color: Color
    let delta: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.spareMicro)
            Text("+\(delta)").font(.spareMicro)
        }
        .foregroundColor(color)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(color.opacity(0.10), in: Capsule())
    }
}

// MARK: - Skeleton

private struct StatsSkeletonView: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            HStack(spacing: Spacing.sm) {
                ForEach(0..<4) { _ in
                    RoundedRectangle(cornerRadius: CornerRadius.md).fill(Color(.systemGray5)).frame(height: 72).shimmer()
                }
            }
            RoundedRectangle(cornerRadius: CornerRadius.md).fill(Color(.systemGray5)).frame(height: 40).shimmer()
            RoundedRectangle(cornerRadius: CornerRadius.lg).fill(Color(.systemGray5)).frame(height: 200).shimmer()
            ForEach(0..<2) { _ in
                RoundedRectangle(cornerRadius: CornerRadius.md).fill(Color(.systemGray5)).frame(height: 80).shimmer()
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg)
    }
}

#if DEBUG
#Preview {
    GrowthStatsView()
}
#endif
