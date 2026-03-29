// AwakeningPersonalityView.swift
// Spare Life – 我的 · 觉醒度与人格配置
// Blueprint §7 我的 · [UIUX] 觉醒度与人格配置 (id: 5e40d5381d2a)
// UIUX lane – slot 2

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Models

struct AwakeningModel {
    var level: Int          // 1-10
    var currentXP: Int
    var nextLevelXP: Int
    var title: String
    var description: String
    var unlockedFeatures: [String]

    var progressFraction: Double {
        guard nextLevelXP > 0 else { return 1.0 }
        return Double(currentXP) / Double(nextLevelXP)
    }
}

struct MBTIProfile {
    let typeCode: String
    let archetypeName: String
    let summary: String
    let dimensions: [Dimension]
    let strengths: [String]
    let guideItems: [GuideItem]

    struct Dimension: Identifiable {
        let id: String
        let title: String
        let pair: String
        let preferredLetter: String
        let preferredLabel: String
        let score: Int
        let detail: String
        let color: Color
    }

    struct GuideItem: Identifiable {
        let id: String
        let icon: String
        let title: String
        let detail: String
    }
}

struct PersonaMask: Identifiable {
    let id: String
    var name: String
    var description: String
    var isActive: Bool
    var traits: [String]
    let createdAt: Date
}

enum AwakeningLoadState {
    case idle, loading, loaded, error(String)
}

// MARK: - Store

@MainActor
final class AwakeningPersonalityStore: ObservableObject {
    @Published var loadState: AwakeningLoadState = .idle
    @Published var awakening: AwakeningModel? = nil
    @Published var mbtiProfile: MBTIProfile? = nil
    @Published var masks: [PersonaMask] = []
    @Published var selectedTab: Tab = .awakening
    @Published var editingMask: PersonaMask? = nil
    @Published var showAddMask = false

    enum Tab: String, CaseIterable {
        case awakening  = "觉醒度"
        case dna        = "MBTI"
        case masks      = "面具"
    }

