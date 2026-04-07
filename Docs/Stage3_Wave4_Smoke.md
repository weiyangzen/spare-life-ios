# Stage 3 Wave 4 Smoke

This document freezes the real smoke chain for:

- `S3-091` OpenClaw IM lane smoke
- `S3-092` shared `messages` typed route smoke
- `S3-093` macOS parity + desktop optimization smoke

The current checkout remains the only runtime truth. These scripts intentionally compile or execute the live source tree instead of trusting the broken SwiftPM manifests under `ios/spare-life-ios-app` and `app/macos`.

## Commands

Run these commands from the repo root:

```bash
bash Docs/scripts/validate_stage3_openclaw_im_smoke.sh
bash Docs/scripts/validate_stage3_messages_typed_routes.sh
bash Docs/scripts/validate_stage3_macos_smoke.sh
```

## S3-091 OpenClaw IM Smoke

`Docs/scripts/validate_stage3_openclaw_im_smoke.sh` executes `ios/spare-life-openclaw-plugin/src/demo/companion-chat-flow-demo.mjs` and fails unless the current runtime produces all of the following from a real SQLite-backed OpenClaw companion session:

- `messages home` with canonical home handoff
- DM open via locator and DM send on a direct surface
- group open and group send with low-signal suppression
- group vote launch/cast/close with a persisted result summary
- group summary persistence
- companion inspect surfaced as diagnostics/internal tool instead of a fake thread subpage

This smoke is intentionally anchored to the live plugin demo because that is the real OpenClaw IM lane in the current repo. It does not treat string contracts or docs-only payloads as proof.

## S3-092 Messages Typed Route Smoke

`Docs/scripts/validate_stage3_messages_typed_routes.sh` directly compiles the current shared Swift source set from:

- `ios/spare-life-ios-app/App/ConversationRouter.swift`
- `ios/spare-life-ios-app/App/CrossTabHandoff.swift`
- `ios/spare-life-ios-app/App/AppHandoffRouter.swift`
- `ios/spare-life-ios-app/App/DesignSystem/**`
- `ios/spare-life-ios-app/Features/CompanionChat/**`
- `ios/spare-life-ios-app/Features/Shared/**`

The generated smoke host renders `MessagesFeatureRootView` as a real AppKit-hosted SwiftUI surface and asserts:

- `hub -> thread`
- `thread -> relationship`
- `thread -> memory`
- `thread -> quadRole`
- `thread -> groupPlay`
- `subpage -> home`

For each step, it verifies the canonical `router.path`, current route, handoff hint, and non-empty rendered layout.

## S3-093 macOS Parity + Desktop Smoke

`Docs/scripts/validate_stage3_macos_smoke.sh` bypasses the currently invalid `app/macos/Package.swift` test paths and directly compiles:

- `app/macos/Sources/Stage3MacOSTargetContract/**`
- `app/macos/Sources/Stage3MacOSRuntime/**` except `Stage3MacOSHostResources.swift`
- the shared `app/macos/Shared/SpareLifeCoreSource/**` intake that the macOS lane already mirrors

The generated smoke host validates:

- the five mirrored main pages remain `xianxia / master / earnSocial / messages / myProfile`
- the shared macOS root shell renders at both default desktop size and minimum desktop size
- all mirrored pages render at both default and minimum desktop sizes
- every workspace snapshot still exposes a multi-column desktop layout
- the macOS messages workspace can enter `thread`, enter `relationship`, and return to `home` through the shared typed route

This is the authoritative Stage 3 macOS parity evidence until the `app/macos` manifest itself is repaired.
