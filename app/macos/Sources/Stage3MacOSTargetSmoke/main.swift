import Foundation
import Stage3MacOSTargetContract

@main
struct Stage3MacOSTargetSmoke {
    static func main() throws {
        let target = Stage3MacOSTarget.stage3
        let source = try String(contentsOf: runtimeMainTabViewURL(), encoding: .utf8)
        let mirror = try Stage3MacOSTargetValidator.validateMirror(against: source)

        let tabSummary = mirror.runtimeTabs.map(\.id).joined(separator: ", ")
        let shellSummary = target.allowedShellContainers.joined(separator: ", ")

        print("Stage 3 macOS target locked to \(target.uiBase).")
        print("Mirrored runtime tabs: \(tabSummary)")
        print("Allowed desktop shell containers: \(shellSummary)")
    }

    private static func runtimeMainTabViewURL() throws -> URL {
        let fileManager = FileManager.default
        var current = URL(fileURLWithPath: fileManager.currentDirectoryPath)

        for _ in 0..<8 {
            let candidate = current
                .appendingPathComponent("ios")
                .appendingPathComponent("spare-life-ios-app")
                .appendingPathComponent("App")
                .appendingPathComponent("MainTabView.swift")
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            current.deleteLastPathComponent()
        }

        throw NSError(
            domain: "Stage3MacOSTargetSmoke",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: "Could not locate ios/spare-life-ios-app/App/MainTabView.swift from app/macos."
            ]
        )
    }
}
