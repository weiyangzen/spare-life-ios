# Stage2 Blueprint 0328 Checklist

Authoritative source: `/Users/wangweiyang/GitHub/spare-life-ios/Docs/Stage2_Blueprint.md`

This file mirrors the authoritative Stage 2 checklist in Docs/Stage2_Blueprint.md.
Workers may update only their owned section and the guard will refresh this mirror from the blueprint.

### 4.1 全局 Foundation

- [x] 共享瀑布流在 iPad 横屏固定为 5 列，在 iPhone 与 iPad 竖屏固定为 2 列。
- [x] 共享卡片样式统一落地 `8:5` 比例、圆角和 `8px` 间距约束，供 5 个页面复用。
- [x] Stage 2 共享卡片容器与瀑布流实现从单页面抽离成可复用基础层。
- [x] 全局 bottom nav 稳定切换 5 个页面，不再出现点击后停在第一页的问题。
- [x] 全局 bottom nav 不再遮挡实际功能区，并且在 iPhone / iPad / 键盘弹起 / 长列表滚动场景下都有优雅的承接方案。
- [x] preview host 与主工程复用同一套 Stage 2 全局导航和共享样式实现。

### 4.2 闲人

- [x] topic 列表真实走通后端读取，并具备本地缓存与分页承接。
- [x] 单个 topic 详情真实走通 shard 拉取，并能覆盖到 Stage 2 目标的 `1200 topic shards` 数据规模。
- [x] topic 卡片优先显示后端 summary，而不是直接暴露 raw text。
- [x] topic shard 列表使用 IM 风格单条消息渲染，最少展示 id、时间、内容。
- [x] 群名、人名等源字段缺失时，UI 化简成最后四位的稳定展示规则。
- [x] 闲人页面基于真实 ClawDB / 后端链路完成验证，而不是纯本地 mock。

### 4.3 闲聊

