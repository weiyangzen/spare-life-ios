# S2-05 Design System Boundary

代码与旧文档冲突时，以代码为准。本报告只讨论 `DesignTokens`、spacing、typography、color、platform compat 的边界归属：哪些应该被当作共享设计系统，哪些只应停留在页面内常量，不扩展到产品功能新增、具体 UI 重构实现或 OpenClaw/plugin 代码。

## 当前代码现状

### 1. 当前仓库确实存在共享 UI 基础层，但它不是一个边界清晰的 design system

当前最接近“共享设计系统”的目录是：

- `spare-life-ios-app/App/DesignSystem/`
  - `DesignTokens.swift`
  - `PlatformCompat.swift`
  - `WaterfallLayout.swift`
- `spare-life-ios-app/Features/Shared/`
  - `FeedCardProtocol.swift`
  - `UnifiedWaterfallFeed.swift`
  - `UnifiedDiscoverFeedView.swift`
  - `DiscoverMixedFeedSection.swift`

`spare-life-ios-app/Package.swift` 也把 `App` 与 `Features` 一并编进 `SpareLifeCore`，说明这些文件不是“仅供预览的 demo 零件”，而是当前 Swift runtime 共享层的一部分。

但从代码边界看，它们现在更像“共享 UI 杂糅层”，而不是“tokens -> semantic theme -> component -> page local constants”四层分明的 design system。

### 2. `DesignTokens.swift` 同时承载了 token、组件、状态页和工具能力，职责过宽

`spare-life-ios-app/App/DesignSystem/DesignTokens.swift` 当前混放了至少 5 类内容：

- 基础 token
  - `Color.spareYellow`、`spareYellowInk`、`spareOrange`
  - `Spacing`
  - `CornerRadius`
  - `Font.spareTitle1`、`spareBody`、`spareCaption`
  - `Animation.spareSpring`、`spareEase`
- 半语义 token
  - `emotionPositive`
  - `chipSelected`
  - `cardBackground`
  - `cardStroke`
- 视觉 modifier
  - `CardShadow`
  - `ShimmerModifier`
  - `cardShadow()`
  - `shimmer()`
- 共享组件
  - `PillTag`
  - `EmotionBadge`
  - `AvatarView`
- 状态页与交互样式
  - `EmptyStateView`
  - `ErrorStateView`
  - `CardPressStyle`

这意味着当前文件名虽然叫 `DesignTokens`，但仓库真实情况不是“这里只放 token”，而是“这里同时放 token、共享状态页、共享 badge、共享 avatar、共享 button style”。如果后续文档继续把它描述成“纯 token 层”，会误判实际依赖边界。

### 3. `PlatformCompat.swift` 是平台适配层，不是设计系统本体

`spare-life-ios-app/App/DesignSystem/PlatformCompat.swift` 当前承担的是平台兼容和 SwiftUI API 包装：

- AppKit/非 UIKit 环境下的 `NSColor` / `UIApplication` / `UIWindow` shim
- `spareBottomSafeAreaInset()`
- `spareImpactFeedback(_:)`
- `ToolbarItemPlacement` 兼容别名
- `spareNavigationBarTitleDisplayMode`
- `spareNavigationBarHidden`
- `spareNavigationBarClearBackground`
- `spareNavigationSearchable`
- 输入法/自动更正兼容包装

这些能力确实是“共享层”，但它们解决的是：

- iOS / macOS preview-host 编译差异
- SwiftUI API 差异
- 平台交互桥接

它们不属于 token，不属于品牌视觉语言，也不属于页面级样式规范。把它们和 `DesignTokens` 放在同一个 conceptual bucket，会让 “platform compat” 与 “design system” 的责任混在一起。

### 4. `WaterfallLayout` 和 `Features/Shared` 更像共享布局与组件层，而不是 token 层

`spare-life-ios-app/App/DesignSystem/WaterfallLayout.swift` 当前提供的是：

- `WaterfallColumns`
- `WaterfallGrid`
- `ResponsiveMasonryLayout`
- `WaterfallSkeleton`

`spare-life-ios-app/Features/Shared/FeedCardProtocol.swift` 和 `UnifiedWaterfallFeed.swift` 则提供：

- `FeedCard` / `AnyFeedCard`
- `FeedCardKind`
- `FeedSorter`
- `UnifiedWaterfallFeed`
- `FeedSectionHeader`
- `FeedPinnedBanner`

