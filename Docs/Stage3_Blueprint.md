# Stage 3 Blueprint

## 1. 说明

本文件是 `Stage 3` 的唯一实施蓝图。

它不是研究报告摘要，也不是完成回顾，而是一份面向实际落地的 checklist 蓝图。  
所有 Stage 3 代码、目录、路由、平台镜像、OpenClaw IM 对齐、联调与验证工作，都以本文件为唯一执行清单。

它建立在以下材料之上：

1. `Docs/Stage_3_AR_Integrated_Report.md`
2. `Docs/researches/Stage_3_AR/`
3. 当前仓库实际代码与目录结构

## 2. 当前基线

- 历史 `spare-life-ios-app/**`、`spare-life-ios-preview-host/**`、`spare-life-openclaw-plugin/**`、`assets/**` 已在 `2026-04-06` 收口到 `ios/`。
- `OpenClaw` 的 npm `latest` 在 `2026-04-06` 已确认是 `openclaw@2026.4.2`。
- 同级联调路径 `../spare-life-server` 已建立，但当前上游仓库 clone 后为空仓。

## 3. Stage 3 目标

Stage 3 的目标不是“继续加功能”，而是完成以下 5 条主线：

1. 把仓库结构从单平台堆叠形态收口成清晰的平台车道。
2. 把 iOS 现有 runtime 的路由、状态、消息、OpenClaw IM 契约做成稳定主路径。
3. 把 `messages` 页从 mock-heavy surface 推进到 typed route + canonical identity 的可接线形态。
4. 让 `macOS app` 以 `iOS / iPad 横屏` 为 UIUX 基底，一步到位完成一比一复刻与 desktop optimization。
5. 把联调、验证、文档同步从“局部成功”推进到“可重复验证”。

## 4. 设计原则

`以代码现状为唯一运行真相，优先收口目录、主键、路由、字段归一、平台镜像与验证矩阵，避免继续把 support code、字符串 contract 和 mock surface 误写成已接线 runtime。`

## 5. 勾选规则

只有同时满足以下条件，条目才能从 `[ ]` 改成 `[x]`：

- 代码或目录结构已经真实落地
- 相关 README、路径说明、文档映射已同步
- 若涉及 route / locator / OpenClaw IM，主键、fallback 和错误面已经冻结
- 若涉及平台镜像，目标平台页面可实际打开，不只是目录占位
- 若涉及验证，至少有一条可重复执行的本地验证链路

## 6. Stage 3 执行清单

### 6.1 已完成前置骨架

- [x] S3-001 Apple 客户端相关内容已从仓库根收口到 `ios/`。
- [x] S3-002 `android/` 占位目录已创建。
- [x] S3-003 `app/windows11`、`app/macos`、`app/ubuntu` 占位目录已创建。
- [x] S3-004 `../spare-life-server` 同级联调路径已建立。
- [x] S3-005 `ios/assets` 新路径已被 `MasterExperienceStore` 与对应测试承接。
- [x] S3-006 `openclaw` plugin peer dependency 已提升到 `>=2026.4.2`。

### 6.2 仓库结构与平台车道收口

- [x] S3-010 把根层 repo invariant 明确冻结为：`Docs/`、`.gitignore`、`README.md`、自动化目录、平台车道目录。
- [x] S3-011 全仓 README、子 README、路径说明统一改用 `ios/...` 新路径，不再继续写旧根路径。
- [x] S3-012 梳理哪些内容应该长期留在 `ios/`，哪些未来应该迁到 `app/macos` 或其它平台车道，避免后续继续混放。
- [x] S3-013 为 `ios/`、`android/`、`app/` 建立稳定的职责边界说明，防止未来新增文件再次落到仓库根。
- [x] S3-014 为 `../spare-life-server` 的空仓状态补一个联调约束说明，明确当前“路径已预留、服务代码未到位”的真实状态。

### 6.3 iOS 现有主路径收口

