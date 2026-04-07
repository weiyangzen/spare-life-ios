# Stage 3 AR Blueprint

## 1. Purpose

This file is the single authoritative Stage 3 architecture refinement blueprint for `spare-life-ios`.

Stage 3 is not a feature checklist.
Stage 3 is the repo-wide architecture cleanup lane that reconciles current runtime code, docs, support code, and validation workflow.

If any older doc conflicts with runtime code, runtime code wins.

Layout note as of `2026-04-06`:

- historical `spare-life-ios-app/**` now lives under `ios/spare-life-ios-app/**`
- historical `spare-life-ios-preview-host/**` now lives under `ios/spare-life-ios-preview-host/**`
- historical `spare-life-openclaw-plugin/**` now lives under `ios/spare-life-openclaw-plugin/**`
- historical `assets/**` now lives under `ios/assets/**`

## 2. Design Philosophy

`以代码现状为唯一运行真相，优先做边界清晰、文档可验证、状态可追踪、能持续收敛返工的 iOS 架构优化。`

## 3. Interpretation Order

Use this order when evaluating any Stage 3 item:

1. `ios/spare-life-ios-app/App`, `ios/spare-life-ios-app/Features`, and `ios/spare-life-ios-app/Tests`
2. `ios/spare-life-ios-app/LocalBackend`, `ios/spare-life-ios-app/Services`, `ios/spare-life-ios-app/Domain/UseCases`, and `ios/spare-life-openclaw-plugin` where they affect actual repo boundaries
3. `Docs/Stage_3_Codebase_Audit.md`
4. Existing Stage 1 / Stage 2 docs
5. This blueprint

## 4. Completion Gate

An item may be checked from `[ ]` to `[x]` only when all of the following are true:

- the corresponding research doc exists at the exact path written in the item
- the doc is non-empty
- the doc stays inside that one item boundary
- the doc explains current code reality first, then doc drift, then stable SOTA or mature frontier practice, then repo-specific recommendations
- the doc translates the recommendation back into concrete next-step guidance for this repository
- if code and docs disagree, the doc explicitly says code wins

## 5. Worker Ownership

- Slot 1 owns Section 1 only
- Slot 2 owns Section 2 only
- Slot 3 owns Section 3 only
- Slot 4 owns Section 4 only
- Slot 5 owns Section 5 only

Workers may update only:

- their owned section in this blueprint
- their owned output directory under `Docs/researches/Stage_3_AR/`

## 6. Research Output Root

- `Docs/researches/Stage_3_AR/section_1_truth/`
- `Docs/researches/Stage_3_AR/section_2_shell_ui/`
- `Docs/researches/Stage_3_AR/section_3_xianxia_masters/`
- `Docs/researches/Stage_3_AR/section_4_social_messages_profile/`
- `Docs/researches/Stage_3_AR/section_5_boundaries_validation/`

## 7. Checklist

### Section 1. Source Of Truth And Documentation Governance
<!-- STAGE3_SECTION: slot1:start -->
- [x] S1-01 建立产品名、UI 名、代码名、接口名四层统一词典，消除 `闲人 / 咸虾 / 闲虾 / xianxia` 与 `大师 / 闲聊 / masters` 的命名漂移 -> Docs/researches/Stage_3_AR/section_1_truth/01-canonical-module-lexicon.md
- [x] S1-02 重构文档分层规则，明确 `产品蓝图 / 实施蓝图 / 验证镜像 / 运行日志 / 研究报告` 各自的职责，不再把它们混写到同一权威文档里 -> Docs/researches/Stage_3_AR/section_1_truth/02-document-stratification.md
- [x] S1-03 设计统一的代码到文档追踪格式，约束文件头注释、蓝图条目、验证记录与研究报告之间的引用方式 -> Docs/researches/Stage_3_AR/section_1_truth/03-code-to-doc-traceability.md
- [x] S1-04 输出仓库级运行真相地图，明确 `Swift runtime / support .mjs / local backend / plugin workspace / docs-only` 五类资产边界 -> Docs/researches/Stage_3_AR/section_1_truth/04-runtime-truth-map.md
- [x] S1-05 统一配置来源登记方式，梳理 `env / UserDefaults / keychain / local assets / docs assumptions` 的优先级与暴露规则 -> Docs/researches/Stage_3_AR/section_1_truth/05-configuration-source-registry.md
- [x] S1-06 重构 Stage 级验证证据格式，把“需求陈述”和“时间戳运行日志”彻底分离，避免 Stage 文档继续膨胀成操作日志仓库 -> Docs/researches/Stage_3_AR/section_1_truth/06-validation-evidence-format.md
<!-- STAGE3_SECTION: slot1:end -->