这些都是真正的 shared UI primitive，但它们的职责是：

- 统一布局
- 统一 feed 容器
- 统一卡片协议
- 统一 loading/empty/error 容器

它们依赖 token，却不等于 token。当前仓库的共享层真实边界应该至少分成：

- design tokens
- platform adapters
- shared layout/components

而不是继续把这三者统称为一个模糊的“设计系统文件”。

### 5. 颜色、字体、间距在大量页面中仍被直接硬编码，说明 design system 目前只覆盖了一部分现实

虽然 `Spacing`、`CornerRadius`、`Font.spare*`、品牌黄系色已经被大量使用，但跨页仍有大量页面内常量和直接系统样式：

- `XianxiaHomeView.swift`
  - `private let compactSpacing: CGFloat = 8`
  - 页面顶部黄白渐变直接写在页面里
- `SceneTopicView.swift`
  - 同样存在 `compactSpacing = 8`
- `EarnSocialHomeView.swift`
  - `let spacing = Spacing.sm`
  - `let horizontalPadding = Spacing.sm * 2`
  - `max(120, floor(...))`
  - 大量 `.font(.system(size: ...))`
  - 多处 `Color.white`
- `ConversationHubView.swift`
  - 背景渐变直接写在页面里
  - loading/list row 广泛直接使用 `Color.white`
  - toolbar icon 和若干字号直接 `.font(.system(size: ...))`
- `MainTabView.swift`
  - 直接写 `6 / 8 / 10 / 15 / 24 / 36 / 44`
  - 常用字体直接 `.font(.system(size: ...))`
  - tab bar 玻璃感和 prominent button 渐变完全写在页面里
- `MyProfileView.swift`
  - 大量 `.font(.system(size: ...))`
  - 大量 `Color.white`、自定义 gradient、`20 / 22 / 28 / 32 / 36` 等页面内半径与字号

这说明当前 shared token 层的真实作用是：

- 给共享组件和部分页面提供统一基线

而不是：

- 已经收编全仓 spacing / typography / color 的唯一真相

### 6. typography 目前更像“固定字号集合”，还没有升级为带动态字体约束的语义层

当前仓库确实有：

- `Font.spareTitle1`
- `Font.spareTitle2`
- `Font.spareTitle3`
- `Font.spareBody`
- `Font.spareBodySB`
- `Font.spareCaption`
- `Font.spareCaptionSB`
- `Font.spareMicro`

但与此同时，全仓仍广泛存在直接 `.font(.system(size: ...))`。并且当前代码中几乎没有看到：

- `@ScaledMetric`
- `dynamicTypeSize`
- `sizeCategory`
- `UIFontMetrics`

这表示当前 typography 真实状态不是“语义排版系统已稳定落地”，而是“有一组共享字号别名，但页面仍大量绕开它，且动态字体治理几乎缺位”。

### 7. color 当前以品牌黄系为核心，但语义色层还不完整

当前 `Color` 扩展提供了：

- 品牌色
  - `spareYellow`
  - `spareYellowLight`
  - `spareOrange`
  - `spareYellowInk`
  - `spareYellowWash`
  - `spareDark`
- 若干语义别名
  - `emotionPositive`
  - `emotionNegative`
  - `emotionSplit`
  - `emotionNeutral`
  - `chipSelected`
  - `chipUnselected`
  - `cardBackground`
  - `cardStroke`

但在页面内仍大量直接使用：

- `Color.white`
- `Color(.systemGroupedBackground)`
- `Color(.secondarySystemGroupedBackground)`
- `Color(.systemGray5)`
- `Color(.systemGray6)`

说明当前颜色治理只收敛了品牌主色，没有真正把 surface / elevated surface / border / placeholder / interactive state 等语义色完整沉到底层。

### 8. platform compat 的真实边界比旧注释更窄，也更清楚

当前与“平台兼容”直接相关的真实代码主要只有两块：

- `PlatformCompat.swift`
  - AppKit shim
  - navigation/search/haptic/safe-area 适配
- `Package.swift`
  - `SpareLifeCore` 同时支持 `iOS(.v16)` 与 `macOS(.v13)`

另一方面，代码注释与运行现实存在偏差：

- `MainTabView.swift` 注释写着 `light mode only`
- `WaterfallLayout.swift` 注释也写着 `light mode only`
- `spare-life-ios-preview-host/App/SpareLifePreviewHostApp.swift` 确实强制 `.preferredColorScheme(.light)`
- 但当前 active app shell 本身没有统一强制 `.preferredColorScheme(.light)`

