# Stage3IOSPathValidation

This package is the executable path-sensitive validation gate for the `ios/` lane restructure frozen on `2026-04-07`.

It runs against the current checkout instead of a copied snapshot so README drift, `ios/assets/**` string regressions, preview-host project references, plugin self-import behavior, and Swift tests all stay tied to the same repo truth.

The package-level assertions intentionally cover:

- repo docs and lane READMEs that must mention `Docs/Stage3_iOS_Path_Validation.md`, `Docs/scripts/validate_ios_paths.sh`, `swift test --package-path Docs/Stage3IOSPathValidation`, preview-host smoke, plugin self-import, and the current checkout contract
- asset and preview-host paths that must stay normalized to the `ios/` lane
- plugin self-import readiness from the current checkout package root
- Swift test anchors such as `ios/spare-life-ios-app/Tests/SpareLifeCoreTests/PlatformSurfacePolicyTests.swift`
- route-contract adjacency notes such as `crossTabHandoffContracts.mjs`

Primary entrypoints:

- `swift test --package-path Docs/Stage3IOSPathValidation`
- `Docs/scripts/validate_ios_paths.sh`

The shell script complements these tests with real preview-host and package smoke:

- `node --input-type=module` for plugin self-import
- `ruby generate_xcodeproj.rb`
- `xcodebuild -project SpareLifePreviewHost.xcodeproj`

If any of those commands stop matching the current checkout, `S3-090` is no longer satisfied.
