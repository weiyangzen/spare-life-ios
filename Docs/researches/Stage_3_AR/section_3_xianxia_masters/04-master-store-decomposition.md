# S3-04 `MasterExperienceStore.swift` 职责分层研究

本研究只覆盖 `MasterExperienceStore.swift` 牵出的闲聊运行时边界，不展开 `Xianxia` 分页语义或全仓 package 拆分。若旧文档与当前代码冲突，以当前代码和现有测试为准。

## 1. 当前代码现状

### 1.1 当前不是“一个 store 很大”而已，而是“一个文件承接了多个 runtime 层”

当前文件规模已经接近一个 feature 子系统：

- `spare-life-ios-app/Features/Masters/MasterExperienceStore.swift`
  - `2224` 行
- 作为对照：
  - `MasterConversationView.swift` `595` 行
  - `MasterLocalStateStore.swift` `270` 行
  - `MasterConversationService.swift` `1386` 行

更关键的是，这个文件不只包含 `MasterExperienceStore` 本身，还把以下层一起塞了进去：

1. runtime state store
2. catalog snapshot / coverage model
3. asset loader
4. 目录索引解析
5. 资源路径解析与校验
6. 角色资源 document decode
7. profile 派生规则
8. 本地 fallback reply 组装辅助

这已经不是单纯的“根 store 过长”，而是文件边界直接跨了 presentation / domain / data。

### 1.2 `MasterExperienceStore` 当前至少同时拥有七组职责

#### A. 目录与资产装载

`MasterExperienceStore` 直接拥有：

- `catalogLoader`
- `refreshCatalog()`
- `domains` / `domainIndex`
- `masters` / `masterIndex`
- `catalogCoverage`
- `catalogSourceMode`
- `fatalErrorMessage` / `degradedMessage`

而同文件中的 `MasterCatalogLoader` 又继续负责：

- 资产根目录解析
- 目录索引读取
- 字段 / 图片覆盖校验
- `MasterProfile` 派生
- story / template / palette / boundary 生成

也就是说，“目录资源事实层”和“页面状态层”目前混在同一文件里。

#### B. 目录筛选与分页展示

store 还承担了目录页自己的 presentation 逻辑：

- `query`
- `selectedDomainID`
- `filteredMasters`
- `visibleDirectoryMasterCount`
- `resetDirectoryPagination()`
- `loadNextDirectoryBatchIfNeeded(after:)`

这些和 asset loading 是两个不同层级，但当前都放在同一个 root store 里。

#### C. 会话与 transcript 状态

store 还同时管理：

- `recentSessions`
- `conversation`
- `sessionTranscripts`
- `openConversation(for:)`
- `restoreSession(_:)`
- `markSessionRead(_:)`
- `upsertSession(_:)`

这已经是完整的会话状态 owner。

#### D. 实时诊断与 readiness 状态

store 直接持有并更新：

- `conversationServiceStatus`
- `asrConnectionStatus`
- `chatLiveStatusProbe`
- `applyConversationServiceStatus(_:)`
- `refreshChatLiveDiagnosticsIfNeeded()`

这意味着“目录运行时”和“远端对话 readiness 诊断”也被绑在了一个 actor 上。

#### E. 远端对话编排

`sendMessage(_:)` 当前同时负责：

1. 校验输入
2. 把用户消息落进 transcript
3. 组装 `MasterConversationRequest`
4. 调 `conversationService.generateReply`
5. 提升 `serviceStatus`
6. 更新 session topic / preview / unread
7. 持久化 transcript

这已经是一个 chat coordinator，而不是普通 UI store。

#### F. 本地 fallback、故事检索、记忆与 CTA

同一个 store 内还包含：

- `composeReply`
- `rankedStories`
- `recommendedActions`
- `makeMemoryNote`
- `appendAuthorizedMemory`
- `buildConsultationResult`
- `stanceLabel`

这是一组明显的“领域策略 / fallback engine”职责。

#### G. 自动化桥接

store 初始化时就会：

- `bootstrapAutomationIfNeeded()`
- 触发 `MasterStage1Automation.maybeRun(using:)`
- 通过 `automationResultFileURL` 和 `MasterConversationLocalStateStore` 共享自动化结果文件目录

这不是用户态 UI 的职责，而是 operator / automation bridge。

### 1.3 当前 UI 只真正消费了其中一部分职责

从 Swift runtime 的实际调用面看：

- `MasterChatHomeView.swift`
  - 主要只用：
    - `query`
    - `selectedDomainID`
    - `isLoading`
    - `fatalErrorMessage`
    - `directoryMasters`
    - `visibleDirectoryMasters`
    - `hasMoreDirectoryMastersToLoad`
    - `refreshCatalog()`
    - `openConversation(for:)`
    - `loadNextDirectoryBatchIfNeeded(after:)`
