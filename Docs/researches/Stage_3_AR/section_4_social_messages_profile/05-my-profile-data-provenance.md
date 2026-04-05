# S4-05 `MyProfileView` root profile 数据来源层级

## 当前代码现状

1. `MyProfileView` 当前的 root store 仍然是本地 seed store。`MyProfileStore.load()` 在一次固定 600ms 延迟后，直接写入 `UserProfile` 与 `AvatarPublicProfile`，其中 `displayName`、`handle`、`bio`、`avatarAnimal`、`energyBalance`、`socialConnections`、`joinedDate`、`nickname`、`personalityTraits` 都是在 view 文件内硬编码出来的，而不是从独立 repository 或 overview aggregator 注入。证据在 `spare-life-ios-app/Features/MyProfile/MyProfileView.swift:84-130`。
2. root hero 的三张统计卡完全依赖 `UserProfile` 上的混合字段：
   - `闲能` 直接读 `profile.energyBalance`
   - `社交连接` 直接读 `profile.socialConnections`
   - `入驻天` 直接从 `profile.joinedDate` 计算
   这意味着“身份资料”和“跨模块统计”仍然被塞在同一个 `UserProfile` 结构里。证据在 `spare-life-ios-app/Features/MyProfile/MyProfileView.swift:531-654`。
3. root feature cards 也还没有真实 provenance：
   - 同步度卡写死 `72%`
   - 人格卡写死 `INTP / 逻辑学家`
   - 记忆卡写死 `248 条记忆`
   - 隐私卡写死 `12.4 MB`
   这些数字和文案都直接放在 `MyProfileView.swift` 的 UI 层，而不是来自 `MyProfileOverviewMetrics.swift` 或 detail screen 的派生快照。证据在 `spare-life-ios-app/Features/MyProfile/MyProfileView.swift:222-420`。
4. `MyProfileOverviewMetrics.swift` 已经存在一组更接近“root overview provider”的数据能力，但它们还没有成为 root page 的真相来源：
   - `MyProfileXianrenStatsRepository` 会走 `XianxiaTopicRepository` 的 live fetch 和 cache fallback 聚合
   - `MyProfileMasterStatsProvider` 会读 `MasterConversationLocalStateStore`
   - `MyProfileEarnSocialStats` 与 `MyProfileMessageStats` 目前还是 `static let mock`
   证据在 `spare-life-ios-app/Features/MyProfile/MyProfileOverviewMetrics.swift:3-147`。
5. 也就是说，当前 root page 的真实结构不是“已接上 overview metrics”，而是“两套并存的数据世界”：
   - `MyProfileView.swift` 里的 root identity + card copy + hero stats
   - `MyProfileOverviewMetrics.swift` 里的跨模块 live-ish / mock metric providers
   当前两者还没有汇合。
6. `Stage_3_Codebase_Audit.md` 对这一点的判断是准确的：root page 仍然是 mock-heavy，但附近已经有更真实的统计 provider。证据在 `Docs/Stage_3_Codebase_Audit.md:95-108`。

## 当前文档偏差

1. 仓库审计文档本身没有偏差，偏差主要来自更早的功能验证日志与 support runtime 叙述。
2. `ValidationLog_My_FUNC_Batch1.md` 把 `My Profile`、同步度、人格、记忆、成长、隐私都写成“persisted and returned end-to-end”，而且证据主体是 `myContracts.mjs`、`myDashboardService.mjs`、SQLite backend、OpenClaw runtime 和 demo 脚本。那是 support/backend runtime 的真实能力，不是当前 Swift root page 的已接线事实。证据在 `Docs/ValidationLog_My_FUNC_Batch1.md:12-17` 与 `Docs/ValidationLog_My_FUNC_Batch1.md:23-57`。
3. `ValidationLog_UnifiedUI_FUNC_Batch1.md` 也把“卡片化的我的首页”写成真实 waterfall home evidence，但它验证的是 Node/SQLite 的 unified UI synthesis surface，不是当前 `MainTabView -> MyProfileView` 这条 Swift runtime。证据在 `Docs/ValidationLog_UnifiedUI_FUNC_Batch1.md:11-15`。
4. 与上述日志相比，当前 Swift root page 仍然把 `72% / INTP / 248 / 12.4MB` 和 `2480 / 87 / joinedDate` 写在页面文件里。只要代码还是这样，Stage 3 后续研究就必须明确区分：
   - 当前 shipped Swift root page
   - 仓库里更完整的 support/runtime simulation
   - 未来要收口的统一 profile data pipeline
