# S3-03 Topic / Shard 分页追加语义研究

本研究只覆盖 `Xianxia` 的 topic / shard 分页语义，不展开 `Masters` 模块、通用包边界或 UI 视觉改造。若旧文档与当前代码冲突，以当前代码和现有测试为准。

## 1. 当前代码现状

### 1.1 view model 的 `loadMore()` 写法确实是“覆盖赋值”

当前两条分页主路径都把 `loadMore()` 写成了整体替换：

- `spare-life-ios-app/Features/Xianxia/XianxiaHomeView.swift:209-228`
  - `topics = batch.items`
- `spare-life-ios-app/Features/Xianxia/SceneTopicView.swift:211-229`
  - `shards = batch.items`

如果只看 presentation 层，这就是“覆盖当前数组”，而不是“显式追加到当前列表”。

### 1.2 但 repository 返回的不是“单页”，而是“已合并快照”

当前真实追加语义被藏在 repository 里：

- `spare-life-ios-app/Features/Xianxia/SceneTopicView.swift:548-579`
  - `fetchTopics(cursor:)` 请求远端后，会读取已有 cache snapshot，调用 `mergeTopics(existing:incoming:resetting:)`，把 merge 后结果写回 snapshot，再把 merged items 返回给调用方。
- `spare-life-ios-app/Features/Xianxia/SceneTopicView.swift:583-619`
  - `fetchShards(topicId:cursor:)` 做同样的事，只是粒度换成 shard。
- `spare-life-ios-app/Features/Xianxia/SceneTopicView.swift:678-720`
  - `mergeTopics` / `mergeShards` 以 `id` 为 key 做 upsert：
    - 已存在则原位替换
    - 不存在则尾部追加

所以当前运行时的真实情况不是“完全不会追加”，而是：

1. view model 没有显式持有追加语义；
2. repository 通过“读旧 snapshot -> merge -> 写 snapshot -> 返回 merged items”的副作用，把追加语义偷偷兜住了。

### 1.3 测试已经把“追加成功”绑在 repository 副作用上

现有测试明确证明当前分页在运行效果上会得到累计列表：

- `spare-life-ios-app/Tests/SpareLifeCoreTests/XianxiaTopicRepositoryTests.swift:102-157`
  - `testHomeViewModelLoadsPaginatedTopicsAndPersistsMergedCache`
  - `loadInitial()` 后 2 条，`loadMore()` 后变 3 条，并验证 cache snapshot 也是 3 条。
- `spare-life-ios-app/Tests/SpareLifeCoreTests/XianxiaTopicRepositoryTests.swift:240-289`
  - `testHomeViewModelUpsertsOverlappingTopicsDuringPagination`
  - 第二页既更新旧 topic，也追加新 topic。
- `spare-life-ios-app/Tests/SpareLifeCoreTests/XianxiaTopicRepositoryTests.swift:338-396`
  - `testSceneTopicViewModelUpsertsOverlappingShardsDuringPagination`
  - shard 路径同样依赖 merged snapshot 返回值来完成 upsert + append。

这些测试当前是通过的，但它们证明的是“当前组合行为能追加”，不是“分页语义边界清晰”。

### 1.4 当前 infinite scroll 的累计状态落在磁盘 snapshot，而不是页面内存状态

这带来一个关键架构事实：

- `XianxiaHomeViewModel` 和 `SceneTopicViewModel` 各自只保存：
  - `items`
  - `nextCursor`
  - `isLoadingMore`
  - `feedState` / `loadState`
- 但“上一页有哪些 item”并不是由 view model 在 `loadMore()` 内自己 append 的，而是依赖 repository 从磁盘 snapshot 回读。

换句话说，当前分页累计状态的事实 owner 不是 presentation，而是 cache side effect。

### 1.5 当前实现存在三个直接风险点

#### A. 运行语义依赖 repository 必须持续返回 merged items

只要未来有人把 repository 改成更常见的“返回单页 payload”，而忘了同步改 view model，UI 会立刻从“无限滚动”退化成“翻页覆盖”，而且问题会在运行时才暴露。

#### B. live 成功但 cache 写盘失败会被整体当成失败

当前 `fetchTopics` / `fetchShards` 在请求成功后仍要 `write(snapshot, to:)`。如果写盘失败，整个方法就直接 throw，调用侧会走：

- `topics.isEmpty ? .error : .loadedFromCache`
- `shards.isEmpty ? .error : .loadedFromCache`

于是“远端返回成功，但 cache 写失败”会被误报成一次分页失败。当前追加语义和写盘耦合得太紧。

#### C. cache 既承担离线快照，又承担在线分页累计器

当前一个 snapshot 同时承担两类职责：

1. offline fallback 的只读快照
2. online infinite scroll 的累计器

