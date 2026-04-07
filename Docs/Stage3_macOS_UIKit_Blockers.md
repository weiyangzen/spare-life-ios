# Stage 3 macOS UIKit and iOS-only Blockers

## Why this exists

`S3-072` is not asking whether the shared pages can compile on macOS. That baseline already exists.

The real question is which current pages still carry implicit UIKit or iOS-only assumptions that block:

- 1:1 macOS UIUX mirroring beyond the root surface
- desktop-optimized list-detail or multi-column shells
- desktop-grade keyboard, camera, microphone, and interaction behavior

## Blocker Matrix

| Surface | Current dependency | Evidence in code | Impact on macOS parity / desktop optimization | Required extraction path |
| --- | --- | --- | --- | --- |
| `Features/Masters/MasterSpeechInputActions.swift` | `#if os(iOS)` + `AVFoundation` + `UIApplication.shared.sendAction(...)` | Press-to-talk recorder, transcription state, and keyboard dismissal all live inside the iOS-only view. | Hard blocker for a desktop `masters` workspace because microphone capture and composer actions cannot be mirrored by reusing this view as-is. | Split into shared transcription state/view model plus platform-specific speech interaction shell. |
| `Features/Xianxia/QRScanView.swift` | `AVFoundation`, camera session, photo-picker entry, `UIApplication.openSettingsURLString`, raw haptics | Scanner UI, permission recovery, torch control, and photo import are all bundled into the iOS page. | Hard blocker for macOS `xianxia` parity where scan/import must move to desktop panels or file-based import. | Extract scan result model + permission state into shared content, then branch camera/photo/settings affordances into desktop interaction wrappers. |
| `Features/CompanionChat/ChatThreadView.swift` | `UIApplication.shared.sendAction(...)`, iPhone bottom safe-area assumptions | Composer dismissal and bottom bar spacing still assume a mobile keyboard lifecycle. | Medium blocker for `messages` hub-thread-detail because desktop input wants toolbar/inspector behavior, not mobile keyboard dismissal semantics. | Keep thread state shared, move composer chrome into platform-specific layout shells. |
| `Features/Masters/MasterConversationView.swift` | `UIApplication.shared.sendAction(...)` for keyboard dismissal | Conversation compose flow still treats keyboard control as an iOS-only concern. | Medium blocker for desktop `masters` multi-column conversation layout. | Reuse shared conversation state, move input focus management into desktop shell/container. |
| `Features/Xianxia/SceneFeedCardViews.swift` | Raw `UIImpactFeedbackGenerator` in card tap path | Feed cards trigger UIKit haptics directly instead of going through compat helpers. | Low-to-medium blocker: macOS compiles, but shared interaction semantics are still encoded as iOS-only feedback. | Replace raw haptic calls with `spareImpactFeedback(...)` or a desktop interaction wrapper. |
| `Features/Xianxia/SceneAvatarRadarView.swift` | Raw `UIImpactFeedbackGenerator` on initiate action | Avatar interaction feedback is UIKit-specific. | Low-to-medium blocker for desktop hover/context-menu treatment. | Keep avatar/content shared, route feedback to compat or desktop interaction layer. |
| `Features/Xianxia/SceneSocialIntentView.swift` | Raw `UIImpactFeedbackGenerator` / `UINotificationFeedbackGenerator` | Submit/success flows still depend on iOS haptics. | Low-to-medium blocker for desktop confirmation flows and keyboard-driven actions. | Keep submit/result state shared, branch confirmation feedback in interaction shell. |
| `App/MainTabView.swift` | Floating bottom tab bar with mobile safe-area tuning | Current shared shell is explicitly iOS-first even though macOS already branches to `Stage3MacOSDesktopShellView`. | Not a compile blocker, but it shows why desktop optimization must live in shell/container layers instead of inside feature views. | Continue to keep tab semantics shared and desktop chrome in dedicated macOS shell code. |

## Page-level desktop optimization priorities

| Page | Current state | Primary blocker | Preferred next shell |
| --- | --- | --- | --- |
| `messages` | Shared page opens on macOS, but thread composer still carries mobile keyboard behavior. | Thread input and sub-surface presentation remain mobile-first. | Shared message/thread view model + desktop hub-thread-detail shell. |
| `masters` | Shared page opens on macOS, but conversation and speech input still mix iOS-only behavior. | Speech recording and keyboard dismissal are not desktop-shaped. | Shared directory/conversation state + desktop list-detail workspace shell. |
| `xianxia` | Shared page opens on macOS, but scanner and card feedback are still iOS-oriented. | Camera/scan affordances and action feedback remain mobile-specific. | Shared feed/detail state + desktop list-detail shell plus desktop scan/import interaction wrapper. |
| `earnSocial` | Shared root already compiles; no direct hard UIKit blocker identified in the root page. | The missing work is density/layout optimization rather than API portability. | Shared experience store + denser desktop content shell. |
| `myProfile` | Shared root already compiles; most blockers are downstream modal/metric layout density rather than hard APIs. | Needs panel/inspector structure, not duplicated business logic. | Shared profile state + desktop dashboard shell. |

## Stage 3 rule

These blockers should not be solved by copying page trees into `app/macos`.

The correct Stage 3 fix order is:

1. Extract shared content/state/view-model logic.
2. Move platform-only keyboard/camera/microphone/haptic behavior into compat helpers or desktop interaction wrappers.
3. Add desktop layout shells that change workspace structure without forking route/store/business logic.
