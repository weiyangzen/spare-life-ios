# S1-04 仓库级运行真相地图

结论先行：如果只看目录名，这个仓库很容易被误读成“一个 iOS app，加一点本地后端，再带一点插件代码”；但如果按构建边界和 importer 边界看，当前仓库已经天然分成五类资产：`Swift runtime / support .mjs / local backend / plugin workspace / docs-only`。其中 `Swift runtime` 才是当前 iOS app 的 app-native 执行面；`support .mjs` 与 `local backend` 是 repo 内活代码，但今天主要由 `spare-life-openclaw-plugin` 的 Node/OpenClaw runtime 执行；`docs-only` 会影响人和自动化，但不是运行时真相。若 README、诊断页面文案和这些边界冲突，以代码为准。

## 1. 当前代码现状

### 1.1 `Swift runtime` 已经被 `Package.swift` 明确圈定

`spare-life-ios-app/Package.swift:15-39` 很清楚地把当前 `SpareLifeCore` target 限定在：

1. `App`
2. `Domain/Models`
3. `Features`

同时它显式排除了：

1. `LocalBackend`
2. `Services`
3. `Domain/UseCases`
4. `Domain/Models/*.mjs`

这条构建规则已经说明：当前 app-native Swift runtime 的主轴是 Swift 代码，而不是 `.mjs`、`LocalBackend` 或 plugin 代码。任何文档如果把这些被 `exclude` 的目录继续写成“当前 iOS binary 已接线运行面”，都和代码冲突。

### 1.2 `support .mjs` 与 `local backend` 是活代码，但当前主要由 Node/plugin runtime 执行

`spare-life-openclaw-plugin` 不是单纯的说明目录。`spare-life-openclaw-plugin/package.json:5-22` 暴露了 `src/index.mjs`、`./sdk`、`openclaw` extension 和多条 `node ./src/demo/*.mjs` 脚本；`spare-life-openclaw-plugin/src/channel/openclawPlugin.mjs:27-43` 又把 `spare-life-openclaw-plugin` 注册成真实 plugin extension。

更关键的是 importer 关系：

1. `spare-life-openclaw-plugin/src/handlers/sceneScanHandler.mjs:1-14` 直接 import `SceneExperienceUseCase` 与 `SceneFlowRepository`。
2. `spare-life-openclaw-plugin/src/handlers/masterFlowHandler.mjs:1-26` 直接 import `MasterExperienceUseCase` 与 `MasterFlowRepository`。
3. `spare-life-openclaw-plugin/src/handlers/unifiedChannelHandler.mjs:1-17` 直接 import `Domain/UseCases/*.mjs`、`LocalBackend/**` 和 `sceneContracts.mjs`。
4. `spare-life-openclaw-plugin/src/handlers/unifiedUIHandler.mjs:1-40` 同时 import 五个 feature use case 和六个 repository。

所以今天仓库里的 `.mjs` 与 `LocalBackend/**` 不是“纯概念代码”，而是“由 plugin runtime 真实执行的 repo 内活代码”。

### 1.3 诊断页和目录名已经开始制造运行错觉

Swift 侧已经存在两个很容易误导阅读者的诊断面：

1. `spare-life-ios-app/Features/Infrastructure/OpenClawPluginView.swift:1-4` 把自己命名成 “OpenClaw 渠道插件管理面板”。但这只是 Swift UI surface，不等于 plugin runtime 本身已经进入 app-native 执行面。
2. `spare-life-ios-app/Features/MyProfile/PrivacyLocalBackendView.swift:1-4` 把自己命名成“隐私与本地后端控制”。它同样只是一个 Swift 页面，不等于 `spare-life-ios-app/LocalBackend/**` 已经作为当前 app binary 内嵌后端在运行。

这两个页面证明“概念被展示到了 Swift UI”，不证明“底层 runtime 已经接到当前 app-native binary”。

### 1.4 `docs-only` 会影响操作和自动化，但不是 runtime

`Docs/` 并非完全无人消费。`.ops/stage3_ar/lib.sh:12-18` 把 `Docs/Stage_3_AR_Blueprint.md`、`Docs/Stage_3_Codebase_Audit.md`、`Docs/researches/Stage_3_AR` 写成自动化常量；`.ops/stage3_ar/worker_loop.sh:24-57` 和 `.ops/stage3_ar/refresh_todo.sh:8-19` 也会读取这些 docs 生成 prompt 和 todo。

