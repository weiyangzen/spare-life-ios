# Stage 1 Blueprint

## 1. 文档目的

这份文档是 `Spare Life iOS Stage 1` 的唯一 PRD 与执行基线。

如果本文件与总蓝图有冲突，`Stage 1` 以本文件为准。

Stage 1 的目标不是“代码里已经有一些页面和组件”，而是：

1. 五个主页面的职责必须与总蓝图严格对齐。
2. 页面上的 UI、UX、功能闭环必须出现在正确的页面里。
3. 某项功能即使已经做过，但如果放错页面、信息架构不对、交互路径不对，仍然视为 `未完成`。
4. 只有在本机逐项验证通过后，才允许把该项从 `[ ]` 改为 `[x]`。

本文件聚焦 `5 个底部导航页面`：

- 咸虾
- 大师
- 赚闲能
- 消息
- 我的

原始产品蓝图来源于 [sparelife_blueprint.md](/Users/wangweiyang/GitHub/spare-life-ios/Docs/sparelife_blueprint.md)。

其中 `咸虾` 与 `大师` 在 Stage 1 采用明确的简化版本，不沿用总蓝图的完整能力范围。

运行环境说明：
`100.82.60.69` 是 ClawDB 启动的位置，也是负责 ASR 的机器。
开发环境与真实 iPad / iPhone 都在同一个 Tailscale 网络里，随时都可以真实拉通 `100.82.60.69` 这台后端服务器。
因此 Stage 1 的测试标准默认基于真实连通与真实请求，不以纯本地 mock 作为最终完成依据。

## 2. Stage 1 范围

Stage 1 只处理以下问题：

1. 页面职责是否与蓝图一致。
2. 信息架构是否正确落在对应 Tab。
3. 首页结构、详情承接、sheet 路由、跨页面跳转是否符合蓝图。
4. UI 是否具备正确的视觉层级、卡片类型、状态反馈。
5. UX 是否具备正确的浏览节奏、轻操作、异常态、恢复路径。
6. 功能是否形成真实闭环，而不是静态样板或错误页面上的“伪完成”。

Stage 1 不处理以下问题：

1. 高保真美术精修。
2. 长尾动画 polish。
3. 非蓝图要求的额外玩法扩展。
4. 后台运营工具。

## 2.1 Stage 1 简化覆盖说明

### 咸虾：大量简化

Stage 1 的咸虾页面只保留 `topic` 与 `topic shards` 两层能力。

唯一目标：

- 从统一 topic 数据源读取 topics
- 把 topics 拉到设备本地存储
- 每个 topic 以一张卡片的方式进入双列瀑布流
- 点进某个 topic 后读取并展示对应的 topic shards
- 把 topic shards 也落到设备本地存储

Stage 1 明确不做：

- 扫码
- 场景雷达
- 活跃分身
- 场景发起陌生社交
- 与 topic/topic shards 无关的其他卡片

咸虾 Stage 1 的数据与呈现要求，以 [read_clawdb_as_backend_instruction.md](/Users/wangweiyang/GitHub/spare-life-ios/Docs/read_clawdb_as_backend_instruction.md) 为准。

### 大师：聚焦目录 + 对话

Stage 1 的大师页面只保留两段主链路：

1. 大师目录页
   - 每位大师一张卡片
   - 双列瀑布流
   - 用户可以快速浏览并选择某位大师
2. 大师对话页
   - 点进任意大师后可以进行正常的一对一对话
   - 对话需要具备稳定的上下文承接与回复能力
   - 对话页延续现有配色方案
   - 对话布局可参考现有 web 端的成熟对话结构，但在 iOS 上以原生交互方式落地

Stage 1 的大师资源来源固定为本地私有资产目录：

- `./assets/char`
  - 作为大师的字段来源
  - 每个 json 对应一位大师的结构化资料
- `./assets/assets`
  - 作为大师的图片来源
  - 与字段侧一一匹配

当前 Stage 1 只以 `8 套已匹配的大师资源` 为首批目录范围。

约束：

- 先把这 8 套完全做对
- 目录、卡片、进入对话、对话能力全部基于这 8 套资源闭环
- 后续新增资源继续沿用同样的字段与图片匹配规则，不重改 Stage 1 结构

Stage 1 明确不要求大师页先完成完整的：

- 最近聊过谁
- 多大师会诊
- 导向行动
- 独立大师长期记忆管理面板
- 复杂故事库运营入口

