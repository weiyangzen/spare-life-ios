// ContactMaskView.swift
// Spare Life – 对人面具管理（per-contact mask 覆写）
// Blueprint §消息 功能点 对人面具管理 (line:1139)
// UIUX lane – slot 2

import SwiftUI

// MARK: - Contact Mask Store

private let toneOptions: [MaskToneOption] = [
    MaskToneOption(id: "professional", label: "职场正式", description: "语气严谨、逻辑清晰，适合职场沟通。"),
    MaskToneOption(id: "casual",       label: "轻松随意", description: "口语化、简短，像老朋友聊天。"),
    MaskToneOption(id: "warm",         label: "温柔关怀", description: "多用温暖词汇，擅长感受共鸣。"),
    MaskToneOption(id: "direct",       label: "直接果断", description: "少废话，结论先行，不绕弯子。"),
    MaskToneOption(id: "humorous",     label: "幽默风趣", description: "适度玩笑，让对话更轻松愉快。"),
]

private let disclosureLabels = ["不透露", "极少", "适度", "较多", "全开放"]

@MainActor
final class ContactMaskStore: ObservableObject {
    @Published var config: ContactMaskConfig
    @Published private(set) var isSaving = false
    @Published private(set) var saveSuccess = false

    init(contactID: String, contactName: String) {
        config = ContactMaskConfig(
            contactID: contactID,
            maskName: "默认面具",
            tone: "casual",
            topicWhitelist: ["生活", "兴趣"],
            topicBlacklist: ["家庭纠纷", "财务细节"],
            disclosureLevel: 2,
            historyLog: Self.mockHistory()
        )
    }

    func save() {
        isSaving = true
        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            // In production: persist to local DB
            let entry = MaskHistoryEntry(
                id: UUID().uuidString,
                timestamp: Date(),
                changedField: "面具配置",
                oldValue: "旧配置",
                newValue: "新配置"
            )
            config.historyLog.insert(entry, at: 0)
            isSaving = false
            saveSuccess = true
        }
    }

    func addWhitelist(_ topic: String) {
        let t = topic.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, !config.topicWhitelist.contains(t) else { return }
        config.topicWhitelist.append(t)
    }

    func removeWhitelist(_ topic: String) {
        config.topicWhitelist.removeAll { $0 == topic }
    }

    func addBlacklist(_ topic: String) {
        let t = topic.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, !config.topicBlacklist.contains(t) else { return }
        config.topicBlacklist.append(t)
    }

    func removeBlacklist(_ topic: String) {
        config.topicBlacklist.removeAll { $0 == topic }
    }

    private static func mockHistory() -> [MaskHistoryEntry] {
        let now = Date()
        return [
            MaskHistoryEntry(id: "h1", timestamp: now - 86400 * 3,
                             changedField: "语气风格", oldValue: "职场正式", newValue: "轻松随意"),
            MaskHistoryEntry(id: "h2", timestamp: now - 86400 * 7,
                             changedField: "话题白名单", oldValue: "生活", newValue: "生活, 兴趣"),
        ]
    }
}

// MARK: - Contact Mask View

struct ContactMaskView: View {
    let contactID: String
    let contactName: String

    @StateObject private var store: ContactMaskStore
    @Environment(\.dismiss) private var dismiss
    @State private var showHistory = false
    @State private var newWhitelistTopic = ""
    @State private var newBlacklistTopic = ""

