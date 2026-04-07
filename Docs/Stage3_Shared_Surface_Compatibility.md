# Stage 3 Shared Surface Compatibility

## Scope

This document freezes the Stage 3 implementation for:

- `S3-071` minimal iOS/macOS compatibility checks for `DesignTokens`, `PlatformCompat`, `WaterfallLayout`, and shared feed components.
- `S3-075` the preferred desktop-optimization pattern: shared view model plus platform-specific layout shell.

The authoritative runtime truth remains the current source set under `ios/spare-life-ios-app/`.

## Minimum Compatibility Matrix

The explicit compatibility anchors live in `ios/spare-life-ios-app/App/DesignSystem/PlatformCompat.swift` under `Stage3SharedSurfaceCompatibilityMatrix.minimumChecks()`.

| Area | Files | Compile/smoke anchors | Contract |
| --- | --- | --- | --- |
| `design-tokens` | `App/DesignSystem/DesignTokens.swift` | `Color.spareYellow`, `EmptyStateView`, `ErrorStateView`, `CardPressStyle` | Shared palette, typography, placeholders, and empty/error primitives must compile unchanged on iOS and macOS. |
| `platform-compat` | `App/DesignSystem/PlatformCompat.swift` | `spareBottomSafeAreaInset()`, `ToolbarItemPlacement.spareNavigationLeading`, `SpareNavigationBarTitleDisplayMode.inline` | UIKit-only affordances stay behind compat shims; macOS resolves to AppKit or no-op behavior instead of leaking raw `#if os(...)` into feature logic. |
| `waterfall-layout` | `App/DesignSystem/WaterfallLayout.swift` | `WaterfallColumns.count(for:)`, `ResponsiveMasonryLayout`, `WaterfallGrid` | Layout math, skeletons, and width heuristics remain shared across both Apple targets. |
| `shared-feed` | `Features/Shared/FeedCardProtocol.swift`, `Features/Shared/UnifiedWaterfallFeed.swift`, `Features/Shared/DiscoverMixedFeedSection.swift`, `Features/Shared/UnifiedDiscoverFeedView.swift` | `FeedSorter.sorted(_)`, `UnifiedWaterfallFeed`, `DiscoverMixedFeedSection`, `UnifiedDiscoverFeedView` | Feed ranking, loading/empty/error behavior, and discover-page content stay in one shared runtime path. |

## Shared View Model + Platform Shell

`UnifiedDiscoverFeedView.swift` now serves as the Stage 3 reference pattern for desktop optimization:

- `DiscoverFeedViewModel` owns shared load state, ranking, filters, pinned-banner selection, refresh, and retry behavior.
- `SharedFeedLayoutShell` owns only outer workspace layout.
- iOS keeps the inline mobile stack.
- macOS switches to a denser workspace shell with padded control/content panels, without cloning feed ranking or load logic.

This is the intended extraction order for later desktop-optimized pages:

1. Keep content/state in a shared view model or shared feature store.
2. Branch only the outer shell/container that changes layout density or workspace framing.
3. Keep `#if os(...)` out of feature business logic unless the code is explicitly a shell/container/interaction wrapper.

The next candidates to follow this pattern are `xianxia`, `messages`, `masters`, `earnSocial`, and `myProfile`, where desktop optimization should wrap shared content instead of duplicating route/store logic.

## Validation Chain

Run these commands from the repo root:

```bash
xcodebuild -scheme SpareLifeCore -destination 'generic/platform=iOS Simulator' build
xcodebuild -scheme SpareLifeApp-Package -destination 'platform=macOS' test
bash Docs/scripts/validate_stage3_shared_surface.sh
```

Notes:

- `swift build/test --package-path ios/spare-life-ios-app` is currently not authoritative because `Package.swift` still exposes `Domain/Models/crossTabHandoffContracts.mjs` as a loose file to SwiftPM CLI, even though Xcode builds succeed with only warnings.
- `ios/spare-life-ios-preview-host` is also not the Stage 3 compatibility authority because its current asset copy phase expects resource directories that are absent in this checkout.
- `app/macos` package-level smoke is temporarily bypassed because its manifest still points to missing test paths; the shared-surface smoke script compiles the current shared source set directly instead.