- [x] S3-020 把 `messages` 页从当前局部 `NavigationStack` + 根层 `fullScreenCover` 双宿主，收口为单一 feature root。
- [x] S3-021 把 `ConversationRouter` 从“消息线程 modal 状态”升级成 typed route / handoff coordinator。
- [x] S3-022 冻结 `MessagesRoute`，至少覆盖 `home / thread / mask / relationship / memory / quadRole / groupPlay / groupVote / composeDraft`。
- [ ] S3-023 把 `ChatThreadView` 当前本地 `showContactMask / showRelationship / showQuadRole / showGroupPlay / showCrossSessionMemory` 迁移成 typed navigation action。
- [ ] S3-024 按 `S4-03` 边界，把 `CompanionChatStore.swift` 最少拆成 `hub / thread / mask / relationship / memory / group play / shared`。
- [ ] S3-025 让 `EarnSocialHomeView` 与 `EarnSocialExperienceStore` 收口成单一 runtime truth，不再继续双路径并存。
- [ ] S3-026 让 `MyProfile` 根页明确区分 live-ish 聚合值、seeded fallback、未接线指标与 route target。
- [ ] S3-027 修正 `Xianxia` topic/shard `loadMore()` 追加语义，停止覆盖已有数组。
- [ ] S3-028 对当前 `masters -> messages/profile`、`earn social -> messages`、`xianxia -> earn social` 的字符串 route 生产端做统一归口。

### 6.4 OpenClaw IM 对齐与消息卡片唯一标识

- [x] S3-030 为消息卡片定义 canonical `IMCardID`：优先 `conversation_id`，缺失时 fallback 到 `channel_id + group_id` 或 `channel_id + dm_peer_id`。
- [x] S3-031 冻结 `IMConversationLocator`：`conversation(conversationID)` / `group(channelID, groupID)` / `dm(channelID, peerID)`。
- [x] S3-032 为首页卡片、中间态 handoff、详情页打开动作统一一层 `IMCardEnvelope`。
- [x] S3-033 为 group 与 dm 统一 `IMRenderFields` 字段袋，让两者真正走同字段、同渲染、不同 capability 的模式。
- [ ] S3-034 把 OpenClaw 最新能力面完整映射成 Stage 3 capability checklist，而不是只停留在 handler 已存在。
- [x] S3-035 为 `messages home` 建立规范化输入输出模型，明确卡片 title、subtitle、preview、badge、locator、capability 的来源。
- [x] S3-036 为 `conversation open` 建立规范化输入输出模型，明确 timeline、participant、message、stage、group 上下文的最小字段；当前已落地 `conversation_open_input/output`、`conversation_summary`、`conversation_timeline`、`conversation_stage_context`、`conversation_group_context`，并在 plugin response 中保留 raw fields 兼容层。
- [x] S3-037 为 `conversation search` 定义 query、result item、定位主键与空结果语义；当前已落地 `conversation_search_input/output`、`conversation_search_query`、`conversation_search_result_item`、`conversation_search_empty_state`，并固定 `locationPrimaryKey(message_id + turnIndex)` 与 thread handoff hint。
- [ ] S3-038 为 `direct message` 定义 direct-only capability gate，禁止 group surface 误入。
- [ ] S3-039 为 `group conversation` 定义 group-only capability gate，禁止 direct surface 误入。
- [ ] S3-040 为 `group vote launch / ballot / summary` 建 group-only UI 与 route gate，不再只靠 view 内临时 if 判断。
- [ ] S3-041 为 `mask update`、`shared stage draft / access / message`、`ritual schedule / complete` 明确其卡片入口、线程入口与错误回退面。
- [ ] S3-042 为 `companion inspect` 定义它在 client 侧的承接位置：诊断入口、内部工具入口或线程附属面，不再悬空。
- [ ] S3-043 为所有 OpenClaw IM action 明确 required ID、fallback ID、可选 hint、错误分类、UI 不可用文案。
- [ ] S3-044 区分 `unsupported`、`not_ready`、`invalid_locator`、`temporarily_unavailable`、`permission_denied` 五类错误面，不再继续压成一个统一空态。

### 6.5 macOS UIUX 复刻与 Desktop Optimization 主线

