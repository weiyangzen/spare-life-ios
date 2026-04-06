# macOS Desktop Lane

Stage 3 Wave 0 uses this lane to freeze the macOS target contract before a real host app exists.

## Stage 3 target

- Base the macOS app on the current `iOS / iPad landscape` UIUX.
- Mirror the same visual language and information architecture before adding desktop-only affordances.
- Keep runtime truth in `ios/spare-life-ios-app`, which already declares `.macOS(.v13)` support.
- Limit macOS-specific divergence to shell, container, and interaction layers.

## What lives here today

- `Stage3MacOSTargetContract`: the executable contract for S3-050.
- `stage3-macos-target-smoke`: a smoke entrypoint that validates the current `MainTabView` mirror against the frozen Stage 3 target.

## What does not live here yet

- A real macOS host app. That remains S3-051.
- A second feature tree, duplicated stores, or a macOS-only information architecture fork.
