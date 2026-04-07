import Foundation
import Stage3MacOSTargetContract

@main
struct Stage3MacOSTargetSmoke {
    static func main() throws {
        let target = Stage3MacOSTarget.stage3
        let mainTabSource = try readRepoFile("ios/spare-life-ios-app/App/MainTabView.swift")
        let crossTabHandoffSource = try readRepoFile("ios/spare-life-ios-app/App/CrossTabHandoff.swift")
        let conversationRouterSource = try readRepoFile("ios/spare-life-ios-app/App/ConversationRouter.swift")
        let packageManifestSource = try readRepoFile("app/macos/Package.swift")
        let evidence = try Stage3MacOSTargetValidator.validateSameProduct(
            mainTabSource: mainTabSource,
            crossTabHandoffSource: crossTabHandoffSource,
            conversationRouterSource: conversationRouterSource,
            packageManifestSource: packageManifestSource
        )

        let tabSummary = evidence.runtimeTabs.map(\.id).joined(separator: ", ")
        let surfaceSummary = evidence.sharedSurfaceBindings
            .map { "\($0.tabID)->\($0.surfaceID)" }
            .joined(separator: ", ")
        let routeSummary = evidence.messagesRouteKinds.joined(separator: ", ")
        let shellSummary = target.allowedShellContainers.joined(separator: ", ")

        print("Stage 3 macOS target locked to \(target.uiBase).")
        print("Mirrored runtime tabs: \(tabSummary)")
        print("Shared surface bindings: \(surfaceSummary)")
        print("Shared messages routes: \(routeSummary)")
        print("Runtime source intake: \(evidence.runtimeSourceEntries.count) shared entries")
        print("Allowed desktop shell containers: \(shellSummary)")
    }

    private static func readRepoFile(_ relativePath: String) throws -> String {
        let url = try locateRepoFile(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private static func locateRepoFile(_ relativePath: String) throws -> URL {
        let fileManager = FileManager.default
        var current = URL(fileURLWithPath: fileManager.currentDirectoryPath)

        for _ in 0..<8 {
            let candidate = current.appendingPathComponent(relativePath)
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            current.deleteLastPathComponent()
        }

        throw NSError(
            domain: "Stage3MacOSTargetSmoke",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: "Could not locate \(relativePath) from app/macos."
            ]
        )
    }
}
