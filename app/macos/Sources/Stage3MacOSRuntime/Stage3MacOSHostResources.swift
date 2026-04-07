import Foundation

public struct Stage3MacOSHostResourceSnapshot: Equatable, Sendable {
    public let masterCharacterCount: Int
    public let masterImageDirectoryCount: Int
    public let seedSurfaceCount: Int
    public let diagnosticPageCount: Int

    public init(
        masterCharacterCount: Int,
        masterImageDirectoryCount: Int,
        seedSurfaceCount: Int,
        diagnosticPageCount: Int
    ) {
        self.masterCharacterCount = masterCharacterCount
        self.masterImageDirectoryCount = masterImageDirectoryCount
        self.seedSurfaceCount = seedSurfaceCount
        self.diagnosticPageCount = diagnosticPageCount
    }
}

public struct Stage3MacOSHostResourceValidation: Equatable, Sendable {
    public let catalogSourceMode: String
    public let manifestName: String
    public let matchedMasterCount: Int
    public let seedManifestReadable: Bool
    public let diagnosticManifestReadable: Bool
    public let snapshot: Stage3MacOSHostResourceSnapshot

    public init(
        catalogSourceMode: String,
        manifestName: String,
        matchedMasterCount: Int,
        seedManifestReadable: Bool,
        diagnosticManifestReadable: Bool,
        snapshot: Stage3MacOSHostResourceSnapshot
    ) {
        self.catalogSourceMode = catalogSourceMode
        self.manifestName = manifestName
        self.matchedMasterCount = matchedMasterCount
        self.seedManifestReadable = seedManifestReadable
        self.diagnosticManifestReadable = diagnosticManifestReadable
        self.snapshot = snapshot
    }
}

extension Stage3MacOSRuntime {
    public static func validateHostResources() async throws -> Stage3MacOSHostResourceValidation {
        try Stage3MacOSHostResourceBridge.validate()
    }
}

enum Stage3MacOSHostResourceBridge {
    static let hostResourcesDirectoryName = "HostResources"
    static let directoryManifestName = "master_service_directory.json"
    static let seedManifestName = "seed_manifest.json"
    static let diagnosticManifestName = "diagnostic_manifest.json"
    static let requiredImageFiles: Set<String> = ["avatar.png", "image.png", "background.jpg"]

    static func hostResourcesDirectoryURL() throws -> URL {
        for candidate in candidateDirectories() {
            guard FileManager.default.fileExists(atPath: candidate.path) else { continue }
            return candidate
        }

        throw Stage3MacOSHostResourceBridgeError.missingResourcesDirectory
    }

    static func directoryManifestURL() throws -> URL {
        try fileURL(named: directoryManifestName)
    }

    static func seedManifestURL() throws -> URL {
        try fileURL(named: seedManifestName)
    }

    static func diagnosticManifestURL() throws -> URL {
        try fileURL(named: diagnosticManifestName)
    }

    static func masterAssetRoots() throws -> (charDirectory: URL, imageDirectory: URL) {
        let directory = try hostResourcesDirectoryURL()
        let charDirectory = directory.appendingPathComponent("char", isDirectory: true)
        let imageDirectory = directory.appendingPathComponent("assets/char", isDirectory: true)

        guard FileManager.default.fileExists(atPath: charDirectory.path),
              FileManager.default.fileExists(atPath: imageDirectory.path) else {
            throw Stage3MacOSHostResourceBridgeError.assetRootsUnavailable(directory.path)
        }

        return (charDirectory, imageDirectory)
    }

    static func validate() throws -> Stage3MacOSHostResourceValidation {
        let manifestURL = try directoryManifestURL()
        let seedURL = try seedManifestURL()
        let diagnosticURL = try diagnosticManifestURL()
        let roots = try masterAssetRoots()

        let manifestAssetIDs = Set(try loadDirectoryManifest(from: manifestURL).entries.map(\.assetID))
        let characterAssetIDs = try resourceFileIDs(in: roots.charDirectory, pathExtension: "json")
        let imageAssetIDs = try validImageAssetIDs(in: roots.imageDirectory)
        let matchedAssetIDs = manifestAssetIDs
            .intersection(characterAssetIDs)
            .intersection(imageAssetIDs)

        let seedManifest = try loadSeedManifest(from: seedURL)
        let diagnosticManifest = try loadDiagnosticManifest(from: diagnosticURL)

        let sourceMode: String
        if manifestAssetIDs.isEmpty || matchedAssetIDs.isEmpty {
            sourceMode = "unavailable"
        } else if manifestAssetIDs == matchedAssetIDs {
            sourceMode = "synced"
        } else {
            sourceMode = "degraded"
        }

        return Stage3MacOSHostResourceValidation(
            catalogSourceMode: sourceMode,
            manifestName: manifestURL.lastPathComponent,
            matchedMasterCount: matchedAssetIDs.count,
            seedManifestReadable: !seedManifest.seedSurfaces.isEmpty,
            diagnosticManifestReadable: !diagnosticManifest.diagnosticPages.isEmpty,
            snapshot: Stage3MacOSHostResourceSnapshot(
                masterCharacterCount: characterAssetIDs.count,
                masterImageDirectoryCount: imageAssetIDs.count,
                seedSurfaceCount: seedManifest.seedSurfaces.count,
                diagnosticPageCount: diagnosticManifest.diagnosticPages.count
            )
        )
    }

