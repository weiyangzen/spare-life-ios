# S5-05 全仓 fixture 与 seed 数据治理规范

## 当前代码现状

1. 当前仓库至少存在 5 类彼此独立维护的 fixture / seed 来源，而且它们没有一个统一注册表。
   - Swift runtime 页面级 fixture：`EarnSocialHomeView` 直接从 `EarnSocialMockFixtures.cards` 读首页卡片，`EarnSocialPreferenceSheet` 又在同文件里写死偏好标签，聊天首轮 seed 与回复模板也写在同一文件。证据在 `spare-life-ios-app/Features/EarnSocial/EarnSocialHomeView.swift:11-12`、`:229-352`、`:393-409`、`:717-779`。
   - Swift store 级 mock：`CompanionChatStore` 的 `load()` / `refresh()` 都直接回填 `Self.mockThreads()`，而不是读持久化或共享 seed。证据在 `spare-life-ios-app/Features/CompanionChat/CompanionChatStore.swift:276-289` 与 `:307-342`。
   - Swift profile mock：`MyProfileStore.load()` 直接写入 `王威扬 / @the_usual_intp / Shadow Sebastian` 等根页数据；`MyProfileOverviewMetrics` 同时还保留 `EarnSocialStats.mock` 与 `MessageStats.mock`。证据在 `spare-life-ios-app/Features/MyProfile/MyProfileView.swift:94-118` 与 `spare-life-ios-app/Features/MyProfile/MyProfileOverviewMetrics.swift:31-55`。
   - support `.mjs` bootstrap seed：`EarnSocialExperienceUseCase.bootstrap()` 依赖 `bootstrapCatalogSeed()`，`CompanionChatExperienceUseCase.ensureWorkspace()` 依赖 `buildCompanionWorkspaceSeed()`，`MyDashboardExperienceUseCase.bootstrap()` 依赖 `buildMyBootstrapSeed()`。证据在 `spare-life-ios-app/Domain/UseCases/earnSocialExperienceUseCase.mjs:58-77`、`spare-life-ios-app/Domain/UseCases/companionChatExperienceUseCase.mjs:97-107`、`spare-life-ios-app/Domain/UseCases/myDashboardExperienceUseCase.mjs:52-74`。
   - plugin fixture / demo：`spare-life-openclaw-plugin/fixtures/` 下有 `scene_scan_payload.json`、`master_asset_bundle.json`，`unified-ui-flow-demo.mjs` 与 `foundation-bottom-layer-demo.mjs` 默认直接读取这些 JSON。证据在 `spare-life-openclaw-plugin/README.md:13-21`、`spare-life-openclaw-plugin/src/demo/unified-ui-flow-demo.mjs:25-32`、`spare-life-openclaw-plugin/src/demo/foundation-bottom-layer-demo.mjs:15-18`。
2. 同一个业务域现在经常同时存在两套以上不兼容的“世界观”。
   - EarnSocial 当前 live Swift 首页使用 `errand / mouthpiece / buddy / romance / career / funding / idle` 分类和 `errand-01`、`career-08` 这类卡片 ID。证据在 `spare-life-ios-app/Features/EarnSocial/EarnSocialHomeView.swift:131-208` 与 `:240-324`。
   - 同域 support seed 使用 `idle_goods / skill_qa / romance / friendship / job_hiring / errand_help` lane，以及 `agent-job-jia`、`seed-user-luna`、`seed-intent-job` 这类 A2A 标识。证据在 `spare-life-ios-app/Services/EarnSocial/a2aMarketService.mjs:33-202`、`:255-260`，以及 `spare-life-ios-app/Features/EarnSocial/EarnSocialExperienceStore.swift:1074-1180`。
   - 这说明当前代码事实不是“已有一套统一 EarnSocial seed”，而是“首页 mock、Experience store seed、A2A support seed 并存”。