5. 因此，本 item 的目标不是“把 support runtime 说成已经接好了”，而是“先把 root profile 的 ownership 和 provenance 写清楚，再决定哪些部分该接 live-ish provider，哪些部分暂时保留 seeded fallback”。

## 稳定 SOTA / 成熟实践

1. root profile 页通常不应该直接持有混合 ownership 的“大一统用户结构”。成熟做法会至少拆成三层：
   - 可编辑身份资料 `identity snapshot`
   - 只读概览聚合 `overview snapshot`
   - 面向页面的展示投影 `presentation snapshot`
2. `identity snapshot` 负责用户可编辑或相对稳定的资料：
   - 昵称
   - handle
   - bio
   - avatar
   - public avatar/profile visibility
   - joined date
   这些字段应该来自同一个 owner，而不是和能量、社交总量之类派生统计混在一起。
3. `overview snapshot` 负责跨模块聚合指标，并且每项指标都要带 provenance / freshness 语义，例如：
   - `live`
   - `cached`
   - `seeded`
   - `unavailable`
4. root page 应只消费一份聚合后的 `presentation snapshot`，而不是在 SwiftUI file 里临时拼一些 hardcoded 常量，再去别的文件放另一套 provider。
5. 当某些模块暂时没有真实 provider 时，placeholder 也应被提升到“聚合层的显式 seeded fallback”，而不是埋在 UI 层。这样后续替换 provider 时，只需要动 adapter，不需要重新翻 UI 文件找字面量。
6. 派生统计不应该回写进身份资料模型。像 `energyBalance`、`socialConnections` 这类字段如果没有稳定 owner，就不该继续长在 `UserProfile` 这种“可编辑资料结构”里。
7. fallback 顺序应明确而稳定：`live -> cached -> seeded -> unavailable`。这样 root page 的状态可解释、可测试，也更适合后续自动化验证。

## 面向本仓库的具体建议

### 建议的数据来源层级

| 层级 | 应持有的字段 | 当前代码现实 | 面向本仓库的建议 owner |
| --- | --- | --- | --- |
| `identity` | `displayName`, `handle`, `bio`, `avatarAnimal`, `joinedDate`, `avatarProfile.nickname`, `avatarProfile.tagline`, `visibleFields` | 全部写在 `MyProfileStore.load()` 里 | 近期先收敛成 `MyProfileIdentitySeed` / `MyProfileIdentityRepository`；不要继续夹带 overview 指标 |
| `overview-liveish` | `xianxia` topic/channel/entity/mention 聚合，`masters` session/interactions 聚合 | 已在 `MyProfileOverviewMetrics.swift` 里存在，但 root 未消费 | 保持在 `MyProfileOverviewMetrics.swift`，由 root aggregator 统一读取 |
| `overview-seeded` | earn social / messages / sync / memory / privacy 这些暂时没有稳定 Swift provider 的指标 | 一部分在 `MyProfileOverviewMetrics.swift` mock，一部分散落在 `MyProfileView.swift` | 全部收口到 overview 层；UI 文件不再出现裸字面量 |
| `presentation` | hero 三卡、四张 feature cards 的展示文案与数值 | 目前在 view 层直接拼接 | 新增 root presentation mapping，只让 `MyProfileView` 读取成品 snapshot |

### 字段级 ownership 建议

| root surface 字段 | 当前来源 | 建议来源层 |
| --- | --- | --- |
| `displayName / handle / bio / avatarAnimal` | `MyProfileStore.load()` 本地 seed | `identity` |
| `joinedDate` 与“入驻天” | `MyProfileStore.load()` + `daysSince()` | `identity` 提供原始日期，`presentation` 负责显示格式 |
| `闲能` | `UserProfile.energyBalance` seed | 独立 overview 指标；在真实 provider 未出现前，先作为 `seeded overview metric`，不要继续挂在 `UserProfile` |
| `社交连接` | `UserProfile.socialConnections` seed | overview 聚合值；未来应由 messages / masters / earn-social 组合得出 |
| 同步度卡 `72%` | UI 字面量 | 统一迁到 overview 层；未来对齐 sync dashboard provider |
| 人格卡 `INTP / 逻辑学家` | UI 字面量 | 统一迁到 overview 层；未来对齐 awakening/persona surface |
| 记忆卡 `248` | UI 字面量 | 统一迁到 overview 层；未来对齐 memory palace summary |
| 隐私卡 `12.4 MB / 本地后端运行中` | UI 字面量 | 统一迁到 overview 层；未来对齐 privacy/local-backend status |

