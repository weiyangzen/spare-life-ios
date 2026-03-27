# Stage1.1-1.2 Todos

Authoritative source: `/Users/wangweiyang/GitHub/spare-life-ios/Docs/Stage_1_Blueprint.md`

This file is a working snapshot for Stage 1 Xianxia + Masters only.
Checkmarks must be backfilled from real implementation and local validation.

Progress: 咸虾 5/6, 大师 8/10

## 1.1 咸虾
- [x] 咸虾首页信息架构对齐：Stage 1 首页只保留 topic feed，不再承接扫码、雷达、陌生社交等其他能力。
- [x] topics 数据接入：页面能从统一 topic 数据源读取 topics，并形成可持续分页的 feed。
- [x] topics 本地存储：topics 数据能落到设备本地，并在重进页面或失败场景下复用。

验证记录（2026-03-28）：
`swift build --package-path spare-life-ios-app` 通过；`swift test --package-path spare-life-ios-app --filter XianxiaTopicRepositoryTests` 10/10 通过，新增覆盖 iPhone 宽度双列 `WaterfallColumns` 与 `vm.open(topic)` 详情承接状态，并继续覆盖 topics 分页合并、跨实例复用持久化 topics、刷新失败回退缓存，以及 shards 缓存回退与分页 upsert；`curl -i --max-time 10 'http://100.82.60.69:17880/v1/clawdb-topics/topics?batchSize=2&tenantId=default'` 返回 `HTTP/1.1 200 OK`，首批 `2` 条 topic、`nextCursor="2"`；同接口 `cursor=2` 二页探针返回 `ok=True`、`count=2`、`nextCursor='4'`；`curl -sS --max-time 15 'http://100.82.60.69:17880/v1/clawdb-topics/topics/group%3Aoc_01e791aeef5b12259676e529a770a2e6%3A%3Ageptopic-000001/shards?batchSize=2&tenantId=default'` 返回 `ok=true`、`count=2`、`nextCursor=null`，确认 live shard detail 数据可读；`rg -n "WaterfallLayout|TopicFeedCardView|ForEach\\(vm\\.topics\\)|vm\\.open\\(|navigationDestination|SceneTopicView" spare-life-ios-app/Features/Xianxia/XianxiaHomeView.swift` 命中 feed 仅以 `TopicFeedCardView` 进入 `WaterfallLayout`，并由 `vm.open(topic)` 承接到 `SceneTopicView`；`xcodebuild -project spare-life-ios-preview-host/SpareLifePreviewHost.xcodeproj -scheme SpareLifePreviewHost -destination 'platform=iOS Simulator,id=63DAFAF1-789A-4206-8B3C-6B87048AFDF1' build` 通过，随后 `xcrun simctl get_app_container 63DAFAF1-789A-4206-8B3C-6B87048AFDF1 com.wangweiyang.sparelife.previewhost data` + `find "$APP_DATA/Library/Application Support/SpareLife/XianxiaTopics" -maxdepth 1 -type f` 返回 `xianxia-fc9253545836f48d.json`，确认 `Stage1 iPhone 15 Pro` 模拟器首屏运行后已写入本地 topics 缓存；`rg -n "QRScanView|SceneAvatarRadarView|SceneSocialIntentView|SceneClusterOverviewView|SceneSummaryCardView|HotTakeCardView|AvatarRadarCardView|SceneSocialPromptCardView" spare-life-ios-app/Features/Xianxia/XianxiaHomeView.swift spare-life-ios-app/App/MainTabView.swift` 未命中，确认 Stage 1 首页挂载路径未接入扫码、雷达、陌生社交残留入口。
- [x] topic 卡片双列瀑布流：每个 topic 一张卡片，以双列瀑布流方式呈现，不混入其他卡片类型。
- [x] topic shards 详情承接：点击任意 topic 后，能读取并展示对应 topic shards，并把 shards 写入本地存储。
- [ ] 咸虾本机验证通过：在 iPhone 15 Pro 上完成 topics 拉取、卡片浏览、进入 topic detail、分页读取 shards、离线回退缓存的主路径。
## 1.2 大师
- [x] 大师首页信息架构对齐：Stage 1 首页只保留大师目录页，不再优先承接最近聊过谁、会诊、导向行动等复杂能力。
- [x] 大师目录数据接入：大师目录能从预置角色资源和服务端目录中正确读取并建立索引，且当前已提供的整批资源必须全部进入目录。
- [x] 大师资源映射正确：字段固定取自 `./assets/char`，图片固定取自 `./assets/assets`，当前已提供的资源必须一一对应且不能错配；当前首批为 8 套。
- [x] 大师卡片双列瀑布流：每位大师一张卡片，以双列瀑布流方式浏览；当前首批 8 位必须全部显示，后续扩展到更多大师时要支持按批懒加载。
- [x] 大师目录只读约束：用户只能浏览和进入对话，不能在端侧新建、删除或编辑大师本体内容。
- [x] 大师详情承接正确：点击任意大师卡后，进入正确的一对一对话页面，而不是停留在静态详情样板。
- [x] 单大师对话能力：任意大师都能进行正常、连续、可发送可接收的一对一对话。
- [ ] 大师对话 UI 对齐：对话页延续当前配色方案，聊天布局采用成熟对话结构的 iOS 原生版本，不退化成简陋调试页。
- [x] 对话密钥与服务安全边界：对话所需密钥与敏感配置只在本机安全读取，不进入客户端页面配置或版本化文档。
- [ ] 大师本机验证通过：在 iPhone 15 Pro 上完成当前已提供大师批次的目录浏览、卡片正确展示、进入任意大师、发送多轮消息、得到稳定回复、退出再进入继续聊天的主路径；当前首批为 8 位。

