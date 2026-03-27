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
`swift test --filter XianxiaTopicRepositoryTests` 通过，覆盖 topics 分页合并、刷新失败回退缓存、跨实例复用持久化 topics、重叠分页 upsert，以及 shards 缓存回退与分页 upsert；`curl -sS -m 10 'http://100.82.60.69:17880/v1/clawdb-topics/topics?batchSize=2&tenantId=default' | jq '{ok, count: (.data.items|length), nextCursor: .data.nextCursor, firstTopicId: .data.items[0].topicId}'` 返回 `ok=true`、`count=2`、`nextCursor="2"`、`firstTopicId="group:oc_01e791aeef5b12259676e529a770a2e6::geptopic-000001"`；`curl -sS -m 10 'http://100.82.60.69:17880/v1/clawdb-topics/topics?batchSize=2&tenantId=default&cursor=2' | jq '{ok, count: (.data.items|length), nextCursor: .data.nextCursor, firstTopicId: .data.items[0].topicId}'` 返回 `ok=true`、`count=2`、`nextCursor="4"`、`firstTopicId="group:oc_01e791aeef5b12259676e529a770a2e6::geptopic-000003"`；`rg -n "QRScanView|SceneAvatarRadarView|SceneSocialIntentView|SceneClusterOverviewView|SceneSummaryCardView|HotTakeCardView|AvatarRadarCardView|SceneSocialPromptCardView" spare-life-ios-app/Features/Xianxia/XianxiaHomeView.swift spare-life-ios-app/App/MainTabView.swift` 未命中，确认 Stage 1 首页挂载路径未接入扫码、雷达、陌生社交残留入口。
- [ ] topic 卡片双列瀑布流：每个 topic 一张卡片，以双列瀑布流方式呈现，不混入其他卡片类型。
- [ ] topic shards 详情承接：点击任意 topic 后，能读取并展示对应 topic shards，并把 shards 写入本地存储。
- [ ] 咸虾本机验证通过：在 iPhone 15 Pro 上完成 topics 拉取、卡片浏览、进入 topic detail、分页读取 shards、离线回退缓存的主路径。

## 1.2 大师
- [x] 大师首页信息架构对齐：Stage 1 首页只保留大师目录页，不再优先承接最近聊过谁、会诊、导向行动等复杂能力。
- [x] 大师目录数据接入：大师目录能从预置角色资源和服务端目录中正确读取并建立索引，且当前已提供的整批资源必须全部进入目录。
- [x] 大师资源映射正确：字段固定取自 `./assets/char`，图片固定取自 `./assets/assets`，当前已提供的资源必须一一对应且不能错配；当前首批为 8 套。
- [x] 大师卡片双列瀑布流：每位大师一张卡片，以双列瀑布流方式浏览；当前首批 8 位必须全部显示，后续扩展到更多大师时要支持按批懒加载。
- [x] 大师目录只读约束：用户只能浏览和进入对话，不能在端侧新建、删除或编辑大师本体内容。
- [x] 大师详情承接正确：点击任意大师卡后，进入正确的一对一对话页面，而不是停留在静态详情样板。
- [x] 单大师对话能力：任意大师都能进行正常、连续、可发送可接收的一对一对话。
- [x] 大师对话 UI 对齐：对话页延续当前配色方案，聊天布局采用成熟对话结构的 iOS 原生版本，不退化成简陋调试页。
- [x] 对话密钥与服务安全边界：对话所需密钥与敏感配置只在本机安全读取，不进入客户端页面配置或版本化文档。
- [ ] 大师本机验证通过：在 iPhone 15 Pro 上完成当前已提供大师批次的目录浏览、卡片正确展示、进入任意大师、发送多轮消息、得到稳定回复、退出再进入继续聊天的主路径；当前首批为 8 位。

验证日期：2026-03-28
验证设备：macOS masters slice 校验 + `Stage1 iPhone 15 Pro` 模拟器
入口路径：`MasterHomeView` 目录页 -> `.navigationDestination(isPresented: conversationDestinationBinding)` 一对一对话页
验证结果：执行 `xcrun --sdk macosx swiftc -typecheck spare-life-ios-app/App/DesignSystem/PlatformCompat.swift spare-life-ios-app/App/DesignSystem/DesignTokens.swift spare-life-ios-app/App/DesignSystem/WaterfallLayout.swift spare-life-ios-app/Features/Shared/FeedCardProtocol.swift spare-life-ios-app/Features/Shared/UnifiedWaterfallFeed.swift spare-life-ios-app/Features/Masters/MasterConversationService.swift spare-life-ios-app/Features/Masters/MasterLocalStateStore.swift spare-life-ios-app/Features/Masters/MasterExperienceStore.swift spare-life-ios-app/Features/Masters/MasterHomeView.swift spare-life-ios-preview-host/App/MastersPreviewRootView.swift` 通过；`ruby spare-life-ios-preview-host/generate_masters_xcodeproj.rb` 生成独立 `SpareLifeMastersPreviewHost.xcodeproj`，随后 `xcodebuild -project spare-life-ios-preview-host/SpareLifeMastersPreviewHost.xcodeproj -scheme SpareLifeMastersPreviewHost -destination 'platform=iOS Simulator,id=63DAFAF1-789A-4206-8B3C-6B87048AFDF1' build` 通过；`xcrun simctl launch` 驱动 `directory_snapshot` 自动化返回 `visibleMasterCount=8`，确认当前首批 8 位大师全部进入目录；同一独立 host 下抓取的 `masters-conversation.png` 与 `masters-resume.png` 显示对话页已改为紧凑抬头 + 直接消息流 + 底部输入区的原生聊天结构，模式/记忆控制移入辅助层，不再是堆叠调试卡片；`seed_chat` 与 `resume_chat` 自动化均返回 `success=true`，确认退出再进入后 transcript 能继续承接并再次发送一轮追问。
残留问题：`Stage1 iPhone 15 Pro` 模拟器上的 live remote 路径仍未通过，最新 `seed_chat` 自动化返回 `serviceMode=localFallback`，`serviceDetail='实时大师服务这轮不可用，已回退到本地故事与记忆引擎继续回复。原因：大师服务请求失败，状态码 403。 Request not allowed'`；因此本批次只勾选“大师对话 UI 对齐”，继续保留“大师本机验证通过”为未完成。
