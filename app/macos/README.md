# macOS Desktop Lane

Reserved for the macOS desktop host under the shared Rust/Tauri app organization.

Current Stage 3 runtime truth still lives in `ios/spare-life-ios-app`, whose Swift package already declares macOS support.
When this lane becomes active, it should only own macOS shell/container/interaction wrappers and must not fork a second copy of the feature page tree or shared stores.