但如果某些底层能力已经存在，可以作为对话质量的一部分被消费，不单独作为 Stage 1 勾选项。

## 3. 勾选规则

本文件统一采用标准 Markdown checkbox：

- `[ ]` 未完成
- `[x]` 已完成

任何一项要打 `[x]`，必须同时满足以下 6 条：

1. `页面归属正确`：该能力出现在蓝图要求的页面，不允许放错页。
2. `信息架构正确`：入口、承接页、跳转方向与蓝图一致。
3. `UI 完整`：页面结构、卡片层级、加载态、空态、错误态齐全。
4. `UX 完整`：关键路径可走通，反馈明确，不依赖开发者口头解释。
5. `功能闭环`：不是静态假数据摆拍，而是用户能真实完成目标动作。
6. `本机验证通过`：必须在本地运行后人工验证通过。

额外强规则：

- 功能已经存在但 `页面放错`，该项仍然必须保持 `[ ]`。
- 只有“能在当前正确页面中完成蓝图定义的目标”，才算完成。
- 不允许以“底层已经写了 store / model / mock 数据”为由提前打勾。
- 不允许以“Simulator 能看见”为由代替真实交互验证。

## 4. 本机验证标准

Stage 1 默认验证设备矩阵：

- `iPhone 15 Pro`
- `iPad Air`

每一项至少需要满足：

1. 能从正确入口进入。
2. 主路径交互可以完成。
3. 页面不会崩溃、白屏、卡死或陷入死路由。
4. 页面在 iPhone 15 Pro 上可用。

以下类型额外要求在 iPad Air 上验证：

1. 五个 Tab 首页
2. 主要详情页
3. 需要大量卡片混排或双列布局的页面
4. 有 sheet / overlay / bottom action 区域的页面

建议每次勾选前补一条本机验证记录：

```md
验证日期：
验证设备：
入口路径：
验证结果：
残留问题：
```

## 5. 页面与代码映射

当前 iOS 页面文件大致映射如下：

- 咸虾：首页与 topic feed [XianxiaHomeView.swift](/Users/wangweiyang/GitHub/spare-life-ios/spare-life-ios-app/Features/Xianxia/XianxiaHomeView.swift)
- 咸虾：topic 详情与 shards 承接 [SceneTopicView.swift](/Users/wangweiyang/GitHub/spare-life-ios/spare-life-ios-app/Features/Xianxia/SceneTopicView.swift)

- 大师：首页 [MasterHomeView.swift](/Users/wangweiyang/GitHub/spare-life-ios/spare-life-ios-app/Features/Masters/MasterHomeView.swift)
- 大师：目录与对话状态承接 [MasterExperienceStore.swift](/Users/wangweiyang/GitHub/spare-life-ios/spare-life-ios-app/Features/Masters/MasterExperienceStore.swift)

- 赚闲能：首页 [EarnSocialHomeView.swift](/Users/wangweiyang/GitHub/spare-life-ios/spare-life-ios-app/Features/EarnSocial/EarnSocialHomeView.swift)
- 赚闲能：撮合结果 [LeadResultView.swift](/Users/wangweiyang/GitHub/spare-life-ios/spare-life-ios-app/Features/EarnSocial/LeadResultView.swift)

- 消息：首页 [ConversationHubView.swift](/Users/wangweiyang/GitHub/spare-life-ios/spare-life-ios-app/Features/CompanionChat/ConversationHubView.swift)
- 消息：主线程 [ChatThreadView.swift](/Users/wangweiyang/GitHub/spare-life-ios/spare-life-ios-app/Features/CompanionChat/ChatThreadView.swift)
- 消息：对人面具 [ContactMaskView.swift](/Users/wangweiyang/GitHub/spare-life-ios/spare-life-ios-app/Features/CompanionChat/ContactMaskView.swift)
- 消息：四人同场 [QuadRoleChatView.swift](/Users/wangweiyang/GitHub/spare-life-ios/spare-life-ios-app/Features/CompanionChat/QuadRoleChatView.swift)
- 消息：关系养成 [RelationshipGardenView.swift](/Users/wangweiyang/GitHub/spare-life-ios/spare-life-ios-app/Features/CompanionChat/RelationshipGardenView.swift)
- 消息：群聊玩法 [GroupAgentPlayView.swift](/Users/wangweiyang/GitHub/spare-life-ios/spare-life-ios-app/Features/CompanionChat/GroupAgentPlayView.swift)
- 消息：跨会话记忆 [CrossSessionMemoryView.swift](/Users/wangweiyang/GitHub/spare-life-ios/spare-life-ios-app/Features/CompanionChat/CrossSessionMemoryView.swift)

