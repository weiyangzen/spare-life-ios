# S2-04 Feed State Restoration

代码与旧文档冲突时，以代码为准。本报告只讨论 feed/list 状态恢复标准：滚动位置、筛选条件、分页状态、空态和错误态应如何统一，不扩展到产品功能新增或 OpenClaw support code 设计。

## 当前代码现状

### 1. 当前 Swift runtime 没有仓库级 feed/list 状态恢复 contract

在当前 active app shell 与 feature 首页代码里，没有发现统一的：

- `@SceneStorage`
- `@AppStorage`
- `scrollPosition(id:)`
- `NavigationPath` 持久化
- 通用 `RestorationSnapshot`
- per-tab browse state archive

现有状态主要散落在各页面的 `@StateObject` / `@State` 中，能在当前 view 生命周期内保留，但没有形成“可恢复”的统一协议。

### 2. `xianxia` 首页和话题详情只有瞬时状态，没有可恢复快照

`XianxiaHomeViewModel` 当前保存：

- `feedState`
- `topics`
- `totalTopicsCount`
- `nextCursor`
- `isLoadingMore`
- `activeTopic`

`SceneTopicViewModel` 当前保存：

- `loadState`
- `shards`
- `nextCursor`
- `isLoadingMore`

但这两层都没有：

- 滚动位置恢复
- 搜索/筛选恢复
- 已加载页边界恢复
- 重新进入后的 anchor item 恢复
- scene/app 级持久化

更关键的是，两者的 `loadMore()` 现在都会用新 batch 覆盖现有数组，而不是追加：

- `XianxiaHomeViewModel.loadMore()` 把 `topics = batch.items`
- `SceneTopicViewModel.loadMore()` 把 `shards = batch.items`

这意味着当前连“同一次会话里的分页连续性”都不稳定，更谈不上跨重建恢复到原滚动上下文。

### 3. `masters` 是唯一做了本地恢复的模块，但恢复范围只覆盖会话上下文，不覆盖首页 browse state

`MasterExperienceStore` 当前确实有本地状态存档：

- `MasterConversationLocalStateStore.save(...)`
- `MasterConversationLocalStateStore.load()`

持久化内容包括：

- `recentSessions`
- `sessionTranscripts`
- `memoryNotesByMasterID`

相关测试也真实覆盖了：

- 刷新 catalog
- 打开一对一对话
- 连续发送两轮消息
- 重新创建 store
- `restoreSession(...)`
- 恢复后继续沿原历史发送

但首页 browse state 仍然没有进入这个恢复 contract。以下状态不会被恢复：

- `query`
- `selectedDomainID`
- `visibleDirectoryMasterCount`
- 首页滚动位置
- 顶部筛选 chips 的选中态
- 首页空态 / 错误态 / degraded banner
- 当前浏览到哪一批大师卡

反而 `refreshCatalog()` 每次都会：

- 重新装载目录
- `resetDirectoryPagination()`
- 把 `visibleDirectoryMasterCount` 重置到第一页大小

所以当前 `masters` 的真实状态是：

- “对话上下文可恢复”
- “首页 feed/list 浏览状态不可恢复”

这两个概念不能混写。

### 4. `messages` 首页没有恢复 contract，搜索、排序和筛选都停在内存里

`ConversationHubStore` 当前只持有：

- `loadState`
- `threads`
- `searchQuery`
- `selectedKind`

`ConversationHubView` 另外在本地 `@State` 持有：

- `sortMode`

当前没有：

- 持久化 search query
- 持久化 selected kind
- 持久化 sort mode
- 持久化 top visible thread
- 持久化 pinned/read 改动
- 恢复后的最近聊天区 anchor

并且 `refresh()` 会重新用 `mockThreads()` 覆盖 threads，说明就算当前会话里 pin/read 过列表，也没有稳定的恢复基础。

