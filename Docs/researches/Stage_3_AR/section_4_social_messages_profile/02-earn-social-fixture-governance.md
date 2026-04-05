# S4-02 EarnSocial fixture 与 assets 治理策略

## 当前代码现状

1. `EarnSocialHomeView` 把首页内容数据直接写在页面文件内部：
   - `EarnSocialMockFixtures.preChattedCardIDs` 和 `EarnSocialMockFixtures.cards` 直接定义在 `spare-life-ios-app/Features/EarnSocial/EarnSocialHomeView.swift:229-352`。
   - 这些内容不是少量占位符，而是完整的类目卡片数据集，已经承担首页实际展示职责。
2. 首页不止卡片数据写死在 view 文件里，偏好和聊天种子也在同一文件内硬编码：
   - `EarnSocialPreferenceSheet` 的 `preferenceTags` 是按 category 写死的 switch，见 `EarnSocialHomeView.swift:393-409`。
   - `EarnSocialChatMessage.seed(for:)` 与 `sendDraft()` 也直接把首轮对话文案和回复模板写进 view，见 `EarnSocialHomeView.swift:717-779`。
3. `EarnSocialExperienceStore` 同样存在第二套大体量内嵌种子数据：
   - `seedContent()` 内写死了 lane chips、seed intents、personas、trend board、arena、ledger，见 `spare-life-ios-app/Features/EarnSocial/EarnSocialExperienceStore.swift:1074-1438`。
   - `makeTemplates()` 内写死了 market form templates，见 `EarnSocialExperienceStore.swift:1499-1671`。
4. 也就是说，当前 EarnSocial 的 fixture 问题不是“首页一份 mock 卡片没抽出去”，而是至少有四类内容源都散落在 Swift 文件中：
   - 首页卡片
   - 偏好标签
   - 聊天种子 / 回复模板
   - A2A 体验种子 / 表单模板
5. 当前仓库虽然有 `spare-life-ios-app/Resources/` 目录，但里面只有 `.gitkeep`，EarnSocial 还没有进入任何稳定的资源治理路径。
6. 当前所谓 “assets” 也还不是二进制图片资源问题。首页主要使用的是：
   - SF Symbols
   - 颜色 / 字体设计 token
   - 文本内容本身
   这意味着眼下最应该治理的是“内容 fixture 与资源引用协议”，而不是先引入图片资源系统。

## 当前文档偏差

1. 现有审计文档准确指出了首页使用 in-file `EarnSocialMockFixtures`，但这只覆盖了问题的一部分。证据在 `Docs/Stage_3_Codebase_Audit.md:73-76`。
2. 当前真正的偏差是 scope 被低估了：
   - 不是只有 `cards` 写死在页面里。
   - 连偏好、聊天 seed、A2A seed 与表单模板也都各自写死在 SwiftUI / store 文件中。
3. 因此本 item 的治理目标不能只做“把 `EarnSocialMockFixtures` 搬到另一个 Swift 文件”。
   - 那只是换地方继续写死。
   - 需要的是可演进、可比对、可替换、可复用的数据源层。

## 稳定 SOTA / 成熟实践

1. 页面内容 fixture 应与 SwiftUI layout 解耦，最小边界通常是 `Codable` 文档 + feature-scoped repository/provider。
2. 资源治理要做“语义键”而不是“视图写死”：
   - 页面只消费 `symbolKey`、`themeKey`、`avatarKey`、`statusKey`
   - 具体用 SF Symbol、bundle image 还是远端资源，由 loader / resolver 决定
3. Fixture 数据要版本化、可 diff、可局部替换。
   - 小文件按场景拆分，比一个巨大的全量 JSON 更可维护。
4. Live source、bundled fixture、preview fixture 最好共享同一套协议，而不是为 mock 单独写一套完全不同的消费路径。
5. 如果仓库已经有成熟的 bundle + 本地 fallback 读取模式，优先沿用。当前 `Masters` 模块已经展示了这种做法：
   - 优先从 `Bundle.main` 取资源
   - bundle 不可用时退回 feature 内 `Support/` 文件
   - 证据在 `spare-life-ios-app/Features/Masters/MasterExperienceStore.swift:1456-1472` 与 `:2128-2138`

## 面向本仓库的具体建议

1. 为 EarnSocial 增加统一的数据源边界，而不是继续让页面直接读静态 Swift 常量。
   - 建议形态：`EarnSocialFixtureRepository`
   - 职责是加载“首页卡片、偏好、聊天种子、A2A seed、表单模板”
   - `EarnSocialHomeView` 和未来任何 `ExperienceRootView` 只消费 repository 暴露的 DTO / view model
