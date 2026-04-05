# S4-06 跨 tab handoff 契约

## 当前代码现状

1. 根壳层当前只有两个与导航相关的状态：
   - `selectedTab`
   - `ConversationRouter.activeChatThread`
   `MainTabView` 会把 5 个 tab 直接挂到 `TabView`，并额外用 `.fullScreenCover(item: $router.activeChatThread)` 承载一个消息线程 modal。这里没有 per-tab route state、没有 handoff envelope、没有 deep-link parser。证据在 `spare-life-ios-app/App/MainTabView.swift:58-130` 与 `spare-life-ios-app/App/ConversationRouter.swift:1-13`。
2. `XianxiaHomeView` 的当前 Swift runtime 只有 tab 内部导航：列表点击后把 `activeTopic` 设为非空，再 push 到 `SceneTopicView`。它没有任何“切到赚闲能”的 handoff state。证据在 `spare-life-ios-app/Features/Xianxia/XianxiaHomeView.swift:6-41`。
3. 与 Xianxia Swift runtime 相比，support 层已经会生成 `xianxia -> earn social` 的 route：`sceneIntentGuard.mjs` 通过 `buildSocialRoute(intentId, sceneKey)` 写出 `sparelife://earn-social/match?intent_id=...&scene_key=...`。但当前 Swift root shell 并没有消费者。证据在 `spare-life-ios-app/Services/SceneRadar/sceneIntentGuard.mjs:72-85` 与 `spare-life-ios-app/Domain/Models/sceneContracts.mjs:102-107`。
4. `masters` 当前的真实 UI 主路径是：
   - `MasterChatHomeView` 用本地 `showConversation` 布尔值打开 `MasterConversationView`
   - 不是 cross-tab handoff，也不是 typed route
   证据在 `spare-life-ios-app/Features/Masters/MasterChatHomeView.swift:9-49` 与 `spare-life-ios-app/Features/Masters/MasterChatHomeView.swift:148-164`。
5. `MasterExperienceStore` 已经会生产跨 tab route 字符串：
   - `sparelife://messages/self?draft=...`
   - `sparelife://my/profile?highlight=memory`
   但这些 route 目前只是 store 内部 recommendation data；仓库已有 Stage 3 研究明确指出 `routePreview` 在当前 Swift UI 里没有稳定展示面。证据在 `spare-life-ios-app/Features/Masters/MasterExperienceStore.swift:1207-1244` 与 `Docs/researches/Stage_3_AR/section_3_xianxia_masters/04-master-store-decomposition.md:159-167`。
6. `messages` tab 当前也没有 cross-tab 入口承接能力。`ConversationHubView` 自己起 `NavigationStack`，只支持 hub 内部 push 到 `ChatThreadView`，toolbar 里的 `新建对话 / 新建群聊` 仍是空 action。证据在 `spare-life-ios-app/Features/CompanionChat/ConversationHubView.swift:12-45` 与 `spare-life-ios-app/Features/CompanionChat/ConversationHubView.swift:93-99`。
7. `earn social` 当前 active runtime 仍然是本地 mock cards + 本地 sheet 聊天预览。`EarnSocialHomeView` 点卡片只会把 `activeCard` 设为当前 mock card，然后打开 `EarnSocialMockChatView` sheet；它并不消费任何 `threadRoute`。证据在 `spare-life-ios-app/Features/EarnSocial/EarnSocialHomeView.swift:6-50` 与 `spare-life-ios-app/Features/EarnSocial/EarnSocialHomeView.swift:620-710`。
8. 与当前 active runtime 不同，`EarnSocialExperienceStore` 与 `a2aContracts.mjs` 已经存在两种不同的 `earn social -> messages` route 形状：
   - `messages/thread?lane=...&counterpart=...`
   - `messages/thread?bond_id=...&icebreak_session_id=...`
   这说明生产端已经分叉，但消费端还不存在。证据在 `spare-life-ios-app/Features/EarnSocial/EarnSocialExperienceStore.swift:913-915` 与 `spare-life-ios-app/Domain/Models/a2aContracts.mjs:482-490`。