### 5. `earn_social` 和 `my_profile` 目前也没有显式 browse restoration

`EarnSocialHomeView` 的首页状态全部是局部 `@State`：

- `selectedCategory`
- `activeCard`
- `showPreferenceSheet`

当前没有：

- refresh contract
- empty/error contract
- 滚动恢复
- 分页恢复
- category 选择恢复

`MyProfileView` 虽然有 `@StateObject` store 和 `.refreshable`，但也没有：

- 顶层滚动位置恢复
- 首页卡片展开/切换状态恢复
- dashboard browse snapshot

### 6. shared feed 层只记录瞬时滚动观测，不提供恢复 API

`UnifiedWaterfallFeed` 当前会创建内部 `WaterfallScrollState`，只发布：

- `offsetY`
- `isAtTop`

但这份状态：

- 没有对外注入 binding
- 不能编码保存
- 没有 stable item anchor
- 没有恢复入口

因此 shared layer 目前只支持“观察滚动”，不支持“恢复滚动”。

### 7. 当前测试和旧验证记录容易让人误以为恢复能力更完整

当前真实可验证的恢复只有：

- `MasterConversationServiceTests` 对 `restoreSession(...)` 的会话恢复

但旧文档里有更强的说法：

- `Docs/Stage2_Blueprint.md`
- `Docs/Stage2_Blueprint_0328_Checklist.md`
  - 都强调了大师会话恢复测试
- `Docs/ValidationLog_UnifiedUI_FUNC_Batch1.md`
  - 声称 “persisted scroll states on 6 surfaces”
  - 还声称 scene flow “persisted scene feed state”

以当前 Swift runtime 代码为准，这些更强的“统一 scroll/feed state 持久化”结论并没有在 active iOS 首页代码里落地。它们要么来自旧 support/demo 路径，要么超前于当前 runtime。

## 当前文档偏差

### 1. 旧蓝图明确要求“每个 Tab 记住滚动位置、筛选状态和上次浏览上下文”，但当前代码没做到

`Docs/sparelife_blueprint.md` 明确写了：

- 每个 Tab 都需要记住自己的滚动位置、筛选状态和上次浏览上下文
- 需要每个 Tab 独立保存滚动位置、筛选条件、已加载游标

当前 active Swift runtime 里，除了 `masters` 的会话 transcript 外，没有任何首页实现这套 contract。

### 2. 旧验证日志对统一 UI 的恢复能力描述强于当前 runtime

`Docs/ValidationLog_UnifiedUI_FUNC_Batch1.md` 记录了：

- 四个 waterfall home feeds
- 6 个 surface 的 persisted scroll states
- persisted scene feed state

但当前 app shell 的 Swift 代码中没有对应的统一恢复基础设施。按 Stage 3 设计哲学，这类说法不能继续被当作当前 iOS runtime 真相。

### 3. Stage 2 文档里的“restoreSession”容易被误读成“首页状态恢复已完成”

`Docs/Stage2_Blueprint.md` 和其 checklist 镜像都记录了：

- 大师一对一聊天落盘后 `restoreSession` 恢复

这条结论本身是真实的，但它的范围只覆盖：

- conversation transcript
- recent session
- memory notes

它不能外推成：

- 首页滚动恢复
- filter 恢复
- pagination cursor 恢复
- tab-level browse context 恢复

## 稳定 SOTA 或成熟实践

### 1. 要恢复的是“用户可见浏览状态”，不是原样重放整个 view model 内存

成熟实践通常会把恢复对象压缩成可重建的 browse snapshot，而不是直接存 view model 全量内存。最有价值的恢复字段通常是：

- 当前 route / surface identity
- search query
- selected filters / sort
- top anchor item ID
- 已加载页边界或 cursor 边界
- 数据来源标签（live / cached / mock / degraded）
- 最后一次展示的是 empty 还是 error 的语义状态

真正的 transport state、临时 loading 标志、网络错误字符串，不应被机械持久化。

