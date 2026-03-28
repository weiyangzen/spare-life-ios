# Stage1.1-1.2 Todos

Authoritative source: `/Users/wangweiyang/GitHub/spare-life-ios/Docs/Stage_1_Blueprint.md`

This file is a working snapshot for Stage 1 Xianxia + Masters only.
Checkmarks must be backfilled from real implementation and local validation.

Progress: 闲人 6/6, 闲聊 10/10

## 1.1 闲人
- [x] 闲人首页信息架构对齐：Stage 1 首页只保留 topic feed，不再承接扫码、雷达、陌生社交等其他能力。
- [x] topics 数据接入：页面能从统一 topic 数据源读取 topics，并形成可持续分页的 feed。
- [x] topics 本地存储：topics 数据能落到设备本地，并在重进页面或失败场景下复用。

验证记录（2026-03-28）：
`swift build --package-path spare-life-ios-app` 通过；`swift test --package-path spare-life-ios-app --filter XianxiaTopicRepositoryTests` 10/10 通过，新增覆盖 iPhone 宽度双列 `WaterfallColumns` 与 `vm.open(topic)` 详情承接状态，并继续覆盖 topics 分页合并、跨实例复用持久化 topics、刷新失败回退缓存，以及 shards 缓存回退与分页 upsert；`curl -i --max-time 10 'http://100.82.60.69:17880/v1/clawdb-topics/topics?batchSize=2&tenantId=default'` 返回 `HTTP/1.1 200 OK`，首批 `2` 条 topic、`nextCursor="2"`；同接口 `cursor=2` 二页探针返回 `ok=True`、`count=2`、`nextCursor='4'`；`curl -sS --max-time 15 'http://100.82.60.69:17880/v1/clawdb-topics/topics/group%3Aoc_01e791aeef5b12259676e529a770a2e6%3A%3Ageptopic-000001/shards?batchSize=2&tenantId=default'` 返回 `ok=true`、`count=2`、`nextCursor=null`，确认 live shard detail 数据可读；`rg -n "WaterfallLayout|TopicFeedCardView|ForEach\\(vm\\.topics\\)|vm\\.open\\(|navigationDestination|SceneTopicView" spare-life-ios-app/Features/Xianxia/XianxiaHomeView.swift` 命中 feed 仅以 `TopicFeedCardView` 进入 `WaterfallLayout`，并由 `vm.open(topic)` 承接到 `SceneTopicView`；`xcodebuild -project spare-life-ios-preview-host/SpareLifePreviewHost.xcodeproj -scheme SpareLifePreviewHost -destination 'platform=iOS Simulator,id=63DAFAF1-789A-4206-8B3C-6B87048AFDF1' build` 通过，随后 `xcrun simctl get_app_container 63DAFAF1-789A-4206-8B3C-6B87048AFDF1 com.wangweiyang.sparelife.previewhost data` + `find "$APP_DATA/Library/Application Support/SpareLife/XianxiaTopics" -maxdepth 1 -type f` 返回 `xianxia-fc9253545836f48d.json`，确认 `Stage1 iPhone 15 Pro` 模拟器首屏运行后已写入本地 topics 缓存；`rg -n "QRScanView|SceneAvatarRadarView|SceneSocialIntentView|SceneClusterOverviewView|SceneSummaryCardView|HotTakeCardView|AvatarRadarCardView|SceneSocialPromptCardView" spare-life-ios-app/Features/Xianxia/XianxiaHomeView.swift spare-life-ios-app/App/MainTabView.swift` 未命中，确认 Stage 1 首页挂载路径未接入扫码、雷达、陌生社交残留入口。
- [x] topic 卡片双列瀑布流：每个 topic 一张卡片，以双列瀑布流方式呈现，不混入其他卡片类型。
- [x] topic shards 详情承接：点击任意 topic 后，能读取并展示对应 topic shards，并把 shards 写入本地存储。
- [x] 闲人本机验证通过：在 iPhone 15 Pro 上完成 topics 拉取、卡片浏览、进入 topic detail、分页读取 shards、离线回退缓存的主路径。