9. profile 路径在代码层也已经分叉：
   - `MasterExperienceStore` 还在写 `sparelife://my/profile?highlight=memory`
   - `myContracts.mjs` 的集中 builder 已经改成 `sparelife://me/...`
   这意味着光看字符串 path 已经无法判断哪一个才是“真 contract”。证据在 `spare-life-ios-app/Features/Masters/MasterExperienceStore.swift:1227-1233` 与 `spare-life-ios-app/Domain/Models/myContracts.mjs:160-189`。
10. 总结当前运行真相：生产端很多，根壳层消费者几乎没有；而且同一目标 surface 的 payload 形状已经开始分叉。

## 当前文档偏差

1. `Stage_3_Codebase_Audit.md` 与 Section 2 的 shell 研究，对“当前没有 typed route / deep-link dispatcher / cross-tab handoff coordinator”这一点判断是准确的。证据在 `Docs/Stage_3_Codebase_Audit.md:27` 与 `Docs/researches/Stage_3_AR/section_2_shell_ui/02-navigation-presentation-contract.md:186-231`。
2. 真正的偏差来自仓库里越来越多“像 route contract 的字符串”和 support/runtime 验证材料，它们容易让读者误判这些 handoff 已经在 Swift shell 中闭环。
3. `ValidationLog_UnifiedUI_FUNC_Batch1.md` 与 `ValidationLog_My_FUNC_Batch1.md` 验证的是 Node/SQLite support runtime，不是 `MainTabView` 当前这条 Swift tab handoff 路径。证据在 `Docs/ValidationLog_UnifiedUI_FUNC_Batch1.md:11-20` 与 `Docs/ValidationLog_My_FUNC_Batch1.md:12-17`、`Docs/ValidationLog_My_FUNC_Batch1.md:23-57`。
4. 当前最危险的文档偏差不是“没有 route 字符串”，而是“有 route 字符串就像已经有 handoff contract”。从代码事实看，这还不成立。
5. 因此，S4-06 不应该再继续扩散新的 ad-hoc URI，而应该先把 root handoff envelope、目标 tab typed route、legacy alias normalizer 三层关系冻结下来。

## 稳定 SOTA / 成熟实践

1. 跨 tab handoff 的成熟做法是：`root shell 选中目标 tab -> 注入目标 tab 的 typed route -> 目标 tab 自己决定 push / sheet / full-screen`。root 不直接托管业务详情页。
2. handoff contract 应是可序列化、可恢复、可版本化的 envelope，而不是某个 feature store 临时拼出来的一串 query string。
3. destination route 的 canonical payload 应优先使用稳定业务 ID，而不是 display string：
   - `conversationID`
   - `bondID`
   - `icebreakSessionID`
   - `intentID`
   - `sceneKey`
   显示名、lane label、counterpart name 最多只能当 hint，不能当 identity。
4. legacy URI 可以继续被 parser 接受，但不应继续作为新写入格式扩散。成熟实践是：
   - 写入：typed route / centralized builder
   - 读取：normalizer 兼容历史别名
5. 如果目标 tab 还没有完全接好 detail route，handoff 也不应被直接丢弃；更稳的做法是保留 `pending handoff state`，再退化到目标首页。

## 面向本仓库的具体建议

### 建议的最小 handoff envelope

```swift
struct CrossTabHandoff: Equatable, Hashable {
    let id: String
    let sourceSurface: AppSurfaceID
    let targetSurface: AppSurfaceID
    let createdAt: Date
    let payloadVersion: Int
    let route: AppSurfaceRoute
}

enum AppSurfaceRoute: Equatable, Hashable {
    case earnSocial(EarnSocialRoute)
    case messages(MessagesRoute)
    case myProfile(MyProfileRoute)
}
```

约束如下：

1. `sourceSurface` / `targetSurface` 是 root shell 维度，不直接复用 URI path token。
2. `route` 是目标 tab 的 typed route，而不是直接塞一个 `String route`.
3. `payloadVersion` 用于兼容当前仓库里已经分叉的历史 query 形状。

### surface ID 与当前代码的桥接关系

| 建议的 canonical surface ID | 当前壳层落点 |
| --- | --- |
| `xianxia` | `MainTab.xianxia` |
| `masters` | `MainTab.master` |
| `earn_social` | `MainTab.earnSocial` |
| `messages` | `MainTab.messages` |
| `my_profile` | `MainTab.myProfile` |