所以当前“platform compat” 的真实边界是：

- 编译兼容与平台 API 包装已经存在

而不是：

- 主题/色彩模式策略已经被平台层稳定接管

## 当前文档偏差

### 1. 旧蓝图和 Stage 2 勾选容易让人误以为仓库已经拥有一套完整统一的设计系统

`Docs/sparelife_blueprint.md` 的“统一 UI”要求，以及 `Docs/Stage2_Blueprint.md` 中“消息页与闲聊页保持同一设计系统”的勾选，会自然给人一个更强判断：

- 设计系统已经收编跨页 spacing / typography / color
- 页面差异主要只是业务语义差异

但按当前代码现实，真正被统一的主要是：

- 品牌黄系颜色
- 一组基础 spacing / radius / font 常量
- 若干 feed/shared primitives

而不是一套覆盖全仓的设计系统边界。

### 2. 旧文档默认“统一 UI”已经落到首页和组件层，但当前仍有大量页面内视觉常量

Stage 3 审计已经明确 shared layer 是真的存在，但 page-level header/search/filter 仍大量重复。当前再往下看 spacing / typography / color，会发现同样的问题：

- shared primitives 存在
- 页面仍保留大量一次性字号、圆角、背景与渐变

因此文档若继续把“共享 layer 存在”外推成“design system 已完整落地”，会高估现状。

### 3. “light mode only” 在注释和 preview host 中成立，但在当前 app runtime 里并没有被统一强制

代码注释和 preview host 现状容易让文档写出：

- 仓库已经明确只支持 light mode

但当前真正强制 light mode 的只有 preview host。active app shell 本身没有统一主题策略入口，因此这条结论目前最多只能算：

- preview/演示环境偏向 light mode

不能直接升级成：

- design system 已经正式定义并实现了全仓主题策略

## 稳定 SOTA 或成熟实践

### 1. 成熟做法通常把共享 UI 明确拆成四层，而不是只靠一个 `DesignTokens.swift`

较稳的层次通常是：

- `Foundation Tokens`
  - spacing scale
  - radius scale
  - typography roles
  - motion/elevation
  - raw brand palette
- `Semantic Tokens`
  - page background
  - card background
  - primary action fill
  - secondary text
  - destructive/accent/status
- `Shared Components / Layout`
  - badge
  - avatar
  - empty/error state
  - feed container
  - tab bar chrome
- `Screen-local Constants`
  - 单页 hero gradient
  - 某页特有 compact spacing
  - 单页专属 large card corner radius
  - 不具备跨页复用意义的装饰值

对当前仓库，问题不在于“有没有共享值”，而在于这四层还没完全分开。

### 2. 真正的 design-system token 需要满足“跨页面稳定复用”与“语义可命名”

成熟实践下，一个值应该进入 design system，通常至少满足以下条件中的大部分：

- 跨两个及以上 feature 重复出现
- 与品牌、可访问性、平台一致性或 shared component 直接相关
- 能被语义命名，而不是只能叫 `radius20` / `font17`
- 未来变更时，希望通过中心化调整影响多个页面

反过来，如果某个值只在一个页面服务一个构图，不应强行上提为 token。那只会把 design system 变成“一堆页面遗留数字的公共墓地”。

### 3. typography 应以语义角色和动态字体为主，不应长期依赖大量固定字号

成熟 iOS 做法更重视：

- 语义文本角色
  - hero title
  - section title
  - body
  - caption
  - metadata
- dynamic type / scaling 能力
- 组件默认跟随语义层，而不是每页直接写 `.font(.system(size: ...))`

如果 shared typography 只是一组固定字号别名，而页面继续大量自定义字号，那么所谓“统一排版”会很快退化。

### 4. platform compat 应单独治理，不要伪装成视觉 token

平台兼容层成熟做法通常单独处理：

- 编译兼容
- 平台 API 包装
- iOS / macOS toolbar/search/nav 差异
- safe area / haptics / UIKit bridge

这类代码应被当作 platform adapter 或 UI runtime shim，而不是 design system。否则视觉规范、交互策略与编译适配会被绑死在同一处，后续难以维护。

## 面向本仓库的具体建议

### 1. 重新定义 Section 2 下的共享 UI 边界，至少分成四类

建议后续文档和实现都按下表理解：

