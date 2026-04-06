#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "[stage3-ios-path-validation] repo root: ${REPO_ROOT}"

cd "${REPO_ROOT}"

echo "[stage3-ios-path-validation] package docs"
swift test --package-path Docs/Stage3IOSPathValidation

echo "[stage3-ios-path-validation] shared swift typecheck"
xcrun --sdk iphonesimulator swiftc -typecheck \
  -target arm64-apple-ios16.0-simulator \
  ios/spare-life-ios-app/App/DesignSystem/PlatformCompat.swift \
  ios/spare-life-ios-app/App/DesignSystem/PlatformSurfacePolicy.swift

echo "[stage3-ios-path-validation] route contract anchor"
test -f ios/spare-life-ios-app/Domain/Models/crossTabHandoffContracts.mjs

echo "[stage3-ios-path-validation] plugin self-import"
(
  cd ios/spare-life-openclaw-plugin
  node --input-type=module -e "import { ClawdbTopicsClient } from 'spare-life-openclaw-plugin'; if (typeof ClawdbTopicsClient !== 'function') throw new Error('plugin self-import failed'); console.log('plugin self-import ok')"
)

echo "[stage3-ios-path-validation] preview-host smoke from isolated copy"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/stage3-ios-path-validation.XXXXXX")"
trap 'rm -rf "${TEMP_ROOT}"' EXIT

cp -R "${REPO_ROOT}/ios" "${TEMP_ROOT}/ios"

(
  cd "${TEMP_ROOT}/ios/spare-life-ios-preview-host"
  ruby generate_xcodeproj.rb
  xcodebuild -project SpareLifePreviewHost.xcodeproj \
    -scheme SpareLifePreviewHost \
    -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' \
    CODE_SIGNING_ALLOWED=NO \
    build
)

echo "[stage3-ios-path-validation] complete"
