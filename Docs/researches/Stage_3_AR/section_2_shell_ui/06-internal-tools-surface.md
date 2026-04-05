# S2-06 Internal Tools Surface

代码与旧文档冲突时，以代码为准。本报告只讨论 `Features/Infrastructure` 诊断页在信息架构中的位置：它们应被定义为内部工具入口、开发预览能力，还是独立运营面板；不扩展到产品功能新增、OpenClaw plugin 实现细节或非 Section 2 的路由重构。

## 当前代码现状

### 1. 当前仓库存在 4 个 Infrastructure 诊断页，但 app shell 没有任何正式入口

`spare-life-ios-app/Features/Infrastructure/` 当前包含：

- `SQLiteBackendDashboardView.swift`
- `OpenClawPluginView.swift`
- `SecurityRiskControlView.swift`
- `AIMemoryMatchingView.swift`

但 `spare-life-ios-app/App/MainTabView.swift` 当前只承载：

- 5 个产品 tab
  - `xianxia`
  - `master`
  - `earnSocial`
  - `messages`
  - `myProfile`
- 一个根层 `ConversationRouter`
- 一个 `fullScreenCover` 的消息线程入口

`spare-life-ios-app/App/ConversationRouter.swift` 也只负责 `activeChatThread`。当前没有：

- Internal Tools tab
- debug menu route
- 隐藏手势入口
- deep link route
- diagnostics root

因此从 active app shell 角度看，这 4 个页面目前是“已编译但未进入信息架构”的隐藏 surface。

### 2. 这 4 个页面目前都更像本地 mock 诊断面，而不是 live 运营面板

四个页面都有共同模式：

- `@StateObject` store
- `loadState`
- `.task { store.load() }`
- `Task.sleep(...)`
- 本地写死 mock 数据
- `.refreshable { reload() }`

具体来看：

#### `SQLiteBackendDashboardView`

`SQLiteBackendDashboardStore.load()` 在休眠后直接写入：

- `dbVersion = 8`
- `totalSizeBytes = 4_823_040`
- mock `migrations`
- mock `repositories`

它看起来像本地数据库控制面板，但当前代码并没有真实读取 repository/runtime 状态。

#### `OpenClawPluginView`

`OpenClawPluginStore.load()` 在休眠后直接填充：

- `adapters`
- `recentEvents`
- `schemas`
- `handlers`

此前 Section 5 已有研究明确指出它当前是 mock diagnostic surface，不是 live plugin status 面板。

#### `SecurityRiskControlView`

`SecurityRiskControlStore.load()` 在休眠后直接填充：

- `auditLogs`
- `blockRules`
- `reports`
- `privacyBoundaries`

页面语义像“风控后台”，但当前仍是本地构造数据。

#### `AIMemoryMatchingView`

`AIMemoryMatchingStore.load()` 在休眠后直接填充：

- `memories`
- `recentMatches`
- `promptTemplates`
- `totalRecallRequests`
- `avgRecallLatencyMs`

它表达的是 AI 记忆/匹配的诊断视角，不是当前用户可见功能路径。

因此这 4 个页面当前真实属性更接近：

- 诊断型开发预览页面

而不是：

- 已接线的内部运营面板

### 3. 它们已经被编进共享产物，但“被编译”不等于“被纳入信息架构”

`spare-life-ios-app/Package.swift` 把 `App` 与 `Features` 一起编入 `SpareLifeCore`，所以 `Features/Infrastructure` 确实进入当前 Swift package/runtime 编译边界。

同时，`spare-life-ios-preview-host/SpareLifePreviewHost.xcodeproj/project.pbxproj` 和 `spare-life-ios-preview-host/闲人.xcodeproj/project.pbxproj` 也都显式把这 4 个文件纳入 `Infrastructure` group。

但这只说明：

- 这些页面是 repo 的真实代码资产
- 它们可被 preview host / Xcode 打开、编译、运行

并不说明：

- 它们在产品导航中已经有治理过的入口

### 4. preview host 当前也没有真正的诊断目录，只是把这些文件编了进去

`spare-life-ios-preview-host/README.md` 对 preview host 的定义是：

- 一个在真实 iPhone / iPad 上运行现有 SwiftUI surface 的最小 host app

`spare-life-ios-preview-host/App/SpareLifePreviewHostApp.swift` 当前实际渲染的根页面仍然只是：

- `MainTabView()`

所以 preview host 的真实现状是：

- 编译这些 Infrastructure 页面
- 但没有提供一个明确的 diagnostics catalog / internal tools home

这意味着它们虽然更接近“开发预览能力”，却连这层能力本身也还没有被显式建模。

