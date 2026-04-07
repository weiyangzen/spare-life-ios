#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/stage3_messages_typed_routes.XXXXXX")"
HARNESS_SWIFT="$TMP_DIR/Stage3MessagesTypedRouteSmoke.swift"
SMOKE_BIN="$TMP_DIR/stage3_messages_typed_route_smoke"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cat >"$HARNESS_SWIFT" <<'SWIFT'
import AppKit
import Foundation
import SwiftUI

@MainActor
@main
enum Stage3MessagesTypedRouteSmoke {
    static func main() throws {
        _ = NSApplication.shared

        let threads = ConversationHubStore.mockThreads()
        guard let dmThread = threads.first(where: { $0.kind == .human }),
              let quadThread = threads.first(where: { $0.kind == .quadRole }),
              let groupThread = threads.first(where: { $0.kind == .group }) else {
            throw SmokeError("Missing mock threads for the typed route smoke.")
        }

        let router = ConversationRouter()
        let handoff = AppHandoffRouter()
        let size = CGSize(width: 1024, height: 820)

        let homeRoute = MessagesRoute.home
        try check(
            label: "home",
            expectedRoute: homeRoute,
            expectedSubroute: nil,
            expectedHomeTab: "recent",
            router: router,
            handoff: handoff,
            size: size
        ) {
            router.goHome()
        }

        let threadRoute = MessagesRoute.thread(MessagesThreadContext(thread: dmThread))
        try check(
            label: "thread",
            expectedRoute: threadRoute,
            expectedSubroute: nil,
            expectedHomeTab: nil,
            router: router,
            handoff: handoff,
            size: size
        ) {
            router.openChat(dmThread)
        }

        let relationshipRoute = MessagesRoute.relationship(MessagesThreadContext(thread: dmThread))
        try check(
            label: "relationship",
            expectedRoute: relationshipRoute,
            expectedSubroute: "relationship",
            expectedHomeTab: nil,
            router: router,
            handoff: handoff,
            size: size
        ) {
            router.openRelationship(for: dmThread)
        }

        let memoryRoute = MessagesRoute.memory(MessagesThreadContext(thread: dmThread))
        try check(
            label: "memory",
            expectedRoute: memoryRoute,
            expectedSubroute: "memory",
            expectedHomeTab: nil,
            router: router,
            handoff: handoff,
            size: size
        ) {
            router.openMemory(for: dmThread)
        }

        let quadRoleRoute = MessagesRoute.quadRole(MessagesThreadContext(thread: quadThread))
        try check(
            label: "quadRole",
            expectedRoute: quadRoleRoute,
            expectedSubroute: "quad_role",
            expectedHomeTab: nil,
            router: router,
            handoff: handoff,
            size: size
        ) {
            router.openQuadRole(for: quadThread)
        }

        let groupPlayRoute = MessagesRoute.groupPlay(MessagesThreadContext(thread: groupThread))
        try check(
            label: "groupPlay",
            expectedRoute: groupPlayRoute,
            expectedSubroute: "group_play",
            expectedHomeTab: nil,
            router: router,
            handoff: handoff,
            size: size
        ) {
            router.openGroupPlay(for: groupThread)
        }

        try check(
            label: "backHome",
            expectedRoute: homeRoute,
            expectedSubroute: nil,
            expectedHomeTab: "recent",
            router: router,
            handoff: handoff,
            size: size
        ) {
            router.goHome()
        }
    }

    private static func check(
        label: String,
        expectedRoute: MessagesRoute,
        expectedSubroute: String?,
        expectedHomeTab: String?,
        router: ConversationRouter,
        handoff: AppHandoffRouter,
        size: CGSize,
        action: () -> Void
    ) throws {
        action()

        let fittedSize = try realizeRoot(router: router, handoff: handoff, size: size)
        guard router.path == expectedRoute.canonicalStack else {
            throw SmokeError(
                "\(label) canonical stack mismatch. expected=\(stackTitles(expectedRoute.canonicalStack)) actual=\(stackTitles(router.path))"
            )
        }
        guard router.currentRoute == expectedRoute else {
            throw SmokeError("\(label) currentRoute mismatch: \(router.currentRoute.title)")
        }

        try assertHandoff(
            router.lastHandoff,
            expectedRoute: expectedRoute,
            expectedSubroute: expectedSubroute,
            expectedHomeTab: expectedHomeTab
        )

        let pathSummary = router.path.isEmpty ? "home" : stackTitles(router.path)
        print(
            "\(label): route=\(router.currentRoute.title) stack=\(pathSummary) " +
            "handoff=\(handoffSummary(router.lastHandoff)) fitted=\(Int(fittedSize.width))x\(Int(fittedSize.height))"
        )
    }

