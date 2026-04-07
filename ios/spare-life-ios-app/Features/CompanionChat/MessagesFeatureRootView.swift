// MessagesFeatureRootView.swift
// Spare Life – single navigation host for the messages feature.

import SwiftUI

struct MessagesFeatureRootView: View {
    @EnvironmentObject private var router: ConversationRouter
    @EnvironmentObject private var appHandoffRouter: AppHandoffRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            rootContent
                .navigationDestination(for: MessagesRoute.self) { route in
                    destination(for: route)
                }
        }
        .task {
            guard let handoff = appHandoffRouter.lastHandoff else { return }
            router.applyExternalHandoff(handoff)
        }
        .onChange(of: appHandoffRouter.handoffSerial) { _ in
            guard let handoff = appHandoffRouter.lastHandoff else { return }
            router.applyExternalHandoff(handoff)
        }
    }

    @ViewBuilder
    private func destination(for route: MessagesRoute) -> some View {
        switch route {
        case .home:
            ConversationHubView()
        case .thread(let context):
            ChatThreadView(thread: context.thread)
        case .mask(let context):
            ContactMaskView(
                contactID: context.thread.routePrimaryKey,
                contactName: context.thread.contactName,
                presentation: .embedded
            )
        case .relationship(let context):
            RelationshipGardenView(
                profile: .routeSeed(for: context.thread),
                presentation: .embedded
            )
        case .memory(let context):
            CrossSessionMemoryView(
                thread: context.thread,
                presentation: .embedded
            )
        case .quadRole(let context):
            QuadRoleChatView(
                thread: context.thread,
                presentation: .embedded
            )
        case .groupPlay(let context):
            GroupAgentPlayView(
                thread: context.thread,
                presentation: .embedded
            )
        case .groupVote, .composeDraft:
            MessagesPendingSurfaceView(route: route)
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        if let pending = router.pendingHandoff, router.path.isEmpty {
            MessagesPendingHandoffView(
                pending: pending,
                sourceSurface: router.lastHandoff?.sourceSurface,
                dismissPending: {
                    router.clearPendingHandoff()
                }
            )
        } else {
            ConversationHubView()
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
        case .groupVote:
            return "group vote 已有 typed route，但当前仍停留在群玩法总面板，独立投票详情还没拆成 runtime surface。"
        case .composeDraft:
            return "该草稿路由已纳入统一 messages route，但 compose surface 仍未接成独立 runtime。"
        case .home, .thread, .mask, .relationship, .memory, .quadRole, .groupPlay:
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

private struct MessagesPendingHandoffView: View {
    let pending: MessagesPendingHandoff
    let sourceSurface: AppSurfaceID?
    let dismissPending: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: pendingIcon)
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(.spareYellowInk)

            VStack(spacing: Spacing.sm) {
                Text("待接线 handoff")
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

            Button("继续看消息首页") {
                dismissPending()
            }
            .font(.spareCaptionSB)
            .foregroundColor(.spareYellowInk)
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
        .navigationTitle("消息待接线")
        .spareNavigationBarTitleDisplayMode(.inline)
    }

    private var pendingIcon: String {
        switch pending {
        case .composeDraft:
            return "square.and.pencil"
        case .legacyThreadLaneCounterpart, .legacyBondBridge, .unresolvedThread:
            return "clock.arrow.circlepath"
        }
    }

    private var pendingMessage: String {
        switch pending {
        case .composeDraft:
            let sourceTitle = sourceSurface?.title ?? "上游页面"
            return "\(sourceTitle) 已把草稿 handoff 交给消息页，但 compose surface 还没有接成独立 runtime。"
        case .legacyThreadLaneCounterpart:
            return "已把赚闲能带来的消息接手请求挂起。当前 messages root 先落到 hub，等 thread bridge ready 后再消化这份 payload。"
        case .legacyBondBridge:
            return "已保留关系任务到消息线程的桥接 payload。当前还没有可直接打开的 bond thread runtime，所以先挂起。"
        case .unresolvedThread:
            return "已收到 thread locator，但当前消息根页还拿不到可渲染的 live thread summary，只能先保留 handoff。"
        }
    }

    private var contextLine: String? {
        switch pending {
        case .composeDraft(_, let seedText, let sessionID, _):
            if let sessionID, !sessionID.isEmpty {
                return "session_id: \(sessionID)"
            }
            guard let seedText, !seedText.isEmpty else { return nil }
            return "草稿预填：\(seedText)"
        case .legacyThreadLaneCounterpart(let laneID, let counterpartName):
            return "lane: \(laneID) · counterpart: \(counterpartName)"
        case .legacyBondBridge(let bondID, let icebreakSessionID):
            if let icebreakSessionID, !icebreakSessionID.isEmpty {
                return "bond_id: \(bondID) · icebreak_session_id: \(icebreakSessionID)"
            }
            return "bond_id: \(bondID)"
        case .unresolvedThread(let locator, _):
            return locator.canonicalThreadID
        }
    }
}
