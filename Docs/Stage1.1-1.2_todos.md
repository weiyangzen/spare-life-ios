# Stage1.1-1.2 Todos

Authoritative source: `/Users/wangweiyang/GitHub/spare-life-ios/Docs/Stage_1_Blueprint.md`

This file is a working snapshot for Stage 1 Xianxia + Masters only.
Checkmarks must be backfilled from real implementation and local validation.

Progress: 咸虾 3/6, 大师 0/10

## 1.1 咸虾
- [x] 咸虾首页信息架构对齐：Stage 1 首页只保留 topic feed，不再承接扫码、雷达、陌生社交等其他能力。
- [x] topics 数据接入：页面能从统一 topic 数据源读取 topics，并形成可持续分页的 feed。
- [x] topics 本地存储：topics 数据能落到设备本地，并在重进页面或失败场景下复用。

验证记录（2026-03-27）：
`swift build --package-path spare-life-ios-app` 通过；`swift test --package-path spare-life-ios-app --filter XianxiaTopicRepositoryTests` 通过，覆盖 topics 分页合并、失败回退缓存、跨实例复用持久化 topics；`rg -n "QRScanView|SceneAvatarRadarView|SceneSocialIntentView|SceneClusterOverviewView|SceneSummaryCardView|HotTakeCardView|AvatarRadarCardView|SceneSocialPromptCardView" spare-life-ios-app/Features/Xianxia/XianxiaHomeView.swift spare-life-ios-app/App/MainTabView.swift` 未命中，确认首页未接入扫码、雷达、陌生社交残留引用；`curl -sS -m 5 'http://100.82.60.69:17880/v1/clawdb-topics/topics?batchSize=2&tenantId=default'` 与 `curl -sS -m 5 'http://100.82.60.69:17880/v1/clawdb-topics/topics?batchSize=2&tenantId=default&cursor=2'` 均返回 `200 OK` 和有效 topics 数据，确认统一 topic 数据源可持续分页；默认 fallback base URL 已切到 `http://100.82.60.69:17880/v1/clawdb-topics`。
- [ ] topic 卡片双列瀑布流：每个 topic 一张卡片，以双列瀑布流方式呈现，不混入其他卡片类型。
- [ ] topic shards 详情承接：点击任意 topic 后，能读取并展示对应 topic shards，并把 shards 写入本地存储。
- [ ] 咸虾本机验证通过：在 iPhone 15 Pro 上完成 topics 拉取、卡片浏览、进入 topic detail、分页读取 shards、离线回退缓存的主路径。

## 1.2 大师
- [ ] 大师首页信息架构对齐：Stage 1 首页只保留大师目录页，不再优先承接最近聊过谁、会诊、导向行动等复杂能力。
- [ ] 大师目录数据接入：大师目录能从预置角色资源和服务端目录中正确读取并建立索引。
- [ ] 大师资源映射正确：字段固定取自 `./assets/char`，图片固定取自 `./assets/assets`，当前 8 套资源必须一一对应且不能错配。
- [ ] 大师卡片双列瀑布流：每位大师一张卡片，以双列瀑布流方式浏览，卡片信息足以支撑用户做选择。
- [ ] 大师目录只读约束：用户只能浏览和进入对话，不能在端侧新建、删除或编辑大师本体内容。
- [ ] 大师详情承接正确：点击任意大师卡后，进入正确的一对一对话页面，而不是停留在静态详情样板。
- [ ] 单大师对话能力：任意大师都能进行正常、连续、可发送可接收的一对一对话。
- [ ] 大师对话 UI 对齐：对话页延续当前配色方案，聊天布局采用成熟对话结构的 iOS 原生版本，不退化成简陋调试页。
- [ ] 对话密钥与服务安全边界：对话所需密钥与敏感配置只在本机安全读取，不进入客户端页面配置或版本化文档。
- [ ] 大师本机验证通过：在 iPhone 15 Pro 上完成 8 位大师的目录浏览、卡片正确展示、进入任意大师、发送多轮消息、得到稳定回复、退出再进入继续聊天的主路径。