- [x] S3-050 明确 Stage 3 的 `macOS app` 目标是：以 `iOS / iPad 横屏` 为 UIUX 基底，一步到位完成视觉复刻、信息架构复刻和桌面交互优化；`app/macos` 已通过 `Stage3MacOSTargetContract` 冻结基底、复刻范围与 desktop shell 边界。
- [x] S3-051 建立真正的 `macOS app` 宿主，而不是只保留 `app/macos` 占位目录；当前已落地 `stage3-macos-app` 可执行宿主，并由 `Stage3MacOSSharedRootView` 实际承接窗口根视图。
- [x] S3-052 复用现有 SwiftUI 共享层，让 `MainTabView`、shared design system、shared feed / card 组件优先直接跑在 macOS；当前 `Stage3MacOSRuntime` 直接编译 `ios/spare-life-ios-app` 的共享 `App / Features / Domain/Models` 源，并由宿主侧 wrapper 承接包边界。
- [x] S3-053 让 `xianxia / masters / earnSocial / messages / myProfile` 五个主页面在 macOS 上全部可打开，并保持与 iOS / iPad 横屏一致的模块顺序、页面 chrome、卡片语言和主内容结构；当前已通过 `stage3-macos-surface-smoke` 真实构造 `Stage3MacOSDesktopShellView` root 与五个主页面的 macOS hosting surface 并验证顺序一致。
- [x] S3-054 为 macOS 建立桌面壳层：允许用 sidebar / top toolbar / segmented control 等桌面容器替代底部栏，但模块信息架构、进入路径与功能语义必须与 iOS 一致；当前 `app/macos` 已由 `Stage3MacOSDesktopShellView` 承接 root，使用 `sidebar + top toolbar + segmented control` 承接五大模块，并通过 `desktopShellSnapshot()` 固定 root -> tab 的进入路径与模块顺序。
- [ ] S3-055 让 `xianxia` 在 macOS 上升级为桌面友好的 list-detail / multi-column 结构，同时保持 iOS 页面内容、筛选逻辑与详情信息密度一致。
- [ ] S3-056 让 `messages` 在 macOS 上升级为桌面友好的 hub-thread-detail 工作区，可利用更宽屏幕做多栏承接，但消息卡片、线程语义、子页入口与 iOS 一致。
- [ ] S3-057 让 `masters` 在 macOS 上升级为桌面友好的目录-会话工作区，至少支持更稳定的卡片浏览区、会话区、辅助信息区并存。
- [ ] S3-058 让 `earnSocial`、`myProfile`、`Infrastructure` 相关页面在 macOS 上完成更高信息密度编排，而不是简单居中放大 iOS 单列页面。
- [ ] S3-059 让 `ios/assets` 的资源读取链路在 macOS 宿主可复用，至少覆盖大师目录、图片、基础本地 seed 与诊断页依赖资源。
- [ ] S3-060 让 `OpenClawPluginView`、`SQLiteBackendDashboardView` 等基础诊断页在 macOS 上可打开，并利用桌面空间做更适合联调的面板化布局。
- [ ] S3-061 为 macOS 增加桌面级交互：hover 状态、secondary click / context menu、键盘快捷键、command 菜单入口。
- [ ] S3-062 为 macOS 增加窗口级优化：窗口最小尺寸、默认尺寸、可调列宽、状态恢复、上次工作区恢复。
- [ ] S3-063 为 macOS 增加桌面级工具栏与搜索入口，让全局搜索、筛选、刷新、诊断入口不再完全复刻移动端按钮摆放。
- [ ] S3-064 为 macOS 增加桌面级多栏 / inspector / side panel 承接规则，优先把详情、上下文、诊断信息从 modal 改成更适合桌面的并排工作区。
- [ ] S3-065 保持 macOS 与 iOS 的视觉语言同源：色板、卡片、文案、模块边界、状态语义一致；但允许在密度、布局、快捷交互、窗口组织上做桌面优化。
- [ ] S3-066 不允许把 `macOS` 做成另一套产品：桌面优化必须建立在同一 IA、同一功能路径、同一数据与 route 契约之上。

### 6.6 macOS 与 iOS 的共享代码策略

- [x] S3-070 明确哪些 Swift 文件是 iOS/macOS 直接共享，哪些只在 desktop shell、desktop container、desktop interaction 层做分支；当前以 `Docs/Stage3_macOS_Shared_Surface_Policy.md` 与 `ios/spare-life-ios-app/App/DesignSystem/PlatformSurfacePolicy.swift` 冻结共享/分支矩阵。
- [ ] S3-071 为 `DesignTokens`、`PlatformCompat`、`WaterfallLayout`、shared feed 组件建立跨 iOS/macOS 的最小兼容检查。
- [ ] S3-072 梳理哪些页面当前隐含依赖 UIKit / iOS-only API，列出 macOS UIUX 复刻与 desktop optimization 的 blockers。
- [x] S3-073 若存在必须分支的页面，优先把差异收口在壳层、容器层、交互层，不允许在 feature 业务层到处散落 `#if os(...)`；共享 feed/design system 已移除无必要平台 import，并把条件编译约束收口到 compat 与显式分层规则。
- [x] S3-074 为 macOS 建立“共享内容与状态、分支容器与交互”的实现原则，避免刚开始就复制出第二套页面树；`app/macos` 与桌面车道 README 已同步为“共享内容/状态、分支壳层/容器/交互”的执行规则。
- [ ] S3-075 对需要 desktop optimization 的页面，优先抽象成共享 view model + 平台专属 layout shell，而不是复制业务逻辑。

