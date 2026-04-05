# S1-06 Stage 级验证证据格式重构方案

结论先行：当前仓库并不是完全没有“需求和证据分层”，而是已经出现了两种方向相反的形态。健康的一侧是 `Docs/ValidationLog_*.md` 与 `masters-preview-validation.json` 这类独立证据；失控的一侧是 `Docs/Stage2_Blueprint.md` 与 `Docs/Stage2_Blueprint_0328_Checklist.md` 把权威需求、状态镜像和时间戳 rerun 历史混在了同一层。以当前代码和文档现状看，Stage 级证据格式应该收敛成四层：`authoritative requirement`、`status mirror`、`batch validation log`、`machine-readable artifact`。如果旧文档和代码或最新证据冲突，以代码和最新证据为准。

## 1. 当前代码与仓库现状

### 1.1 Stage 3 自动化已经天然要求“权威蓝图”和“研究输出”分离

`Docs/Stage_3_AR_Blueprint.md` 当前已经把几个关键边界写清楚了：

1. 只有一个 authoritative blueprint。
2. 每个 item 只能对应一份独立 research doc。
3. worker 只能改自己的 section 和 research 目录。
4. completion gate 先看 research doc 是否存在且内容合格，再允许勾选。

这说明 Stage 3 的治理框架本身已经默认“权威需求文本”不该兼做运行日志仓库。

### 1.2 `Docs/ValidationLog_*.md` 已经展示出更健康的运行证据格式

当前多个 `ValidationLog` 文件已经具备稳定结构，例如：

1. `Worker`
2. `Date`
3. `Blueprint source`
4. `Items Addressed`
5. `Changes`
6. `Validation Commands`
7. `Environment Limitations`
8. `Loop Gate Self-Assessment`

这类文档虽然还没有完全 machine-parse 的统一 schema，但至少在职责上已经接近“独立证据层”，不会直接篡改需求本身。

### 1.3 `Masters` 自动化已经在写结构化结果文件，这比把日志塞进蓝图健康得多

当前 `MasterConversationLocalStateStore` 会把自动化结果写到独立的 `masters-preview-validation.json`。对应测试已经证明这份 JSON 会落地至少这些字段：

1. `command`
2. `success`
3. `masterID`
4. `visibleMasterCount`
5. `totalMasterCount`
6. `matchedCoverageCount`
7. `hasExactStage1Coverage`
8. `transcriptCount`
9. `serviceMode`
10. `serviceTitle`
11. `serviceDetail`
12. `serviceRequestURL`
13. `serviceCatalogURL`
14. `serviceSourceSummary`
15. `serviceAdvertisedModels`
16. `serviceBlockerCode`
17. `error`

也就是说，仓库已经在用一份单独 artifact 表达“这次验证到底发生了什么”，而不是只能靠蓝图里的一长串自然语言 bullet 复盘。

### 1.4 Stage 2 蓝图和镜像当前仍然把时间戳 rerun 历史混写到权威层

当前最明显的问题不是没有日志，而是日志写错了地方：

1. `Docs/Stage2_Blueprint.md` 自称唯一权威需求源，但 4.3 `闲聊` section 已经吸入了大量 `拆分：2026-03-28 ...` 运行记录。
2. `Docs/Stage2_Blueprint_0328_Checklist.md` 自称只是 mirror，却又复制了几乎同样的时间戳记录。
3. 当前这两份文档都包含 `50` 条 `拆分：2026-03-28` rerun 段落。它们不是 requirement statement，而是 timestamped execution history。

这意味着同一份信息在“权威需求层”和“状态镜像层”被重复存储，还都带上了运行日志语义。

### 1.5 当前仓库已经有三种证据载体，但没有被统一编排

从代码和文档看，现有证据其实已经分成三种：

1. Markdown 运行日志
   `Docs/ValidationLog_*.md`
2. 结构化 JSON 结果
   例如 `masters-preview-validation.json`
3. Stage 文档里的自然语言 rerun 记录

前两种都可以继续演化，第三种应该被收回。因为它一旦进入 authoritative blueprint，就会把 requirement text 污染成操作日志。

## 2. 当前文档偏差

当前 Stage 级验证证据最主要的偏差有五个：

1. `Docs/Stage2_Blueprint.md` 一边声明自己是唯一权威需求源，一边持续吸纳 rerun 命令、环境探针和时间戳观察，导致 requirement 和 execution history 混层。
2. `Docs/Stage2_Blueprint_0328_Checklist.md` 一边声明自己只是 mirror，一边又镜像同样的历史日志，实际上变成了第二个日志仓库。
3. `ValidationLog` 已经存在，却没有被明确设为“唯一允许承载时间戳 rerun 历史的文档层”。
4. 结构化结果文件已经存在，但 Stage 文档没有统一把它们当成 evidence artifact，只是偶尔在自然语言里提到。
5. 当前 Stage 文档的 bullet 往往同时承担三件事：`需求陈述`、`最新 blocker 解释`、`运行历史归档`。这让 diff、审阅、自动化同步都会持续变脏。

## 3. 稳定 SOTA / 成熟实践

对需要长期演进、又要被 automation 安全消费的仓库，成熟做法很稳定：

1. `authoritative requirement` 只说“应该做什么”和“何时算完成”。
2. `status mirror` 只说“现在完成到哪”和“最新证据指针是什么”。
3. `batch validation log` 只说“本次是怎么验证的、遇到了什么限制、结果如何”。
4. `machine-readable artifact` 只负责让 guard、脚本、自动化和后续 diff 能稳定解析 outcome。

这四层背后还有三条成熟纪律：

1. `latest state` 和 `append-only run history` 必须分离。
2. 人类摘要和机器证据必须分离，但要相互引用。
3. Stage 文档可以引用证据，不能吸收证据正文。

