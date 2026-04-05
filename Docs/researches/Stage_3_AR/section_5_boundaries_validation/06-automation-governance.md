# S5-06 Stage 3 自动化运行规约

## 当前代码现状

1. Stage 3 自动化的控制面已经真实存在，而且关键常量都写在 `.ops/stage3_ar/lib.sh`。
   - 自动化根目录、`.cron` 状态目录、日志目录、automation clone 路径、权威 blueprint/audit/research root、guard state/heartbeat、slot state/prompt/last_message/heartbeat/log 文件名都被固定为脚本常量。证据在 `.ops/stage3_ar/lib.sh:3-25` 与 `:84-115`。
   - section marker、slot title、slot research dir 也都在这里定义，guard 和 worker 都依赖这些常量工作。证据在 `.ops/stage3_ar/lib.sh:35-82` 与 `:135-202`。
2. 当前所谓 automation clone，实际不是 Git `worktree`，而是一个“单独 `git init` 的镜像仓 + rsync 同步”的执行沙箱。
   - `setup_worktree.sh` 会在 `$WORKTREE_DIR` 下执行 `git init`、`remote add origin "$ROOT_DIR"`、`fetch`、`checkout`。证据在 `.ops/stage3_ar/setup_worktree.sh:8-20`。
   - 随后它再用 `rsync -a --delete` 把主仓复制到 clone，并显式排除 `.git/`、`.cron/`、`.build/`、`node_modules/`、`.ops/stage3_ar/automation-clone/`。证据在 `.ops/stage3_ar/setup_worktree.sh:23-40`。
   - 这意味着当前实现真相是“automation clone mirror”，不是“共享对象数据库的 git worktree”。
3. install 流程已经把验证、cron 和 worker 启动串起来了。
   - `install.sh` 先跑 `setup_worktree.sh`、`refresh_todo.sh`，再以 `VALIDATE_ONLY=1` 运行 guard。证据在 `.ops/stage3_ar/install.sh:6-11`。
   - 然后它用 `CRON_MARKER` 去重已有 crontab，并安装一条每 15 分钟执行一次 guard 的 cron。证据在 `.ops/stage3_ar/install.sh:13-22`。
   - 最后启动 5 个 slot worker。证据在 `.ops/stage3_ar/install.sh:24-28`。
4. worker ownership 既存在于 blueprint，也存在于 worker loop 的实际执行约束里。
   - Blueprint 规定 Slot 1-5 各自只拥有一个 section，并且 worker 只能改自己 section 和自己 research output dir。证据在 `Docs/Stage_3_AR_Blueprint.md:37-56`。
   - `worker_loop.sh` 每次只读取自己 slot 的 pending item，生成“唯一可写范围”“每项一文档”“完成后再勾选”的 prompt，并把 prompt 写入 `.cron`。证据在 `.ops/stage3_ar/worker_loop.sh:19-27`、`:29-57`。
   - 实际执行时，它把 `codex exec` 的工作目录固定到 `$WORKTREE_DIR`，并把最后一条消息写入 per-slot `last_message` 文件。证据在 `.ops/stage3_ar/worker_loop.sh:62-71`。
5. guard merge 现在是真正的单一回写入口。
   - `guard.sh` 会先检查 item 总数不超过 100，再跑 `refresh_todo.sh`。证据在 `.ops/stage3_ar/guard.sh:10-17`。
   - validate-only 模式下，它只校验已勾选 item 的 research doc 是否存在且非空，并写 guard state/heartbeat。证据在 `.ops/stage3_ar/guard.sh:18-24`。
   - 正常模式下，它逐 slot 抽取 clone blueprint 对应 section，用 section marker 回填主仓 blueprint，并把 slot research dir 从 clone `rsync` 回主仓。证据在 `.ops/stage3_ar/guard.sh:31-42`。
   - merge 完成后再次校验 checked docs、刷新 todo，并在全部 item 完成时触发 cleanup。证据在 `.ops/stage3_ar/guard.sh:44-55`。