补充验证记录（2026-03-28）：
`swift test --package-path spare-life-ios-app --filter XianxiaTopicRepositoryTests` 11/11 通过，新增覆盖 `XianxiaTopicAPIConfiguration` 对 feed/shard batch size 覆盖值的读取；`xcodebuild -project spare-life-ios-preview-host/SpareLifePreviewHost.xcodeproj -scheme SpareLifePreviewHost -destination 'platform=iOS Simulator,id=63DAFAF1-789A-4206-8B3C-6B87048AFDF1' build` 通过；本机启动 `node spare-life-ios-preview-host/Scripts/xianxia_clawdb_proxy.mjs` 作为 `127.0.0.1:17881 -> 100.82.60.69:17880` 的验证代理后，`xcodebuild -project spare-life-ios-preview-host/SpareLifePreviewHost.xcodeproj -scheme SpareLifePreviewHost -destination 'platform=iOS Simulator,id=63DAFAF1-789A-4206-8B3C-6B87048AFDF1' -only-testing:SpareLifePreviewHostUITests/XianxiaStage1UITests/testStage1TopicFeedDetailPaginationAndOfflineFallbackOnIPhone15Pro test` 在 `Stage1 iPhone 15 Pro` 模拟器 1/1 通过，真实走通首页 topics 拉取、点击首张 topic 进入 detail、以 `XIANXIA_TOPICS_SHARD_BATCH_SIZE=1` 触发 shards 分页读取、切换代理到 offline 后重启并再次进入 detail 的离线缓存回退；随后 `xcrun simctl get_app_container 63DAFAF1-789A-4206-8B3C-6B87048AFDF1 com.wangweiyang.sparelife.previewhost data` + Python 解析确认 `SpareLife/XianxiaTopics` 下 `xianxia-87146ea68a34554b.json` 为 topics 缓存 `items=24 nextCursor=24`，`xianxia-209ea2869f332ec7.json` 为已打开 topic 的 shards 缓存 `items=2 nextCursor=None`，与 UI 测试主路径一致。
## 1.2 闲聊
- [x] 闲聊首页信息架构对齐：Stage 1 首页只保留大师目录页，不再优先承接最近聊过谁、会诊、导向行动等复杂能力。
- [x] 闲聊目录数据接入：大师目录能从预置角色资源和服务端目录中正确读取并建立索引，且当前已提供的整批资源必须全部进入目录。
- [x] 闲聊资源映射正确：字段固定取自 `./assets/char`，图片固定取自 `./assets/assets`，当前已提供的资源必须一一对应且不能错配；当前首批为 8 套。
- [x] 闲聊卡片双列瀑布流：每位大师一张卡片，以双列瀑布流方式浏览；当前首批 8 位必须全部显示，后续扩展到更多大师时要支持按批懒加载。
- [x] 闲聊目录只读约束：用户只能浏览和进入对话，不能在端侧新建、删除或编辑大师本体内容。
- [x] 闲聊详情承接正确：点击任意大师卡后，进入正确的一对一对话页面，而不是停留在静态详情样板。
- [x] 单大师对话能力：任意大师都能进行正常、连续、可发送可接收的一对一对话。
- [x] 闲聊对话 UI 对齐：对话页延续当前配色方案，聊天布局采用成熟对话结构的 iOS 原生版本，不退化成简陋调试页。
- [x] 对话密钥与服务安全边界：对话所需密钥与敏感配置只在本机安全读取，不进入客户端页面配置或版本化文档。
- [x] 闲聊本机验证通过：在 iPhone 15 Pro 上完成当前已提供大师批次的目录浏览、卡片正确展示、进入任意大师、发送多轮消息、得到稳定回复、退出再进入继续聊天的主路径；当前首批为 8 位。

验证日期：2026-03-28
验证设备：macOS masters slice 校验 + `Stage1 iPhone 15 Pro` 模拟器
入口路径：`Stage1MastersPreviewRootView` 大师目录页 -> `MasterHomeView` 双列卡片 -> `.navigationDestination(isPresented: conversationDestinationBinding)` 一对一对话页
验证结果：执行 `xcrun --sdk macosx swiftc -typecheck spare-life-ios-app/App/DesignSystem/PlatformCompat.swift spare-life-ios-app/App/DesignSystem/DesignTokens.swift spare-life-ios-app/App/DesignSystem/WaterfallLayout.swift spare-life-ios-app/Features/Shared/FeedCardProtocol.swift spare-life-ios-app/Features/Shared/UnifiedWaterfallFeed.swift spare-life-ios-app/Features/Masters/MasterConversationService.swift spare-life-ios-app/Features/Masters/MasterLocalStateStore.swift spare-life-ios-app/Features/Masters/MasterExperienceStore.swift spare-life-ios-app/Features/Masters/MasterStage1Automation.swift spare-life-ios-app/Features/Masters/MasterHomeView.swift spare-life-ios-preview-host/App/Stage1MastersPreviewRootView.swift spare-life-ios-preview-host/App/Stage1MastersPreviewHostApp.swift` 通过；`ruby spare-life-ios-preview-host/generate_stage1_masters_xcodeproj.rb` 生成隔离的 `SpareLifeStage1MastersPreviewHost.xcodeproj`，随后 `xcodebuild -project spare-life-ios-preview-host/SpareLifeStage1MastersPreviewHost.xcodeproj -scheme SpareLifeStage1MastersPreviewHost -destination 'platform=iOS Simulator,id=63DAFAF1-789A-4206-8B3C-6B87048AFDF1' build` 通过；`xcrun simctl launch` 驱动 `directory_snapshot` 自动化返回 `success=true`、`visibleMasterCount=8`、`matchedCoverageCount=8`、`hasExactStage1Coverage=true`，确认当前首批 8 位大师全部进入目录且字段/图片映射完整；同一台 `Stage1 iPhone 15 Pro` 模拟器上，`seed_chat` 自动化返回 `success=true`、`serviceMode=liveRemote`、`serviceTitle='实时对话已接通'`、`transcriptCount=5`，确认进入任意大师后已完成多轮发送并得到稳定远端回复；随后 `resume_chat` 自动化返回 `success=true`、`serviceMode=liveRemote`、`resumedTranscriptCount=5`、`transcriptCount=7`，确认退出再进入后 transcript 继续承接并再次完成一轮追问；额外执行 `xcrun simctl io 63DAFAF1-789A-4206-8B3C-6B87048AFDF1 screenshot /tmp/spare-life-masters-validation/masters-directory.png` 与 `.../masters-resume.png`，补充留存目录卡片与恢复聊天页的 iPhone 15 Pro 本机画面。
残留问题：共享 `SpareLifePreviewHost.xcodeproj` 当前被与 masters 无关的 Xianxia 冲突标记阻塞，因此本次改用隔离的 masters-only preview host 完成验证；大师目录与对话主路径本身已通过，不影响本项勾选。