    func load() {
        guard case .idle = loadState else { return }
        loadState = .loading
        Task {
            try? await Task.sleep(nanoseconds: 650_000_000)
            awakening = AwakeningModel(
                level: 4,
                currentXP: 340,
                nextLevelXP: 500,
                title: "初醒者",
                description: "分身已掌握你的基础语言风格与常见价值偏好，可以应对日常陌生社交场景。",
                unlockedFeatures: ["基础代理回复", "语言风格匹配", "简单情绪感知", "陌生社交破冰"]
            )
            mbtiProfile = MBTIProfile(
                typeCode: "INTP",
                archetypeName: "逻辑学家",
                summary: "先理解原理，再决定是否行动。比起热闹和即时表态，更偏好独立思考、抽象建模和在脑中推演多个可能性。",
                dimensions: [
                    .init(
                        id: "ei",
                        title: "能量来源",
                        pair: "E / I",
                        preferredLetter: "I",
                        preferredLabel: "独处充电",
                        score: 72,
                        detail: "长时间社交会快速掉电，更适合先独立思考，再进入对话。",
                        color: .spareYellow
                    ),
                    .init(
                        id: "sn",
                        title: "信息偏好",
                        pair: "S / N",
                        preferredLetter: "N",
                        preferredLabel: "抽象模式",
                        score: 68,
                        detail: "会自然去寻找原理、结构和长期趋势，而不是只停留在事实表层。",
                        color: .spareYellowInk
                    ),
                    .init(
                        id: "tf",
                        title: "决策方式",
                        pair: "T / F",
                        preferredLetter: "T",
                        preferredLabel: "逻辑优先",
                        score: 64,
                        detail: "先判断结论是否自洽、有没有漏洞，再考虑关系和感受层的表达。",
                        color: .spareOrange
                    ),
                    .init(
                        id: "jp",
                        title: "生活节奏",
                        pair: "J / P",
                        preferredLetter: "P",
                        preferredLabel: "保留弹性",
                        score: 70,
                        detail: "不喜欢被过早锁死方案，更倾向先探索，再逐步收束行动。",
                        color: .spareYellow
                    )
                ],
                strengths: ["独立思考", "抽象推理", "系统建模", "长期兴趣驱动"],
                guideItems: [
                    .init(
                        id: "guide-comm",
                        icon: "message.badge.fill",
                        title: "沟通方式",
                        detail: "先给问题背景和讨论目标，再进入交流。比起纯寒暄，更适合从一个明确主题切入。"
                    ),
                    .init(
                        id: "guide-collab",
                        icon: "square.and.pencil",
                        title: "协作建议",
                        detail: "把目标、边界和截止时间说清楚，减少临时打断，INTP 的输出质量会明显更稳。"
                    ),
                    .init(
                        id: "guide-social",
                        icon: "person.2.fill",
                        title: "社交提醒",
                        detail: "高密度社交后需要独处恢复；如果持续被迫在线，表达会明显变钝。"
                    ),
                    .init(
                        id: "guide-growth",
                        icon: "arrow.triangle.branch",
                        title: "成长方向",
                        detail: "少等 100 分答案，多把 60 分原型拿出来验证。INTP 最容易卡在脑内过度迭代。"
                    )
                ]
            )
            masks = [
                .init(id: "m1", name: "职场模式",   description: "对同事和职业联系人展示更正式、专注效率的一面。", isActive: true,  traits: ["专业", "简洁", "目标导向"], createdAt: Date().addingTimeInterval(-86400 * 10)),
                .init(id: "m2", name: "闺蜜/死党", description: "对亲密朋友展示放松、幽默、可以说废话的模式。",  isActive: false, traits: ["幽默", "直白", "温暖"],   createdAt: Date().addingTimeInterval(-86400 * 5)),
                .init(id: "m3", name: "陌生人破冰", description: "初次见面用中性而有趣的风格，快速建立安全感。",  isActive: false, traits: ["友好", "好奇", "开放"],   createdAt: Date().addingTimeInterval(-86400 * 2)),
            ]
            loadState = .loaded
        }
    }

    func reload() { loadState = .idle; load() }
}

// MARK: - Root View

struct AwakeningPersonalityView: View {
    @StateObject private var store = AwakeningPersonalityStore()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                contentBody
            }
            .navigationTitle("觉醒度与 MBTI")
            .spareNavigationBarTitleDisplayMode(.large)
        }
        .task { store.load() }
    }

    @ViewBuilder
    private var contentBody: some View {
        switch store.loadState {
        case .idle, .loading:
            AwakeningSkeletonView()
        case .loaded:
            AwakeningScrollView(store: store)
        case .error(let msg):
            ErrorStateView(message: msg, retry: { store.reload() })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Scroll View

private struct AwakeningScrollView: View {
    @ObservedObject var store: AwakeningPersonalityStore

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                tabPicker
                    .padding(.horizontal, Spacing.lg)

                tabContent
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.xxxl + 32)
            }
            .padding(.top, Spacing.lg)
        }
        .refreshable { store.reload() }
        .sheet(item: $store.editingMask) { mask in
            MaskEditSheet(mask: mask)
                .presentationDragIndicator(.visible)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $store.showAddMask) {
            MaskCreateSheet()
                .presentationDragIndicator(.visible)
                .presentationDetents([.large])
        }
    }

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(AwakeningPersonalityStore.Tab.allCases, id: \.self) { tab in
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
        case .awakening:
            if let awakening = store.awakening {
                AwakeningLevelCard(awakening: awakening)
                FeaturesUnlockedCard(features: awakening.unlockedFeatures)
            }
        case .dna:
            if let mbtiProfile = store.mbtiProfile {
                MBTIProfileCard(profile: mbtiProfile)
                MBTIGuideCard(profile: mbtiProfile)
            }
        case .masks:
            MasksSection(store: store)
        }
    }
}

