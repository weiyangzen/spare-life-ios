import Foundation

enum SparePlatformSurfaceRole: String, CaseIterable, Sendable {
    case sharedContentAndState = "shared-content-and-state"
    case desktopShell = "desktop-shell"
    case desktopContainer = "desktop-container"
    case desktopInteraction = "desktop-interaction"

    var summary: String {
        switch self {
        case .sharedContentAndState:
            return "Keep feature content, state, routing payloads, and shared renderers identical across iOS and macOS."
        case .desktopShell:
            return "Own top-level navigation chrome such as tab bar, sidebar, toolbar, and workspace entry points."
        case .desktopContainer:
            return "Own presentation structure such as modal vs split view, list-detail, or multi-column workspace shells."
        case .desktopInteraction:
            return "Own platform-only hardware and interaction affordances such as hover, keyboard, camera, microphone, and haptics."
        }
    }
}

struct SparePlatformSurfaceEntry: Identifiable, Hashable, Sendable {
    let file: String
    let role: SparePlatformSurfaceRole
    let reason: String

    var id: String { file }
}

enum SparePlatformSurfacePolicy {
    // Shared by default: these files already compile in the Swift package's iOS/macOS target
    // and should remain the common source of truth unless a later wave proves otherwise.
    static let directSharedFiles: [SparePlatformSurfaceEntry] = [
        .init(
            file: "App/ConversationRouter.swift",
            role: .sharedContentAndState,
            reason: "Route state and cross-tab payloads stay canonical across Apple platforms."
        ),
        .init(
            file: "App/DesignSystem/DesignTokens.swift",
            role: .sharedContentAndState,
            reason: "Shared color, typography, avatar loading, and empty/error states are common UI primitives."
        ),
        .init(
            file: "App/DesignSystem/PlatformCompat.swift",
            role: .sharedContentAndState,
            reason: "Cross-platform shims centralize platform conditionals instead of scattering them into feature pages."
        ),
        .init(
            file: "App/DesignSystem/WaterfallLayout.swift",
            role: .sharedContentAndState,
            reason: "Shared waterfall layout math and skeleton rendering are identical on iOS and macOS."
        ),
        .init(
            file: "Features/CompanionChat/CompanionChatStore.swift",
            role: .sharedContentAndState,
            reason: "Feature state and seeded conversation data stay shared; only presentation may diverge later."
        ),
        .init(
            file: "Features/EarnSocial/EarnSocialExperienceStore.swift",
            role: .sharedContentAndState,
            reason: "Earn Social state and seeded data remain common runtime truth."
        ),
        .init(
            file: "Features/EarnSocial/EarnSocialHomeView.swift",
            role: .sharedContentAndState,
            reason: "Current page content and IA remain shared until a later desktop container is required."
        ),
        .init(
            file: "Features/Masters/MasterExperienceStore.swift",
            role: .sharedContentAndState,
            reason: "Master directory and conversation state stay shared even when container presentation diverges."
        ),
        .init(
            file: "Features/Shared/DiscoverMixedFeedSection.swift",
            role: .sharedContentAndState,
            reason: "Mixed-feed composition is shared content, not a desktop-only surface."
        ),
        .init(
            file: "Features/Shared/FeedCardProtocol.swift",
            role: .sharedContentAndState,
            reason: "Card taxonomy and ranking rules are platform-agnostic contracts."
        ),
        .init(
            file: "Features/Shared/UnifiedDiscoverFeedView.swift",
            role: .sharedContentAndState,
            reason: "The discover feed is a shared content surface and should not grow desktop-only business logic."
        ),
        .init(
            file: "Features/Shared/UnifiedWaterfallFeed.swift",
            role: .sharedContentAndState,
            reason: "Loading, empty, error, refresh, and masonry feed behavior are shared runtime concerns."
        ),
        .init(
            file: "Features/Xianxia/XianxiaHomeView.swift",
            role: .sharedContentAndState,
            reason: "Current Xianxia home content stays shared until a dedicated desktop container is introduced."
        ),
    ]

    // Explicit exceptions: when macOS diverges, it must do so in shell/container/interaction
    // wrappers instead of cloning feature trees or duplicating shared stores.
    static let explicitDesktopBranchFiles: [SparePlatformSurfaceEntry] = [
        .init(
            file: "App/MainTabView.swift",
            role: .desktopShell,
            reason: "Root tab chrome and workspace host may become sidebar/toolbar-based on desktop."
        ),
        .init(
            file: "Features/Masters/MasterChatHomeView.swift",
            role: .desktopContainer,
            reason: "The masters directory may switch from modal flow to list-detail or multi-column workspace."
        ),
        .init(
            file: "Features/Masters/MasterSpeechInputActions.swift",
            role: .desktopInteraction,
            reason: "Microphone recording affordances and press-to-talk interactions are platform-specific."
        ),
        .init(
            file: "Features/Xianxia/QRScanView.swift",
            role: .desktopInteraction,
            reason: "Camera capture, permission prompts, and scan affordances are platform hardware concerns."
        ),
    ]

    static let implementationPrinciples: [String] = [
        "Default new Apple-client files to shared content and state until a concrete desktop requirement proves otherwise.",
        "Route, store, card taxonomy, and content renderers stay shared even when the desktop host changes navigation chrome.",
        "When macOS needs a different workspace shape, extract a shared content/view-model core first, then wrap it in a desktop shell or container.",
        "Limit platform-only behavior to compat helpers or dedicated shell/container/interaction wrappers; feature business views should not accumulate raw #if os(...) checks."
    ]

    static func role(for file: String) -> SparePlatformSurfaceRole {
        if let branch = explicitDesktopBranchFiles.first(where: { $0.file == file }) {
            return branch.role
        }
        if let shared = directSharedFiles.first(where: { $0.file == file }) {
            return shared.role
        }
        return .sharedContentAndState
    }
}
