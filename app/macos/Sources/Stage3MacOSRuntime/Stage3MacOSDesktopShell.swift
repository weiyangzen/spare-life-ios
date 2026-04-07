import AppKit
import SwiftUI

public struct Stage3MacOSDesktopShellSnapshot: Equatable, Sendable {
    public let rootView: String
    public let containerKinds: [String]
    public let sidebarModuleOrder: [String]
    public let segmentedControlOrder: [String]
    public let selectedTabID: String
    public let entryPath: [String]
    public let toolbarActionKinds: [String]
    public let searchEntryKind: String

    public init(
        rootView: String,
        containerKinds: [String],
        sidebarModuleOrder: [String],
        segmentedControlOrder: [String],
        selectedTabID: String,
        entryPath: [String],
        toolbarActionKinds: [String],
        searchEntryKind: String
    ) {
        self.rootView = rootView
        self.containerKinds = containerKinds
        self.sidebarModuleOrder = sidebarModuleOrder
        self.segmentedControlOrder = segmentedControlOrder
        self.selectedTabID = selectedTabID
        self.entryPath = entryPath
        self.toolbarActionKinds = toolbarActionKinds
        self.searchEntryKind = searchEntryKind
    }
}

public struct Stage3MacOSDesktopShellView: View {
    @ObservedObject private var appState = Stage3MacOSAppState.shared
    @ObservedObject private var chrome = Stage3MacOSWorkspaceChrome.shared
    @Environment(\.openWindow) private var openWindow
    @State private var selectedTabID: String
    @StateObject private var router = ConversationRouter()
    @StateObject private var handoffRouter = AppHandoffRouter()

    public init(initialTabID: String = Stage3MacOSRuntime.defaultSelectedTabID) {
        _selectedTabID = State(initialValue: Stage3MacOSRuntime.resolvedTabID(initialTabID))
    }

    private var activeTabID: String {
        Stage3MacOSRuntime.resolvedTabID(selectedTabID)
    }

    private var activePage: Stage3MacOSMirroredPageDescriptor {
        Stage3MacOSRuntime.pageDescriptor(for: activeTabID) ?? Stage3MacOSRuntime.mirroredPages[0]
    }

    private var shellSnapshot: Stage3MacOSDesktopShellSnapshot {
        Stage3MacOSRuntime.desktopShellSnapshot(selectedTabID: activeTabID)
    }

