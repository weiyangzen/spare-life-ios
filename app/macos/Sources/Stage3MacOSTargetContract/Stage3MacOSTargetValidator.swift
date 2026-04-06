import Foundation

public struct Stage3MacOSTargetMirror: Sendable, Equatable {
    public let runtimeTabs: [Stage3RuntimeTab]

    public init(runtimeTabs: [Stage3RuntimeTab]) {
        self.runtimeTabs = runtimeTabs
    }
}

public enum Stage3MacOSTargetValidationError: Error, LocalizedError, Equatable {
    case tabDeclarationsNotFound
    case mirrorMismatch(expected: [Stage3RuntimeTab], actual: [Stage3RuntimeTab])

    public var errorDescription: String? {
        switch self {
        case .tabDeclarationsNotFound:
            return "Could not locate MainTabView tab declarations to validate the macOS Stage 3 mirror."
        case let .mirrorMismatch(expected, actual):
            let expectedSummary = expected.map(\.id).joined(separator: ", ")
            let actualSummary = actual.map(\.id).joined(separator: ", ")
            return "MainTabView no longer matches the frozen Stage 3 macOS mirror. Expected [\(expectedSummary)] but found [\(actualSummary)]."
        }
    }
}

public enum Stage3MacOSTargetValidator {
    public static func validateMirror(against source: String) throws -> Stage3MacOSTargetMirror {
        let runtimeTabs = try extractRuntimeTabs(from: source)
        let expectedTabs = Stage3MacOSTarget.stage3.canonicalTabs

        guard runtimeTabs == expectedTabs else {
            throw Stage3MacOSTargetValidationError.mirrorMismatch(
                expected: expectedTabs,
                actual: runtimeTabs
            )
        }

        return Stage3MacOSTargetMirror(runtimeTabs: runtimeTabs)
    }

    private static func extractRuntimeTabs(from source: String) throws -> [Stage3RuntimeTab] {
        let pattern = #"""
        ([A-Za-z_][A-Za-z0-9_]*)\(\)\s*
        \.tag\(MainTab\.([A-Za-z_][A-Za-z0-9_]*)\)\s*
        \.tabItem\s*\{\s*
        Label\("([^"]+)",\s*systemImage:\s*"[^"]+"\)\s*
        \}
        """#

        let regex = try NSRegularExpression(
            pattern: pattern,
            options: [.allowCommentsAndWhitespace, .dotMatchesLineSeparators]
        )
        let sourceRange = NSRange(source.startIndex..<source.endIndex, in: source)
        let matches = regex.matches(in: source, options: [], range: sourceRange)

        let runtimeTabs = matches.compactMap { match -> Stage3RuntimeTab? in
            guard match.numberOfRanges == 4,
                  let rootViewRange = Range(match.range(at: 1), in: source),
                  let idRange = Range(match.range(at: 2), in: source),
                  let labelRange = Range(match.range(at: 3), in: source) else {
                return nil
            }

            return Stage3RuntimeTab(
                id: String(source[idRange]),
                label: String(source[labelRange]),
                rootView: String(source[rootViewRange])
            )
        }

        guard !runtimeTabs.isEmpty else {
            throw Stage3MacOSTargetValidationError.tabDeclarationsNotFound
        }

        return runtimeTabs
    }
}