- `MasterConversationView.swift`
  - 主要只用：
    - `conversation`
    - `master(withID:)`
    - `sendMessage(_:)`
    - `setConversationInlineError(_:)`
- `MasterSpeechInputActions.swift`
  - 只额外用：
    - `asrConnectionStatus`
    - `transcribeAudio(at:)`

与此同时，下列状态在当前 Swift UI 路径里几乎没有稳定展示面：

- `consultation`
- `routePreview`
- `recentSessions`
- `catalogCoverage`（除自动化和测试外）
- `conversationServiceStatus` 的全量诊断信息

其中 `consultation` 和 `routePreview` 在 Swift 运行时搜索结果里只有 store 自己定义与更新，没有独立 view 使用。这说明 store 当前持有了“未真正成型的 surface state”。

### 1.4 同一文件里的 `MasterCatalogLoader` 把数据层细节继续向上泄漏

`MasterCatalogLoader` 当前在同一文件内负责：

- `resolveAssetRoots()`
- `validateAssetCoverage(roots:)`
- `resolvedDirectoryManifestPath()`
- `resourceFileIDs`
- `resourceDirectoryIDs`
- `validateImageDirectory`
- `derivedEntry`
- `makeProfile`
- `makeTemplates`
- `makeStories`

这意味着根 store 文件实际上把“资产资源系统”和“闲聊页面状态系统”一起打包了。只要动会话 store，就会顺手碰到目录资产编排。

### 1.5 测试已经把这些跨层职责一起绑定到 `MasterExperienceStore`

现有测试能直接证明 store 现在承担的是整条运行链路：

- `MasterCatalogLoaderTests.swift:137-208`
  - 验证目录只读、8 张卡首屏分页和打开一对一。
- `MasterConversationServiceTests.swift:299-358`
  - 验证 `refreshCatalog()` 会把 chat live probe blocker 映射到入口状态。
- `MasterConversationServiceTests.swift:555-590`
  - 验证远端失败后会回退到角色化 fallback reply。
- `MasterConversationServiceTests.swift:593-760`
  - 验证 store 初始化触发自动化、写结果文件、读 coverage 和会话状态。
- `MasterConversationServiceTests.swift:997-1106`
  - 验证完整 live 对话、落盘、reload、restoreSession、继续携带上下文发送。
- `MasterConversationServiceTests.swift:1109-1231`
  - 验证候选态 -> liveRemote 提升，以及页面侧预检状态传入 conversation。

这些测试本身有价值，但也说明 store 现在已经成了 feature 的总枢纽。

## 2. 当前文档偏差

### 2.1 `Stage_1_Blueprint.md` 说 Stage 1 只保留目录 + 一对一，但 store 已内建更多 latent 能力

`Docs/Stage_1_Blueprint.md:79-120` 明确写的是：

- Stage 1 主链路只保留“目录页 + 一对一对话页”
- 明确不要求：
  - 最近聊过谁
  - 多大师会诊
  - 导向行动
  - 独立记忆管理面板

但当前 store 已经持有：

- `recentSessions`
- `consultation`
- `routePreview`
- `recommendedActions`
- `appendAuthorizedMemory`

这并不意味着代码错了，而是说明文档如果继续把这些能力理解成“未实现”，就会偏离代码事实。更准确的说法应该是：

- 当前 Swift UI 主路径仍以目录 + 一对一为主；
- 但 store 内部已经内嵌了最近会话、会诊、行动导向、记忆写入等 latent runtime state。

### 2.2 `Stage_3_Codebase_Audit.md` 对“一个很大的 store”描述还不够细

`Docs/Stage_3_Codebase_Audit.md` 已经指出：

- `MasterExperienceStore.swift` 是一个很大的 store；
- 它同时持有目录、会话状态、诊断、远端对话行为、本地 fallback。

这判断是对的，但仍低估了两点：

1. 同文件还包含 `MasterCatalogLoader` 及其完整资产派生链，不只是 store。
2. store 初始化还直接桥接 `MasterStage1Automation`，把 operator 自动化耦进用户态 runtime。

也就是说，当前真实问题是“根 store + loader + automation bridge 混装”，不只是“store 过大”。

### 2.3 `Stage2_Blueprint.md` 把大量诊断与自动化能力写成结果，但没有把边界归属写清

`Docs/Stage2_Blueprint.md:181-226` 已经记录了很多与 masters 相关的真实能力：

- chat live candidate / liveRemote 区分
- `/v1/models` 预检
- exact blocker 写入
- `stage2_smoke` 自动化结果文件
- transcript restore
- fallback 角色化改写

这些描述大体符合代码，但没有明确分层：

- 哪些属于 `MasterConversationService`
- 哪些属于 `MasterChatLiveProbe`
- 哪些属于 `MasterExperienceStore`
- 哪些只是 `MasterStage1Automation` 的 operator 能力

