import Foundation

public enum RepoRootLocatorError: Error, CustomStringConvertible {
    case repoRootNotFound(startingAt: String)

    public var description: String {
        switch self {
        case let .repoRootNotFound(startingAt):
            return "Unable to locate repository root from \(startingAt)"
        }
    }
}

public func findRepoRoot(startingAt filePath: String) throws -> URL {
    let fileURL = URL(fileURLWithPath: filePath, isDirectory: false)
    let fileManager = FileManager.default
    var candidate = fileURL.deletingLastPathComponent()

    while true {
        let anchors = [
            candidate.appendingPathComponent("README.md"),
            candidate.appendingPathComponent("Docs/Stage3_Blueprint.md"),
            candidate.appendingPathComponent("ios/README.md")
        ]

        if anchors.allSatisfy({ fileManager.fileExists(atPath: $0.path) }) {
            return candidate
        }

        let parent = candidate.deletingLastPathComponent()
        if parent.path == candidate.path {
            break
        }
        candidate = parent
    }

    throw RepoRootLocatorError.repoRootNotFound(startingAt: filePath)
}

public func readText(at url: URL) throws -> String {
    try String(contentsOf: url, encoding: .utf8)
}
