# Stage 3 Codebase Audit

## Scope

This document summarizes the current Spare Life iOS repository from the code outward.

Interpretation order for Stage 3:

1. Runtime code under `spare-life-ios-app/App`, `spare-life-ios-app/Features`, and the tests in `spare-life-ios-app/Tests`
2. Supporting runtime-adjacent code that affects integration boundaries, including `spare-life-ios-app/LocalBackend`, `spare-life-ios-app/Services`, `spare-life-ios-app/Domain/UseCases`, and `spare-life-openclaw-plugin`
3. Existing docs under `Docs/`
4. This audit

If code and docs conflict, code wins.

## Stage 3 Design Philosophy

`以代码现状为唯一运行真相，优先做边界清晰、文档可验证、状态可追踪、能持续收敛返工的 iOS 架构优化。`

## Current App Design

### 1. App shell

- The app shell lives in `spare-life-ios-app/App/MainTabView.swift`.
- The runtime has 5 tabs: `xianxia`, `master`, `earnSocial`, `messages`, `myProfile`.
- The bottom bar is a custom floating `SpareTabBar`, not the system tab bar.
- A lightweight `ConversationRouter` exists in `spare-life-ios-app/App/ConversationRouter.swift`, but it currently routes only message-thread presentation.
- The package target `SpareLifeCore` is defined in `spare-life-ios-app/Package.swift` and compiles only Swift code under `App`, `Domain/Models`, and `Features`. The `.mjs` services, local backend code, and plugin code are not part of the Swift package runtime target.

### 2. Shared UI layer

- Shared layout primitives live in `spare-life-ios-app/App/DesignSystem` and `spare-life-ios-app/Features/Shared`.
- `WaterfallLayout`, `WaterfallColumns`, `UnifiedWaterfallFeed`, and related shared card abstractions are reused across multiple home pages.
- The visual direction is mostly consistent: warm yellow accent, light mode, rounded card language, feed-first home screens.
- The shared layer is real, but page-level header/search/filter implementations are still repeated rather than fully extracted as one page-chrome system.

### 3. `闲虾 / xianxia` module

- Main entry: `spare-life-ios-app/Features/Xianxia/XianxiaHomeView.swift`
- Detail page and repository: `spare-life-ios-app/Features/Xianxia/SceneTopicView.swift`
- This module is the most clearly connected live-data path in the current app shell.
- `XianxiaTopicRepository` already supports:
  - environment and `UserDefaults` based gateway configuration
  - HTTP fetches for topics and shards
  - cache snapshots
  - pagination cursors
  - repository tests in `spare-life-ios-app/Tests/SpareLifeCoreTests/XianxiaTopicRepositoryTests.swift`
- Important code reality:
  - the module is architecturally view-heavy because models, repository, config, errors, parsing helpers, and views live in one large file
  - `loadMore()` in both `XianxiaHomeViewModel` and `SceneTopicViewModel` replaces existing arrays with the newest batch instead of appending, so the documented pagination story is stronger than the current code behavior

### 4. `闲聊 / masters` module

- Home entry: `spare-life-ios-app/Features/Masters/MasterChatHomeView.swift`
- Core state owner: `spare-life-ios-app/Features/Masters/MasterExperienceStore.swift`
- Conversation UI: `spare-life-ios-app/Features/Masters/MasterConversationView.swift`
- ASR path: `spare-life-ios-app/Features/Masters/MasterASRService.swift`
- Tests cover:
  - catalog loading
  - conversation and speech flow
  - ASR diagnostics
  - state restore behavior
- This module is the most sophisticated in terms of runtime diagnostics and fallback strategy.
- Important code reality:
  - one very large store owns catalog loading, session state, diagnostics, asset interpretation, remote conversation behavior, and local fallback logic
  - the code already distinguishes live candidate vs live connected vs local fallback more honestly than most other modules
  - the Stage 2 doc around masters is operationally rich, but it mixes requirement, diagnosis, and repeated run log lines in the same authoritative document

### 5. `赚闲能 / earn social` module

- Home entry: `spare-life-ios-app/Features/EarnSocial/EarnSocialHomeView.swift`
- Large state model exists in `spare-life-ios-app/Features/EarnSocial/EarnSocialExperienceStore.swift`
- Important code reality:
  - the actual home page currently uses local in-file `EarnSocialMockFixtures`
  - the large `EarnSocialExperienceStore` is not the active home-page runtime path
  - this creates a dual-path architecture: a simple production-facing UI path and a much larger not-clearly-wired experience model path
- This is a major Stage 3 cleanup target because docs can easily overstate what the home screen actually runs.

### 6. `消息 / companion chat` module

- Home entry: `spare-life-ios-app/Features/CompanionChat/ConversationHubView.swift`
- Store and domain-like models: `spare-life-ios-app/Features/CompanionChat/CompanionChatStore.swift`
- Additional advanced surfaces exist:
  - `ChatThreadView.swift`
  - `RelationshipGardenView.swift`
  - `GroupAgentPlayView.swift`
  - `CrossSessionMemoryView.swift`
  - `QuadRoleChatView.swift`
  - `ContactMaskView.swift`
- Important code reality:
  - the IM hub is currently mock-data driven
  - `ConversationHubStore` seeds threads in memory and does not yet represent a real persistence-backed message home
  - advanced message surfaces exist, but the app shell does not yet express a fully integrated navigation map for them

### 7. `我的 / profile` module