但这类消费是“操作与治理输入”，不是“产品 runtime”。因此 `Docs/**` 必须归到 `docs-only`，而不是因为被 `.ops` 读取，就被误判成 support runtime。

## 2. 当前文档偏差

当前最明显的偏差有四类：

1. 根 README 仍把仓库压缩成 “iOS app workspace with a local SQLite-backed companion chat backend”。证据在 `README.md:12-15`。这会让人自然脑补成“本地 SQLite backend 已在 app 内原生运行”，但构建边界并不支持这个说法。
2. `spare-life-ios-app/README.md:7-16` 把 `Domain/UseCases`、`LocalBackend`、`Services` 都放在 “This workspace is reserved for the iOS client” 的结构说明下，却没有补一行说明它们今天主要由 plugin runtime 消费。
3. `spare-life-ios-app/LocalBackend/README.md:1-10` 更直接写出 “embedded backend inside the iOS app”。这和 `Package.swift:18-34` 的 `exclude` 冲突，必须以代码为准。
4. plugin README 虽然更接近运行现实，但它也会引入另一种误判：`spare-life-openclaw-plugin/README.md:19-22` 与 `:71-103` 把 `src/sdk/` 写成 “app SDK client” 并直接面向 “App uses ws://...” 叙述，容易让人以为当前 Swift app 已经共享这套 JS SDK。实际上，Swift 侧 topic client 仍是原生自写实现，不是同一个 SDK。

## 3. 稳定 SOTA / 成熟实践

对多 runtime 单仓库，成熟做法不是按“目录名听起来像什么”分类，而是按三条边界分类：

1. 构建边界：谁会被什么 target / package / runtime 真正装载。
2. importer 边界：谁被谁直接 import。
3. 运行边界：谁在 app / Node / plugin / automation / 人工阅读中被执行。

这会导出两个成熟规则：

1. “展示某个概念的 UI 页面”不等于“那个概念背后的 runtime 已经在同一执行面里”。`OpenClawPluginView.swift` 和 `PrivacyLocalBackendView.swift` 就是典型例子。
2. “文档被自动化读取”也不等于“文档属于 runtime 资产”。docs 可以是 operator input，但仍然不是执行真相。

## 4. 面向本仓库的具体建议

### 4.1 五类资产的仓库级真相表

| 资产类 | Canonical 路径 | 当前主要执行者 | 当前真相 | 不应再使用的说法 |
| --- | --- | --- | --- | --- |
| `Swift runtime` | `spare-life-ios-app/App/**`, `spare-life-ios-app/Features/**`, `spare-life-ios-app/Domain/Models/*.swift` | iOS / SwiftUI app；以及验证侧的 preview-host Swift surface | 这是当前 app-native Swift 主运行面；只有进入这条构建链的 Swift 代码，才可以被描述成“当前 iOS 运行时真相” | 不要把 `.mjs`、`LocalBackend/**`、plugin runtime 写成已进入当前 app binary |
| `support .mjs` | `spare-life-ios-app/Domain/Models/*.mjs`, `spare-life-ios-app/Domain/UseCases/**/*.mjs`, `spare-life-ios-app/Services/**/*.mjs` | Node / OpenClaw plugin handlers / demos | 这是 repo 内活跃的 support 与 contract 代码，但今天主要被 plugin runtime 调用，不是当前 Swift binary 的 native runtime | 不要写成“iOS app runtime code”；也不要把它降格成纯文档或死代码 |
| `local backend` | `spare-life-ios-app/LocalBackend/**` | Node / OpenClaw plugin handlers / demos | 这是 SQLite repository、migration、memory/backing store 层；今天是真实执行代码，但执行面主要在 Node/plugin 侧 | 不要继续写成“already embedded inside the iOS app” |
| `plugin workspace` | `spare-life-openclaw-plugin/**` | OpenClaw / Node / npm scripts | 这是唯一可以诚实宣称“当前 gateway / channel / JS SDK / demo runtime”存在的 workspace | 不要把 plugin README 的 JS SDK 直接等同于当前 Swift app 已共享的 client 实现 |
| `docs-only` | `Docs/**`, `Docs/researches/**`, `spare-life-openclaw-plugin/Docs/**` | 人工阅读；`.ops` 自动化读取 | 这是意图、治理、验证和研究资产；它们可以驱动人和自动化，但不是产品 runtime 本身 | 不要拿 docs 当作“已经接线”的运行证据 |

### 4.2 五类之间的真实流向