- 我的：首页 [MyProfileView.swift](/Users/wangweiyang/GitHub/spare-life-ios/spare-life-ios-app/Features/MyProfile/MyProfileView.swift)
- 我的：同步度 [SyncScoreDashboardView.swift](/Users/wangweiyang/GitHub/spare-life-ios/spare-life-ios-app/Features/MyProfile/SyncScoreDashboardView.swift)
- 我的：觉醒与人格 [AwakeningPersonalityView.swift](/Users/wangweiyang/GitHub/spare-life-ios/spare-life-ios-app/Features/MyProfile/AwakeningPersonalityView.swift)
- 我的：记忆宫殿 [MemoryPalaceView.swift](/Users/wangweiyang/GitHub/spare-life-ios/spare-life-ios-app/Features/MyProfile/MemoryPalaceView.swift)
- 我的：成长统计 [GrowthStatsView.swift](/Users/wangweiyang/GitHub/spare-life-ios/spare-life-ios-app/Features/MyProfile/GrowthStatsView.swift)
- 我的：隐私与本地后端 [PrivacyLocalBackendView.swift](/Users/wangweiyang/GitHub/spare-life-ios/spare-life-ios-app/Features/MyProfile/PrivacyLocalBackendView.swift)

## 6. Stage 1 全空 Checklist

说明：

- 本阶段默认全部未完成。
- 每一项都需要在 `正确页面 + 正确交互路径 + 本机验证` 下通过后，才能改成 `[x]`。

### 6.1 咸虾

- [ ] 咸虾首页信息架构对齐：Stage 1 首页只保留 topic feed，不再承接扫码、雷达、陌生社交等其他能力。
- [ ] topics 数据接入：页面能从统一 topic 数据源读取 topics，并形成可持续分页的 feed。
- [ ] topics 本地存储：topics 数据能落到设备本地，并在重进页面或失败场景下复用。
- [ ] topic 卡片双列瀑布流：每个 topic 一张卡片，以双列瀑布流方式呈现，不混入其他卡片类型。
- [ ] topic shards 详情承接：点击任意 topic 后，能读取并展示对应 topic shards，并把 shards 写入本地存储。
- [ ] 咸虾本机验证通过：在 iPhone 15 Pro 上完成 topics 拉取、卡片浏览、进入 topic detail、分页读取 shards、离线回退缓存的主路径。

### 6.2 大师

- [x] 大师首页信息架构对齐：Stage 1 首页只保留大师目录页，不再优先承接最近聊过谁、会诊、导向行动等复杂能力。
- [x] 大师目录数据接入：大师目录能从预置角色资源和服务端目录中正确读取并建立索引。
- [x] 大师资源映射正确：字段固定取自 `./assets/char`，图片固定取自 `./assets/assets`，当前 8 套资源必须一一对应且不能错配。
- [ ] 大师卡片双列瀑布流：每位大师一张卡片，以双列瀑布流方式浏览，卡片信息足以支撑用户做选择。
- [ ] 大师目录只读约束：用户只能浏览和进入对话，不能在端侧新建、删除或编辑大师本体内容。
- [ ] 大师详情承接正确：点击任意大师卡后，进入正确的一对一对话页面，而不是停留在静态详情样板。
- [ ] 单大师对话能力：任意大师都能进行正常、连续、可发送可接收的一对一对话。
- [ ] 大师对话 UI 对齐：对话页延续当前配色方案，聊天布局采用成熟对话结构的 iOS 原生版本，不退化成简陋调试页。
- [ ] 对话密钥与服务安全边界：对话所需密钥与敏感配置只在本机安全读取，不进入客户端页面配置或版本化文档。
- [ ] 大师本机验证通过：在 iPhone 15 Pro 上完成 8 位大师的目录浏览、卡片正确展示、进入任意大师、发送多轮消息、得到稳定回复、退出再进入继续聊天的主路径。

### 6.3 赚闲能

