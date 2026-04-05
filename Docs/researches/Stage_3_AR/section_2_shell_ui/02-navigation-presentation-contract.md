# S2-02 Navigation And Presentation Contract

代码与旧文档冲突时，以代码为准。本报告只讨论 `TabView / NavigationStack / fullScreenCover / router` 的页面呈现契约，以及根路由与跨 tab 进入详情页的统一规范。

## 当前代码现状

### 1. 当前根壳层是“TabView 外壳 + 每个 tab 自带 NavigationStack”

`spare-life-ios-app/App/MainTabView.swift` 当前负责：

- `TabView(selection: $selectedTab)`
- 自定义底部浮动 `SpareTabBar`
- 根层的 `ConversationRouter`
- 根层 `fullScreenCover(item: $router.activeChatThread)`

与此同时，每个 tab 的根视图又各自包了一层 `NavigationStack`：

- `XianxiaHomeView`
- `MasterChatHomeView`
- `EarnSocialHomeView`
- `ConversationHubView`
- `MyProfileView`

这说明当前 runtime 已经形成“每个 tab 拥有自己独立 stack”的事实，只是这个契约还没有被正式文档化。

### 2. 当前各 tab 的详情呈现方式并不统一

| Surface | Root Container | 详情进入方式 | 当前问题 |
| --- | --- | --- | --- |
| `xianxia` | `NavigationStack` | `navigationDestination(isPresented:)` -> `SceneTopicView` | 典型层级 push |
| `masters` | `NavigationStack` | iOS 上 `fullScreenCover(isPresented:)` -> `MasterConversationView` | 会话详情走 modal，不是 push |
| `earn_social` | `NavigationStack` | `.sheet(item: activeCard)` + `.sheet(isPresented: showPreferenceSheet)` | 主卡详情与偏好页都走 sheet |
| `messages` | `NavigationStack` | `NavigationLink(value:)` + `navigationDestination(for:)` -> `ChatThreadView` | in-tab 是 push，但根层又有全局 `fullScreenCover` 同一详情 |
| `my_profile` | `NavigationStack` | `NavigationLink(destination:)` + 多个 `.sheet` | push 与 sheet 边界相对清楚 |

当前并不是“没有导航”，而是已经存在 4 套不同 contract：

- push detail
- modal conversation
- sheet preview
- root-level global modal

### 3. Messages 已经出现“双轨详情入口”

消息模块目前同时存在两条线程详情路径：

1. `ConversationHubView` 内部：
   - `NavigationLink(value: thread)`
   - `.navigationDestination(for: ConversationThread.self)`

2. `MainTabView` 根层：
   - `.fullScreenCover(item: $router.activeChatThread)`
   - 同样展示 `ChatThreadView`

而 `ConversationRouter` 当前只有：

- `activeChatThread`
- `openChat(_:)`

并未真正统一“根路由”和“tab 内路由”。这会带来两个现实问题：

- 同一个 `ChatThreadView` 可能被 push，也可能被根层 modal 展示
- 跨 tab 进入消息详情时，当前没有明确规定是“切 tab 后 push”还是“根层直接盖一个 full-screen”

### 4. Masters 当前会话页是 iOS modal 契约，不是 stack detail 契约

`MasterChatHomeView` 目前在 iOS 上使用：

- `.fullScreenCover(isPresented: $showConversation)`

只有非 iOS 分支才使用：

- `.navigationDestination(isPresented: $showConversation)`

这说明当前真实契约是：

- `masters` 首页是 tab 内页面
- 大师一对一会话在 iOS 上被视作“脱离 tab 的沉浸式页面”

它和 Xianxia、MyProfile 的 detail push 契约不同。

### 5. Earn Social 当前把“卡片详情”和“偏好设置”都视作 sheet

`EarnSocialHomeView` 当前使用：

- `.sheet(item: $activeCard)` 展示 `EarnSocialMockChatView`
- `.sheet(isPresented: $showPreferenceSheet)` 展示 `EarnSocialPreferenceSheet`

这意味着该模块现阶段更像“首页 + 浮层预览/配置”，而不是稳定的层级详情树。

### 6. Root shell 当前没有 typed route，也没有 deep-link dispatcher

虽然 `Masters` 和 `EarnSocialExperienceStore` 已经生成了很多 `sparelife://...` route 字符串，但当前 app shell 没有看到：

- `onOpenURL`
- `NavigationPath` registry
- typed app route
- 跨 tab handoff coordinator

所以当前根壳层并不能真正消费这些 route 字符串。

### 7. 自定义 tab bar 让“detail 是否应隐藏底栏”成为真实架构问题

`MainTabView` 的 tab bar 不是系统 tab bar，而是整个 `tabLayer` 的 `safeAreaInset(edge: .bottom)`。

这意味着：

