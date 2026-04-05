# S5-02 Plugin 与 iOS App 契约同步

## 当前代码现状

1. `clawdb-topics` topic gateway 的当前权威资产集中在 plugin workspace，而不是在 iOS app：
   - `spare-life-openclaw-plugin/manifests/clawdb-topics.channel.json` 定义了 transport、HTTP base path、route 和 WS ops。证据在 `spare-life-openclaw-plugin/manifests/clawdb-topics.channel.json:1-23`。
   - `spare-life-openclaw-plugin/src/channel/clawdbTopicsChannelPlugin.mjs` 定义了 config schema、默认 host/port/path、publicBaseUrl、gateway 生命周期。证据在 `spare-life-openclaw-plugin/src/channel/clawdbTopicsChannelPlugin.mjs:11-57` 与 `:74-250`。
   - `spare-life-openclaw-plugin/src/channel/clawdbTopicsGatewayServer.mjs` 执行真实 HTTP/WS server，暴露 `/health`、`/topics`、`/topics/{topicId}`、`/topics/{topicId}/shards`，并处理 `ping` / `topics.list` / `topics.shards.list` / `topic.get`。证据在 `spare-life-openclaw-plugin/src/channel/clawdbTopicsGatewayServer.mjs:47-260`。
2. `spare-life-openclaw-plugin/src/sdk/clawdbTopicsClient.mjs` 已经实现了 topic gateway 的 JS SDK，支持 HTTP + WS 双通道、batch pull、getTopic、iterateTopics / iterateTopicShards。证据在 `spare-life-openclaw-plugin/src/sdk/clawdbTopicsClient.mjs:39-260`。
3. 但当前 iOS app 并没有消费这份 SDK。`spare-life-ios-app/Features/Xianxia/SceneTopicView.swift` 自己定义了 `XianxiaTopicAPIConfiguration`、baseURL 归一化、`topicsURL` / `shardsURL`、batchSize/tenantId 处理，以及 `ClawdbGatewayEnvelope` 的 HTTP envelope 解析。证据在 `spare-life-ios-app/Features/Xianxia/SceneTopicView.swift:398-645` 与 `:749-755`。这说明 app 与 plugin 之间的 topic contract 今天是“双实现、手工同步”，不是单一 client implementation。
4. 这条双实现还包含默认值复制：
   - plugin README 和 gateway server 默认使用 `/v1/clawdb-topics` 与 `/v1/clawdb-topics/ws`。证据在 `spare-life-openclaw-plugin/README.md:52-69` 与 `spare-life-openclaw-plugin/src/channel/clawdbTopicsGatewayServer.mjs:47-54`。
   - iOS app 也把默认 base URL 写死为 `http://100.82.60.69:17880/v1/clawdb-topics`，并自己补齐 `v1/clawdb-topics` 路径。证据在 `spare-life-ios-app/Features/Xianxia/SceneTopicView.swift:402-468`。
5. payload schema 目前也不是单一真相：
   - `channelContracts.mjs` 负责 `scene_scan` payload 的 assert，并引用了 iOS app 的 `sceneContracts.mjs` 常量。证据在 `spare-life-openclaw-plugin/src/schemas/channelContracts.mjs:1-40`。
   - `unifiedChannelContracts.mjs` 负责 `requestId / routeKey / action / body` 的 envelope 约束，并直接枚举 `scene / masters / earn_social / companion / my / unified_ui / ai_memory / security`。证据在 `spare-life-openclaw-plugin/src/schemas/unifiedChannelContracts.mjs:1-40`。
   - 同时 `unifiedChannelHandler` 自己又维护了一整套 route/action dispatch map。证据在 `spare-life-openclaw-plugin/src/handlers/unifiedChannelHandler.mjs:19-95`。也就是说，schema 与 runtime dispatch 仍有双重维护。
6. plugin runtime 当前与 iOS app 的关系不是“通过稳定外部 SDK 调用”，而是“直接跨 workspace import app 下的 `.mjs` 领域层”：
   - `sceneScanHandler`、`masterFlowHandler`、`earnSocialFlowHandler`、`companionChatHandler`、`myDashboardHandler`、`unifiedUIHandler` 都直接 import `spare-life-ios-app/Domain/UseCases/*.mjs` 与 `LocalBackend/**/*.mjs`。证据分别在 `spare-life-openclaw-plugin/src/handlers/sceneScanHandler.mjs:1-39`、`masterFlowHandler.mjs:1-64`、`earnSocialFlowHandler.mjs:1-101`、`companionChatHandler.mjs:1-111`、`myDashboardHandler.mjs:1-83`、`unifiedUIHandler.mjs:1-85`。
