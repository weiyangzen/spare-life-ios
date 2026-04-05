# S2-03 Shared Page Chrome

代码与旧文档冲突时，以代码为准。本报告只讨论首页通用 page chrome 的抽象边界：标题、搜索、筛选、顶部轻模块与刷新行为如何统一，不扩展到 Section 2 之外的路由或持久化实现。

## 当前代码现状

### 1. 根应用壳层只统一了 tab 和底栏，没有统一首页 chrome

`spare-life-ios-app/App/MainTabView.swift` 当前只负责：

- `TabView(selection: $selectedTab)`
- 自定义底部浮动 `SpareTabBar`
- 根层 `ConversationRouter`
- 根层 `fullScreenCover` 的消息线程呈现

每个首页自己的顶区则完全分散在各 feature root view：

- `spare-life-ios-app/Features/Xianxia/XianxiaHomeView.swift`
- `spare-life-ios-app/Features/Masters/MasterChatHomeView.swift`
- `spare-life-ios-app/Features/EarnSocial/EarnSocialHomeView.swift`
- `spare-life-ios-app/Features/CompanionChat/ConversationHubView.swift`
- `spare-life-ios-app/Features/MyProfile/MyProfileView.swift`

当前仓库真实状态不是“已经有 page chrome，只差再复用一点”，而是“每个首页各自定义 chrome，shared layer 只统一到卡片和状态视图这一层”。

### 2. 标题区、背景层和导航栏处理已经出现明显重复

当前至少存在 3 套首页 chrome 家族：

| Surface | 顶区实现 | 导航策略 | 背景策略 |
| --- | --- | --- | --- |
| `xianxia` | 自定义 `topBar`，只显示标题和总数 | `spareNavigationBarHidden(true)` | 手写黄白渐变 |
| `masters` | 自定义 `header + searchBar` | `spareNavigationBarHidden(true)` | 手写黄白渐变 |
| `earn_social` | 自定义 `header + categoryTabs + preferenceButton` | `spareNavigationBarHidden(true)` | 手写黄白渐变 |
| `messages` | 用系统 `navigationTitle + searchable + toolbar` | 保留导航栏 | 页面内手写黄白渐变 |
| `my_profile` | 无通用标题区，直接进入 hero/dashboard | `spareNavigationBarHidden(true)` | `ProfileAmbientBackground()` |

这说明当前复用粒度停在“视觉风格相似”，还没有形成“同类首页共享一套 chrome contract”。

### 3. 搜索和筛选语义已经存在，但入口位置完全不一致

#### `masters`

`MasterChatHomeView` 顶部自带 inline `TextField("搜索大师或关键词", text: $store.query)`，但筛选只是 store 层能力：

- `MasterExperienceStore` 有 `selectedDomainID`
- `MasterExperienceStore.filteredMasters` 会按 `selectedDomainID` 和 `query` 过滤
- 但首页 UI 当前没有任何领域 filter chips

也就是说，代码已经有“搜索 + 领域筛选”的一半 contract，但 chrome 没把它完整表达出来。

#### `messages`

`ConversationHubView` 走的是另一套做法：

- 搜索通过 `spareNavigationSearchable(text:prompt:)`
- 筛选和排序塞进导航栏 `Menu`
- `selectedKind` 在 store 中
- `sortMode` 却在 view 本地 `@State`

同样是首页筛选，`messages` 把能力分散到了 store、本地状态和导航栏菜单三个位置。

#### `earn_social`

`EarnSocialHomeView` 没有自由文本搜索，主控件是顶部水平 `categoryTabs`，再加一个“我的偏好”按钮。它实际上把“筛选”和“顶部轻操作”混写到了同一个 header。

#### `xianxia`

`XianxiaHomeView` 目前没有搜索和筛选 UI，只有标题与 topic 总数。和旧蓝图预期相比，这不是“样式没统一”，而是入口本身还没有落到当前 runtime。

### 4. 顶部轻模块的数据钩子已经散落存在，但几乎都没有进入首页 chrome

旧蓝图期望每个首页在主内容区之上还有“轻模块”，当前代码只完成了部分数据准备，没有形成统一展示层：