3. 消息域也存在 runtime mock 图景与 support seed 图景并存的问题。
   - 当前 Swift 消息首页是 `Dubi / Sophie / Omar & Aris(群) / Mia / Hannah` 这一组线程。证据在 `spare-life-ios-app/Features/CompanionChat/CompanionChatStore.swift:307-342`。
   - support `.mjs` 侧的 canonical-ish social graph 则是 `lin-zhou / chen-miao / he-qi / weekend-makers`，并带有默认 mask、direct seeds、group seeds。证据在 `spare-life-ios-app/Domain/Models/companionContracts.mjs:31-78` 与 `spare-life-ios-app/Services/CompanionChat/companionChatService.mjs:36-183`。
   - 两边的联系人、群组、对话文案、关系温度都不是同一组对象。
4. 我的页根数据与 support seed 也并不一致。
   - Swift 根页把当前用户渲染为 `王威扬`、`@the_usual_intp`、`Shadow Sebastian`。证据在 `spare-life-ios-app/Features/MyProfile/MyProfileView.swift:99-116`。
   - `.mjs` bootstrap seed 却把同一用户起成 `林闻`、`闻闻分身`，并绑定另一套 headline、persona tags、training tasks、error replay。证据在 `spare-life-ios-app/Services/My/myDashboardService.mjs:134-296`。
   - 当前代码真相因此是“Profile root 与 My dashboard support seed 未对齐”，而不是“同一个人设在多层复用”。
5. plugin fixture 自身也在维护一个独立的 demo 世界。
   - `scene_scan_payload.json` 定义了 `viewer_amy`、`Tech Mixer 2026`、`Mia / Leo / Tina / Ray / Nora`、`agent_mia` 等实体。证据在 `spare-life-openclaw-plugin/fixtures/scene_scan_payload.json:2-155`。
   - `master_asset_bundle.json` 又定义了另一套 masters world：`zeng-guofan / wang-yangming / daosheng-hefu / su-shi` 等 bundle。证据在 `spare-life-openclaw-plugin/fixtures/master_asset_bundle.json:2-240`。
   - 这些 fixture 能驱动 plugin demos，但没有任何 repo-level 规则说明它们与 Swift 页面 mock、`.mjs` bootstrap seed、tests mock transport 的关系。
6. tests 也在独立造世界，而且当前没有规则区分“允许孤立造世界的测试”与“应该复用共享 seed 的集成验证”。
   - `MyProfileDashboardTests` 内部自带 `MyProfileMockClawdbTransport`、自造 topics batch 与 envelope。证据在 `spare-life-ios-app/Tests/SpareLifeCoreTests/MyProfileDashboardTests.swift:19-145`。
   - `XianxiaTopicRepositoryTests` 同样在测试文件里造 topic/shard mock route 和分页批次。证据在 `spare-life-ios-app/Tests/SpareLifeCoreTests/XianxiaTopicRepositoryTests.swift:102-220`。
   - 这种做法对确定性测试是合理的，但今天并没有一份文档说明什么时候允许这种独立 fixture，什么时候应该挂到共享 seed。
7. 当前真正的代码结论应明确写成一句话：仓库里已经存在多套平行 seed 世界，尚无一个全仓 canonical fixture truth。任何文档若把现状描述成“只是某个页面用了 mock”都低估了问题范围。

## 当前文档偏差

1. `Docs/Stage_3_Codebase_Audit.md` 准确指出了 EarnSocial、消息、我的页分别存在 mock-heavy 问题，但它只是在模块级别点名，没有上升到“全仓 fixture 治理缺位”。证据在 `Docs/Stage_3_Codebase_Audit.md:69-108`。
2. `S4-02` 已经把 EarnSocial fixture 问题写得很清楚，但它天然是 feature-scoped 研究，不是 repo-wide fixture policy。
   - 它覆盖了首页卡片、偏好、聊天 seed、A2A seed 的 feature 内分散问题。证据在 `Docs/researches/Stage_3_AR/section_4_social_messages_profile/02-earn-social-fixture-governance.md:5-24`。
   - 但它没有覆盖 CompanionChat、MyProfile、plugin fixture、tests mock transport，因此不能被当作全仓 fixture 规范的替代品。证据在 `Docs/researches/Stage_3_AR/section_4_social_messages_profile/02-earn-social-fixture-governance.md:26-34`。
