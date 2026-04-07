// SceneSocialIntentView.swift
// Spare Life – 咸虾 场景发起陌生社交
// Blueprint §3.1 功能点4: 从扫码页跳入陌生社交流程
// Covers: lane selection, initiation mode, intent note, risk gate, submit
// UIUX lane – slot 2

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - SceneSocialIntentView

struct SceneSocialIntentView: View {
    let scene: Scene
    var targetAvatar: SceneAvatarCard? = nil

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appHandoffRouter: AppHandoffRouter
    @StateObject private var vm: SocialIntentViewModel

    init(scene: Scene, targetAvatar: SceneAvatarCard? = nil) {
        self.scene = scene
        self.targetAvatar = targetAvatar
        _vm = StateObject(wrappedValue: SocialIntentViewModel(scene: scene, targetAvatar: targetAvatar))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                switch vm.submitState {
                case .form:
                    formBody
                case .submitting:
                    submittingOverlay
                case .success:
                    successView
                case .error(let msg):
                    errorView(message: msg)
                }
            }
            .navigationTitle(navigationTitle)
            .spareNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .spareNavigationLeading) {
                    if case .form = vm.submitState {
                        Button("取消") { dismiss() }
                    }
                }
            }
            .interactiveDismissDisabled(vm.submitState == .submitting)
            .onChange(of: vm.submitState) { state in
                // Reset spring scales so animation replays if user retries.
                if case .submitting = state {
                    successCheckScale = 0.3
                    successRingScale  = 0.5
                }
            }
        }
    }

    private var navigationTitle: String {
        if let avatar = targetAvatar {
            return "向 \(avatar.displayName) 发起社交"
        }
        return "在「\(scene.name)」发起社交"
    }

    // MARK: - Form Body

    private var formBody: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                // Step progress bar
                IntentStepProgress(draft: vm.draft)
                    .padding(.top, Spacing.xs)

                // Target avatar card (if specific avatar was chosen)
                if let avatar = targetAvatar {
                    TargetAvatarBanner(avatar: avatar)
                }

                // ── Step 1: Lane selection ────────────────────────────
                SectionCard(title: "1  选择社交赛道", icon: "flag") {
                    LaneSelectionGrid(selectedLane: $vm.draft.lane)
                }

                // ── Step 2: Initiation mode ───────────────────────────
                SectionCard(title: "2  选择开场方式", icon: "person.2") {
                    InitModeSelector(selectedMode: $vm.draft.mode)
                }

                // ── Step 3: Intent note ───────────────────────────────
                SectionCard(title: "3  写下你的意图（选填）", icon: "pencil") {
                    IntentNoteEditor(note: $vm.draft.note)
                }

                // ── Risk notice ───────────────────────────────────────
                RiskNoticeView(riskLevel: vm.riskLevel)

                // ── Submit button ─────────────────────────────────────
                submitButton

                Spacer(minLength: Spacing.xxxl)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
        }
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            vm.submit()
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .bold))
                Text("发起社交")
                    .font(.spareBodySB)
            }
            .foregroundColor(.spareDark)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(Color.spareYellow, in: RoundedRectangle(cornerRadius: CornerRadius.md))
            .cardShadow(prominent: true)
        }
        .buttonStyle(.plain)
        .disabled(!vm.canSubmit)
        .opacity(vm.canSubmit ? 1 : 0.5)
    }

    // MARK: - Submitting Overlay

    private var submittingOverlay: some View {
        VStack(spacing: Spacing.lg) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .spareYellow))
                .scaleEffect(1.4)
            Text("正在配对你的分身…")
                .font(.spareBodySB)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Success View

    @State private var successCheckScale: CGFloat = 0.3
    @State private var successRingScale: CGFloat = 0.5

    private var successView: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Spring-animated checkmark
            ZStack {
                Circle()
                    .fill(Color.emotionPositive.opacity(0.12))
                    .frame(width: 110, height: 110)
                    .scaleEffect(successRingScale)
                Circle()
                    .strokeBorder(Color.emotionPositive.opacity(0.25), lineWidth: 2)
                    .frame(width: 110, height: 110)
                    .scaleEffect(successRingScale)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 58))
                    .foregroundColor(.emotionPositive)
                    .scaleEffect(successCheckScale)
            }
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
                    successCheckScale = 1.0
                    successRingScale = 1.0
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }

            VStack(spacing: Spacing.sm) {
                Text("已成功发起！")
                    .font(.spareTitle2)
                Text(successMessage)
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xxxl)
            }

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                appHandoffRouter.openLegacyRoute(
                    vm.earnSocialRoute(targetAvatarName: targetAvatar?.displayName),
                    sourceSurface: .xianxia
                )
                dismiss()
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "bolt.circle.fill")
                        .font(.system(size: 14))
                    Text("去赚闲能继续破冰")
                        .font(.spareBodySB)
                }
                .foregroundColor(.spareDark)
                .frame(maxWidth: 220)
                .padding(.vertical, Spacing.md)
                .background(Color.spareYellow, in: Capsule())
                .cardShadow(prominent: true)
            }
            .buttonStyle(.plain)

            Button {
                dismiss()
            } label: {
                Text("返回场景")
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    private var successMessage: String {
        switch vm.draft.mode {
        case .avatarFirst:
            return "你的分身已出发，等对方分身回应后会通知你。"
        case .dualAvatar:
            return "双方分身已进入破冰对话，稍后你可以接手。"
        case .humanFirst:
            return "对话请求已送达，等待对方接受后可直接聊起来。"
        }
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.emotionNegative)
            Text("发起失败")
                .font(.spareTitle3)
            Text(message)
                .font(.spareCaption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxxl)

            Button {
                vm.submitState = .form
            } label: {
                Text("重试")
                    .font(.spareBodySB)
                    .foregroundColor(.white)
                    .frame(maxWidth: 160)
                    .padding(.vertical, Spacing.md)
                    .background(Color.primary, in: Capsule())
            }
            .buttonStyle(.plain)

            Button { dismiss() } label: {
                Text("取消")
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }
}

