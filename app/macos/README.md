# macOS Desktop Lane

Stage 3 Wave 1 turns this lane into the real macOS host while keeping the Stage 3 target contract executable.

## Stage 3 target

- Base the macOS app on the current `iOS / iPad landscape` UIUX.
- Mirror the same visual language and information architecture before adding desktop-only affordances.
- Keep runtime truth in `ios/spare-life-ios-app`, which already declares `.macOS(.v13)` support.
- Limit macOS-specific divergence to shell, container, and interaction layers.

## What lives here today

- `Stage3MacOSTargetContract`: the executable contract for S3-050.
- `Stage3MacOSRuntime`: the macOS runtime wrapper that compiles the shared SwiftUI surface from `ios/spare-life-ios-app` inside this lane.
- `stage3-macos-app`: the real macOS host entrypoint that boots the shared `MainTabView`.
- `stage3-macos-target-smoke`: validates the current `MainTabView` mirror against the frozen Stage 3 target.
- `stage3-macos-surface-smoke`: realizes the shared root plus `xianxia / masters / earnSocial / messages / myProfile` as real macOS hosting surfaces.

## Shared source intake

- `Shared/SpareLifeCoreSource` is a symlink back to `ios/spare-life-ios-app`.
- The runtime compiles the existing shared `App / Features / Domain/Models` sources directly, while keeping the package-only workaround local to `app/macos`.
- No second macOS feature tree is duplicated here.

## What still does not live here

- A second feature tree, duplicated stores, or a macOS-only information architecture fork.