3. `spare-life-openclaw-plugin/README.md` 把 `fixtures/` 描述成 “sample payloads for local testing”。证据在 `spare-life-openclaw-plugin/README.md:13-21`。这会自然强化“plugin fixture 只是 plugin 自己的本地样例”这一局部视角，而不是 repo-wide shared seed 视角。
4. 当前仓库没有任何一份权威文档声明：
   - 哪些 fixture 是 canonical seed
   - 哪些是 consumer projection
   - 哪些只是 demo payload
   - 哪些是 isolated test fixture
   - 哪些实体 ID 必须跨层稳定复用
5. 因此当前文档偏差并不只是“有旧文档没更新”，而是“缺了一层 repo-level fixture taxonomy 与 ownership 规范”。

## 稳定 SOTA / 成熟实践

1. 成熟仓库不会要求所有 consumer 直接共享同一个原始 JSON，但会要求所有跨层 demo / preview / bootstrap 都能追溯到同一份 canonical scenario graph。
2. fixture 治理首先要做“类型划分”，而不是先做“文件搬家”。至少应区分：
   - canonical seed：跨消费者共享的主世界观与稳定 ID
   - consumer projection：面向某个 app surface / plugin / preview 的投影视图
   - demo fixture：为 smoke 或 demo 保留的静态快照
   - isolated test fixture：只服务单测 / 边界测试的局部构造数据
   - example payload：只用于 README / API 示例，不计入 canonical truth
3. canonical seed 应具备稳定身份键、schema version、owner、consumer 列表和 drift policy。否则消费者一多，任何一处“顺手改个 displayName”都会演变成全仓世界观分叉。
4. 对 runtime、support code、plugin、tests 同时存在的仓库，更成熟的做法是“同一世界观，多种投影”。
   - runtime 只拿自己需要的轻量 DTO
   - plugin demo 拿可落地的静态 JSON snapshot
   - tests 在需要真实跨层语义时复用共享 builder
   - 只有极端边界或错误场景测试，才允许独立造世界
5. isolated test fixture 是被允许的，但必须显式标记为局部、非 canonical。否则 deterministic unit test 很容易反过来变成另一套隐式世界观。
6. 静态快照型 fixture 最好由 canonical seed 生成，而不是靠多个 consumer 各自手写。这样 demo 可 diff、runtime 可投影、tests 可复用，而且 drift 可以被机器比对。
7. 打包方式不是 source-of-truth。`Bundle.main`、`Support/Fixtures/`、plugin `fixtures/`、test helper 都只是消费位置，不应该再各自演变成世界观源头。

## 面向本仓库的具体建议

1. 先为本仓库建立明确的 fixture taxonomy，而不是继续默认“谁需要数据谁就在自己目录里写一份”。
   - 建议固定 5 个分类：`canonical_seed`、`consumer_projection`、`demo_fixture`、`isolated_test_fixture`、`example_payload`。
   - 任何新加 fixture 必须先声明自己属于哪一类。
2. 选择一套 repo-wide canonical scenario graph，专门承载跨层稳定 ID 与人物/关系/场景语义。
   - 当前仓库已经反复出现一条潜在共用主题：`AI 产品 / 上海 / Demo 收尾 / 求职 / side project`。
   - 这个主题同时出现在 companion seed、my dashboard seed、EarnSocial job lane、scene scan payload、master bundle 文案里，只是实体 ID 和名字没有对齐。证据在 `spare-life-ios-app/Services/CompanionChat/companionChatService.mjs:55-175`、`spare-life-ios-app/Services/My/myDashboardService.mjs:134-296`、`spare-life-ios-app/Services/EarnSocial/a2aMarketService.mjs:63-75`、`:147-200`、`spare-life-openclaw-plugin/fixtures/scene_scan_payload.json:8-155`、`spare-life-openclaw-plugin/fixtures/master_asset_bundle.json:30-240`。
   - 推荐把这条主题提炼成 canonical scenario，而不是继续让每层自己起人名和 ID。
3. 当前 repo 更适合采用“shared scenario source + per-consumer projection”的治理，而不是把 plugin fixture 或某个 Swift 页面 fixture 升成总源头。
   - 不应把 `EarnSocialHomeView.swift` 里的 inline cards 升格为全仓真相。
   - 也不应把 plugin `fixtures/*.json` 升格为全仓真相，因为那会让 app runtime 反向依赖 plugin workspace。
   - 推荐长期把 canonical seed 放在 repo-neutral 的 fixture source 层，再让 Swift / `.mjs` / plugin / tests 分别消费。
