# S1-03 代码到文档追踪格式

结论先行：仓库并不是完全没有追踪链路，而是已经长出了四套彼此不兼容的半成品锚点。`Docs/sparelife_blueprint.md` 已经有稳定的 `[line:][id:]` token，`Docs/Stage_3_AR_Blueprint.md` 已经有稳定的 Stage item id 和 research doc path，Swift 文件头里也已经零散写入了 blueprint 注释，验证日志也有 `Blueprint source`。真正缺的是一套统一 schema。建议从现在开始把文档层统一收敛到 `DocTrace` / `Trace` 两种固定字段，最小字段集只保留 `stage_items / bp_refs / code_refs / research_refs / validation_refs` 五类键；其中 `bp id` 是主键，`line` 只做人工定位，代码和旧文档冲突时仍以代码为准。另一个必须明确的现实约束是，`.mjs` 运行时里已经把 `traceability` 用作“数据溯源”字段，文档层不要再复用这个词做新 schema。

## 1. 当前代码现状

### 1.1 仓库已经存在两个稳定的“权威文档锚点”

1. 产品蓝图 `Docs/sparelife_blueprint.md` 已经不是纯自由文本，它为每个产品项和 `[UIUX] / [FUNC]` 子项生成了稳定 token。比如 `Docs/sparelife_blueprint.md:1171-1180` 与 `Docs/sparelife_blueprint.md:1263-1280` 已经明确使用 `[line:1116][id:441adf69a696]`、`[line:1144][id:37f88205febb]` 这类组合键。这个结构足够当作 feature 级权威锚点。
2. Stage 3 蓝图也已经有自己的稳定锚点。`Docs/Stage_3_AR_Blueprint.md:60-67` 把 `S1-03`、`S1-04` 这样的 stage item id 和唯一 research doc path 写死；`.ops/stage3_ar/lib.sh:12-18`、`.ops/stage3_ar/lib.sh:68-81`、`.ops/stage3_ar/worker_loop.sh:24-57` 又把 `Docs/Stage_3_AR_Blueprint.md`、`Docs/Stage_3_Codebase_Audit.md`、`Docs/researches/Stage_3_AR/...` 与 `<!-- STAGE3_SECTION -->` 标记写成自动化常量。也就是说，Stage 3 这一层已经天然可追踪。

### 1.2 代码文件头已经在引用文档，但格式没有统一

Swift 文件头今天至少存在五种不同写法：

| 文件 | 当前写法 | 现状判断 |
| --- | --- | --- |
| `spare-life-ios-app/App/MainTabView.swift:1-4` | `Blueprint §7 ... (line:1150)` | 只有 line，没有 id；可读，但不稳定 |
| `spare-life-ios-app/Features/MyProfile/MyProfileView.swift:1-5` | 同时出现 `(id: 37f88205febb)` 与 `(line:1154)` | 比 line-only 更强，但字段名仍是自由文本 |
| `spare-life-ios-app/Features/Shared/UnifiedDiscoverFeedView.swift:1-4` | 一行里串了两个 line 引用 | 人能看懂，机器难以稳定解析 |
| `spare-life-ios-app/Features/Masters/MasterExperienceStore.swift:1-4` | `Blueprint §3.2 功能点 1-7` | 只有章节语义，没有精确 item token |
| `spare-life-ios-app/Features/Masters/MasterChatHomeView.swift:1-20` | 无文件头追踪注释 | 该文件与文档完全脱锚 |

同一批文件头里还混入了 `UIUX lane – slot 2` 这类执行元数据，例如 `spare-life-ios-app/Features/MyProfile/MyProfileView.swift:5`、`spare-life-ios-app/Features/Masters/MasterExperienceStore.swift:4`。这不是错，但它和“需求来自哪里”属于不同层级，今天被挤在同一块注释里。

### 1.3 验证日志已经引用蓝图，但只引用到“范围”，没有引用到“精确项”

1. `Docs/ValidationLog_Xianxia_UIUX_Batch4.md:1-15` 顶部写了 `Blueprint source: Docs/sparelife_blueprint.md §6 (checklist lines 1116–1119)`，并在表格里列出 `1116-1119`。它能说明“本批大致覆盖了哪些行”，但没有把 `[UIUX]` 子项的稳定 `id` 写出来。
2. `Docs/ValidationLog_Messages_FUNC_Batch1.md:1-18` 也采用同样模式，只写 `Docs/sparelife_blueprint.md §7 (checklist lines 1137-1143)` 和 line 列表。对人类已经够用，但对自动化和跨文档回溯来说，仍然停留在 section/range 级别。

### 1.4 研究文档有一 item 一 doc 约束，但没有强制 trace 头

