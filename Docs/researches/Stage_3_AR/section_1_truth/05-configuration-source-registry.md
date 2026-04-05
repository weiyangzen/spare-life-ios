# S1-05 配置来源登记方式统一方案

结论先行：当前仓库已经存在多条真实配置解析链，但它们分散在 `Xianxia`、`Masters`、preview host、本地资源加载和 smoke automation 里，还没有被登记成一套统一规则。更关键的是，这个仓库并不存在一个对所有字段都成立的“单一总优先级”；真正稳定的做法是按字段类型登记解析链。以当前代码为准，可以先收敛成四类：`secret credential`、`endpoint / model / runtime flag`、`local assets`、`docs assumptions`。其中 `docs assumptions` 只能是人工说明，不能再被当成运行时配置源；如果旧文档和代码冲突，以代码为准。

## 1. 当前代码现状

### 1.1 仓库已经有多条真实配置链，但它们按模块各自演化

当前最值得登记的配置面至少有五条：

| 配置面 | 代码入口 | 当前字段类型 | 当前解析顺序 | 备注 |
| --- | --- | --- | --- | --- |
| `XianxiaTopicAPIConfiguration` | `spare-life-ios-app/Features/Xianxia/SceneTopicView.swift` | endpoint / tenant / batch size | `env(XIANXIA_*/CLAWDB_*) -> UserDefaults(xianxia.topic.* / clawdbTopics.*) -> built-in defaults` | 无 keychain，纯运行参数 |
| `MasterASRConfiguration` | `spare-life-ios-app/Features/Masters/MasterASRService.swift` | endpoint / method / auth header name / token / model / routing | `env(MASTER_ASR_*) -> UserDefaults(masters.asr.*) -> built-in defaults` | 状态文案会回显来源名，但不会泄露密钥值 |
| `MasterChatConfiguration.current()` | `spare-life-ios-app/Features/Masters/MasterConversationService.swift` | `baseURL / model / apiKey` | `apiKey: keychain -> env(MASTER_CHAT_* / MOONSHOT_*) -> UserDefaults(masters.chat.apiKey/authToken)`；`baseURL: env(MASTER_CHAT_* / MOONSHOT_*) -> UserDefaults(masters.chat.baseURL)`；`model: env(MASTER_CHAT_* / MOONSHOT_*) -> UserDefaults(masters.chat.model) -> fallback(k2p5)` | 运行态把 secret 和 endpoint 分成了不同优先级链 |
| `MasterChatLiveProbe.resolveCandidate()` | `spare-life-ios-app/Features/Masters/MasterConversationService.swift` | smoke / preflight 候选配置 | `stage env -> defaults/keychain -> legacy env(ANTHROPIC_*)` | 这是 probe 专用兼容链，不是主运行链 |
| `MasterCatalogLoader` / `MasterServiceDirectory` | `spare-life-ios-app/Features/Masters/MasterExperienceStore.swift` | local assets / manifest | `bundle resources -> repo asset roots / Support manifest` | 读的是本地资产，不是 env/defaults |

这五条链已经足够说明：仓库里的“配置来源”不是一件事，而是至少三种不同类别的输入。

### 1.2 `Xianxia` 运行时配置已经形成明确的 `env > defaults > built-in` 链

`XianxiaTopicAPIConfiguration.current()` 当前对四组字段执行的是同一套优先级：

1. `baseURL`
   `XIANXIA_TOPICS_BASE_URL` / `CLAWDB_TOPICS_BASE_URL`
   -> `xianxia.topic.baseURL` / `clawdbTopics.baseURL`
   -> 内建默认值 `http://100.82.60.69:17880/v1/clawdb-topics`
2. `tenantId`
   `XIANXIA_TOPICS_TENANT_ID` / `CLAWDB_TOPICS_TENANT_ID`
   -> `xianxia.topic.tenantId` / `clawdbTopics.tenantId`
   -> `"default"`
3. `feedBatchSize`
   env alias -> defaults alias -> `20`
4. `shardBatchSize`
   env alias -> defaults alias -> `20`

这条链说明两件事：

1. 当前 repo 已经把 `env` 当成最高优先级的运行时覆盖源。
2. `UserDefaults` 在 `Xianxia` 里承担的是“本机持久覆盖”，不是“秘密凭据存储”。

仓库还把解析结果继续写进了行为面：`XianxiaTopicRepository` 的缓存 scope 会把 `baseURL` 与 `tenantId` 拼进 cache file digest。这意味着 endpoint 与 tenant 不是纯诊断参数，而是缓存边界的一部分。

### 1.3 `Masters ASR` 也遵循 `env > defaults > built-in`，但它已经开始登记来源和暴露规则

