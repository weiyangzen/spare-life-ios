# S2-01 App Shell Metadata

代码与旧文档冲突时，以代码为准。本报告只讨论根应用壳层命名与模块元数据，不扩展到 Section 2 之外的 UI 抽象问题。

## 当前代码现状

### 1. 根壳层的唯一运行入口已经收敛到 `MainTabView`

- 预览宿主当前直接挂载 `MainTabView()`，见 `spare-life-ios-preview-host/App/SpareLifePreviewHostApp.swift`。
- 根壳层 tab 身份定义在 `spare-life-ios-app/App/MainTabView.swift` 的 `enum MainTab`，当前 5 个 runtime tab 为：
  - `xianxia`
  - `master`
  - `earn_social`
  - `messages`
  - `my_profile`
- 当前中文 tab label 分别是：
  - `闲虾`
  - `闲聊`
  - `赚闲能`
  - `消息`
  - `我的`

### 2. 壳层元数据只统一了一半

`MainTab` 目前只统一了以下字段：

- `rawValue`
- `label`
- `icon`
- `selectedIcon`
- `isProminent`

但根壳层真正依赖的其他 metadata 仍未进入同一来源：

- `TabView.tabItem` 里的 label 和 icon 仍然是硬编码，没有复用 `MainTab.label` / `MainTab.icon`
- `SpareTabBar` 的 accessibility id 使用的是 `main-tab-\(tab.rawValue)`，说明 `rawValue` 已被当作机器 key
- 消息路由、跨 tab route、深链 route、analytics key 没有共享同一个注册表

这意味着当前仓库还没有一个“单一模块元数据表”，只有一个“部分 UI 元数据枚举”。

### 3. router target 与 tab 身份已经开始分叉

`ConversationRouter` 只暴露一个 `activeChatThread`，它不是通用 app shell router，只是消息线程展示状态：

- `spare-life-ios-app/App/ConversationRouter.swift`

与此同时，`Masters` 域模型里已经存在另一套目标命名：

- `MasterActionTarget.messages`
- `MasterActionTarget.earnSocial`
- `MasterActionTarget.profile`
- `MasterActionTarget.masters`

这套 target 名称与 `MainTab` 并不一致：

| 语义 | `MainTab` | `MasterActionTarget` | 当前 route path |
| --- | --- | --- | --- |
| 闲聊 | `master` | `masters` | `sparelife://masters/home?...` |
| 赚闲能 | `earn_social` | `earnSocial` | `sparelife://earn-social/...` |
| 我的 | `my_profile` | `profile` | `sparelife://my/profile?...` |
| 消息 | `messages` | `messages` | `sparelife://messages/...` |

当前代码现实不是“缺一个命名规范”，而是已经同时存在至少三套 machine naming：

- `MainTab.rawValue`
- `MasterActionTarget.rawValue`
- `sparelife://...` path segment

### 4. deep-link key 目前是字符串分散写法，没有统一消费者

当前可见的 deep-link / route 字符串主要散落在：

- `spare-life-ios-app/Features/Masters/MasterExperienceStore.swift`
- `spare-life-ios-app/Features/EarnSocial/EarnSocialExperienceStore.swift`

典型样例如下：

- `sparelife://my/profile?highlight=memory`
- `sparelife://earn-social/market?lane=jobSeek&topic=...`
- `sparelife://messages/self?draft=...`
- `sparelife://masters/home?domain=...`
- `sparelife://messages/thread?lane=...&counterpart=...`

但在 app shell 层当前没有发现以下统一入口：

- `onOpenURL`
- deep-link dispatcher
- route parser
- 统一的 typed route enum

因此这些字符串当前更像“写进状态模型里的未来路由意图”，不是已接线的根壳层 contract。

### 5. analytics key 在 root shell 层尚未成形

根壳层与各 tab 当前没有统一 analytics key。代码里只看到共享 feed 卡片层的最小事件语义：

- `spare-life-ios-app/Features/Shared/FeedCardProtocol.swift`
  - `FeedCardEvent.Action.impression`
  - `FeedCardEvent.Action.tap`
  - `FeedCardEvent.Action.ctaTap`
  - `FeedCardEvent.Action.swipeAway`

这说明仓库并非完全没有“埋点事件”的概念，但它还停留在 card interaction 级别，没有提升为：

- shell screen key
- tab selected key
- router target key
- deep-link source / target key

### 6. 目前最真实的命名基线

