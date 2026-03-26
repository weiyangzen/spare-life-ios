// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SpareLifeApp",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "SpareLifeCore", targets: ["SpareLifeCore"]),
        .executable(name: "spare-life-scene-demo", targets: ["SpareLifeCLI"])
    ],
    targets: [
        .target(
            name: "SpareLifeCore",
            path: ".",
            exclude: [
                "CSQLite",
                "README.md",
                "Resources",
                "Tests",
                "App/CLI",
                "LocalBackend",
                "Services",
                "Domain/Models/a2aContracts.mjs",
                "Domain/Models/companionContracts.mjs",
                "Domain/Models/masterContracts.mjs",
                "Domain/Models/myContracts.mjs",
                "Domain/Models/sceneContracts.mjs",
                "Domain/Models/unifiedUIContracts.mjs",
                "Domain/UseCases"
            ],
            sources: [
                "App",
                "Domain/Models",
                "Features"
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
