# S1-02 Document Stratification

结论先行：仓库已经有“分层文档”所需的骨架，但职责边界没有被严格执行。Stage 3 自动化脚本按 `蓝图 section + 研究目录` 运行，`ValidationLog_*` 也已经是独立日志文件；真正的问题是 `Docs/Stage2_Blueprint.md` 与其镜像仍然把规范、执行状态、诊断和时间戳 rerun 记录混写在同一条权威链路里。若权威文档和代码冲突，以代码为准；若权威文档和运行日志冲突，以代码与最新验证证据为准。

## 1. 当前代码与仓库现状

从仓库结构和自动化约束看，文档已经不是“纯文字附属品”，而是自动化输入的一部分：

1. `.ops/stage3_ar/lib.sh:12-18` 把 `Docs/Stage_3_AR_Blueprint.md`、`Docs/Stage_3_Codebase_Audit.md`、`Docs/researches/Stage_3_AR/*` 写成固定路径常量。
2. `.ops/stage3_ar/lib.sh:68-81` 依赖每个 slot 的独立 research 目录和 `<!-- STAGE3_SECTION -->` 标记来做自动化切分。
3. `.ops/stage3_ar/worker_loop.sh:41-56` 进一步把 worker 的唯一可写范围限制为“一个蓝图 section + 一个 research 目录”，说明 Stage 3 自动化天然要求文档边界清晰、可机器定位。
4. `Docs/Stage2_Blueprint.md:5-7` 已经声明“唯一权威需求源”和“执行镜像不是第二需求源”；说明 repo 并不是没有分层意识，而是执行不彻底。
5. `Docs/ValidationLog_Xianxia_UIUX_Batch4.md` 已经展示了更健康的运行日志形态：按批次记录时间、环境、修改、验证与限制，且不负责定义新需求。

换句话说，仓库现实并不是“还没有分层”，而是“已有分层骨架，但 Stage 2 权威链路被混写打穿了”。

## 2. 当前文档偏差

当前最明显的偏差有四个：

1. `Docs/Stage2_Blueprint.md` 一边自称“唯一权威需求源”，一边在同一 checklist 下持续堆入大量 `拆分：2026-03-28 ...` 的 rerun 记录、环境探针和重复诊断，这让规范文本和证据文本混在了一起。
2. `Docs/Stage2_Blueprint_0328_Checklist.md` 本应只是执行镜像，但它又镜像了这些大段运行细节，结果镜像文件事实上承担了第二份运行日志职能。
3. `Docs/ValidationLog_*.md` 已经存在，但它们并没有成为运行证据的唯一归宿；同一批诊断信息仍在 Stage 2 蓝图与镜像里重复出现。
4. `Docs/sparelife_blueprint.md`、`Docs/Stage2_Blueprint.md`、`Docs/Stage_3_AR_Blueprint.md` 之间虽然分别承载产品、阶段与研究入口，但仓库里没有一张明确的“文档分层职责表”告诉维护者哪些内容允许写在哪一层。

`Docs/Stage_3_Codebase_Audit.md:133-170` 已经准确指出了这个问题：Stage 2 文档“吸收了过多执行日志”，验证项“混写了 requirement / implementation note / test coverage / manual validation / live probe / repeated timestamped rerun logs”。这个判断和当前文件内容是一致的。

## 3. 稳定 SOTA / 成熟实践

对一个既要靠人工阅读、又要被自动化 worker 消费的仓库，成熟做法不是让“一份大文档什么都写”，而是把文档分成四种语义层，再补一层生成镜像：

1. 规范层：定义“应该做什么”，只负责需求、边界、完成门槛、所有权。
2. 生成镜像层：定义“现在做到哪”，只负责状态、同步后的最小摘要、证据指针。
3. 证据层：定义“这次运行发生了什么”，强调时间、环境、命令、结果、阻塞，天然 append-only。
4. 研究层：定义“为什么应该这样改”，强调单议题分析、成熟实践、建议、顺序、风险。
5. 产品意图层：定义“产品想成为什么”，提供信息架构、定位、目标体验，但不直接裁定当前代码是否已经做到。

成熟实践背后的共识规则也很稳定：

1. 一个文档只承担一种 authority。规范文档不能顺手变成日志仓库，日志文档也不能偷偷新增需求。
2. 生成镜像只能反映权威文档和最新证据，不能引入新判断；否则它就会变成“第二权威源”。
3. 运行日志必须可追加、可回溯、可引用，但不应该淹没规范文本。
4. 研究报告应该是一 item 一文档的有边界分析，只有当建议被吸收入实施蓝图时，才进入规范层。