`MasterASRConfiguration.resolved()` 当前的解析链和 `Xianxia` 接近，但它更完整：

1. endpoint 相关字段
   `MASTER_ASR_URL / MASTER_ASR_BASE_URL / MASTER_ASR_PATH / MASTER_ASR_METHOD`
   -> `masters.asr.url / baseURL / path / method`
   -> 内建默认值 `http://100.82.60.69:8020` + `/v1/asr/transcribe` + `POST`
2. auth 相关字段
   `MASTER_ASR_AUTH_HEADER / MASTER_ASR_AUTH_SCHEME / MASTER_ASR_API_KEY / MASTER_ASR_AUTH_TOKEN`
   -> `masters.asr.authHeader / authScheme / apiKey / authToken`
   -> 无
3. model / language / responseFormat / routingProfile
   `env -> defaults -> built-in or nil`

这条链比旧文档更可信的地方在于：

1. 当前代码内建默认端点是 `100.82.60.69:8020/v1/asr/transcribe`，不是旧文档反复记录的 `100.82.60.69:17880/v1/audio/transcriptions`。
2. `currentStatus()` 会回显 `endpoint=env(...)`、`baseURL=defaults(...)`、`auth=未注入` 这类来源摘要，但测试明确要求它不能把 `env-secret` 明文回显出来。

也就是说，ASR 这条链已经天然包含了“来源登记”和“暴露规则”的雏形。

### 1.4 `Masters chat` 运行态已经把 secret 和 endpoint 分成不同优先级链

`MasterChatConfiguration.current()` 是当前仓库里最复杂也最值得成为基线的一条链：

1. `apiKey`
   `keychain(com.wangweiyang.sparelife.masters.chat / k2p5.api-key)`
   -> `MASTER_CHAT_API_KEY` / `MOONSHOT_API_KEY`
   -> `masters.chat.apiKey` / `masters.chat.authToken`
   -> unavailable
2. `baseURL`
   `MASTER_CHAT_BASE_URL` / `MOONSHOT_BASE_URL`
   -> `masters.chat.baseURL`
   -> invalid / unavailable
3. `model`
   `MASTER_CHAT_MODEL` / `MOONSHOT_MODEL`
   -> `masters.chat.model`
   -> fallback(`k2p5`)

还要特别指出两条代码事实：

1. `current()` 在允许的情况下会把环境变量里的 API key 持久化到 keychain，下一次读取时优先走 keychain。
2. preview host 会在 `SpareLifePreviewHostApp` 里注册 `masters.chat.baseURL` 和 `masters.chat.model` 的 `UserDefaults` 默认值，所以 defaults 在这个 surface 上不只是测试辅助，而是 preview host 的真实输入。

这说明当前 repo 已经在事实上采用了“secret 先 keychain、endpoint 先 env、model 可 defaults 回退”的分层策略，只是文档没有把它明确写出来。

### 1.5 `live probe` 另有一条兼容链，它不是主运行真相

`MasterChatLiveProbe.resolveCandidate()` 和 `MasterChatConfiguration.current()` 相似但不相同：

1. `baseURL`
   `MASTER_CHAT_BASE_URL`
   -> `MOONSHOT_BASE_URL`
   -> `masters.chat.baseURL`
   -> legacy `ANTHROPIC_BASE_URL`
   -> legacy `ANTHROPIC_HOST`
2. `apiKey`
   `keychain`
   -> `MASTER_CHAT_API_KEY`
   -> `MOONSHOT_API_KEY`
   -> `masters.chat.apiKey`
   -> legacy `ANTHROPIC_AUTH_TOKEN`
   -> legacy `ANTHROPIC_API_KEY`
3. `model`
   `MASTER_CHAT_MODEL`
   -> `MOONSHOT_MODEL`
   -> `masters.chat.model`
   -> fallback(`k2p5`)

这条链的性质必须单独标注，因为它只服务于 `/v1/models` 预检、`MASTER_CHAT_LIVE_SMOKE=1` 和 `stage2_smoke` 之类自动化路径。它属于“probe-only compatibility fallback”，不能被误写成主运行链已经接受 `ANTHROPIC_*` 为 Stage 2 真配置。

### 1.6 本地大师目录和资源已经是另一类配置输入：`local assets`

`MasterCatalogLoader` 和 `MasterServiceDirectory` 当前并不读 env/defaults/keychain，它们读的是本地资源：

1. 目录 manifest
   `Bundle.main.url(forResource: "master_service_directory", withExtension: "json")`
   -> `Features/Masters/Support/master_service_directory.json`