### 6.7 路由、handoff 与跨端一致性

- [ ] S3-080 把 `messages` 内部 route、跨 tab handoff、OpenClaw IM locator 对齐成同一套主键体系。
- [x] S3-081 冻结 `CrossTabHandoff` 的 canonical payload，不再继续扩散 ad-hoc URI。
- [x] S3-082 为 `messages/self?draft=...`、`thread?lane=...&counterpart=...`、`thread?bond_id=...&icebreak_session_id=...` 建立 legacy normalizer，并把 `messages/self` 收口到 canonical `compose_draft` handoff，把两类 `thread` 历史入口统一降级为 `messages home + pendingThread` 兼容层。
- [ ] S3-083 让 `masters -> messages`、`masters -> profile`、`earn social -> messages` 在 iOS 与 macOS 上共享同一 handoff 解释逻辑。
- [ ] S3-084 当目标 surface 尚未 ready 时，为 iOS 和 macOS 同时提供 pending handoff，而不是直接丢 payload。

### 6.8 验证、联调与验收

- [x] S3-090 为 `ios/` 新结构补完整路径敏感验证，至少覆盖 README、assets、preview-host、plugin import、Swift tests；当前已落地 `Docs/Stage3IOSPathValidation`、`Docs/scripts/validate_ios_paths.sh`、`Docs/Stage3_iOS_Path_Validation.md`，并把 README / lane README / preview-host smoke / plugin self-import / path-validation Swift tests 收口到同一条可重复执行的本地验证链路。
- [ ] S3-091 为 `OpenClaw IM` lane 建最小 smoke：messages home、DM open/send、group open/send、vote、summary、inspect。
- [ ] S3-092 为 `messages` typed route 建最小 smoke：hub -> thread -> relationship / memory / groupPlay / quadRole。
- [ ] S3-093 为 macOS UIUX parity + desktop optimization 建最小 smoke：五大主页面可打开、主路径详情可进入、主导航可返回、窗口可 resize、多栏布局可稳定工作。
- [ ] S3-094 为 iOS 和 macOS 共同建立页面 parity checklist，避免“名称相同但页面内容已分叉”；同时单独建立 desktop optimization checklist，避免“只是放大 iOS 页面”。
- [ ] S3-095 为 plugin demo、client-only local seed、未来 server-backed joint debug 建三档验证矩阵。
- [ ] S3-096 当 `../spare-life-server` 有真实内容后，建立 client / plugin / server 三方 contract 验证，覆盖 locator、render fields、error surface、fallback。

### 6.9 文档同步与收尾

- [ ] S3-100 当 `Stage3_Blueprint` 中的 route / locator / macOS parity contract 落地后，同步回写 `Docs/Stage_3_AR_Blueprint.md` 的相关条目。
- [ ] S3-101 把本轮新增的 OpenClaw IM identity、macOS parity、macOS desktop optimization、平台车道边界补进后续验证日志模板，避免未来执行记录再次失真。
- [ ] S3-102 当 iOS 与 macOS 的 UIUX parity 和 desktop optimization 都达到可验收状态后，再讨论下一轮更激进的 OS-native 扩展，而不是把本阶段目标继续往后拖。

## 7. 推荐施工顺序

### 7.1 Wave 0：先冻结不会再反复变的 contract

这一波是全部后续工作的共同前置。如果这一层不先冻结，4 并发会很快互相冲突。

- [ ] W0-01 先完成 `S3-010` 到 `S3-014`，把仓库边界、平台车道、空 server 状态和 README 路径统一。
- [ ] W0-02 先完成 `S3-030`、`S3-031`、`S3-081`、`S3-082`，冻结 `IMCardID`、`IMConversationLocator`、`CrossTabHandoff` 和 legacy normalizer 方向。
- [ ] W0-03 先完成 `S3-050`、`S3-070`、`S3-073`、`S3-074`，冻结 macOS 的总体路线和“共享内容、分支容器”的实现原则。

### 7.2 Wave 1：4 并发同时启动的第一轮