`Docs/researches/Stage_3_AR/README.md:1-23` 已经规定 “one blueprint item maps to one research doc” 以及每篇文档必须写“当前代码现状 / 文档偏差 / 成熟实践 / 建议 / 风险”。这说明 research 层已经具备 topic 边界，但它还没有强制每篇文档在顶部声明：

1. 它对应哪个 `stage_item`
2. 它覆盖哪些 `code_refs`
3. 它关联哪些 `validation_refs`

所以今天 research doc 的“可读性”强于“可机器回链性”。

### 1.5 `.mjs` 运行时已经把 `traceability` 占用了

这点如果不先说清楚，后续格式会撞词。`spare-life-ios-app/Services/SceneRadar/sceneDiscussionEngine.mjs:198-267` 用 `traceability` 把 summary/hot_take/risk card 追回原始 post；`spare-life-ios-app/Domain/UseCases/sceneExperienceUseCase.mjs:55-64` 把这组 `traceability` 继续传给 repository；`spare-life-ios-app/LocalBackend/SQLite/sceneFlowRepository.mjs:168-176` 再把它持久化。这是运行时数据溯源，不是文档追踪。所以文档层应该使用 `DocTrace` 或 `Trace`，不要再新造一个同名 `traceability`。

## 2. 当前文档偏差

当前最主要的偏差不是“完全没有追踪”，而是“锚点很多，但主键不统一”：

1. 文件头有的写 line，有的写 id，有的只写章节，有的完全没写。结果是同一个仓库里的代码文件并没有一致的回链方式。
2. Stage 3 蓝图 item id 非常稳定，但还没有反向进入代码文件头和验证日志。`S1-03` 这种治理项今天只能从蓝图找到 research doc，不能顺手追到受影响代码面。
3. 验证日志只写大范围 line，不写精确 `id`。一旦同一 line 下同时有产品主项、`[UIUX]` 子项、`[FUNC]` 子项，这个范围引用就不够精确。
4. 现有文件头把 `UIUX lane – slot 2` 这种执行信息和 blueprint 追踪混在一起，导致“需求出处”和“谁做的”没有分层。
5. `line` 本身不是稳定主键。`Docs/sparelife_blueprint.md` 里今天同时提供了 `line` 和 `id`，但代码文件头常常只保留 `line`，等于主动丢掉了更稳定的那一半。
6. 显示名已经发生过漂移。S1-01 已经证明 `闲人 / 咸虾 / 闲虾 / xianxia` 与 `大师 / 闲聊 / masters` 同时存在。若追踪链路继续依赖自由文本标题，而不是稳定 token，名字一漂移，链路就断。

## 3. 稳定 SOTA / 成熟实践

对这种“产品蓝图 + 阶段蓝图 + 代码文件头 + 验证日志 + 研究文档”同时存在的仓库，成熟做法很稳定：

1. 用“稳定 id”做主键，用“line / path / title”做辅助定位。`id` 用于机器回链，`line` 用于人类快速打开。
2. 跨介质统一字段名，不统一宿主语法。也就是说，Markdown 可以用 `## Trace`，Swift/JS 可以用 `// DocTrace:`，但字段集应该相同。
3. 追踪块必须是机器可 grep 的结构化文本，而不是自然语言句子。否则自动化永远要靠猜。
4. requirement trace 和 execution metadata 分开。`lane / slot / batch` 有价值，但它不是需求来源，不该和 `bp_refs` 混成一个字段。
5. 运行时数据溯源和文档追踪分名治理。当前仓库里已经有业务层 `traceability`，文档层如果继续借这个词，会把“卡片来源于哪些帖子”和“文件来源于哪个蓝图项”混成一件事。

## 4. 面向本仓库的具体建议

### 4.1 统一最小字段集

建议以后所有文档追踪都只用以下五个键：

| 字段 | 含义 | 例子 | 备注 |
| --- | --- | --- | --- |
| `stage_items` | Stage / AR item id | `S1-03`, `S4-05` | 对 Stage 研究和阶段验证最稳定 |
| `bp_refs` | 产品蓝图锚点 | `[line:1144][id:37f88205febb]` | `id` 必须有；`line` 作为辅助定位 |
| `code_refs` | 相关代码路径 | `spare-life-ios-app/Features/MyProfile/MyProfileView.swift` | 一律 repo-relative |
| `research_refs` | 研究文档路径 | `Docs/researches/Stage_3_AR/section_1_truth/03-code-to-doc-traceability.md` | 一 item 一 doc |
| `validation_refs` | 验证日志路径 | `Docs/ValidationLog_My_FUNC_Batch1.md` | 可多个 |

强约束：

1. `bp_refs` 不再允许只写 line；必须至少带 `id`，最好保留现有 `[line:][id:]` 双 token。
2. `code_refs / research_refs / validation_refs` 一律写 repo-relative path，不写绝对路径，不写自然语言描述。
3. `lane / slot / batch` 如需保留，单独放到 `Workstream` 或文件头普通注释，不放进 `Trace` 字段集。

