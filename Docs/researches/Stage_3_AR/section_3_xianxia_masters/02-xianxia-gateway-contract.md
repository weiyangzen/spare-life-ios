# S3-02 XianxiaTopicRepository 网关契约研究

本研究只覆盖 `XianxiaTopicRepository` 的网关契约、环境配置、缓存策略和失败降级路径，不展开 UI 结构改造与 `Masters` 模块。若旧文档与当前代码冲突，以当前代码和现有测试为准。

## 1. 当前代码现状

### 1.1 现有网关契约

当前 repository 实际对接的是一个固定形态的 ClawDB topics 网关：

- base path：`{baseURL}/topics`
- shards path：`{baseURL}/topics/{topicId}/shards`
- method：`GET`
- timeout：`15s`
- query：
  - `tenantId`
  - `batchSize`
  - `cursor`（可选）

响应契约也已经被代码固定下来：

```json
{
  "ok": true,
  "data": { "...payload..." },
  "error": null
}
```

repository 的错误映射规则是：

- 非 2xx：优先尝试从同 envelope 里提取 `error`，否则抛 `invalidHTTPStatus`
- 2xx 但 `ok == false`：抛 `gateway(message)`
- 2xx 且 `ok == true` 但 `data == nil`：抛 `missingPayload`
- 传输层异常：包成 `transport(message)`

这已经是一个存在中的真实 contract，不是“待设计”的空白区。

### 1.2 现有环境配置优先级已经明确，但只存在于代码里

`XianxiaTopicAPIConfiguration.current()` 当前的解析优先级是：

1. `ProcessInfo.environment`
2. `UserDefaults`
3. 硬编码默认值

更细一点：

- base URL：
  - `XIANXIA_TOPICS_BASE_URL`
  - `CLAWDB_TOPICS_BASE_URL`
  - `defaults(xianxia.topic.baseURL)`
  - `defaults(clawdbTopics.baseURL)`
  - 默认 `http://100.82.60.69:17880/v1/clawdb-topics`
- tenant：
  - `XIANXIA_TOPICS_TENANT_ID`
  - `CLAWDB_TOPICS_TENANT_ID`
  - `defaults(xianxia.topic.tenantId)`
  - `defaults(clawdbTopics.tenantId)`
  - 默认 `default`
- feed batch size / shard batch size：
  - 先读 `XIANXIA_*`
  - 再读 `CLAWDB_*`
  - 再读 `defaults(xianxia.topic.*)`
  - 再读 `defaults(clawdbTopics.*)`
  - 最后默认 `20`

另外，base URL 还有一层 `normalizeBaseURL`：

- 空 path 会自动补成 `/v1/clawdb-topics`
- 已经以 `v1/clawdb-topics` 结尾则直接使用
- 否则会在原 path 后再补 `/v1/clawdb-topics`

这些都是当前真实运行逻辑，但现有文档没有把它记录成一个可审计 contract。

### 1.3 现有缓存策略

repository 现在内建了本地 snapshot cache：

- cache root：`Application Support/SpareLife/XianxiaTopics`
- 如果 App Support 取不到，则退回 temporary directory
- topics 一个 snapshot 文件
- shards 按 `topicId` 一个 snapshot 文件
- 文件名不是明文 `topicId`，而是对 `baseURL|tenantId|prefix` 做稳定哈希

这意味着 cache scope 不是“全局唯一一份 Xianxia 数据”，而是至少按下面三项隔离：

- base URL
- tenantId
- topics / shards(topicId)

因此切环境、切 tenant 时，当前代码会自然落到不同 cache 桶，而不是共享同一份旧数据。

### 1.4 当前分页 merge 实际放在 repository 内部

`fetchTopics` / `fetchShards` 当前的行为不是“只返回远端这一页”。

它们会在内部做下面的事：

1. 发网关请求拿当前页。
2. 读取旧 snapshot。
3. 若 `cursor == nil`，直接 reset 为本页。
4. 若 `cursor != nil`，按 `id` 对 `existing + incoming` 做 upsert merge。
5. 把 merge 结果写回 snapshot。
6. 返回 merge 结果给调用方。

因此当前 repository 的真实角色是一个混合体：

- gateway client
- cache store
- page accumulator
- snapshot writer

这正是契约不够清晰的根源。

### 1.5 当前失败降级路径是“repository + view model”分担，而不是 repository 自己完整拥有

repository 自己只负责：

- `cachedTopics()`
- `cachedShards(topicId:)`
- `fetchTopics(...)`
- `fetchShards(...)`

真正的失败降级逻辑现在分散在调用方：

- `XianxiaHomeViewModel.loadInitial()` 先尝试 hydrate cache，再打 live；live 失败时决定是否显示 cache 或 error。
- `SceneTopicViewModel.loadInitial()` 也是同样模式。
- `MyProfileXianrenStatsRepository` 则直接循环 `fetchTopics(cursor:)`，并不走“先 cache 再 live”的 UI 降级路径。

