# spare-life-ios

Client repository for `weiyangzen/spare-life-ios`.

## Branding

Current app logo source:

- `ios/assets/branding/spare-life-logo.jpeg`
- imported from `Downloads/Gemini_Generated_Image_o7xrryo7xrryo7xr.jpeg`

## Workspace Layout

- `Docs/`: repo-level blueprints, reports, validation logs, and research notes.
- `ios/`: Apple-client lane, including the Swift package app, preview host, OpenClaw plugin workspace, and local assets.
- `android/`: placeholder for the future Android client lane.
- `app/`: desktop lane placeholders for the shared Rust/Tauri surface split into `windows11`, `macos`, and `ubuntu`.

## Local Joint Debug Layout

- The server checkout is expected at `../spare-life-server` for client/server joint debugging.
- As of `2026-04-06`, the upstream `alphane-ai/spare-life-server` clone at that path is present but empty, so the sibling path contract is ready even though no server working tree content is available yet.
- In the current Stage 3 worker checkout, the effective same-machine sibling path resolves to `/Users/wangweiyang/GitHub/spare-life-server`; `server-backed joint debug` stays `gated` until that repo has tracked files.

## Apple Parity And Verification Matrix

- `S3-094` is frozen in [Docs/Stage3_Apple_Parity_Checklists.md](/Users/wangweiyang/GitHub/spare-life-ios/.cron/stage3_exec_repo_slot4/Docs/Stage3_Apple_Parity_Checklists.md). It keeps iOS/macOS page parity and desktop optimization tied to `validate_stage3_shared_surface.sh`, `validate_stage3_messages_typed_routes.sh`, and `validate_stage3_macos_smoke.sh`.
- `S3-095` and `S3-096` are frozen in [Docs/Stage3_Verification_Matrix.md](/Users/wangweiyang/GitHub/spare-life-ios/.cron/stage3_exec_repo_slot4/Docs/Stage3_Verification_Matrix.md), [Docs/scripts/validate_stage3_verification_matrix.sh](/Users/wangweiyang/GitHub/spare-life-ios/.cron/stage3_exec_repo_slot4/Docs/scripts/validate_stage3_verification_matrix.sh), and [Docs/scripts/validate_stage3_joint_debug_contracts.sh](/Users/wangweiyang/GitHub/spare-life-ios/.cron/stage3_exec_repo_slot4/Docs/scripts/validate_stage3_joint_debug_contracts.sh).
- The matrix explicitly separates `plugin-demo`, `client-only-local-seed`, and `server-backed joint debug`, and it keeps the server lane visibly `gated` instead of pretending the empty sibling checkout is already wired runtime.

## iOS Path Validation

- `S3-090` is frozen by [Docs/Stage3_iOS_Path_Validation.md](/Users/wangweiyang/GitHub/spare-life-ios/.cron/stage3_exec_repo_slot4/Docs/Stage3_iOS_Path_Validation.md), [Docs/scripts/validate_ios_paths.sh](/Users/wangweiyang/GitHub/spare-life-ios/.cron/stage3_exec_repo_slot4/Docs/scripts/validate_ios_paths.sh), and [Docs/Stage3IOSPathValidation](/Users/wangweiyang/GitHub/spare-life-ios/.cron/stage3_exec_repo_slot4/Docs/Stage3IOSPathValidation).
- Run `swift test --package-path Docs/Stage3IOSPathValidation` to assert README/docs sync, `ios/assets/**` string normalization, preview-host references, plugin self-import expectations, and Swift test anchors.
- The smoke chain is intentionally run against the current checkout so path-sensitive regressions in preview-host, plugin import, or route-contract adjacency are caught before they drift into generated artifacts.
- The validation docs also pin `crossTabHandoffContracts.mjs` as part of the current checkout contract surface, so route normalization notes stay aligned with the `ios/` lane move.
