public struct Stage3MacOSTarget: Sendable, Equatable {
    public let uiBase: String
    public let replicationScope: [String]
    public let allowedShellContainers: [String]
    public let invariants: [String]
    public let forbiddenDivergence: [String]
    public let canonicalTabs: [Stage3RuntimeTab]

    public init(
        uiBase: String,
        replicationScope: [String],
        allowedShellContainers: [String],
        invariants: [String],
        forbiddenDivergence: [String],
        canonicalTabs: [Stage3RuntimeTab]
    ) {
        self.uiBase = uiBase
        self.replicationScope = replicationScope
        self.allowedShellContainers = allowedShellContainers
        self.invariants = invariants
        self.forbiddenDivergence = forbiddenDivergence
        self.canonicalTabs = canonicalTabs
    }
}

public struct Stage3RuntimeTab: Sendable, Equatable {
    public let id: String
    public let label: String
    public let rootView: String

    public init(id: String, label: String, rootView: String) {
        self.id = id
        self.label = label
        self.rootView = rootView
    }
}

extension Stage3MacOSTarget {
    public static let stage3 = Stage3MacOSTarget(
        uiBase: "iOS / iPad landscape",
        replicationScope: [
            "visual replication",
            "information architecture replication",
            "desktop interaction optimization"
        ],
        allowedShellContainers: [
            "sidebar",
            "top toolbar",
            "segmented control",
            "multi-column workspace"
        ],
        invariants: [
            "mirror the current iOS / iPad landscape visual language before inventing new desktop-only surfaces",
            "keep the current tab order, entry semantics, and shared runtime truth aligned with ios/spare-life-ios-app",
            "constrain desktop changes to shell, container, and interaction layers",
            "treat hover, keyboard, windowing, and context menus as optimizations on top of the same information architecture"
        ],
        forbiddenDivergence: [
            "a separate macOS information architecture",
            "feature logic forks that bypass shared runtime truth",
            "copying a second macOS-only page tree under app/macos",
            "rewriting labels, module order, or root routes independently from MainTabView"
        ],
        canonicalTabs: [
            Stage3RuntimeTab(id: "xianxia", label: "闲虾", rootView: "XianxiaHomeView"),
            Stage3RuntimeTab(id: "master", label: "闲聊", rootView: "MasterChatHomeView"),
            Stage3RuntimeTab(id: "earnSocial", label: "赚闲能", rootView: "EarnSocialHomeView"),
            Stage3RuntimeTab(id: "messages", label: "消息", rootView: "ConversationHubView"),
            Stage3RuntimeTab(id: "myProfile", label: "我的", rootView: "MyProfileView")
        ]
    )
}
