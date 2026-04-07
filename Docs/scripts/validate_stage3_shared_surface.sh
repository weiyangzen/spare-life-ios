#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/stage3_shared_surface_smoke.XXXXXX")"
SMOKE_SWIFT="$TMP_DIR/Stage3SharedSurfaceSmoke.swift"
SMOKE_BIN="$TMP_DIR/stage3_shared_surface_smoke"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cat >"$SMOKE_SWIFT" <<'SWIFT'
import Foundation
import SwiftUI

@main
struct Stage3SharedSurfaceSmokeMain {
    @MainActor
    static func main() {
        let checks = Stage3SharedSurfaceCompatibilityMatrix.minimumChecks()
        print("Stage 3 shared surface smoke ok: \(checks.count) compatibility areas.")
        for line in Stage3SharedSurfaceCompatibilityMatrix.summaryLines() {
            print(line)
        }
    }
}
SWIFT

xcrun swiftc \
  -target arm64-apple-macos13.0 \
  -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
  "$ROOT/ios/spare-life-ios-app/App/DesignSystem/DesignTokens.swift" \
  "$ROOT/ios/spare-life-ios-app/App/DesignSystem/PlatformCompat.swift" \
  "$ROOT/ios/spare-life-ios-app/App/DesignSystem/WaterfallLayout.swift" \
  "$ROOT/ios/spare-life-ios-app/Features/Shared/FeedCardProtocol.swift" \
  "$ROOT/ios/spare-life-ios-app/Features/Shared/UnifiedWaterfallFeed.swift" \
  "$ROOT/ios/spare-life-ios-app/Features/Shared/DiscoverMixedFeedSection.swift" \
  "$ROOT/ios/spare-life-ios-app/Features/Shared/UnifiedDiscoverFeedView.swift" \
  "$SMOKE_SWIFT" \
  -o "$SMOKE_BIN"

"$SMOKE_BIN"
