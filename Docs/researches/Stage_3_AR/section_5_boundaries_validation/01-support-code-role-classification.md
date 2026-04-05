# S5-01 Support Code 角色分类

## 当前代码现状

1. 代码现状必须先以编译边界为准，而不是以目录名为准。`spare-life-ios-app/Package.swift` 明确把 `LocalBackend`、`Services`、`Domain/UseCases` 整个排除在 `SpareLifeCore` target 之外，只把 `App`、`Domain/Models`、`Features` 作为 Swift package 源码编入当前 iOS runtime。证据在 `spare-life-ios-app/Package.swift:15-39`。这意味着这些 `.mjs` 不是当前 iOS app binary 的原生运行时代码。
2. 但这些 `.mjs` 也绝不是纯文档占位。`spare-life-openclaw-plugin/src/handlers/*.mjs` 直接 import `spare-life-ios-app/Domain/UseCases/*.mjs` 与 `spare-life-ios-app/LocalBackend/**/*.mjs`，并在 handler 内实例化 repository/use case 形成可执行 Node runtime：
   - `sceneScanHandler` 直接拉起 `SceneExperienceUseCase` + `SceneFlowRepository`。证据在 `spare-life-openclaw-plugin/src/handlers/sceneScanHandler.mjs:1-39`。
   - `masterFlowHandler` 直接拉起 `MasterExperienceUseCase` + `MasterFlowRepository`。证据在 `spare-life-openclaw-plugin/src/handlers/masterFlowHandler.mjs:1-64`。
   - `earnSocialFlowHandler` 直接拉起 `EarnSocialExperienceUseCase` + `EarnSocialRepository`。证据在 `spare-life-openclaw-plugin/src/handlers/earnSocialFlowHandler.mjs:1-101`。
   - `companionChatHandler` 直接拉起 `CompanionChatExperienceUseCase` + `CompanionChatRepository`。证据在 `spare-life-openclaw-plugin/src/handlers/companionChatHandler.mjs:1-111`。
   - `myDashboardHandler` 直接拉起 `MyDashboardExperienceUseCase` + `MyDashboardRepository`。证据在 `spare-life-openclaw-plugin/src/handlers/myDashboardHandler.mjs:1-83`。
   - `unifiedChannelHandler` 直接拉起 `AIMemoryMatchingUseCase`、`SecurityRiskUseCase`、`FoundationRepository`、`LocalBackendDatabase`，并把 scene / masters / earn social / companion / my / unified_ui 全部路由到 plugin runtime。证据在 `spare-life-openclaw-plugin/src/handlers/unifiedChannelHandler.mjs:1-220`。
   - `unifiedUIHandler` 直接把 `UnifiedUIExperienceUseCase` 以及五个 feature repository/use case 组合成一条独立运行链。证据在 `spare-life-openclaw-plugin/src/handlers/unifiedUIHandler.mjs:1-85`。
3. 这批 `.mjs` 的真实角色因此不是“iOS runtime code”，而是“monorepo 内、由 OpenClaw plugin runtime 执行的 support code / contract code / future-lane scaffolding”。如果文档把它们写成“已经嵌入当前 iOS app 运行路径”，就和代码冲突；此处必须以代码为准。
4. README 目前存在明显语义漂移：
   - `spare-life-ios-app/README.md` 把 `Domain/UseCases`、`LocalBackend`、`Services` 写成 iOS client workspace 的自然组成部分，容易让读者误判这些目录和 `SpareLifeCore` 一样会随 app 编译进入运行时。证据在 `spare-life-ios-app/README.md:7-16`。
   - `spare-life-ios-app/LocalBackend/README.md` 更直接把 `LocalBackend` 写成 “embedded backend inside the iOS app”。证据在 `spare-life-ios-app/LocalBackend/README.md:1-10`。
   - 根 README 也把 `spare-life-ios-app/` 概括成 “iOS app workspace with a local SQLite-backed companion chat backend”。证据在 `README.md:12-15`。
5. 现状里没有任何 `.mjs` 被证明接入 Xcode target。当前工作树中对 `.pbxproj` 的检索没有发现 `LocalBackend/`、`Services/`、`Domain/UseCases/` 或 `.mjs` 资源挂载记录；再结合 `Package.swift` 的 `exclude`，代码层能支持的最稳结论就是：这些文件是 repo 内活代码，但不是当前 iOS binary 的 native runtime。
6. 逐文件 importer 收敛结果也说明，这批 `.mjs` 里没有“完全无人引用的死目录”：
   - scene / master / earn social / companion / my 五个 feature cluster 都被 plugin handler 直接消费。
   - `AIMemoryMatchingUseCase`、`SecurityRiskUseCase`、`FoundationRepository` 被 `unifiedChannelHandler` 直接消费。
   - `UnifiedUIExperienceUseCase` 与 `UnifiedUIRepository` 被 `unifiedUIHandler` 直接消费。
   - `Services/*` 大多只被上层 use case import，这说明它们是中间 support/service layer，而不是独立 runtime surface。

