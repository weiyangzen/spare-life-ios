import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct MasterConversationView: View {
    @ObservedObject var store: MasterExperienceStore
    var onBack: () -> Void = {}

    @State private var draftText = ""

    var body: some View {
        Group {
            if let conversation = store.conversation,
               let profile = store.master(withID: conversation.masterID) {
                conversationScreen(conversation: conversation, profile: profile)
            } else {
                ErrorStateView(message: "当前会话不可用。", retry: nil)
            }
        }
        .spareNavigationBarHidden(true)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private func conversationScreen(
        conversation: MasterConversationDraft,
        profile: MasterProfile
    ) -> some View {
        ZStack {
            MasterConversationBackground(profile: profile)

            VStack(spacing: 0) {
                MasterConversationHeaderBar(
                    profile: profile,
                    status: conversation.serviceStatus,
                    onBack: onBack
                )

                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: Spacing.md) {
                            MasterConversationHeroCard(
                                profile: profile,
                                status: conversation.serviceStatus,
                                applyTemplate: { template in
                                    draftText = template.prompt
                                }
                            )

                            if let inlineError = conversation.inlineError,
                               !inlineError.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                MasterConversationErrorBanner(message: inlineError)
                            }

                            ForEach(conversation.messages) { message in
                                MasterConversationMessageRow(
                                    message: message,
                                    assistantName: profile.displayName,
                                    assistantAvatarURL: profile.avatarURL
                                )
                            }

                            if conversation.isReplying {
                                MasterConversationTypingRow(
                                    assistantName: profile.displayName,
                                    assistantAvatarURL: profile.avatarURL
                                )
                            }

                            Color.clear
                                .frame(height: 1)
                                .id("master-conversation-bottom")
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.top, Spacing.md)
                        .padding(.bottom, Spacing.xxxl + 80)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissKeyboardIfNeeded()
                    }
                    .onAppear {
                        if draftText.isEmpty {
                            draftText = conversation.prefilledPrompt
                        }
                        scrollToBottom(using: proxy)
                    }
                    .onChange(of: conversation.messages.count) { _ in
                        scrollToBottom(using: proxy)
                    }
                    .onChange(of: conversation.prefilledPrompt) { _ in
                        if !conversation.prefilledPrompt.isEmpty {
                            draftText = conversation.prefilledPrompt
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MasterConversationComposer(
                store: store,
                conversation: conversation,
                draftText: $draftText
            )
        }
    }

    private func scrollToBottom(using proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.spareEase) {
                proxy.scrollTo("master-conversation-bottom", anchor: .bottom)
            }
        }
    }
}

private struct MasterConversationBackground: View {
    let profile: MasterProfile

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.09, green: 0.10, blue: 0.15),
                        Color(red: 0.12, green: 0.11, blue: 0.18),
                        Color(red: 0.08, green: 0.09, blue: 0.13)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                if let image = MasterConversationAssetImageLoader.image(at: profile.imageSet.backgroundPath) {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.28),
                        Color.black.opacity(0.44),
                        Color.black.opacity(0.62),
                        Color.black.opacity(0.72)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private struct MasterConversationHeaderBar: View {
    let profile: MasterProfile
    let status: MasterConversationServiceStatus
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.black.opacity(0.32))
                    )
            }
            .buttonStyle(.plain)

            AvatarView(
                name: profile.displayName,
                size: 42,
                avatarURL: profile.avatarURL
            )
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(status.tone == .success ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color.black.opacity(0.6), lineWidth: 2))
                    .offset(x: 2, y: 2)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(profile.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Circle()
                    .fill(status.tone == .success ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                Text(status.tone == .success ? "Online" : "Ready")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.28))
            )
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
    }
}

private struct MasterConversationHeroCard: View {
    let profile: MasterProfile
    let status: MasterConversationServiceStatus
    let applyTemplate: (MasterQuestionTemplate) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top, spacing: Spacing.md) {
                AvatarView(
                    name: profile.displayName,
                    size: 58,
                    avatarURL: profile.portraitURL ?? profile.avatarURL
                )

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(profile.displayName)
                        .font(.spareTitle2)
                        .foregroundStyle(.white)
                    Text(profile.tagline)
                        .font(.spareCaption)
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(3)
                    HStack(spacing: 8) {
                        MasterConversationMetaChip(
                            icon: "bolt.fill",
                            text: status.title
                        )
                        MasterConversationMetaChip(
                            icon: "sparkles",
                            text: profile.domainTitle
                        )
                    }
                }

                Spacer(minLength: 0)
            }

            Text(profile.headline)
                .font(.spareBody)
                .foregroundStyle(.white.opacity(0.90))
                .lineLimit(3)

            if !profile.featuredTemplates.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(Array(profile.featuredTemplates.prefix(3))) { template in
                            Button {
                                applyTemplate(template)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.title)
                                        .font(.spareCaptionSB)
                                        .foregroundStyle(.white)
                                    Text(template.prompt)
                                        .font(.spareMicro)
                                        .foregroundStyle(.white.opacity(0.72))
                                        .lineLimit(2)
                                }
                                .frame(width: 180, alignment: .leading)
                                .padding(Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.white.opacity(0.10))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.28))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct MasterConversationMetaChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.white.opacity(0.88))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.10))
        )
    }
}

