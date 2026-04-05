# S1-01 Canonical Module Lexicon

结论先行：当前运行时已经给出了更可信的模块命名基线。`闲虾 / 闲聊` 是当前用户可见 UI 名，`Xianxia / Masters` 是当前主代码名，`xianxia / masters` 是当前更稳定的接口名；旧文档里的 `闲人`、`咸虾`、`大师` 不能继续被当成默认模块名使用。若旧文档与代码冲突，以代码为准。

## 1. 当前代码现状

当前仓库并不存在一套真正统一的四层词典，但运行时和契约层已经暴露出足够清晰的主轴：

| 观察层 | 场景模块 | 大师对话模块 | 证据 |
| --- | --- | --- | --- |
| 当前 UI 名 | `闲虾` | `闲聊` | `spare-life-ios-app/App/MainTabView.swift:24-29`, `spare-life-ios-app/App/MainTabView.swift:72-77`, `spare-life-ios-app/Features/Xianxia/XianxiaHomeView.swift:44-56`, `spare-life-ios-app/Features/Masters/MasterChatHomeView.swift:59-76` |
| 当前主代码名 | `Xianxia` | `Masters` | `spare-life-ios-app/Features/Xianxia/*`, `spare-life-ios-app/Features/Masters/*` |
| 当前接口名 | `xianxia` | `masters` | `spare-life-ios-app/Domain/Models/unifiedUIContracts.mjs:13-18`, `spare-life-ios-app/Domain/Models/unifiedUIContracts.mjs:76-89`, `spare-life-ios-app/Domain/Models/masterContracts.mjs:80-105`, `spare-life-ios-app/Features/Xianxia/SceneTopicView.swift:402-427` |
| 当前代码内残留漂移 | `咸虾`, `闲人`, `xianren` 仍残留 | `master` 单数 key 与 `大师` 文案仍残留 | `spare-life-ios-app/Services/UnifiedUI/unifiedFeedService.mjs:713-739`, `spare-life-ios-app/Features/Xianxia/QRScanView.swift:2`, `spare-life-ios-app/Features/Xianxia/SceneFeedCardViews.swift:2`, `spare-life-ios-app/Features/MyProfile/MyProfileOverviewMetrics.swift:3-17`, `spare-life-ios-app/App/MainTabView.swift:14-18` |

几个关键事实需要单独点明：

1. `MainTabView.swift` 把模块 key 写成了 `xianxia` 和 `master`，但显示标签是 `闲虾` 和 `闲聊`。这说明“代码内部状态 key”和“用户可见名字”已经分叉。
2. `masterContracts.mjs`、`unifiedUIContracts.mjs`、`masters.asr.*` / `masters.chat.*` 这类 deep-link 与配置命名已经稳定使用 `masters` 复数；`MainTab.master` 是当前代码层的例外值，不是接口层主轴。
3. `MasterChatHomeView.swift` 的页面标题是 `闲聊`，但页面内的搜索框和空态仍然用 `大师` 指代内容实体。这说明 `大师` 更像“模块内角色实体名”，而不是“模块名”。
4. `MyProfileOverviewMetrics.swift` 仍保留 `MyProfileXianrenStats*`，说明老词 `闲人 / xianren` 已经渗透到跨模块统计层，漂移并不只发生在首页文案。
5. `unifiedFeedService.mjs` 仍给两个 feed surface 输出 `咸虾` 和 `大师` 标题，说明同一仓库内甚至同一运行时支撑层也没有共用一个表意词典。

## 2. 当前文档偏差

当前文档对这两个模块的叫法至少存在三组冲突：

| 文档 | 场景模块叫法 | 大师模块叫法 | 冲突点 |
| --- | --- | --- | --- |
| `Docs/sparelife_blueprint.md` | `咸虾` | `大师` | 仍把旧产品命名当成一级 tab 名使用 |
| `Docs/Stage2_Blueprint.md` / `Docs/Stage2_Blueprint_0328_Checklist.md` | `闲人` | `闲聊` | 场景模块换成了另一套旧词，大师模块跟 runtime UI 接近 |
| `Docs/Stage_3_Codebase_Audit.md` | `闲虾 / xianxia` | `闲聊 / masters` | 已经意识到代码与旧文档冲突，但还没有给出四层词典 |

这会直接带来三类治理问题：

1. 同一模块在蓝图、实现、统计、路由、日志里无法被稳定检索，自动化和人工 review 都会误判。
2. 新 worker 无法判断 `大师` 是模块名还是内容实体名，容易在未来文档或代码里继续放大漂移。
3. 如果后续要做追踪格式、验证镜像或配置注册，`闲人 / 咸虾 / 闲虾 / xianxia / xianren` 这组别名会让同一证据链断裂。

