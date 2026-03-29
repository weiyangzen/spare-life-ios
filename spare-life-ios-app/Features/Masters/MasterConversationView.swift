import SwiftUI

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
    }

    private func conversationScreen(
        conversation: MasterConversationDraft,
        profile: MasterProfile
    ) -> some View {
        ZStack {
            MasterConversationBackgroundLayer(profile: profile)

            VStack(spacing: 0) {
                MasterConversationTopBar(
                    profile: profile,
                    status: conversation.serviceStatus,
                    onBack: onBack
                )

                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: Spacing.md) {
                            if let inlineError = conversation.inlineError,
                               !inlineError.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                MasterConversationInlineError(message: inlineError)
                            }

                            ForEach(conversation.messages) { message in
                                MasterConversationBubble(
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
                        .padding(.bottom, Spacing.xxl)
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
        .safeAreaInset(edge: .bottom) {
            composer(for: conversation)
        }
    }

    private func composer(for conversation: MasterConversationDraft) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if !conversation.prefilledPrompt.isEmpty {
                Text("已带入问题模板，你可以直接改，也可以直接发。")
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }

            MasterSpeechInputActions(
                store: store,
                draftText: $draftText,
                disabled: conversation.isReplying
            )

            HStack(alignment: .bottom, spacing: Spacing.sm) {
                TextField("和大师继续聊下去", text: $draftText, axis: .vertical)
                    .lineLimit(2...6)
                    .font(.spareBody)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                            .fill(Color.white.opacity(0.92))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                            .stroke(Color.cardStroke, lineWidth: 1)
                    )

                Button {
                    let pending = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !pending.isEmpty else { return }

                    Task {
                        await store.sendMessage(pending)
                        if store.conversation?.inlineError == nil {
                            draftText = ""
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(isSendDisabled(conversation) ? Color.white.opacity(0.65) : Color.spareYellow)
                            .frame(width: 42, height: 42)
                        Image(systemName: conversation.isReplying ? "ellipsis" : "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(isSendDisabled(conversation) ? .secondary : .spareDark)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isSendDisabled(conversation))
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.35))
                .frame(height: 1)
        }
    }

    private func isSendDisabled(_ conversation: MasterConversationDraft) -> Bool {
        draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || conversation.isReplying
    }

    private func scrollToBottom(using proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.spareEase) {
                proxy.scrollTo("master-conversation-bottom", anchor: .bottom)
            }
        }
    }
}

private struct MasterConversationBackgroundLayer: View {
    let profile: MasterProfile

    var body: some View {
        ZStack {
            MasterConversationAssetImageView(path: profile.imageSet.backgroundPath)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.30),
                    Color.black.opacity(0.10),
                    Color.white.opacity(0.82),
                    Color.white.opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

private struct MasterConversationTopBar: View {
    let profile: MasterProfile
    let status: MasterConversationServiceStatus
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.72), in: Circle())
            }
            .buttonStyle(.plain)

            AvatarView(
                name: profile.displayName,
                size: 42,
                avatarURL: profile.avatarURL
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName)
                    .font(.spareBodySB)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(profile.title)
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Circle()
                        .fill(status.tone == .success ? Color.emotionPositive : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(status.modelName ?? status.providerName)
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.35))
                .frame(height: 1)
        }
    }
}

private struct MasterConversationInlineError: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.emotionNegative)
            Text(message)
                .font(.spareCaption)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                .fill(Color.white.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                .stroke(Color.emotionNegative.opacity(0.24), lineWidth: 1)
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
                        .fill(Color.secondary.opacity(0.7))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                    .fill(Color.white.opacity(0.88))
            )

            Spacer(minLength: 48)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MasterConversationBubble: View {
    let message: MasterMessage
    let assistantName: String
    let assistantAvatarURL: URL?

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.sm) {
            if isUser {
                Spacer(minLength: 48)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.text)
                        .font(.spareBody)
                        .foregroundColor(.spareDark)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                                .fill(Color.spareYellow)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                                .stroke(Color.spareYellow.opacity(0.9), lineWidth: 1)
                        )
                    Text(message.timestamp)
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }
            } else {
                AvatarView(name: assistantName, size: 30, avatarURL: assistantAvatarURL)

                VStack(alignment: .leading, spacing: 4) {
                    Text(assistantName)
                        .font(.spareMicro)
                        .foregroundColor(.secondary)

                    Text(message.text)
                        .font(.spareBody)
                        .foregroundColor(.primary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                                .fill(Color.white.opacity(0.90))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                                .stroke(Color.cardStroke, lineWidth: 1)
                        )

                    Text(message.timestamp)
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 48)
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}

private struct MasterConversationAssetImageView: View {
    let path: String

    var body: some View {
        Group {
            if let image = MasterConversationAssetImageLoader.image(at: path) {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [Color.spareYellowLight, Color.white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
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