这层桥接很重要，因为当前代码真实 tab key 仍然有 `master` 单数形式，而 Section 2 文档已经把更稳定的 machine surface ID 指向 `masters`。S4-06 不建议继续让 feature store 直接依赖 `MainTab.rawValue`。

### 建议的目标 tab typed route

```swift
enum EarnSocialRoute: Equatable, Hashable {
    case home
    case match(intentID: String, sceneKey: String)
}

enum MessagesRoute: Equatable, Hashable {
    case home
    case composeDraft(draft: String?, source: MessagesHandoffSource)
    case thread(locator: MessagesThreadLocator, source: MessagesHandoffSource)
}

enum MessagesThreadLocator: Equatable, Hashable {
    case conversation(conversationID: String)
    case bond(bondID: String, icebreakSessionID: String?)
}

enum MyProfileRoute: Equatable, Hashable {
    case home
    case memory(userID: String?, highlight: MyProfileHighlight?)
}
```

其中：

1. `MessagesRoute.composeDraft` 用来吸收当前 `messages/self?draft=...` 这类历史写法。
2. `MessagesRoute.thread` 只接受稳定 locator：
   - 已有消息线程时用 `conversationID`
   - earn social human takeover 但线程尚未 materialize 时用 `bondID + icebreakSessionID`
3. `MyProfileRoute.memory` 比 `my/profile?highlight=memory` 更精确，也更贴近 `myContracts.mjs` 已经存在的 `buildMemoryRoute(...)`。

### flow 级 payload 规则

| Flow | Canonical target route | 必填 payload | 可选 payload | 不再作为 canonical 的字段 |
| --- | --- | --- | --- | --- |
| `xianxia -> earn social` | `EarnSocialRoute.match` | `intentID`, `sceneKey` | `scanTargetID`, `sourceTopicID` | scene title、展示文案 |
| `masters -> messages` | `MessagesRoute.composeDraft` | `source = .masters` | `draft`, `masterID`, `sessionID` | `messages/self` 这类 path 形状本身 |
| `masters -> profile` | `MyProfileRoute.memory` | `source = .masters` 或等价来源元数据 | `userID`, `highlight = .authorization`, `masterID`, `sessionID` | `my/profile?highlight=memory` |
| `earn social -> messages` | `MessagesRoute.thread` | `locator = .conversation(...)` 或 `.bond(...)` | `sourceLaneID`, `counterpartID`, `icebreakSessionID` | `lane`, `counterpartName` 这种展示字符串 |

### legacy alias normalizer 规则

| 当前历史字符串 | 归一化结果 |
| --- | --- |
| `sparelife://earn-social/match?intent_id=...&scene_key=...` | `EarnSocialRoute.match(intentID:sceneKey:)` |
| `sparelife://messages/self?draft=...` | `MessagesRoute.composeDraft(draft:..., source:.masters)` |
| `sparelife://my/profile?highlight=memory` | `MyProfileRoute.memory(userID:nil, highlight:.memory)` |
| `sparelife://me/memory?user_id=...` | `MyProfileRoute.memory(userID:..., highlight:nil)` |
| `sparelife://messages/thread?bond_id=...&icebreak_session_id=...` | `MessagesRoute.thread(locator:.bond(...), source:.earnSocial)` |

需要单独说明的一点：

1. `sparelife://messages/thread?lane=...&counterpart=...` 不应再作为新写入格式继续扩散。
2. 在 bridge 期间，normalizer 可以把它先解读成“待解析的 earn social thread intent”，再尝试补成 `.bond(...)` 或直接回落到 `MessagesRoute.home + pendingHandoff`。
3. 也就是说，`lane + counterpartName` 只能是兼容层 hint，不能再是 canonical thread locator。

### 对当前三条 handoff 的具体落地建议

#### 1. `xianxia -> earn social`

