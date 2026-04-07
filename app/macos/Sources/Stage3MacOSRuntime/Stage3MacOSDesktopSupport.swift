import AppKit
import Combine
import SwiftUI

public struct Stage3MacOSWindowConfiguration: Equatable, Sendable {
    public let id: String
    public let autosaveName: String
    public let defaultSize: CGSize
    public let minSize: CGSize

    public init(id: String, autosaveName: String, defaultSize: CGSize, minSize: CGSize) {
        self.id = id
        self.autosaveName = autosaveName
        self.defaultSize = defaultSize
        self.minSize = minSize
    }
}

public struct Stage3MacOSDesktopInteractionSnapshot: Equatable, Sendable {
    public let hoverSurfaces: [String]
    public let contextMenuSurfaces: [String]
    public let keyboardShortcuts: [String]
    public let commandMenus: [String]

    public init(
        hoverSurfaces: [String],
        contextMenuSurfaces: [String],
        keyboardShortcuts: [String],
        commandMenus: [String]
    ) {
        self.hoverSurfaces = hoverSurfaces
        self.contextMenuSurfaces = contextMenuSurfaces
        self.keyboardShortcuts = keyboardShortcuts
        self.commandMenus = commandMenus
    }
}

public struct Stage3MacOSWorkspaceCommandItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let tabID: String
    public let key: Int

    public init(id: String, title: String, tabID: String, key: Int) {
        self.id = id
        self.title = title
        self.tabID = tabID
        self.key = key
    }
}

public struct Stage3MacOSDiagnosticCommandItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let pageID: String
    public let key: Int

    public init(id: String, title: String, pageID: String, key: Int) {
        self.id = id
        self.title = title
        self.pageID = pageID
        self.key = key
    }
}

@MainActor
public final class Stage3MacOSAppState: ObservableObject {
    private enum DefaultsKey: String {
        case selectedTabID = "stage3.macos.state.selectedTabID"
        case infrastructureToolID = "stage3.macos.state.infrastructureToolID"
    }

    public static let shared = Stage3MacOSAppState()

    private let defaults: UserDefaults

    @Published public var selectedTabID: String
    @Published public var infrastructureToolID: String
    @Published public var pendingDiagnosticPageID: String?
    @Published public var diagnosticOpenRequestSerial: Int = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.selectedTabID = Stage3MacOSRuntime.resolvedTabID(
            defaults.string(forKey: DefaultsKey.selectedTabID.rawValue)
                ?? Stage3MacOSRuntime.defaultSelectedTabID
        )
        self.infrastructureToolID = Self.normalizedInfrastructureToolID(
            defaults.string(forKey: DefaultsKey.infrastructureToolID.rawValue)
                ?? Stage3MacOSRuntime.openClawDiagnosticPageID
        )
    }

    public func selectTab(_ tabID: String) {
        let resolved = Stage3MacOSRuntime.resolvedTabID(tabID)
        guard selectedTabID != resolved else { return }
        selectedTabID = resolved
        defaults.set(resolved, forKey: DefaultsKey.selectedTabID.rawValue)
    }

    public func selectInfrastructureTool(_ toolID: String) {
        let resolved = Self.normalizedInfrastructureToolID(toolID)
        guard infrastructureToolID != resolved else { return }
        infrastructureToolID = resolved
        defaults.set(resolved, forKey: DefaultsKey.infrastructureToolID.rawValue)
    }

    public func requestDiagnosticWindow(_ pageID: String) {
        let resolved = Stage3MacOSRuntime.resolvedDiagnosticPageID(pageID)
        if resolved != Stage3MacOSRuntime.infrastructureWorkspacePageID {
            selectInfrastructureTool(resolved)
        }
        pendingDiagnosticPageID = resolved
        diagnosticOpenRequestSerial += 1
    }

    private static func normalizedInfrastructureToolID(_ value: String) -> String {
        let resolved = Stage3MacOSRuntime.resolvedDiagnosticPageID(value)
        if resolved == Stage3MacOSRuntime.infrastructureWorkspacePageID {
            return Stage3MacOSRuntime.openClawDiagnosticPageID
        }
        return resolved
    }
}