- tab 内 push 的详情页天然会继承这个底栏
- `fullScreenCover` 能直接绕开底栏

因此当前 `masters` 和根层 `messages` 倾向使用 `fullScreenCover`，不是偶然，而是被现有 shell 结构推出来的结果。

## 当前文档偏差

### 1. Masters 的旧文档仍在描述旧导航结构

`Docs/Stage1.1-1.2_todos.md` 仍把大师入口描述为：

- `Stage1MastersPreviewRootView`
- `MasterHomeView`
- `.navigationDestination(isPresented: conversationDestinationBinding)`

这和当前 iOS runtime 的 `MasterChatHomeView + fullScreenCover` 已经不一致。

### 2. 旧文档默认把“进入详情页”当作统一概念，但代码里并不统一

旧文档和验证记录大量使用“进入 topic detail”“进入一对一”“进入消息线程”这类表达，但没有明确区分：

- push
- sheet
- full-screen modal
- root router handoff

对 Stage 3 来说，这种模糊表述已经不够用。

### 3. 审计文档只点到了 `ConversationRouter`，没完全揭示双轨展示

`Docs/Stage_3_Codebase_Audit.md` 已指出 `ConversationRouter` 只处理 message-thread presentation，但没有把以下事实展开：

- `ConversationHubView` 已经自己拥有线程 push 路径
- 根层 `ConversationRouter` 又额外承接同一详情页面

S2-02 需要把这个冲突正式写成 contract 问题，而不是只当作实现细节。

## 稳定 SOTA 或成熟实践

### 1. `TabView` + per-tab `NavigationStack` 是稳定成熟模式

多 tab iOS app 的成熟实践通常是：

- `TabView` 管理顶层 surface 切换
- 每个 tab 维护自己独立的 navigation history
- root coordinator 只处理跨 tab handoff 和全局 modal

这比“所有详情都由根层统一接管”更可维护，也更利于状态恢复。

### 2. 一个详情页面应该只有一个主呈现契约

成熟实践强调：

- 同一个 detail surface 应该有一个主进入方式
- 同一个 route type 无论从哪里进入，都应映射到同一个 presentation rule

否则会出现：

- 返回手势不一致
- 生命周期不一致
- 状态恢复不一致
- 自动化路径不一致

### 3. push、sheet、fullScreenCover 的边界必须显式分类

稳定做法通常是：

- `push`
  - 同一信息架构树内的层级钻取
- `sheet`
  - 辅助任务、编辑器、偏好设置、轻量预览
- `fullScreenCover`
  - 沉浸式、强中断式、需要完全脱离底层 shell 的流程

关键不是某个 API 更高级，而是同类页面必须服从同类契约。

### 4. 跨 tab 进入详情页的成熟做法是“切 tab + 注入目标路由”

成熟实践不建议 root 直接用 modal 把目标页面盖在当前 tab 之上，除非该页面天生就是 global modal。

更稳定的跨 tab contract 是：

1. root 选择目标 tab
2. 把 typed route 写入目标 tab 的 navigation state
3. 目标 tab 自己完成 push / modal 决策

这样 detail 的所有者始终是目标 tab，而不是 root shell。

## 面向本仓库的具体建议

### 1. 正式定义“根壳层只做 tab 选择与跨 tab handoff”

建议根壳层后续职责只保留：

- `selectedTab`
- 每个 tab 的 route state 持有
- deep-link 解析入口
- global modal

不建议 root shell 继续直接持有某个业务详情页，比如：

- `ChatThreadView`

因为这会让 root 变成业务详情容器，而不是 app shell。

### 2. 为每个 tab 定义 typed route，而不是继续依赖布尔值和散字符串

建议后续 contract 最少拆为：

- `XianxiaRoute`
- `MastersRoute`
- `EarnSocialRoute`
- `MessagesRoute`
- `MyProfileRoute`
- `AppShellRoute`

示意：

- `MessagesRoute.thread(threadID: String)`
- `MastersRoute.conversation(masterID: String, prefilledPrompt: String?)`
- `XianxiaRoute.topic(topicID: String)`
- `MyProfileRoute.memory`

这样 root handoff 才有稳定目标，不会依赖 `activeTopic != nil`、`showConversation`、`activeCard != nil` 这类局部布尔状态。

### 3. 明确本仓库的 presentation 分类规则

结合当前代码现实，建议采用以下统一规范：

#### A. push

适用页面：

- `SceneTopicView`
- `ChatThreadView`
- `SyncScoreDashboardView`
- `AwakeningPersonalityView`
- `MemoryPalaceView`
- `PrivacyLocalBackendView`

规则：

- 属于同一 tab 的层级详情
- 允许保留 tab 内历史
- 允许被 cross-tab handoff 注入

#### B. sheet

适用页面：