// MARK: - Awakening Level Card

private struct AwakeningLevelCard: View {
    let awakening: AwakeningModel
    @State private var progressAnimated: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.spareYellowInk)
                        Text("Lv.\(awakening.level)  \(awakening.title)")
                            .font(.spareTitle3)
                    }
                    Text(awakening.description)
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
                Spacer()
                AwakeningOrb(level: awakening.level)
            }

            // XP Progress bar
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text("成长进度")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(awakening.currentXP) / \(awakening.nextLevelXP) XP")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.spareYellowInk, .spareYellow],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: progressAnimated * geo.size.width, height: 8)
                    }
                    .onAppear {
                        withAnimation(.spring(response: 1.1, dampingFraction: 0.7).delay(0.2)) {
                            progressAnimated = awakening.progressFraction
                        }
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(Spacing.lg)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .cardShadow()
    }
}

private struct AwakeningOrb: View {
    let level: Int
    @State private var pulse = false

    private var orbColor: Color {
        switch level {
        case 1..<3:  return .gray
        case 3..<5:  return .spareYellowInk
        case 5..<7:  return .spareYellowInk
        case 7..<9:  return .spareYellowInk
        default:     return .spareYellow
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(orbColor.opacity(0.15))
                .frame(width: 64, height: 64)
                .scaleEffect(pulse ? 1.12 : 1.0)

            Circle()
                .fill(
                    RadialGradient(colors: [orbColor, orbColor.opacity(0.4)],
                                   center: .center, startRadius: 0, endRadius: 28)
                )
                .frame(width: 48, height: 48)

            Text("\(level)")
                .font(.spareTitle2)
                .foregroundColor(.white)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Unlocked Features

private struct FeaturesUnlockedCard: View {
    let features: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("已解锁能力")
                .font(.spareBodySB)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.sm) {
                ForEach(features, id: \.self) { feature in
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.spareYellowInk)
                            .font(.spareCaptionSB)
                        Text(feature)
                            .font(.spareCaption)
                        Spacer()
                    }
                    .padding(Spacing.sm)
                    .background(Color.spareYellowInk.opacity(0.08), in: RoundedRectangle(cornerRadius: CornerRadius.sm))
                }
            }
        }
        .padding(Spacing.lg)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .cardShadow()
    }
}

// MARK: - MBTI Card

private struct MBTIProfileCard: View {
    let profile: MBTIProfile

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.sm) {
                        Text(profile.typeCode)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)

                        PillTag(label: profile.archetypeName, color: .spareYellowInk, filled: true)
                    }

                    Text("MBTI 人格")
                        .font(.spareCaptionSB)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.spareYellowInk)
                    .frame(width: 44, height: 44)
                    .background(Color.spareYellow.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Text(profile.summary)
                .font(.spareCaption)
                .foregroundColor(.secondary)

            FlowTagsView(tags: profile.strengths)

            VStack(spacing: Spacing.md) {
                ForEach(profile.dimensions) { dimension in
                    MBTIAxisRow(dimension: dimension)
                }
            }
        }
        .padding(Spacing.lg)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .cardShadow()
    }
}

private struct MBTIAxisRow: View {
    let dimension: MBTIProfile.Dimension

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dimension.title)
                        .font(.spareCaptionSB)
                    Text(dimension.pair)
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(dimension.preferredLetter) \(dimension.score)%")
                    .font(.spareCaptionSB)
                    .foregroundColor(dimension.color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(dimension.color)
                        .frame(width: geo.size.width * CGFloat(dimension.score) / 100, height: 8)
                }
            }
            .frame(height: 8)

            Text("\(dimension.preferredLabel)：\(dimension.detail)")
                .font(.spareMicro)
                .foregroundColor(.secondary)
        }
    }
}

