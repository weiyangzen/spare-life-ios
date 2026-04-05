# S5-04 统一验证矩阵

## 当前代码现状

1. `swift test` 是当前最完整、最稳定的 Swift 级验证入口。`spare-life-ios-app/Package.swift` 定义了 `SpareLifeCoreTests` test target。证据在 `spare-life-ios-app/Package.swift:46-49`。现有测试里既有确定性测试，也有 live smoke 的可选子集：
   - 最小 shell smoke 是 `SpareLifeCoreSmokeTests.testMainTabsExposeExpectedCount()`，只验证 `MainTab` 数量为 5。证据在 `spare-life-ios-app/Tests/SpareLifeCoreTests/SpareLifeCoreSmokeTests.swift:4-7`。
   - masters automation contract、conversation、catalog、ASR、Xianxia repository 等都有普通单测覆盖。
   - `MASTER_CHAT_LIVE_SMOKE=1` 与 `MASTER_ASR_LIVE_SMOKE=1` 时，tests 还会尝试真实远端 smoke；若环境未准备好则明确 `XCTSkip`。证据在 `spare-life-ios-app/Tests/SpareLifeCoreTests/MasterConversationServiceTests.swift:891-994` 与 `spare-life-ios-app/Tests/SpareLifeCoreTests/MasterASRServiceTests.swift:267-304`。
   这说明今天的 `swift test` 真实形态是“deterministic core tests + opt-in live smokes”，不是单一纯离线测试集。
2. app shell smoke 在当前仓库里并不存在独立生产 app target，因此不能假装有一条“真正的 app target smoke”。当前唯一 `@main` app 是 preview host 的 `SpareLifePreviewHostApp`，它在 `WindowGroup` 里加载 `MainTabView()`。证据在 `spare-life-ios-preview-host/App/SpareLifePreviewHostApp.swift:3-17`。所以今天最接近 shell smoke 的两条现有入口分别是：
   - package 内的 `SpareLifeCoreSmokeTests`，验证根 tab contract；
   - preview host 的 `xcodebuild ... build` / `simctl launch`，验证 host 能把 root shell 拉起。
3. preview host UI test 是实物，而且目前只有一份真实 UITest 文件。`spare-life-ios-preview-host/UITests/XianxiaStage1UITests.swift` 包含两个场景：
   - `testStage1TopicFeedDetailPaginationAndOfflineFallbackOnIPhone15Pro()`：通过 launch env 配置 Xianxia base URL 和 batch size，再借助本地 proxy 在 online/offline 间切换验证 topics/shards 与缓存回退。证据在 `spare-life-ios-preview-host/UITests/XianxiaStage1UITests.swift:20-59` 与 `:90-117`。
   - `testMastersDirectoryShows8CardsAndOpensOneToOneOnIPhone15Pro()`：验证闲聊目录卡片与对话页进入。证据在 `spare-life-ios-preview-host/UITests/XianxiaStage1UITests.swift:61-88`。
   同时 preview host README 明确说 host 直接编译 `../spare-life-ios-app/` 现有源码。证据在 `spare-life-ios-preview-host/README.md:3-10`。