### 5. 产品信息架构里已经有一个更像“用户可见控制面”的替代路径：`PrivacyLocalBackendView`

`spare-life-ios-app/Features/MyProfile/PrivacyLocalBackendView.swift` 当前是：

- “我的 · 隐私与本地后端控制”

并且 `spare-life-ios-app/Features/MyProfile/MyProfileView.swift` 已经通过 `NavigationLink` 把它挂进“我的”页。

这很关键，因为它说明当前仓库其实已经在用另一条路径表达“用户能看见的底层控制”：

- 用户可见、带信息架构归属的是 `PrivacyLocalBackendView`
- 低层细颗粒诊断页却没有进入同一条产品导航

所以当前最真实的边界不是“底层能力统一暴露给用户了”，而是：

- 用户可见控制面只暴露了一部分
- 其他诊断页仍停留在隐藏开发 surface

### 6. 以当前代码为准，它们既不是正式 internal-tools 入口，也不是独立运营面板

判断一个页面是不是“内部工具入口”，至少要看到：

- 明确入口
- 明确分组
- 明确使用对象
- 至少 basic 的 mock/live provenance 标识

当前都没有。

判断一个页面是不是“独立运营面板”，至少要看到：

- live 数据
- 权限/角色
- 审计/可追溯
- 运营场景 ownership
- 与产品 IA 分离的明确治理

当前也都没有。

所以按现状判断，它们最准确的定义是：

- 未治理完成的开发诊断/预览 surface

## 当前文档偏差

### 1. 旧蓝图把这些底层页面列为已完成模块，容易让人误以为它们已经是正式产品或运营面板

`Docs/sparelife_blueprint.md` 在“底层”区块把以下四项都列成独立模块，并且 UIUX/FUNC 都已勾选：

- iOS 本地 SQLite 后端
- OpenClaw 插件
- AI 记忆与匹配能力
- 安全与风控

如果只看旧文档，很容易得出更强结论：

- 这些面板已经是成熟产品或成熟运营面

但按当前代码，至少在 IA 层这结论不成立。它们没有进入 app shell，也没有形成受治理的 internal tools surface。

### 2. 旧蓝图同时又把“隐私与本地后端控制”放在“我的”页，这与当前四个 Infrastructure 页面产生了角色重叠

`Docs/sparelife_blueprint.md` 还明确要求：

- “我的”页应让用户感知数据真的在本地，且可以管理
- 未来可有渠道同步授权开关

当前代码真正落到产品导航里的，正是 `PrivacyLocalBackendView`。这说明旧文档其实混用了两种 surface：

- 用户可见控制面
- 工程/诊断面

但没有把它们在 IA 上彻底分开。

### 3. `OpenClawPluginView` 的旧文档语义明显强于当前代码

Section 5 研究已经明确：

- `OpenClawPluginView.swift` 当前是 mock diagnostic surface
- 不能被当作 app 与 plugin runtime 已接线的证据

因此如果继续把它写成“独立运营面板”或“当前统一渠道已可观测入口”，就会直接违背代码现实。

## 稳定 SOTA 或成熟实践

### 1. 成熟仓库通常把“产品 IA”和“诊断/运营 IA”分开治理

较稳的做法通常是三分法：

- 用户可见 surface
  - 设置、隐私、数据导出、授权控制
- debug/internal tools
  - mock inspector
  - local DB viewer
  - gateway probe
  - schema/debug panel
- 独立 ops surface
  - live 指标
  - 权限系统
  - 审计日志
  - 多环境切换
  - operator workflow

这三者的进入条件、风险模型和使用对象完全不同，不适合继续放在同一信息架构层次里。

### 2. 移动端里的“独立运营面板”门槛通常很高

只有在以下条件都比较明确时，移动端才适合承载独立 ops surface：

- 真实 live 数据接入
- 明确 operator 身份与鉴权
- 审计记录
- 环境与权限隔离
- 不是由 web/internal console 更适合承载

当前这 4 个页面都不满足这个门槛，因此不应被定义为“独立运营面板”。

### 3. 对未接线或 mock 占主导的诊断页，更成熟的归位是“开发预览能力”

当页面主要承担的是：

- 结构预演
- mock 数据验收
- UI 交互验证
- 未来 live surface 的占位

更成熟的归类通常是：

- preview host catalog
- debug-only internal tools
- hidden diagnostics

而不是直接放进产品壳层，制造“这些能力已经对用户或运营正式开放”的假象。

### 4. 用户可见的底层控制应只保留对用户有意义的那一层抽象

比如：

- 本地数据库是否健康
- 最近备份时间
- 授权范围
- 清理本地缓存
- 是否允许云端同步

