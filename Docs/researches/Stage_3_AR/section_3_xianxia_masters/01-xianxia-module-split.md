# S3-01 Xianxia 模块拆边界研究

本研究只覆盖 `SceneTopicView.swift` 牵出的 `Xianxia` 模块边界拆分，不展开 `Masters`、通用包边界、或分页语义修正方案细节。若旧文档与当前代码冲突，以当前代码和现有测试为准。

## 1. 当前代码现状

### 1.1 `SceneTopicView.swift` 现在同时承载了多个层级

`spare-life-ios-app/Features/Xianxia/SceneTopicView.swift` 目前同时放了以下职责：

1. `SceneTopicView` 详情页 SwiftUI 视图。
2. `TopicShardSkeleton` 详情页局部占位视图。
3. `SceneTopicViewModel` 详情页状态机和加载流程。
4. `XianxiaTopic`、`XianxiaTopicShard`、`XianxiaTopicBatch`、`XianxiaTopicShardBatch`、snapshot、state enum 等模型类型。
5. `XianxiaTopicAPIConfiguration` 运行时配置解析。
6. `XianxiaTopicRepository` actor、传输层 typealias、错误类型、网关 envelope 解析。
7. cache 目录、cache key、snapshot 读写和 merge 逻辑。
8. `XianxiaRelativeTime`、`XianxiaSenderMask`、`XianxiaFeishuTextExtractor` 等显示辅助和文本清洗逻辑。
9. JSON 编解码、ISO8601、稳定哈希等基础工具。
10. `String.nonEmpty` 这类小型通用扩展。

这意味着一个“详情页文件”已经越过了 view 文件的边界，变成了 `Xianxia` 模块的事实聚合点。

### 1.2 当前依赖方向已经反过来了

从代码关系看，`SceneTopicView.swift` 不只是 detail screen：

- `XianxiaHomeView.swift` 依赖 `XianxiaTopic`、`XianxiaTopicFeedState`、`XianxiaTopicRepository`。
- `SceneFeedCardViews.swift` 依赖 `XianxiaTopic` / `XianxiaTopicShard` 和它们的显示计算属性。
- `MyProfileOverviewMetrics.swift` 依赖 `XianxiaTopicRepository` 与 `XianxiaTopic` 聚合统计。

结果是：

- 首页依赖详情页文件暴露出来的模型和 repository。
- 我的页面依赖详情页文件暴露出来的数据层。
- 详情页文件稍一拆动，就会波及 feed、profile、tests 三处以上。

这不是“一个文件太长”而已，而是模块出口放错了位置。

### 1.3 当前分页“能跑通”，但边界归属不稳

`XianxiaHomeViewModel.loadMore()` 和 `SceneTopicViewModel.loadMore()` 都是直接把 `topics = batch.items` / `shards = batch.items` 整体替换。

但当前 repository 在 `fetchTopics` / `fetchShards` 中会：

- 先读 cache snapshot
- 在 repository 内部按 `id` merge
- 把 merge 结果写回 cache
- 再把 merge 后的 `items` 返回给调用方

所以当前运行时和测试里，分页看起来是“追加成功”的；但这个成功依赖的是 repository 的磁盘 snapshot merge，而不是 view model 自己显式持有分页累计语义。边界上仍然是混装，只是恰好被 cache side effect 掩盖了。

### 1.4 现有 UI 只消费了部分领域信息

`XianxiaTopic` / `XianxiaTopicShard` 已经携带：

- `topicId`
- `topicPath`
- `status`
- `messageCount`
- `summary`
- `senderTail`
- `rawText`
- `updatedAt`
- `shardCount` / `shardOrdinal` / `isCanonical`

但当前 `TopicFeedCardView` 和 `TopicShardCardView` 实际主要只展示：

- `topic.rawTextDisplay`
- `shard.rawTextDisplay`