这一轮目标是把最容易互相阻塞的 4 个主干同时搭起来，但写入范围要分开。

- [ ] W1-01 并发 A：完成 `S3-020`、`S3-021`、`S3-022`，先把 iOS 消息根路由壳层搭好。
- [ ] W1-02 并发 B：完成 `S3-032`、`S3-033`、`S3-035`、`S3-036`、`S3-037`，把 OpenClaw IM 的统一 envelope 和输入输出模型先写实。
- [ ] W1-03 并发 C：完成 `S3-051`、`S3-052`、`S3-053`、`S3-054`，先把 macOS 宿主、共享层接线和 5 个页面骨架跑起来。
- [ ] W1-04 并发 D：完成 `S3-090` 的路径敏感验证基线，并为后续 iOS/macOS/OpenClaw 三条线准备 smoke 脚手架。

### 7.3 Wave 2：进入真正的 feature 收口

这一轮在 Wave 1 已有壳层、locator、宿主之后推进，仍然保持 4 并发，但避免写同一组文件。

- [ ] W2-01 并发 A：完成 `S3-023`、`S3-024`、`S3-080`，把 `messages` 页从本地 bool + 大 store 形态推进到 typed route + 边界拆分。
- [ ] W2-02 并发 B：完成 `S3-034`、`S3-038`、`S3-039`、`S3-040`、`S3-043`、`S3-044`，把 OpenClaw IM capability gate 和错误面补齐。
- [ ] W2-03 并发 C：完成 `S3-055`、`S3-056`、`S3-057`、`S3-058`、`S3-060`，让 macOS 的 `xianxia / messages / masters / earnSocial / myProfile` 进入真正的桌面 UIUX 优化阶段。
- [ ] W2-04 并发 D：完成 `S3-071`、`S3-072`、`S3-075`，持续清理 iOS/macOS 共享层的兼容与 blocker。

### 7.4 Wave 3：跨模块一致性与桌面深水区

- [ ] W3-01 完成 `S3-025`、`S3-026`、`S3-027`、`S3-028`，收口其余 iOS 主路径。
- [ ] W3-02 完成 `S3-041`、`S3-042`，把 `mask / ritual / shared stage / inspect` 的 UI 承接补齐。
- [ ] W3-03 完成 `S3-059`、`S3-061`、`S3-062`、`S3-063`、`S3-064`、`S3-065`、`S3-066`，把 macOS 的资源、桌面交互、窗口组织、面板化布局一步到位。
- [ ] W3-04 完成 `S3-083`、`S3-084`，让 iOS/macOS 共享同一 handoff 解释逻辑。

### 7.5 Wave 4：验收与文档闭环

- [ ] W4-01 完成 `S3-091`、`S3-092`，把 iOS + OpenClaw IM smoke 跑通。
- [ ] W4-02 完成 `S3-093`、`S3-094`，建立 macOS parity + desktop optimization 验收矩阵。
- [ ] W4-03 完成 `S3-095`、`S3-096`，补齐 plugin demo / local seed / server-backed joint debug 的三档验证。
- [ ] W4-04 完成 `S3-100`、`S3-101`、`S3-102`，把蓝图、验证模板、Stage 3 AR 文档回写闭环。

## 8. 推荐 4 并发分工

### 8.1 并发 1：iOS Shell 与 Messages Route

职责：

- 负责 iOS 主壳层、消息路由、`ConversationRouter`、`MessagesRoute`、`CompanionChatStore` 拆分。

推荐认领条目：

- [ ] P1-01 `S3-020`
- [ ] P1-02 `S3-021`
- [ ] P1-03 `S3-022`
- [ ] P1-04 `S3-023`
- [ ] P1-05 `S3-024`
- [ ] P1-06 `S3-025`
- [ ] P1-07 `S3-026`
- [ ] P1-08 `S3-027`
- [ ] P1-09 `S3-028`
- [ ] P1-10 `S3-080`
- [ ] P1-11 `S3-083`
- [ ] P1-12 `S3-084`

推荐写入范围：

- `ios/spare-life-ios-app/App/**`
- `ios/spare-life-ios-app/Features/CompanionChat/**`

不建议越界写入：

- `ios/spare-life-openclaw-plugin/**`
- `app/macos/**`

### 8.2 并发 2：OpenClaw IM Contract 与 Capability

职责：