### 4.2 各类介质的推荐写法

#### 代码文件头

```swift
// DocTrace:
// - bp_refs: [line:1144][id:37f88205febb], [line:1154][id:b605d32f0e61]
// - stage_items: S4-05
// - research_refs: Docs/researches/Stage_3_AR/section_4_social_messages_profile/05-my-profile-data-provenance.md
```

规则：

1. 产品功能文件优先写 `bp_refs`。
2. 当前正在 Stage 内被治理的文件，再补 `stage_items` 与 `research_refs`。
3. 如果文件不对应产品蓝图主项，只对应治理项，可以只写 `stage_items`。

#### Stage 蓝图条目

现有 Stage 3 条目已经有两项正确做法：`S1-03` 这样的稳定 item id，以及 `-> research doc path`。建议保留当前主行格式，再按需增加一行结构化 trace，而不是把自然语言继续堆在 item 主行上：

```md
- [ ] S4-05 ... -> Docs/researches/Stage_3_AR/section_4_social_messages_profile/05-my-profile-data-provenance.md
  Trace: bp_refs=[line:1144][id:37f88205febb], [line:1154][id:b605d32f0e61]
```

对纯治理项如 `S1-03`、`S1-04`，允许 `bp_refs` 为空，因为它们并不直接对应产品蓝图功能项。

#### 验证日志

```md
## Trace

- stage_items: S4-05
- bp_refs: [line:1144][id:c70d0a1b5786]
- code_refs:
  - spare-life-ios-app/Features/MyProfile/MyProfileView.swift
- validation_refs: self
```

规则：

1. 顶部 `Blueprint source: ... lines 1137-1143` 这种范围写法可以保留为人类摘要，但不再作为唯一追踪字段。
2. 真正可 machine-parse 的主键必须下沉到 `bp_refs` 或 `stage_items`。
3. 一次 batch 覆盖多个产品项时，逐项列出 `bp_refs`，不要只给区间。

#### 研究文档

```md
## Trace

- stage_items: S1-03
- code_refs:
  - .ops/stage3_ar/lib.sh
  - spare-life-ios-app/App/MainTabView.swift
- validation_refs:
  - Docs/ValidationLog_Xianxia_UIUX_Batch4.md
  - Docs/ValidationLog_Messages_FUNC_Batch1.md
```

规则：

1. 每篇 research doc 至少声明 `stage_items` 和 `code_refs`。
2. 若该研究直接对应产品功能面，再补 `bp_refs`。
3. 若该研究依赖现有验证证据，再补 `validation_refs`。

### 4.3 仓库级执行规则

建议把这套格式固化成三条简单规则：

1. `bp id` 是产品层主键；`stage item` 是阶段层主键；谁处在哪一层，就先认谁。
2. 每个 artifact 只维护自己看得见的上游和下游：
   - 文件头知道自己来自哪些 blueprint / stage item
   - research doc 知道自己覆盖哪些代码和日志
   - validation log 知道自己验证了哪些 item 和哪些代码
3. 任何一处若只能写自然语言标题而写不出 `id / path / item`，都应视为追踪信息不完整。

## 5. 实施顺序

1. 先冻结术语：文档层统一叫 `DocTrace` / `Trace`，明确与运行时 `traceability` 分名。
2. 再从 Stage 3 research doc 开始执行，因为它们现在已经是“一 item 一 doc”，最容易先加结构化追踪头。
3. 然后更新新的验证日志模板，让 `stage_items / bp_refs / code_refs` 成为固定顶部块，而不是只写 `Blueprint source` 范围。
4. 接着在未来真实改动到的 Swift/JS 文件里渐进式补 `DocTrace` 文件头，不做一次性全仓大翻修。
5. 最后才考虑回填旧文件头和旧日志，优先补高频 surface，而不是追求一次性 100% 覆盖。

## 6. 风险

1. 如果试图一次性给全仓所有文件补 header，会制造巨大 diff，也会和实际业务改动纠缠在一起，反而降低可审查性。
2. 如果继续允许 line-only 引用，后续蓝图一改行号，追踪链路会再次退化成“只能靠人猜”。
3. 如果把 `lane / slot` 继续和 `bp_refs` 混写，未来自动化仍然要先做文本清洗，schema 形同虚设。
4. 如果文档层继续复用 `traceability` 这个词，会和 `sceneDiscussionEngine.mjs`、`sceneFlowRepository.mjs` 的业务溯源字段混淆，导致讨论时说不清究竟在谈“数据来源”还是“文档来源”。
5. 如果 Stage 3 研究、验证日志、代码文件头还是各自发明格式，后面 S1-06 做验证证据治理时还要先回头修追踪主键，返工会成倍增加。

代码和旧文档冲突时，本条研究结论以代码为准。
