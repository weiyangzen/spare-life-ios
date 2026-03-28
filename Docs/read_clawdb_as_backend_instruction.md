# Stage 1 咸虾数据接入说明

## 1. 目的

Stage 1 的咸虾页面只做一件事：

- 读取 `topic` 列表
- 读取某个 `topic` 下的 `topic shards`
- 把它们缓存到设备本地存储
- 以 `一个 topic 一张卡片` 的双列瀑布流方式展示

除以上内容外，Stage 1 不承接扫码、场景雷达、场景社交、意图草稿或其他扩展能力。

## 2. Stage 1 唯一页面结构

咸虾页面在 Stage 1 只有两层：

1. `Topic Feed`
   - 首页双列瀑布流
   - 每张卡片代表一个 topic
   - 卡片展示 topic 的核心摘要信息
2. `Topic Detail`
   - 点进某张 topic 卡片后进入
   - 页面主体是该 topic 的 `topic shards`
   - shards 按时间顺序或服务端定义顺序展示

## 3. 设备本地存储要求

Stage 1 必须把读取到的 `topics` 与 `topic shards` 落到设备本地存储，满足：

- 首次拉取后可本地复用
- 再次进入页面时优先显示本地缓存
- 网络失败时可回退到最近一次有效缓存
- `topic` 与 `topic shards` 分层缓存
- 能按 `topicId` 查询对应的 shards

## 4. Topic Feed 呈现规则

首页只保留双列瀑布流 topic 卡片，不要加入额外的页面玩法。

每张 topic 卡片建议至少包含：

- topic 标题
- topic 的一句摘要
- shard 数量或最近活跃信息
- 更新时间

交互要求：

- 首屏就能浏览 topic 卡片
- 支持懒加载分页
- 支持下拉刷新或显式刷新
- 支持点击进入 topic detail

## 5. Topic Detail 呈现规则

进入某个 topic 后，只做该 topic 的 shards 展示。

页面要求：

- 顶部清楚标识当前 topic
- 列表主体为 topic shards
- 能区分 shard 的顺序、时间和内容主体
- 支持分页继续加载更早 shards
- 没有数据时给出空态
- 拉取失败时给出错误态和重试路径

## 6. Stage 1 不做的内容

以下能力不属于当前 Stage 1 咸虾范围：

- 扫码进入场景
- 场景公共讨论页的独立多层信息架构
- 活跃分身雷达
- 从场景直接发起陌生社交
- 任何与 topic feed 无关的额外混排卡片

## 7. 验收标准

咸虾 Stage 1 只有在以下条件同时满足时才算通过：

1. 首页能正确拉取并显示 topic 卡片双列瀑布流
2. 点击任意 topic 能进入 shards 详情页
3. topics 与 shards 都能写入本地存储
4. 断网或失败时能回退到本地缓存
5. 页面上没有混入 Stage 1 之外的额外能力