    public var body: some View {
        HSplitView {
            if chrome.isShellSidebarVisible {
                sidebar
            }
            detail
        }
        .stage3SplitAutosave("desktopShell")
        .frame(minWidth: 1120, minHeight: 760)
        .background(Color(nsColor: .windowBackgroundColor))
        .environmentObject(router)
        .environmentObject(handoffRouter)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    chrome.toggleShellSidebar()
                } label: {
                    Image(systemName: chrome.isShellSidebarVisible ? "sidebar.leading" : "sidebar.right")
                        .foregroundStyle(.primary)
                }
                .help(chrome.isShellSidebarVisible ? "收起模块侧栏" : "显示模块侧栏")
            }

            ToolbarItem(placement: .automatic) {
                Label("Spare Life", systemImage: "macwindow.on.rectangle")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            ToolbarItem(placement: .principal) {
                Picker("模块", selection: $selectedTabID) {
                    ForEach(Stage3MacOSRuntime.mirroredPages) { page in
                        Text(page.label)
                            .tag(page.id)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(minWidth: 420)
            }

            ToolbarItemGroup(placement: .primaryAction) {
                toolbarSearchField
                toolbarFilterMenu

                if chrome.canRefresh {
                    Button {
                        chrome.requestRefresh()
                    } label: {
                        Label(chrome.refreshLabel, systemImage: "arrow.clockwise")
                    }
                    .help(chrome.refreshLabel)
                }

                Menu {
                    ForEach(Stage3MacOSRuntime.diagnosticPages) { page in
                        Button(page.label) {
                            if page.id == Stage3MacOSRuntime.infrastructureWorkspacePageID {
                                openWindow(id: page.id)
                            } else {
                                appState.selectInfrastructureTool(page.id)
                                openWindow(id: page.id)
                            }
                        }
                    }
                } label: {
                    Label("诊断", systemImage: "wrench.and.screwdriver.fill")
                }
                .help("打开诊断工具窗口")

                if chrome.canToggleInspector {
                    Button {
                        chrome.toggleInspector()
                    } label: {
                        Image(systemName: chrome.isInspectorVisible ? "sidebar.trailing" : "sidebar.right")
                    }
                    .help(chrome.isInspectorVisible ? "收起 Inspector" : "显示 Inspector")
                }
            }
        }
        .onChange(of: router.handoffSerial) { _ in
            guard router.lastRequestedRoute != .home else { return }
            guard activeTabID != Stage3MacOSRuntime.messagesTabID else { return }

            withAnimation(.spareSpring) {
                selectedTabID = Stage3MacOSRuntime.messagesTabID
            }
        }
        .onAppear {
            let restoredTabID = appState.selectedTabID
            if selectedTabID != restoredTabID {
                selectedTabID = restoredTabID
            }
            chrome.prepare(for: activeTabID)
        }
        .onChange(of: selectedTabID) { tabID in
            appState.selectTab(tabID)
            chrome.prepare(for: tabID)
        }
        .onChange(of: appState.selectedTabID) { tabID in
            if selectedTabID != tabID {
                selectedTabID = tabID
            }
        }
    }

    @ViewBuilder
    private var toolbarSearchField: some View {
        if let searchPrompt = chrome.searchPrompt {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(searchPrompt, text: $chrome.searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 7)
            .frame(width: 248)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.spareYellow.opacity(0.22), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private var toolbarFilterMenu: some View {
        if !chrome.filterOptions.isEmpty {
            let title = chrome.selectedFilterTitle ?? "筛选"

            Menu {
                ForEach(chrome.filterOptions) { option in
                    Button {
                        chrome.selectFilter(option.id)
                    } label: {
                        Label(option.title, systemImage: option.systemImage)
                    }
                }
            } label: {
                Label(title, systemImage: "line.3.horizontal.decrease.circle")
            }
            .help("切换当前工作区筛选")
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Spare Life")
                    .font(.spareTitle3)
                    .foregroundColor(.primary)

                Text("桌面壳层保持与 iOS 一致的模块 IA 与进入语义。")
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.lg)

            Divider()
                .padding(.horizontal, Spacing.md)

            VStack(spacing: Spacing.xs) {
                ForEach(Stage3MacOSRuntime.mirroredPages) { page in
                    sidebarButton(for: page)
                }
            }
            .padding(.horizontal, Spacing.sm)

            Spacer(minLength: 0)
        }
        .frame(minWidth: 232, idealWidth: 248, maxWidth: 272, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [
                    Color.spareYellow.opacity(0.08),
                    Color.white.opacity(0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(width: 1)
        }
    }

    private var detail: some View {
        VStack(spacing: 0) {
            contentHeader
            Divider()
            Stage3MacOSMirroredPageView(tabID: activeTabID)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var contentHeader: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(activePage.label)
                    .font(.spareTitle2)
                    .foregroundColor(.primary)

                Text(shellSnapshot.entryPath.joined(separator: " / "))
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: Spacing.sm) {
                if let selectedFilterTitle = chrome.selectedFilterTitle {
                    Text(selectedFilterTitle)
                        .font(.spareCaptionSB)
                        .foregroundColor(.spareYellowInk)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.xs)
                        .background(
                            Capsule()
                                .fill(Color.spareYellow.opacity(0.16))
                        )
                }

                Text("与 iOS 同模块顺序、同入口语义")
                    .font(.spareCaptionSB)
                    .foregroundColor(.spareYellowInk)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .background(
                        Capsule()
                            .fill(Color.spareYellow.opacity(0.16))
                    )
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(
            LinearGradient(
                colors: [
                    Color.spareYellow.opacity(0.10),
                    Color.white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func sidebarButton(for page: Stage3MacOSMirroredPageDescriptor) -> some View {
        let isSelected = activeTabID == page.id

        return Button {
            guard activeTabID != page.id else { return }

            withAnimation(.spareSpring) {
                selectedTabID = page.id
            }
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: Stage3MacOSRuntime.shellSymbol(for: page.id))
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .foregroundColor(isSelected ? .spareYellowInk : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(page.label)
                        .font(.spareBodySB)
                        .foregroundColor(.primary)

                    Text("root / \(page.id)")
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.spareYellow.opacity(0.18) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.spareYellow.opacity(0.28) : Color.clear, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .stage3HoverLift(enabled: !isSelected)
        .contextMenu {
            Button("切换到 \(page.label)") {
                withAnimation(.spareSpring) {
                    selectedTabID = page.id
                }
            }

            Button("复制模块路径") {
                Stage3MacOSPasteboard.copy("root / \(page.id)")
            }
        }
        .accessibilityIdentifier("macos-shell-sidebar-\(page.id)")
    }
}