### Section 2. App Shell And Shared UI Architecture
<!-- STAGE3_SECTION: slot2:start -->
- [x] S2-01 统一根应用壳层命名和模块元数据，收敛 `MainTab`, tab labels, router target, analytics key, deep-link key 的一致性策略 -> Docs/researches/Stage_3_AR/section_2_shell_ui/01-app-shell-metadata.md
- [x] S2-02 梳理 `TabView / NavigationStack / fullScreenCover / router` 的页面呈现契约，给出根路由和跨 tab 进入详情页的统一规范 -> Docs/researches/Stage_3_AR/section_2_shell_ui/02-navigation-presentation-contract.md
- [x] S2-03 抽象首页通用 page chrome，统一标题、搜索、筛选、顶部轻模块与刷新行为，减少各页重复实现 -> Docs/researches/Stage_3_AR/section_2_shell_ui/03-shared-page-chrome.md
- [x] S2-04 定义 feed/list 状态恢复标准，覆盖滚动位置、筛选条件、分页状态、空态和错误态，不再让各模块自己拼接 -> Docs/researches/Stage_3_AR/section_2_shell_ui/04-feed-state-restoration.md
- [x] S2-05 审计并收敛 `DesignTokens`, spacing, typography, color, platform compat 的边界，明确哪些是设计系统，哪些只是页面内常量 -> Docs/researches/Stage_3_AR/section_2_shell_ui/05-design-system-boundary.md
- [x] S2-06 重新定义 Infrastructure 诊断页在信息架构中的位置，决定它们应当是内部工具入口、开发预览能力，还是独立运营面板 -> Docs/researches/Stage_3_AR/section_2_shell_ui/06-internal-tools-surface.md
<!-- STAGE3_SECTION: slot2:end -->

### Section 3. Xianxia And Masters Runtime Cleanup
<!-- STAGE3_SECTION: slot3:start -->
- [x] S3-01 把 `SceneTopicView.swift` 中混装的 view, model, config, repository, cache parsing 重新拆边界，产出更稳的 `Xianxia` 模块结构建议 -> Docs/researches/Stage_3_AR/section_3_xianxia_masters/01-xianxia-module-split.md
- [x] S3-02 梳理 `XianxiaTopicRepository` 的网关契约、环境配置、缓存策略和失败降级路径，给出清晰的 repository contract 方案 -> Docs/researches/Stage_3_AR/section_3_xianxia_masters/02-xianxia-gateway-contract.md
- [x] S3-03 专门审计 topic/shard 分页语义，解释当前 `loadMore()` 覆盖数组而非追加的实现风险，并给出一致的 infinite-scroll 方案 -> Docs/researches/Stage_3_AR/section_3_xianxia_masters/03-pagination-append-semantics.md
- [x] S3-04 拆解 `MasterExperienceStore.swift` 的职责，把目录资产、会话状态、诊断、远端对话、回退逻辑、持久化边界分层 -> Docs/researches/Stage_3_AR/section_3_xianxia_masters/04-master-store-decomposition.md
- [x] S3-05 收敛大师实时对话路径，统一 `catalog probe / live candidate / live connected / local fallback / roleplay rewrite` 的状态机和证据格式 -> Docs/researches/Stage_3_AR/section_3_xianxia_masters/05-master-live-chat-state-machine.md
- [x] S3-06 重构 ASR readiness 契约，明确 `endpoint config / auth config / preview-host capability / smoke validation / blocker reporting` 的边界和归属 -> Docs/researches/Stage_3_AR/section_3_xianxia_masters/06-master-asr-readiness.md
<!-- STAGE3_SECTION: slot3:end -->

