# S3-05 大师实时对话状态机与证据格式研究

本研究只覆盖 `Masters` 实时对话路径的状态机与证据格式，不展开 `Xianxia` 分页、ASR readiness 细化或全仓 package 拆分。若旧文档与当前代码冲突，以当前代码和现有测试为准。

## 1. 当前代码现状

### 1.1 当前运行链路是多段拼装，不是一个统一的五段状态机

当前实时对话链路分散在四个位置：

- `spare-life-ios-app/Features/Masters/MasterConversationService.swift`
  - `MasterChatConfiguration.currentStatus()` 只根据 baseURL / model / apiKey 是否解析成功给出候选态或回退态。
- `spare-life-ios-app/Features/Masters/MasterExperienceStore.swift`
  - `refreshCatalog()` 先把 `conversationService.status` 写到 store，再调用 `refreshChatLiveDiagnosticsIfNeeded()` 跑页面侧 `/v1/models` 预检。
- `spare-life-ios-app/Features/Masters/MasterExperienceStore.swift`
  - `openConversation(for:)` / `restoreSession(_:)` 只是把 store 级 `conversationServiceStatus` 拷进会话草稿。
- `spare-life-ios-app/Features/Masters/MasterExperienceStore.swift`
  - `sendMessage(_:)` 里真正发出 `chat/completions` 请求；成功后升级成 live，失败后切到本地 fallback。

这意味着当前代码事实更接近“配置态 + 目录刷新预检 + 真实发送 + 回复改写”四段拼接，而不是 item 描述里的单一显式状态机。

### 1.2 当前核心状态结构只有三种 delivery mode，承载不了本 item 需要的五个节点

`MasterConversationServiceStatus` 当前只有：

- `deliveryMode`
  - `.liveRemote`
  - `.configuredCandidate`
  - `.localFallback`
- `tone`
  - `.success`
  - `.ready`
  - `.warning`
- `title / detail`
  - 以展示文案承载具体证据

它没有显式字段表达：

- 当前是否正处于 `catalog probe`
- 候选态是“只注入了 config”还是“已通过 `/v1/models` 预检”
- fallback 是配置缺失、鉴权失败、模型未广告、发送失败，还是回包模型漂移
- 当前回复是否经过 `roleplay rewrite`

所以当前结构能“说出结果”，但不能稳定表达“从哪一步走到这个结果”。

### 1.3 `catalog probe` 目前只是目录刷新副作用，不是第一类状态节点

`MasterExperienceStore.makeDefaultChatLiveStatusProbe()` 当前会：

1. 通过 `MasterChatLiveProbe.resolveCandidate()` 解析候选配置。
2. 把 `chat/completions` URL 映射成 `/v1/models` catalog URL。
3. 调 `MasterChatLiveProbe.ensureExpectedModelAdvertised(...)` 做只读预检。
4. 返回：
   - `.candidate(...)`，如果目录里广告了目标模型；
   - `.localFallback(...)`，如果目录未广告模型、鉴权失败或 transport 失败；
   - `nil`，如果连 baseURL / apiKey 都没有，表示这轮预检直接跳过。

问题在于：

- “预检跳过”没有独立状态。
- “预检进行过且成功”与“只有配置、未发预检”都可能落成 `.configuredCandidate`。
- 页面和自动化只能从 `detail` 长文本里猜这次到底有没有做过 catalog probe。

### 1.4 `live candidate` 当前把两类证据混成了一类

当前至少有两种候选态来源：

#### A. 只靠配置解析得出的候选态

`MasterChatConfigurationResolution.status` 在 baseURL + apiKey + model 解析成功后，会直接返回：

- `title = "k2p5 live 候选已注入"`
- `deliveryMode = .configuredCandidate`

这时还没有做网络预检。

#### B. 已跑过 `/v1/models` 预检后的候选态

`makeDefaultChatLiveStatusProbe()` 在模型目录广告目标模型后，也返回：

- `title = "k2p5 live 候选已注入"`
- `deliveryMode = .configuredCandidate`

这时其实已经拿到了更强证据：

- `catalogURL`
- `advertisedModels`
- `sourceSummary`

但两者仍共用同一个 delivery mode。也就是说，当前代码能在 `detail` 文本里写出差别，却没有 machine-readable 的差别。

### 1.5 `live connected` 当前定义是诚实的，但只在发送成功后才成立