4. 对当前已存在的几条“多世界观冲突”，建议先按业务域对齐主标识。
   - EarnSocial：先建立首页 category 与 A2A lane 的稳定映射，至少明确 `career <-> job_hiring`、`buddy <-> friendship`、`idle <-> idle_goods`、`errand <-> errand_help` 的对应关系。
   - Messages：决定 runtime 首页到底以 `Dubi/Sophie/...` 还是 `lin-zhou/chen-miao/he-qi` 作为 canonical contact graph。
   - MyProfile：决定根页用户到底沿用 `王威扬/@the_usual_intp` 还是 support seed 的 `林闻/闻闻分身`，不能长期双写。
5. 为 canonical seed 建议最少补 7 个治理字段。
   - `fixture_set_id`
   - `scenario_id`
   - `schema_version`
   - `owner`
   - `consumers`
   - `stable_ids`
   - `drift_policy`
6. plugin 下的 `scene_scan_payload.json`、`master_asset_bundle.json` 这类文件更适合降级为 generated snapshot。
   - 它们仍然可以保留在 `spare-life-openclaw-plugin/fixtures/` 方便本地 demo。
   - 但文件头或旁路 manifest 应写明：来自哪个 `scenario_id`、哪个 `schema_version`、由哪套 generator 产出。
7. tests 不需要全部改成共享大 seed，但必须建立一条硬边界：
   - 行为级、边界级、错误恢复级单测可以继续使用 isolated fixture builder。
   - 任何声称验证跨层 contract、shared route、跨 surface 同一人物/同一场景的测试，都应改为复用 canonical scenario 或由 canonical generator 产出。
8. 结合本仓库当前代码结构，短期最值得先统一的是“身份与场景字典”，而不是一次性统一所有长文案。
   - 先收敛 user/contact/agent/master/lane/card/group 的 stable IDs。
   - 再收敛 displayName、tagline、summary 等可变字段。
   - 这样返工成本最低，也最符合“边界清晰、状态可追踪”的设计哲学。

## 实施顺序

1. 先做 fixture inventory，把当前所有 source 按 `canonical_seed / consumer_projection / demo_fixture / isolated_test_fixture / example_payload` 分类，而不是只按目录列文件。
2. 从现有多世界观里选出一条 canonical scenario graph，并锁定稳定身份键、lane/category 映射、group/contact/user/agent/master 的主 ID。
3. 再把 plugin fixture 和 support `.mjs` bootstrap seed 接到同一份 scenario source，先确保 integration/demo 层可追溯。
4. 然后迁移当前 live Swift runtime 的 inline mocks。
   - `EarnSocialHomeView`
   - `CompanionChatStore`
   - `MyProfileStore`
5. 最后再回头清理 tests：需要跨层语义的一批改为共享 scenario；只做局部行为验证的一批保留 isolated builder，但显式标注。
6. 等身份层稳定后，再考虑是否把生成链落成静态 JSON snapshot、bundle resource、preview fixture loader 等消费形态。

## 风险

1. 如果直接要求所有 tests 统一复用一套大 seed，测试会变重、变脆，也会掩盖真实的边界场景。因此要保留 isolated test fixture 的合法位置。
2. 如果在稳定 ID 尚未锁定前就迁移 Swift 页面或 plugin demos，会很快触发第二轮 rename / route / snapshot 返工。
3. 如果把 canonical truth 放到 plugin `fixtures/` 或某个 Swift 页面文件里，会把局部消费目录误升格成全仓真相，后续 drift 只会重演。
4. 如果只统一文案而不统一 stable IDs，deep link、A2A route、demo payload、test assertions 仍会继续分叉。
5. 如果只做“搬文件”不做 taxonomy、ownership、scenario version，仓库会从“多份 inline mock”变成“多份散落 JSON”，问题形式变了，本质没变。

代码和旧文档冲突时，本条研究结论以代码为准。