- `MasterExperienceStore.recentStripSessions` 已能提供“最近聊过谁”的 strip 数据，但 `MasterChatHomeView` 没渲染
- `ConversationHubStore.recentContacts` 已能提供“最近聊天”数据，但 `ConversationHubView` 没渲染
- `EarnSocialHomeView` 顶部只有 category chips 和偏好按钮，没有“闲能余额 / 今日可赚 / 快捷筛选”
- `XianxiaHomeView` 没有“扫码入口 / 最近扫过 / 热门场景”轻模块

这意味着“顶部轻模块”目前不是缺少 shared UI 组件，而是没有统一 chrome slot 来接它们。

### 5. 刷新行为已经共享到一部分状态视图，但还没有被 page chrome 接管

当前刷新 contract 依附在各页的内容容器上，而不是 chrome：

- `XianxiaHomeView`
  - loaded feed 上有 `.refreshable`
  - empty/error 通过局部按钮触发 `vm.refresh()`
- `MasterChatHomeView`
  - loaded scroll 上有 `.refreshable`
  - error 用 `ErrorStateView` retry
  - empty 用“清空筛选”按钮而非刷新
- `ConversationHubView`
  - loaded `List` 上有 `.refreshable`
  - error 直接 `store.retry()`
- `MyProfileView`
  - loaded scroll 上有 `.refreshable`
- `EarnSocialHomeView`
  - 没有 refreshable，也没有 empty/error contract

共享层已有一些基础件：

- `spare-life-ios-app/Features/Shared/UnifiedWaterfallFeed.swift`
  - 统一 loading / empty / error / pull-to-refresh
- `spare-life-ios-app/App/DesignSystem/DesignTokens.swift`
  - `EmptyStateView`
  - `ErrorStateView`
- `spare-life-ios-app/App/DesignSystem/PlatformCompat.swift`
  - `spareNavigationSearchable`
- `spare-life-ios-app/Features/Shared/FeedCardProtocol.swift`
  - `FeedKindFilterBar`
  - `FeedSectionHeader`
  - `FeedPinnedBanner`

但这些 shared primitive 仍然停在“内容区和局部控件”，没有一个“首页 chrome 组合器”把标题、搜索、筛选、轻模块和刷新控制成一份统一 contract。

### 6. `UnifiedWaterfallFeed` 已经证明 shared layer 存在，但它停在 chrome 下方

`UnifiedWaterfallFeed` 统一了：

- skeleton
- empty state
- error state
- pull-to-refresh
- 滚动 offset 观测

但它没有统一：

- 页面标题
- 搜索栏摆放
- 筛选 chips 位置
- 顶部轻模块
- 页面级 action / source badge / refresh affordance

因此它更像“feed content container”，不是“page chrome”。

## 当前文档偏差

### 1. 全局蓝图要求的是统一页面骨架，但当前 runtime 还没真正拥有这层骨架

`Docs/sparelife_blueprint.md` 统一页面骨架明确写了：

- 顶部导航区：标题、搜索、筛选、切换器、必要的全局操作
- 顶部轻量级固定模块：例如最近聊过谁、闲能余额、同步度、扫码入口
- 主内容区：瀑布流卡片或 IM 列表

当前代码里只有“主内容区”开始共享；顶区和轻模块仍然分散在各首页。

### 2. `xianxia` 旧文档对 page chrome 的描述明显强于现有代码

旧蓝图要求 `xianxia` 首页具备：

- 左侧标题 `咸虾`
- 右侧扫码入口
- 标题下的搜索和场景筛选 chips
- “最近扫过”或“现在最热场景”轻模块

当前 `XianxiaHomeView` 真实只有：

- 标题 `闲虾`
- 话题总数
- feed content

因此这部分不是“共享组件没抽出来”，而是旧文档明显领先于当前 runtime。

### 3. `masters` 旧文档要求“最近聊过谁 + 领域 chips”，当前只完成了 store 侧准备

旧蓝图要求：

- 顶部标题
- 固定“最近聊过谁”横向条
- 领域筛选 chips

当前代码现实：

- 标题与搜索框已经有
- `recentStripSessions` 已有数据钩子，但未渲染
- `selectedDomainID` 已在 store 中，但未渲染筛选 chips

