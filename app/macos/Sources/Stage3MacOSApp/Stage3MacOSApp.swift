import Stage3MacOSRuntime
import SwiftUI

@main
struct Stage3MacOSApp: App {
    var body: some Scene {
        WindowGroup("Spare Life Stage 3 macOS") {
            Stage3MacOSSharedRootView()
        }

        Window("Infrastructure Diagnostics", id: Stage3MacOSRuntime.infrastructureWorkspacePageID) {
            Stage3MacOSDiagnosticPageView(pageID: Stage3MacOSRuntime.infrastructureWorkspacePageID)
        }

        Window("OpenClaw Plugin", id: Stage3MacOSRuntime.openClawDiagnosticPageID) {
            Stage3MacOSDiagnosticPageView(pageID: Stage3MacOSRuntime.openClawDiagnosticPageID)
        }

        Window("SQLite Backend", id: Stage3MacOSRuntime.sqliteDiagnosticPageID) {
            Stage3MacOSDiagnosticPageView(pageID: Stage3MacOSRuntime.sqliteDiagnosticPageID)
        }

        Window("Security Risk Control", id: Stage3MacOSRuntime.securityDiagnosticPageID) {
            Stage3MacOSDiagnosticPageView(pageID: Stage3MacOSRuntime.securityDiagnosticPageID)
        }

        Window("AI Memory Matching", id: Stage3MacOSRuntime.memoryMatchingDiagnosticPageID) {
            Stage3MacOSDiagnosticPageView(pageID: Stage3MacOSRuntime.memoryMatchingDiagnosticPageID)
        }
    }
}
