// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Stage3IOSPathValidation",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Stage3IOSPathValidationSupport",
            targets: ["Stage3IOSPathValidationSupport"]
        )
    ],
    targets: [
        .target(
            name: "Stage3IOSPathValidationSupport",
            path: "Sources/Stage3IOSPathValidationSupport"
        ),
        .testTarget(
            name: "Stage3IOSPathValidationTests",
            dependencies: ["Stage3IOSPathValidationSupport"]
        )
    ]
)