也就是说，这一页的文档偏差不是“完全没有”，而是“UI 只落了一半”。

### 4. `earn_social` 旧文档要求有顶部统计轻模块，当前首页没有

旧蓝图要求：

- 顶部固定区展示闲能余额、今日可赚、快捷筛选
- 首屏展示 6 条赛道 chips

当前 `EarnSocialHomeView` 只有：

- category tabs
- 偏好按钮
- mock card waterfall

顶部轻模块在当前 runtime 并不存在。

### 5. `messages` 旧文档要求“最近聊天区”固定在列表上方，当前 store 有数据但 UI 未接

旧蓝图要求：

- 顶部标题 `消息`
- 右侧搜索、发起新会话或筛选入口
- 最上方固定最近聊天区
- 下方 IM 列表

当前 `ConversationHubView` 只实现了：

- `navigationTitle`
- `searchable`
- toolbar menu
- IM list

`recentContacts` 仍停在 store 计算层，没有进入首页 chrome。

## 稳定 SOTA 或成熟实践

### 1. page chrome 应该独立于 feed/list 容器，而不是继续塞进每个首页根视图

成熟做法通常把首页拆成两层：

- `PageChrome`
  - 标题、搜索、筛选、轻模块、状态 badge、页面级 action
- `ContentContainer`
  - waterfall feed / list / dashboard

这样 shared layer 才能稳定复用，而不会把卡片布局、导航、路由和 chrome 混成一个大 view。

### 2. “统一”不等于所有首页长一样，而是同类页面共用同一语义 contract

对当前仓库，更合理的成熟模式是分家族统一：

- `FeedHomeChrome`
  - 适合 `xianxia / masters / earn_social`
- `ListHomeChrome`
  - 适合 `messages`
- `DashboardChrome`
  - 适合 `my_profile`

真正需要统一的是：

- 标题语义
- 搜索入口语义
- 筛选入口语义
- 顶部轻模块插槽
- refresh affordance

而不是把 `messages` 和 `my_profile` 强行做成和 feed 首页同一个头部结构。

### 3. 搜索、筛选、轻模块要有固定 slot，不要继续让每页自己发明摆放规则

稳定实践通常会把 chrome slot 明确成：

- `title`
- `subtitle/status`
- `search`
- `primaryFilters`
- `utilityStrip`
- `trailingActions`
- `refreshPolicy`

页面可以按需隐藏某些 slot，但 slot 的含义和层级顺序不能每页重写。

### 4. refresh 是 page-level contract，不只是 feed-level modifier

成熟实践里，刷新应该由页面 contract 明确表达：

- 页面是否可刷新
- 刷新触发点是 pull-to-refresh、按钮，还是两者都有
- 当前数据源是 live / cached / degraded / mock
- 空态和错误态是否允许同一个 refresh action 重试

当前仓库的 shared layer 已有 `refreshable` 和空错态组件，下一步不是另造一套状态视图，而是把 refresh contract 上移到 chrome。

### 5. 优先复用现有 shared primitive，不要为了“抽象”重写已有基础件

本仓库已经有成熟的底层积木：

- `spareNavigationSearchable`
- `UnifiedWaterfallFeed`
- `FeedKindFilterBar`
- `FeedSectionHeader`
- `FeedPinnedBanner`
- `EmptyStateView`
- `ErrorStateView`

因此 S2-03 的合理方向是“补 page chrome 组合层”，而不是推翻现有卡片流和状态视图。

## 面向本仓库的具体建议

### 1. 在 `Features/Shared` 层定义一份最小 `PageChrome` 契约

建议后续共享抽象至少拆成以下语义结构：

| 字段 | 用途 |
| --- | --- |
| `title` | 页面主标题 |
| `subtitle` / `statusBadge` | 数据来源、数量、缓存/降级提示 |
| `searchMode` | `none / inlineField / navigationDrawer` |
| `filters` | 顶部主筛选 chips 或菜单项 |
| `utilityStrip` | 最近聊天、最近场景、余额摘要等轻模块 |
| `trailingActions` | 扫码、偏好、发起会话等页面级按钮 |
| `refreshPolicy` | 是否可刷新、统一的 refresh action、按钮文案 |

