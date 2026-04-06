// MessagesFeatureRootView.swift
// Spare Life – single navigation host for the messages feature.

import SwiftUI

struct MessagesFeatureRootView: View {
    @EnvironmentObject private var router: ConversationRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            ConversationHubView()
                .navigationDestination(for: MessagesRoute.self) { route in
                    destination(for: route)
                }
        }
    }

    @ViewBuilder
    private func destination(for route: MessagesRoute) -> some View {
        switch route {
        case .home:
            ConversationHubView()
        case .thread(let context):
            ChatThreadView(thread: context.thread)
        case .mask, .relationship, .memory, .quadRole, .groupPlay, .groupVote, .composeDraft:
            MessagesPendingSurfaceView(route: route)
        }
    }
}

private struct MessagesPendingSurfaceView: View {
    let route: MessagesRoute

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: pendingIcon)
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(.spareYellowInk)

            VStack(spacing: Spacing.sm) {
                Text(route.title)
                    .font(.spareTitle3)
                    .foregroundColor(.primary)

                Text(pendingMessage)
                    .font(.spareBody)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let contextLine {
                Text(contextLine)
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        Capsule()
                            .fill(Color.spareYellow.opacity(0.12))
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Spacing.xl)
        .background(
            LinearGradient(
                colors: [
                    Color.spareYellow.opacity(0.10),
                    Color.white,
                    Color.white
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle(route.title)
        .spareNavigationBarTitleDisplayMode(.inline)
    }

    private var pendingIcon: String {
        switch route {
        case .mask:
            return "theatermasks.fill"
        case .relationship:
            return "heart.circle.fill"
        case .memory:
            return "brain"
        case .quadRole:
            return "person.3.fill"
        case .groupPlay:
            return "person.2.circle.fill"
        case .groupVote:
            return "checklist.checked"
        case .composeDraft:
            return "square.and.pencil"
        case .home, .thread:
            return "message"
        }
    }

    private var pendingMessage: String {
        switch route {
        case .mask, .relationship, .memory, .quadRole, .groupPlay, .groupVote:
            return "该路由 contract 已冻结，但线程内入口仍保留 legacy sheet 流程，等待后续 S3-023 接成 typed navigation。"
        case .composeDraft:
            return "该草稿路由已纳入统一 messages route，但 compose surface 仍未接成独立 runtime。"
        case .home, .thread:
            return "该页面没有 pending 状态。"
        }
    }

    private var contextLine: String? {
        switch route {
        case .mask(let context),
             .relationship(let context),
             .memory(let context),
             .quadRole(let context),
             .groupPlay(let context):
            return "目标联系人：\(context.thread.contactName)"
        case .groupVote(let context):
            return "群投票：\(context.title)"
        case .composeDraft(let context):
            return "draft_id: \(context.draftID)"
        case .home, .thread:
            return nil
        }
    }
}