- [ ] 赚闲能首页信息架构对齐：顶部信息、闲能余额/今日可赚、赛道 chips、双列瀑布流按蓝图落位。
- [ ] 赚闲能首页卡片优先级对齐：赛道机会卡、破冰/继续撮合卡、分身发现卡、竞技场/任务卡按蓝图组织。
- [ ] A2A 六赛道入口：闲置物品、技能问答、婚恋、交友、求职招人、跑腿求助六条赛道明确可见。
- [ ] 陌生社交意图市场：按六条赛道组织意图入口、模板和推荐，不是抽象概念集合。
- [ ] 双 Agent 破冰：完整体现 human-agent-agent-human 四段式预沟通主玩法。
- [ ] 发现别人的分身：用户能浏览陌生人分身卡，并理解为何值得接触。
- [ ] 闲能经济系统：闲能获取、消耗、账本、结算可见且闭环。
- [ ] 六赛道趋势与热点探索：各赛道热度、机会分布、活动与奖励可浏览。
- [ ] A2A 竞技场和社交小游戏：至少有完整入口、玩法承接和结果反馈。
- [ ] 陌生关系升温与羁绊任务：支持从陌生关系推进到熟人关系。
- [ ] 赛道撮合结果与结算：交易/问答/婚恋/求职/跑腿等结果状态可跟踪。
- [ ] 赚闲能本机验证通过：在 iPhone 15 Pro 上完成选赛道、发意图、分身预沟通、进入结果/结算承接的主路径。

### 6.4 消息

- [ ] 消息首页信息架构对齐：顶部标题、搜索/发起/筛选入口、最近聊天区、IM 列表按蓝图落位。
- [ ] 消息首页排序与状态对齐：最近活跃、未读、关系状态、待处理状态能正确影响排序。
- [ ] 熟人聊天主线程：支持 human / agent / system，多消息线程与未读/搜索闭环。
- [ ] 对人面具管理：针对不同联系人能查看、切换、覆写不同社交面具。
- [ ] 真人 + 双方分身同场：四角色同场消息线程能正确区分角色与权限。
- [ ] 熟人关系养成玩法：双人任务、纪念卡、回忆线等关系经营能力落在消息体系内。
- [ ] 熟人群聊 + Agent 玩法：群聊中的做局、总结、投票等玩法有可用承接。
- [ ] 情感连续性与跨会话记忆：进入会话时能看见关系、记忆、情绪和待回应上下文。
- [ ] 消息本机验证通过：在 iPhone 15 Pro 上完成首页找人、进入线程、查看关系卡、操作面具、完成一轮多角色互动。

### 6.5 我的

- [ ] 我的首页信息架构对齐：不是设置页，而是分身控制台式双列卡片流首页。
- [ ] 我的首页卡片优先级对齐：同步度卡必须是首要卡片，其次是人格、记忆、成长、隐私等控制台卡。
- [ ] My Profile：个人资料与分身公开资料可查看、可编辑、可控制可见性。
- [ ] 分身同步度仪表盘：能看到分身像不像我、懂不懂我、能不能替我说话的核心指标。
- [ ] 觉醒度与人格配置：人格 DNA、觉醒、面具、情绪基线等配置有清晰承接。
- [ ] 记忆宫殿管理：分身记忆可查看、编辑、授权、删除，且有边界说明。
- [ ] 数据统计与成长回顾：闲能、社交、同步成长、成长日记等统计卡有正确承接。
- [ ] 隐私与本地后端控制：SQLite、本地数据、授权、备份清理和隐私边界可管理。
- [ ] 我的本机验证通过：在 iPhone 15 Pro 上完成资料查看、同步度查看、人格配置、记忆管理、隐私查看的主路径。

## 7. Stage 1 出口条件

只有当以下条件同时满足时，Stage 1 才算完成：

1. 上述 46 项 checklist 全部变为 `[x]`。
2. 每一项都能在正确页面中完成，不存在“功能做了但挂错页面”的情况。
3. 五个主页面都至少在 `iPhone 15 Pro` 完成一次完整人工验证。
4. 五个首页都至少在 `iPad Air` 上完成一次布局与交互验证。
5. 不再依赖口头解释“这个能力其实在别的页面里”。

## 8. 执行约束

Stage 1 执行过程中，任何新增开发任务都必须满足：

1. 先对照本文件确认归属页面。
2. 再实现 UI。
3. 再补齐 UX 状态。
4. 再接真实功能。
5. 最后本机验证通过后才能打 `[x]`。

如果某项功能已经存在但不符合以上顺序，也不能提前勾选，必须回到正确页面重做对齐。