- Main page: `spare-life-ios-app/Features/MyProfile/MyProfileView.swift`
- Supporting metrics: `spare-life-ios-app/Features/MyProfile/MyProfileOverviewMetrics.swift`
- Supporting feature cards and detail screens:
  - `SyncScoreDashboardView.swift`
  - `AwakeningPersonalityView.swift`
  - `PrivacyLocalBackendView.swift`
  - `MemoryPalaceView.swift`
  - `GrowthStatsView.swift`
- Important code reality:
  - the root page still renders mostly mock profile data and mock card metrics
  - there is already a real `MyProfileXianrenStatsRepository` and a `MyProfileMasterStatsProvider`, with tests
  - those more realistic data providers are not yet the clear source of truth for the root profile page

### 8. Infrastructure and hidden support surfaces

- `spare-life-ios-app/Features/Infrastructure/` contains internal operator or diagnostic views:
  - `SQLiteBackendDashboardView.swift`
  - `OpenClawPluginView.swift`
  - `SecurityRiskControlView.swift`
  - `AIMemoryMatchingView.swift`
- These support capabilities are real repository concerns, but they are not currently expressed as a clearly governed internal-tools surface in the app information architecture.

### 9. Non-Swift support code inside the same repo

- `spare-life-ios-app/LocalBackend/` contains embedded-backend-oriented `.mjs` and SQL migration code.
- `spare-life-ios-app/Services/*.mjs` and `spare-life-ios-app/Domain/UseCases/*.mjs` define richer business flows for scene radar, masters, earn-social, unified UI, companion chat, and profile.
- `spare-life-openclaw-plugin/` is a separate plugin workspace with its own runtime, SDK, handlers, and gateway contract.
- Important code reality:
  - these files materially influence architecture and future direction
  - they are not compiled into the `SpareLifeCore` Swift package target
  - repo docs should stop implying that every `.mjs` flow is already part of the shipped iOS runtime path

## Code vs Docs Relationship

### 1. Global documentation state

- `Docs/sparelife_blueprint.md` is still useful as product-intent and information-architecture context, but it is broader and more speculative than the current code.
- `Docs/Stage2_Blueprint.md` is closer to implementation reality, but it has absorbed too much execution logging.
- `Docs/Stage2_Blueprint_0328_Checklist.md` mirrors the Stage 2 blueprint, which is acceptable, but both files now carry repeated validation entries that make them hard to use as clean design sources.
- Root `README.md` is accurate but too thin for a repo with three distinct layers: iOS runtime, local embedded backend/support code, and OpenClaw plugin workspace.

### 2. Naming drift

- The same module appears as `闲人`, `咸虾`, `闲虾`, and `xianxia`.
- The masters module appears as `大师` in old docs and `闲聊` in current tab UI.
- This is not a cosmetic issue only. It leaks into code comments, filenames, docs, and future API language.

### 3. Runtime truth drift

- Xianxia has a real repository and tests, so docs can legitimately describe a live-ish topic pipeline.
- Masters has a strong diagnostic and fallback path, but live integration remains gated by external configuration and backend availability.
- EarnSocial home is materially simpler than the large experience-store code suggests.
- Messages is mostly mock-state driven in the current home path.
- MyProfile root is still mock-heavy even though more realistic stats repositories already exist nearby.

### 4. Layering drift

- SwiftUI runtime code, `.mjs` support logic, plugin runtime, and validation docs all live in one repository.
- The repo does not yet expose one canonical architecture map that says:
  - what is shipped now
  - what is support code only
  - what is integration contract code
  - what is future-facing design scaffolding

### 5. Validation drift

- Current docs often mix:
  - requirement
  - implementation note
  - test coverage note
  - manual validation result
  - live probe result
  - repeated timestamped rerun logs
- This makes the docs hard to diff, hard to trust, and hard for automation workers to extend cleanly.

## Stage 3 Architecture Risks

### 1. False confidence from dual paths

- `EarnSocialHomeView.swift` and `EarnSocialExperienceStore.swift` can both make the module look “implemented”, even though only one is active.
- The same risk exists between Swift runtime paths and `.mjs` support logic.

### 2. Oversized stores and view files

- `MasterExperienceStore.swift` and `SceneTopicView.swift` each carry multiple concerns that should be separated for maintainability and test clarity.

### 3. Pagination semantics are under-specified in code

- Xianxia topic and shard pagination currently overwrite arrays during `loadMore()`.
- Any doc claiming robust infinite-scroll continuity must be treated as ahead of code until this is corrected.

### 4. Root-page data provenance is inconsistent

- Some root pages use real gateways.
- Some use local mocked state.
- Some have both, but the live provider is not the wired default.
- Stage 3 must make provenance explicit on every module boundary.

### 5. Documentation is hard to automate safely

- Because authoritative requirement text and execution history are mixed, future workers can easily modify the wrong layer of truth.

## Stage 3 Priorities

1. Establish a clean source-of-truth hierarchy for docs, naming, runtime paths, and validation evidence.
2. Partition the repo into clearer architecture boundaries: Swift runtime, support/backend scaffolding, plugin workspace, and docs.
3. Resolve dual-path modules by choosing one runtime path per surface or clearly labeling non-runtime code.
4. Reduce oversized files and stores where multiple concerns are currently fused.
5. Make each home page’s data provenance explicit: live, cached, mock, or diagnostic.
6. Expand tests and automation around the real runtime path, not just design scaffolding.