如果只看当前 runtime code，最接近“运行真相”的 top-level surface 名称其实是：

- 代码域名：`xianxia`, `masters`, `earn_social`, `messages`, `my_profile`
- UI label：`闲虾`, `闲聊`, `赚闲能`, `消息`, `我的`

其中只有 `xianxia` / `messages` 接近一致；其余 3 个 surface 都存在至少两套命名。

## 当前文档偏差

### 1. Xianxia 名称长期漂移

`Docs/Stage_3_Codebase_Audit.md` 已明确记录同一模块同时出现：

- `闲人`
- `咸虾`
- `闲虾`
- `xianxia`

旧文档仍然保留了这种漂移：

- `Docs/Stage1.1-1.2_todos.md` 使用 `闲人`
- `Docs/ValidationLog_UnifiedUI_FUNC_Batch1.md` 使用 `咸虾`
- 当前 runtime UI 使用 `闲虾`

这不是纯文案问题。它已经影响：

- 入口说明
- preview host 工程名
- 自动化测试叙述
- 模块身份认知

### 2. Masters 名称在“模块名”和“产品名”之间摇摆

当前 tab label 是 `闲聊`，但旧文档大量使用 `大师` 作为模块名，甚至把目录页和对话页都合称“大师”。

现实上这两者并不等价：

- `闲聊` 是产品表层入口名
- `masters` 是代码域模型名
- `大师` 更像资产和角色集合名

旧文档把三者混写，导致“模块名”和“内容实体名”边界不清。

### 3. 文档常把 preview host、历史 root、当前 root 混成一件事

例如：

- `Docs/Stage1.1-1.2_todos.md` 仍使用 `Stage1MastersPreviewRootView`、`MasterHomeView`
- 当前 runtime root 实际是 `MainTabView` + `MasterChatHomeView`

这类历史文档并不是错误资料，但它们不能继续被当作当前 app shell 元数据真相。

### 4. 文档默认把 route 命名当作已经统一

旧文档和验证日志经常直接描述“从某 tab 进入某页面”，但并未揭示：

- root tab id
- router target
- deep-link path
- analytics key

在当前代码里它们并未统一，更谈不上“同一个 source of truth”。

## 稳定 SOTA 或成熟实践

### 1. 顶层 surface 必须有一份单独的 canonical registry

成熟的 iOS app shell 不会把以下元数据分散到多个枚举、硬编码 label 和字符串 route 中：

- tab identity
- 显示名
- 机器 key
- deep-link root
- analytics screen key
- accessibility id
- router target

成熟实践是为顶层 surface 维护一个 registry，并从这份 registry 派生 UI 和路由配置。

### 2. 一份 metadata 同时承载“显示名”和“机器名”，但两者必须显式区分

稳定做法不是强迫 UI label 等于 machine key，而是明确区分：

- `displayTitle`
- `canonicalID`
- `analyticsKey`
- `deepLinkRoot`
- `legacyAliases`

这样才不会把“闲聊 / 大师 / masters”混在同一字段里。

### 3. deep-link path 应只保留一层 canonical token，兼容 alias 只用于解析

成熟实践通常是：

- 写入时只输出 canonical token
- 读取时临时兼容 legacy token
- 兼容层有明确退场顺序

也就是说，`my/profile`、`my_profile`、`profile` 这类历史变体可以临时被解析，但不能继续同时作为新写入格式存在。

### 4. analytics key 不应从 UI label 反推

成熟实践一般使用独立、稳定、不可翻译的 analytics key，例如：

- `shell.xianxia`
- `shell.masters`
- `shell.earn_social`
- `shell.messages`
- `shell.my_profile`

而不是从 `闲虾`、`闲聊` 这类文案反推事件名。

## 面向本仓库的具体建议

### 1. 为 Stage 3 明确一套 canonical top-level surface ID

基于当前代码现实和最小返工原则，建议把 top-level canonical ID 定为：

| Surface | Canonical ID | 当前显示名 |
| --- | --- | --- |
| Xianxia | `xianxia` | `闲虾` |
| Masters | `masters` | `闲聊` |
| Earn Social | `earn_social` | `赚闲能` |
| Messages | `messages` | `消息` |
| My Profile | `my_profile` | `我的` |

选择理由：

- `xianxia` 已是代码与配置里的稳定 token
- `masters` 比 `master` 更贴近当前模块边界和现有 `MasterActionTarget`
- `earn_social` 已存在于 `MainTab.rawValue`
- `messages` 已一致
- `my_profile` 已存在于 `MainTab.rawValue`

