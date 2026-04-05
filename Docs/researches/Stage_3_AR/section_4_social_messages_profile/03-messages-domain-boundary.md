# S4-03 消息模块真实领域边界

## 当前代码现状

1. 当前 Swift runtime 的消息入口只有两层主路径：`MainTabView` 把 `消息` tab 直接接到 `ConversationHubView()`，而 `ConversationHubView` 自己起 `NavigationStack`，只把 `ConversationThread` 导航到 `ChatThreadView`。证据在 `spare-life-ios-app/App/MainTabView.swift:70-83` 与 `spare-life-ios-app/Features/CompanionChat/ConversationHubView.swift:17-45`。
2. `CompanionChatStore.swift` 目前不是一个单纯的 “IM hub store” 文件，而是把多个子域的核心类型压在一起：
   - `IM hub`：`ConversationKind`、`ConversationThread`、`ConversationHubStore`
   - `thread`：`ChatSenderRole`、`ChatMessage`
   - `mask`：`ContactMaskConfig`、`MaskHistoryEntry`
   - `relationship`：`BondTask`、`AnniversaryCard`、`RelationshipProfile`
   - `memory`：`MemorySnippet`
   证据在 `spare-life-ios-app/Features/CompanionChat/CompanionChatStore.swift:11-239`。
3. `ChatThreadView` 已经在 UI 层承担了跨域聚合器角色，而不只是“消息时间线页面”。它持有 `showContactMask`、`showRelationship`、`showQuadRole`、`showGroupPlay`、`showCrossSessionMemory` 五个跨域路由状态，并在 toolbar 与 context cards 中直接拉起这些子页。证据在 `spare-life-ios-app/Features/CompanionChat/ChatThreadView.swift:45-58`、`spare-life-ios-app/Features/CompanionChat/ChatThreadView.swift:321-346`、`spare-life-ios-app/Features/CompanionChat/ChatThreadView.swift:365-389`、`spare-life-ios-app/Features/CompanionChat/ChatThreadView.swift:472-698`。
4. 现有高级子页已经自然分化出独立语义，但它们在 Swift runtime 中仍然各自使用本地 mock store：
   - `ContactMaskStore.save()` 只延迟后插入一条假 history，并直接注释 “In production: persist to local DB”。证据在 `spare-life-ios-app/Features/CompanionChat/ContactMaskView.swift:41-57`。
   - `RelationshipGardenStore.load()` 会用 `mockProfile(base:)` 覆写传入的 profile。证据在 `spare-life-ios-app/Features/CompanionChat/RelationshipGardenView.swift:52-57` 与 `spare-life-ios-app/Features/CompanionChat/RelationshipGardenView.swift:87-127`。
   - `CrossSessionMemoryStore.load()` 用 `mockSnapshot(thread:)` 加载跨会话记忆。证据在 `spare-life-ios-app/Features/CompanionChat/CrossSessionMemoryView.swift:129-139`。
   - `GroupAgentPlayStore.load()` 用 `mockSnapshot(groupName:)` 加载群玩法快照。证据在 `spare-life-ios-app/Features/CompanionChat/GroupAgentPlayView.swift:164-177`。
   - `QuadRoleChatStore.load()` 用 `mockQuadMessages(contactName:)` 加载四人场。证据在 `spare-life-ios-app/Features/CompanionChat/QuadRoleChatView.swift:32-38` 与 `spare-life-ios-app/Features/CompanionChat/QuadRoleChatView.swift:56-78`。
5. 与 Swift runtime 相比，仓库支撑层其实已经表达出更清楚的领域边界。`companionContracts.mjs` 区分了 `conversation`、`participant`、`mask`、`relationship`、`ritual`、`memory`、`group vote` 等独立契约与 route helper，证据在 `spare-life-ios-app/Domain/Models/companionContracts.mjs:9-29` 与 `spare-life-ios-app/Domain/Models/companionContracts.mjs:115-220`。`companionChatRepository.mjs` 也分别定义了 `conversationRow`、`messageRow`、`maskRow`、`relationshipRow`、`ritualRow`、`memoryRow`、`groupRow`、`voteRow`、`groupSummaryRow` 的解析边界，证据在 `spare-life-ios-app/LocalBackend/SQLite/companionChatRepository.mjs:51-248`。
6. 结论不是“消息模块没有边界”，而是“仓库支撑层已经有边界，当前 Swift runtime 只是在 UI 和共享模型文件里把它们重新压扁了”。

