// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SpareLifeApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "SpareLifeCore", targets: ["SpareLifeCore"]),
        .executable(name: "spare-life-scene-demo", targets: ["SpareLifeCLI"])
    ],
    targets: [
        .systemLibrary(
            name: "CSQLite",
            path: "CSQLite",
            pkgConfig: "sqlite3",
            providers: [
                .apt(["libsqlite3-dev"])
            ]
        ),
        .target(
            name: "SpareLifeCore",
            dependencies: ["CSQLite"],
            path: ".",
            exclude: [
                "CSQLite",
                "Features",
                "README.md",
                "Resources",
                "Tests",
                "App/CLI"
            ],
            sources: [
                "App",
                "Domain",
                "LocalBackend",
                "Services"
            ]
        ),
        .executableTarget(
            name: "SpareLifeCLI",
            dependencies: ["SpareLifeCore"],
            path: "App/CLI"
        ),
        .testTarget(
            name: "SpareLifeCoreTests",
            dependencies: ["SpareLifeCore"],
            path: "Tests"
        )
    ]
)