所以当前代码里，“cache fallback”不是 repository contract 自己的显式输出，而是调用方各自手动拼装。

### 1.6 当前 contract 有一个很重要但未文档化的副作用

当前 live fetch 成功后，如果 snapshot 写盘失败，repository 会直接 throw。

也就是说：

- 远端请求明明成功
- payload 也解出来了
- 但只要本地 cache write 失败
- 整个 fetch 仍被当成失败处理

这会把“live success but cache write failed”错误地降级成用户可见失败。当前文档没有记录这一点。

## 2. 当前文档偏差

### 2.1 文档没有记录真实配置优先级和兼容别名

现有 Stage 文档和说明文档会提到：

- 本地代理
- 远端 ClawDB 地址
- 部分环境变量

但没有一份文档完整写出：

- `XIANXIA_*` 优先于 `CLAWDB_*`
- `UserDefaults` 兼容两套 key
- 默认 tenant 是 `default`
- 默认 batch size 是 `20`
- 默认 base URL 会退回 `http://100.82.60.69:17880/v1/clawdb-topics`

这会导致运行环境一旦切换，外部人员只能靠读源码推断。

### 2.2 Stage 3 audit 对分页边界的描述不够准确

`Docs/Stage_3_Codebase_Audit.md` 把现状总结成 `loadMore()` 覆盖数组而不是追加。

当前代码和测试展示的真实情况是：

- view model 的赋值动作确实是覆盖式赋值
- 但 repository 返回前已经从 snapshot merge 过
- 所以“追加效果”是存在的，只是责任落点不清楚

更准确的文档偏差描述应该是：

- 当前分页累计语义并不在 view model，而被隐藏在 repository + cache side effect 中

### 2.3 旧文档把 offline fallback 说成页面能力，但没有说明真实分工

旧文档会说“失败时可回退到最近一次有效缓存”，这句话本身没错，但没说明真实实现位置：

- repository 只提供 raw fetch 和 raw cache read
- 真正何时先读 cache、何时 live 失败回退，是 view model 自己决定

因此现有文档在“功能表述层面正确”，在“边界归属层面不准确”。

### 2.4 文档没有说明 cache bucket 按 baseURL 和 tenantId 隔离

旧文档通常只说：

- topics 与 shards 分层缓存
- 能按 `topicId` 查询对应 shards

但当前代码还额外做了：

- base URL 隔离
- tenantId 隔离
- hash file naming

这会直接影响：

- 多环境 smoke
- preview host 代理切换
- 不同租户之间的 cache 污染风险

现有文档没有把这部分写成 contract。

## 3. 稳定 SOTA 或成熟实践

对 iOS feature data layer，更成熟的做法通常是把三种职责拆开：

1. `Gateway`
   - 只关心 URL、query、HTTP、envelope decode、error mapping。
   - 不关心 cache。
   - 不关心分页累计。

2. `CacheStore`
   - 只关心 snapshot 读写、命名、隔离域、迁移。
   - 不关心 HTTP。

3. `Repository`
   - 只负责把 gateway、cache、load policy 编排成调用方能理解的结果。
   - 明确返回数据来源和降级信息。

另一个成熟实践是：repository contract 必须让“这是单页结果还是累计结果”变成显式语义，不能靠调用方去猜，也不能靠磁盘 side effect 暗中完成。

失败降级方面，更稳定的实践是：

- live fetch success 不应因为 cache write fail 就整体视为失败
- cache write fail 应作为 warning 或 secondary error 暴露
- 调用方能区分 `live data`, `cache data`, `live failed but cache used`, `live succeeded but cache stale`

## 4. 面向本仓库的具体建议

### 4.1 先把 contract 拆成三层

建议把当前 `XianxiaTopicRepository` 背后的接口拆成三组：

#### A. Gateway contract

```swift
protocol XianxiaTopicGatewayContract {
    func fetchTopicsPage(cursor: String?, batchSize: Int) async throws -> XianxiaTopicBatch
    func fetchShardsPage(topicId: String, cursor: String?, batchSize: Int) async throws -> XianxiaTopicShardBatch
}
```

责任：

- 发请求
- decode envelope
- 映射 transport/http/gateway/decode error

不负责：

- merge
- cache
- fallback

#### B. Cache contract

```swift
protocol XianxiaTopicCacheStoreContract {
    func readTopics() throws -> XianxiaTopicPageSnapshot?
    func writeTopics(_ snapshot: XianxiaTopicPageSnapshot) throws
    func readShards(topicId: String) throws -> XianxiaTopicShardSnapshot?
    func writeShards(_ snapshot: XianxiaTopicShardSnapshot) throws
}
```

责任：