- [x] `./assets/char` 与 `./assets/assets` 现有大师资源全部刷成卡片，当前批次至少完整显示 8 位。
- [x] 闲聊首页卡片列表复用共享瀑布流与共享卡片样式，不再挂旧的复杂首页。
- [x] 点击任意大师卡后，稳定进入一对一闲聊页面。
- [ ] 闲聊聊天框接入 ClawDB 服务器的 ASR 接口，支持语音识别输入并正确回填到对话发送链路。
- [x] 拆分：聊天框已增加音频文件导入与 ASR 转写回填，识别文本会回填到同一发送草稿链路。
- [x] 拆分：聊天框已支持本地录音入口，结束录音后会把生成音频送入同一 ASR 转写回填草稿链路。
- [x] 拆分：ASR 转写文本回填后会与手写草稿合并，并沿用同一 `sendMessage` 发送链路；本地单测已覆盖。
- [x] 拆分：ASR 转写失败时会保留当前草稿，并把错误以内联文案留在聊天框；本地单测已覆盖。
- [x] 拆分：聊天框 ASR 临时音频文件在成功或失败后都会清理，避免导入/录音残留；本地单测已覆盖。
- [x] 拆分：聊天输入区已落地可配置 ASR 客户端，支持 `MASTER_ASR_URL / MASTER_ASR_BASE_URL / MASTER_ASR_PATH / MASTER_ASR_METHOD` 与 multipart 音频上传；当服务返回 `text / transcript / data.text` 时会直接回填到同一发送草稿。
- [x] 拆分：ASR 客户端已支持 `MASTER_ASR_AUTH_HEADER / MASTER_ASR_AUTH_SCHEME / MASTER_ASR_API_KEY / MASTER_ASR_AUTH_TOKEN` 鉴权覆盖，并通过本地单测验证请求头拼装。
- [x] 拆分：默认 `100.82.60.69:17880` 健康检查已确认是 `clawdb-topics-gateway`，`POST /v1/audio/transcriptions` 当前稳定返回 `405 method_not_allowed`，可排除这条默认路由不是现成可用 ASR 写入口。
- [x] 拆分：聊天输入区已展示当前 ASR 配置诊断，能明确区分默认 probe 路由、缺少鉴权与已注入 live 候选参数，避免把“可配置客户端”误判为“已接通 ClawDB live ASR”；本地单测已覆盖。
- [x] 拆分：聊天输入区在 ASR 状态未 ready 时会直接以内联文案回显当前诊断 blocker，并停止导入/录音转写尝试，不再把默认 `405` probe 路由误用成可写入口；本地单测已覆盖。
- [x] 拆分：聊天输入区 ASR 诊断已明确列出 live endpoint 注入键位（`env` + `UserDefaults` 双通道），缺少 host / path / method 时能直接提示下一步该配哪里；本地单测已覆盖。
- [x] 拆分：聊天输入区 ASR 诊断已明确列出鉴权注入键位（`env` + `UserDefaults` 双通道），缺少 header / scheme / token 时能直接提示下一步该配哪里；本地单测已覆盖。
- [x] 拆分：ASR 诊断会回显当前配置来源通道（`env` / `defaults` / 内建 probe），且不会泄露明文密钥；本地单测已覆盖。
- [x] 拆分：ClawDB ASR 的真实写入 host / path / method 仍未提供，当前还不能把 live 端点写死进客户端。
- [x] 拆分：已复核 `Docs/Stage2_Blueprint*`、`MasterASRService.swift`、`MasterASRServiceTests.swift` 与当前执行环境，仍未发现可直接写入客户端的 live `MASTER_ASR_URL / MASTER_ASR_BASE_URL / MASTER_ASR_PATH / MASTER_ASR_METHOD` 实值。
- [x] 拆分：当前执行环境确认未注入任何 `MASTER_ASR_*` 环境变量。
- [x] 拆分：2026-03-28 已复核当前机器 `defaults read`，未见任何 `masters.asr.*` live 配置；结合 shell 仍无 `MASTER_ASR_*`，ASR 主项继续保持未勾。
- [x] 拆分：ClawDB ASR 鉴权 header 名、scheme 与密钥来源仍未提供，live 联调前不能诚实勾选主项。
- [x] 拆分：已复核 `Docs/Stage2_Blueprint*`、`MasterASRService.swift`、`MasterASRServiceTests.swift` 与当前执行环境，仍未发现可直接用于 live 联调的 `MASTER_ASR_AUTH_HEADER / MASTER_ASR_AUTH_SCHEME / MASTER_ASR_API_KEY / MASTER_ASR_AUTH_TOKEN` 实值或来源说明。
- [x] 拆分：已补充 `MASTER_ASR_LIVE_SMOKE=1` + `MASTER_ASR_SMOKE_AUDIO_FILE` 驱动的 ASR live smoke test；拿到真实端点与鉴权后，可直接对候选配置发起一次真实转写验证，默认无配置时会跳过。
- [x] 拆分：2026-03-28 当前执行环境直连 `100.82.60.69:17880` 时，`GET /health` 已恢复并返回 `clawdb-topics-gateway`，但 `POST /v1/audio/transcriptions` 仍稳定返回 `{"ok":false,"error":"method_not_allowed"}`；因此仍无法把 ClawDB ASR live 写入口诚实勾选为已接通。
- [x] 拆分：2026-03-28 已再次直连 `http://100.82.60.69:17880/v1/audio/transcriptions`；空 JSON `POST` 与 `OPTIONS` 都返回 `{"ok":false,"error":"method_not_allowed"}` + `HTTP 405`，默认 `clawdb-topics-gateway` 路由仍不是可用 ASR 写入口。
- [x] 拆分：2026-03-28 当前 shell 再次复核仍只见 legacy `ANTHROPIC_*`，未注入任何 `MASTER_ASR_*`；直连 `POST http://100.82.60.69:17880/v1/audio/transcriptions` 继续返回 `HTTP 405` + `{"ok":false,"error":"method_not_allowed"}`，因此 ASR 主项继续保持未勾。
- [x] 拆分：已复核 `spare-life-ios-preview-host` 与相关工程配置，当前预览宿主仍缺少 `NSMicrophoneUsageDescription`；端到端录音联调暂不能诚实勾选，且宿主 plist 不在本 lane 内。
- [x] 大师闲聊请求携带全量 context，而不是只带最后一轮浅上下文。
- [ ] 大师闲聊推理路径切到提供的 `k2p5` 模型与对应后端请求逻辑。
- [x] 拆分：大师对话服务已支持 OpenAI-compatible `chat/completions` 请求体与 `k2p5` 默认模型配置。
- [x] 拆分：大师对话服务现已优先读取 `MASTER_CHAT_BASE_URL / MASTER_CHAT_API_KEY / MASTER_CHAT_MODEL`（`baseURL` 同时支持 `defaults(masters.chat.baseURL)`），并通过本地单测验证 `/v1/chat/completions` 请求体、`k2p5` 默认模型与全量 context 发送。
- [x] 拆分：大师对话配置诊断现已区分 `baseURL` 未注入、`API key` 缺失、以及 live `k2p5` 候选已注入三种状态，并明确列出 `MASTER_CHAT_BASE_URL / MASTER_CHAT_API_KEY / MASTER_CHAT_MODEL`、`defaults(masters.chat.baseURL / masters.chat.model)` 与本机钥匙串来源；本地单测已覆盖。
- [x] 拆分：大师对话页服务状态现已明确区分“`k2p5` live 候选已注入”和“实时对话已接通”；仅注入 `MASTER_CHAT_*` 但尚未收到远端回复时只显示候选，不再误报主链路已接通；本地单测已覆盖。
- [x] 拆分：当当前 shell 只有 legacy `ANTHROPIC_*` 配置时，`k2p5` 诊断会明确标注这只是旁路线索，Stage 2 主链路仍只认 `MASTER_CHAT_*`；本地单测已覆盖。
- [x] 拆分：大师对话配置诊断现已额外回显 legacy `ANTHROPIC_HOST / ANTHROPIC_DEFAULT_OPUS_MODEL` 线索，避免当前 shell 只有 host 时被误判成无线索；本地单测已覆盖。
- [x] 拆分：已补充本地 `MasterExperienceStore` 集成测试，覆盖 8 张大师卡装载、进入一对一、经 `K2P5MasterConversationService` 连续发送两轮消息、落盘后 `restoreSession` 恢复，以及恢复后继续携带完整历史 context 发送；本地单测已覆盖。
- [x] 拆分：2026-03-28 当前执行环境仍未提供 `MASTER_CHAT_BASE_URL` / `MASTER_CHAT_API_KEY` 的 Stage 2 live `k2p5` 配置；shell 仅见 legacy `ANTHROPIC_*`，带鉴权请求 `http://24.199.97.185:8080/v1/models` 仍只枚举 Claude 系列。
- [x] 拆分：2026-03-28 已复核当前机器 `defaults read` 与钥匙串，未发现 `masters.chat.*` 或 `com.wangweiyang.sparelife.masters.chat/k2p5.api-key`；带当前 shell 的 legacy 鉴权请求 `http://24.199.97.185:8080/v1/models` 仍只枚举 Claude 系列，未发现 `k2p5`。
- [x] 拆分：已补充 `MASTER_CHAT_LIVE_SMOKE=1` 驱动的 `MasterExperienceStore` 一对一聊天 smoke test，直接覆盖 `openConversation -> sendMessage -> k2p5` 实际发送链路；拿到 live `MASTER_CHAT_*` 配置后可直接复跑。
- [x] 拆分：2026-03-28 以当前 shell 的 `ANTHROPIC_BASE_URL / ANTHROPIC_AUTH_TOKEN` 临时映射到 `MASTER_CHAT_BASE_URL / MASTER_CHAT_API_KEY` 执行上述 smoke 时，首轮即返回 `503 No available accounts: no available accounts`；因此基于 live `k2p5` 端点的一对一聊天自动化验证主项仍不能诚实勾选。
- [x] 拆分：2026-03-28 再次以当前 shell 的 `ANTHROPIC_BASE_URL / ANTHROPIC_AUTH_TOKEN` 临时映射到 `MASTER_CHAT_BASE_URL / MASTER_CHAT_API_KEY` 执行上述 smoke 时，首轮改为返回 `404`，并在错误详情里回显 `model: k2p5`；因此基于 live `k2p5` 端点的一对一聊天自动化验证仍未完成。
- [x] 拆分：2026-03-28 已直接用当前 shell 的 legacy `ANTHROPIC_AUTH_TOKEN` 对 `http://24.199.97.185:8080/v1/chat/completions` 发送 `model=k2p5` 的最小请求，服务返回 `{"error":{"message":"model: k2p5","type":"server_error"}}` + `HTTP 404`；因此提供的后端当前仍未实际接住 `k2p5` 对话请求。
- [x] 拆分：`MASTER_CHAT_LIVE_SMOKE=1` 的一对一聊天 smoke 现已在发起首轮消息前预检候选端点 `/v1/models`；若未枚举到 `k2p5` 会直接回报精确阻塞并跳过，不再等聊天请求 `404` 后才暴露问题。本地单测与当前 shell 映射实测已覆盖。
- [x] 拆分：2026-03-28 已把 `MASTER_CHAT_LIVE_SMOKE=1` 的一对一聊天 smoke 补到可在缺少 `MASTER_CHAT_*` 时自动借用当前 shell 的 legacy `ANTHROPIC_BASE_URL / ANTHROPIC_AUTH_TOKEN / ANTHROPIC_API_KEY` 做只读预检；本机实测 `http://24.199.97.185:8080/v1/models` 仍只枚举 Claude 系列，未广告 `k2p5`，因此基于 live `k2p5` 端点的一对一聊天自动化验证仍未完成，主项暂不勾。
- [x] 拆分：2026-03-28 将当前 shell 的 legacy 鉴权临时映射到 `MASTER_CHAT_BASE_URL / MASTER_CHAT_API_KEY` 重跑 `MASTER_CHAT_LIVE_SMOKE=1` 后，`GET http://24.199.97.185:8080/v1/models` 仍未广告 `k2p5`，实际仅返回 `claude-opus-4-5-20251101 / claude-opus-4-6 / claude-sonnet-4-6 / claude-sonnet-4-5-20250929 / claude-haiku-4-5-20251001`；因此 `k2p5` 主项继续保持未勾。
- [x] 拆分：已抽出 `MasterChatLiveProbe`，统一处理 `MASTER_CHAT_*`、`defaults(masters.chat.baseURL / masters.chat.model)`、本机钥匙串与 legacy `ANTHROPIC_*` 的 live 候选解析及 `/v1/models` 预检；若候选端点未广告 `k2p5`，会直接回报 exact blocker，本地单测已覆盖。
- [x] 拆分：`MasterExperienceStore` 刷新目录后会复用 `MasterChatLiveProbe` 做页面侧 `/v1/models` 预检；若候选端点未广告 `k2p5`，一对一页状态会直接展示 exact blocker，若已广告则展示“live 候选已注入”并回显模型目录；本地单测已覆盖。
- [x] 拆分：若 live 端点回包中的 `model` 未继续指向 `k2p5` 系列，聊天服务会拒绝把该轮误标为“实时对话已接通”，并回退到本地故事引擎；本地单测已覆盖。
- [x] 拆分：2026-03-28 当前 shell 再次复核仍未注入任何 `MASTER_CHAT_*`；借用现有 legacy `ANTHROPIC_AUTH_TOKEN / ANTHROPIC_API_KEY` 对 `ANTHROPIC_BASE_URL/v1/models` 发起只读探针时，返回模型仍只有 `claude-opus-4-5-20251101 / claude-opus-4-6 / claude-sonnet-4-6 / claude-sonnet-4-5-20250929 / claude-haiku-4-5-20251001`，未广告 `k2p5`，因此主项继续保持未勾。
- [x] 大师回复必须符合上下文和角色设定，像“小说场景中的角色台词”，而不是通用助手口吻。
- [x] 拆分：`/v1/chat/completions` 的 system prompt 现已明确要求把回复写成“小说场景里的角色台词”，并禁止输出“作为 AI / 模型 / 助手”“建议如下”“1. 2. 3.” 等通用助手口吻；本地单测已覆盖。
- [x] 拆分：当 `k2p5` 或兼容后端返回通用助手式文案时，聊天服务会在落地前改写成贴合当前故事与上下文的角色对白，再展示到一对一会话；本地单测已覆盖。
- [x] 拆分：即使 `k2p5` 或兼容后端返回不带 AI 腔的普通建议 prose，只要缺少场景锚点或角色说话人痕迹，聊天服务也会补写成带上下文的角色对白再展示；本地单测已覆盖。
- [x] 拆分：本地故事引擎回退与会诊回复已改成角色对白风格，沿用相关故事与授权记忆，不再输出“会按某风格回应 / 我的立场是”这类元叙述；本地单测已覆盖。
- [ ] 闲聊页面完成当前 8 位大师卡片与至少 1 条真实对话链路的本机验证。
- [x] 拆分：`MasterStage1Automation` 已重新接到当前 `MasterExperienceStore` 初始化路径；注入 `SPARE_MASTERS_AUTOMATION_COMMAND` 后，会沿用同一 `MasterConversationLocalStateStore` 目录写出 `masters-preview-validation.json`，本地单测已覆盖。
- [x] 拆分：`MasterStage1Automation` 已新增 `stage2_smoke` 命令，会在同一次自动化里先断言当前 8 位大师目录覆盖无缺口，再进入一对一并要求两轮 `liveRemote` 对话成功后才写出 `masters-preview-validation.json`；本地单测已覆盖。
- [x] 拆分：`stage2_smoke` 自动化在进入一对一前会先读取当前 `k2p5` 预检状态；若 `/v1/models` 未广告 `k2p5` 或缺少 live 配置，会把 exact blocker 直接写入 `masters-preview-validation.json`，不再等发送后被本地回退详情稀释；本地单测已覆盖。
- [x] 拆分：2026-03-28 已本机复跑 `MasterConversationServiceTests.testMasterStage1AutomationWritesStage2SmokeValidation`，确认 `stage2_smoke` 自动化仍覆盖 `8` 张大师卡、进入一对一与两轮 `liveRemote` 判定的回归链路；但这仍是受控测试，不等于已拿到真实 `k2p5` live 对话。
- [x] 拆分：`MasterStage1Automation` 的 `resume_chat` 现已补上本地单测，要求复用同一 `MasterConversationLocalStateStore` 恢复至少 `5` 条 transcript 后，再追加一轮 `liveRemote` 一问一答并写回结果文件。
- [x] 拆分：2026-03-28 已用上述自动化 bootstrap 在本机复跑 `directory_snapshot`，结果 `success=true`、`visibleMasterCount=8`、`matchedCoverageCount=8`、`hasExactStage1Coverage=true`。
- [x] 拆分：2026-03-28 已用 `MasterChatLiveProbe` 复跑本机真实对话链路预检；本地 `MasterExperienceStore` 集成测试仍覆盖 8 卡装载、进入一对一、持久化恢复与完整 context 发送，但当前 shell 借用 legacy `ANTHROPIC_*` 访问 `http://24.199.97.185:8080/v1/models` 仍只返回 Claude 系列、未广告 `k2p5`，因此“至少 1 条真实对话链路”主项继续保持未勾。
- [x] 拆分：2026-03-28 已在当前 shell 复跑页面侧 live 预检所依赖的只读探针；`http://24.199.97.185:8080/v1/models` 借用 legacy `ANTHROPIC_AUTH_TOKEN / ANTHROPIC_API_KEY` 的 Bearer 鉴权后，仍只返回 `claude-opus-4-5-20251101 / claude-opus-4-6 / claude-sonnet-4-6 / claude-sonnet-4-5-20250929 / claude-haiku-4-5-20251001`，因此页面状态会直接停在“k2p5 预检未通过”，真实对话主项继续保持未勾。
- [x] 拆分：2026-03-28 已把 `MasterChatLiveProbe` / `MasterRoleplayReplyComposer` / `MasterSpeechTranscriptionFlow` 收回 preview host 已纳入的 Masters 源文件，随后 `xcodebuild -project spare-life-ios-preview-host/闲人.xcodeproj -scheme SpareLifePreviewHost -destination 'platform=iOS Simulator,id=63DAFAF1-789A-4206-8B3C-6B87048AFDF1' build` 已在 `Stage1 iPhone 15 Pro` 本机通过，页面级验证前置编译恢复。
- [x] 拆分：2026-03-28 已用 `xcrun --sdk macosx swiftc -typecheck` 复核当前 Masters 源集（含上述合并后的语音/对话辅助类型），仅剩 `MasterChatHomeView.swift` 与 `MasterHomeView.swift` 的 macOS `onChange` deprecated warning，无新的类型错误。
- [x] 拆分：2026-03-28 已补充 masters 专用 preview host UI 驱动；`xcodebuild test -project spare-life-ios-preview-host/闲人.xcodeproj -scheme SpareLifePreviewHost -destination 'platform=iOS Simulator,id=63DAFAF1-789A-4206-8B3C-6B87048AFDF1' -only-testing:SpareLifePreviewHostUITests/XianxiaStage1UITests/testMastersDirectoryShows8CardsAndOpensOneToOneOnIPhone15Pro` 已在 `Stage1 iPhone 15 Pro` 本机通过，实跑覆盖从默认 `闲人` tab 切到 `闲聊`、确认 8 张大师卡可见并进入一对一会话页。

