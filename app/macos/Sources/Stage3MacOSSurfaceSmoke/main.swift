import Foundation
import Stage3MacOSRuntime

@main
enum Stage3MacOSSurfaceSmoke {
    @MainActor
    static func main() throws {
        let results = try Stage3MacOSSmokeRunner.run()
        let pageSummary = Stage3MacOSRuntime.mirroredPages.map(\.id).joined(separator: ", ")

        print("Stage 3 macOS host booted with shared MainTabView runtime.")
        print("Mirrored page order: \(pageSummary)")

        for result in results {
            print(
                "Rendered \(result.id) via \(result.rootView) with fitted size " +
                "\(Int(result.measuredWidth))x\(Int(result.measuredHeight))."
            )
        }
    }
}