    init(contactID: String, contactName: String) {
        self.contactID = contactID
        self.contactName = contactName
        _store = StateObject(wrappedValue: ContactMaskStore(contactID: contactID, contactName: contactName))
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    headerCard
                    maskNameSection
                    toneSection
                    disclosureSection
                    topicWhitelistSection
                    topicBlacklistSection
                    historySection
                    saveButton
                }
                .padding(Spacing.lg)
                .padding(.bottom, Spacing.xxxl)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("面具设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .alert("保存成功", isPresented: $store.saveSuccess) {
                Button("好") { }
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: Spacing.lg) {
            Image(systemName: "theatermasks.fill")
                .font(.system(size: 32))
                .foregroundColor(.spareYellow)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("为 \(contactName) 定制面具")
                    .font(.spareTitle3)
                Text("覆写你的分身在这段对话中的语气、话题和透露程度。")
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.lg)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .cardShadow()
    }

    // MARK: - Mask Name

    private var maskNameSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("面具名称", systemImage: "tag.fill")
                .font(.spareBodySB)

            TextField("为这个面具命名", text: $store.config.maskName)
                .font(.spareBody)
                .padding(Spacing.md)
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: CornerRadius.md))
        }
        .cardSection()
    }

    // MARK: - Tone

    private var toneSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label("语气风格", systemImage: "waveform.path")
                .font(.spareBodySB)

            ForEach(toneOptions) { option in
                toneRow(option)
            }
        }
        .cardSection()
    }

    private func toneRow(_ option: MaskToneOption) -> some View {
        let isSelected = store.config.tone == option.id
        return Button {
            withAnimation(.spareEase) {
                store.config.tone = option.id
            }
        } label: {
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.spareYellow : Color.secondary.opacity(0.3),
                                lineWidth: isSelected ? 2 : 1)
                        .frame(width: 20, height: 20)
                    if isSelected {
                        Circle()
                            .fill(Color.spareYellow)
                            .frame(width: 10, height: 10)
                    }
                }
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(option.label)
                        .font(isSelected ? .spareBodySB : .spareBody)
                        .foregroundColor(.primary)
                    Text(option.description)
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(Spacing.md)
            .background(
                isSelected ? Color.spareYellow.opacity(0.08) : Color(.tertiarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: CornerRadius.md)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Disclosure Level

    private var disclosureSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Label("透露程度", systemImage: "lock.open.fill")
                    .font(.spareBodySB)
                Spacer()
                Text(disclosureLabels[store.config.disclosureLevel])
                    .font(.spareBodySB)
                    .foregroundColor(.spareYellow)
            }

            Slider(
                value: Binding(
                    get: { Double(store.config.disclosureLevel) },
                    set: { store.config.disclosureLevel = Int($0.rounded()) }
                ),
                in: 0...4, step: 1
            )
            .tint(.spareYellow)

            HStack {
                Text("不透露")
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
                Spacer()
                Text("全开放")
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }
        }
        .cardSection()
    }

    // MARK: - Topic Lists

    private var topicWhitelistSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label("允许话题（白名单）", systemImage: "checkmark.shield.fill")
                .font(.spareBodySB)
                .foregroundColor(.emotionPositive)

            topicChips(topics: store.config.topicWhitelist, color: .emotionPositive) { topic in
                store.removeWhitelist(topic)
            }

            topicInput(placeholder: "添加话题…", text: $newWhitelistTopic) {
                store.addWhitelist(newWhitelistTopic)
                newWhitelistTopic = ""
            }
        }
        .cardSection()
    }

    private var topicBlacklistSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label("禁止话题（黑名单）", systemImage: "xmark.shield.fill")
                .font(.spareBodySB)
                .foregroundColor(.emotionNegative)

            topicChips(topics: store.config.topicBlacklist, color: .emotionNegative) { topic in
                store.removeBlacklist(topic)
            }

            topicInput(placeholder: "添加禁止话题…", text: $newBlacklistTopic) {
                store.addBlacklist(newBlacklistTopic)
                newBlacklistTopic = ""
            }
        }
        .cardSection()
    }

    private func topicChips(topics: [String], color: Color, onRemove: @escaping (String) -> Void) -> some View {
        FlowLayout(spacing: Spacing.sm) {
            ForEach(topics, id: \.self) { topic in
                HStack(spacing: Spacing.xs) {
                    Text(topic)
                        .font(.spareCaptionSB)
                    Button { onRemove(topic) } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                    }
                }
                .foregroundColor(color)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(color.opacity(0.12), in: Capsule())
            }
        }
    }

    private func topicInput(placeholder: String, text: Binding<String>, onSubmit: @escaping () -> Void) -> some View {
        HStack(spacing: Spacing.sm) {
            TextField(placeholder, text: text)
                .font(.spareBody)
                .submitLabel(.done)
                .onSubmit(onSubmit)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(Color(.tertiarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: CornerRadius.md))
            Button(action: onSubmit) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.spareYellow)
            }
        }
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Button {
                withAnimation(.spareEase) { showHistory.toggle() }
            } label: {
                HStack {
                    Label("修改历史", systemImage: "clock.arrow.circlepath")
                        .font(.spareBodySB)
                    Spacer()
                    Image(systemName: showHistory ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.spareCaptionSB)
                }
            }
            .buttonStyle(.plain)

            if showHistory {
                if store.config.historyLog.isEmpty {
                    Text("暂无修改记录")
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        ForEach(store.config.historyLog) { entry in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    Text(entry.changedField)
                                        .font(.spareCaptionSB)
                                    Text("\(entry.oldValue) → \(entry.newValue)")
                                        .font(.spareCaption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(entry.timestamp, style: .relative)
                                    .font(.spareMicro)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, Spacing.xs)
                            Divider()
                        }
                    }
                }
            }
        }
        .cardSection()
    }

    // MARK: - Save

    private var saveButton: some View {
        Button {
            store.save()
        } label: {
            Group {
                if store.isSaving {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else {
                    Text("保存面具设置")
                        .font(.spareBodySB)
                }
            }
            .foregroundColor(.spareDark)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(Color.spareYellow, in: RoundedRectangle(cornerRadius: CornerRadius.pill))
        }
        .disabled(store.isSaving)
    }
}

// MARK: - Flow Layout (wrapping chip layout)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                height += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Card Section Helper

private extension View {
    func cardSection() -> some View {
        self
            .padding(Spacing.lg)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
            .cardShadow()
    }
}