### 2. 滚动恢复优先使用稳定 item anchor，不优先用裸像素 offset

对瀑布流和动态高度卡片来说，成熟做法更偏向：

- 记录顶部可见 item 的稳定 ID
- 记录是“贴顶展示”还是“位于中段”

而不是只存一个 raw `offsetY`。原因是：

- 卡片高度会变
- 列数会变
- 宽度会变
- 数据排序可能更新

用 item anchor 恢复，通常比纯像素偏移更稳。

### 3. 分页状态恢复应该和内容快照分层，不要把“已加载多少页”混进 UI 局部变量

成熟做法会把分页恢复拆成：

- 已展示的 item identity 边界
- 下一个 cursor / page token
- 是否还有更多页

恢复顺序一般是：

1. 先恢复 filter/search/sort
2. 再加载第一页或缓存快照
3. 如有必要，回放到 snapshot 对应的分页边界
4. 最后再滚动到 anchor item

如果先滚动、后补页，或先补页、后改 filter，都会让恢复结果不稳定。

### 4. empty/error 应恢复“语义类型”，不是盲目恢复旧文案

成熟实践不会简单持久化“上次错误字符串”。更稳的方式是记录语义状态，例如：

- `noResultsAfterFilter`
- `initialLoadFailed`
- `showingCacheAfterRefreshFailure`
- `mockDatasetEmpty`

恢复时再结合当前数据源重新决定展示文案，避免把过期错误信息继续展示给用户。

### 5. 每个 tab/feature 自己拥有 browse snapshot，root shell 只做 handoff

在多 tab 应用中，更稳的边界是：

- root shell 只知道“当前进入哪个 surface”
- 每个 tab 自己拥有 `BrowseRestorationSnapshot`
- 跨 tab handoff 只注入目标 route 和必要 payload

否则 root shell 会被迫理解每个 feature 的 scroll/filter/pagination 细节，边界会迅速失控。

### 6. 会话 transcript 和首页 browse state 应分开存

当前 `masters` 已经证明：

- conversation transcript 是长寿命、跨重启的重要资产

但 feed/list browse state 的性质不同：

- 生命周期更短
- 数据结构更轻
- 更适合 scene-scoped 或轻量 snapshot

把这两者混在同一个 archive 里，会导致 snapshot 过大、责任不清、失效条件复杂。

## 面向本仓库的具体建议

### 1. 为 Stage 3 定义一份统一的 browse restoration envelope

建议后续标准至少能表达以下语义：

| 字段 | 说明 |
| --- | --- |
| `surfaceID` | 哪个首页或列表 surface |
| `routeContext` | 例如 topic detail 的 topicID |
| `searchQuery` | 当前搜索词 |
| `selectedFilterIDs` | 当前筛选 |
| `sortKey` | 当前排序 |
| `topAnchorItemID` | 顶部或主 anchor item |
| `paginationBoundary` | 已加载页边界 / next cursor / hasMore |
| `contentState` | `loaded / empty(reason) / error(reason)` |
| `sourceMode` | `live / cached / degraded / mock` |
| `updatedAt` | snapshot 时间戳 |

这个 envelope 是仓库级 contract；具体 feature 可以只使用其中一部分字段。

### 2. 把当前 surface 按恢复复杂度分成 3 类

#### A. 真分页 feed

适用：

- `XianxiaHomeView`
- `SceneTopicView`

最低恢复要求：

- route context
- top anchor item
- next cursor / hasMore
- source mode

但要诚实说明：在 `loadMore()` 仍覆盖数组、没有 append 之前，这一类页面不能声称“已具备稳定恢复能力”。它依赖 S3-03 的分页语义修正。

#### B. 本地筛选 + 分批展示 feed

适用：

- `MasterChatHomeView`

最低恢复要求：