- snapshot schema
- cache scope
- file naming
- migration

#### C. Repository contract

```swift
enum XianxiaLoadPolicy {
    case liveOnly
    case cacheOnly
    case cacheThenRefresh
    case refreshWithCacheFallback
}

enum XianxiaDataSource {
    case live
    case cache
}

enum XianxiaRepositoryWarning: Equatable {
    case cacheWriteFailed(String)
}

struct XianxiaRepositoryPage<Item: Equatable>: Equatable {
    let items: [Item]
    let nextCursor: String?
    let total: Int?
    let batchSize: Int
    let tenantId: String
    let source: XianxiaDataSource
    let snapshotDate: Date?
    let warnings: [XianxiaRepositoryWarning]
}
```

repository 再对外提供：

```swift
protocol XianxiaTopicRepositoryContract {
    func loadTopics(cursor: String?, batchSize: Int?, policy: XianxiaLoadPolicy) async throws -> XianxiaRepositoryPage<XianxiaTopic>
    func loadShards(topicId: String, cursor: String?, batchSize: Int?, policy: XianxiaLoadPolicy) async throws -> XianxiaRepositoryPage<XianxiaTopicShard>
    func cachedTopics() throws -> XianxiaTopicPageSnapshot?
    func cachedShards(topicId: String) throws -> XianxiaTopicShardSnapshot?
}
```

### 4.2 对本仓库最关键的一点：repository 不应继续偷偷承担 page accumulator

本仓库里，分页累计更适合放在：

- view model
- 或者一个显式 pager/use case

而不是 repository 通过磁盘 snapshot merge 后再把累计结果塞回去。

原因很直接：

- `XianxiaHomeViewModel`
- `SceneTopicViewModel`
- `MyProfileXianrenStatsRepository`

这三个调用方对“单页”还是“累计页”的需求并不相同。把累计语义绑死在 repository，会让不同调用方都被迫跟着同一种副作用模型走。

### 4.3 保留当前 URL 和 env 兼容面，但把解析过程做成可诊断对象

本仓库已经存在：

- `XIANXIA_*`
- `CLAWDB_*`
- `defaults(xianxia.topic.*)`
- `defaults(clawdbTopics.*)`

这些兼容面短期内不应删除，否则会破坏既有 preview host / smoke / tests。

但建议把它们收敛成一个显式 provider，例如：

```swift
struct XianxiaTopicResolvedConfiguration: Equatable {
    let baseURL: URL
    let tenantId: String
    let feedBatchSize: Int
    let shardBatchSize: Int
    let sources: [String: String]
}
```

这样 diagnostics、smoke、研究文档都能直接看到“这个值从哪来”，而不是继续靠人工猜测。

### 4.4 失败降级应改成“主结果 + 警告”，而不是把 cache write 失败升级成主错误

对当前 repo 最实际的建议是：

- live fetch 成功时，优先把 live data 返回给调用方
- cache write 若失败，作为 warning 挂在结果上
- 真正决定 UI 是否显示“已缓存”“缓存不可写”“离线回退”的，是 presentation 层

这比当前“写盘失败直接整个请求失败”更稳，也更接近真实运行语义。

### 4.5 保留 cache scope 按 baseURL + tenantId 隔离，这是当前代码里做对的一点

当前 cache key 把：

- baseURL
- tenantId
- topics / shards(topicId)

都纳入了 scope，这能避免多环境数据串桶。这个策略不建议回退成简单的固定文件名。

需要改的是：

- 把这条规则写进 contract
- 让 cache store 自己拥有它
- 而不是散落在 repository 私有 helper 中

## 5. 实施顺序

1. 先冻结当前 HTTP contract、env 优先级、cache scope 规则，补成文档和单测基线。
2. 提取 `XianxiaTopicGateway`，保持 URL 和 envelope 行为不变。
3. 提取 `XianxiaTopicCacheStore`，保持现有 cache 命名和 snapshot schema 不变。
4. 让 repository 改为显式 `load policy + source metadata` 输出。
5. 把 pagination accumulation 从 repository 移到调用方或专用 pager。
6. 最后再同步 `XianxiaHomeViewModel`、`SceneTopicViewModel`、`MyProfileXianrenStatsRepository` 的调用方式。

## 6. 风险

- `MyProfileXianrenStatsRepository` 现在依赖 repository 返回“累计后的 topics”；contract 改成单页后，它必须自己显式 append。
- 如果 cache file naming 规则变化，旧 snapshot 会被遗留；需要决定是否做一次性迁移，还是接受自然失效。
- preview host 和本地代理验证现在默认沿用既有环境变量与 URL 规则；兼容面收敛时不能破坏这些 smoke 路径。
- 当前非 2xx 响应依赖 envelope `error` 解码；若服务端未来在 error body 上不再复用该格式，gateway error mapping 需要保留兼容分支。