2. 字段与图片资源根目录
   优先尝试 bundle 中的
   - `char` + `assets/char`
   - `MasterCharAssets` + `MasterImageAssets/char`
   否则回退到 repo 根目录
   - `./assets/char`
   - `./assets/assets/char`

这说明当前代码里的“本地资产”不是文档里的抽象名词，而是实打实的配置来源。它决定：

1. 目录 manifest 来自哪里
2. 大师字段 JSON 来自哪里
3. 图片映射来自哪里
4. preview host 是走 bundle 资源还是 repo roots

### 1.7 `docs assumptions` 现在大量存在，但它们不该继续被当成配置源

当前仓库里仍有一些“文档假设”在代替配置登记说话：

1. `Docs/Stage2_Blueprint.md` 与镜像反复记录某个 ASR probe route、某些 live 配置是否存在。
2. Stage 2 文档把大师资源描述成固定来自 `./assets/char` 与 `./assets/assets`，但代码其实先查 bundle，再查 repo roots。
3. 一些旧 README 会把 local backend、plugin 或 defaults 行为写成更确定的运行事实。

这些信息当然有参考价值，但它们不是 runtime config source。只要和代码冲突，就必须降级成“过时假设”。

## 2. 当前文档偏差

当前文档对配置来源最明显的偏差有五个：

1. 它们默认把 `env`、`UserDefaults`、`keychain`、`assets` 混写成一类“配置”，但代码实际上按字段类型分开解析。
2. 旧文档把 `MASTER_CHAT_*`、`masters.chat.*`、keychain 与 legacy `ANTHROPIC_*` 的关系写得不够清楚，容易把 probe fallback 误当成 Stage 2 主链路。
3. Stage 2 文档多次把 ASR 探针叙述为 `17880/v1/audio/transcriptions`，但当前 `MasterASRService.swift` 的内建默认值已经是 `8020/v1/asr/transcribe`。这类冲突必须以代码为准。
4. 文档常把大师资源路径简化成 `./assets/char` 与 `./assets/assets`，但代码真实顺序是“先 bundle，再 repo roots，再报错”。如果不登记这条顺序，preview host 和 app bundle 行为会一直被误读。
5. 文档会写“当前 shell 未注入”“defaults read 未见配置”这类观测结论，但没有明确说明这些只是观测结果，不构成新的配置权威。

## 3. 稳定 SOTA / 成熟实践

对这种同时包含 app runtime、preview host、local assets、automation probe 的仓库，成熟做法不是定义一个全局单行优先级，而是做“按字段类型登记的配置来源注册表”：

1. `secret credential` 单独登记，因为它天然需要更严格的暴露规则和不同的读写策略。
2. `endpoint / model / tenant / runtime flag` 单独登记，因为它们更适合 `env` 和 `UserDefaults` 这种覆盖型来源。
3. `local assets` 单独登记，因为它们不是“键值配置”，而是文件系统 / bundle 解析链。
4. `docs assumptions` 单独登记，而且只允许标为 “non-runtime hint”，不能进入真实解析顺序。

成熟实践还会补齐四条纪律：

1. 每个字段都要同时记录 “读取顺序” 和 “允许暴露到哪里”。
2. secret 只能回显来源名，不能回显值；路径和 manifest 可以回显相对路径，但不能把本机隐私内容写进文档。
3. 兼容性 fallback 必须标记 `probe-only` 或 `legacy-only`，防止被误报成主链路。
4. 文档只能登记代码已经实现的解析链，不能把计划中的手工说明写成“当前默认源”。

## 4. 面向本仓库的具体建议

### 4.1 建议采用统一的配置来源登记字段

建议以后所有配置登记都只用下面这一组字段：

| 字段 | 含义 |
| --- | --- |
| `config_surface` | 哪个 consumer 在读这组配置，例如 `XianxiaTopicAPIConfiguration` |
| `field_group` | `secret credential` / `endpoint` / `model` / `runtime flag` / `asset roots` / `manifest` |
| `read_order` | 精确到 key 名或路径顺序 |
| `write_back_policy` | 是否会从 env/bootstrap 写回 keychain 或 defaults |
| `exposure_rule` | UI / 日志 / 文档里允许暴露到什么粒度 |
| `compatibility_scope` | 是否允许 legacy fallback；若允许，是否仅限 probe |
| `code_owner_truth` | 对应的代码文件，出现冲突时以它为准 |

这样登记后，就不会再把“一个 key 在哪儿读”和“这个值能不能写进文档”混成一件事。

### 4.2 建议采用的仓库级优先级矩阵

当前仓库最合理的统一方式不是单行总排序，而是以下矩阵：