4. plugin smoke 现在主要依赖 demo scripts，而不是稳定测试套件。`spare-life-openclaw-plugin/package.json` 暴露了 `scene-flow-demo`、`master-flow-demo`、`companion-chat-flow-demo`、`my-dashboard-flow-demo`、`foundation-bottom-demo`、`clawdb-topics-sdk-demo` 等脚本。证据在 `spare-life-openclaw-plugin/package.json:14-22`。但同一个 `package.json` 仍保留 `node --test ./tests/master-flow.test.mjs` 形式的脚本，而实际 `spare-life-openclaw-plugin/tests/` 目录只有 `.gitkeep`。代码说明 plugin smoke 当前是“demo 驱动、测试缺席”的状态，不是“demo + tests 都完善”。
5. gateway smoke 也是实物，但入口分散。`spare-life-openclaw-plugin/manifests/clawdb-topics.channel.json` 把 HTTP `health/topics/topic/shards` 路由和 WS ops 固定为协议能力。证据在 `spare-life-openclaw-plugin/manifests/clawdb-topics.channel.json:1-23`。`clawdbTopicsGatewayServer.mjs` 真实实现了 `/health`、topics/shards/topic HTTP 路由与 `ping/topics.list/topics.shards.list/topic.get` WS op。证据在 `spare-life-openclaw-plugin/src/channel/clawdbTopicsGatewayServer.mjs:111-198` 与 `:244-270`。`clawdb-topics-sdk-demo.mjs` 又提供了基于 JS SDK 的 topics + shards 批量拉取 smoke。证据在 `spare-life-openclaw-plugin/src/demo/clawdb-topics-sdk-demo.mjs:1-40`。此外，preview host 还有一个 `xianxia_clawdb_proxy.mjs` 用于把 gateway 代理成 online/offline 状态，辅助 UI test 验证缓存回退。证据在 `spare-life-ios-preview-host/Scripts/xianxia_clawdb_proxy.mjs:1-88`。
6. docs evidence generation 已经有正确方向，但没有统一矩阵约束。`S1-02` 明确把 `Docs/ValidationLog_*.md` 定义为 append-only 运行证据，规定蓝图只保留 scope、checklist、ownership 与 evidence pointer。证据在 `Docs/researches/Stage_3_AR/section_1_truth/02-document-stratification.md:49-55` 与 `:63-69`。但当前 Stage 1 文档仍把 `swift test`、`curl`、`xcodebuild`、`simctl` 等长串 rerun 记录直接写进蓝图正文。证据在 `Docs/Stage_1_Blueprint.md:217-224`。也就是说，证据层规则已存在，执行层还没有被矩阵化收敛。
7. 当前部分 `ValidationLog_*` 已经出现“日志声称跑过的命令，代码里并不存在”的问题。最明显的是 `Docs/ValidationLog_Foundation_FUNC_Batch1.md` 记录了 `node --test spare-life-openclaw-plugin/tests/master-flow.test.mjs`、`companion-chat-flow.test.mjs`、`my-dashboard-flow.test.mjs` 全部通过。证据在 `Docs/ValidationLog_Foundation_FUNC_Batch1.md:36-38`。但当前 plugin `tests/` 目录只有 `.gitkeep`。这说明 docs evidence generation 现在还缺最基本的命令-实物一致性 guard。

## 当前文档偏差

1. `spare-life-openclaw-plugin/README.md` 把 `tests/` 写成 “plugin-focused tests”。证据在 `spare-life-openclaw-plugin/README.md:19-22`。但代码里并没有对应测试文件，只有 demo scripts。任何把 plugin 验证矩阵写成“tests + demos 均已成型”的文档，都会和代码冲突。
2. `spare-life-ios-app/README.md` 仍把 `App/` 说成 app entry / bootstrap。证据在 `spare-life-ios-app/README.md:7-16`。这会让读者误以为 app shell smoke 应该直接挂到 `spare-life-ios-app` 的 app target 上，但代码现实是唯一 host app 在 preview host。
3. `Docs/Stage_1_Blueprint.md` 继续把大量验证命令与结果写在蓝图正文里。证据在 `Docs/Stage_1_Blueprint.md:217-224`。这与 S1-02 已经定义好的“蓝图不写 rerun 历史、ValidationLog 才是 append-only 证据”直接冲突。
4. 当前 repo 没有一张单独的矩阵同时说明：
   - 哪些 lane 是 blocking deterministic
   - 哪些 lane 是 optional live smoke
   - 每条 lane 的前置条件
   - 每条 lane 的证据应写到哪里
   - 哪些命令只是 demo，不应伪装成 test

## 稳定 SOTA / 成熟实践

1. 统一验证矩阵的核心不是“把所有命令放在一个表里”，而是先把验证 lane 分层：
   - deterministic/blocking
   - integration/simulator
   - runtime demo smoke
   - live/credential-gated
   - docs evidence