| 类别 | 当前代码中的代表 | 应归属什么 | 不应再被误写成什么 |
| --- | --- | --- | --- |
| Design tokens | `Spacing`, `CornerRadius`, `Font.spare*`, 品牌色 | 基础视觉规范 | 具体页面组件 |
| Platform adapters | `PlatformCompat.swift` | 平台适配层 | 设计系统 token |
| Shared UI primitives | `PillTag`, `AvatarView`, `EmptyStateView`, `UnifiedWaterfallFeed`, `FeedCardProtocol` | 组件/布局层 | 页面内常量 |
| Page-local constants | `compactSpacing = 8`、单页 gradient、单页大圆角与特殊字号 | 页面内部实现细节 | 全局 token |

### 2. 对“是否进入 design system”建立硬判定规则

建议以后只有满足以下任一条件的值，才允许升格为 design-system token：

- 至少被两个 feature surface 复用
- 被 shared primitive 直接依赖
- 明确属于品牌、无障碍、平台一致性策略
- 后续需要在仓库级统一调整

否则默认留在页面内，以 `private let` 或 `private enum Style` 形式存在。

### 3. `DesignTokens.swift` 在概念上应被拆成“token 层”和“共享组件层”

即使暂时不改代码，也应先在文档上明确：

- `Spacing / CornerRadius / Font / Animation / base colors` 是 token
- `PillTag / EmotionBadge / AvatarView / EmptyStateView / ErrorStateView / CardPressStyle` 是 shared primitives

这样后续任何 worker 再研究 shared UI 时，不会再把一个 badge 或 empty state 当成“token 本身”。

### 4. `PlatformCompat.swift` 应被视为平台外观桥接层，不参与 token 边界判断

后续涉及：

- `spareNavigationSearchable`
- `spareNavigationBarHidden`
- `spareBottomSafeAreaInset`
- haptic wrappers

都应归入 platform/runtime adapter 讨论，不应再混入 color/spacing/typography 文档里当作设计系统组成部分。

### 5. typography 先做“语义化收口”，再谈全仓替换

当前最合理的仓库建议不是立刻把所有 `.font(.system(size: ...))` 清空，而是先建立边界：

- 共享组件必须优先使用语义字体 token
- 首页壳层与 shared chrome 优先收口
- 单页艺术化排版先允许保留局部常量
- 只有稳定复用后，再上提为公共 typography role

否则会把大量只服务于一个页面构图的字号误提升为全局规范。

### 6. color 先补足语义 surface/token，再决定是否统一主题策略

短期内最有价值的是补齐：

- page background
- elevated surface
- card surface
- border
- placeholder
- text secondary / tertiary
- destructive / warning / success

而不是直接宣布：

- “仓库只支持 light mode”

因为当前代码现实还没把主题策略真正接到 active app runtime。

### 7. `WaterfallLayout` 与 `Features/Shared` 保持为共享布局层，不要并回 token 文档

`WaterfallLayout`、`UnifiedWaterfallFeed`、`FeedCardProtocol` 的价值在于：

- 布局 contract
- feed container
- card abstraction

不是视觉 token。后续如果继续把它们和 token 混写，Section 2 的共享 UI 研究会一直失焦。

## 实施顺序

1. 先在文档上确认四层边界：token、platform adapter、shared primitive、page-local constants。
2. 为当前共享层做一次“升格/降级”清单，把 `DesignTokens.swift` 中哪些是 token、哪些是 primitive 标出来。
3. 只对共享组件和 app shell 先做 typography/color/spacing 语义收口，不先清扫所有页面内数字。
4. 再审计首页根壳和高复用页面里的直接 `.font(.system(size: ...))`、`Color.white`、`Color(.systemGray*)`，决定哪些进入语义 token，哪些继续留在页面内。
5. 最后再讨论 dark mode / theme policy 是否要被 active runtime 明确接管，而不是只停留在 preview host。

## 风险

- 如果把所有页面数字都硬提成 token，会得到一个庞大但不可维护的“伪设计系统”。
- 如果继续让 `DesignTokens.swift` 混放 token 与组件，后续任何收口都会牵出不必要的依赖耦合。
- 如果在没有动态字体治理前就把固定字号制度化，会把当前局部实现固化成长期约束。
- 如果把 preview host 的 light-mode 偏好误写成 runtime 真相，会继续放大文档与代码的偏差。
- 如果不把 `PlatformCompat` 从 design-system 讨论中剥离，后续兼容性修补会反过来污染视觉规范文档。