| 字段类型 | 建议优先级 | 适用现状 |
| --- | --- | --- |
| `secret credential` | `keychain -> stage env -> defaults compatibility -> unavailable -> docs assumptions(never runtime)` | 对齐 `MasterChatConfiguration` |
| `endpoint / model / tenant / batch size / runtime flag` | `env -> UserDefaults -> built-in default -> docs assumptions(never runtime)` | 对齐 `Xianxia`、`ASR`、部分 `Masters` |
| `local assets / manifest / bundled resources` | `bundle resources -> repo asset roots -> unavailable -> docs assumptions(never runtime)` | 对齐 `MasterCatalogLoader` |
| `legacy compatibility probe` | `stage truth chain resolved first -> legacy env fallback only for smoke / preflight` | 对齐 `MasterChatLiveProbe` |

这张矩阵的关键价值是，它能解释当前代码为什么看起来“不统一”却仍然合理：

1. `env` 并不是永远高于一切，因为 secret 在 `Masters chat` 里先认 keychain。
2. `defaults` 在 preview host 里是真输入，在 live secret 上又只是兼容入口。
3. `local assets` 根本不该和 `env/defaults` 放在同一条解析链里比较。

### 4.3 建议采用的暴露规则

建议以后统一执行下面几条暴露规则：

1. secret 只允许暴露来源名，例如 `keychain(service/account)`、`env(MASTER_CHAT_API_KEY)`，不允许暴露明文值。
2. endpoint 可以暴露最终 URL 与来源摘要，因为这类信息是联调与 blocker 判断必须知道的。
3. `UserDefaults` 的 key 名可以公开，value 只有在非 secret 场景下才允许写入文档。
4. local assets 可以公开相对路径、manifest 文件名、bundle resource 名，但不应该把角色 JSON 正文或图片内容搬进蓝图。
5. docs assumptions 只允许作为“手工说明”存在，不能被描述为“当前默认源”或“当前客户端会自动读取”。

### 4.4 建议补成仓库级配置注册表的首批条目

如果按当前代码现状落地，首批至少要登记下面五条：

1. `XianxiaTopicAPIConfiguration`
   明确 `env alias -> defaults alias -> built-in`，并说明这些字段会影响 cache scope。
2. `MasterASRConfiguration`
   明确 `env -> defaults -> built-in`，并标注状态页只暴露来源，不暴露 secret。
3. `MasterChatConfiguration`
   明确 `apiKey` 与 `baseURL/model` 分别走不同优先级链，并标注 `env secret` 可能 bootstrap 进 keychain。
4. `MasterChatLiveProbe`
   明确 legacy `ANTHROPIC_*` 只限 smoke / preflight，不得拿去给 Stage 文档做“已接通”结论。
5. `MasterCatalogLoader` / `MasterServiceDirectory`
   明确 bundle resources 与 repo roots 的顺序，停止把 `./assets/char` 写成唯一来源。

### 4.5 对旧文档最需要立刻纠偏的三点

1. 停止把 `docs assumptions` 写成“当前默认配置”。
2. 明确修正 ASR 默认 probe / 默认 endpoint 的旧描述，以 `MasterASRService.swift` 为准。
3. 明确写出大师资源与目录 manifest 先 bundle、后 repo root 的顺序，不再让 preview host 行为看起来像“神秘特殊 case”。

## 5. 实施顺序

1. 先在 Stage 3 文档层建立这一份 registry 规则，后续研究文档都按字段类型登记来源。
2. 再回收明显过时的 Stage 2 配置叙述，尤其是 ASR 默认路由和大师资源来源。
3. 然后把 `probe-only legacy fallback` 单独标记出来，避免继续误导 live 结论。
4. 接着把 secret 的 defaults 使用统一降格为“兼容入口”，长期主路径明确为 keychain 或显式 env。
5. 最后补缺失单测，例如给 `XianxiaTopicAPIConfiguration` 增加 env 覆盖 defaults 的显式测试，避免未来优先级回退。

## 6. 风险

1. 如果强行定义一条对所有字段都成立的总优先级，会把 secret、assets、endpoint 三类完全不同的输入错误地压平。
2. 如果把 `legacy env` 不加标签地写进统一优先级，未来很容易再次把只读 probe 误判成 Stage 主链路已接通。
3. 如果继续允许文档直接声称“当前默认值就是某个 URL / 某个路径”，而不回链到代码，配置真相会再次漂移。
4. 如果 secret 暴露规则不单列，文档和状态页很容易在“来源登记”过程中顺手泄露明文密钥。
5. 如果过早移除 `UserDefaults` 兼容入口，而不先处理 preview host 和本机调试路径，会让当前可验证链路先倒退。

代码和旧文档冲突时，本条研究结论以代码为准。