这会让 contract 变得模糊：

- 调用方不知道 `batch.items` 是单页还是累计结果；
- cache 读写失败会直接影响在线分页行为；
- 后续如果要改成内存分页、内存快照、或只缓存首屏，现有 view model 都会被连带打断。

## 2. 当前文档偏差

### 2.1 `Stage_3_Codebase_Audit.md` 说“覆盖而不是追加”，只说对了一半

`Docs/Stage_3_Codebase_Audit.md` 当前写法是：

- `loadMore()` in both `XianxiaHomeViewModel` and `SceneTopicViewModel` replaces existing arrays with the newest batch instead of appending

这句话在 presentation 层面是对的，但对完整运行语义不够准确。当前代码和测试给出的更精确事实是：

- view model 的赋值动作确实是覆盖式；
- 但 repository 返回前已经做了 snapshot merge；
- 运行结果通常仍表现为追加。

因此真正的问题不是“完全没有追加”，而是：

- 追加语义被隐藏在 repository + cache side effect 中，边界归属错误。

### 2.2 旧文档把“支持 infinite scroll / 按批继续加载”写成能力，但没有说清 owner

`Docs/Stage_1_Blueprint.md:109` 对 masters 目录明确提出“后续扩展到更多资源时要支持按批懒加载 / 分页继续加载”。`Xianxia` 代码现在已经有类似 infinite-scroll 行为，但现有文档没有交代：

- 谁负责维护累计列表；
- cache 是 fallback 还是 page accumulator；
- `loadMore()` 的 contract 是拿单页还是拿累计结果。

这导致文档表面上承认“有分页”，但没有把实现边界写成可验证 contract。

### 2.3 现有研究文档还没把“单页 contract”和“累计 contract”分开

S3-01 / S3-02 已经指出 `SceneTopicView.swift` 混装和 repository 契约混杂的问题，但还没有把分页语义单独落成一条明确规则：

- gateway 应返回单页；
- repository 应明确返回单页还是累计；
- presentation 应不应该自己 append。

S3-03 需要补上的就是这个缺口。

## 3. 稳定 SOTA 或成熟实践

对 SwiftUI / iOS 的 cursor-based feed，更成熟的做法通常有四条：

### 3.1 单页结果和累计结果必须是两种不同语义

更稳定的分页 contract 一般会明确区分：

- `PageResponse<Item>`
  - 只代表本次请求拿回来的这一页
- `AccumulatedListState<Item>`
  - 代表页面当前累计列表、cursor、terminal state、loading flags

不能让调用方靠猜 `items` 到底是单页还是累计结果。

### 3.2 append / upsert 应由 presentation 或专门的 accumulator 显式拥有

对 infinite scroll 来说，“用户当前已看到的列表”是页面状态，不是磁盘缓存状态。成熟实践通常会把追加逻辑放在：

- view model
- use case
- 通用 pagination accumulator

而不是放在“cache snapshot 回读”的副作用里。

### 3.3 cache 应是 fallback 或 warm-start，不应是唯一累计器

cache 适合承担：

- 首屏 warm start
- 离线 fallback
- 上次成功结果回显

但不适合同时承担“在线分页累计的唯一真实 owner”。否则 live path 的正确性就会被 cache 能否读写绑住。

### 3.4 cache 写失败通常应降为 warning，而不是吞掉 live 成功

更成熟的策略通常是：

1. 先把 live page 返回给调用方；
2. 尝试异步或 best-effort 写 cache；
3. 如果写失败，记录 warning / diagnostics；
4. 不把已经成功的 live page 整体回滚成用户可见失败。

## 4. 面向本仓库的具体建议

### 4.1 统一成“gateway / cache / pagination state”三层语义

建议把当前 topic 和 shard 的分页 contract 收敛成：

#### A. gateway / page contract

```swift
struct CursorPage<Item> {
    let items: [Item]
    let nextCursor: String?
    let total: Int?
}
```

这个层只表达“本次拉下来的这一页”。

#### B. cache snapshot contract

```swift
struct PaginatedSnapshot<Item> {
    let items: [Item]
    let nextCursor: String?
    let updatedAt: Date
}
```

这个层只表达“最近一次可回显的快照”。

#### C. presentation accumulator contract

```swift
struct PaginationState<Item> {
    var items: [Item]
    var nextCursor: String?
    var isLoadingMore: Bool
    var source: DataSourceKind
}
```

这个层才是页面真正的累计 owner。

### 4.2 repository 应返回“单页 live 结果”，不要继续把 merged snapshot 伪装成 batch

更适合本仓库的收敛方式是：

- `fetchTopicsPage(cursor:)` / `fetchShardsPage(topicId:cursor:)`
  - 返回单页 live 结果
