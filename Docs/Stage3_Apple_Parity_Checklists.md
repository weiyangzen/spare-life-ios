# Stage 3 Apple Parity Checklists

Date frozen: `2026-04-07`

This document is the executable acceptance checklist for `S3-094`.

The current runtime truth stays in:

- `ios/spare-life-ios-app/App/MainTabView.swift`
- `ios/spare-life-ios-app/Features/**`
- `app/macos/Sources/Stage3MacOSRuntime/**`
- `app/macos/Sources/Stage3MacOSTargetContract/**`

It exists to stop two common failures:

1. iOS and macOS keep the same page names while the actual content, entry path, or route semantics have already drifted apart.
2. macOS claims "desktop optimization" while only enlarging the iOS page instead of adding a real desktop shell, catalog, inspector, or toolbar workflow.

## Validation Anchors

Run these commands from the repo root:

```bash
bash Docs/scripts/validate_stage3_shared_surface.sh
bash Docs/scripts/validate_stage3_messages_typed_routes.sh
bash Docs/scripts/validate_stage3_macos_smoke.sh
```

These commands are the only acceptance anchors for this checklist:

- `validate_stage3_shared_surface.sh` keeps shared Apple source truthful, including `UnifiedDiscoverFeedView`, `PlatformCompat`, `WaterfallLayout`, and shared feed primitives.
- `validate_stage3_messages_typed_routes.sh` proves `MessagesFeatureRootView` still runs the canonical `home -> thread -> relationship / memory / groupPlay / quadRole` route path from the current checkout.
- `validate_stage3_macos_smoke.sh` proves the current macOS host still opens the five mirrored pages, keeps multi-column workspaces, and returns from `messages` detail back to `home`.

## Shared Page Parity Checklist

Every row below must stay true before parity can be claimed.

| Surface | iOS runtime truth | macOS runtime truth | Must stay mirrored | Smoke / contract anchor |
| --- | --- | --- | --- | --- |
| Shell order | `MainTabView` tab order | `Stage3MacOSRuntime.mirroredPages` | `xianxia / master / earnSocial / messages / myProfile` order, labels, and entry meaning stay identical | `validate_stage3_macos_smoke.sh` checks mirrored page order |
| `xianxia` | `XianxiaHomeView` | `Stage3MacOSXianxiaWorkspaceView` | topic feed cards, shard detail semantics, refresh path, and topic metadata remain the same content system | `workspaceSnapshot(for: "xianxia")`, `validate_stage3_macos_smoke.sh` |
| `master` | `MasterChatHomeView` | `Stage3MacOSMastersWorkspaceView` | master directory, conversation session, recent-session restore, and domain filter semantics stay the same runtime path | `workspaceSnapshot(for: "master")`, `validate_stage3_macos_smoke.sh` |
| `earnSocial` | `EarnSocialHomeView` | `Stage3MacOSEarnSocialWorkspaceView` | same category rails, waterfall cards, card chat entry, and preference entry; current runtime truth remains local mock market, not a hidden live backend | `workspaceSnapshot(for: "earnSocial")`, `validate_stage3_macos_smoke.sh` |
| `messages` | `MessagesFeatureRootView` | `Stage3MacOSMessagesWorkspaceView` | same canonical locator, typed route stack, thread subpages, and home/thread recovery semantics | `validate_stage3_messages_typed_routes.sh`, `validate_stage3_macos_smoke.sh` |
| `myProfile` | `MyProfileView` | `Stage3MacOSProfileWorkspaceView` | same profile metrics, dashboard surfaces, route targets, and backend/diagnostic truth labels | `workspaceSnapshot(for: "myProfile")`, `validate_stage3_macos_smoke.sh` |
| Shared primitives | `PlatformCompat`, `DesignTokens`, `WaterfallLayout`, `UnifiedDiscoverFeedView`, shared feed components | Same shared source intake under `app/macos` | palette, copy, empty/loading/error states, feed ranking, and shared cards stay single-source | `validate_stage3_shared_surface.sh` |

## Page-Level Parity Acceptance

- `xianxia`: macOS must still expose topic catalog, topic detail, and topic inspector as the desktop shell around the same topic/shard content, not a separate xianxia product.
- `master`: macOS must still expose master cards, conversation session, and recent-session context from the shared master runtime, not a second conversation system.
- `earnSocial`: macOS must still surface the same category/card/preference semantics that live in `EarnSocialHomeView`, while clearly labeling the current surface as seeded/local runtime truth.
- `messages`: macOS must still consume the same canonical `MessagesConversationLocator`, thread identity, and `MessagesFeatureRootView` semantics that iOS uses.
- `myProfile`: macOS must still use the same metrics/dashboard/provenance model as iOS, including seeded fallback vs live-ish truth labels.

## Desktop Optimization Checklist

The desktop lane only passes when it adds a real workspace shell on top of shared content.

| Surface | Required desktop optimization | Not acceptable | Current evidence |
| --- | --- | --- | --- |
| Shell | sidebar + top toolbar + segmented control | enlarging the iOS bottom-tab shell without desktop chrome | `Stage3MacOSRuntime.desktopShellSnapshot()` |
| `xianxia` | list-detail-inspector workspace | one long centered mobile feed | `layoutStyle = list-detail-inspector`, columns `topic catalog / topic detail / topic inspector` |
| `master` | directory-session-inspector workspace | modal-only conversation flow on a wide screen | `layoutStyle = directory-session-inspector` |
| `earnSocial` | category catalog + market canvas + inspector | a single enlarged `EarnSocialHomeView` with no desktop context column | `layoutStyle = market-canvas-inspector` |
| `messages` | hub-thread-detail workspace with typed-route detail in the center column | same thread sheet stack, only scaled larger | `layoutStyle = hub-thread-detail`, `MessagesFeatureRootView` route smoke |
| `myProfile` | identity summary + dashboard + backend inspector | one long mobile dashboard with no provenance or backend context column | `layoutStyle = identity-dashboard-inspector` |

## Desktop-Wide Optimization Acceptance

- Toolbar search and toolbar filter must exist as desktop chrome, not only as inline mobile controls.
- Sidebar and inspector must be collapsible desktop containers, not ad-hoc view-local conditionals.
- Parallel workspace columns must carry detail and diagnostics that would otherwise be hidden behind mobile modal stacks.
- Desktop optimization must preserve shared copy, shared semantic states, and the same module boundaries described by `Stage3MacOSRuntime.visualParitySnapshot()`.

## Rejection Rules

Reject parity if any of the following becomes true:

- page names still match, but iOS and macOS no longer expose the same route target or content structure
- macOS introduces a second feature tree or second store path for a mirrored page
- a page claims desktop optimization but has no stable catalog/detail/inspector split
- shared feed/runtime primitives drift apart across Apple targets while the page still claims "same surface"

Code and live smoke override this document if they conflict.
