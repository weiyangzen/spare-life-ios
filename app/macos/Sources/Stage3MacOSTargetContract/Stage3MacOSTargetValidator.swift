import Foundation

public struct Stage3MacOSTargetMirror: Sendable, Equatable {
    public let runtimeTabs: [Stage3RuntimeTab]

    public init(runtimeTabs: [Stage3RuntimeTab]) {
        self.runtimeTabs = runtimeTabs
    }
}

public struct Stage3MacOSSameProductEvidence: Sendable, Equatable {
    public let runtimeTabs: [Stage3RuntimeTab]
    public let sharedSurfaceBindings: [Stage3SharedSurfaceBinding]
    public let sharedSurfaceIDs: [String]
    public let messagesRouteKinds: [String]
    public let runtimeSourceEntries: [String]

    public init(
        runtimeTabs: [Stage3RuntimeTab],
        sharedSurfaceBindings: [Stage3SharedSurfaceBinding],
        sharedSurfaceIDs: [String],
        messagesRouteKinds: [String],
        runtimeSourceEntries: [String]
    ) {
        self.runtimeTabs = runtimeTabs
        self.sharedSurfaceBindings = sharedSurfaceBindings
        self.sharedSurfaceIDs = sharedSurfaceIDs
        self.messagesRouteKinds = messagesRouteKinds
        self.runtimeSourceEntries = runtimeSourceEntries
    }
}

private struct Stage3AppSurfaceDescriptor: Equatable {
    let caseName: String
    let rawValue: String
}

public enum Stage3MacOSTargetValidationError: Error, LocalizedError, Equatable {
    case tabDeclarationsNotFound
    case mirrorMismatch(expected: [Stage3RuntimeTab], actual: [Stage3RuntimeTab])
    case appSurfaceCatalogNotFound
    case appSurfaceCatalogMismatch(expected: [String], actual: [String])
    case surfaceBindingsNotFound
    case surfaceBindingsMismatch(expected: [Stage3SharedSurfaceBinding], actual: [Stage3SharedSurfaceBinding])
    case messagesRouteKindsNotFound
    case messagesRouteKindsMismatch(expected: [String], actual: [String])
    case runtimeSourceIntakeNotFound
    case runtimeSourceIntakeMismatch(expected: [String], actual: [String])
    case runtimeLocalForkDetected(actual: [String])