结果就是文档看起来很丰富，但未来做拆边界时缺少一个“职责地图”。

### 2.4 现有文档没有指出哪些 store 状态当前没有稳定 UI surface

当前代码里 `consultation` 和 `routePreview` 已经在 store 里有 published state 和 mutation 方法，但 Swift UI 侧没有稳定 surface 消费它们。现有文档没有把这种“latent state but no stable surface”记录出来，容易让后续 worker 误判它们已经是稳定 runtime path。

## 3. 稳定 SOTA 或成熟实践

对这类带目录、对话、fallback、diagnostics、持久化、operator 自动化的 feature，更成熟的做法通常是：

### 3.1 根 store 只做编排，不自己承载所有策略和 IO

更稳定的 root store 一般只负责编排 child store / coordinator，而不是自己直接：

- 读资源目录
- 算 coverage
- 发远端对话
- 生成本地 fallback
- 写落盘
- 启动自动化

### 3.2 目录资产层、会话状态层、远端编排层应分开

成熟的 feature 分层通常会至少分成：

- catalog / repository
- directory presentation state
- conversation session state
- chat orchestration
- diagnostics / readiness
- persistence

这样每一层都能单测，也更容易替换实现。

### 3.3 operator 自动化不应隐式挂在用户态 store 初始化上

自动化桥接如果一定要复用 feature store，也更适合：

- 由外层 app / preview host / automation runner 显式注入
- 或由单独的 automation facade 持有

而不是让用户态 store 在 init 时偷偷触发 operator 工作流。

### 3.4 纯策略逻辑应尽量做成无状态 engine

像下面这些逻辑更适合做纯函数 / 无状态 engine：

- ranked story selection
- fallback reply composition
- memory note derivation
- CTA recommendation
- consultation merge

这样它们就不需要和 UI state 共用一个 `@MainActor` 对象。

## 4. 面向本仓库的具体建议

### 4.1 先把当前运行时切成六个清晰边界

建议把当前 `MasterExperienceStore.swift` 拆成下面六层：

#### A. `MasterCatalogRepository` / `MasterCatalogLoader`

职责：

- 解析 `master_service_directory.json`
- 解析角色 JSON
- 校验图片目录
- 生成 `MasterCatalogSnapshot`
- 提供 `MasterCatalogCoverage`

不负责：

- 搜索关键字
- 目录分页可见数量
- 对话状态
- 自动化触发

#### B. `MasterDirectoryStore`

职责：

- `query`
- `selectedDomainID`
- `visibleDirectoryMasterCount`
- `filteredMasters`
- `visibleDirectoryMasters`
- `refreshCatalog()`

不负责：

- 远端对话
- transcript
- fallback reply
- 自动化结果文件

#### C. `MasterConversationSessionStore`

职责：

- `conversation`
- `recentSessions`
- `sessionTranscripts`
- `openConversation`
- `restoreSession`
- `markSessionRead`
- `upsertSession`

不负责：

- 目录资源加载
- 远端 diagnostics 预检
- ASR 配置解析

#### D. `MasterChatDiagnosticsController`

职责：

- `conversationServiceStatus`
- `chatLiveStatusProbe`
- candidate / liveRemote / localFallback 状态推进
- 页面入口状态与会话状态同步

不负责：

- 目录装载
- transcript 持久化
- fallback reply 文案生成

#### E. `MasterConversationCoordinator`

职责：

- 接收用户输入
- 组装 `MasterConversationRequest`
- 调 `conversationService.generateReply`
- 失败时切 fallback engine
- 回写 session / transcript / memory

这里才是 `sendMessage(_:)` 应在的层。

#### F. `MasterPersistenceRepository`

职责：

- `load()`
- `save(recentSessions:sessionTranscripts:masters:)`
- archive schema 版本治理

这层已经有 `MasterConversationLocalStateStore` 雏形，下一步要做的是把 store 对它的使用边界清晰化，而不是继续混在 root store 内部逻辑里。

### 4.2 `MasterExperienceStore` 短期可退化成 facade，而不是马上消失

考虑到当前 UI、测试和自动化都直接依赖 `MasterExperienceStore`，本仓库更稳妥的做法不是一口气删掉它，而是：

1. 先把底层职责抽到单独类型；
2. 暂时保留 `MasterExperienceStore` 作为 facade；
3. 让 facade 只暴露当前 UI 需要的聚合状态和命令；
4. 再逐步让测试转向更小的 store / coordinator。

这样能避免一次性打断：

- `MasterChatHomeView`
- `MasterConversationView`
- `MasterSpeechInputActions`
- `MasterStage1Automation`
- 现有集成测试

