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

struct PersonalityDNA {
    var traits: [Trait]

    struct Trait: Identifiable {
        let id: String
        let name: String
        let leftPole: String
        let rightPole: String
        /// -1.0 (full left) ... +1.0 (full right)
        var value: Double
        let color: Color
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
    @Published var dna: PersonalityDNA? = nil
    @Published var masks: [PersonaMask] = []
    @Published var selectedTab: Tab = .awakening
    @Published var editingMask: PersonaMask? = nil
    @Published var showAddMask = false

    enum Tab: String, CaseIterable {
        case awakening  = "觉醒度"
        case dna        = "人格 DNA"
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
            dna = PersonalityDNA(traits: [
                .init(id: "ei", name: "内外倾向", leftPole: "内向",   rightPole: "外向",   value:  0.3, color: .blue),
                .init(id: "ns", name: "思维方式", leftPole: "感性",   rightPole: "理性",   value:  0.1, color: .purple),
                .init(id: "tf", name: "判断倾向", leftPole: "情感优先", rightPole: "逻辑优先", value: -0.2, color: .orange),
                .init(id: "jp", name: "行为风格", leftPole: "灵活",   rightPole: "计划",   value:  0.4, color: .teal),
                .init(id: "op", name: "开放程度", leftPole: "保守",   rightPole: "开放",   value:  0.6, color: .green),
            ])
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
            .navigationTitle("觉醒度与人格")
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
            if let dna = store.dna {
                PersonalityDNACard(dna: dna)
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
                            .foregroundColor(.orange)
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
                                    colors: [.orange, .yellow],
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
        case 3..<5:  return .blue
        case 5..<7:  return .purple
        case 7..<9:  return .orange
        default:     return .yellow
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
                            .foregroundColor(.green)
                            .font(.spareCaptionSB)
                        Text(feature)
                            .font(.spareCaption)
                        Spacer()
                    }
                    .padding(Spacing.sm)
                    .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: CornerRadius.sm))
                }
            }
        }
        .padding(Spacing.lg)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .cardShadow()
    }
}

// MARK: - Personality DNA Card

private struct PersonalityDNACard: View {
    let dna: PersonalityDNA

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "dna")
                    .foregroundColor(.purple)
                Text("人格 DNA")
                    .font(.spareBodySB)
                Spacer()
                Button("调整") {
                    // In production: present edit sheet
                }
                .font(.spareCaption)
                .foregroundColor(.spareYellow)
            }

            VStack(spacing: Spacing.md) {
                ForEach(dna.traits) { trait in
                    TraitSlider(trait: trait)
                }
            }
        }
        .padding(Spacing.lg)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .cardShadow()
    }
}

private struct TraitSlider: View {
    let trait: PersonalityDNA.Trait

    private var normalized: Double { (trait.value + 1) / 2 }

    var body: some View {
        VStack(spacing: Spacing.xs) {
            HStack {
                Text(trait.name)
                    .font(.spareCaptionSB)
                Spacer()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 6)

                    // Filled portion
                    RoundedRectangle(cornerRadius: 4)
                        .fill(trait.color)
                        .frame(width: normalized * geo.size.width, height: 6)

                    // Thumb
                    Circle()
                        .fill(trait.color)
                        .frame(width: 14, height: 14)
                        .offset(x: max(0, normalized * geo.size.width - 7))
                }
            }
            .frame(height: 14)

            HStack {
                Text(trait.leftPole)
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
                Spacer()
                Text(trait.rightPole)
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }
        }
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
                            PillTag(label: "使用中", color: .green, filled: true)
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
                PillTag(label: tag, color: .purple)
            }
        }
    }
}

#if DEBUG
#Preview {
    AwakeningPersonalityView()
}
#endif