### 2. 明确区分 5 类字段，不再互相借名

建议后续根壳层 metadata 至少拆成这 5 类：

- `surfaceID`
  - 例：`masters`
- `displayTitle`
  - 例：`闲聊`
- `routerTarget`
  - 例：`mastersHome`
- `deepLinkRoot`
  - 例：`masters`
- `analyticsKey`
  - 例：`shell.masters`

关键点：

- `displayTitle` 允许中文
- 其余字段只使用稳定 machine key
- `routerTarget` 不再直接复用 deep-link path 字符串

### 3. 不建议继续把 `MainTab` 当成唯一命名源

`MainTab` 已经是 UI 枚举，但它不是完整 metadata registry。建议后续演进为：

- `AppShellSurface`
  - 负责 canonical metadata
- `MainTab`
  - 只负责 tab UI 选择，或直接由 `AppShellSurface` 派生

原因是 `MainTab.master` 这种单数字段已经落后于当前 `masters` 模块现实。

### 4. 统一 route 输出格式，停止新写入 legacy path

建议新 contract 统一输出：

- `sparelife://xianxia/...`
- `sparelife://masters/...`
- `sparelife://earn_social/...`
- `sparelife://messages/...`
- `sparelife://my_profile/...`

这比当前混用：

- `earn-social`
- `my/profile`
- `masters/home`

更适合作为单一 machine contract。

如果产品层仍希望对外展示更自然的 URL 片段，可以在解析层做 alias，不要在写入层继续混写。

### 5. analytics key 只在 canonical metadata 中声明

建议 tab / shell analytics 不从各页面自行拼接，统一来自 surface registry，例如：

| Surface | Analytics Key |
| --- | --- |
| Xianxia | `shell.xianxia` |
| Masters | `shell.masters` |
| Earn Social | `shell.earn_social` |
| Messages | `shell.messages` |
| My Profile | `shell.my_profile` |

这样才能和 deep-link root、router target 保持一一对应。

### 6. 为旧文档与旧 route 保留临时 alias，但不再作为真相

建议 alias 仅用于读，不用于写：

| Canonical ID | 临时兼容 alias |
| --- | --- |
| `xianxia` | `闲人`, `咸虾`, `闲虾` |
| `masters` | `master`, `大师`, `闲聊` |
| `earn_social` | `earn-social`, `earnSocial` |
| `my_profile` | `profile`, `my/profile`, `myProfile` |

这样既不会强行抹掉历史资料，也不会继续制造新漂移。

## 实施顺序

1. 先新增根壳层 metadata registry 文档与类型设计，明确 canonical ID、displayTitle、deepLinkRoot、analyticsKey、legacyAliases。
2. 再让 `MainTab`、`SpareTabBar`、`TabView.tabItem` 改为引用同一份 metadata，消除 label/icon 硬编码重复。
3. 把 `MasterActionTarget`、`ConversationRouter` 和未来 root router 从“字符串或弱枚举”迁移为基于 canonical surface 的 typed target。
4. 统一新写入的 deep-link path，仅在解析层保留 `earn-social`、`my/profile` 等旧别名。
5. 最后清理 Stage 1 / Stage 2 文档中的历史模块名，把“历史叫法”降级为注释或迁移说明。

## 风险

### 1. `MainTab.rawValue` 已被测试与 accessibility 标识消费

例如 `main-tab-\(tab.rawValue)` 已经直接进入 accessibility identifier。若直接改动现有 raw value，会波及：

- UI 自动化
- 快照测试
- 潜在外部脚本

因此更稳的做法是先引入 canonical registry，再分阶段迁移 raw value，而不是一次性硬改。

### 2. 持久化 route 字符串可能已经进入本地状态

`MasterLocalStateStore` 已把 CTA 的 `route` / `target` 直接编码进本地记录。若未来 route format 改名，需要兼容旧持久化数据的解析。

### 3. 文档中的中文模块名并非都该删掉

`闲聊`、`闲虾` 是产品层 label，不应被误删。真正要删除的是“用中文展示名充当 machine key”的写法。

### 4. 当前还没有 deep-link dispatcher

这意味着 metadata 统一后，真正的收益要等到 root router 和 deep-link parser 接入后才能完全体现。也正因为如此，现在是定义 canonical metadata 的最好窗口期，改动成本最低。