`senderTailDisplay`、`updatedAt`、`shardOrdinal` 等信息在 UI 上基本未被消费。这说明模型、格式化逻辑和 UI 呈现已经脱节，进一步增加了“什么属于 domain，什么属于 screen-only presentation”的不清晰。

## 2. 当前文档偏差

### 2.1 Stage 3 audit 对分页现状的描述和代码不完全一致

`Docs/Stage_3_Codebase_Audit.md` 目前写的是 `loadMore()` 会“覆盖数组而不是追加”。

当前代码和测试显示的真实情况更细一点：

- view model 的确是整体赋值。
- 但 repository 会在返回前从 cache snapshot 做 merge。
- `XianxiaTopicRepositoryTests` 已经覆盖了 topics/shards 分页 upsert 场景，并验证调用侧最后拿到的是 merge 结果。

所以更准确的表述应该是：

- 当前分页累计语义被藏在 repository + cache side effect 里，而不是由 presentation 层显式拥有。

这里应以代码和测试为准，而不是继续沿用“纯覆盖、不追加”的旧表述。

### 2.2 Stage 1/2 文档对 detail 页展示要求强于当前 UI 实现

旧文档里明确写过：

- detail 顶部应清楚标识当前 topic
- shard 列表应能区分顺序、时间、内容主体
- Stage 2 要求 IM 风格展示，至少包含 id、时间、内容

当前 `SceneTopicView` / `TopicShardCardView` 的现实是：

- 头部标题是固定的“话题内容”，没有显示当前 topic 标识。
- shard 卡片只显示正文内容。
- `senderTailDisplay`、`updatedAt`、`shardOrdinal` 虽然在模型里存在，但未进入当前 UI。

这类冲突应直接写明：旧文档描述的是目标态，不是当前代码事实；Stage 3 研究必须以当前代码为准。

### 2.3 当前文档没有把跨模块依赖写清

旧文档主要把 `SceneTopicView.swift` 当作“topic detail 页面”描述，但代码现实是它还承担：

- `Xianxia` 模块的数据出口
- `MyProfile` 统计数据的依赖入口
- 首页 view model / detail view model 共用状态与模型的定义位置

这层真实依赖关系没有被现有文档准确记录。

## 3. 稳定 SOTA 或成熟实践

对 SwiftUI feature module 来说，更成熟也更稳定的做法通常有四条：

1. 视图文件只承载页面组合和少量局部 UI helper，不承载 repository、config、cache、coder、hash 这类基础设施。
2. 纯模型、格式化逻辑、文本清洗逻辑应独立于 SwiftUI 视图文件，便于复用和单测。
3. 跨 feature 复用的能力应该依赖稳定的 domain/data contract，而不是依赖某个 detail screen 文件。
4. repository 应是 data layer 入口，不应由某个页面文件“顺便定义出来”。

对本仓库尤其重要的一点是：`MyProfile` 已经在复用 `Xianxia` 数据能力，所以 `Xianxia` 需要的是稳定的 feature-facing data boundary，而不是继续把 detail screen 当成默认模块出口。

## 4. 面向本仓库的具体建议

### 4.1 目标不是横向“大层级重构”，而是先把 `SceneTopicView.swift` 从事实总入口降回 screen 文件

建议的收敛方向如下：

```text
Features/Xianxia/
  UI/
    XianxiaHomeView.swift
    SceneTopicView.swift
    SceneFeedCardViews.swift
  Presentation/
    XianxiaHomeViewModel.swift
    SceneTopicViewModel.swift
    XianxiaLoadState.swift
  Domain/
    XianxiaTopic.swift
    XianxiaTopicShard.swift
    XianxiaTopicTextFormatting.swift
  Data/
    XianxiaTopicRepository.swift
    XianxiaTopicRepositoryContract.swift
    XianxiaTopicGateway.swift
    XianxiaTopicCacheStore.swift
    XianxiaTopicAPIConfiguration.swift
    XianxiaTopicSnapshots.swift
    XianxiaTopicGatewayEnvelope.swift
```

