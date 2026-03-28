import SwiftUI

struct MasterConversationView: View {
    @ObservedObject var store: MasterExperienceStore
    @State private var draftText = ""

    var body: some View {
        Group {
            if let conversation = store.conversation,
               let profile = store.master(withID: conversation.masterID) {
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: Spacing.lg) {
                                MasterConversationHeaderCard(profile: profile)
                                MasterConversationStatusCard(status: conversation.serviceStatus)

                                if let inlineError = conversation.inlineError {
                                    ErrorStateView(message: inlineError, retry: nil)
                                }

                                ForEach(conversation.messages) { message in
                                    MasterConversationBubble(
                                        message: message,
                                        assistantName: profile.displayName,
                                        assistantAvatarURL: profile.avatarURL
                                    )
                                }

                                if conversation.isReplying {
                                    HStack(spacing: Spacing.sm) {
                                        ProgressView()
                                        Text("正在整理回复…")
                                            .font(.spareCaption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(Spacing.md)
                                }

                                Color.clear
                                    .frame(height: 1)
                                    .id("master-conversation-bottom")
                            }
                            .padding(.horizontal, Spacing.lg)
                            .padding(.top, Spacing.lg)
                            .padding(.bottom, Spacing.xxxl)
                        }
                        .background(Color(.systemGroupedBackground))
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

                    composer(for: conversation)
                }
                .navigationTitle(profile.displayName)
                .spareNavigationBarTitleDisplayMode(.inline)
            } else {
                ErrorStateView(message: "当前会话不可用。", retry: nil)
            }
        }
    }

    private func composer(for conversation: MasterConversationDraft) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if !conversation.prefilledPrompt.isEmpty {
                Text("已带入问题模板，可继续修改后发送。")
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }

            HStack(alignment: .bottom, spacing: Spacing.sm) {
                TextField("输入你想继续问大师的问题", text: $draftText, axis: .vertical)
                    .lineLimit(2...6)
                    .font(.spareBody)
                    .padding(Spacing.md)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.lg)
                            .stroke(Color.cardStroke, lineWidth: 1)
                    )

                Button {
                    let pending = draftText
                    Task {
                        await store.sendMessage(pending)
                        if store.conversation?.inlineError == nil {
                            draftText = ""
                        }
                    }
                } label: {
                    Image(systemName: conversation.isReplying ? "ellipsis.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundColor(sendButtonColor(isDisabled: isSendDisabled(conversation)))
                }
                .buttonStyle(.plain)
                .disabled(isSendDisabled(conversation))
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.md)
        .background(.ultraThinMaterial)
    }

    private func isSendDisabled(_ conversation: MasterConversationDraft) -> Bool {
        draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || conversation.isReplying
    }

    private func sendButtonColor(isDisabled: Bool) -> Color {
        isDisabled ? .secondary.opacity(0.6) : .spareYellow
    }

    private func scrollToBottom(using proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.spareEase) {
                proxy.scrollTo("master-conversation-bottom", anchor: .bottom)
            }
        }
    }
}

private struct MasterConversationHeaderCard: View {
    let profile: MasterProfile

    var body: some View {
        HStack(spacing: Spacing.md) {
            AvatarView(name: profile.displayName, size: 54, avatarURL: profile.avatarURL)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(profile.displayName)
                    .font(.spareTitle3)
                Text(profile.title)
                    .font(.spareCaptionSB)
                    .foregroundColor(.secondary)
                Text(profile.tagline)
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(Spacing.md)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
    }
}

private struct MasterConversationStatusCard: View {
    let status: MasterConversationServiceStatus

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: status.isLiveRemote ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(status.isLiveRemote ? .emotionPositive : .emotionSplit)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(status.title)
                    .font(.spareCaptionSB)
                Text(status.detail)
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(Spacing.md)
        .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
    }
}

private struct MasterConversationBubble: View {
    let message: MasterMessage
    let assistantName: String
    let assistantAvatarURL: URL?

    private var isUser: Bool {
        message.role == .user
    }

    private var alignment: HorizontalAlignment {
        isUser ? .trailing : .leading
    }

    var body: some View {
        VStack(alignment: alignment, spacing: Spacing.xs) {
            HStack {
                if isUser { Spacer() }
                if !isUser {
                    AvatarView(name: assistantName, size: 28, avatarURL: assistantAvatarURL)
                }
                VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                    Text(message.role == .assistant ? assistantName : "我")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)

                    Text(message.text)
                        .font(.spareBody)
                        .foregroundColor(isUser ? .white : .primary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.lg)
                                .fill(isUser ? Color.spareYellow : Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.lg)
                                .stroke(isUser ? Color.spareYellow : Color.cardStroke, lineWidth: 1)
                        )

                    Text(message.timestamp)
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }
                if isUser { }
                if !isUser {
                    Spacer()
                }
            }
        }
    }
}