`K2P5MasterConversationService.generateReply(for:)` 的 live 升级门槛是明确的：

1. `chat/completions` 返回 `2xx`
2. 能抽出非空文本
3. 回包里的 `model` 与目标 `k2p5` 签名一致
4. 回复经过 `MasterRoleplayReplyComposer.remoteReply(...)` 处理

只有满足这些条件，才会返回：

- `deliveryMode = .liveRemote`
- `title = "实时对话已接通"`

这是当前链路里最稳定也最诚实的一段。

### 1.6 `local fallback` 当前把多类 blocker 压成同一种出口

当前会落入 fallback 的原因至少有五类：

- `MASTER_CHAT_BASE_URL` 缺失或无效
- API key 缺失
- `/v1/models` 未广告 `k2p5`
- `/v1/models` 返回 `401 / 403`
- `chat/completions` 发送时 transport / status / returned model 失败

但现状里存在两层压平：

#### A. 预检失败时

`makeDefaultChatLiveStatusProbe()` 会把很多原因压成：

- `title = "k2p5 预检未通过"`，或
- `title = "k2p5 鉴权失效"`

#### B. 发送失败时

`MasterExperienceStore.sendMessage(_:)` catch 任何远端错误后，会统一生成：

- `MasterConversationServiceStatus.fallback(...)`
- `title = "当前使用本地故事引擎"`

也就是说，预检失败还能保留较精确的 blocker 标题，真正 send-time failure 却又退回到通用 fallback 标题。

### 1.7 `roleplay rewrite` 当前不是状态，而是隐式变换步骤

当前回复风格改写发生在两条路径：

- 远端成功回复：
  - `MasterRoleplayReplyComposer.remoteReply(from:for:)`
- 本地 fallback 回复：
  - `MasterRoleplayReplyComposer.fallbackReply(for:)`
  - 由 `MasterExperienceStore.composeReply(...)` 包一层 `MasterMessage`

但当前没有任何状态或证据字段说明：

- 远端原文是否被原样保留
- 是否做了角色化 rewrite
- rewrite 是 remote reply rewrite 还是 local fallback generation

因此 item 里的 `roleplay rewrite` 在代码里不是第一类状态节点，而是一个未显式记录的渲染步骤。

### 1.8 当前证据格式分裂在页面对象、自动化结果和长文本 detail 里

当前证据至少分三层：

#### A. 页面 / store 证据

`MasterConversationServiceStatus` 有：

- `providerName`
- `modelName`
- `credentialSource`
- `deliveryMode`
- `tone`
- `title`
- `detail`

#### B. 自动化结果证据

`MasterStage1Automation.Result` 只有：

- `serviceMode`
- `serviceTitle`
- `serviceDetail`

而且 `serviceMode` 目前通过：

```swift
currentServiceStatus.isLiveRemote ? "liveRemote" : "localFallback"
```

直接把 `configuredCandidate` 压成 `localFallback`。

#### C. UI 证据

`MasterConversationHeaderBar` 只看 `tone`：

- `.success` 显示绿色 `Online`
- 其他一律橙色 `Ready`

因此 `configuredCandidate` 和 `localFallback` 在头部徽标上会被压成同一视觉语义。

## 2. 当前文档偏差

### 2.1 `Stage2_Blueprint_0328_Checklist.md` 对自动化结果格式的描述已经落后于当前代码

旧文档里明确写了：

- `masters-preview-validation.json` 会保留 `configuredCandidate / liveRemote / localFallback` 三态；
- 还会写出 `serviceProvider / serviceModel / serviceCredentialSource / serviceTone / serviceRequestURL / serviceCatalogURL / serviceSourceSummary / serviceAdvertisedModels / serviceBlockerCode`。

但当前 `MasterStage1Automation.Result` 实际只有：

- `serviceMode`
- `serviceTitle`
- `serviceDetail`

并且 `serviceMode` 仍是二态压平。这里已经出现“文档 richer than code”的明确冲突，必须以代码为准。

### 2.2 旧文档把 send-time blocker 说得比当前代码更精细

旧文档声称：

- 若首轮真实发送返回 `404 model: k2p5` 或 transport 错误，页面与结果文件会保留 exact send-time blocker，而不是统一降成“当前使用本地故事引擎”。

但当前 `MasterExperienceStore.sendMessage(_:)` catch 块事实是：

