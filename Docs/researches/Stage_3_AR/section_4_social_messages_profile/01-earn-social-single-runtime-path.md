# S4-01 EarnSocial 单一运行真相

## 当前代码现状

1. `MainTabView` 当前把 `赚闲能` tab 直接挂到 `EarnSocialHomeView()`，而不是任何 store-backed 容器。证据在 `spare-life-ios-app/App/MainTabView.swift:70-80`。
2. `EarnSocialHomeView` 自己持有 `selectedCategory`、`activeCard`、`showPreferenceSheet` 三个本地 `@State`，并通过 `EarnSocialMockFixtures.cards[selectedCategory]` 直接构造首页瀑布流。这里没有 `@StateObject`、`@ObservedObject`、`loadIfNeeded()` 或任何 `EarnSocialExperienceStore` 注入。证据在 `spare-life-ios-app/Features/EarnSocial/EarnSocialHomeView.swift:6-49`。
3. `EarnSocialExperienceStore` 的确定义了一整套大型 A2A 运行时模型，包括 `homeState`、lane chips、intent market、persona deck、icebreak、trend、arena、bond、wallet、ledger，以及 `seedContent()` / `makeTemplates()` 的完整种子数据。证据在 `spare-life-ios-app/Features/EarnSocial/EarnSocialExperienceStore.swift:533-579` 与 `:1074-1538`。
4. 但是当前代码库里没有任何位置实例化 `EarnSocialExperienceStore()` 作为 EarnSocial 首页入口。全局检索只命中 `MainTabView` 的 `EarnSocialHomeView()` 入口；不存在“首页挂了 store 只是我们没看见”的第二条接线。
5. `EarnSocialExperienceStore.swift` 又不是可以直接删除的纯死代码，因为 `LeadResultView` 复用了它定义的 `EarnSocialLaneID`。证据在 `spare-life-ios-app/Features/EarnSocial/LeadResultView.swift:65-114` 与 `spare-life-ios-app/Features/EarnSocial/EarnSocialExperienceStore.swift:11-87`。

结论必须以运行接线为准：当前单一运行真相是 `EarnSocialHomeView.swift`，不是 `EarnSocialExperienceStore.swift`。

## 当前文档 / 命名偏差

1. `Stage_3_Codebase_Audit.md` 已经正确指出当前首页使用的是 in-file fixtures，且大型 `EarnSocialExperienceStore` 不是激活的首页运行路径。证据在 `Docs/Stage_3_Codebase_Audit.md:71-77`。
2. 真正的偏差主要来自命名和文件语义，而不是审计文档本身：
   - `EarnSocialExperienceStore.swift` 文件头写着 “赚闲能 A2A experience store” 与 “Blueprint §3.3 功能点 1-7”，会让阅读者自然推断“这一整套体验已经被首页接上”。
   - 同时 `EarnSocialHomeView.swift` 文件头写的是 “Stage 2 earn-social home”，又会让人误判它只是旧实现或过渡实现。
3. 这两份文件并列存在时，会形成一个高误导性的“双真相”状态：
   - 读首页接线的人会得出“当前产品很简单”。
   - 读 `ExperienceStore` 的人会得出“当前产品已经进入复杂 A2A 状态机”。
   - 两个结论在各自局部都像真相，但只有前者是今天的运行真相。

## 稳定 SOTA / 成熟实践

1. 一个用户可达入口只能有一个可验证的运行时宿主。页面真实挂载的是谁，谁就是运行真相；未挂载的复杂 store 只能被定义为 prototype、future path 或 experiment。
2. 共享领域类型不能和“是否接线的运行时 store”绑在同一个文件里。否则删除、迁移、审计都会被共享类型依赖卡住。
3. 如果团队要保留未来路径，成熟做法不是让两套实现并列伪装成同一级别生产代码，而是明确区分：
   - `live runtime`
   - `prototype / scenario model`
   - `shared domain models`
4. 文档也必须按接线事实分层，而不是按“代码体量最大者”分层。否则 checklist 会持续朝未接线路径投入返工。

## 面向本仓库的具体建议

1. 立即把 `EarnSocialHomeView.swift` 定义为当前 EarnSocial 首页的唯一运行真相。
   - 判断标准不是“哪份代码更先进”，而是“`MainTabView` 当前实际挂了谁”。
   - 在未来真正改线之前，所有 Stage 3 文档、蓝图和研究都应把首页运行状态描述为“本地状态 + 本地 fixture 驱动的瀑布流与 mock chat”。
2. 把 `EarnSocialExperienceStore.swift` 定义为“未接线的候选运行时模型”，而不是当前首页实现。
   - 这不是否定它的价值，而是纠正文档语义。
   - 只要没有新的根视图显式持有 `@StateObject private var store = EarnSocialExperienceStore()` 并被 `MainTabView` 挂载，它就不能被记为 live runtime。
3. 把共享类型从 store 文件里拆出来，降低“共享模型”和“候选运行时”之间的耦合。
   - 第一优先是 `EarnSocialLaneID`，因为 `LeadResultView` 已经依赖它。
   - 后续如果 `LeadResultView` 还需要 `EarnIntentCard`、`EarnPersonaCard` 一类共享语义，也应该进入独立的 domain/support 文件，而不是继续压在 `EarnSocialExperienceStore.swift` 里。
4. 如果团队未来决定让 A2A 路径取代当前首页，必须先增加一个显式的宿主层，例如 `EarnSocialExperienceRootView`，再由 `MainTabView` 明确切换入口。
   - 只有完成这一步，单一运行真相才会从 `EarnSocialHomeView` 迁移到新的 root view。
   - 在那之前，不能把“候选路径的完整度”误写成“当前线上路径的事实”。
5. Stage 3 后续所有 EarnSocial 文档建议统一打标签：
   - `live`: 已被入口接线
   - `shared`: 跨页面共享模型
   - `prototype`: 未被入口接线的候选实现

## 实施顺序

1. 先修正文档和命名语义，统一说明当前 live runtime 是 `EarnSocialHomeView`。
2. 再抽离 `EarnSocialLaneID` 及其他共享模型，打断 `LeadResultView` 对 store 文件的隐性依赖。
3. 然后再做二选一决策：
   - 保留当前简单首页，继续以它为基线演进。
   - 或者设计一个明确的 `ExperienceRootView`，把 A2A store 真正接入入口。
4. 只有在第 3 步完成入口切换后，才允许更新“单一运行真相”的文档结论。

## 风险

1. 如果不先宣布 `EarnSocialHomeView` 是唯一运行真相，后续任何优化都可能继续围绕未接线 store 展开，返工概率很高。
2. 如果直接删除 `EarnSocialExperienceStore.swift`，会伤到 `LeadResultView` 当前对 `EarnSocialLaneID` 的依赖，因此正确动作是先拆共享类型，再决定 store 命运。
3. 如果过早把首页切到 `EarnSocialExperienceStore`，会把当前简单可运行路径直接换成一套更大但尚未经过真实接线收口的模型，风险高于收益。
4. 如果继续维持“双真相”，Section 4 的文档会长期失真，Messages/Profile 等后续研究也会在错误前提上展开。