7. demo code 与 runtime code 今天也需要分开看：
   - `package.json` 暴露了大量 `src/demo/*.mjs` 脚本。证据在 `spare-life-openclaw-plugin/package.json:14-22`。
   - `src/demo/` 目录里确实存在这些 demo 文件，用于本地验证与闭环样例。
   - 但 `tests/` 目录当前只有 `.gitkeep`，而 `package.json` 仍保留了 `node --test ./tests/master-flow.test.mjs` 脚本。也就是 demo 是实物，test entry 多数只是历史痕迹。
8. `OpenClawPluginView.swift` 不是 app 与 plugin runtime 的真实同步面，而是一个本地 mock 的诊断面板。`OpenClawPluginStore.load()` 直接填充 adapters、events、schemas、handlers 假数据，并在视图 `.task { store.load() }` 中渲染。证据在 `spare-life-ios-app/Features/Infrastructure/OpenClawPluginView.swift:141-315`。因此不能把这个页面当作“当前 plugin 状态已接入 app”。

## 当前文档偏差

1. plugin README 把 `src/sdk/` 直接叫做 “app SDK client (`ClawdbTopicsClient`)”，并给出 JS `import { ClawdbTopicsClient } from "spare-life-openclaw-plugin"` 的示例。证据在 `spare-life-openclaw-plugin/README.md:19-21` 与 `:71-92`。这在 Node / JS 世界里成立，但在当前 Swift iOS app 世界里并不成立，因为 app 没有使用这份 SDK。
2. plugin README 还把 `tests/` 列为 “plugin-focused tests”。证据在 `spare-life-openclaw-plugin/README.md:21-22`。但当前工作树的 `tests/` 只有 `.gitkeep`，真实可运行的是 `src/demo/*.mjs`；代码和 README 冲突时应以代码为准。
3. plugin README 的 “App uses ws://<tailscale-ip>...” 也容易让读者误判当前 app 已经通过 SDK 或 WebSocket 接入 plugin。证据在 `spare-life-openclaw-plugin/README.md:98-113`。但当前 Swift `XianxiaTopicRepository` 走的是 `URLSession.shared.data(for:)` 的 HTTP GET 路径，不是 WebSocket SDK。证据在 `spare-life-ios-app/Features/Xianxia/SceneTopicView.swift:522-645`。
4. `OpenClawPluginView.swift` 名字会让人自然以为它是 live plugin dashboard，但它当前完全依赖本地 mock 数据。证据在 `spare-life-ios-app/Features/Infrastructure/OpenClawPluginView.swift:168-315`。这也是 repo boundary 文档里必须纠偏的一处。
5. `openclaw.plugin.json` 的 `configSchema` 目前是空对象，而真实的 channel config schema 在 `clawdbTopicsChannelPlugin.mjs` 内。证据分别在 `spare-life-openclaw-plugin/openclaw.plugin.json:1-8` 与 `spare-life-openclaw-plugin/src/channel/clawdbTopicsChannelPlugin.mjs:11-57`。这会让读配置入口的人误以为 plugin 层没有实质配置。

## 稳定 SOTA / 成熟实践

1. 一个跨 runtime 契约只能有一个权威层级。成熟做法通常是：
   - manifest / schema 是协议真相
   - generated or hand-maintained client 只是协议适配器
   - runtime server 实现协议
   - demo 只消费公开 client/runtime，不再复制协议细节
2. app client 不应手写第二份协议默认值与 envelope 解析，除非它被明确标成 “parallel client implementation” 并有 contract test 持续校验。否则路径、op 名、error envelope、batch/cursor 语义很容易漂移。
3. monorepo 内跨 workspace 直接 import domain code 可以作为短期策略，但必须承认这是内部耦合，而不是稳定外部集成边界。真正稳定的边界应该是：
   - shared contract package
   - generated client
   - versioned schema test
4. demo code 与 test code 不能混作同一层证据。demo 只能证明“这条路径在当前机器上能跑一遍”，不能代替“协议未漂移、接口仍兼容、未来改动可被守住”。

## 面向本仓库的具体建议

