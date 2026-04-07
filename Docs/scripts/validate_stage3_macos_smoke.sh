#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/stage3_macos_smoke.XXXXXX")"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
CONTRACT_LIB="$TMP_DIR/libStage3MacOSTargetContract.dylib"
CONTRACT_MODULE="$TMP_DIR/Stage3MacOSTargetContract.swiftmodule"
HARNESS_SWIFT="$TMP_DIR/Stage3MacOSParitySmoke.swift"
SMOKE_BIN="$TMP_DIR/stage3_macos_parity_smoke"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cat >"$HARNESS_SWIFT" <<'SWIFT'
import AppKit
import Foundation
import Stage3MacOSTargetContract
import SwiftUI

@MainActor
@main
enum Stage3MacOSParitySmoke {
    static func main() throws {
        _ = NSApplication.shared

        let expectedPageIDs = ["xianxia", "master", "earnSocial", "messages", "myProfile"]
        let mirroredPageIDs = Stage3MacOSRuntime.mirroredPages.map(\.id)
        guard mirroredPageIDs == expectedPageIDs else {
            throw SmokeError("Unexpected mirrored page order: \(mirroredPageIDs.joined(separator: ", "))")
        }

        let shellSnapshot = Stage3MacOSRuntime.desktopShellSnapshot()
        guard shellSnapshot.containerKinds.contains("sidebar"),
              shellSnapshot.containerKinds.contains("top toolbar"),
              shellSnapshot.containerKinds.contains("segmented control") else {
            throw SmokeError("Desktop shell containers drifted from the parity contract.")
        }

        let defaultSize = Stage3MacOSRuntime.desktopWindowConfiguration.defaultSize
        let minSize = Stage3MacOSRuntime.desktopWindowConfiguration.minSize
        let defaultResults = try Stage3MacOSSmokeRunner.run(size: defaultSize)
        let compactResults = try Stage3MacOSSmokeRunner.run(size: minSize)

        guard defaultResults.count == expectedPageIDs.count + 1 else {
            throw SmokeError("Default-size smoke rendered \(defaultResults.count) surfaces instead of 6.")
        }
        guard compactResults.count == expectedPageIDs.count + 1 else {
            throw SmokeError("Compact-size smoke rendered \(compactResults.count) surfaces instead of 6.")
        }

        let rootDefault = try realizeRootShell(size: defaultSize)
        let rootCompact = try realizeRootShell(size: minSize)

        print(
            "desktop-shell: containers=\(shellSnapshot.containerKinds.joined(separator: ", ")) " +
            "default=\(Int(rootDefault.width))x\(Int(rootDefault.height)) " +
            "compact=\(Int(rootCompact.width))x\(Int(rootCompact.height))"
        )

        for tabID in expectedPageIDs {
            guard let snapshot = Stage3MacOSRuntime.workspaceSnapshot(for: tabID) else {
                throw SmokeError("Missing workspace snapshot for \(tabID).")
            }
            guard snapshot.columnKinds.count >= 3 else {
                throw SmokeError("Workspace \(tabID) no longer keeps a multi-column desktop layout.")
            }
            guard !snapshot.panelRules.isEmpty else {
                throw SmokeError("Workspace \(tabID) lost its panel rules.")
            }

            print(
                "workspace \(tabID): layout=\(snapshot.layoutStyle) " +
                "columns=\(snapshot.columnKinds.joined(separator: " | "))"
            )
        }

        let threads = ConversationHubStore.mockThreads()
        guard let dmThread = threads.first(where: { $0.kind == .human }) else {
            throw SmokeError("Missing DM thread for macOS messages workspace smoke.")
        }

        let router = ConversationRouter()
        let handoff = AppHandoffRouter()
        let messagesSize = CGSize(width: 1320, height: 860)

        let homeRoute = MessagesRoute.home
        try checkMessagesWorkspace(
            label: "messages-home",
            expectedRoute: homeRoute,
            expectedSubroute: nil,
            expectedHomeTab: "recent",
            router: router,
            handoff: handoff,
            size: messagesSize
        ) {
            router.goHome()
        }

        let threadRoute = MessagesRoute.thread(MessagesThreadContext(thread: dmThread))
        try checkMessagesWorkspace(
            label: "messages-thread",
            expectedRoute: threadRoute,
            expectedSubroute: nil,
            expectedHomeTab: nil,
            router: router,
            handoff: handoff,
            size: messagesSize
        ) {
            router.openChat(dmThread)
        }

        let relationshipRoute = MessagesRoute.relationship(MessagesThreadContext(thread: dmThread))
        try checkMessagesWorkspace(
            label: "messages-relationship",
            expectedRoute: relationshipRoute,
            expectedSubroute: "relationship",
            expectedHomeTab: nil,
            router: router,
            handoff: handoff,
            size: messagesSize
        ) {
            router.openRelationship(for: dmThread)
        }

        try checkMessagesWorkspace(
            label: "messages-back-home",
            expectedRoute: homeRoute,
            expectedSubroute: nil,
            expectedHomeTab: "recent",
            router: router,
            handoff: handoff,
            size: messagesSize
        ) {
            router.goHome()
        }

        let defaultSummary = defaultResults.map(\.id).joined(separator: ", ")
        let compactSummary = compactResults.map(\.id).joined(separator: ", ")
        print("surfaces default: \(defaultSummary)")
        print("surfaces compact: \(compactSummary)")
    }