把当前仓库画成最小真相图，大致应该是：

```text
docs-only
  -> humans / .ops automation

Swift runtime
  -> 直接运行 SwiftUI 页面与原生 client
  -> 在部分 surface 上展示 plugin / local-backend 概念，但不等于接管这些 runtime

plugin workspace
  -> import support .mjs
  -> import local backend
  -> 提供 OpenClaw channel / demo / JS SDK

support .mjs
  -> 组合 contract、service、use case
  -> 被 plugin workspace 执行

local backend
  -> 提供 SQLite repository / migration / persistence
  -> 被 plugin workspace 执行
```

这张图里最容易被误判的点有两个：

1. `support .mjs` 不是 docs-only，它是活代码。
2. `local backend` 不是今天的 app-native embedded backend，它更接近“repo 内、由 Node/plugin 侧执行的本地仓储层”。

### 4.3 邻接但需要单独标注的目录

虽然本条只要求五类资产，但仓库里还有三类很容易被硬塞错类的邻接目录，建议后续文档显式标注：

1. `spare-life-ios-preview-host/**`
   当前更像 `swift-validation-host`，而不是产品主 runtime。它是 Swift 可执行面，但职责偏验证与 smoke。
2. `.ops/**`
   当前是 automation/operator surface。它会读取 docs、驱动 worker，但不应归入 `docs-only` 或产品 runtime。
3. `assets/**`
   当前是静态资源库。它会被 Swift runtime 与其他导入流程消费，但它本身不属于这五类“运行真相”代码面。

这三类如果不额外标注，后续维护者很容易为了凑“五类”而把它们硬归错位。

### 4.4 建议采用的判定顺序

以后判断一个路径属于哪类资产，建议按下面顺序执行：

1. 先看是否位于 `Docs/**`。如果是，直接归 `docs-only`。
2. 再看是否位于 `spare-life-openclaw-plugin/**`。如果是，直接归 `plugin workspace`。
3. 再看是否位于 `spare-life-ios-app/LocalBackend/**`。如果是，归 `local backend`。
4. 再看是否是 `spare-life-ios-app` 下的 `.mjs` support/contract/use-case 文件。若是，归 `support .mjs`。
5. 最后再看是否进入 `Package.swift` 的 Swift source 或 preview-host Swift surface。若是，归 `Swift runtime` 或其验证子面。

这样判断，比“文件名里写了 Backend / Plugin / Service 就按名字猜”稳定得多。

## 5. 实施顺序

1. 先在 Stage 3 文档层统一词汇：以后所有研究文档都按这张五类地图写，不再把 `.mjs` 总称为 “iOS runtime”。
2. 再纠偏 README：优先修根 README、`spare-life-ios-app/README.md`、`spare-life-ios-app/LocalBackend/README.md` 的运行表面描述。
3. 然后收敛诊断页口径：`OpenClawPluginView.swift`、`PrivacyLocalBackendView.swift` 在后续文档里统一标成 “Swift diagnostic surface”，不再暗示它们等于底层 runtime。
4. 接着把 future Stage 研究都带上 `asset class` 视角，例如在研究文档顶部声明“本项覆盖的是 `Swift runtime` 还是 `support .mjs` / `local backend` / `plugin workspace`”。
5. 最后再考虑是否做自动化 inventory，让 `find + Package.swift + importer graph` 定期产出一份可 diff 的资产分类表。

## 6. 风险

1. 如果继续沿用 “iOS app + local backend” 这种双层口径，团队会持续高估当前 app binary 的实际能力，尤其会误把 plugin/runtime 成果当作 app-native 已接线能力。
2. 如果反过来把 `support .mjs`、`local backend` 全部降格成“未来代码”，又会误删当前 plugin runtime 的真实依赖链。
3. 如果不把诊断页和底层 runtime 分开表述，后续任何看到 `OpenClawPluginView.swift` 或 `PrivacyLocalBackendView.swift` 的人都会默认“既然 UI 上有面板，后端一定已经在 app 内跑了”。
4. 如果 `docs-only` 继续被当成运行证据，自动化、人和代码之间的“真相层级”会再次混乱，S1-06 做验证证据治理时会失去边界。
5. 如果不单独标注 `spare-life-ios-preview-host/**` 与 `.ops/**` 这类邻接面，后续维护者很容易为了图省事，把它们硬塞进五类之一，造成新的边界漂移。

代码和旧文档冲突时，本条研究结论以代码为准。
