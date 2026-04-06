# S4-07 OpenClaw IM 唯一卡片标识与全量逻辑对齐

## 当前代码现状

1. 当前 Swift runtime 的消息页仍以本地 `ConversationHubStore` 为主，卡片身份主要围绕 `conversationId` 和本地 seed 建立；消息首页还没有一层独立的“跨 channel 标准化 locator”。这一点在 `ios/spare-life-ios-app/Features/CompanionChat/CompanionChatStore.swift` 与 `ios/spare-life-ios-app/Features/CompanionChat/ConversationHubView.swift` 的现实里很明显。
2. 支撑层与 plugin 其实已经表达出比 Swift runtime 更丰富的 IM 逻辑。`ios/spare-life-openclaw-plugin/src/inbound/normalizeCompanionPayloads.mjs` 当前已支持：
   - `messages home`
   - `conversation open / search`
   - `direct message`
   - `mask update`
   - `shared stage draft / access / message`
   - `ritual schedule / complete`
   - `group conversation / message`
   - `group vote launch / ballot`
   - `group summary`
   - `companion inspect`
3. `ios/spare-life-openclaw-plugin/src/handlers/companionChatHandler.mjs` 已经把这些 payload 形状接到对应 use case，但这里的输入仍以单次 action 所需字段为主，还没有向 UI 暴露统一的“消息卡片身份 contract”。
4. 仓库内已有的消息研究更多集中在：
   - `S4-03`：领域边界
   - `S4-04`：消息 surface 内部导航整合
   - `S4-06`：跨 tab handoff
   它们都提到了稳定业务主键的重要性，但还没有专门回答一个更细的现实问题：
   如果上游没有现成 `conversation_id`，页面一张卡片到底应该怎样稳定地代表“一个 channel 的一个 group”或“一个 channel 的一个 dm”。
5. `OpenClaw` 的 npm `latest` 在 `2026-04-06` 为 `2026.4.2`。当前仓库已经把 plugin `peerDependencies` 提升到 `>=2026.4.2`；接下来的真实缺口不在 package metadata，而在 capability parity、card identity 和 render parity。

## 当前文档偏差

1. `S4-03 / S4-04 / S4-06` 都正确强调了消息域需要主键化、route 化和 normalizer，但它们没有把“卡片身份 fallback”单独冻结成一个 contract。
2. 现有文档也还没有把最新版 OpenClaw 的 IM 能力面与本仓库当前 companion lane 做一张完整对照表，因此很容易继续停留在“有 direct 和 group handler”就等于“消息首页已能稳定承接”的错觉里。
3. 如果不补这一层，后续不管是 `messages home`、`earn social -> messages`，还是未来 server 回包，都会继续在 `conversationId`、`groupId`、`contactId`、`channelId` 之间各说各话。

## 稳定 SOTA / 成熟实践

1. IM 首页的唯一标识不应被 UI 命名左右，而应由稳定 locator 驱动。成熟做法是：
   - 能用 `conversation_id` 时就直接用
   - 没有 conversation materialization 时，退回到“容器 ID + 对话对象 ID”的组合键
2. 对于多 channel IM，group 与 dm 最稳的 fallback 不是 display name，而是：
   - group: `channel_id + group_id`
   - dm: `channel_id + peer_id`
3. UI 不应该直接依赖 OpenClaw 原始 payload 的字段差异。更稳的做法是先落一层标准化 envelope，例如：

```text
IMCardEnvelope
  - locator
  - canonicalCardID
  - surfaceKind(group | dm)
  - title
  - subtitle
  - unreadCount
  - lastMessagePreview
  - actorSummary
  - capabilityFlags
  - sourceChannelID
```

4. 最新版协议支持什么 action，不等于首页已经能稳定消费这些 action。成熟做法是把“可调用逻辑”与“可渲染 surface”分开治理：
   - `action parity`
   - `render parity`
   - `navigation parity`
   - `capability parity`
5. group-only 行为和 dm-only 行为要在 locator 层就被筛掉，不要等 view 内部才发现类型不匹配。

## 面向本仓库的具体建议

补充一个基于当前代码现状的落地约束：

1. 现在的 support runtime 并没有上游回传独立 `channel_id` 字段，因此本仓库 companion lane 先把 unified channel 的 `routeKey = companion` 冻结成当前 `sourceChannelID / channelID`。
2. direct message fallback 里的 `dm_peer_id` 在当前仓库里对应现有 `contactId`，直到上游真的回传单独 `dm_peer_id` 再替换。
3. 这不是把 support runtime 误写成 Swift 已接线事实，而是给当前 Node/SQLite/OpenClaw companion lane 一套不再继续漂移的主键约束。

