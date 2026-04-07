# Stage 3 iOS Path Validation

Date frozen: `2026-04-07`

`S3-090` exists to keep the `ios/` lane move honest. The validation gate must run against the current checkout, not against hand-copied notes or stale generated artifacts, because the failure mode here is path drift rather than logic drift.

## Covered surface

- README and lane docs: root `README.md`, `ios/README.md`, this document, and `Docs/Stage3IOSPathValidation/README.md` must continue to advertise the same validation commands and `ios/` lane boundaries.
- Asset strings: runtime-facing strings that point at `ios/assets/**` must stay normalized after the move from the repo root.
- Preview-host smoke: the host project and generator must continue to reference `../assets/...` and `../spare-life-ios-app/...` from the `ios/spare-life-ios-preview-host/` lane.
- Plugin self-import: the OpenClaw package must still self-resolve from the current checkout without pretending the plugin is already published or wired through another host.
- Swift tests: both the path-validation package and the shared-surface Swift tests must remain executable.

## Command matrix

1. Path-validation Swift tests:

```bash
swift test --package-path Docs/Stage3IOSPathValidation
```

This command is the test gate for `S3-090`. It asserts that the new `ios/` layout keeps README/docs sync, `ios/assets/**` strings, preview-host references, plugin import assumptions, and the canonical Swift test path `ios/spare-life-ios-app/Tests/SpareLifeCoreTests/PlatformSurfacePolicyTests.swift`.

2. Shared compatibility typecheck:

```bash
xcrun swiftc -typecheck \
  -target arm64-apple-macos13.0 \
  -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
  ios/spare-life-ios-app/App/DesignSystem/DesignTokens.swift \
  ios/spare-life-ios-app/App/DesignSystem/PlatformCompat.swift \
  ios/spare-life-ios-app/App/DesignSystem/PlatformSurfacePolicy.swift \
  ios/spare-life-ios-app/App/DesignSystem/WaterfallLayout.swift \
  ios/spare-life-ios-app/Features/Shared/FeedCardProtocol.swift \
  ios/spare-life-ios-app/Features/Shared/UnifiedWaterfallFeed.swift \
  ios/spare-life-ios-app/Features/Shared/DiscoverMixedFeedSection.swift \
  ios/spare-life-ios-app/Features/Shared/UnifiedDiscoverFeedView.swift
```

3. Plugin self-import from the current checkout:

```bash
(
  cd ios/spare-life-openclaw-plugin
  node --input-type=module -e "import { ClawdbTopicsClient } from 'spare-life-openclaw-plugin'; if (typeof ClawdbTopicsClient !== 'function') throw new Error('plugin self-import failed')"
)
```

4. Preview-host smoke from an isolated copy of the current checkout:

```bash
(
  cd "$TMPDIR/.../ios/spare-life-ios-preview-host"
  ruby generate_xcodeproj.rb
  xcodebuild -project SpareLifePreviewHost.xcodeproj \
    -scheme SpareLifePreviewHost \
    -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' \
    CODE_SIGNING_ALLOWED=NO \
    build
)
```

The preview-host step is intentionally staged in a temp copy so validation can prove `ruby generate_xcodeproj.rb` and `xcodebuild -project SpareLifePreviewHost.xcodeproj` still work without mutating tracked files outside the worker's write scope.

## Contract notes

- `crossTabHandoffContracts.mjs` remains part of the current checkout contract surface because route normalization is still anchored in `ios/spare-life-ios-app/Domain/Models/`.
- `Docs/scripts/validate_ios_paths.sh` is the single shell entrypoint expected to replay the matrix above.
- Failing any one of these commands means the repo is describing the `ios/` restructure more optimistically than the runtime truth supports.
