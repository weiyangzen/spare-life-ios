import SwiftUI

public struct Stage3MacOSToolbarFilterOption: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let systemImage: String

    public init(id: String, title: String, systemImage: String) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
    }
}

public struct Stage3MacOSDesktopToolbarSnapshot: Equatable, Sendable {
    public let activeWorkspaceID: String
    public let searchPrompt: String?
    public let filterOptionIDs: [String]
    public let selectedFilterID: String?
    public let actionKinds: [String]
    public let shellSidebarVisible: Bool
    public let inspectorVisible: Bool

    public init(
        activeWorkspaceID: String,
        searchPrompt: String?,
        filterOptionIDs: [String],
        selectedFilterID: String?,
        actionKinds: [String],
        shellSidebarVisible: Bool,
        inspectorVisible: Bool
    ) {
        self.activeWorkspaceID = activeWorkspaceID
        self.searchPrompt = searchPrompt
        self.filterOptionIDs = filterOptionIDs
        self.selectedFilterID = selectedFilterID
        self.actionKinds = actionKinds
        self.shellSidebarVisible = shellSidebarVisible
        self.inspectorVisible = inspectorVisible
    }
}

public struct Stage3MacOSVisualParitySnapshot: Equatable, Sendable {
    public let paletteKinds: [String]
    public let cardSurfaceKinds: [String]
    public let copyAndStatusKinds: [String]
    public let desktopOptimizations: [String]

    public init(
        paletteKinds: [String],
        cardSurfaceKinds: [String],
        copyAndStatusKinds: [String],
        desktopOptimizations: [String]
    ) {
        self.paletteKinds = paletteKinds
        self.cardSurfaceKinds = cardSurfaceKinds
        self.copyAndStatusKinds = copyAndStatusKinds
        self.desktopOptimizations = desktopOptimizations
    }
}

@MainActor
public final class Stage3MacOSWorkspaceChrome: ObservableObject {
    public static let shared = Stage3MacOSWorkspaceChrome()

    @Published public private(set) var activeWorkspaceID = Stage3MacOSRuntime.defaultSelectedTabID
    @Published public private(set) var searchPrompt: String?
    @Published public var searchText = ""
    @Published public private(set) var filterOptions: [Stage3MacOSToolbarFilterOption] = []
    @Published public private(set) var selectedFilterID: String?
    @Published public private(set) var refreshLabel = "刷新当前工作区"
    @Published public private(set) var canRefresh = true
    @Published public private(set) var canToggleInspector = true
    @Published public var isShellSidebarVisible = true
    @Published public var isInspectorVisible = true
    @Published public var refreshRequestSerial = 0

    private init() {}

    public var selectedFilterTitle: String? {
        filterOptions.first(where: { $0.id == selectedFilterID })?.title
    }

    public func configure(
        workspaceID: String,
        searchPrompt: String?,
        searchText: String,
        filterOptions: [Stage3MacOSToolbarFilterOption],
        selectedFilterID: String?,
        refreshLabel: String,
        canRefresh: Bool = true,
        canToggleInspector: Bool = true
    ) {
        activeWorkspaceID = Stage3MacOSRuntime.resolvedTabID(workspaceID)
        self.searchPrompt = searchPrompt
        if self.searchText != searchText {
            self.searchText = searchText
        }
        self.filterOptions = filterOptions
        self.selectedFilterID = selectedFilterID
        self.refreshLabel = refreshLabel
        self.canRefresh = canRefresh
        self.canToggleInspector = canToggleInspector
    }

    public func prepare(for workspaceID: String) {
        configure(
            workspaceID: workspaceID,
            searchPrompt: nil,
            searchText: "",
            filterOptions: [],
            selectedFilterID: nil,
            refreshLabel: "刷新 \(Stage3MacOSRuntime.pageDescriptor(for: workspaceID)?.label ?? "当前工作区")"
        )
    }

    public func requestRefresh() {
        refreshRequestSerial += 1
    }

    public func selectFilter(_ filterID: String?) {
        selectedFilterID = filterID
    }

    public func toggleShellSidebar() {
        isShellSidebarVisible.toggle()
    }

    public func toggleInspector() {
        guard canToggleInspector else { return }
        isInspectorVisible.toggle()
    }

    public func snapshot() -> Stage3MacOSDesktopToolbarSnapshot {
        Stage3MacOSDesktopToolbarSnapshot(
            activeWorkspaceID: activeWorkspaceID,
            searchPrompt: searchPrompt,
            filterOptionIDs: filterOptions.map(\.id),
            selectedFilterID: selectedFilterID,
            actionKinds: [
                "toggle sidebar",
                "workspace picker",
                "workspace search",
                "workspace filter",
                "refresh",
                "diagnostics",
                "toggle inspector"
            ],
            shellSidebarVisible: isShellSidebarVisible,
            inspectorVisible: isInspectorVisible
        )
    }
}

extension Stage3MacOSRuntime {
    public static func visualParitySnapshot() -> Stage3MacOSVisualParitySnapshot {
        Stage3MacOSVisualParitySnapshot(
            paletteKinds: [
                "shared spareYellow accent",
                "shared card stroke neutrals",
                "shared semantic status colors"
            ],
            cardSurfaceKinds: [
                "white rounded cards",
                "yellow-tinted workspace chrome",
                "shared capsule badges"
            ],
            copyAndStatusKinds: [
                "shared Chinese product copy",
                "shared module boundary labels",
                "shared empty/loading/error semantics"
            ],
            desktopOptimizations: [
                "toolbar search and filter",
                "collapsible sidebar and inspector",
                "parallel workspaces instead of mobile-first modal stacking"
            ]
        )
    }
}