6. cleanup 行为当前是强破坏性的。
   - `cleanup.sh` 会从 crontab 移除 `CRON_MARKER` 对应行。证据在 `.ops/stage3_ar/cleanup.sh:6-8`。
   - 它会停止全部 slot 对应的 tmux session。证据在 `.ops/stage3_ar/cleanup.sh:10-15`。
   - 当 `REMOVE_STAGE3_AUTOMATION=1` 时，它会直接删除 `.cron`、automation clone，以及整个 `.ops/stage3_ar` 目录。证据在 `.ops/stage3_ar/cleanup.sh:17-21`。
   - 也就是说，当前实现并不会默认保留运行审计轨迹或运维脚本副本。
7. operator handoff 今天主要依赖“产物自解释”，而不是显式 runbook。
   - 全局摘要文件：`.cron/stage3_ar.todo.md`、`stage3_ar_guard.state`、`stage3_ar_guard.heartbeat`。证据在 `.ops/stage3_ar/lib.sh:15-18` 与 `.ops/stage3_ar/refresh_todo.sh:9-26`。
   - per-slot 摘要文件：`stage3_ar_slotN.state`、`prompt.txt`、`last_message.txt`、`heartbeat`、`log`。证据在 `.ops/stage3_ar/lib.sh:84-102` 与 `.ops/stage3_ar/worker_loop.sh:19-23`。
   - 但当前没有任何 operator-facing 文档说明这些文件如何判读、什么叫 stale、什么时候该重建 clone、什么时候该停 worker。
8. 当前 worker 运行权限是高权限 lane。
   - `worker_loop.sh` 调用 `codex exec --dangerously-bypass-approvals-and-sandbox`。证据在 `.ops/stage3_ar/worker_loop.sh:62-68`。
   - 这并不代表实现错误，但它意味着 Stage 3 自动化不能只靠隐含脚本约束，还需要明示的 operator governance。

## 当前文档偏差

1. `Docs/Stage_3_AR_Blueprint.md` 只定义了 completion gate、worker ownership 和 research output root，并没有定义 install、automation clone 生命周期、guard merge 规则、cron 节奏、cleanup 模式或 operator handoff。证据在 `Docs/Stage_3_AR_Blueprint.md:26-56` 与 `:100-107`。
2. 一些 Stage 3 研究文档已经提到“自动化依赖 section marker 与 slot output dir”，但这只是说明文档被自动化消费，不等于自动化本身已经有运行规约。
   - 例如 `S1-02` 只指出 `.ops/stage3_ar` 依赖明确的文档边界。证据在 `Docs/researches/Stage_3_AR/section_1_truth/02-document-stratification.md:9-11`。
   - `S1-04` 也只是说明 docs 是自动化的输入之一。证据在 `Docs/researches/Stage_3_AR/section_1_truth/04-runtime-truth-map.md:48`。
3. 当前命名本身存在一个容易误导 operator 的偏差。
   - 脚本名叫 `setup_worktree.sh`，变量叫 `WORKTREE_DIR`。证据在 `.ops/stage3_ar/lib.sh:10` 与 `.ops/stage3_ar/setup_worktree.sh:1-4`。
   - 但实现不是 `git worktree add`，而是 `git init + fetch + checkout + rsync`。证据在 `.ops/stage3_ar/setup_worktree.sh:8-40`。
   - 所以任何把当前机制描述成“git worktree” 的口径都会和代码冲突。
4. 当前 repo 没有一份明确的“operator handoff 文档”解释：
   - 哪些文件是权威状态
   - heartbeat 过多久算异常
   - guard 失败时先看哪里
   - clone 什么时候应该重建
   - cleanup 完成前应保留哪些审计材料
5. 因此当前文档偏差的本质是：自动化脚本已存在，但运维规则仍然被埋在 shell 细节和动态 prompt 里，没有被提升成稳定治理文档。

## 稳定 SOTA / 成熟实践