- `EarnSocialPreferenceSheet`
- `EditProfileSheet`
- `EditAvatarVisibilitySheet`
- `EditProfileAvatarSheet`

规则：

- 辅助编辑、短流程配置、轻量预览
- 关闭后返回原上下文
- 不承担跨 tab 路由目的地职责

#### C. fullScreenCover

建议保留给以下类别：

- 真正需要脱离 shell 的沉浸式流程
- 扫码、相机、语音录制、系统协作流
- 暂时无法在 push 下正确隐藏自定义 tab bar 的过渡性 detail

这里要特别说明：

- `MasterConversationView` 当前可以先维持 full-screen 过渡契约
- 但目标 contract 不应再是“业务页自己决定布尔 modal”，而应升级为 `MastersRoute.conversation(...) + hidesShellTabBar`

### 4. Messages 应收敛到“一个线程，一个 route”

建议把消息线程统一为：

- 主 contract：`MessagesRoute.thread`
- in-tab 进入：消息页列表 push 到 `MessagesRoute.thread`
- cross-tab 进入：root 选中 `messages` tab，再把 `MessagesRoute.thread` 注入消息 tab

这意味着 `MainTabView` 上的：

- `.fullScreenCover(item: $router.activeChatThread)`

应该被视为过渡层，不是长期契约。

### 5. Masters 会话建议从“布尔 modal”升级为“typed route + shell 可见性策略”

建议中期目标不是简单把 `fullScreenCover` 改成 push，而是先把 contract 改正确：

- `MastersRoute.conversation(masterID: String, sessionID: String?)`
- route metadata 指明 `prefersImmersivePresentation` 或 `hidesShellTabBar`

然后再由 shell 统一决定：

- 当前先用 full-screen adapter
- 后续 tab bar 隐藏策略成熟后，再迁移到 push

这样可以避免一边改 presentation API，一边继续保留弱布尔状态。

### 6. Earn Social 当前不适合作为跨 tab detail 的目标页

当前 `EarnSocialHomeView` 仍然是 mock card + sheet 结构。建议它在 Stage 3 里先保持：

- 首页浏览留在 tab 内
- 轻量聊天预览继续用 sheet

但来自其他 tab 的 handoff 不应再指向“某个未接线的 mock sheet”，而应指向未来可路由的 typed destination，例如：

- `EarnSocialRoute.intent(intentID: String)`
- `EarnSocialRoute.market(lane: ...)`

否则 deep-link 只会停留在字符串层。

### 7. 根路由的统一规范

建议为本仓库定义以下根路由规范：

1. 根层只接受 `AppShellRoute`
2. `AppShellRoute` 的第一层只负责确定目标 tab
3. 第二层 payload 使用目标 tab 自己的 typed route
4. 任何跨 tab 详情进入都必须先落到目标 tab，再由目标 tab 决定 push / sheet / full-screen

示例：

- 从 `masters` CTA 去消息线程
  - root: 选中 `messages`
  - payload: `MessagesRoute.thread(...)`
- 从 `earn_social` 去 profile memory
  - root: 选中 `my_profile`
  - payload: `MyProfileRoute.memory`

## 实施顺序

1. 先定义 root shell route contract 和 per-tab route enum，不急着改 UI API。
2. 把 `ConversationRouter` 从“消息线程 modal 状态”升级为“跨 tab handoff coordinator”。
3. 让 `ConversationHubView` 与跨 tab handoff 共用同一个 `MessagesRoute.thread`。
4. 给 `MastersRoute.conversation` 建立 typed contract，先用 adapter 兼容当前 `fullScreenCover`。
5. 再引入 shell-level `hidesTabBar` / `presentationStyle` 策略，逐步消除“某个业务页直接决定 modal”的做法。
6. 最后接入 deep-link parser，把 `sparelife://...` 字符串真正翻译成 `AppShellRoute`。

## 风险

### 1. 自定义 tab bar 目前天然偏向 modal

因为 `SpareTabBar` 是根层 `safeAreaInset`，不是系统 tab bar，直接把更多页面改成 push 可能会先暴露“详情页仍显示底栏”的 UI 问题。

### 2. 旧自动化路径可能依赖当前 presentation API

旧文档和自动化记录里已经存在：

- `navigationDestination`
- `fullScreenCover`
- 历史 preview root

如果未来只改展示 API、不先定义 route contract，很容易造成自动化继续追旧入口。

### 3. 当前 route 字符串还没有真实消费者

这意味着统一 contract 前，不能假设现有 `sparelife://...` 已经能驱动页面跳转。它们需要先被映射到 typed route，才能进入稳定状态恢复和 UI 自动化。

### 4. 同一页面混用 push 与 modal 的惯性已经形成

尤其是消息线程和大师会话。如果没有明确规定“谁拥有 detail”，团队后续很容易在新页面里继续复制这种双轨模式。