    public var errorDescription: String? {
        switch self {
        case .tabDeclarationsNotFound:
            return "Could not locate MainTabView tab declarations to validate the macOS Stage 3 mirror."
        case let .mirrorMismatch(expected, actual):
            let expectedSummary = expected.map(\.id).joined(separator: ", ")
            let actualSummary = actual.map(\.id).joined(separator: ", ")
            return "MainTabView no longer matches the frozen Stage 3 macOS mirror. Expected [\(expectedSummary)] but found [\(actualSummary)]."
        case .appSurfaceCatalogNotFound:
            return "Could not locate AppSurfaceID declarations from the shared cross-tab handoff contract."
        case let .appSurfaceCatalogMismatch(expected, actual):
            return "The shared AppSurfaceID catalog diverged from the frozen Stage 3 macOS parity contract. Expected [\(expected.joined(separator: ", "))] but found [\(actual.joined(separator: ", "))]."
        case .surfaceBindingsNotFound:
            return "Could not locate MainTabView surface bindings to validate macOS parity."
        case let .surfaceBindingsMismatch(expected, actual):
            let expectedSummary = expected.map { "\($0.tabID)->\($0.surfaceID)" }.joined(separator: ", ")
            let actualSummary = actual.map { "\($0.tabID)->\($0.surfaceID)" }.joined(separator: ", ")
            return "MainTabView surface bindings diverged from the frozen Stage 3 macOS parity contract. Expected [\(expectedSummary)] but found [\(actualSummary)]."
        case .messagesRouteKindsNotFound:
            return "Could not locate shared MessagesRoute cases to validate macOS parity."
        case let .messagesRouteKindsMismatch(expected, actual):
            return "MessagesRoute diverged from the frozen Stage 3 macOS parity contract. Expected [\(expected.joined(separator: ", "))] but found [\(actual.joined(separator: ", "))]."
        case .runtimeSourceIntakeNotFound:
            return "Could not locate Stage3MacOSRuntime source intake from app/macos/Package.swift."
        case let .runtimeSourceIntakeMismatch(expected, actual):
            return "Stage3MacOSRuntime source intake diverged from the frozen Stage 3 parity contract. Expected [\(expected.joined(separator: ", "))] but found [\(actual.joined(separator: ", "))]."
        case let .runtimeLocalForkDetected(actual):
            return "Stage3MacOSRuntime sources include unexpected local feature forks: [\(actual.joined(separator: ", "))]."
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

    public static func validateSameProduct(
        mainTabSource: String,
        crossTabHandoffSource: String,
        conversationRouterSource: String,
        packageManifestSource: String
    ) throws -> Stage3MacOSSameProductEvidence {
        let mirror = try validateMirror(against: mainTabSource)
        let appSurfaceCatalog = try extractAppSurfaceCatalog(from: crossTabHandoffSource)
        let surfaceBindings = try extractSurfaceBindings(
            from: mainTabSource,
            using: appSurfaceCatalog
        )
        let expectedBindings = Stage3MacOSTarget.stage3.sharedSurfaceBindings

        guard surfaceBindings == expectedBindings else {
            throw Stage3MacOSTargetValidationError.surfaceBindingsMismatch(
                expected: expectedBindings,
                actual: surfaceBindings
            )
        }

        let sharedSurfaceIDs = appSurfaceCatalog.map(\.rawValue)
        let expectedSurfaceIDs = expectedBindings.map(\.surfaceID)
        guard sharedSurfaceIDs == expectedSurfaceIDs else {
            throw Stage3MacOSTargetValidationError.appSurfaceCatalogMismatch(
                expected: expectedSurfaceIDs,
                actual: sharedSurfaceIDs
            )
        }

        let messagesRouteKinds = try extractMessagesRouteKinds(from: conversationRouterSource)
        let expectedRouteKinds = Stage3MacOSTarget.stage3.sharedMessagesRouteKinds
        guard messagesRouteKinds == expectedRouteKinds else {
            throw Stage3MacOSTargetValidationError.messagesRouteKindsMismatch(
                expected: expectedRouteKinds,
                actual: messagesRouteKinds
            )
        }

        let runtimeSourceEntries = try extractRuntimeSourceEntries(from: packageManifestSource)
        let runtimeSourceContract = Stage3MacOSTarget.stage3.runtimeSourceIntake
        let localForks = runtimeSourceEntries.filter { entry in
            !runtimeSourceContract.allowedLocalWrappers.contains(entry) &&
                !entry.hasPrefix(runtimeSourceContract.sharedSourcePrefix)
        }
        guard localForks.isEmpty else {
            throw Stage3MacOSTargetValidationError.runtimeLocalForkDetected(actual: localForks)
        }

        guard runtimeSourceEntries == runtimeSourceContract.requiredSources else {
            throw Stage3MacOSTargetValidationError.runtimeSourceIntakeMismatch(
                expected: runtimeSourceContract.requiredSources,
                actual: runtimeSourceEntries
            )
        }

        return Stage3MacOSSameProductEvidence(
            runtimeTabs: mirror.runtimeTabs,
            sharedSurfaceBindings: surfaceBindings,
            sharedSurfaceIDs: sharedSurfaceIDs,
            messagesRouteKinds: messagesRouteKinds,
            runtimeSourceEntries: runtimeSourceEntries
        )
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

    private static func extractAppSurfaceCatalog(from source: String) throws -> [Stage3AppSurfaceDescriptor] {
        let enumBody = try extractSection(
            from: source,
            startMarker: "enum AppSurfaceID",
            endMarker: "var title:"
        )
        let pattern = #"case\s+([A-Za-z_][A-Za-z0-9_]*)(?:\s*=\s*"([^"]+)")?"#
        let regex = try NSRegularExpression(pattern: pattern)
        let sectionRange = NSRange(enumBody.startIndex..<enumBody.endIndex, in: enumBody)

        let descriptors = regex.matches(in: enumBody, options: [], range: sectionRange).compactMap { match -> Stage3AppSurfaceDescriptor? in
            guard let caseRange = Range(match.range(at: 1), in: enumBody) else {
                return nil
            }

            let caseName = String(enumBody[caseRange])
            let rawValue: String
            if let explicitRawRange = Range(match.range(at: 2), in: enumBody) {
                rawValue = String(enumBody[explicitRawRange])
            } else {
                rawValue = caseName
            }

            return Stage3AppSurfaceDescriptor(caseName: caseName, rawValue: rawValue)
        }

        guard !descriptors.isEmpty else {
            throw Stage3MacOSTargetValidationError.appSurfaceCatalogNotFound
        }

        return descriptors
    }

    private static func extractSurfaceBindings(
        from source: String,
        using appSurfaceCatalog: [Stage3AppSurfaceDescriptor]
    ) throws -> [Stage3SharedSurfaceBinding] {
        let bindingSection = try extractSection(
            from: source,
            startMarker: "var surfaceID: AppSurfaceID",
            endMarker: "init?(surfaceID: AppSurfaceID)"
        )
        let pattern = #"case\s+\.([A-Za-z_][A-Za-z0-9_]*)\s*:\s*return\s+\.([A-Za-z_][A-Za-z0-9_]*)"#
        let regex = try NSRegularExpression(pattern: pattern)
        let sectionRange = NSRange(bindingSection.startIndex..<bindingSection.endIndex, in: bindingSection)
        let catalogByCaseName = Dictionary(uniqueKeysWithValues: appSurfaceCatalog.map { ($0.caseName, $0.rawValue) })

        let bindings = regex.matches(in: bindingSection, options: [], range: sectionRange).compactMap { match -> Stage3SharedSurfaceBinding? in
            guard let tabRange = Range(match.range(at: 1), in: bindingSection),
                  let surfaceCaseRange = Range(match.range(at: 2), in: bindingSection) else {
                return nil
            }

            let tabID = String(bindingSection[tabRange])
            let surfaceCaseName = String(bindingSection[surfaceCaseRange])
            guard let surfaceID = catalogByCaseName[surfaceCaseName] else {
                return nil
            }

            return Stage3SharedSurfaceBinding(tabID: tabID, surfaceID: surfaceID)
        }

        guard !bindings.isEmpty else {
            throw Stage3MacOSTargetValidationError.surfaceBindingsNotFound
        }

        return bindings
    }

    private static func extractMessagesRouteKinds(from source: String) throws -> [String] {
        let enumBody = try extractSection(
            from: source,
            startMarker: "enum MessagesRoute",
            endMarker: "var canonicalStack:"
        )
        let pattern = #"case\s+([A-Za-z_][A-Za-z0-9_]*)\b"#
        let regex = try NSRegularExpression(pattern: pattern)
        let sectionRange = NSRange(enumBody.startIndex..<enumBody.endIndex, in: enumBody)
        let routeKinds = regex.matches(in: enumBody, options: [], range: sectionRange).compactMap { match -> String? in
            guard let routeRange = Range(match.range(at: 1), in: enumBody) else {
                return nil
            }
            return String(enumBody[routeRange])
        }

        guard !routeKinds.isEmpty else {
            throw Stage3MacOSTargetValidationError.messagesRouteKindsNotFound
        }

        return routeKinds
    }

    private static func extractRuntimeSourceEntries(from source: String) throws -> [String] {
        guard let runtimeTargetRange = source.range(of: "name: \"Stage3MacOSRuntime\"") else {
            throw Stage3MacOSTargetValidationError.runtimeSourceIntakeNotFound
        }
        let searchRange = runtimeTargetRange.lowerBound..<source.endIndex
        let sourcesBody = try extractArrayLiteral(
            from: source,
            marker: "sources:",
            searchRange: searchRange
        )
        let pattern = #""([^"]+)""#
        let regex = try NSRegularExpression(pattern: pattern)
        let bodyRange = NSRange(sourcesBody.startIndex..<sourcesBody.endIndex, in: sourcesBody)
        let sourceEntries = regex.matches(in: sourcesBody, options: [], range: bodyRange).compactMap { match -> String? in
            guard let entryRange = Range(match.range(at: 1), in: sourcesBody) else {
                return nil
            }
            return String(sourcesBody[entryRange])
        }

        guard !sourceEntries.isEmpty else {
            throw Stage3MacOSTargetValidationError.runtimeSourceIntakeNotFound
        }

        return sourceEntries
    }

    private static func extractSection(
        from source: String,
        startMarker: String,
        endMarker: String
    ) throws -> String {
        guard let startRange = source.range(of: startMarker) else {
            throw Stage3MacOSTargetValidationError.tabDeclarationsNotFound
        }
        guard let endRange = source.range(of: endMarker, range: startRange.upperBound..<source.endIndex) else {
            throw Stage3MacOSTargetValidationError.tabDeclarationsNotFound
        }

        return String(source[startRange.lowerBound..<endRange.lowerBound])
    }

    private static func extractArrayLiteral(
        from source: String,
        marker: String,
        searchRange: Range<String.Index>
    ) throws -> String {
        guard let markerRange = source.range(of: marker, range: searchRange) else {
            throw Stage3MacOSTargetValidationError.runtimeSourceIntakeNotFound
        }
        guard let openBracket = source[markerRange.upperBound..<searchRange.upperBound].firstIndex(of: "[") else {
            throw Stage3MacOSTargetValidationError.runtimeSourceIntakeNotFound
        }
        guard let closeBracket = matchingBracketEnd(in: source, openBracket: openBracket) else {
            throw Stage3MacOSTargetValidationError.runtimeSourceIntakeNotFound
        }

        return String(source[source.index(after: openBracket)..<closeBracket])
    }

    private static func matchingBracketEnd(
        in source: String,
        openBracket: String.Index
    ) -> String.Index? {
        var depth = 0
        var index = openBracket

        while index < source.endIndex {
            let character = source[index]
            if character == "[" {
                depth += 1
            } else if character == "]" {
                depth -= 1
                if depth == 0 {
                    return index
                }
            }

            index = source.index(after: index)
        }

        return nil
    }
}