## 3. 稳定 SOTA / 成熟实践

对这类“产品词、UI 词、代码词、接口词”长期并存的仓库，成熟做法不是强行把四层都改成同一个字面量，而是建立“一模块一词典，一层一主名”的约束：

1. 每个模块在 `产品名 / UI 名 / 代码名 / 接口名` 四层各自只有一个 canonical token。
2. “模块名”和“模块内实体名”必须拆开治理。模块可以叫 `闲聊`，模块里的 persona 仍然可以叫 `大师`；这不是冲突，而是名词层级不同。
3. 接口名必须优先稳定，因为它会渗透到 deep-link、UserDefaults、环境变量、缓存 key、日志聚合和未来的协议兼容层。
4. 旧别名只能以“兼容 alias”或“迁移注记”存在，不能继续作为新标题、新变量名、新 checklist 文案的输入源。
5. 一旦代码层和旧文档层冲突，规范应该选择“代码现在怎么跑，词典就先怎么立”；否则词典会变成新的幻觉来源。

## 4. 面向本仓库的具体建议

### 4.1 建议采用的四层统一词典

| 模块 | 产品名 | UI 名 | 代码名 | 接口名 | 允许保留的实体词 | 不再作为模块名的新写法 |
| --- | --- | --- | --- | --- | --- | --- |
| 场景雷达模块 | `闲虾` | `闲虾` | `Xianxia` | `xianxia` | `话题`, `场景`, `topic`, `shard` | `闲人`, `咸虾`, `xianren` |
| 大师对话模块 | `闲聊` | `闲聊` | `Masters` | `masters` | `大师`, `会诊`, `master profile` | `大师` 作为模块名, `master` 作为模块 key |

这张表有两个关键解释：

1. 场景模块当前以 `闲虾` 为产品与 UI 主名，不再让 `咸虾` 和 `闲人` 轮流上位。原因很简单：当前 app shell 和页面头部都已经用 `闲虾`，这是最接近运行时真相的表述。
2. 大师模块当前以 `闲聊` 为产品与 UI 主名，但 `大师` 继续保留为模块内角色实体名。例如“搜索大师”“大师卡”“多大师会诊”都合法；只有当它被拿来充当 tab 名、一级模块名、stage 标题时才应视为漂移。

### 4.2 代码与文档的具体收敛规则

1. 一级模块标题、tab 名、蓝图 section 名、研究标题统一使用产品名：`闲虾`、`闲聊`。
2. 页面可见标题、底部导航、空态标题统一使用 UI 名；在本仓库里当前与产品名相同。
3. Swift 类型名、目录名、测试命名统一使用代码名：`Xianxia*`、`Master*` / `Masters*`。其中 `Master*` 允许保留在实体类型层，`Masters` 作为模块集合名使用。
4. 路由、UserDefaults、环境变量、协议字段统一使用接口名：`xianxia`、`masters`。对 `master` 单数 key 和 `xianren` 老 alias 只保留兼容读，不再新增写。

### 4.3 当前最值得优先修的三个漂移点

1. `MainTab.master` 应该列入后续低风险内部重命名队列，目标是与 `masters` 路由和模块目录对齐。
2. `MyProfileXianrenStats*` 应该列入跨模块命名修正队列，至少要在 Stage 3 的统计层停用 `xianren` 这个旧 alias。
3. `unifiedFeedService.mjs` 的 `咸虾 / 大师` 标题应该回归到 `闲虾 / 闲聊` 模块名；如果要展示 `大师`，应放在 card/entity copy 层，而不是 feed surface title 层。

## 5. 实施顺序

1. 先把这张词典作为 Stage 3 的文档基准，后续所有 Section 1-5 研究文档都按这张表用词。
2. 再收敛权威文档：优先修 `Docs/sparelife_blueprint.md`、`Docs/Stage2_Blueprint.md`、`Docs/Stage2_Blueprint_0328_Checklist.md` 的一级模块叫法。
3. 然后修内部低风险代码命名：`MainTab.master`、`MyProfileXianrenStats*`、共享 feed title/comment。
4. 最后再处理外部兼容：对已有 `master` / `xianren` 读取路径保留兼容 alias，确认没有 UserDefaults、deep-link、缓存迁移风险后再删老入口。

## 6. 风险

1. 如果直接改接口层 key，而不保留兼容读，`UserDefaults`、环境变量和旧 deep-link 会立即失效。
2. 如果把 `大师` 一刀切替换成 `闲聊`，会误伤大量本来合法的“实体词”语义，尤其是搜索文案、卡片标题和会诊 copy。
3. 如果没有先立词典就继续推进 Stage 3 其他 section，后续研究文档会再次把 `闲人 / 咸虾 / 闲虾 / xianxia / xianren` 混写，返工成本会比现在更高。