1. 立即把 topic gateway 的单一协议真相明确为 plugin workspace 中这三层的组合：
   - `manifests/clawdb-topics.channel.json` 负责 transport 能力、HTTP/WS path、op 名与 pagination 能力声明。
   - `src/channel/clawdbTopicsChannelPlugin.mjs` 负责 config schema、默认端口/路径、publicBaseUrl 和 gateway lifecycle。
   - `src/channel/clawdbTopicsGatewayServer.mjs` 负责运行时实现。
   这三层之外，任何 client 只能消费，不应再重新定义协议。
2. 把当前 Swift `XianxiaTopicRepository` 明确定义成 “parallel native app client”，不是 SDK。既然它今天确实存在，就不要伪装成在用 plugin SDK；但也必须把它纳入 contract sync 范围。
3. 为 topic gateway 增加最小 contract 同步规则：
   - path truth 以 `clawdb-topics.channel.json` 为准。
   - app 侧 `topicsURL` / `shardsURL` 逻辑必须通过单独的 contract smoke 与 manifest 对齐。
   - envelope truth 以 plugin server 返回的 `{ ok, data, error }` 结构为准；Swift 侧不能擅自扩大或缩小字段语义。
4. 把 `channelContracts.mjs` / `unifiedChannelContracts.mjs` 与 `unifiedChannelHandler` 的 route/action 枚举逐步收敛成一个 shared contract registry。
   - 当前 `unifiedChannelContracts.mjs` 维护 `CHANNEL_ROUTES`。
   - `unifiedChannelHandler` 维护更细的 actionMap。
   - 成熟做法是把 route -> actions -> payload normalizer 的注册信息集中成一份表，然后 schema、handler、demo 同时读取它，而不是分散重复。
5. 明确五层同步策略：
   - `topic gateway`: plugin manifest + channel runtime 为真相。
   - `SDK`: 当前只有 JS SDK；Swift app 是 parallel client，不应被 README 写成“已经统一 SDK”。
   - `payload schema`: 以 plugin `src/schemas/*` 为真相，但应进一步抽成独立 contract plane，减少对 iOS app `Domain/Models/*.mjs` 的反向依赖。
   - `demo code`: 非权威，只做 smoke；必须使用公开 runtime/client 入口，不再复制协议常量。
   - `plugin runtime`: 是 Node/plugin 执行真相，不等于 iOS app UI 集成真相。
6. 把 `OpenClawPluginView.swift` 在后续文档中重命名为 “mock diagnostic surface” 口径，直到它真的接入 gateway status / schema / runtime metrics 为止。
7. README 需要后续按现状改写成更精确的说法：
   - plugin 有 JS SDK
   - iOS Swift app 当前使用自写 native client 访问 topic gateway
   - tests 目前未成型，现有可运行的是 demos

## 实施顺序

1. 先冻结真相：当前 iOS app 通过 `SceneTopicView.swift` 内的原生 Swift HTTP client 访问 `clawdb-topics`，不是通过 JS SDK，也不是通过 WebSocket。
2. 再把 topic gateway 的 path/op/capability 真相固定到 `clawdb-topics.channel.json` 与 channel runtime，禁止第三处继续写默认 path。
3. 然后补一条最小 contract smoke：
   - 读取 manifest 的 base path / ws path / ops
   - 校验 Swift app 的 `XianxiaTopicAPIConfiguration` 归一化结果与 plugin manifest 一致
   - 校验 gateway server 返回 envelope 仍为 `{ ok, data, error }`
4. 接着收敛 unified channel registry，把 route/action/schema/runtime dispatch 放到同一份声明源。
5. 最后才考虑两件事：
   - 是否给 Swift 端真正生成或手写独立 SDK
   - 是否把 `OpenClawPluginView.swift` 接成 live status surface

## 风险

1. 如果继续维持 topic gateway 双实现而没有 contract smoke，plugin 改 path、op 名、cursor 语义或 envelope 字段时，Swift app 侧会静默漂移。
2. 如果 README 继续把 JS SDK 描述成 “app SDK”，团队会持续误判 iOS app 已经共享 client implementation，导致排查问题时找错层。
3. 如果把 demo 当 test，Stage 3 自动化会高估边界稳定性；当前 `tests/` 几乎为空，这个风险已经存在。
4. 如果继续把 `OpenClawPluginView.swift` 当作“契约已接线”的证据，会给 UI/运营面板带来虚假的运行可观测性。
5. 如果 `unifiedChannelContracts.mjs` 与 `unifiedChannelHandler` 的 route/action 表继续分头维护，未来只要新增或改名一个 route，就会出现 schema 允许但 runtime 不认，或 runtime 接受但 schema 不收的分叉。

代码和旧文档冲突时，本条研究结论以代码为准。
