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
        .library(
            name: "Stage3MacOSRuntime",
            targets: ["Stage3MacOSRuntime"]
        ),
        .executable(
            name: "stage3-macos-app",
            targets: ["Stage3MacOSApp"]
        ),
        .executable(
            name: "stage3-macos-target-smoke",
            targets: ["Stage3MacOSTargetSmoke"]
        ),
        .executable(
            name: "stage3-macos-surface-smoke",
            targets: ["Stage3MacOSSurfaceSmoke"]
        )
    ],
    targets: [
        .target(
            name: "Stage3MacOSTargetContract",
            path: "Sources/Stage3MacOSTargetContract"
        ),
        .target(
            name: "Stage3MacOSRuntime",
            dependencies: ["Stage3MacOSTargetContract"],
            path: ".",
            exclude: [
                "Shared/SpareLifeCoreSource/App/MainTabView.swift",
                "Shared/SpareLifeCoreSource/Features/EarnSocial/LeadResultView.swift",
                "Shared/SpareLifeCoreSource/Features/CompanionChat/ChatThreadView.swift",
                "Shared/SpareLifeCoreSource/Features/CompanionChat/QuadRoleChatView.swift",
                "Shared/SpareLifeCoreSource/Features/Masters/Support",
                "Shared/SpareLifeCoreSource/Features/Xianxia/QRScanView.swift"
            ],
            sources: [
                "Sources/Stage3MacOSRuntime",
                "Shared/SpareLifeCoreSource/App/AppHandoffRouter.swift",
                "Shared/SpareLifeCoreSource/App/CrossTabHandoff.swift",
                "Shared/SpareLifeCoreSource/App/ConversationRouter.swift",
                "Shared/SpareLifeCoreSource/App/DesignSystem",
                "Shared/SpareLifeCoreSource/Domain/Models/SceneModels.swift",
                "Shared/SpareLifeCoreSource/Features/CompanionChat",
                "Shared/SpareLifeCoreSource/Features/EarnSocial",
                "Shared/SpareLifeCoreSource/Features/Infrastructure",
                "Shared/SpareLifeCoreSource/Features/Masters",
                "Shared/SpareLifeCoreSource/Features/MyProfile",
                "Shared/SpareLifeCoreSource/Features/Shared",
                "Shared/SpareLifeCoreSource/Features/Xianxia"
            ],
            resources: [
                .copy("Resources/HostResources")
            ]
        ),
        .executableTarget(
            name: "Stage3MacOSTargetSmoke",
            dependencies: ["Stage3MacOSTargetContract"],
            path: "Sources/Stage3MacOSTargetSmoke"
        ),
        .executableTarget(
            name: "Stage3MacOSSurfaceSmoke",
            dependencies: [
                "Stage3MacOSTargetContract",
                "Stage3MacOSRuntime"
            ],
            path: "Sources/Stage3MacOSSurfaceSmoke"
        ),
        .executableTarget(
            name: "Stage3MacOSApp",
            dependencies: ["Stage3MacOSRuntime"],
            path: "Sources/Stage3MacOSApp"
        ),
        .testTarget(
            name: "Stage3MacOSTargetContractTests",
            dependencies: ["Stage3MacOSTargetContract"],
            path: "Tests/Stage3MacOSTargetContractTests"
        ),
        .testTarget(
            name: "Stage3MacOSRuntimeTests",
            dependencies: [
                "Stage3MacOSTargetContract",
                "Stage3MacOSRuntime"
            ],
            path: "Tests/Stage3MacOSRuntimeTests"
        )
    ]
)
