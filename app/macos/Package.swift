// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Stage3MacOSLane",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Stage3MacOSTargetContract",
            targets: ["Stage3MacOSTargetContract"]
        ),
        .executable(
            name: "stage3-macos-target-smoke",
            targets: ["Stage3MacOSTargetSmoke"]
        )
    ],
    targets: [
        .target(
            name: "Stage3MacOSTargetContract",
            path: "Sources/Stage3MacOSTargetContract"
        ),
        .executableTarget(
            name: "Stage3MacOSTargetSmoke",
            dependencies: ["Stage3MacOSTargetContract"],
            path: "Sources/Stage3MacOSTargetSmoke"
        ),
        .testTarget(
            name: "Stage3MacOSTargetContractTests",
            dependencies: ["Stage3MacOSTargetContract"],
            path: "Tests/Stage3MacOSTargetContractTests"
        )
    ]
)