- `cachedTopicsSnapshot()` / `cachedShardsSnapshot(topicId:)`
  - 返回 snapshot
- `saveTopicsSnapshot(_:)` / `saveShardsSnapshot(_:)`
  - best-effort 写盘

不要继续让 `fetchTopics` / `fetchShards` 既像 gateway，又像 cache store，又像 accumulator。

### 4.3 把 append / upsert 显式移到 view model 或共用 accumulator

对当前仓库，最直接的做法是让两个 view model 显式持有累计语义：

- `loadInitial(forceRefresh:)`
  - 先 hydrate snapshot
  - live 成功后：`items = firstPage.items`
  - `nextCursor = firstPage.nextCursor`
- `loadMore()`
  - live 成功后：对当前 `items` 做 `upsertAppend`
  - `nextCursor = page.nextCursor`

这样即使未来 repository 改回“返回单页”，页面 contract 也不会失真。

### 4.4 `upsertAppend` 要保留当前仓库已经验证过的稳定顺序

现有测试其实已经给出了仓库想要的语义：

- 已出现过的 item 应原位更新；
- 新 item 追加到尾部；
- 不因为 overlap 而打乱先前顺序。

因此建议抽一个统一 helper，topic / shard 共用：

```swift
func upsertAppend<Item: Identifiable>(
    existing: [Item],
    incoming: [Item]
) -> [Item]
```

它的顺序语义应保持：

1. 老项原位置更新；
2. 新项尾部追加；
3. 不重排老列表。

### 4.5 把 cache 写失败从“hard failure”降成“diagnostic warning”

对本仓库更稳的处理方式是：

- live page 解码成功后，先更新 UI
- snapshot 写盘失败只记录 warning
- `feedState` / `loadState` 保持 `.loaded`
- 如需追踪，可给 repository 增加 `lastCacheWarning` 或 diagnostics channel

否则 infinite scroll 的在线正确性会被文件系统状态牵连。

### 4.6 topics / shards 应共用同一套分页状态机

当前两个 view model 基本是镜像实现，只是元素类型不同。建议抽出同一套 contract：

- 统一 `loadInitial`
- 统一 `loadMore`
- 统一 `hydrate snapshot`
- 统一 `prefetch threshold`
- 统一“live / cache / error”状态命名

这样 topic 和 shard 就不会在后续演进中出现一边修了 append、一边还保留旧 contract 的漂移。

### 4.7 测试要从“repository 返回 merged items”转为“view model 自己维护累计结果”

S3-03 完成后的测试重点应该改成：

1. repository 返回第二页单页数据时，view model 仍能 append 成累计列表；
2. overlap item 会原位更新；
3. cache 写失败不会吞掉 live success；
4. hydrate snapshot 只影响首屏 warm-start，不影响 `loadMore()` 的累计 owner。

## 5. 实施顺序

1. 先为 topics / shards 抽出单页 `CursorPage` contract，不改 UI。
2. 把 repository 内的 `mergeTopics` / `mergeShards` 从 live fetch 主路径移出，改成 view model 或 accumulator 使用。
3. 给 `XianxiaHomeViewModel` 和 `SceneTopicViewModel` 增加统一的 `upsertAppend` 累计逻辑。
4. 保留 snapshot 作为 warm-start / fallback，但改为 best-effort 写盘。
5. 重写分页相关测试，让它们验证“view model 自己 append”，而不是隐式依赖 repository 回传 merged snapshot。
6. 最后再把 topic / shard 两条分页状态机收敛成可复用实现，减少双份维护。

## 6. 风险

### 6.1 迁移时最容易把“显示顺序”改坏

当前测试实际上默认了“旧项原位更新 + 新项尾部追加”的顺序。如果重构时改成简单的 `Dictionary` 重建列表，顺序就可能漂移，直接影响 feed 连续性。

### 6.2 pull-to-refresh 和 load-more 的 cursor 竞争要重新校准

一旦 view model 自己持有累计状态，`refreshFromPullToRefresh()`、`loadInitial(forceRefresh:)`、`loadMore()` 的互斥关系就必须明确，否则会出现：

- 旧 cursor 继续追加到新列表；
- 刷新后被旧分页回包反向污染。

### 6.3 cache 语义变化会影响 offline 体验

如果把 cache 从“累计 owner”改回“warm-start snapshot”，必须同步决定：

- snapshot 保存首屏还是累计结果；
- refresh 后是否立即覆盖旧 snapshot；
- shard snapshot 是否仍按 `topicId` 保存完整累计列表。

这些不是阻塞重构的理由，但必须在实施时一次说清。

### 6.4 现有测试需要同步换语义，否则会形成假保护

如果只改实现不改测试，测试仍然可能因为 repository 继续返回 merged items 而通过，无法真正保护“presentation 层显式拥有追加语义”这一目标。