- `query`
- `selectedDomainID`
- `visibleDirectoryMasterCount` 或等价 page boundary
- top visible master ID
- `catalogSourceMode`

现有会话 transcript 存档应继续保留，但必须和首页 browse snapshot 分离。

#### C. IM list / mock-backed list

适用：

- `ConversationHubView`
- `EarnSocialHomeView`
- `MyProfileView` 的首页 dashboard 可只实现最小滚动恢复

最低恢复要求：

- 搜索和筛选
- 排序
- top anchor item
- 当前展示的 source mode

但如果底层仍是 `mockThreads()` 或 in-file fixtures，就必须在 snapshot 中明确 `mock` provenance，不能伪装成稳定业务数据恢复。

### 3. 为每个 surface 明确“恢复输入”和“重新计算状态”的边界

建议统一规则如下：

- 允许持久化：
  - route identity
  - search/filter/sort
  - top anchor item
  - pagination boundary
  - content semantic state
- 不直接持久化：
  - `isLoading`
  - 原始错误字符串
  - 具体 shimmer/skeleton 展示状态
  - 临时弹窗开关

这样恢复时才不会把某次网络失败或某次动画中间态误当成长期真相。

### 4. 把恢复顺序写成统一 lifecycle

建议本仓库统一为：

1. 读取 snapshot
2. 先应用 search/filter/sort
3. 加载缓存或第一页数据
4. 如 snapshot 记录了分页边界，则按边界补齐页数
5. 数据 ready 后恢复 anchor item
6. 后台触发一次 freshness refresh
7. 根据当前结果重新计算 empty/error 语义态

这比“页面各自 `onAppear` 后随便 reload，再试图滚回去”稳定得多。

### 5. shared feed/list 层需要把“可恢复 anchor”变成显式接口

当前 `WaterfallScrollState` 只提供 `offsetY` / `isAtTop` 还不够。shared layer 后续至少要能表达：

- 当前 top visible item ID
- 允许从外部注入初始 anchor
- restore 完成后的回调

否则每个页面都会继续在各自 view body 里手搓 scroll restore 逻辑，无法形成仓库级标准。

### 6. 先把 `masters` 会话恢复和首页恢复拆文义，再扩展到全仓

建议文档和后续实现里显式区分两类恢复：

- `Conversation Restoration`
  - transcript / session / memory notes
- `Browse Restoration`
  - scroll / filter / pagination / empty/error context

当前仓库已经完成前者的一部分，但几乎还没开始后者。这个边界必须先写清楚，才能防止后续文档继续高估现状。

## 实施顺序和风险

### 实施顺序

1. 先定义仓库级 `BrowseRestorationSnapshot` contract，不先落到所有页面。
2. 先接 `masters` 首页和 `messages` 首页。
   这两页最容易验证：
   - 都有明确 search/filter/sort 语义
   - `masters` 已有本地 archive 经验
   - `messages` 是 list，恢复 anchor 相对简单
3. 再接 `xianxia` 和 `SceneTopicView`。
   但必须在 S3-03 修正 append pagination 语义后，才能给出可信的页边界恢复。
4. 最后处理 `earn_social` 和 `my_profile`。
   这两页当前 runtime 仍偏 mock / dashboard，更适合做最小 snapshot，而不是先追求完整分页恢复。

### 风险

- 如果继续用 raw 像素 offset 作为主要恢复依据，瀑布流一旦变列数或卡片高度就会错位。
- 如果把 browse snapshot 和 transcript/archive 混在一起存，state 文件会越来越重，也更难判断何时失效。
- 如果把旧错误字符串直接恢复出来，会在数据已经变化后继续向用户展示过期错误。
- `xianxia` 当前分页覆盖数组的实现，会让任何“恢复到第 N 页”的说法都不可信。
- `earn_social` 与 `messages` 目前都是 mock-heavy 路径，若不显式记录 source provenance，恢复结果会给人“已接上真实数据”的错觉。
