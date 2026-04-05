# S4-04 消息模块导航整合方案

## 当前代码现状

1. 当前消息模块存在两套线程呈现宿主：
   - `ConversationHubView` 自己起 `NavigationStack`，并用 `.navigationDestination(for: ConversationThread.self)` 打开 `ChatThreadView`。证据在 `spare-life-ios-app/Features/CompanionChat/ConversationHubView.swift:17-45`。
   - `MainTabView` 又在根层持有 `ConversationRouter`，并准备了一个 `fullScreenCover(item: $router.activeChatThread)` 来打开同一个 `ChatThreadView`。证据在 `spare-life-ios-app/App/MainTabView.swift:58-66` 与 `spare-life-ios-app/App/MainTabView.swift:103-126`。
2. 这套根路由实际上还没真正启用：`ConversationRouter` 只有 `activeChatThread` 与 `openChat(_:)` 两个成员，且当前代码库里没有任何调用 `openChat(_:)` 的地方；`ConversationHubView` 虽然注入了 `router`，却没有使用它。证据在 `spare-life-ios-app/App/ConversationRouter.swift:7-12`、`spare-life-ios-app/Features/CompanionChat/ConversationHubView.swift:13-15`，以及对 `openChat(` 的全仓检索结果。
3. `ConversationHubView` 本身并没有把高级消息页面整合成可验证入口：
   - toolbar 里的 `新建对话` 与 `新建群聊` 仍是空 action。证据在 `spare-life-ios-app/Features/CompanionChat/ConversationHubView.swift:95-99`。
   - 空态 CTA “去认识新朋友” 也是空 action。证据在 `spare-life-ios-app/Features/CompanionChat/ConversationHubView.swift:176-184`。
   - hub 里没有任何直接路由到 `mask`、`relationship`、`memory`、`group play` 的能力，必须先进入 thread。
4. `ChatThreadView` 当前把高级页面全部做成局部 modal 岛屿：
   - 通过五个布尔状态 `showContactMask`、`showRelationship`、`showQuadRole`、`showGroupPlay`、`showCrossSessionMemory` 控制子页。
   - 这些子页都由 `sheet` 呈现。
   - 子页自己再包一层 `NavigationStack` 和 `关闭` 按钮。
   证据在 `spare-life-ios-app/Features/CompanionChat/ChatThreadView.swift:45-58`、`spare-life-ios-app/Features/CompanionChat/ChatThreadView.swift:321-346`，以及 `ContactMaskView.swift:108-135`、`RelationshipGardenView.swift:142-173`、`QuadRoleChatView.swift:93-132`。
5. 当前返回路径因此非常脆弱：
   - hub -> thread 走的是 push
   - thread -> advanced surface 走的是 sheet dismiss
   - app shell 还保留一条未接线的 full-screen thread path
   这意味着同一个消息模块里同时存在 stack pop、sheet dismiss、full-screen close 三种返回机制，但没有一个统一的 route state 解释它们。
6. 仓库里已经存在不少消息 route 生产者，但 Swift runtime 还没有任何消费者：
   - `companionContracts.mjs` 生成 `sparelife://messages/home`、`/thread`、`/mask`、`/relationship`、`/group-vote`。证据在 `spare-life-ios-app/Domain/Models/companionContracts.mjs:115-145`。
   - `MasterExperienceStore.swift` 生成 `sparelife://messages/self?draft=...`。证据在 `spare-life-ios-app/Features/Masters/MasterExperienceStore.swift:1218-1224`。
   - `EarnSocialExperienceStore.swift` 生成 `sparelife://messages/thread?lane=...&counterpart=...`。证据在 `spare-life-ios-app/Features/EarnSocial/EarnSocialExperienceStore.swift:913-915`。
   - `a2aContracts.mjs` 又定义了 `sparelife://messages/thread?bond_id=...&icebreak_session_id=...`。证据在 `spare-life-ios-app/Domain/Models/a2aContracts.mjs:482-490`。
   - 但 Swift 侧没有 `onOpenURL`、没有 URL parser、没有 route normalizer。对 `sparelife://messages` 的 Swift 全仓检索只命中 route 字符串的生产端，没有命中消费端。
