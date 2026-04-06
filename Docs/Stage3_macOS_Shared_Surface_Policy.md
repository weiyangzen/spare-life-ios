# Stage 3 macOS Shared Surface Policy

## Runtime Truth

- `ios/spare-life-ios-app/Package.swift` 已声明 `.iOS(.v16)` 与 `.macOS(.v13)`，当前 Apple 端共享 runtime truth 在 `ios/spare-life-ios-app/`。
- `app/macos/` 仍是宿主车道占位目录，不是第二套 feature tree 的起点。
- Wave 0 的目标不是先复制页面，而是先冻结哪些文件默认共享，哪些差异只能落在 shell、container、interaction 层。

## Directly Shared Swift Files

| File | Shared role | Why it stays shared |
| --- | --- | --- |
| `ios/spare-life-ios-app/App/ConversationRouter.swift` | content + state | route 主键、handoff 语义和状态归口必须跨 iOS/macOS 共用。 |
| `ios/spare-life-ios-app/App/DesignSystem/DesignTokens.swift` | content + state | 色板、字体、头像加载、空态/错误态属于同源视觉与 shared primitives。 |
| `ios/spare-life-ios-app/App/DesignSystem/PlatformCompat.swift` | content + state | 平台兼容 shim 的职责是吸收差异，而不是把差异放回 feature 页面。 |
| `ios/spare-life-ios-app/App/DesignSystem/WaterfallLayout.swift` | content + state | 瀑布流布局算法、骨架屏和列宽计算在 iOS/macOS 保持同一实现。 |
| `ios/spare-life-ios-app/Features/CompanionChat/CompanionChatStore.swift` | content + state | 消息状态和 seeded runtime truth 先保持共享。 |
| `ios/spare-life-ios-app/Features/EarnSocial/EarnSocialExperienceStore.swift` | content + state | Earn Social 状态与数据归口不因宿主平台分叉。 |
| `ios/spare-life-ios-app/Features/EarnSocial/EarnSocialHomeView.swift` | content + state | 当前页面内容与 IA 仍应直接共享，后续只允许外层容器优化。 |
| `ios/spare-life-ios-app/Features/Masters/MasterExperienceStore.swift` | content + state | 大师目录与会话状态共享，不能复制第二套 store。 |
| `ios/spare-life-ios-app/Features/Shared/FeedCardProtocol.swift` | content + state | card taxonomy、排序和字段契约必须跨平台一致。 |
| `ios/spare-life-ios-app/Features/Shared/DiscoverMixedFeedSection.swift` | content + state | 混排 section 属于共享内容，不是桌面专属页面。 |
| `ios/spare-life-ios-app/Features/Shared/UnifiedWaterfallFeed.swift` | content + state | loading/empty/error/refresh/feed skeleton 属于共享运行逻辑。 |
| `ios/spare-life-ios-app/Features/Shared/UnifiedDiscoverFeedView.swift` | content + state | discover feed 是共享内容页，不应先长出 macOS 专属业务分支。 |
| `ios/spare-life-ios-app/Features/Xianxia/XianxiaHomeView.swift` | content + state | 当前闲虾首页内容先共享，后续若做多栏只抽外层容器。 |

## Explicit Desktop Branch Points

| File | Layer | Why the branch lives here |
| --- | --- | --- |
| `ios/spare-life-ios-app/App/MainTabView.swift` | desktop shell | 根导航 chrome 可从底栏切到 sidebar/toolbar/workspace，但模块顺序、进入路径和 route 语义必须共用。 |
| `ios/spare-life-ios-app/Features/Masters/MasterChatHomeView.swift` | desktop container | 大师目录允许从 modal/push 承接切到 list-detail / multi-column，但共享 store、卡片内容和会话语义不复制。 |
| `ios/spare-life-ios-app/Features/Masters/MasterSpeechInputActions.swift` | desktop interaction | 麦克风录音与按住说话是硬件/交互差异，应该留在交互层。 |
| `ios/spare-life-ios-app/Features/Xianxia/QRScanView.swift` | desktop interaction | 摄像头权限、扫码体验与设备能力是平台交互差异，不应渗入业务内容层。 |

## Implementation Principles

1. 默认规则：除非进入“显式分支清单”，新页面、新 store、新 route 文件一律先按 shared content + state 落地。
2. shell 只管顶层宿主：tab bar、sidebar、toolbar、workspace 入口可以变，但模块 IA、route、数据主键不能变。
3. container 只管结构承接：modal、push、split view、list-detail、多栏布局可以变，但共享内容组件与状态归口不能复制。
4. interaction 只管平台 affordance：hover、secondary click、keyboard shortcut、camera、microphone、haptics 只在交互层分支。
5. 任何页面如果需要 desktop optimization，先抽共享内容/共享 view model，再包一层 macOS shell/container，而不是直接复制整个页面树。
6. `#if os(...)` / `#if canImport(...)` 如果不是 compat shim 或显式 shell/container/interaction wrapper，就视为待清理信号。