这些是用户能理解且能承担后果的控制面。

而像：

- migration timeline
- repository read/write count
- handler error rate
- schema validation count
- risk-control rule inventory

更适合 internal tools 或 operator surface，不应直接塞进主产品 IA。

## 面向本仓库的具体建议

### 1. 当前最合理的结论：这 4 个 `Infrastructure` 页面应被重新定义为“开发预览能力”，不是独立运营面板

原因很直接：

- 没有 app shell 正式入口
- 没有统一 diagnostics home
- 没有 live 数据
- 没有角色鉴权
- 没有 operator audit

所以它们当前最准确的 IA 定位应是：

- developer preview / diagnostic surfaces

### 2. 如果后续需要 on-device 团队验证，应新增一个 debug-only `Internal Tools` 入口，而不是把这 4 页直接塞进 5-tab IA

对当前仓库，更稳的做法是：

- 产品主 IA 继续保持 5 tab 不变
- preview host 或 debug build 下新增单独 `InternalToolsHome`
- 由该入口承接：
  - SQLite diagnostics
  - OpenClaw diagnostics
  - AI memory diagnostics
  - security/risk diagnostics

这样既能满足团队验证，又不会污染产品导航。

### 3. 用户可见的“底层控制”应继续归属 `我的` 页，而不是交给 Infrastructure 目录

以当前代码现实看，`PrivacyLocalBackendView` 更像用户真正能理解的 surface。建议继续把以下内容留在用户 IA：

- 本地数据库健康状态
- 备份
- 清理
- 授权范围
- 面向用户的隐私控制

而不要让用户直接进入：

- repository 级统计
- plugin handler 状态
- 风控规则清单
- prompt 模板计数

### 4. 四个页面后续应按“用户控制面 / internal tools / future ops”三类拆账

建议按现状先这样归类：

| 页面 | 当前最合理归类 | 备注 |
| --- | --- | --- |
| `PrivacyLocalBackendView` | 用户控制面 | 已在 `我的` 页有正式入口 |
| `SQLiteBackendDashboardView` | internal diagnostic preview | 与用户控制面有主题重叠，但粒度更工程化 |
| `OpenClawPluginView` | internal diagnostic preview | 目前是 mock contract/debug surface |
| `AIMemoryMatchingView` | internal diagnostic preview | 偏 AI pipeline 诊断，不是用户页 |
| `SecurityRiskControlView` | internal diagnostic preview | 当前是 mock 风控后台，不适合放入主产品 IA |

### 5. 为防止文档继续漂移，应给每个诊断页加“provenance 口径”

后续文档和命名建议统一写清：

- `mock diagnostic`
- `local runtime diagnostic`
- `live internal tool`

以当前代码为准，这 4 个页面至少现在都不该被写成：

- live operator console
- shipped user-facing control panel

### 6. 只有满足升级门槛后，页面才允许从“开发预览能力”升级到“内部工具入口”或“独立运营面板”

建议的升级门槛：

#### 升级到 internal tool

- 有统一入口
- 有 mock/live provenance 标识
- 有明确目标用户
- 至少具备 debug/build gating

#### 升级到独立 ops surface

- live 数据源
- 权限/角色控制
- 审计与追溯
- 明确 operator workflow
- 不与 web/backend console 重复

当前这 4 页都未满足第二层门槛。

## 实施顺序

1. 先在文档上把 `Features/Infrastructure` 统一口径改成“开发诊断/预览 surface”。
2. 明确 `PrivacyLocalBackendView` 是用户可见控制面，继续放在 `我的` 页，不与低层 diagnostics 混写。
3. 如果团队确实需要真机访问这些页面，先在 preview host 或 debug build 增加一个单独 `Internal Tools` 根入口，而不是改主 tab IA。
4. 为每个 diagnostics page 增加 provenance 标签，区分 mock / local / live。
5. 只有某个页面完成 live 接线、权限与审计后，再单独评估是否提升为 internal tool，绝不整体提升为“独立运营面板”。

## 风险

- 如果把当前 mock 诊断页当成独立运营面板，会制造“能力已接线”的虚假运行真相。
- 如果把低层 diagnostics 直接塞进产品 IA，会污染用户导航并暴露用户无法理解的工程语义。
- 如果不区分 `PrivacyLocalBackendView` 与 `SQLiteBackendDashboardView` 的角色，会让“用户控制面”和“工程诊断面”双重重复、边界混乱。
- 如果 release 路径未来不加 gating 就开放这些页面，安全与风控相关信息可能以未治理状态暴露。
- 如果继续维持“编译进工程但没有治理入口”的状态，后续文档会反复把它们误写成已正式纳入信息架构的功能面。