private struct MasterConversationErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.yellow)
            Text(message)
                .font(.spareCaption)
                .foregroundStyle(.white.opacity(0.92))
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.red.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.red.opacity(0.24), lineWidth: 1)
        )
    }
}

private struct MasterConversationTypingRow: View {
    let assistantName: String
    let assistantAvatarURL: URL?

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.sm) {
            AvatarView(name: assistantName, size: 30, avatarURL: assistantAvatarURL)

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(Color.white.opacity(0.7))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.32))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )

            Spacer(minLength: 48)
        }
    }
}

private struct MasterConversationMessageRow: View {
    let message: MasterMessage
    let assistantName: String
    let assistantAvatarURL: URL?

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if isUser {
                Spacer(minLength: 24)
                userBubble
            } else {
                assistantBubble
                Spacer(minLength: 24)
            }
        }
    }

    private var assistantBubble: some View {
        HStack(alignment: .top, spacing: 8) {
            AvatarView(name: assistantName, size: 30, avatarURL: assistantAvatarURL)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(assistantName)
                    .font(.spareMicro)
                    .foregroundStyle(.white.opacity(0.58))

                Text(message.text)
                    .font(.spareBody)
                    .foregroundStyle(.white.opacity(0.96))
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.black.opacity(0.34))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )

                Text(message.timestamp)
                    .font(.spareMicro)
                    .foregroundStyle(.white.opacity(0.42))
            }
        }
    }

    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("我")
                .font(.spareMicro)
                .foregroundStyle(.white.opacity(0.58))

            Text(message.text)
                .font(.spareBody)
                .foregroundStyle(Color(red: 0.15, green: 0.13, blue: 0.06))
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.spareYellowLight, Color.spareYellow],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            Text(message.timestamp)
                .font(.spareMicro)
                .foregroundStyle(.white.opacity(0.42))
        }
    }
}

private struct MasterConversationComposer: View {
    @ObservedObject var store: MasterExperienceStore
    let conversation: MasterConversationDraft
    @Binding var draftText: String

    var body: some View {
        VStack(spacing: Spacing.sm) {
            if !conversation.prefilledPrompt.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                    Text("已带入推荐提问，直接发或继续改。")
                        .font(.spareMicro)
                }
                .foregroundStyle(.white.opacity(0.72))
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(alignment: .bottom, spacing: Spacing.sm) {
                MasterSpeechInputActions(
                    store: store,
                    draftText: $draftText,
                    disabled: conversation.isReplying
                )

                TextField("继续和这位大师聊", text: $draftText, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.spareBody)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .spareTextInputAutocapitalizationNever()
                    .spareDisableAutocorrection(true)
                    .submitLabel(.send)
                    .onSubmit {
                        sendCurrentDraft()
                    }

                Button {
                    sendCurrentDraft()
                } label: {
                    Image(systemName: conversation.isReplying ? "ellipsis" : "arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(isSendDisabled ? Color.white.opacity(0.58) : Color.spareDark)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(isSendDisabled ? Color.white.opacity(0.12) : Color.spareYellow)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isSendDisabled)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .padding(.bottom, max(spareBottomSafeAreaInset(), Spacing.sm))
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.52))
                .background(.ultraThinMaterial)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }

    private var isSendDisabled: Bool {
        draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || conversation.isReplying
    }

    private func sendCurrentDraft() {
        let pending = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pending.isEmpty else { return }

        draftText = ""
        store.setConversationInlineError(nil)

        Task {
            await store.sendMessage(pending)
            if store.conversation?.inlineError != nil, draftText.isEmpty {
                draftText = pending
            }
        }
    }
}

@MainActor
private func dismissKeyboardIfNeeded() {
    #if canImport(UIKit)
    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil,
        from: nil,
        for: nil
    )
    #endif
}

private enum MasterConversationAssetImageLoader {
    static func image(at path: String) -> Image? {
        #if canImport(UIKit)
        guard let image = UIImage(contentsOfFile: path) else { return nil }
        return Image(uiImage: image)
        #elseif canImport(AppKit) && !canImport(UIKit)
        guard let image = NSImage(contentsOfFile: path) else { return nil }
        return Image(nsImage: image)
        #else
        return nil
        #endif
    }
}