7. 结论是：当前高级消息页面不是“分散组件已经接好导航”，而是“分散组件只在 thread 内部以 sheet 形式临时可达”，还没有形成模块级、tab 级、跨入口可验证的导航整合方案。

## 当前文档偏差

1. `Stage_3_Codebase_Audit.md` 对导航现状的判断是准确的：高级消息页面虽然存在，但 app shell 还没有完整整合它们。证据在 `Docs/Stage_3_Codebase_Audit.md:90-93`。
2. `ValidationLog_Messages_UIUX_Batch1.md` 写的是 “接入消息详情路由”，但当前 Swift 代码里的实现只是 `ChatThreadView` 上的本地 `sheet`。这可以算“详情页内部入口”，不能算“消息模块已经有统一 route graph”。证据在 `Docs/ValidationLog_Messages_UIUX_Batch1.md:12-13`、`Docs/ValidationLog_Messages_UIUX_Batch1.md:35-39` 与 `spare-life-ios-app/Features/CompanionChat/ChatThreadView.swift:321-346`。
3. `ValidationLog_Messages_FUNC_Batch1.md` 与 `.mjs` route helper 会让读者误以为 `messages/home`、`messages/thread`、`messages/mask` 等 deep link 已经进入当前 iOS runtime；实际上它们只是 support/backend 层的契约和 demo 证据，并没有 Swift 消费侧。证据在 `Docs/ValidationLog_Messages_FUNC_Batch1.md:24-46`、`Docs/ValidationLog_Messages_FUNC_Batch1.md:52-110`，以及 `Docs/Stage_3_Codebase_Audit.md:121-127`。
4. 当前最大的文档偏差不是“子页不存在”，而是“已有子页被误写成已完成整合导航”。

## 稳定 SOTA / 成熟实践

1. 一个 tab feature 最好只有一个主导航宿主。对于 SwiftUI，这通常意味着 feature root 自己管理单一 `NavigationStack(path:)`，而不是同时保留局部 `NavigationStack`、根层 `fullScreenCover` 和子页自带 `NavigationStack`。
2. 层级型子页面优先走 typed route push，只有短生命周期编辑流才适合继续用 `sheet`。例如：
   - `relationship`、`memory`、`group play`、`quad role` 是 feature surface，适合走 route
   - `add anniversary`、`launch vote`、`memory correction` 是局部编辑流，适合保留为 modal
3. 成熟的消息路由必须是可序列化、可恢复、可被其他模块调用的。也就是说，路由状态应该绑定业务主键，比如 `conversationID`、`contactID`、`groupID`、`voteID`，而不是绑定某个 SwiftUI view 的临时布尔值。
4. 外部入口和内部入口要复用同一套 route contract。来自 `masters`、`earn social`、`a2a` 的 handoff 不应直接实例化视图，而应发一个统一的 `MessagesRoute`，由消息模块自己解释。
5. 如果仓库里已经存在多套历史 route 字符串，成熟做法不是让调用方继续各说各话，而是在消息模块内加一层 route normalizer / compatibility bridge，把旧 query 统一收敛成一个规范化的内部 route。

## 面向本仓库的具体建议

1. 为消息 tab 建立单一 `MessagesFeatureRoot`，它才是整个消息簇唯一的导航宿主。
   - `MainTabView` 里的 `ConversationHubView()` 应升级为 `MessagesFeatureRoot()`
   - `ConversationHubView` 不再自己持有 `NavigationStack`
   - `MainTabView` 上那条 `fullScreenCover(activeChatThread)` 应退出主路径，最多只保留兼容桥接期
2. 把 `ConversationRouter` 从 “只有一个 `activeChatThread`” 升级为 typed route state，而不是继续堆布尔值。建议的最小形态：

```swift
enum MessagesRoute: Hashable {
    case hub(MessagesHubState)
    case thread(conversationID: String)
    case mask(contactID: String)
    case relationship(contactID: String)
    case memory(contactID: String)
    case quadRole(conversationID: String)
    case groupPlay(conversationID: String)
    case groupVote(groupID: String, voteID: String)
    case composeDraft(text: String?)
}
```