1. 成熟的代码研究自动化应明确区分 control plane 与 execution sandbox。
   - control plane：权威 blueprint、completion gate、section ownership、merge policy
   - execution sandbox：automation clone、worker prompt、运行日志、临时状态文件
   - 两者之间只允许通过 guard 这类单一入口回写
2. install、worker、guard、cleanup 都应是幂等或接近幂等的运维动作。
   - 重跑 install 不应叠加重复 cron
   - 重跑 guard 不应破坏无关 section
   - cleanup 应可区分 pause / archive / destroy
3. section-scoped write ownership 不应只存在于“给模型的提示词”里，还应有 operator 可审计的规则描述和异常恢复流程。
4. operator handoff 最稳定的方式不是“看 terminal 记忆”，而是固定产物 + freshness SLA。
   - 总览 todo
   - 全局 guard state / heartbeat
   - per-slot state / heartbeat / last message / log
   - 明确 stale 阈值和对应动作
5. destructive cleanup 必须是显式动作，并在删除前先归档最低限度审计证据。否则自动化一结束，后验分析与交接就没有落点。
6. 高权限 automation lane 必须把权限边界写清楚。使用 bypass approvals / sandbox 的 runner 并不是禁忌，但前提是：
   - 执行范围被严格限定
   - merge 由单一 guard 负责
   - operator 知道自己在运行 privileged worker

## 面向本仓库的具体建议

1. 先把当前 Stage 3 自动化的术语固定下来，避免后续文档、脚本和操作口径继续漂移。
   - `authoritative blueprint`：主仓 `Docs/Stage_3_AR_Blueprint.md`
   - `automation clone`：`.ops/stage3_ar/automation-clone`
   - `worker-owned section`：Blueprint 中被 slot 独占的 section
   - `guard merge`：唯一允许把 clone section 回写到主仓的步骤
   - `operator handoff artifacts`：`.cron` 下的 todo/state/heartbeat/last_message/log
   - `cleanup-on-complete`：open item 归零后由 guard 触发的自动收尾行为
2. 明确写下“主仓是唯一权威，automation clone 只是执行沙箱”的治理规则。
   - worker 永远只在 clone 写入。
   - 主仓 section 只能由 guard merge 回写。
   - operator 不应在自动化运行期间同时手改主仓和 clone 的同一 section；如果必须手改，先暂停 worker，再重建 clone。
3. 把当前已有但未文档化的 handoff artifacts 正式列成运维契约。
   - 全局：`.cron/stage3_ar.todo.md`、`stage3_ar_guard.state`、`stage3_ar_guard.heartbeat`
   - 单 slot：`stage3_ar_slotN.state`、`stage3_ar_slotN.heartbeat`、`stage3_ar_slotN.last_message.txt`、`stage3_ar_slotN.log`
   - 这些文件应被认定为 operator 的第一观察面，而不是附属调试信息。
4. 为 operator handoff 增加最小可执行判读规则。
   - `guard.heartbeat` 超过约定窗口未更新，先检查 `guard.state` 与 guard log。
   - `slotN.heartbeat` stale 但 tmux 仍在，先看 `slotN.log` 与 `slotN.last_message.txt`。
   - `slotN.state` 长期停在 `failed`，优先修 blueprint/doc path/owned-scope 问题，再恢复 worker。
   - `todo.md` 与 blueprint open item 数不一致时，先重跑 `refresh_todo.sh` 与 `guard.sh`，再判断是否存在 merge 异常。
5. 当前 clone lifecycle 需要被正式治理，而不是继续依赖 operator 记忆。
   - automation clone 不是持久协作仓，它可以被销毁和重建。
   - 以下情况建议强制重建 clone：主分支切换、section marker 变更、worker ownership 变更、主仓已被人工批量更新、guard 发现 section 无法安全抽取。
   - 由于现实现只在 install 阶段 `rsync` 主仓到 clone，后续主仓若发生外部变更，clone 会天然变 stale。证据在 `.ops/stage3_ar/install.sh:9-11` 与 `.ops/stage3_ar/setup_worktree.sh:33-40`。
