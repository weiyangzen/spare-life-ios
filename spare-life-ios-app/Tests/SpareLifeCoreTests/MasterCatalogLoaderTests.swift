import XCTest
@testable import SpareLifeCore

final class MasterCatalogLoaderTests: XCTestCase {
    func testMasterCatalogLoadsExpectedEightMasters() throws {
        let snapshot = try MasterCatalogLoader.load()

        XCTAssertEqual(snapshot.masters.count, 8)
        XCTAssertEqual(
            Set(snapshot.masters.map(\.id)),
            Set(["001546", "001550", "001560", "001565", "001567", "001570", "001572", "001580"])
        )
        XCTAssertEqual(snapshot.sessions.count, 0)
        XCTAssertEqual(snapshot.domains.count, 4)
    }

    func testMasterCatalogMappingUsesMatchedLocalAssets() throws {
        let snapshot = try MasterCatalogLoader.load()
        let fileManager = FileManager.default

        for master in snapshot.masters {
            XCTAssertEqual(master.imageSet.assetID, master.id)
            XCTAssertTrue(
                master.assetBundle.directoryManifestPath.hasSuffix(
                    "/spare-life-ios-app/Features/Masters/Support/master_service_directory.json"
                )
            )
            XCTAssertTrue(master.assetBundle.characterAssetPath.hasSuffix("/assets/char/\(master.id).json"))
            XCTAssertTrue(master.assetBundle.imageDirectoryPath.hasSuffix("/assets/assets/char/\(master.id)"))
            XCTAssertEqual(Set(master.assetBundle.mappedImageFiles), Set(["avatar.png", "image.png", "background.jpg"]))

            XCTAssertTrue(fileManager.fileExists(atPath: master.assetBundle.directoryManifestPath))
            XCTAssertTrue(fileManager.fileExists(atPath: master.assetBundle.characterAssetPath))
            XCTAssertTrue(fileManager.fileExists(atPath: master.imageSet.avatarPath))
            XCTAssertTrue(fileManager.fileExists(atPath: master.imageSet.portraitPath))
            XCTAssertTrue(fileManager.fileExists(atPath: master.imageSet.backgroundPath))
        }
    }

    func testMasterCatalogIDsMatchLocalCharacterAndImageDirectoriesExactly() throws {
        let snapshot = try MasterCatalogLoader.load()
        let expectedIDs = Set(snapshot.masters.map(\.id))
        let fileManager = FileManager.default

        let firstMaster = try XCTUnwrap(snapshot.masters.first)
        let characterDirectory = URL(fileURLWithPath: firstMaster.assetBundle.characterAssetPath).deletingLastPathComponent()
        let imageRootDirectory = URL(fileURLWithPath: firstMaster.assetBundle.imageDirectoryPath).deletingLastPathComponent()

        let localCharacterIDs = Set<String>(
            try fileManager.contentsOfDirectory(
                at: characterDirectory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            .compactMap { url in
                guard url.pathExtension == "json" else { return nil }
                return url.deletingPathExtension().lastPathComponent
            }
        )

        let localImageIDs = Set<String>(
            try fileManager.contentsOfDirectory(
                at: imageRootDirectory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            .compactMap { url in
                guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return nil }
                return url.lastPathComponent
            }
        )

        XCTAssertEqual(localCharacterIDs, expectedIDs)
        XCTAssertEqual(localImageIDs, expectedIDs)
    }

    @MainActor
    func testMasterHomeCardsStayDirectoryOnly() async throws {
        let store = MasterExperienceStore()

        await store.refreshCatalog()

        XCTAssertEqual(store.masters.count, 8)
        XCTAssertEqual(store.homeCards.count, store.masters.count)
        XCTAssertTrue(store.homeCards.allSatisfy { card in
            if case .master = card {
                return true
            }
            return false
        })
    }
}
