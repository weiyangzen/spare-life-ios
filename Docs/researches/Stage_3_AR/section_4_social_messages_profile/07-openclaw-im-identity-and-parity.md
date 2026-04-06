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

1. `ios/spare-life-ios-app/Domain/Models/companionContracts.mjs` 已冻结三件事：
   - `COMPANION_CHANNEL_ID = companion`
   - `buildCanonicalIMCardID(...)`
   - `buildIMConversationLocator(...)`
2. `messages home` 与 `conversation detail` 当前 support runtime 都会带出：
   - `canonicalCardID`
   - `locator`
   - `sourceChannelID`
   - `handoff`
3. `openConversation` 的 inbound normalize 与 use case 现在都接受 canonical locator，不再只认单一 `conversationId`。
4. 兼容字段 `route` 仍保留给旧 surface 使用，但它已退化成 legacy 兼容字段，不再是 canonical identity。

## 风险

1. 如果没有 canonical card ID，消息首页在 server 尚未 materialize conversation 时会持续出现重复卡片、错卡片或刷新丢身份的问题。
2. 如果 group 和 dm 继续各用一套字段，UI 虽然“都像 IM”，但一旦要接 server 或 latest OpenClaw capability，就会在字段映射层大量返工。
3. 如果只升级 `openclaw` 版本，不补 capability matrix 和 error surface，所谓“支持最新版所有 IM 逻辑”仍然会停留在 package metadata 层。
4. 如果继续用 display string 当 locator，一旦重命名、本地化或上游改文案，历史 handoff 与缓存恢复都会失稳。
