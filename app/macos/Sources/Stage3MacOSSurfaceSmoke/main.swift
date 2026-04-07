import Foundation
import Stage3MacOSRuntime

@main
enum Stage3MacOSSurfaceSmoke {
    @MainActor
    static func main() throws {
        let results = try Stage3MacOSSmokeRunner.run()
        let diagnosticResults = try Stage3MacOSSmokeRunner.runDiagnosticSurfaces()
        let pageSummary = Stage3MacOSRuntime.mirroredPages.map(\.id).joined(separator: ", ")
        let diagnosticSummary = Stage3MacOSRuntime.diagnosticPages.map(\.id).joined(separator: ", ")
        let shell = Stage3MacOSRuntime.desktopShellSnapshot()

        print("Stage 3 macOS host booted with desktop shell root \(shell.rootView).")
        print("Desktop containers: \(shell.containerKinds.joined(separator: ", "))")
        print("Mirrored page order: \(pageSummary)")
        print("Diagnostic surfaces: \(diagnosticSummary)")

        for result in results {
            print(
                "Rendered \(result.id) via \(result.rootView) with fitted size " +
                "\(Int(result.measuredWidth))x\(Int(result.measuredHeight))."
            )
        }

        for result in diagnosticResults {
            print(
                "Rendered diagnostic \(result.id) via \(result.rootView) with fitted size " +
                "\(Int(result.measuredWidth))x\(Int(result.measuredHeight))."
            )
        }
    }
}