2. 每条 lane 应有唯一入口、唯一 owner、唯一证据落点。否则同一个验证动作会同时出现在蓝图、镜像、ValidationLog、README 与临时脚本里，最终没人知道哪一条才是权威记录。
3. demo 只能证明“当前机器上有一条运行链能走通”，不能替代 test。成熟实践会把 demo 与 test 明确区分，并在矩阵里标注 `demo-smoke` 或 `contract-test`，绝不混写。
4. live smoke 应明确是 opt-in lane，并通过环境变量或 secret presence 显式开启；如果未配置，应该是 `skip` 而不是 `fail`。当前 masters chat/asr tests 已经沿这个方向实现。
5. 文档证据层应该 append-only，但必须建立命令-实物一致性校验。否则日志会持续累计历史误报，反而降低可信度。

## 面向本仓库的具体建议

1. 以代码现状为准，把当前仓库的统一验证矩阵收敛成下面 6 条 lane：

| Lane | 当前权威入口 | 主要前置条件 | 产出 / 证据 | 建议地位 |
| --- | --- | --- | --- | --- |
| `swift test` | `swift test --package-path spare-life-ios-app` | 本机有 Swift toolchain | test output；必要时摘要写入 `Docs/ValidationLog_*` | `blocking` |
| `app shell smoke` | `xcodebuild -project spare-life-ios-preview-host/SpareLifePreviewHost.xcodeproj -scheme SpareLifePreviewHost -destination '<sim>' build`，必要时 `xcrun simctl launch` | Xcode + Simulator；因为当前无独立生产 app target，所以以 preview host shell 代替 | build log / launch proof；摘要写入 `ValidationLog` | `blocking` for shell changes |
| `preview host UI test` | `xcodebuild ... -only-testing:SpareLifePreviewHostUITests/XianxiaStage1UITests/... test` | Xcode + Simulator；Xianxia case 还需先启动 proxy | `.xcresult`、simulator proof、摘要写入 `ValidationLog` | `blocking` for host UI / flow changes |
| `plugin smoke` | `node spare-life-openclaw-plugin/src/demo/*.mjs` 或 `npm run <demo>` | Node 运行时；必要时本地 SQLite/fixture | stdout JSON / console summary；摘要写入 `ValidationLog` | `non-blocking demo-smoke`，直到真实 tests 出现 |
| `gateway smoke` | `openclaw gateway` + `curl /health` + `node spare-life-openclaw-plugin/src/demo/clawdb-topics-sdk-demo.mjs` | OpenClaw、channel install、gateway 已启动；必要时可配 proxy | `/health` 响应、SDK demo 输出、摘要写入 `ValidationLog` | `blocking` for gateway contract changes |
| `docs evidence generation` | `Docs/ValidationLog_*.md` append-only 记录 | 前五条 lane 至少实际运行一条 | 日期、环境、命令、结果、限制、证据摘要 | `required` for completion proof |

2. 对这 6 条 lane 的 repo-specific 细化规则，建议立即固定如下：
   - `swift test` lane 只把确定性测试视为默认 blocking。`MASTER_CHAT_LIVE_SMOKE=1` 与 `MASTER_ASR_LIVE_SMOKE=1` 触发的 live tests 单独记作 `swift-live-smoke` 子状态，未配置时允许 `skip`。
   - `app shell smoke` lane 只负责“host 能把 root shell 编译并拉起”，不负责业务交互深度验证。它和 preview host UI test 的职责必须分离。
   - `preview host UI test` lane 当前有两个真实场景：`Xianxia topic feed/detail/offline fallback` 与 `Masters directory open one-to-one`。不要在矩阵里虚构更多 case。
   - `plugin smoke` lane 当前只能声明为 `demo-smoke`。在 `spare-life-openclaw-plugin/tests/` 真正补齐文件之前，任何 `node --test ...` 成功记录都不应再被当作完成门槛。
   - `gateway smoke` lane 必须包含一条最小 health probe 与一条真实 client probe。只跑 `/health` 不足以证明 schema、topics/shards 路径和 SDK client 没漂移。
   - `docs evidence generation` lane 必须把“命令是否真实存在”纳入基本校验；日志里出现的命令，仓库里就必须能找到对应脚本或测试文件。