这里的重点不是目录名必须完全照抄，而是边界要变成下面这样：

- `UI` 只保留视图和局部占位/卡片。
- `Presentation` 只保留状态机和页面交互。
- `Domain` 保留 `XianxiaTopic` / `XianxiaTopicShard` 和纯显示格式化逻辑。
- `Data` 保留 repository、gateway、cache、config、snapshot、error。

### 4.2 `MyProfile` 的复用点决定了哪些类型不能继续挂在 detail screen 下

由于 `MyProfileXianrenStatsRepository` 已经直接依赖：

- `XianxiaTopicRepository`
- `XianxiaTopic`

因此以下类型应该从 `SceneTopicView.swift` 中尽早抽出为稳定公共边界：

- `XianxiaTopic`
- `XianxiaTopicShard`
- `XianxiaTopicBatch`
- `XianxiaTopicShardBatch`
- snapshot 类型
- repository contract

否则后续任何 detail 页调整都会连带影响 profile 聚合路径。

### 4.3 纯格式化逻辑应该从 screen file 中独立

`XianxiaFeishuTextExtractor`、`XianxiaSenderMask`、`XianxiaRelativeTime` 的共同特征是：

- 不依赖 SwiftUI
- 可能被 feed、detail、profile、未来 diagnostics 多处复用
- 适合做独立单测

它们更适合成为 `Domain/Formatting` 或 `Presentation/Formatting` 级别的独立文件，而不是继续作为 detail 页面私有工具。

### 4.4 repository 实现可以保留在 `Xianxia` feature 内，但不应继续由页面文件定义

当前没有证据表明 `Xianxia` repository 必须马上升为全仓共享 package feature；但至少应做到：

- 不再由 `SceneTopicView.swift` 持有其定义
- 对外暴露稳定 contract
- 让 `XianxiaHomeViewModel`、`SceneTopicViewModel`、`MyProfileXianrenStatsRepository` 都依赖同一 contract

这能先解决边界混乱，再决定后续是否抽到更上层 package boundary。

### 4.5 分页累计语义的责任应在下一步显式化，但不要在本 item 里和 S3-03 混写

本项只建议把“谁拥有分页累计语义”从 detail 文件混装里拆清：

- presentation/use case 层应显式拥有分页累计状态
- repository 应回到清晰的数据访问职责

真正的 infinite-scroll append contract 细化，应留给 S3-03，不在本研究里展开成另一篇分页方案。

## 5. 实施顺序

1. 先抽纯模型和纯格式化逻辑，不改行为。
2. 再把 `XianxiaTopicAPIConfiguration`、repository、snapshot、error、cache helper 从 `SceneTopicView.swift` 中独立出来。
3. 再把 `SceneTopicViewModel` 和 `XianxiaHomeViewModel` 挪到 `Presentation` 层，并用同一个 repository contract 注入。
4. 最后让 `SceneTopicView.swift` 只保留页面组合、refresh/empty/error 呈现和本地 UI 细节。
5. 分页语义显式化与 cache/fallback contract 收敛，放到 S3-02 / S3-03 后续条目处理。

## 6. 风险

- `SpareLifeCore` 测试当前直接 import 这些类型；拆文件后需要同步校正访问控制，但不能改变行为。
- `MyProfile` 已经复用 `Xianxia` repository；若只按“页面拆文件”思路处理，很容易把 profile 依赖点漏掉。
- 现有 UI 测试依赖 `xianxia.topicCard`、`xianxia.topicShardCard`、`xianxia.topicDetail.scrollView` 等标识；拆边界时必须保留这些外部契约。
- 当前命名仍有 `闲人 / 咸虾 / 闲虾 / xianxia` 漂移，重命名应等待 S1-01 的统一词典先落，不要在本项里顺手扩大改名范围。