## 4. 面向本仓库的具体建议

### 4.1 五类文档职责表

| 文档层 | 建议角色定义 | 当前/建议文件 | 允许内容 | 禁止内容 | 更新方式 |
| --- | --- | --- | --- | --- | --- |
| 产品蓝图 | 长周期产品定位、信息架构、体验原则 | `Docs/sparelife_blueprint.md` | tab 定位、核心对象、信息架构、体验原则 | 时间戳 rerun、命令输出、环境探针、逐条运行 blocker | 人工维护，低频变更 |
| 实施蓝图 | 当前 stage 的唯一权威实施计划与完成门槛 | `Docs/Stage2_Blueprint.md`, `Docs/Stage_3_AR_Blueprint.md` | scope、interpretation order、checklist、ownership、完成标准、证据链接位 | 大段运行日志、重复 probe 记录、命令输出、每天的 rerun 历史 | 人工维护，受 ownership 约束 |
| 验证镜像 | 从实施蓝图或 guard 生成的状态镜像 | `Docs/Stage2_Blueprint_0328_Checklist.md` | 勾选状态、最小 blocker 摘要、最新证据链接 | 新需求、新建议、长篇诊断、运行过程叙述 | 生成优先，人工只修生成器 |
| 运行日志 | 按批次/日期记录验证动作与结果的 append-only 证据 | `Docs/ValidationLog_*.md` | 日期、环境、命令、结果、限制、blocker、证据截图/输出摘要 | 修改完成门槛、补写产品要求、改 checklist 语义 | 追加写入，按批次归档 |
| 研究报告 | 单 item 边界内的分析、成熟实践、改造建议 | `Docs/researches/Stage_3_AR/...` | 当前现状、文档偏差、成熟实践、建议、顺序、风险 | 跨 item 合并泛文、权威需求定义、运行日志流水账 | 一 item 一文档，人工维护 |

### 4.2 对当前文件的直接判定

1. `Docs/sparelife_blueprint.md` 应继续只承担产品蓝图职责，不再追加阶段性验证记录。
2. `Docs/Stage_3_AR_Blueprint.md` 当前结构是健康方向：它已经把 completion gate、worker ownership、research output root 分开写清楚，应当维持这种“规范层”形态。
3. `Docs/Stage2_Blueprint.md` 需要瘦身。它保留“范围、要求、权威 checklist、完成门槛”即可，所有 `拆分：2026-03-28 ...` 这类 rerun 证据应迁出到运行日志。
4. `Docs/Stage2_Blueprint_0328_Checklist.md` 需要回归“镜像层”。它可以保留状态和证据指针，但不应继续承载成百上千行诊断历史。
5. `Docs/ValidationLog_*.md` 已经是正确方向，应成为唯一允许写入详细运行过程的地方。

### 4.3 推荐的最小落地规则

1. 以后凡是带具体日期、命令、HTTP 返回、环境变量检查结果的内容，一律写入运行日志，不进蓝图正文。
2. 实施蓝图里的每个 checklist item 只保留“做什么 + 完成条件 + 证据路径”，不保留多轮 rerun 历史。
3. 验证镜像最多保留一行 blocker 摘要和一个最新证据指针，避免它再次膨胀成第二份蓝图。
4. 研究报告只负责“为什么这样收敛”，被采纳后的结论再回写到实施蓝图，不反向宣布自己是权威需求。

## 5. 实施顺序

1. 先冻结职责边界：从现在开始停止向 `Docs/Stage2_Blueprint.md` 和镜像继续追加新的时间戳 rerun 段落。
2. 再做 Stage 2 清理：把现有 `拆分：2026-03-28 ...` 历史按主题迁移到独立 `ValidationLog_*` 文件，Stage 2 蓝图只保留需求、状态和证据入口。
3. 然后瘦身镜像：让 `Docs/Stage2_Blueprint_0328_Checklist.md` 只保留勾选状态、必要的一行 blocker、以及对应证据路径。
4. 最后把这套职责表下沉到 guard/生成器规则里，让自动化在写入前就能拒绝“把日志写进蓝图”“把建议写进镜像”这类越界内容。

## 6. 风险

1. Stage 2 目前已经把大量历史探针写进蓝图和镜像，抽离时会产生一次较大的文档 diff；如果没有稳定链接，读者会短期内找不到旧证据。
2. 部分操作者可能已经习惯直接在蓝图里找“最新 blocker”。如果抽离日志后没有留下清晰证据入口，使用体验会先变差。
3. 如果只改文档、不改生成与 guard 规则，旧习惯会很快复发，镜像和蓝图会再次被运行日志污染。