public enum Stage3MacOSPasteboard {
    public static func copy(_ value: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
    }
}

extension Stage3MacOSRuntime {
    public static let workspaceCommandItems: [Stage3MacOSWorkspaceCommandItem] = mirroredPages.enumerated().map {
        index,
        page in
        Stage3MacOSWorkspaceCommandItem(
            id: "workspace.\(page.id)",
            title: page.label,
            tabID: page.id,
            key: index + 1
        )
    }

    public static let diagnosticCommandItems: [Stage3MacOSDiagnosticCommandItem] = diagnosticPages.enumerated().map {
        index,
        page in
        Stage3MacOSDiagnosticCommandItem(
            id: "diagnostic.\(page.id)",
            title: page.label,
            pageID: page.id,
            key: index + 1
        )
    }

    public static let desktopWindowConfiguration = Stage3MacOSWindowConfiguration(
        id: "desktopShell",
        autosaveName: "stage3.macos.window.desktopShell",
        defaultSize: CGSize(width: 1440, height: 920),
        minSize: CGSize(width: 1180, height: 780)
    )

    public static func windowConfiguration(for pageID: String) -> Stage3MacOSWindowConfiguration {
        switch resolvedDiagnosticPageID(pageID) {
        case infrastructureWorkspacePageID:
            return Stage3MacOSWindowConfiguration(
                id: infrastructureWorkspacePageID,
                autosaveName: "stage3.macos.window.infrastructure",
                defaultSize: CGSize(width: 1520, height: 920),
                minSize: CGSize(width: 1260, height: 820)
            )
        case openClawDiagnosticPageID:
            return Stage3MacOSWindowConfiguration(
                id: openClawDiagnosticPageID,
                autosaveName: "stage3.macos.window.openClaw",
                defaultSize: CGSize(width: 1520, height: 920),
                minSize: CGSize(width: 1260, height: 820)
            )
        case sqliteDiagnosticPageID:
            return Stage3MacOSWindowConfiguration(
                id: sqliteDiagnosticPageID,
                autosaveName: "stage3.macos.window.sqlite",
                defaultSize: CGSize(width: 1440, height: 900),
                minSize: CGSize(width: 1180, height: 820)
            )
        case securityDiagnosticPageID:
            return Stage3MacOSWindowConfiguration(
                id: securityDiagnosticPageID,
                autosaveName: "stage3.macos.window.security",
                defaultSize: CGSize(width: 1360, height: 880),
                minSize: CGSize(width: 1120, height: 780)
            )
        case memoryMatchingDiagnosticPageID:
            return Stage3MacOSWindowConfiguration(
                id: memoryMatchingDiagnosticPageID,
                autosaveName: "stage3.macos.window.memoryMatching",
                defaultSize: CGSize(width: 1360, height: 880),
                minSize: CGSize(width: 1120, height: 780)
            )
        default:
            return desktopWindowConfiguration
        }
    }

    public static func splitAutosaveName(for name: String) -> String {
        "stage3.macos.split.\(name)"
    }

    public static func desktopInteractionSnapshot() -> Stage3MacOSDesktopInteractionSnapshot {
        let workspaceShortcuts = workspaceCommandItems.map { item in
            "cmd+\(item.key) -> \(item.tabID)"
        }
        let diagnosticShortcuts = diagnosticCommandItems.map { item in
            "cmd+option+\(item.key) -> \(item.pageID)"
        }

        return Stage3MacOSDesktopInteractionSnapshot(
            hoverSurfaces: [
                "desktop.sidebar",
                "masters.directory.card",
                "messages.thread.row",
                "infrastructure.tool.card",
                "profile.dashboard.tile"
            ],
            contextMenuSurfaces: [
                "desktop.sidebar",
                "messages.thread.row",
                "masters.directory.card",
                "masters.recent.session",
                "infrastructure.tool.card"
            ],
            keyboardShortcuts: workspaceShortcuts + diagnosticShortcuts,
            commandMenus: ["Workspace", "Infrastructure"]
        )
    }
}

@MainActor
public struct Stage3MacOSWorkspaceCommands: Commands {
    @ObservedObject private var appState = Stage3MacOSAppState.shared
    @Environment(\.openWindow) private var openWindow