1. 保留当前 support 层的 `intentID + sceneKey` 组合，因为这是当前代码里唯一像“稳定业务主键”的 payload。
2. 不要把 route 目标定义成 `EarnSocialHomeView` 里的某个 mock sheet。
3. 目标应是 `EarnSocialRoute.match(intentID:sceneKey:)`；在 EarnSocial typed route 还没落地前，允许 root 退化为：
   - 切到 `earn_social`
   - 把完整 handoff payload 存成 `pendingEarnSocialHandoff`
   - destination tab 首页自己决定何时消费

#### 2. `masters -> messages/profile`

1. `masters -> messages` 不再继续写 `messages/self`，统一收口到 `MessagesRoute.composeDraft`。
2. payload 至少要保留：
   - `draft`
   - `masterID`
   - `sessionID`
   这样消息页后续才能知道这条草稿来自哪位大师的哪个上下文。
3. `masters -> profile` 当前真实意图是“去检查记忆授权”，不是泛化的“去 profile 首页”。因此目标应是 `MyProfileRoute.memory`，而不是继续用 `my/profile?highlight=memory` 这种弱字符串。
4. 如果持久化层短期仍必须存字符串，建议改用 `myContracts.mjs` 里的 `buildMemoryRoute(...)`，不要再在 `MasterExperienceStore` 手写 `my/profile`。

#### 3. `earn social -> messages`

1. 当前 active UI home 还没有这个 handoff，现有 `threadRoute` 都来自非 active runtime path，因此 S4-06 不能把它误写成“已接线事实”。
2. canonical payload 只接受两种 locator：
   - 已 materialize 的 `conversationID`
   - 还在 A2A / bond bridge 阶段的 `bondID + icebreakSessionID`
3. `lane` 和 `counterpartName` 只能作为 compatibility hint，因为它们不是稳定主键。
4. `a2aContracts.mjs` 的 `buildMessagesThreadRoute({ bondId, sessionId })` 比 `EarnSocialExperienceStore` 的 `lane + counterpart` 版本更接近稳定 contract，后续应优先保留前者。

### root shell 的职责边界

1. root shell 只做三件事：
   - 切换目标 tab
   - 写入目标 tab route state
   - 在目标 tab 暂未 ready 时保留 pending handoff
2. root shell 不再直接承载 `ChatThreadView` 这类业务详情页。
3. `ConversationRouter` 应从“消息线程 modal 状态”升级为“跨 tab handoff coordinator”，而不是继续只暴露 `activeChatThread`。

## 实施顺序

1. 先冻结 `CrossTabHandoff`、`EarnSocialRoute`、`MessagesRoute`、`MyProfileRoute` 以及 flow 级 payload 规则。
2. 再把当前散落的 route string 生产端接到 normalizer：
   - `buildSocialRoute(...)`
   - `MasterExperienceStore.recommendedActions(...)`
   - `EarnSocialExperienceStore.threadRoute`
   - `a2aContracts.buildMessagesThreadRoute(...)`
3. 把 `ConversationRouter` 升级成 root handoff coordinator，并让它持有每个目标 tab 的 route state。
4. 让 destination tab 逐步实现 typed route 消费：
   - `messages` 先吃 `composeDraft` 与 `thread`
   - `my_profile` 先吃 `memory`
   - `earn_social` 至少先能持有 `pending match handoff`
5. 最后再移除 legacy 新写入：
   - `messages/self`
   - `messages/thread?lane=...&counterpart=...`
   - `my/profile?highlight=memory`

## 风险

1. 如果继续让 feature store 自己生产并直接持久化 ad-hoc URI，route 格式会继续分叉，等真正接 root dispatcher 时需要兼容的历史形状会更多。
2. `MasterLocalStateStore` 已经持久化了 CTA 的 `route` / `target`，所以 legacy alias parser 必须保留一段时间，不能一次性删掉旧格式。
3. `earn social` 当前 active runtime 不是 `EarnSocialExperienceStore`，如果忽略这点，很容易把 off-path route data 当成已接线入口来设计。
4. 如果不为“目标 tab 尚未 ready”设计 pending handoff 状态，handoff payload 会在 root 切 tab 之后直接丢失，导致用户只看到目标首页，却没有进入目标上下文。
5. 如果继续用 display string 做 locator，例如 `counterpartName`，一旦文案改名、去重或本地化，历史 handoff 将不可稳定恢复。