    private static func realizeRoot(
        router: ConversationRouter,
        handoff: AppHandoffRouter,
        size: CGSize
    ) throws -> CGSize {
        let rootView = AnyView(
            MessagesFeatureRootView()
                .environmentObject(router)
                .environmentObject(handoff)
                .frame(width: size.width, height: size.height, alignment: .topLeading)
        )
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = CGRect(origin: .zero, size: size)

        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
        window.contentView?.layoutSubtreeIfNeeded()
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))

        let fitted = hostingView.fittingSize
        window.close()

        guard fitted.width > 0, fitted.height > 0 else {
            throw SmokeError("MessagesFeatureRootView produced an empty layout.")
        }
        return fitted
    }

    private static func assertHandoff(
        _ handoff: CrossTabHandoff?,
        expectedRoute: MessagesRoute,
        expectedSubroute: String?,
        expectedHomeTab: String?
    ) throws {
        guard let handoff else {
            throw SmokeError("Expected a messages handoff but found nil.")
        }
        guard handoff.targetSurface == .messages else {
            throw SmokeError("Expected messages handoff target, found \(handoff.targetSurface.rawValue).")
        }
        guard case .messages(let route) = handoff.route else {
            throw SmokeError("Expected a messages handoff route.")
        }

        switch route {
        case .home(let tab):
            guard expectedRoute == .home else {
                throw SmokeError("Expected thread handoff, found home(\(tab)).")
            }
            guard expectedHomeTab == tab else {
                throw SmokeError("Expected home tab \(expectedHomeTab ?? "nil"), found \(tab).")
            }
        case .thread(let locator, let hint):
            guard let expectedThreadID = canonicalThreadID(for: expectedRoute) else {
                throw SmokeError("Expected home handoff, found thread(\(locator.canonicalThreadID)).")
            }
            guard locator.canonicalThreadID == expectedThreadID else {
                throw SmokeError("Expected thread id \(expectedThreadID), found \(locator.canonicalThreadID).")
            }
            guard hint["subroute"] == expectedSubroute else {
                throw SmokeError("Expected subroute \(expectedSubroute ?? "nil"), found \(hint["subroute"] ?? "nil").")
            }
        case .composeDraft:
            throw SmokeError("Compose draft handoff is outside the S3-092 typed route smoke.")
        }
    }

    private static func canonicalThreadID(for route: MessagesRoute) -> String? {
        switch route {
        case .home, .composeDraft:
            return nil
        case .thread(let context),
             .mask(let context),
             .relationship(let context),
             .memory(let context),
             .quadRole(let context),
             .groupPlay(let context):
            return context.canonicalThreadID
        case .groupVote(let context):
            return context.thread.canonicalThreadID
        }
    }

    private static func stackTitles(_ stack: [MessagesRoute]) -> String {
        stack.map(\.title).joined(separator: " -> ")
    }

    private static func handoffSummary(_ handoff: CrossTabHandoff?) -> String {
        guard let handoff else { return "none" }
        switch handoff.route {
        case .messages(.home(let tab)):
            return "messages.home(\(tab))"
        case .messages(.thread(let locator, let hint)):
            let suffix = hint["subroute"].map { ".\($0)" } ?? ""
            return "messages.thread(\(locator.canonicalThreadID)\(suffix))"
        case .messages(.composeDraft(let draftID, _, _)):
            return "messages.composeDraft(\(draftID))"
        case .earnSocial:
            return "earnSocial"
        case .myProfile:
            return "myProfile"
        }
    }
}

private struct SmokeError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}
SWIFT

cd "$ROOT"

SOURCES=()
while IFS= read -r file; do
  SOURCES+=("$file")
done < <(
  {
    rg --files -g '*.swift' ios/spare-life-ios-app/App/DesignSystem
    rg --files -g '*.swift' ios/spare-life-ios-app/Features/CompanionChat
    rg --files -g '*.swift' ios/spare-life-ios-app/Features/Shared
    printf '%s\n' \
      ios/spare-life-ios-app/App/AppHandoffRouter.swift \
      ios/spare-life-ios-app/App/CrossTabHandoff.swift \
      ios/spare-life-ios-app/App/ConversationRouter.swift \
      ios/spare-life-ios-app/Features/EarnSocial/EarnSocialExperienceStore.swift
  } | sort
)

xcrun swiftc \
  -target arm64-apple-macos13.0 \
  -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
  "${SOURCES[@]}" \
  "$HARNESS_SWIFT" \
  -o "$SMOKE_BIN"

"$SMOKE_BIN"
