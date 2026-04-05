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