    private static func realizeRootShell(size: CGSize) throws -> CGSize {
        Stage3MacOSAppState.shared.selectTab(Stage3MacOSRuntime.defaultSelectedTabID)
        return try realize(
            AnyView(
                Stage3MacOSDesktopShellView(initialTabID: Stage3MacOSRuntime.defaultSelectedTabID)
            ),
            size: size,
            settle: 0.35
        )
    }

    private static func checkMessagesWorkspace(
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
        let fitted = try realize(
            AnyView(
                Stage3MacOSMessagesWorkspaceView()
                    .environmentObject(router)
                    .environmentObject(handoff)
            ),
            size: size,
            settle: 0.95
        )

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
            "handoff=\(handoffSummary(router.lastHandoff)) fitted=\(Int(fitted.width))x\(Int(fitted.height))"
        )
    }

    private static func realize(
        _ view: AnyView,
        size: CGSize,
        settle: TimeInterval
    ) throws -> CGSize {
        let hostingView = NSHostingView(
            rootView: AnyView(
                view.frame(width: size.width, height: size.height, alignment: .topLeading)
            )
        )
        hostingView.frame = CGRect(origin: .zero, size: size)

        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.setContentSize(size)
        window.contentView = hostingView
        window.contentView?.layoutSubtreeIfNeeded()
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(settle))

        let fitted = hostingView.fittingSize
        window.close()

        guard fitted.width > 0, fitted.height > 0 else {
            throw SmokeError("A macOS smoke surface produced an empty layout.")
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
            throw SmokeError("Compose draft handoff is outside the S3-093 macOS smoke.")
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

CONTRACT_SOURCES=()
while IFS= read -r file; do
  CONTRACT_SOURCES+=("$file")
done < <(rg --files -g '*.swift' app/macos/Sources/Stage3MacOSTargetContract | sort)

xcrun swiftc \
  -target arm64-apple-macos13.0 \
  -sdk "$SDK_PATH" \
  -parse-as-library \
  -emit-library \
  -emit-module \
  -module-name Stage3MacOSTargetContract \
  "${CONTRACT_SOURCES[@]}" \
  -emit-module-path "$CONTRACT_MODULE" \
  -o "$CONTRACT_LIB"

RUNTIME_SOURCES=()
while IFS= read -r file; do
  case "$file" in
    app/macos/Sources/Stage3MacOSRuntime/Stage3MacOSHostResources.swift|\
    app/macos/Shared/SpareLifeCoreSource/App/MainTabView.swift|\
    app/macos/Shared/SpareLifeCoreSource/Features/EarnSocial/LeadResultView.swift|\
    app/macos/Shared/SpareLifeCoreSource/Features/CompanionChat/ChatThreadView.swift|\
    app/macos/Shared/SpareLifeCoreSource/Features/CompanionChat/QuadRoleChatView.swift|\
    app/macos/Shared/SpareLifeCoreSource/Features/Xianxia/QRScanView.swift)
      continue
      ;;
  esac
  RUNTIME_SOURCES+=("$file")
done < <(
  {
    rg --files -g '*.swift' app/macos/Sources/Stage3MacOSRuntime
    rg --files -g '*.swift' app/macos/Shared/SpareLifeCoreSource/App/DesignSystem
    printf '%s\n' \
      app/macos/Shared/SpareLifeCoreSource/App/AppHandoffRouter.swift \
      app/macos/Shared/SpareLifeCoreSource/App/CrossTabHandoff.swift \
      app/macos/Shared/SpareLifeCoreSource/App/ConversationRouter.swift \
      app/macos/Shared/SpareLifeCoreSource/Domain/Models/SceneModels.swift
    rg --files -g '*.swift' app/macos/Shared/SpareLifeCoreSource/Features/CompanionChat
    rg --files -g '*.swift' app/macos/Shared/SpareLifeCoreSource/Features/EarnSocial
    rg --files -g '*.swift' app/macos/Shared/SpareLifeCoreSource/Features/Infrastructure
    rg --files -g '*.swift' app/macos/Shared/SpareLifeCoreSource/Features/Masters
    rg --files -g '*.swift' app/macos/Shared/SpareLifeCoreSource/Features/MyProfile
    rg --files -g '*.swift' app/macos/Shared/SpareLifeCoreSource/Features/Shared
    rg --files -g '*.swift' app/macos/Shared/SpareLifeCoreSource/Features/Xianxia
  } | sort
)

xcrun swiftc \
  -target arm64-apple-macos13.0 \
  -sdk "$SDK_PATH" \
  -I "$TMP_DIR" \
  -L "$TMP_DIR" \
  -lStage3MacOSTargetContract \
  "${RUNTIME_SOURCES[@]}" \
  "$HARNESS_SWIFT" \
  -o "$SMOKE_BIN"

DYLD_LIBRARY_PATH="$TMP_DIR${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}" "$SMOKE_BIN"