## 角色分类结论

先定义本条目的判定口径，避免“shipped”一词继续混淆：

1. 本文把“shipped support code”限定为“当前仓库内已经被真实 runtime path 执行的 support code”，这里的 runtime path 指 `spare-life-openclaw-plugin` 的 Node/plugin runtime，而不是当前 iOS app binary。
2. 本文把“contract code”限定为“负责路由、权限、schema、cross-feature 协调的边界代码”，它可以是活代码，但不等于当前 iOS UI 的已接线路径。
3. 本文把“future-lane scaffolding”限定为“已经可执行，但当前主要服务于未来路线或 demo/runtime synthesis，而不是当前 Swift app surface”。

| 范围 | 主要文件 | 当前真实 importer | 角色分类 | 结论 |
| --- | --- | --- | --- | --- |
| Scene flow | `LocalBackend/SQLite/sceneFlowRepository.mjs` + `Services/SceneRadar/*.mjs` + `Domain/UseCases/sceneExperienceUseCase.mjs` | `sceneScanHandler`，且也被 `unifiedUIHandler` 二次组合 | shipped support code | 这是 plugin runtime 的真实场景讨论/意图闭环，不是 Swift app binary 的 native runtime。 |
| Masters flow | `LocalBackend/SQLite/masterFlowRepository.mjs` + `Services/Masters/*.mjs` + `Domain/UseCases/masterExperienceUseCase.mjs` | `masterFlowHandler`，且也被 `unifiedUIHandler` 二次组合 | shipped support code | 这是 plugin runtime 的真实大师目录/会话闭环，不是当前 Swift `MasterExperienceStore.swift` 的直接后端。 |
| EarnSocial flow | `LocalBackend/SQLite/earnSocialRepository.mjs` + `Services/EarnSocial/a2aMarketService.mjs` + `Domain/UseCases/earnSocialExperienceUseCase.mjs` | `earnSocialFlowHandler`，且也被 `unifiedUIHandler` 二次组合 | shipped support code | 这是 A2A/Node 侧的可执行 support flow；当前 Swift 首页并没有直接接这套 `.mjs`。 |
| Companion flow | `LocalBackend/SQLite/companionChatRepository.mjs` + `LocalBackend/ConversationMemory/companionRecallService.mjs` + `Services/CompanionChat/companionChatService.mjs` + `Domain/UseCases/companionChatExperienceUseCase.mjs` | `companionChatHandler`，且也被 `unifiedUIHandler` 二次组合 | shipped support code | 这是 plugin runtime 的真实消息/群聊/记忆 support flow；不是当前 `ConversationHubView.swift` 的 app-native persistence path。 |
| My flow | `LocalBackend/SQLite/myDashboardRepository.mjs` + `Services/My/myDashboardService.mjs` + `Domain/UseCases/myDashboardExperienceUseCase.mjs` | `myDashboardHandler`，且也被 `unifiedUIHandler` 二次组合 | shipped support code | 这是 plugin runtime 的真实 profile/privacy/growth support flow；不是当前 Swift root profile page 的已接线 data source。 |
| Foundation / unified channel | `LocalBackend/SQLite/localBackendDatabase.mjs` + `LocalBackend/Repositories/foundationRepository.mjs` + `Services/LLMBridge/aiMemoryMatchingService.mjs` + `Services/EmotionEngine/securityRiskService.mjs` + `Domain/UseCases/aiMemoryMatchingUseCase.mjs` + `Domain/UseCases/securityRiskUseCase.mjs` | `unifiedChannelHandler` | contract code with active execution | 它们当前是活代码，但主要职责是 repo contract、route guard、memory recall、security audit，而不是某个 Swift 页面自己的 feature runtime。 |
| Unified UI synthesis | `LocalBackend/SQLite/unifiedUIRepository.mjs` + `Services/UnifiedUI/unifiedFeedService.mjs` + `Domain/UseCases/unifiedUIExperienceUseCase.mjs` | `unifiedUIHandler` 与 `unifiedChannelHandler` 的 `unified_ui` route | future-lane scaffolding with executable runtime | 这是“未来统一瀑布流/统一 UI contract”的可执行支架，不是当前 Swift `MainTabView` 的接线真相。 |

## 当前文档偏差