### Section 4. EarnSocial, Messages, And Profile Consistency
<!-- STAGE3_SECTION: slot4:start -->
- [x] S4-01 决定 `EarnSocialHomeView.swift` 与 `EarnSocialExperienceStore.swift` 的单一运行真相，消除当前“简单主路径 + 大型未接线状态模型”并存的问题 -> Docs/researches/Stage_3_AR/section_4_social_messages_profile/01-earn-social-single-runtime-path.md
- [x] S4-02 设计 EarnSocial fixture 与 assets 策略，把当前 in-file mock fixtures 外提成可治理的数据源层，而不是把内容写死在页面文件里 -> Docs/researches/Stage_3_AR/section_4_social_messages_profile/02-earn-social-fixture-governance.md
- [x] S4-03 梳理消息模块的真实领域边界，区分 `IM hub`, `thread`, `mask`, `relationship`, `memory`, `group play`，避免继续用一个 UI 文件承载半个 domain -> Docs/researches/Stage_3_AR/section_4_social_messages_profile/03-messages-domain-boundary.md
- [x] S4-04 研究消息模块的导航整合方案，让现有高级子页不再只是分散组件，而是有可验证的入口、状态和返回路径 -> Docs/researches/Stage_3_AR/section_4_social_messages_profile/04-messages-surface-integration.md
- [x] S4-05 把 `MyProfileView.swift` 的 mock root data 与 `MyProfileOverviewMetrics.swift` 的 live-ish stats provider 对齐，明确 root profile 的数据来源层级 -> Docs/researches/Stage_3_AR/section_4_social_messages_profile/05-my-profile-data-provenance.md
- [x] S4-06 定义跨 tab handoff 契约，统一 `xianxia -> earn social`, `masters -> messages/profile`, `earn social -> messages` 的 route 和 state payload 规则 -> Docs/researches/Stage_3_AR/section_4_social_messages_profile/06-cross-tab-handoff-contract.md
- [x] S4-07 冻结 OpenClaw IM 的 canonical locator、card identity、capability parity 与 compatibility fallback contract，避免 `messages home / thread open / cross-tab handoff` 再继续各说各话 -> Docs/researches/Stage_3_AR/section_4_social_messages_profile/07-openclaw-im-identity-and-parity.md
- Wave 4 backfill: `MessagesRoute`、legacy route normalizer、canonical locator、OpenClaw IM envelope 的当前 acceptance 已由 `Docs/Stage3_Wave4_Smoke.md` 与 `Docs/Stage3_Apple_Parity_Checklists.md` 承接；这些文档是执行与验收镜像，不替代本 Section 的研究结论。
<!-- STAGE3_SECTION: slot4:end -->

### Section 5. Repo Boundaries, Validation, And Automation
<!-- STAGE3_SECTION: slot5:start -->
- [x] S5-01 输出 `LocalBackend`, `Services/*.mjs`, `Domain/UseCases/*.mjs` 的角色分类，明确哪些是 shipped support code，哪些是 prototype, contract, or future-lane scaffolding -> Docs/researches/Stage_3_AR/section_5_boundaries_validation/01-support-code-role-classification.md
- [x] S5-02 对齐 iOS app 与 `spare-life-openclaw-plugin` 的契约边界，明确 topic gateway、SDK、payload schema、demo code、plugin runtime 的同步策略 -> Docs/researches/Stage_3_AR/section_5_boundaries_validation/02-plugin-app-contract-sync.md
- [x] S5-03 研究 `SpareLifeCore` package boundary，明确哪些 Swift files 应进入 package、哪些应留在 app-only 或 preview-host-only 层 -> Docs/researches/Stage_3_AR/section_5_boundaries_validation/03-package-boundary-audit.md
- [x] S5-04 建立统一验证矩阵，覆盖 `swift test`, app shell smoke, preview host UI test, plugin smoke, gateway smoke, and docs evidence generation -> Docs/researches/Stage_3_AR/section_5_boundaries_validation/04-validation-matrix.md
- [x] S5-05 定义全仓 fixture 和 seed 数据治理规范，避免测试、页面 mock、服务 demo、plugin fixture 各自维护一套不一致世界观 -> Docs/researches/Stage_3_AR/section_5_boundaries_validation/05-fixture-seed-governance.md
- [x] S5-06 为 Stage 3 自动化本身建立运行规约，明确 automation clone, worker ownership, guard merge, cron cleanup, and operator handoff 的长期治理方式 -> Docs/researches/Stage_3_AR/section_5_boundaries_validation/06-automation-governance.md
<!-- STAGE3_SECTION: slot5:end -->