### 4.3 `consultation` 和 `routePreview` 需要单独判定“保留为 latent state 还是移出根 store”

当前 Swift UI 路径里：

- 没有稳定 view 消费 `consultation`
- 没有稳定 view 消费 `routePreview`

因此建议在本仓库里做一个明确选择：

#### 方案 A：近期不做会诊 / route preview surface

那就把它们移出 `MasterExperienceStore` 主暴露面，至少不要继续作为目录主 store 的顶层 published state。

#### 方案 B：后续确实要做

那就提前抽成：

- `MasterConsultationStore`
- `MasterActionRoutingStore`

不要继续塞在目录 + 一对一主 store 里。

### 4.4 自动化桥接应从 `init()` 里移走

当前最危险的隐藏耦合之一是：

- `MasterExperienceStore.init()` 会调用 `bootstrapAutomationIfNeeded()`
- 在特定环境变量下自动跑 `MasterStage1Automation`

建议改为：

- 由 preview host / automation runner 显式创建 `MasterAutomationBridge`
- 再把 `MasterExperienceStore` 注入进去

这样用户态页面创建 store 时就不会隐式背上 operator 责任。

### 4.5 把 fallback engine 从 `@MainActor` store 中拿出来

当前这些方法都是纯策略，更适合迁出：

- `composeReply`
- `rankedStories`
- `recommendedActions`
- `buildConsultationResult`
- `makeMemoryNote`

建议形成无状态的：

- `MasterFallbackReplyEngine`
- `MasterConsultationEngine`
- `MasterMemoryPolicy`

这能直接减少：

- root store 的代码体积
- `@MainActor` 上执行的纯计算
- 远端失败分支与 UI 状态耦合

### 4.6 目录 loader 要和会话 runtime 拆文件，也拆测试

当前 `MasterCatalogLoader` 和资源 document decode 全在 `MasterExperienceStore.swift` 内，会导致：

- 目录资产变更和会话逻辑变更落在同一个 diff
- 文件级 review 难度过高
- 测试职责边界模糊

更适合本仓库的做法是：

- 目录 loader 独立文件 + loader tests
- conversation coordinator 独立文件 + message flow tests
- diagnostics controller 独立文件 + probe tests
- persistence 独立文件 + archive tests

## 5. 实施顺序

1. 先把 `MasterCatalogLoader`、资源 document、目录解析和 coverage 校验从 `MasterExperienceStore.swift` 中独立出来，不改运行行为。
2. 再把 `MasterConversationLocalStateStore` 的 load/save 使用面抽成单独 persistence coordinator，让 store 不再自己维护全部归档细节。
3. 再抽 `MasterChatDiagnosticsController`，把 `conversationServiceStatus`、`chatLiveStatusProbe` 和 preflight -> candidate -> live 的推进逻辑拿出去。
4. 再抽 `MasterConversationCoordinator`，让 `sendMessage(_:)` 只做会话编排，不再和目录刷新、automation、资产 loader 共处一层。
5. 最后决定 `consultation` / `routePreview` 的归宿：要么独立成子 store，要么暂时降为非主路径 latent state。
6. 等上面边界稳定后，再把 `MasterExperienceStore` 收缩成 facade，并把 `bootstrapAutomationIfNeeded()` 从 init 中移走。

## 6. 风险

### 6.1 最大风险不是“拆不动”，而是把现有跨层测试一起打碎

当前很多测试是围绕 `MasterExperienceStore` 这个总入口写的。拆分时如果没有保留 facade 层，测试会一次性大面积失效，影响回归信心。

### 6.2 自动化行为迁移会改变当前 preview / operator 使用习惯

`MasterStage1Automation` 现在依赖 store 初始化自动 bootstrap。把它改成显式桥接后，preview host 和自动化 runner 都要同步更新调用方式，否则会出现“页面能跑，但自动化不再自动产出结果文件”的回归。

### 6.3 目录 loader 抽离会暴露 `#filePath` 资产路径假设

当前 loader 通过 `#filePath` 反推 repo root 和 `Support/master_service_directory.json`。一旦拆文件、改路径或挪层，资产根路径解析就必须同步调整，否则很容易出现“会话逻辑没问题，但目录全挂”的假故障。

### 6.4 latent state 处理不当会制造新的“半实现 surface”

如果直接把 `consultation`、`routePreview` 粗暴外提，却没有对应 UI surface 或明确 owner，就只是把“一个大 store”变成“多个半实现 store”，问题不会真正减少。

### 6.5 主 actor 负载转移需要保持状态一致性

当前很多事情都在一个 `@MainActor` store 里顺序发生。拆分后虽然边界更清晰，但也必须处理好：

- transcript 写回时机
- status 更新时机
- session 与 conversation 同步
- fallback reply 回写顺序

否则容易引入“状态不同步但测试偶发通过”的新问题。