private struct MBTIGuideCard: View {
    let profile: MBTIProfile

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "text.book.closed.fill")
                    .foregroundColor(.spareYellowInk)
                Text("\(profile.typeCode) 人格指南")
                    .font(.spareBodySB)
                Spacer()
            }

            VStack(spacing: Spacing.sm) {
                ForEach(profile.guideItems) { item in
                    HStack(alignment: .top, spacing: Spacing.md) {
                        Image(systemName: item.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.spareYellowInk)
                            .frame(width: 28, height: 28)
                            .background(Color.spareYellow.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.spareCaptionSB)
                            Text(item.detail)
                                .font(.spareCaption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()
                    }
                    .padding(Spacing.sm)
                    .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: CornerRadius.md))
                }
            }
        }
        .padding(Spacing.lg)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .cardShadow()
    }
}

// MARK: - Masks Section

private struct MasksSection: View {
    @ObservedObject var store: AwakeningPersonalityStore

    var body: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                Text("面具列表")
                    .font(.spareBodySB)
                Spacer()
                Button {
                    store.showAddMask = true
                } label: {
                    Label("新建", systemImage: "plus")
                        .font(.spareCaptionSB)
                        .foregroundColor(.spareYellow)
                }
            }

            if store.masks.isEmpty {
                EmptyStateView(
                    icon: "theatermasks",
                    title: "还没有面具",
                    message: "创建面具让分身根据场景调整风格。",
                    actionLabel: "新建面具",
                    action: { store.showAddMask = true }
                )
            } else {
                ForEach(store.masks) { mask in
                    MaskRow(mask: mask) {
                        store.editingMask = mask
                    }
                }
            }
        }
    }
}

private struct MaskRow: View {
    let mask: PersonaMask
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: mask.isActive ? "theatermasks.fill" : "theatermasks")
                            .foregroundColor(mask.isActive ? .spareYellow : .secondary)
                        Text(mask.name)
                            .font(.spareBodySB)
                        if mask.isActive {
                            PillTag(label: "使用中", color: .spareYellowInk, filled: true)
                        }
                    }
                    Text(mask.description)
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle")
                        .foregroundColor(.secondary)
                }
            }

            FlowTagsView(tags: mask.traits)
        }
        .padding(Spacing.md)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
        .cardShadow()
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(mask.isActive ? Color.spareYellow.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
    }
}

// MARK: - Sheets

private struct MaskEditSheet: View {
    let mask: PersonaMask
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var description: String

    init(mask: PersonaMask) {
        self.mask = mask
        _name        = State(initialValue: mask.name)
        _description = State(initialValue: mask.description)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("面具设置") {
                    TextField("面具名称", text: $name)
                    TextField("面具描述", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section {
                    Button("保存") { dismiss() }
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("编辑面具")
            .spareNavigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        }
    }
}

private struct MaskCreateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("新建面具") {
                    TextField("面具名称", text: $name)
                    TextField("面具描述", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section {
                    Button("创建") { dismiss() }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .disabled(name.isEmpty)
                }
            }
            .navigationTitle("新建面具")
            .spareNavigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        }
    }
}

// MARK: - Skeleton

private struct AwakeningSkeletonView: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(Color(.systemGray5)).frame(height: 40).shimmer()
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(Color(.systemGray5)).frame(height: 160).shimmer()
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(Color(.systemGray5)).frame(height: 120).shimmer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg)
    }
}

// FlowTagsView is reused from MyProfileView; re-declare locally to avoid cross-file dependency issues
// (in a real modular app, this lives in Shared/)
private struct FlowTagsView: View {
    let tags: [String]
    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 60, maximum: 120), spacing: Spacing.sm)],
            alignment: .leading, spacing: Spacing.sm
        ) {
            ForEach(tags, id: \.self) { tag in
                PillTag(label: tag, color: .spareYellowInk)
            }
        }
    }
}

#if DEBUG
#Preview {
    AwakeningPersonalityView()
}
#endif