如果不守这三条纪律，蓝图最终一定会膨胀成“需求 + 日志 + 回忆录”的混合体。

## 4. 面向本仓库的具体建议

### 4.1 建议采用四层 Stage 证据包

建议以后所有 Stage 级验证都按下面四层组织：

| 层级 | 建议载体 | 责任 | 禁止内容 |
| --- | --- | --- | --- |
| `authoritative requirement` | `Docs/Stage*_Blueprint.md` | requirement statement、completion gate、evidence pointer | 时间戳 rerun 历史、命令输出、长段 blocker 复读 |
| `status mirror` | `Docs/Stage*_Checklist*.md` | 勾选状态、最新 blocker code、最新 evidence pointer | 新需求、新建议、长篇运行叙述 |
| `batch validation log` | `Docs/ValidationLog_*.md` | 本批命令、环境、结果、限制、人工摘要 | 改 requirement、改完成门槛、重复镜像整段蓝图 |
| `machine-readable artifact` | `*.json` / `*.jsonl` 结果文件 | 稳定字段、automation consume、精确 blocker 与 outcome | 自由散文式说明、模糊状态词 |

这四层已经和当前仓库现有资产天然对齐，不需要发明新范式。

### 4.2 建议把 Stage 文档中的“最新状态”压缩成最小摘要

以后 Stage 蓝图里的每个 item 最多只保留：

1. requirement 本身
2. 当前勾选状态
3. 一个最新 evidence pointer
4. 必要时一个 blocker code 或一句 blocker summary

例如 Stage 2 的 ASR 主项不应该继续挂 10 多条 `2026-03-28 已再次复核...`。它只需要留下类似：

```md
- [ ] 闲聊聊天框接入 ClawDB 服务器的 ASR 接口，支持语音识别输入并正确回填到对话发送链路。
  Latest evidence: Docs/ValidationLog_Masters_FUNC_BatchX.md
  Blocker: asr_live_endpoint_unavailable
```

时间戳 rerun 细节则全部留在 validation log 或 JSON artifact。

### 4.3 建议把 `ValidationLog` 收敛成统一 header，而不是继续自由发挥

结合 S1-03 的追踪格式，建议 `ValidationLog` 统一顶层结构为：

```md
## Trace
- stage_items: ...
- bp_refs: ...
- code_refs: ...
- artifact_refs: ...

## Summary
- result: passed | blocked | failed | partial
- blocker_code: ...
- latest_run_at: ...
- environment_class: node | preview-host | simulator | device | docs-only

## Commands
...

## Environment Limitations
...

## Run Notes
...
```

这样做有两个直接好处：

1. 人类依然能读到过程。
2. automation 不必再从自然语言 paragraph 里猜“这次到底 pass 了还是 blocked 了”。

### 4.4 建议把 `masters-preview-validation.json` 升级为 Stage 结构化证据的样板

当前 `masters-preview-validation.json` 已经证明这种结构化结果是可行的。建议把它的思路扩成仓库级样板：

1. 通用元字段
   `stage`, `command`, `success`, `run_at`, `environment_class`
2. 验证范围字段
   `stage_items`, `surface`, `sessionID`
3. 结果字段
   `serviceMode`, `serviceTitle`, `serviceBlockerCode`, `error`
4. 证据字段
   `requestURL`, `catalogURL`, `sourceSummary`, `advertisedModels`
5. 计数字段
   `visibleMasterCount`, `matchedCoverageCount`, `transcriptCount`

以后无论是 ASR、k2p5、Xianxia feed，还是 preview host smoke，都可以复用同一结果 schema，而不是把关键 outcome 只写在 Markdown prose 里。

### 4.5 建议立即纠偏的三个地方

1. 从现在开始停止向 `Docs/Stage2_Blueprint.md` 和 `Docs/Stage2_Blueprint_0328_Checklist.md` 追加新的时间戳 rerun bullet。
2. 把 Stage 2 现有的 rerun 历史迁回 `Docs/ValidationLog_*` 或新的按主题归档的 run log。
3. 让 guard / mirror 生成逻辑以后只同步 `status + latest evidence pointer + blocker code`，不再同步整段运行历史。

## 5. 实施顺序

1. 先冻结写入规则：Stage 蓝图和 mirror 不再接受新的时间戳 rerun 段落。
2. 再定义统一 evidence header，让 `ValidationLog` 和 JSON artifact 都能稳定携带 `stage_items / result / blocker_code / artifact_refs`。
3. 然后把 Stage 2 里最膨胀的 ASR 与 `k2p5` 运行历史迁出到独立日志。
4. 接着以 `masters-preview-validation.json` 为样板，补出更多 surface 的 machine-readable result 文件。
5. 最后才让 mirror/guard 生成器完全切换到新的最小摘要格式，避免旧内容继续回流。

## 6. 风险

1. 如果只删除蓝图里的历史日志，却没有留下明确 evidence pointer，读者会短期失去定位能力。
2. 如果只有 Markdown 日志而没有结构化 artifact，automation 仍然得靠文本猜状态，后续返工还会出现。
3. 如果只设计格式、不改生成器和 guard，镜像文件很快会再次被运行历史污染。
4. 历史迁移会产生一次较大的文档 diff；如果没有 blocker code 和 artifact path，旧证据会更难搜索。
5. 如果把 `ValidationLog` 写成第二份 requirement 文档，只是把问题从 Stage 蓝图挪到了另一个文件名，治理并不会真的收敛。

代码和旧文档冲突时，本条研究结论以代码为准；蓝图和最新验证证据冲突时，Stage 状态应以后者为准，而不是继续沿用过时 rerun 文字。
