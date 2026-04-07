import AppKit
import Stage3MacOSTargetContract
import SwiftUI

public struct Stage3MacOSMirroredPageDescriptor: Identifiable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let rootView: String

    public init(id: String, label: String, rootView: String) {
        self.id = id
        self.label = label
        self.rootView = rootView
    }
}

public struct Stage3MacOSSharedRootView: View {
    public init() {}

    public var body: some View {
        Stage3MacOSDesktopShellView()
    }
}

public struct Stage3MacOSMirroredPageView: View {
    public let tabID: String

    public init(tabID: String) {
        self.tabID = tabID
    }

    @ViewBuilder
    public var body: some View {
        switch tabID {
        case "xianxia":
            Stage3MacOSXianxiaWorkspaceView()
        case "master":
            Stage3MacOSMastersWorkspaceView()
        case "earnSocial":
            EarnSocialHomeView()
        case "messages":
            Stage3MacOSMessagesWorkspaceView()
        case "myProfile":
            MyProfileView()
        default:
            Text("Unsupported macOS mirrored page: \(tabID)")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

@MainActor
public enum Stage3MacOSRuntime {
    public static let rootViewName = "Stage3MacOSDesktopShellView"
    public static let shellContainerKinds = ["sidebar", "top toolbar", "segmented control"]
    public static let messagesTabID = "messages"

    public static let mirroredPages: [Stage3MacOSMirroredPageDescriptor] = Stage3MacOSTarget.stage3.canonicalTabs.map {
        Stage3MacOSMirroredPageDescriptor(id: $0.id, label: $0.label, rootView: $0.rootView)
    }

    public static let defaultSelectedTabID = mirroredPages.first?.id ?? "xianxia"

    public static func desktopShellSnapshot(
        selectedTabID: String = defaultSelectedTabID
    ) -> Stage3MacOSDesktopShellSnapshot {
        let resolvedTabID = resolvedTabID(selectedTabID)
        let moduleOrder = mirroredPages.map(\.id)

        return Stage3MacOSDesktopShellSnapshot(
            rootView: rootViewName,
            containerKinds: shellContainerKinds,
            sidebarModuleOrder: moduleOrder,
            segmentedControlOrder: moduleOrder,
            selectedTabID: resolvedTabID,
            entryPath: ["root", resolvedTabID]
        )
    }

    public static func rootHostingView(
        size: CGSize = CGSize(width: 1280, height: 900)
    ) -> NSHostingView<AnyView> {
        makeHostingView(for: AnyView(Stage3MacOSSharedRootView()), size: size)
    }

    public static func pageHostingView(
        for tabID: String,
        size: CGSize = CGSize(width: 1280, height: 900)
    ) -> NSHostingView<AnyView>? {
        guard mirroredPages.contains(where: { $0.id == tabID }) else {
            return nil
        }

        let rootView: AnyView
        if tabID == messagesTabID {
            rootView = AnyView(
                Stage3MacOSMirroredPageView(tabID: tabID)
                    .environmentObject(ConversationRouter())
            )
        } else {
            rootView = AnyView(Stage3MacOSMirroredPageView(tabID: tabID))
        }

        return makeHostingView(for: rootView, size: size)
    }

    public static func pageDescriptor(for tabID: String) -> Stage3MacOSMirroredPageDescriptor? {
        mirroredPages.first(where: { $0.id == tabID })
    }

    public static func resolvedTabID(_ tabID: String) -> String {
        pageDescriptor(for: tabID)?.id ?? defaultSelectedTabID
    }

    public static func shellSymbol(for tabID: String) -> String {
        switch tabID {
        case "xianxia":
            return "rectangle.grid.1x2"
        case "master":
            return "graduationcap"
        case "earnSocial":
            return "bolt.circle.fill"
        case "messages":
            return "message"
        case "myProfile":
            return "person.crop.circle"
        default:
            return "square.grid.2x2"
        }
    }

    static func makeHostingView(
        for view: AnyView,
        size: CGSize
    ) -> NSHostingView<AnyView> {
        let framedView = AnyView(
            view
                .frame(width: size.width, height: size.height, alignment: .topLeading)
        )
        let hostingView = NSHostingView(rootView: framedView)
        hostingView.frame = CGRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()
        return hostingView
    }
}