// MARK: - IntentStepProgress
// Horizontal 3-step roadmap shown at the top of the intent form.
// Steps: 1 = lane, 2 = mode, 3 = note (optional).

private struct IntentStepProgress: View {
    let draft: IntentDraft

    // Step 3 is considered "active" once the user has typed a note.
    private var noteActive: Bool { !draft.note.isEmpty }

    var body: some View {
        HStack(spacing: 0) {
            StepNode(number: 1, label: "选赛道", isDone: true)

            StepConnector(filled: true)

            StepNode(number: 2, label: "选方式", isDone: true)

            StepConnector(filled: noteActive)

            StepNode(number: 3, label: "写意图", isDone: noteActive, isOptional: true)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: CornerRadius.md)
        )
    }

    // ── Sub-components ──────────────────────────────────────────────

    private struct StepNode: View {
        let number: Int
        let label: String
        var isDone: Bool
        var isOptional: Bool = false

        var body: some View {
            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .fill(isDone ? Color.spareYellow : Color(.systemGray5))
                        .frame(width: 26, height: 26)
                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.spareDark)
                    } else {
                        Text("\(number)")
                            .font(.spareMicro)
                            .foregroundColor(.secondary)
                    }
                }
                .animation(.spareFast, value: isDone)

                HStack(spacing: 1) {
                    Text(label)
                        .font(.spareMicro)
                        .foregroundColor(isDone ? .primary : .secondary)
                    if isOptional {
                        Text("*")
                            .font(.spareMicro)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private struct StepConnector: View {
        var filled: Bool

        var body: some View {
            Rectangle()
                .fill(filled ? Color.spareYellow : Color(.systemGray4))
                .frame(height: 2)
                .frame(maxWidth: .infinity)
                .offset(y: -9)  // align with circle centres
                .animation(.spareFast, value: filled)
        }
    }
}

// MARK: - SectionCard

private struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.spareYellow)
                Text(title)
                    .font(.spareCaptionSB)
                    .foregroundColor(.secondary)
            }
            content()
        }
        .padding(Spacing.md)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .cardShadow()
    }
}

// MARK: - TargetAvatarBanner
// Shows the specific avatar being targeted at the top of the form.

private struct TargetAvatarBanner: View {
    let avatar: SceneAvatarCard