- 负责 locator、card identity、OpenClaw IM envelope、capability matrix、错误面、plugin 侧 contract 对齐。

推荐认领条目：

- [ ] P2-01 `S3-030`
- [ ] P2-02 `S3-031`
- [ ] P2-03 `S3-032`
- [ ] P2-04 `S3-033`
- [ ] P2-05 `S3-034`
- [ ] P2-06 `S3-035`
- [ ] P2-07 `S3-036`
- [ ] P2-08 `S3-037`
- [ ] P2-09 `S3-038`
- [ ] P2-10 `S3-039`
- [ ] P2-11 `S3-040`
- [ ] P2-12 `S3-041`
- [ ] P2-13 `S3-042`
- [ ] P2-14 `S3-043`
- [ ] P2-15 `S3-044`

推荐写入范围：

- `ios/spare-life-openclaw-plugin/**`
- `Docs/researches/Stage_3_AR/section_4_social_messages_profile/**`
- 若必须触达 client 侧，只写共享 contract 文件，不直接改 macOS shell

不建议越界写入：

- `app/macos/**`
- `ios/spare-life-ios-app/App/**`

### 8.3 并发 3：macOS App 与 Desktop Optimization

职责：

- 负责 macOS 宿主、桌面壳层、多栏布局、窗口行为、桌面交互、diagnostic panel 化和页面 parity。

推荐认领条目：

- [ ] P3-01 `S3-050`
- [ ] P3-02 `S3-051`
- [ ] P3-03 `S3-052`
- [ ] P3-04 `S3-053`
- [ ] P3-05 `S3-054`
- [ ] P3-06 `S3-055`
- [ ] P3-07 `S3-056`
- [ ] P3-08 `S3-057`
- [ ] P3-09 `S3-058`
- [ ] P3-10 `S3-059`
- [ ] P3-11 `S3-060`
- [ ] P3-12 `S3-061`
- [ ] P3-13 `S3-062`
- [ ] P3-14 `S3-063`
- [ ] P3-15 `S3-064`
- [ ] P3-16 `S3-065`
- [ ] P3-17 `S3-066`

推荐写入范围：

- `app/macos/**`
- 若采用共享 SwiftUI 宿主，也可认领 macOS 专属 wrapper / shell 文件

谨慎写入范围：

- `ios/spare-life-ios-app/Features/**` 中真正共享的 UI 组件需要先与并发 1、并发 4 对齐写入边界

### 8.4 并发 4：共享层、验证、文档与收尾

职责：

- 负责平台边界、共享层兼容、验证矩阵、README/文档同步、测试脚手架、最终收尾。

推荐认领条目：

- [ ] P4-01 `S3-010`
- [ ] P4-02 `S3-011`
- [ ] P4-03 `S3-012`
- [ ] P4-04 `S3-013`
- [ ] P4-05 `S3-014`
- [ ] P4-06 `S3-071`
- [ ] P4-07 `S3-072`
- [ ] P4-08 `S3-073`
- [ ] P4-09 `S3-074`
- [ ] P4-10 `S3-075`
- [ ] P4-11 `S3-090`
- [ ] P4-12 `S3-091`
- [ ] P4-13 `S3-092`
- [ ] P4-14 `S3-093`
- [ ] P4-15 `S3-094`
- [ ] P4-16 `S3-095`
- [ ] P4-17 `S3-096`
- [ ] P4-18 `S3-100`
- [ ] P4-19 `S3-101`
- [ ] P4-20 `S3-102`

推荐写入范围：

- 根层 `README.md`、`Docs/**`
- 共享层与兼容层
- 测试、脚手架、验证矩阵文件

### 8.5 4 并发之间的协作规则

- [ ] C4-01 并发 1 和并发 2 以 `IMConversationLocator / IMCardID / MessagesRoute` 为唯一接口面，不绕过彼此直接拼 ad-hoc 字段。
- [ ] C4-02 并发 3 不直接发明第二套消息、大师、闲人 contract；macOS 只能消费并发 1 / 并发 2 已冻结的接口。
- [ ] C4-03 并发 4 不主动改 feature 业务逻辑，只负责共享层、验证、文档与边界收口。
- [ ] C4-04 若多个并发都需要碰共享 SwiftUI 组件，先由并发 4 或指定 owner 抽壳，再让各并发分别接入，避免同文件交叉冲突。
- [ ] C4-05 每一轮 wave 结束都要回写本蓝图勾选状态，禁止口头同步而不更新 checklist。