验证日期：2026-03-28
验证设备：macOS 本地 masters slice 校验
入口路径：`MasterHomeView` 目录页 -> `.navigationDestination(item: $store.conversation)` 一对一对话页
验证结果：执行 `xcrun --sdk macosx swiftc -typecheck spare-life-ios-app/App/DesignSystem/PlatformCompat.swift spare-life-ios-app/App/DesignSystem/DesignTokens.swift spare-life-ios-app/App/DesignSystem/WaterfallLayout.swift spare-life-ios-app/Features/Shared/FeedCardProtocol.swift spare-life-ios-app/Features/Shared/UnifiedWaterfallFeed.swift spare-life-ios-app/Features/Masters/MasterConversationService.swift spare-life-ios-app/Features/Masters/MasterExperienceStore.swift spare-life-ios-app/Features/Masters/MasterHomeView.swift` 通过；另用临时命令行 harness 编译并运行 masters slice，输出 `service_mode=liveRemote`、`credential_source=keychain`、`model=claude-sonnet-4-6`，随后依次输出 8 位当前 Stage 1 大师的 `single_turn_ok=<asset_id>:<displayName>`，并以 `follow_up_messages=7`、`masters_validation_ok` 收尾，确认当前 8 位大师都能走真实远端一对一收发，且首位大师可继续追问形成多轮上下文；同一 harness 还确认对话密钥已从本机 `ANTHROPIC_API_KEY` 引导写入并回读自钥匙串，不进入页面配置。`xcodebuild -project spare-life-ios-preview-host/SpareLifePreviewHost.xcodeproj -scheme SpareLifePreviewHost -destination 'platform=iOS Simulator,id=63DAFAF1-789A-4206-8B3C-6B87048AFDF1' build` 仍被 `spare-life-ios-app/Features/Xianxia` 中既有冲突标记阻塞，失败点不在 masters lane。
残留问题：大师对话 UI 已按原生聊天结构重做，但受 `spare-life-ios-app/Features/Xianxia` 现有冲突阻塞，尚未完成独立于全工程构建的设备态 UI 验证，因此本批次不勾选“大师对话 UI 对齐”与 “大师本机验证通过”。