### 推荐的 root snapshot 形态

```swift
struct MyProfileRootSnapshot {
    let identity: MyProfileIdentitySnapshot
    let publicAvatar: MyProfilePublicAvatarSnapshot?
    let overview: MyProfileOverviewSnapshot
    let presentation: MyProfilePresentationSnapshot
}
```

其中：

1. `identity` 只放稳定资料，不再携带 `energyBalance` / `socialConnections`。
2. `overview` 负责跨模块指标，并给每项指标标注 `live / cached / seeded / unavailable`。
3. `presentation` 负责把 overview 指标翻译成 hero cards 与 feature card copy，避免 UI 再嵌字面量。

### 对当前仓库最小返工、但可持续收敛的落地策略

1. 不要等“所有 detail screen 都有真实 provider”才开始收口 provenance。当前就可以先把 root page 里的裸字面量迁到一个 overview adapter 层。
2. `MyProfileOverviewMetrics.swift` 已经天然是候选聚合层。建议继续沿用它，但把职责从“散落的 provider/types”升级为“root overview data boundary”。
3. 近期可以接受的 truth ladder：
   - `xianxia`: `MyProfileXianrenStatsRepository` live/cached
   - `masters`: `MyProfileMasterStatsProvider` live-ish local state
   - `earn social`: seeded fallback，但定义在 overview 层
   - `messages`: seeded fallback，但定义在 overview 层
   - `sync / personality / memory / privacy`: seeded fallback，但定义在 overview 层
4. 对 root page 来说，最关键的不是“现在全部 live”，而是“每个数字都能回答它从哪来、为什么是 seed、后面该由谁接手”。
5. 这也意味着 `MyProfileView.swift` 未来应退回成纯展示页：
   - 只读 root snapshot
   - 发编辑 action
   - 不再自己制造 profile 世界观

## 实施顺序

1. 先冻结 provenance map，把 `MyProfileView.swift` 里的所有数值字段分类成 `identity`、`overview-liveish`、`overview-seeded`。
2. 然后把 `72% / INTP / 248 / 12.4MB / energyBalance / socialConnections` 从 `MyProfileView.swift` 抽出，集中到 overview adapter 层。
3. 再让 root store 不直接发布 `UserProfile`，而是发布 `MyProfileRootSnapshot` 或同等聚合投影。
4. 之后把 `MyProfileXianrenStatsRepository` 与 `MyProfileMasterStatsProvider` 接到 root snapshot 上，并为每项指标补 freshness/source 标签。
5. 最后再分别替换 seeded fallback：
   - earn social / messages provider
   - sync/persona/memory/privacy provider
   - 真实 identity repository

## 风险

1. 如果继续让 `UserProfile` 同时承载可编辑资料和 overview 统计，后续任何一个指标改 source of truth 都会碰 root identity 结构，返工范围会持续扩大。
2. 如果 root page 继续保留 UI 层裸字面量，即使 detail screen 或 support runtime 已经变真，首页数字也会继续和真实子页脱节。
3. `MyProfileXianrenStatsRepository` 当前对 `XianxiaTopicRepository.fetchTopics()` 的返回语义有隐式耦合；此前 Stage 3 研究已经指出它依赖 repository 的累计 items 语义。若后续 topic repository contract 调整，profile overview 聚合会被联动影响。证据可参考 `Docs/researches/Stage_3_AR/section_3_xianxia_masters/02-xianxia-gateway-contract.md:129` 与 `Docs/researches/Stage_3_AR/section_3_xianxia_masters/02-xianxia-gateway-contract.md:401`。
4. 当前 support/backend 验证日志已经把 profile cluster 写得很“真”，如果不在 root page 层明确 provenance，后续 worker 很容易再次误把 support runtime 当成 Swift 首页的已接线事实。
5. 当前还没有真实的 Swift identity repository。若为了“看起来统一”而过早把 support-side my-dashboard model 直接宣称为 root identity truth，会再次制造“文档比运行时更完整”的偏差。