## 当前文档偏差

1. `Stage_3_Codebase_Audit.md` 对消息模块的现实描述是准确的：当前 IM hub 仍然是 mock-data 驱动，且 app shell 没有完整表达高级消息页面的导航图。证据在 `Docs/Stage_3_Codebase_Audit.md:81-93`。
2. 真正的偏差来自验证日志把“仓库支撑能力”写成了“当前 iOS runtime 事实”。`ValidationLog_Messages_FUNC_Batch1.md` 把 IM hub、主线程、面具、关系、群玩法、跨会话记忆全部记为 “persisted and returned end-to-end” 或 “real”，并把 Node + SQLite demo 作为主要验证证据。证据在 `Docs/ValidationLog_Messages_FUNC_Batch1.md:12-18`、`Docs/ValidationLog_Messages_FUNC_Batch1.md:24-46`、`Docs/ValidationLog_Messages_FUNC_Batch1.md:52-110`。
3. 这与仓库审计结论直接冲突：审计已经明确 `.mjs`、本地 backend、plugin runtime 并不编译进当前 `SpareLifeCore` Swift package 运行时，因此不能把它们直接当成当前 app shell 的已接线事实。证据在 `Docs/Stage_3_Codebase_Audit.md:121-127`。
4. `ValidationLog_Messages_UIUX_Batch1.md` 写的是 “接入消息详情路由”，但当前 Swift 代码里的高级子页只是 `ChatThreadView` 上的本地 `sheet`，并不是消息模块的一等 route。证据在 `Docs/ValidationLog_Messages_UIUX_Batch1.md:12-13`、`Docs/ValidationLog_Messages_UIUX_Batch1.md:35-39` 与 `spare-life-ios-app/Features/CompanionChat/ChatThreadView.swift:321-346`。
5. 因此，Section 4 后续研究必须持续区分三层真相：
   - 当前 shipped Swift runtime
   - 仓库内已存在的 support/backend domain
   - 还未完成接线的未来消息架构

## 稳定 SOTA / 成熟实践

1. 消息类产品通常按 bounded context 切分，而不是按“一个总聊天页 + 几个弹窗”切分。成熟边界通常至少包括：
   - 会话列表 / hub
   - 线程时间线 / composer
   - per-contact communication policy
   - relationship progression / rituals
   - cross-session memory / recall
   - group coordination / vote / summary
2. `IM hub` 应只消费轻量 summary projection，而不拥有子域明细状态。它需要的是 `conversation summary`、过滤器、排序和 unread，而不是 mask 历史、关系任务列表、记忆纠错表单。
3. `thread` 适合作为应用层 orchestration shell，负责时间线、输入框、上下文摘要和子域入口；但它不该直接拥有子域明细状态，更不该用一串布尔值表达整个子域路由图。
4. `mask`、`relationship`、`memory`、`group play` 应各自拥有清晰 aggregate 和 repository/protocol。哪怕当前还是 mock，也应该先在命名和类型边界上独立出来。
5. 如果仓库支撑层已经有数据库表、契约函数和 route helper，Swift runtime 的边界命名应优先向这些稳定契约对齐，而不是再发明一套新的临时分类。
6. “四人场”更像 `thread` 的一种会话模式，而不是和 `mask`、`relationship`、`memory` 同级的顶层 bounded context；`agentDirect` 则是 `ConversationKind`，不是新的子域。

## 面向本仓库的具体建议

### 建议的边界定义