3. `ChatThreadView` 要退回线程壳层角色，不再直接持有五个 `showXxx` 布尔值。
   - 它只应该发出 “navigate to `.relationship(contactID)`” 之类的 typed action
   - 真正的 `presentation` 交给 `MessagesFeatureRoot` 的 stack / modal policy
4. 统一高级页面的返回路径：
   - `hub -> thread -> relationship/memory/groupPlay/quadRole` 统一走 stack pop
   - `relationship -> add anniversary`
   - `memory -> correction`
   - `groupPlay -> launch vote`
   这类局部编辑流保留 `sheet`
   - 这样用户始终知道自己是从哪个 feature surface 进入、返回到哪里
5. 为 route contract 增加归一化层，收敛当前仓库里已经出现的多种消息 URL 形状。
   - 规范化后的主键建议只保留：`conversation_id`、`contact_id`、`group_id`、`vote_id`、`draft`、`source`
   - `lane`、`counterpart`、`bond_id`、`icebreak_session_id` 这类上游上下文字段可以进入兼容转换层，再映射成标准化 `MessagesRoute`
   - `messages/self?draft=...` 这类历史格式不要直接扩散到更多调用点
6. 让 hub 的入口变成可验证状态，而不是继续保留 no-op：
   - `新建对话` -> `.composeDraft(nil)` 或 contact picker
   - `新建群聊` -> create group flow
   - 空态 CTA 如果还没有跨 tab 契约，就应明确禁用或暂时隐藏，而不是显示一个无法触发的按钮
7. 为 `group play` 和 `quad role` 加业务前置约束，而不是只靠 view 内 if 判断：
   - `groupPlay` 只有 group conversation 才能进入
   - `quadRole` 只有 direct / eligible conversation 才能进入
   - 非法 route 统一回落到 thread 层的 error banner 或 unavailable surface，而不是让子页自己兜底
8. 把 `messages/home`、`messages/thread`、`messages/mask`、`messages/relationship` 这些 route 真正接到 Swift app shell 之后，再把其它模块的 CTA route 指向它们；在此之前，文档应明确标注它们是 contract，不是已接线入口。
9. 这里先只解决“消息模块内部导航整合”。跨 tab 切换和上游 handoff payload 统一属于 `S4-06`，但本 item 需要先把消息模块内部承接面整理好，避免 `S4-06` 直接对接一堆本地 bool 和 sheet。

## 实施顺序

1. 先定义规范化 `MessagesRoute`，列清楚 hub、thread、mask、relationship、memory、group play、quad role、group vote、compose draft 的最小 payload。
2. 再把消息 tab 收口成单一 `MessagesFeatureRoot`，移除当前“双宿主”状态：`ConversationHubView` 内部 `NavigationStack` 与 `MainTabView` 的 `fullScreenCover` 不能再同时作为主路径存在。
3. 然后把 `ChatThreadView` 的五个 route bool 迁移成 typed navigation action，并把高级页面改成 stack-managed feature surfaces。
4. 再加 route normalizer，把现有 `messages/self`、`thread?lane=...`、`thread?bond_id=...` 等历史入口统一映射到规范化 `MessagesRoute`。
5. 最后补入口验证：
   - app shell 进入 hub
   - hub 进入 thread
   - thread 进入 relationship / memory / groupPlay / quadRole
   - detail 返回 thread，再返回 hub

## 风险

1. 如果继续保留 `ConversationHubView` 的本地 `NavigationStack` 和 `MainTabView` 的 `fullScreenCover` 并行存在，消息线程将长期存在双宿主和双返回逻辑，后续很难稳定做状态恢复。
2. 如果继续用布尔值驱动高级页面，任何来自外部模块或 deep link 的入口都只能绕过 feature router 直接拼 view，导航状态将不可验证。
3. 如果先去统一跨 tab handoff，而不先收口消息模块内部 route，`S4-06` 会被迫对接一套尚未成形的本地 modal 组合，返工更大。
4. 如果 route contract 不做归一化，`messages/self`、`thread?lane=...`、`thread?bond_id=...` 会继续扩散，最终没有一个入口能被稳定解释。
5. 如果把所有详情都继续留在 `sheet`，虽然短期看起来改动小，但返回路径、状态恢复、深链和自动化验证都不会真正变好。