1. `spare-life-ios-app/README.md` 与 `LocalBackend/README.md` 的问题不在于“描述完全虚构”，而在于缺了运行表面限定语。它们没有说明这些目录今天主要由 plugin runtime 执行，而不是随 `SpareLifeCore` 编译进 app。证据分别在 `spare-life-ios-app/README.md:7-16` 与 `spare-life-ios-app/LocalBackend/README.md:1-10`。
2. 根 README 继续把本仓库压缩成 “iOS app + local SQLite backend” 双层视角，遗漏了第三层最关键的现实边界：`spare-life-openclaw-plugin/` 正在直接执行这些 `.mjs`。证据在 `README.md:12-15`。
3. `Stage_3_Codebase_Audit.md` 在这个问题上已经比 README 更接近事实。它明确写了这些 `.mjs` 会影响架构边界，但没有进入 `SpareLifeCore` target。证据在 `Docs/Stage_3_Codebase_Audit.md:121-128`。所以本条研究不是推翻审计，而是把“目录存在”进一步收敛成“逐簇角色分类”。

## 稳定 SOTA / 成熟实践

1. 多 runtime 单仓库的成熟做法，不是强行把所有代码都叫“app runtime”，而是先把每份代码放回真实执行表面：
   - app-native runtime
   - plugin/server runtime
   - contract plane
   - future-lane scaffold
2. support code 是否“活着”，应由 importer 和构建入口共同决定，而不是由目录名或 README 决定。当前仓库里最关键的证据就是：
   - `Package.swift` 决定它们不进 Swift app target。
   - plugin handlers 决定它们确实会在 Node/plugin runtime 中执行。
3. contract code 与 feature runtime code 最好分层命名。当前仓库里 `aiMemoryMatching`、`securityRisk`、`unifiedChannel` 其实是边界治理层，不应该再被写成“只是服务文件”或“未来再说”的模糊资产。
4. future-lane scaffold 可以保留，但必须显式标注“已可执行”与“尚未接入主 UI”两个状态。这样既能保住迭代积累，又能避免误把 demo/候选实现当成现网真相。

## 面向本仓库的具体建议

1. 立即采用双轴标签，而不是单一“是否存在于 app repo”标签：
   - `app-native`: 进入 `SpareLifeCore` 或 Xcode app target 的 Swift runtime。
   - `plugin-executed support`: 被 `spare-life-openclaw-plugin/src/handlers/*.mjs` 直接执行的 `.mjs`。
   - `contract-active`: 被 `unifiedChannelHandler`、schema、guard、memory/audit 路由执行的边界代码。
   - `future-lane executable`: 可以运行，但未接入 Swift 主 UI 的实验/候选路径。
2. 对 S5-01 覆盖的 `.mjs`，当前建议的仓库级官方分类如下：
   - scene / masters / earn social / companion / my 五簇：`plugin-executed support`
   - foundation / ai-memory / security：`contract-active`
   - unified UI：`future-lane executable`
3. 文档口径要立即统一成一句真话：
   - 这些 `.mjs` 是当前仓库里的活代码。
   - 它们主要服务于 OpenClaw plugin runtime 与验证闭环。
   - 它们不是当前 iOS app binary 的 native runtime。
4. 后续若要继续扩 `.mjs`，每新增一个目录都应附带一行 owner/role 声明，至少写清：
   - importer 是谁
   - 目标 runtime 是 app、plugin 还是 contract
   - 是否允许主 UI 直接依赖
5. `UnifiedUI*` 这条线在未接入 Swift 主壳层前，不应再被写成“shared UI infrastructure”，而应写成“future-lane executable scaffold”。当前 importer 已经证明它可执行，但当前 Swift 首页并不消费它。

## 实施顺序

1. 先冻结词汇：以后所有 Stage 3 文档都不再把这批 `.mjs` 统称为 “iOS app runtime”。
2. 再在仓库文档层统一四类标签：`app-native / plugin-executed support / contract-active / future-lane executable`。
3. 然后分别处理三类收敛：
   - README 纠偏，把 `LocalBackend` 从“embedded in iOS app”改成“repo-local backend code executed by plugin/support runtimes”。
   - contract 层抽明边界，让 `ai_memory / security / unified_channel` 不再被埋在 feature 目录语义里。
   - unified UI 路线单独标“未接主 UI”。
4. 只有在某个 `.mjs` 真正被 Swift runtime 接线或被新的 app-host process 消费时，才允许把它从 `plugin-executed support` 或 `future-lane executable` 升级成 `app-native`。

## 风险

1. 如果继续把这些 `.mjs` 写成“iOS app embedded backend”，团队会持续高估当前 app binary 的真实能力，导致 validation 和重构都做在错误前提上。
2. 如果反过来把它们全当成“未来代码”或“死代码”，会直接误删当前 plugin runtime 的真实依赖链，尤其是 five-feature handlers 与 `unifiedChannelHandler`。
3. 如果不把 `foundation / ai-memory / security` 单独标成 contract 层，后续很容易把权限审计、记忆召回、channel envelope 继续塞回 feature 目录，边界会再次变糊。
4. 如果不明确 `UnifiedUI*` 只是 future lane，后续 Section 2 和 Section 5 都会在一个并未接入 Swift shell 的实现上持续返工。

代码和旧文档冲突时，本条研究结论以代码为准。