### 建议的 canonical locator

```text
IMConversationLocator
  - conversation(conversationID)
  - group(channelID, groupID)
  - dm(channelID, peerID)
```

### 建议的 canonical card ID

```text
conversation:<conversation_id>
group:<channel_id>:<group_id>
dm:<channel_id>:<peer_id>
```

规则如下：

1. 能拿到 `conversation_id` 时，永远优先它，因为它最接近真正 materialized thread。
2. 若尚未 materialize，但上游已明确 group，则用 `group:<channel_id>:<group_id>`。
3. 若尚未 materialize，但上游是 direct message，则用 `dm:<channel_id>:<peer_id>`。
4. 不允许再用 `group title`、`counterpartName`、`lane label` 这类显示文案做 identity。

### 建议的统一字段袋

建议所有消息首页卡片、消息详情入口、跨入口 handoff 都先消费一层统一的 `IMRenderFields`：

- `canonicalCardID`
- `locator`
- `surfaceKind`
- `primaryTitle`
- `secondaryTitle`
- `avatarHint`
- `lastMessagePreview`
- `lastMessageAt`
- `unreadCount`
- `badgeFlags`
- `sourceChannelID`
- `capabilityFlags`

这样 group 与 dm 才能真正走“同字段、同渲染、不同 capability”的模式。

### 建议的最新版 OpenClaw 对齐面

以 `2026-04-06` 的 `openclaw@2026.4.2` 为当前最新版基线，本仓库 companion lane 至少要对齐以下逻辑：

1. `messages home`
2. `conversation open`
3. `conversation search`
4. `direct message`
5. `mask update`
6. `shared stage draft`
7. `stage access`
8. `stage message`
9. `ritual schedule`
10. `ritual completion`
11. `group conversation`
12. `group message`
13. `group vote launch`
14. `group vote ballot`
15. `group summary`
16. `companion inspect`

这里的“对齐”不是只让 handler 能调用，而是四层都要有清单：

- inbound normalize
- use case / repository support
- UI render / route support
- capability / error surface

### 与现有 Stage 3 研究的桥接关系

1. `S4-03` 继续负责 bounded context：hub / thread / mask / relationship / memory / group play。
2. `S4-04` 继续负责消息模块内部导航图。
3. `S4-06` 继续负责跨 tab handoff。
4. 本条 `S4-07` 只负责补齐这三者之间缺的一块：
   “OpenClaw / server / UI 都认同的一致 identity 与 card envelope”。

## 实施顺序

1. 先冻结 `IMConversationLocator` 和 `canonicalCardID` 规则。
2. 再给消息首页补 `IMRenderFields` 标准化层，把 Swift seed、plugin 回包、未来 server 回包统一映射到同一字段袋。
3. 然后对齐 `MessagesRoute`，让 route payload 优先接受 canonical locator，而不是 ad-hoc query 字段。
4. 接着为最新版 OpenClaw action 面补 capability matrix，明确哪些逻辑已经可调、哪些还只是 contract。
5. 最后再补 smoke：DM、group、vote、summary、inspect 至少各有一条可重复验证路径。

## 当前实现回写

1. `ios/spare-life-ios-app/Domain/Models/companionContracts.mjs` 当前已冻结消息卡片主 contract：
   - `COMPANION_CHANNEL_ID = companion`
   - `buildCanonicalIMCardID(...)`
   - `buildIMConversationLocator(...)`
   - `buildIMRenderFields(...)`
   - `buildIMCardEnvelope(...)`
   - `buildMessagesHomeInputModel(...)`
   - `buildMessagesHomeOutputModel(...)`
   - `buildConversationSummaryModel(...)`
   - `buildConversationOpenInputModel(...)`
   - `buildConversationOpenOutputModel(...)`
   - `buildConversationSearchInputModel(...)`
   - `buildConversationSearchOutputModel(...)`
   - `buildConversationOpenAction(...)`
2. `ios/spare-life-ios-app/Services/CompanionChat/companionChatService.mjs` 现在把 `messages home` 卡片与 `conversation detail` 顶部入口都收口成同一层 `IMCardEnvelope`。同一 envelope 会同时带出：
   - `canonicalCardID`
   - `locator`
   - `sourceChannelID`
   - `surfaceKind`
   - `renderFields`
   - `fieldSources`
   - `handoff`
   - `openAction`
