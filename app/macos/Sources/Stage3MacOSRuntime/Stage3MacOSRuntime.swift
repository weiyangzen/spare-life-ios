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
        MainTabView()
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
            XianxiaHomeView()
        case "master":
            MasterChatHomeView()
        case "earnSocial":
            EarnSocialHomeView()
        case "messages":
            ConversationHubView()
                .environmentObject(ConversationRouter())
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
    public static let mirroredPages: [Stage3MacOSMirroredPageDescriptor] = Stage3MacOSTarget.stage3.canonicalTabs.map {
        Stage3MacOSMirroredPageDescriptor(id: $0.id, label: $0.label, rootView: $0.rootView)
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

        return makeHostingView(for: AnyView(Stage3MacOSMirroredPageView(tabID: tabID)), size: size)
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
