# iOS Lane

- `spare-life-ios-app/`: Swift package app runtime that already declares both iOS and macOS platforms; shared content/state stays here until a desktop host needs shell/container/interaction wrappers.
- `spare-life-ios-preview-host/`: preview host, UI test shell, and helper scripts.
- `spare-life-openclaw-plugin/`: OpenClaw plugin workspace and demo/runtime glue.
- `assets/`: local client assets kept with the Apple client lane.

## Validation

- Path-sensitive validation for the lane move lives in [Docs/Stage3_iOS_Path_Validation.md](/Users/wangweiyang/GitHub/spare-life-ios/.cron/stage3_exec_repo_slot4/Docs/Stage3_iOS_Path_Validation.md), [Docs/scripts/validate_ios_paths.sh](/Users/wangweiyang/GitHub/spare-life-ios/.cron/stage3_exec_repo_slot4/Docs/scripts/validate_ios_paths.sh), and [Docs/Stage3IOSPathValidation](/Users/wangweiyang/GitHub/spare-life-ios/.cron/stage3_exec_repo_slot4/Docs/Stage3IOSPathValidation).
- Run `swift test --package-path Docs/Stage3IOSPathValidation` before claiming the new `ios/` layout is stable.
- The gate checks `ios/assets/**`, preview-host smoke, plugin self-import, the current checkout docs, and Swift tests together so the `ios/` lane does not silently drift back to root-level assumptions.
- Keep `crossTabHandoffContracts.mjs` in the current checkout contract discussion: route normalization still lives beside the shared Swift/package surface.
- Wave 4 smoke for the Apple lane now lives in [Docs/Stage3_Wave4_Smoke.md](/Users/wangweiyang/GitHub/spare-life-ios/.cron/stage3_exec_repo_slot4/Docs/Stage3_Wave4_Smoke.md), [Docs/scripts/validate_stage3_openclaw_im_smoke.sh](/Users/wangweiyang/GitHub/spare-life-ios/.cron/stage3_exec_repo_slot4/Docs/scripts/validate_stage3_openclaw_im_smoke.sh), and [Docs/scripts/validate_stage3_messages_typed_routes.sh](/Users/wangweiyang/GitHub/spare-life-ios/.cron/stage3_exec_repo_slot4/Docs/scripts/validate_stage3_messages_typed_routes.sh).
- Those scripts run against the current checkout because the real OpenClaw IM lane is the plugin demo/runtime and the real `messages` route surface is the shared SwiftUI source tree, not the currently broken SwiftPM package manifests.
- Apple page parity and desktop optimization acceptance live in [Docs/Stage3_Apple_Parity_Checklists.md](/Users/wangweiyang/GitHub/spare-life-ios/.cron/stage3_exec_repo_slot4/Docs/Stage3_Apple_Parity_Checklists.md).
- The three-tier verification matrix lives in [Docs/Stage3_Verification_Matrix.md](/Users/wangweiyang/GitHub/spare-life-ios/.cron/stage3_exec_repo_slot4/Docs/Stage3_Verification_Matrix.md) and [Docs/scripts/validate_stage3_verification_matrix.sh](/Users/wangweiyang/GitHub/spare-life-ios/.cron/stage3_exec_repo_slot4/Docs/scripts/validate_stage3_verification_matrix.sh), which keeps `plugin-demo`, `client-only-local-seed`, and `server-backed joint debug` separate and truthful for the current checkout.