3. `IMRenderFields` 现在已经把 group 与 dm 统一进同一字段袋：
   - 同字段：`primaryTitle / secondaryTitle / preview / badge / unreadCount / lastMessageAt / sourceChannelID / capabilityFlags`
   - 不同能力：dm 打开 `mask / shared stage / ritual`，group 打开 `group message / vote / summary`
4. `messages home` 的 runtime 出口现在有明确的规范化输入输出模型：
   - `input`: `kind=userId/limit/sourceSurface/tab/route`
   - `output`: `kind=messages_home_output`，并显式带出 `route / handoff / sourceChannelID / unreadTotal / cardEnvelopes`
   - 每张卡片再用 `fieldSources` 明确 `title / subtitle / preview / badge / locator / capability` 的来源
5. `openConversation` 不再只认显式 `conversationId`。当前 runtime 可接受三类详情打开入口：
   - `cardEnvelope`
   - `openAction`
   - canonical `locator`
   其中 group/dm locator 会先在 handler 层经 repository 解析成真实 `conversationId`，再进入 use case；因此“locator 可开详情”现在是 runtime truth，但不是“use case 原生理解 locator”。
6. `conversation open` 现在已有明确的 typed 输入输出模型：
   - `input.kind = conversation_open_input`
   - `output.kind = conversation_open_output`
   - `output.conversation` 收口为稳定 `conversation_summary`
   - `output.timeline` 明确以 `timeline_item -> locationPrimaryKey(message_id)` 描述时间线定位
   - `output.participants / messages` 最少冻结 `participantKey / role / displayName / permissions` 与 `messageId / turnIndex / actor / channelKind / content / stageMode`
   - `output.stageContext / groupContext` 分别补齐 direct shared-stage 与 group vote/summary 的最小上下文，不再只靠 raw message/participant 数组猜语义
7. `conversation search` 现在已有独立 query/result/empty-state contract：
   - `input.kind = conversation_search_input`
   - `output.kind = conversation_search_output`
   - `output.query.kind = conversation_search_query`
   - `output.resultItems[*]` 固定带 `locationPrimaryKey = { kind: message_id, value, turnIndex }`
   - 每条 result item 同时带 `handoff.route.kind = thread`，并把定位主键塞进 `hint`
   - 空结果统一返回 `conversation_search_empty_state(reason=no_match)`，而不是让上层靠 `hits.length === 0` 自行猜测
8. 兼容字段 `route` 仍保留给旧 surface 使用，但它已退化成 legacy 兼容字段，不再是 canonical identity。
9. `companionContracts.mjs` 现已把最新版 OpenClaw companion action 面显式收口成 `buildOpenClawIMCapabilityChecklist(surfaceKind)`：
   - 每项固定带 `actionKey / label / stage3Item / flagKey / surfaceScope / normalizeInput / handlerMethod / entrySurface / runtimeGate`
   - 这样 runtime truth 不再是“handler 存在即代表已接线”，而是明确区分 shared、direct-only、group-only 与当前 gate 形态
10. `direct message` 与 `group conversation` 现已补到 handler 级 surface gate：
   - `normalizeDirectMessageInput(...)` 与 `normalizeGroupConversationInput(...)` 可选接收 `cardEnvelope / locator / surfaceKind`
   - `companionChatHandler.sendDirectMessage(...)` 会通过 `assertOpenClawIMCapabilityAllowed(...)` 拒绝 group surface 误入
   - `companionChatHandler.openGroupConversation(...)` 会通过同一 gate 拒绝 direct surface 误入
   - 当前其余 group-only / direct-only action 仍主要依赖 `capabilityFlags` 呈现，后续再由 `S3-040/S3-041/S3-043/S3-044` 继续补齐更细的 route/error gate

## 风险

1. 如果没有 canonical card ID，消息首页在 server 尚未 materialize conversation 时会持续出现重复卡片、错卡片或刷新丢身份的问题。
2. 如果 group 和 dm 继续各用一套字段，UI 虽然“都像 IM”，但一旦要接 server 或 latest OpenClaw capability，就会在字段映射层大量返工。
3. 如果只升级 `openclaw` 版本，不补 capability matrix 和 error surface，所谓“支持最新版所有 IM 逻辑”仍然会停留在 package metadata 层。
4. 如果继续用 display string 当 locator，一旦重命名、本地化或上游改文案，历史 handoff 与缓存恢复都会失稳。