关键点不是命名本身，而是让每个首页把这些信息提交成一份结构化 contract，而不是直接在 view body 里手写布局。

### 2. 先定义 3 个 chrome 变体，不要一开始做成“万能首页头部”

建议 Stage 3 采用以下边界：

#### A. `FeedHomeChrome`

用于：

- `XianxiaHomeView`
- `MasterChatHomeView`
- `EarnSocialHomeView`

特点：

- 顶部大标题
- 可选 inline search
- 横向 filter chips
- 可选 utility strip
- 下方接 waterfall feed

#### B. `ListHomeChrome`

用于：

- `ConversationHubView`

特点：

- 允许继续使用系统导航栏标题
- 搜索走 `navigationDrawer`
- toolbar 继续承载 menu/filter
- utility strip 放在 list 上方，但仍然属于 chrome，而不是 list row

#### C. `DashboardChrome`

用于：

- `MyProfileView`

特点：

- 保留 profile hero 主视觉
- 不强行要求搜索和筛选
- 只共享标题/状态/刷新/action 的最小 contract

### 3. 把当前已有但未接线的数据钩子优先纳入 chrome slot

这是当前仓库最小返工、收益最高的切入点：

- `masters`
  - 把 `recentStripSessions` 接成 utility strip
  - 把 `selectedDomainID` 接成 filter chips
- `messages`
  - 把 `recentContacts` 接成 utility strip
  - 把当前 toolbar filter/sort 归入统一 chrome model
- `xianxia`
  - 先把标题、统计、未来扫码入口纳入统一 chrome slot
  - 搜索/筛选保持 `none`，不要伪造不存在的 runtime 能力
- `earn_social`
  - 把 `selectedCategory` 纳入 chrome filters
  - 将“我的偏好”视为 trailing action，而不是 header 私有布局

### 4. 保持 `UnifiedWaterfallFeed` 只负责内容区，不把 chrome 强塞进去

更稳的组合关系应当是：

1. `PageChrome`
2. `ContentContainer`
3. `Empty/Error/Loading` 继续复用 shared state views

不要把标题、搜索、utility strip 混进 `UnifiedWaterfallFeed`，否则它会同时承担：

- 页面骨架
- 列表状态
- 布局测量
- 滚动监控

这会把一个原本清晰的 shared feed primitive 再次做大。

### 5. 明确 source-of-truth badge，不再让页面自己暗示“这是实时/缓存/mock”

当前各页对数据来源表达不一致：

- `masters` 有 `catalogSourceMode`
- `xianxia` 有 `loadedFromCache`
- `earn_social` 当前实际是 mock fixtures
- `messages` 当前是内存 mock data

建议 chrome 层统一提供 source badge / subtitle contract，至少区分：

- `live`
- `cached`
- `degraded`
- `mock`

这样页面不会继续把“运行真相”藏在局部 copy 里。

## 实施顺序和风险

### 实施顺序

1. 先在 shared 层定义 `PageChrome` 语义模型和 3 个 chrome family 的边界，不先改业务页面。
2. 先接 `masters` 和 `messages`。
   这两页收益最高，因为数据钩子已经存在：
   - `recentStripSessions`
   - `recentContacts`
   - `selectedDomainID`
   - `selectedKind`
3. 再接 `xianxia` 和 `earn_social`。
   这两页当前 runtime 能力更少，适合在 contract 稳定后按真实能力填充 slot。
4. 最后决定 `my_profile` 是否只接最小 `DashboardChrome`，不要为了“一致”牺牲现有 hero/dashboard 结构。

### 风险

- 如果把 `my_profile` 强行并入 feed-style chrome，会直接破坏当前 profile hero 结构。
- 如果把 page chrome 和 S2-04 的恢复状态一起设计，会把视觉骨架和状态持久化耦合过深。
- 如果为了“统一”把不存在的搜索/筛选能力先画出来，会再次制造“文档强于代码”的假象。
- 如果把 source badge 继续埋在页面 copy 而不是 chrome contract，后续仍然无法稳定对比 live / cached / mock 真相。