| 边界 | 当前主要载体 | 应拥有的职责 | 不应继续拥有的职责 |
| --- | --- | --- | --- |
| `IM hub` | `ConversationHubView`, `ConversationHubStore`, `ConversationThread` | 会话列表、搜索、排序、未读、置顶、打开线程 | 面具历史、关系任务、记忆纠错、群投票明细 |
| `thread` | `ChatThreadView`, `ChatThreadStore`, `ChatMessage` | 时间线、输入、AI sidecar、上下文摘要、跳转子页 | 子域 detail state、自身以外的 route bool 风暴 |
| `mask` | `ContactMaskView`, `ContactMaskStore`, `ContactMaskConfig` | per-contact 语气、透露程度、topic policy、配置历史 | 线程消息、关系羁绊、群玩法 |
| `relationship` | `RelationshipGardenView`, `RelationshipGardenStore`, `RelationshipProfile` | 温度/羁绊、双人任务、纪念卡、回忆线 | 跨会话检索、群投票、线程输入 |
| `memory` | `CrossSessionMemoryView`, `CrossSessionMemoryStore`, `CrossSessionSnapshot` | 摘要层、长期记忆、情绪快照、纠错、待接续 | 面具策略、关系 ritual 排期、群消息治理 |
| `group play` | `GroupAgentPlayView`, `GroupAgentPlayStore`, `GroupPlaySnapshot` | 群 Agent、噪音控制、投票、总结、行动项 | 1v1 关系养成、per-contact mask |

### 额外边界判定

1. `quadRole` 应定义为 `thread` 的一种 presentation / participation mode，而不是新的顶层域。
2. `agentDirect` 只是 `ConversationKind` 的一种分类，属于 hub 和 thread 的筛选/呈现维度，不是独立子域。
3. `ConversationThread` 保留 `relationTemperature`、`activeMaskName` 这类字段是可以接受的，但它们必须被定义为 hub summary projection，而不是这些子域的 source of truth。
4. `CompanionChatStore.swift` 需要拆成按边界分组的文件，即使仍然留在同一个 feature 目录里，也不应再由一个“共享数据模型与 Store”文件背负整个消息簇的类型定义。
5. 推荐的最小拆分方向：
   - `Features/CompanionChat/Hub/*`
   - `Features/CompanionChat/Thread/*`
   - `Features/CompanionChat/Mask/*`
   - `Features/CompanionChat/Relationship/*`
   - `Features/CompanionChat/Memory/*`
   - `Features/CompanionChat/GroupPlay/*`
   - `Features/CompanionChat/Shared/*` 只保留真正跨域共享的枚举和 summary DTO
6. 支撑层协议也应按边界镜像，而不是一个抽象 “CompanionChatRepository” 吞掉全部语义。至少在 Swift runtime 接口层面，建议拆出：
   - `ConversationSummaryRepository`
   - `ThreadTimelineRepository`
   - `ContactMaskRepository`
   - `RelationshipRepository`
   - `CrossSessionMemoryRepository`
   - `GroupPlayRepository`
7. 当前 runtime 状态标签应写实：
   - `live shell`: `IM hub` 与 `thread` 的基础 UI
   - `locally seeded surfaces`: `mask`, `relationship`, `memory`, `group play`, `quad role`
   - `support/backend domain`: `.mjs` contracts + SQLite repository + plugin demo

## 实施顺序

1. 先在文档中冻结边界词汇，明确 `IM hub / thread / mask / relationship / memory / group play / quadRole / agentDirect` 的归属关系。
2. 然后拆 `CompanionChatStore.swift` 的共享类型，把 hub summary、thread timeline、mask、relationship、memory、group play 的模型文件分开。
3. 再让 `ChatThreadView` 退回 “线程壳层”，只保留上下文摘要与子域跳转，不再直接持有子域明细状态。
4. 接着按边界给每个子域补 repository/protocol，对齐已有 `.mjs` 与 SQLite 支撑层的命名。
5. 最后再决定哪些子域要真正接到 persistence-backed runtime，哪些仍然明确标成 local seed / prototype。

## 风险

1. 如果不先做边界冻结，后续任何导航或数据层优化都可能继续围绕“一个线程页管理全部消息子域”展开，返工会继续累积。
2. 如果把 `relationship` 和 `memory` 混成一个域，`回忆线`、`跨会话摘要`、`纠错`、`ritual` 的职责会再次打结，最终既不好持久化也不好解释。
3. 如果把 `group play` 当成普通 thread 插件而不是 group-only bounded context，群投票、噪音控制和摘要能力会污染 1v1 路径。
4. 如果继续把 Node/SQLite 支撑能力写成“当前 app shell 已真实接线”，文档将持续误导后续 worker 在错误层面上做优化。
5. 如果过度抽象，提前把所有边界都塞回一个“万能消息仓库”，表面上类型分了，真实 ownership 仍然不清楚，风险不会下降。