- 一律 `MasterConversationServiceStatus.fallback(...)`
- 标题固定为 `"当前使用本地故事引擎"`

所以当前 send-time blocker 仍主要存在于 `detail` 文本中，没有升级成稳定的结构化状态。

### 2.3 `Stage_1_Blueprint.md` 的历史验证叙述不能再被当成当前运行真相

旧 Stage 1 文档包含：

- preview-host 上 `seed_chat` / `resume_chat` 返回 `serviceMode=liveRemote`
- 由此推断真实对话链路已接通

但 Stage 3 的解释顺序明确规定：

1. 先看当前代码
2. 再看 Stage 3 audit
3. 最后才是旧文档

当前代码里，live 是否真的接通，仍取决于外部 `MASTER_CHAT_*` / keychain / legacy 映射与远端模型目录。旧日志不能替代当前状态机和当前证据格式。

### 2.4 `Stage_3_Codebase_Audit.md` 判断方向对，但 item 粒度还不够细

Audit 已经说：

- masters 对 live candidate / live connected / local fallback 的区分相对诚实；
- store 内有诊断与回退逻辑。

这判断方向是对的，但对 S3-05 还不够：

- `catalog probe` 不是第一类状态；
- `roleplay rewrite` 没有显式证据；
- automation result 压平了候选态；
- UI 顶部徽标把 fallback 和 candidate 都压成 `Ready`。

所以“有区分”不等于“状态机和证据格式已经收敛”。

## 3. 稳定 SOTA 或成熟实践

对这类客户端实时对话链路，更成熟的做法通常不是把所有步骤塞进一个扁平文案状态，而是拆成“连接状态”和“回复生成路径”两条并行事实。

### 3.1 连接状态应显式、单调、可回放

更稳定的主状态机通常是：

```swift
enum MasterChatPhase {
    case catalogProbe
    case liveCandidate
    case liveConnected
    case localFallback
}
```

状态切换需要满足两个原则：

- 只在确实拿到更强证据时升级
- 每个节点都能追溯“为什么在这里”

### 3.2 预检证据不应只存在于长文本里

成熟实践通常会把预检证据结构化，而不是全塞在 `detail` 文案里。至少会有：

- `catalogURL`
- `requestURL`
- `sourceSummary`
- `advertisedModels`
- `blockerCode`
- `credentialSource`
- `validatedAt`

这样页面、自动化、日志和测试才能消费同一份事实，而不是各自解析自然语言。

### 3.3 “候选态”需要区分 config-only 与 probe-verified

对真实链路来说，下面两件事不是同一强度的证据：

- “我已经拿到 baseURL + apiKey”
- “我刚刚对 `/v1/models` 做过预检，且目标模型在目录里”

成熟做法通常会让候选态至少带一个 `origin` 或 `evidenceKind`：

- `configOnly`
- `catalogVerified`

否则候选态虽然诚实地不是 live，但仍然不够可追踪。

### 3.4 `roleplay rewrite` 更适合作为并行证据维度，而不是硬塞进连接状态

从工程上看，`roleplay rewrite` 不是“连接状态”，而是“回复输出路径”。更成熟的表达通常会拆成另一条并行维度：

```swift
enum MasterReplyRenderPath {
    case rawRemote
    case rewrittenRemote
    case localRoleplayFallback
}
```

这样既能满足 item 对 `roleplay rewrite` 的追踪要求，又不会把“网络连通性”与“台词改写策略”混成一类状态。

### 3.5 自动化和页面必须共用同一证据 envelope

成熟实践的关键不是文案更丰富，而是：

- 页面 header / hero card
- 自动化结果 JSON
- 单测断言
- 验证日志

都来自同一个结构体，而不是一个地方拼 `title/detail`，另一个地方再自己压平。

## 4. 面向本仓库的具体建议

### 4.1 把当前 `MasterConversationServiceStatus` 升级成“主状态 + 证据 + 输出路径”三层模型

更适合本仓库的收敛方式是：

```swift
enum MasterChatPhase: String, Codable {
    case catalogProbe
    case liveCandidate
    case liveConnected
    case localFallback
}

enum MasterReplyRenderPath: String, Codable {
    case rawRemote
    case rewrittenRemote
    case localRoleplayFallback
}

struct MasterChatEvidence: Codable {
    let requestURL: String?
    let catalogURL: String?
    let sourceSummary: String?
    let advertisedModels: [String]
    let blockerCode: String?
    let blockerDetail: String?
    let returnedModel: String?
    let credentialSource: String
    let validatedAt: String?
    let candidateOrigin: String?
}
```