    public init() {}

    public var body: some Commands {
        CommandMenu("Workspace") {
            ForEach(Stage3MacOSRuntime.workspaceCommandItems) { item in
                Button(item.title) {
                    appState.selectTab(item.tabID)
                }
                .keyboardShortcut(
                    KeyEquivalent(Character(String(item.key))),
                    modifiers: [.command]
                )
            }
        }

        CommandMenu("Infrastructure") {
            ForEach(Stage3MacOSRuntime.diagnosticCommandItems) { item in
                Button(item.title) {
                    if item.pageID == Stage3MacOSRuntime.infrastructureWorkspacePageID {
                        openWindow(id: item.pageID)
                    } else {
                        appState.selectInfrastructureTool(item.pageID)
                        openWindow(id: item.pageID)
                    }
                }
                .keyboardShortcut(
                    KeyEquivalent(Character(String(item.key))),
                    modifiers: [.command, .option]
                )
            }
        }
    }
}

private struct Stage3MacOSWindowProbe: NSViewRepresentable {
    let configuration: Stage3MacOSWindowConfiguration

    func makeNSView(context: Context) -> ProbeView {
        ProbeView(configuration: configuration)
    }

    func updateNSView(_ nsView: ProbeView, context: Context) {
        nsView.configuration = configuration
    }

    final class ProbeView: NSView {
        var configuration: Stage3MacOSWindowConfiguration {
            didSet {
                applyIfPossible()
            }
        }

        init(configuration: Stage3MacOSWindowConfiguration) {
            self.configuration = configuration
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            applyIfPossible()
        }

        private func applyIfPossible() {
            guard let window else {
                DispatchQueue.main.async { [weak self] in
                    self?.applyIfPossible()
                }
                return
            }

            window.minSize = configuration.minSize
            if window.frameAutosaveName != configuration.autosaveName {
                let restored = window.setFrameUsingName(configuration.autosaveName)
                window.setFrameAutosaveName(configuration.autosaveName)
                if !restored {
                    window.setContentSize(configuration.defaultSize)
                    window.center()
                }
            }
        }
    }
}

private struct Stage3MacOSSplitViewProbe: NSViewRepresentable {
    let autosaveName: String

    func makeNSView(context: Context) -> ProbeView {
        ProbeView(autosaveName: autosaveName)
    }

    func updateNSView(_ nsView: ProbeView, context: Context) {
        nsView.autosaveName = autosaveName
    }

    final class ProbeView: NSView {
        var autosaveName: String {
            didSet {
                applyIfPossible()
            }
        }

        init(autosaveName: String) {
            self.autosaveName = autosaveName
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            applyIfPossible()
        }

        private func applyIfPossible() {
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      let rootView = self.window?.contentView,
                      let splitView = self.findSplitView(in: rootView) else {
                    return
                }

                if splitView.autosaveName != self.autosaveName {
                    splitView.autosaveName = self.autosaveName
                }
            }
        }

        private func findSplitView(in view: NSView) -> NSSplitView? {
            if let splitView = view as? NSSplitView {
                return splitView
            }

            for subview in view.subviews {
                if let splitView = findSplitView(in: subview) {
                    return splitView
                }
            }

            return nil
        }
    }
}

private struct Stage3MacOSHoverLiftModifier: ViewModifier {
    @State private var isHovered = false

    let enabled: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(enabled && isHovered ? 1.01 : 1.0)
            .shadow(
                color: enabled && isHovered ? Color.black.opacity(0.08) : Color.clear,
                radius: 14,
                y: 6
            )
            .animation(.easeOut(duration: 0.16), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

public extension View {
    func stage3WindowConfiguration(_ configuration: Stage3MacOSWindowConfiguration) -> some View {
        background(Stage3MacOSWindowProbe(configuration: configuration))
    }

    func stage3SplitAutosave(_ name: String) -> some View {
        background(Stage3MacOSSplitViewProbe(autosaveName: Stage3MacOSRuntime.splitAutosaveName(for: name)))
    }

    func stage3HoverLift(enabled: Bool = true) -> some View {
        modifier(Stage3MacOSHoverLiftModifier(enabled: enabled))
    }
}