    private static func candidateDirectories() -> [URL] {
        let sourceResourcesURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/\(hostResourcesDirectoryName)", isDirectory: true)

        return [
            Bundle.module.resourceURL?.appendingPathComponent(hostResourcesDirectoryName, isDirectory: true),
            Bundle.main.resourceURL?.appendingPathComponent(hostResourcesDirectoryName, isDirectory: true),
            sourceResourcesURL
        ]
        .compactMap { $0 }
    }

    private static func fileURL(named name: String) throws -> URL {
        for directory in candidateDirectories() {
            let fileURL = directory.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: fileURL.path) else { continue }
            return fileURL
        }

        throw Stage3MacOSHostResourceBridgeError.missingManifest(name)
    }

    private static func loadDirectoryManifest(from url: URL) throws -> Stage3MacOSDirectoryManifestDocument {
        try decode(Stage3MacOSDirectoryManifestDocument.self, from: url)
    }

    private static func loadSeedManifest(from url: URL) throws -> Stage3MacOSSeedManifestDocument {
        try decode(Stage3MacOSSeedManifestDocument.self, from: url)
    }

    private static func loadDiagnosticManifest(from url: URL) throws -> Stage3MacOSDiagnosticManifestDocument {
        try decode(Stage3MacOSDiagnosticManifestDocument.self, from: url)
    }

    private static func decode<Document: Decodable>(_ type: Document.Type, from url: URL) throws -> Document {
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(Document.self, from: data)
        } catch {
            throw Stage3MacOSHostResourceBridgeError.unreadableFile(url, error.localizedDescription)
        }
    }

    private static func resourceFileIDs(in directory: URL, pathExtension: String) throws -> Set<String> {
        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw Stage3MacOSHostResourceBridgeError.unreadableFile(directory, error.localizedDescription)
        }

        return Set(contents.compactMap { url in
            guard url.pathExtension.lowercased() == pathExtension.lowercased() else { return nil }
            return url.deletingPathExtension().lastPathComponent
        })
    }

    private static func validImageAssetIDs(in directory: URL) throws -> Set<String> {
        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw Stage3MacOSHostResourceBridgeError.unreadableFile(directory, error.localizedDescription)
        }

        var validIDs = Set<String>()
        for assetDirectory in contents {
            let values = try? assetDirectory.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { continue }
            let actualFiles = try resourceFileNames(in: assetDirectory)
            guard actualFiles == requiredImageFiles else {
                throw Stage3MacOSHostResourceBridgeError.incompleteImageDirectory(assetDirectory.lastPathComponent)
            }
            validIDs.insert(assetDirectory.lastPathComponent)
        }

        return validIDs
    }

    private static func resourceFileNames(in directory: URL) throws -> Set<String> {
        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw Stage3MacOSHostResourceBridgeError.unreadableFile(directory, error.localizedDescription)
        }

        return Set(contents.compactMap { url in
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
            guard values?.isRegularFile == true else { return nil }
            return url.lastPathComponent
        })
    }
}

private struct Stage3MacOSSeedManifestDocument: Decodable {
    let seedSurfaces: [Entry]

    enum CodingKeys: String, CodingKey {
        case seedSurfaces = "seed_surfaces"
    }

    struct Entry: Decodable {
        let id: String
    }
}

private struct Stage3MacOSDiagnosticManifestDocument: Decodable {
    let diagnosticPages: [Entry]

    enum CodingKeys: String, CodingKey {
        case diagnosticPages = "diagnostic_pages"
    }

    struct Entry: Decodable {
        let id: String
    }
}

private struct Stage3MacOSDirectoryManifestDocument: Decodable {
    let entries: [Entry]

    struct Entry: Decodable {
        let assetID: String

        enum CodingKeys: String, CodingKey {
            case assetID = "asset_id"
        }
    }
}

private enum Stage3MacOSHostResourceBridgeError: LocalizedError {
    case missingResourcesDirectory
    case missingManifest(String)
    case assetRootsUnavailable(String)
    case unreadableFile(URL, String)
    case incompleteImageDirectory(String)

    var errorDescription: String? {
        switch self {
        case .missingResourcesDirectory:
            return "未找到 Stage 3 macOS HostResources 目录。"
        case .missingManifest(let name):
            return "未找到 macOS 宿主资源清单：\(name)"
        case .assetRootsUnavailable(let directory):
            return "HostResources 缺少大师目录或图片根目录：\(directory)"
        case .unreadableFile(let url, let detail):
            return "读取 macOS 宿主资源失败：\(url.lastPathComponent)，\(detail)"
        case .incompleteImageDirectory(let assetID):
            return "大师图片目录缺少必需文件：\(assetID)"
        }
    }
}