2. 资源文件先放在 feature 自己的 `Support` 目录，再视工程打包情况决定是否同步进 bundle resources。
   - 推荐初始落点：`spare-life-ios-app/Features/EarnSocial/Support/Fixtures/`
   - 推荐长期别名：`spare-life-ios-app/Resources/EarnSocial/`
   - 原因：当前 `Resources/` 还是空壳，而 `Masters` 已经证明了 “bundle 优先 + Support fallback” 对本仓库是可行模式。
3. 不要把全部 EarnSocial 内容揉成一个超大 JSON。建议按稳定边界拆成至少 5 份：
   - `home_cards.json`
   - `home_preferences.json`
   - `chat_seed_templates.json`
   - `experience_seed.json`
   - `experience_market_templates.json`
4. 为每类 fixture 定义稳定 ID，并复用现有代码里的业务主键。
   - 首页卡片直接沿用 `errand-01`、`career-08` 这类现有 ID
   - 经验商店沿用 `seed-intent-job`、`persona-job-jia`、`trend-job` 这类 ID
   - 不要在迁移过程中重新发明一套新的匿名标识
5. 为“assets”定义语义字段，而不是在视图里继续硬编码表现层选择。
   - 例如：`symbolKey`、`badgeStyleKey`、`stateTagKey`、`avatarStyleKey`
   - 当前没有专门的图片资源时，resolver 可以先把这些 key 映射到 SF Symbol 或颜色 token
   - 以后如果 EarnSocial 引入头像图、分类插画、活动 banner，只需扩展 resolver，不必重写页面结构
6. 首页运行真相应优先迁移。
   - 因为当前 live runtime 是 `EarnSocialHomeView`
   - 所以 fixture 外提应该先服务首页卡片、偏好、聊天 seed
   - `EarnSocialExperienceStore` 的种子迁移可以放在第二阶段，避免用未接线路径绑架当前治理优先级
7. 不建议把布局常量、视觉 token、交互动效也一起数据化。
   - 数据层只治理内容、状态、资源引用
   - 视图层继续负责布局与样式组合
   - 否则会把当前问题从“内容写死”变成“布局也难以维护”

## 建议的数据模型边界

1. 首页卡片 DTO
   - `id`
   - `category`
   - `direction`
   - `actorRole`
   - `counterpartRole`
   - `title`
   - `summary`
   - `meta`
   - `rewardLabel`
   - `tags`
   - `isPreChatted`
2. 偏好 DTO
   - `category`
   - `tags`
3. 聊天种子 DTO
   - `cardID` 或 `category + direction`
   - `initialMessages`
   - `replyTemplate`
   - `requiresPreChattedPreamble`
4. A2A 体验 DTO
   - lane chips
   - seed intents
   - personas
   - trends
   - arena
   - ledger
5. 资源引用 DTO
   - `symbolKey`
   - `themeKey`
   - `assetKey`（当前可为空，预留未来图片/插画）

## 实施顺序

1. 先做 inventory，列全当前所有 inline fixture 的来源，不只统计 `EarnSocialMockFixtures`。
2. 再定义 `Codable` schema，并锁定主键与 category/lane 枚举映射。
3. 落地 feature-scoped `Support/Fixtures` 文件，并实现 bundle 优先、Support fallback 的读取器。
4. 第一批只替换 `EarnSocialHomeView`：
   - 首页卡片
   - 偏好标签
   - 聊天 seed / 回复模板
5. 第二批再把 `EarnSocialExperienceStore` 的 `seedContent()` 与 `makeTemplates()` 接到同一 repository。
6. 最后再决定是否让 preview、snapshot、将来的测试也统一复用这套 fixture loader。

## 风险

1. 如果只把 `EarnSocialMockFixtures` 从页面挪到另一个 Swift 文件，治理表面完成，但本质上仍然不可追踪、不可 schema 校验、不可与未来 live source 对齐。
2. 首页 category 和 `ExperienceStore` lane 不是同一套分类体系：
   - 首页是 `errand / mouthpiece / buddy / romance / career / funding / idle`
   - store 是 `idleGoods / skillQA / romance / friendship / jobHiring / errandHelp`
   - 如果不先定义映射关系，仓库会出现第二轮 fixture 漂移
3. 当前项目的 bundle resources 还没有为 EarnSocial 实际接线，直接假设资源一定能被打包，会造成后续落地受阻。
4. 把所有表现细节都塞进数据源会让 JSON 变成“伪视图描述语言”，增加维护成本。这里要守住边界，只数据化内容与资源引用，不数据化布局。
5. 如果不优先迁移当前 live runtime，而是先清理 `ExperienceStore`，就会再次把优化资源投入到未接线路径上。