    var body: some View {
        HStack(spacing: Spacing.md) {
            AvatarView(name: avatar.displayName, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(avatar.displayName)
                    .font(.spareBodySB)
                    .lineLimit(1)
                Text(avatar.tagline)
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "arrow.right.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(.spareYellow)
        }
        .padding(Spacing.md)
        .background(Color.spareYellow.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .strokeBorder(Color.spareYellow.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - LaneSelectionGrid
// 2×3 grid of social lane options.

private struct LaneSelectionGrid: View {
    @Binding var selectedLane: SceneSocialPromptCard.SocialLane

    private let lanes = SceneSocialPromptCard.SocialLane.allCases
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Spacing.sm) {
            ForEach(lanes) { lane in
                LaneTile(lane: lane, isSelected: selectedLane == lane) {
                    withAnimation(.spareFast) { selectedLane = lane }
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
        }
    }
}

private struct LaneTile: View {
    let lane: SceneSocialPromptCard.SocialLane
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.spareYellow : Color(.systemGray5))
                        .frame(width: 40, height: 40)
                    Image(systemName: lane.icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(isSelected ? .spareDark : .secondary)
                }
                Text(lane.rawValue)
                    .font(.spareMicro)
                    .foregroundColor(isSelected ? .spareDark : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .fill(isSelected ? Color.spareYellow.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .strokeBorder(isSelected ? Color.spareYellow : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - InitModeSelector
// Segmented-style rows for picking the conversation initiation mode.

private struct InitModeSelector: View {
    @Binding var selectedMode: IntentDraft.InitMode

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(IntentDraft.InitMode.allCases, id: \.self) { mode in
                InitModeRow(mode: mode, isSelected: selectedMode == mode) {
                    withAnimation(.spareEase) { selectedMode = mode }
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
        }
    }
}

private struct InitModeRow: View {
    let mode: IntentDraft.InitMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.spareYellow : Color(.systemGray5))
                        .frame(width: 36, height: 36)
                    Image(systemName: mode.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isSelected ? .spareDark : .secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xs) {
                        Text(mode.rawValue)
                            .font(.spareBodySB)
                        if mode == .avatarFirst {
                            Text("推荐")
                                .font(.spareMicro)
                                .foregroundColor(.spareDark)
                                .padding(.horizontal, Spacing.xs)
                                .padding(.vertical, 1)
                                .background(Color.spareYellow.opacity(0.8), in: Capsule())
                        }
                    }
                    Text(mode.description)
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .emotionPositive : Color(.systemGray4))
            }
            .padding(Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .fill(isSelected ? Color.spareYellow.opacity(0.08) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .strokeBorder(isSelected ? Color.spareYellow.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - IntentNoteEditor
// Expandable text editor for writing the social intent.

private struct IntentNoteEditor: View {
    @Binding var note: String
    private let maxLength = 120

    var body: some View {
        VStack(alignment: .trailing, spacing: Spacing.xs) {
            TextField(
                "例如：想认识同行，聊聊最近市场动态（可不填）",
                text: $note,
                axis: .vertical
            )
            .font(.spareBody)
            .lineLimit(3...6)
            .onChange(of: note) { newValue in
                if newValue.count > maxLength {
                    note = String(newValue.prefix(maxLength))
                }
            }

            Text("\(note.count)/\(maxLength)")
                .font(.spareMicro)
                .foregroundColor(note.count > maxLength - 10 ? .emotionSplit : .secondary)
        }
    }
}

// MARK: - RiskNoticeView
// Contextual risk disclosure based on the computed risk level.

private struct RiskNoticeView: View {
    let riskLevel: IntentDraft.RiskLevel

    private var config: (icon: String, title: String, message: String, color: Color) {
        switch riskLevel {
        case .low:
            return (
                "shield.lefthalf.filled",
                "隐私保护",
                "你的真实联系方式、位置和身份信息不会直接暴露给对方。分身会先代你探风。",
                .emotionPositive
            )
        case .medium:
            return (
                "exclamationmark.shield",
                "注意",
                "对话将由你的分身发起，但对方可能会问到你的真实信息。",
                .emotionSplit
            )
        case .high:
            return (
                "exclamationmark.triangle",
                "风控提示",
                "该社交请求被标记为较高风险，请确认你了解相关规则。",
                .emotionNegative
            )
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: config.icon)
                .font(.system(size: 20))
                .foregroundColor(config.color)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(config.title)
                    .font(.spareCaptionSB)
                    .foregroundColor(config.color)
                Text(config.message)
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.md)
        .background(config.color.opacity(0.08), in: RoundedRectangle(cornerRadius: CornerRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .strokeBorder(config.color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - SocialIntentViewModel

@MainActor
final class SocialIntentViewModel: ObservableObject {
    @Published var draft: IntentDraft
    @Published var submitState: SubmitState = .form

    enum SubmitState: Equatable {
        case form
        case submitting
        case success
        case error(String)
    }

    init(scene: Scene, targetAvatar: SceneAvatarCard?) {
        self.draft = IntentDraft(
            sceneID: scene.id,
            sceneName: scene.name,
            lane: .friend,
            mode: .avatarFirst
        )
    }

    var canSubmit: Bool {
        if case .form = submitState { return true }
        return false
    }

    var riskLevel: IntentDraft.RiskLevel {
        switch draft.mode {
        case .humanFirst:  return .medium
        case .avatarFirst: return .low
        case .dualAvatar:  return .low
        }
    }

    func earnSocialRoute(targetAvatarName: String?) -> String {
        LegacyAppRouteBuilder.earnSocialMarket(
            lane: earnSocialLane,
            topic: handoffTopic(targetAvatarName: targetAvatarName)
        )
    }

    func submit() {
        guard case .form = submitState else { return }
        submitState = .submitting
        // FUNC lane will call the real A2A initiation endpoint here.
        // Present success state so the full success UI path is exercised.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            submitState = .success
        }
    }

    private var earnSocialLane: EarnSocialLaneID {
        switch draft.lane {
        case .friend, .meal:
            return .friendship
        case .collab, .jobSeek:
            return .jobHiring
        case .skill:
            return .skillQA
        case .errand:
            return .errandHelp
        }
    }

    private func handoffTopic(targetAvatarName: String?) -> String? {
        let note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty {
            return note
        }
        if let targetAvatarName, !targetAvatarName.isEmpty {
            return "\(draft.sceneName) · \(targetAvatarName)"
        }
        return draft.sceneName
    }
}