然后在展示层保留当前 `title / detail` 作为文案，而不是让它们继续承担全部事实。

### 4.2 显式补出 `catalog probe` 节点，不再让它只是 `refreshCatalog()` 的副作用

建议把当前目录刷新里的 live 诊断拆成显式阶段：

1. `catalogProbe`
   - `candidateOrigin = configOnly` 或 `catalogVerified`
   - 记录 `catalogURL / advertisedModels / blockerCode`
2. `liveCandidate`
   - 仅表示“可以尝试发真实消息，但还未收到首条远端回复”
3. `liveConnected`
   - 只有真实回复完成后才能进入
4. `localFallback`
   - 记录 fallback reason

这样 `refreshCatalog()`、`openConversation()`、`sendMessage()` 就能围绕同一条主状态线工作。

### 4.3 保留 send-time exact blocker，不要再统一掉进通用 fallback 标题

当前 send-time failure 仍会被标题压成 `"当前使用本地故事引擎"`。更适合本仓库的做法是：

- preflight failure：
  - `blockerCode = model_not_advertised / auth_invalid / missing_config`
- send-time failure：
  - `blockerCode = send_transport_failed / send_invalid_status / returned_model_mismatch`
- fallback 只是 `phase`
- 具体原因放在 `blockerCode + blockerDetail`

这样本地故事引擎仍可继续兜底，但证据不会丢。

### 4.4 把 `roleplay rewrite` 从“隐式步骤”提成稳定证据

建议在每条 assistant reply 上额外记录：

- `renderPath`
  - `rewrittenRemote`
  - `localRoleplayFallback`
- `usedStories`
- `usedMemories`

这不是为了做产品功能，而是为了让验证能回答两个问题：

- 这条回复是远端真的说的，还是远端文案被二次改写过？
- 这条回复是本地故事引擎生成的，还是远端成功后的角色化润色？

### 4.5 把 `MasterStage1Automation.Result` 对齐到同一份状态证据

当前 automation 最大问题是把候选态压平了。建议把结果文件升级成：

- `servicePhase`
- `serviceTitle`
- `serviceDetail`
- `serviceEvidence`
  - `requestURL`
  - `catalogURL`
  - `advertisedModels`
  - `sourceSummary`
  - `blockerCode`
  - `returnedModel`
- `replyRenderPath`

只要页面、自动化、测试都消费这套结构，旧文档里那些“字段已经存在”的说法才能重新变成真话。

### 4.6 UI 头部状态也要从“tone 驱动”改成“phase 驱动”

当前头部把所有非 success 都显示成 `Ready`，这会把：

- 候选态
- 预检失败
- 发送失败后的 fallback

在视觉上压成一类。更合理的映射应该是：

- `catalogProbe` -> `Checking`
- `liveCandidate` -> `Candidate`
- `liveConnected` -> `Online`
- `localFallback` -> `Fallback`

即使 UI 文案保持中文卡片标题不变，徽标语义也应该跟 phase 对齐。

## 5. 实施顺序和风险

### 5.1 实施顺序

1. 先定义新的 phase / evidence / renderPath 结构体，用 adapter 把旧 `MasterConversationServiceStatus` 映射进去，不先改 UI。
2. 再把 `MasterChatConfiguration.currentStatus()`、`MasterChatLiveProbe`、`sendMessage(_:)` 改成统一产出 phase + evidence。
3. 把 `MasterStage1Automation.Result` 升级为结构化证据输出，并同步修正当前二态压平。
4. 最后再改 `MasterConversationHeaderBar` 等 UI，把视觉徽标从 `tone` 切到 `phase`。

### 5.2 主要风险

- 如果先改 UI、后改状态结构，很容易出现页面文案和自动化结果继续说两套话。
- 如果把 `roleplay rewrite` 硬塞进 transport phase，会让状态机语义变乱；它更适合作为并行证据维度。
- 如果结构化证据时直接写入原始 token / header 值，会造成敏感信息泄漏；只能记录来源与 redacted presence。
- `masters-preview-validation.json` 一旦换 schema，现有消费脚本与旧验证记录会有兼容性成本；需要版本字段或平滑迁移。