6. guard merge 目前已经有“只回写 section + research dir”的良好基础，但还需要补 operator 规则。
   - 当前它能校验 marker、item 总数、checked docs 是否存在。证据在 `.ops/stage3_ar/guard.sh:7-14` 与 `:44-50`。
   - 建议长期再补两层治理：clone base provenance 记录、以及“拒绝 merge 非 owned dir 的改动”。
   - 这两层即便短期不立刻实现，也必须先写进 runbook，避免人以为 prompt 约束就等于硬隔离。
7. 当前 cleanup 行为应拆成三种模式，而不是只保留一种破坏性收尾。
   - `pause`：停止 cron / tmux，但保留 `.cron` 与 automation clone
   - `archive`：导出 `.cron` 状态、最后一次 todo、last_message、guard state，再准备销毁
   - `destroy`：删除 `.cron`、clone、`.ops/stage3_ar`
   - 当前实现的 `REMOVE_STAGE3_AUTOMATION=1` 实际上直接跳到 `destroy`，缺少显式 archive 步骤。证据在 `.ops/stage3_ar/cleanup.sh:17-21`。
8. 建议把当前动态 prompt 中那些关键治理规则，升格成静态 runbook，而不是继续只存在于 `worker_loop.sh`。
   - 唯一可写范围
   - 每 item 一文档
   - 达到 completion gate 才能勾选
   - 最后一条消息必须列完成项与 doc 路径
   - 这些规则今天真实存在于 `worker_loop.sh:39-57`，但 operator 不打开脚本就看不到。
9. 由于当前 worker 以高权限 `codex exec` 运行，建议正式把它标记为 privileged automation lane。
   - 这不需要改变当前实现路径。
   - 但必须在规约中写明：只有在 automation clone、slot ownership、guard merge 三者都有效时，才允许启动 worker。

## 实施顺序

1. 先输出一份 operator-facing runbook，固定术语、角色、手动命令入口与 handoff artifacts。
2. 再把 stale heartbeat、failed state、guard validate-only 失败这三类最常见异常的恢复路径写成表格化规则。
3. 然后补 clone lifecycle 规则：何时刷新、何时重建、何时禁止人工并行修改主仓对应 section。
4. 接着强化 guard merge 的 provenance 与 foreign-write 审计要求。
5. 最后才调整 cleanup，实现 pause / archive / destroy 三段式，而不是直接删光。

## 风险

1. 当前 cleanup 完成后可以直接删除 `.cron`、automation clone 和 `.ops/stage3_ar`，这会让 postmortem、handoff、复盘几乎无迹可循。证据在 `.ops/stage3_ar/cleanup.sh:17-21`。
2. 当前 clone 只在 install 时与主仓对齐一次，后续主仓若有人工变更，worker 可能在 stale clone 上继续推进，最终由 guard merge 回写出意外覆盖或冲突。证据在 `.ops/stage3_ar/install.sh:9-11` 与 `.ops/stage3_ar/setup_worktree.sh:33-40`。
3. 当前 ownership 约束主要通过 prompt 与目录约定表达，并没有实现“技术上绝不可能越界写”的硬隔离，因此 operator 不能把提示词当成完整防线。证据在 `.ops/stage3_ar/worker_loop.sh:39-57`。
4. `WORKTREE_DIR` / `setup_worktree.sh` 的命名会让人误以为这里具备真实 git worktree 的刷新与引用语义，但实现并非如此；如果 operator 基于错误心智模型操作，恢复路径会走偏。
5. 高权限 `codex exec --dangerously-bypass-approvals-and-sandbox` 使这条自动化 lane 天然带有运维风险；如果没有显式 runbook 和 handoff 规则，系统越自动，责任边界反而越模糊。证据在 `.ops/stage3_ar/worker_loop.sh:62-68`。

代码和旧文档冲突时，本条研究结论以代码为准。