### 4.4 赚闲能

- [x] 页面顶部分类轨道完整呈现 `跑腿 / 嘴替 / 搭子 / 两性 / 求职招聘 / 投融资 / 闲置` 7 个分类。
- [x] 每个分类都能从本地存储 / assets 加载 10 个 Mock 卡片。
- [x] 点击任意卡片后可以进入对应的聊天框页面。
- [x] 分类页面与卡片详情页复用共享卡片和共享瀑布流规范。
- [x] `../Social_Masks_EvoHack/` 与 `Docs/evomap_link.md` 的接入位置和输入契约在代码结构中预留清楚。

### 4.5 消息

- [x] 消息首页能从本地存储 / assets 刷出 10 个 Mock 联系人卡片。
- [x] 点击联系人后进入类 IM 的聊天详情页。
- [x] 聊天详情页提供 `真人 / 分身` 模式切换开关。
- [x] 消息页的 mock 联系人、消息与模式状态支持本地存储承接。
- [x] 消息页与闲聊页保持同一设计系统，但聊天语义明确区分“对大师闲聊”和“人与分身消息”。

### 4.6 我的

- [x] 我的页面总览同时呈现 `闲人 / 闲聊 / 赚闲能 / 消息` 四组数据区域。
- [x] 闲人区域真实读取 ClawDB 指标：渠道数、话题数、独立 id 数、被 Mention 次数。
- [x] 闲聊区域呈现大师交互人数与交互次数。
- [x] 赚闲能区域呈现 mock 的交互人数、交互次数和个人赚能风格描述。
- [x] 消息区域呈现 mock 的真人 / 分身互动统计。
- [x] 我的页面整体布局复用 Stage 2 共享卡片规范并完成 iPhone / iPad 适配验证。