3. 当前 repo 最该立刻落地的统一命令集合应是下面这组，而不是再让每份文档自由发挥：
   - `swift test --package-path spare-life-ios-app`
   - `swift test --package-path spare-life-ios-app --filter SpareLifeCoreSmokeTests`
   - `xcodebuild -project spare-life-ios-preview-host/SpareLifePreviewHost.xcodeproj -scheme SpareLifePreviewHost -destination '<sim>' build`
   - `node spare-life-ios-preview-host/Scripts/xianxia_clawdb_proxy.mjs`
   - `xcodebuild -project spare-life-ios-preview-host/SpareLifePreviewHost.xcodeproj -scheme SpareLifePreviewHost -destination '<sim>' -only-testing:SpareLifePreviewHostUITests/XianxiaStage1UITests/testStage1TopicFeedDetailPaginationAndOfflineFallbackOnIPhone15Pro test`
   - `xcodebuild -project spare-life-ios-preview-host/SpareLifePreviewHost.xcodeproj -scheme SpareLifePreviewHost -destination '<sim>' -only-testing:SpareLifePreviewHostUITests/XianxiaStage1UITests/testMastersDirectoryShows8CardsAndOpensOneToOneOnIPhone15Pro test`
   - `node spare-life-openclaw-plugin/src/demo/foundation-bottom-layer-demo.mjs`
   - `node spare-life-openclaw-plugin/src/demo/scene-flow-demo.mjs`
   - `node spare-life-openclaw-plugin/src/demo/master-flow-demo.mjs`
   - `node spare-life-openclaw-plugin/src/demo/companion-chat-flow-demo.mjs`
   - `node spare-life-openclaw-plugin/src/demo/my-dashboard-flow-demo.mjs`
   - `node spare-life-openclaw-plugin/src/demo/unified-ui-flow-demo.mjs`
   - `curl http://127.0.0.1:17880/health`
   - `node spare-life-openclaw-plugin/src/demo/clawdb-topics-sdk-demo.mjs`
4. docs evidence generation 的建议格式应该沿用 S1-02，而不是继续把 rerun 记录塞回蓝图正文。即：
   - 蓝图只保留 item、完成门槛、证据路径。
   - 每次实际运行后的命令、环境、结果、限制、截图或 stdout 摘要，一律写入 `Docs/ValidationLog_*.md`。
   - `ValidationLog` 里如果引用了脚本/测试文件，必须先确认该文件在仓库里存在。
5. 针对当前最明显的验证矩阵漏洞，建议立即修正文档口径：
   - README 与 ValidationLog 都不再写 “plugin-focused tests 已存在”。
   - 把当前 plugin lane 统一改叫 `demo-smoke`。
   - 把 preview host build/launch 明确写成当前的 app shell smoke，而不是伪造一个不存在的生产 app smoke。

## 实施顺序

1. 先冻结矩阵命名：以后所有文档统一使用 `swift test / app shell smoke / preview host UI test / plugin smoke / gateway smoke / docs evidence generation` 这 6 个 lane 名。
2. 再修正文档事实错误：删除或标注现有 `ValidationLog_*` 中对不存在 plugin tests 的通过记录，README 也同步改口径。
3. 然后把 preview host build 与 UITest 拆成两条单独证据 lane，避免 “build 成功” 和 “UI 流程通过” 继续混在一条记录里。
4. 接着给 gateway smoke 固定最小组合：`/health` + SDK demo；需要 UI offline fallback 时，再显式加 proxy。
5. 最后才考虑自动化生成 ValidationLog 模板或 guard，让命令-文件存在性检查不再靠人工复核。

## 风险

1. 如果继续把 demo 和 test 混写，团队会持续高估 plugin/runtime 的边界稳定性，尤其是在 `tests/` 实际为空的情况下。
2. 如果不把 app shell smoke 与 preview host UI test 拆开，后续只要 UI test 环境出问题，连最基础的 shell 编译/启动状态都会一起失真。
3. 如果 gateway smoke 只保留 `/health`，topics/shards 路由或 SDK client 漂移时很可能在文档里显示“gateway healthy”，但真实 app client 已经失配。
4. 如果 docs evidence generation 不做命令-实物一致性校验，历史日志里的假阳性会越积越多，最终让 Stage 3 自动化失去可信度。
5. 如果继续把 rerun 历史直接写进蓝图正文，统一验证矩阵即使写出来，也会再次被执行日志污染，无法长期维持。

代码和旧文档冲突时，本条研究结论以代码为准。
