# S5-03 `SpareLifeCore` Package Boundary Audit

## 当前代码现状

1. `SpareLifeCore` 现在的 Swift package 边界是清楚的，但它只是“其中一个”编译入口，不是唯一入口。`spare-life-ios-app/Package.swift` 把 `SpareLifeCore` 定义成 library target，只纳入 `App`、`Domain/Models`、`Features` 三个源码根，并排除了 `App/CLI`、`Features/Masters/Support`、`LocalBackend`、`Services`、`Domain/UseCases`、`Tests` 与 `Resources`。证据在 `spare-life-ios-app/Package.swift:15-49`。按这份 manifest，当前 package 内共有 49 个 Swift 文件。
2. 但运行中的 iOS host 并不通过 package 依赖来消费这 49 个文件。`spare-life-ios-preview-host/SpareLifePreviewHost.xcodeproj/project.pbxproj` 直接把 `../spare-life-ios-app/App/*.swift`、`../spare-life-ios-app/Domain/Models/*.swift`、`../spare-life-ios-app/Features/**/*.swift` 逐个加入工程源文件列表，而不是声明一个 `SpareLifeCore` package dependency。证据在 `spare-life-ios-preview-host/SpareLifePreviewHost.xcodeproj/project.pbxproj:81-137`。对比 `Package.swift` 与 `.pbxproj` 后，当前两者覆盖的是同一组 49 个 Swift 文件。
3. 仓库里唯一的 `@main` app entry 并不在 `spare-life-ios-app`，而在 preview host。全文检索 `@main` 只命中 `spare-life-ios-preview-host/App/SpareLifePreviewHostApp.swift:3`；这个 host app 在 `WindowGroup` 中直接启动 `MainTabView()`，并在 `init()` 里注册 masters 默认配置。证据在 `spare-life-ios-preview-host/App/SpareLifePreviewHostApp.swift:3-17`。这说明当前真正的 host-only Swift 文件是 preview host 下的 app bootstrap，而不是 `spare-life-ios-app/App/`。
4. `spare-life-ios-app/App/` 当前实际承担的不是 app entry，而是 shell surface 与 shared infra：
   - `App/MainTabView.swift` 定义了 `MainTab`、根 `TabView`、自定义 tab bar、`fullScreenCover` 路由承接。证据在 `spare-life-ios-app/App/MainTabView.swift:11-236`。
   - `App/ConversationRouter.swift` 是消息线程展示的轻量 router。证据在 `spare-life-ios-app/App/ConversationRouter.swift:1-10`。
   - `App/DesignSystem/PlatformCompat.swift` 明确写着 “cross-platform shims for SwiftUI package indexing/building”，并为非 UIKit 平台提供兼容层。证据在 `spare-life-ios-app/App/DesignSystem/PlatformCompat.swift:1-70`。
   这类文件更接近“可复用 UI shell / package-compatible infrastructure”，而不是 host bootstrap。
5. 当前 package 边界里混入了一份明显偏向 preview/test automation 的 Swift 文件：`Features/Masters/MasterStage1Automation.swift`。它通过 `SPARE_MASTERS_AUTOMATION_COMMAND` 环境变量决定执行 `directory_snapshot`、`seed_chat`、`stage2_smoke`、`resume_chat`，并向本地状态目录写验证结果。证据在 `spare-life-ios-app/Features/Masters/MasterStage1Automation.swift:4-39`。`MasterExperienceStore` 在启动路径里会检测这类环境变量并自动触发 automation runner。证据在 `spare-life-ios-app/Features/Masters/MasterExperienceStore.swift:537-546`。对应测试也全部围绕 automation 结果文件写入和 smoke payload 展开，而不是用户运行时行为本身。证据在 `spare-life-ios-app/Tests/SpareLifeCoreTests/MasterConversationServiceTests.swift:608-624`、`:655-683`、`:848-886`。
6. `SpareLifeCore` 还存在“Swift 在 package，资源在 host”的现实边界。`Package.swift` 显式排除了 `Features/Masters/Support`，但 `MasterExperienceStore` 会优先从 `Bundle.main` 读取 `master_service_directory.json`，找不到时再回退到 `#filePath` 邻近的 `Support/master_service_directory.json`。证据在 `spare-life-ios-app/Package.swift:23-25` 与 `spare-life-ios-app/Features/Masters/MasterExperienceStore.swift:2128-2139`。preview host 工程则把这份 JSON 作为资源显式打包进 app。证据在 `spare-life-ios-preview-host/SpareLifePreviewHost.xcodeproj/project.pbxproj:103` 与 `:452-460`。这意味着 package 目前只对 Swift 边界负责，还没有成为资源边界的真相。
7. preview host README 直接承认当前 host 是“编译 `../spare-life-ios-app/` 现有源码”的最小 iOS host。证据在 `spare-life-ios-preview-host/README.md:3-10`。因此，今天最准确的代码结论不是“所有 Swift 都由 `SpareLifeCore` 驱动”，而是“package 与 preview host project 手工维护了同一组 Swift 源文件边界”。

## 当前文档偏差

1. `spare-life-ios-app/README.md` 目前把 `App/` 描述成 “app entry, scene lifecycle, and bootstrap wiring”。证据在 `spare-life-ios-app/README.md:7-16`。但代码现状恰好相反：唯一 `@main` 在 preview host，`spare-life-ios-app/App/` 放的是 `MainTabView`、`ConversationRouter` 和 `DesignSystem`。如果继续沿用 README 的表述，会误导读者把 package 内的 shell surface 当成 host bootstrap。
2. `Docs/Stage_3_Codebase_Audit.md` 对 package 的结论只说到 “`SpareLifeCore` 编译 `App`、`Domain/Models`、`Features`”，这本身没错，但它没有把 preview host 直接编译同一批 Swift 文件这一层补充出来。结果读者容易误判 package 已经是 Swift compile boundary 的唯一真相。
3. 现有文档也没有明确指出 `MasterStage1Automation.swift` 其实是 preview/test harness，而不是普通 feature runtime。只要它继续留在 `SpareLifeCore` 主目标里，package boundary 文档如果仍把 49 个 Swift 文件一概称作 “core runtime”，就会把 automation lane 伪装成用户运行时。
4. preview host README 已经比 app README 更接近代码现实，因为它明确说 host 直接编译 `../spare-life-ios-app/`。证据在 `spare-life-ios-preview-host/README.md:3-10`。当前真正的漂移，不是 preview host 文档，而是 app/package 口径没有把“双编译入口”写清楚。

## 稳定 SOTA / 成熟实践

1. library/package target 应只承载可复用的 Swift 代码单元：视图、状态模型、领域模型、轻量路由、跨平台兼容层。它不应该承担 host app `@main`、签名配置、Info.plist、或专门为 UI automation 设计的 runner。
2. host app target 应只负责进程入口、默认配置注入、资源装配、签名与平台能力声明。换句话说，`MainTabView` 可以在 package，`SpareLifePreviewHostApp` 不应进 package。
3. preview/UI automation 应放在 host-only 或独立 support target，而不是直接塞进核心库。否则 library 会被环境变量、result file path、simulator smoke command 这类验证细节污染。
4. 一个仓库最好只有一份 Swift compile manifest 真相。要么 preview host 直接依赖 package，要么 package 清晰声明不被 host 使用；最糟的状态就是现在这样由 `Package.swift` 与 `.pbxproj` 并行维护同一组源文件。
5. 对 bundle 资源有依赖的 feature，成熟做法要么把资源显式收进 package target resources，要么通过 host 注入资源定位器，而不是同时依赖 `Bundle.main` 与 `#filePath` 双路径兜底。

## 面向本仓库的具体建议

1. 先把当前 Swift 代码分成三层，而不是继续用“都在 `spare-life-ios-app` 里所以都算 core”这种口径：

| 分类 | 当前应归属的 Swift 文件 | 结论 |
| --- | --- | --- |
| package (`SpareLifeCore`) | `spare-life-ios-app/App/DesignSystem/*.swift`、`spare-life-ios-app/App/MainTabView.swift`、`spare-life-ios-app/App/ConversationRouter.swift`、`spare-life-ios-app/Domain/Models/*.swift`、`spare-life-ios-app/Features/**/*.swift` 中真正的 feature/store/view 文件 | 这些文件是可复用 Swift surface，当前也确实被 package 与 preview host 双方消费，应保留在 package。 |
| app-only host | `spare-life-ios-preview-host/App/SpareLifePreviewHostApp.swift`，以及未来真正的生产 app `@main` / bootstrap 文件 | 这类文件负责进程入口、默认配置、host resource 组装，不应进入 package。 |
| preview-host-only / automation support | `spare-life-ios-preview-host/UITests/XianxiaStage1UITests.swift`，以及建议迁出的 `spare-life-ios-app/Features/Masters/MasterStage1Automation.swift` | 这类文件为 UI automation、smoke orchestration、result file 输出服务，不应继续混在 package 主 runtime。 |

2. 对 `spare-life-ios-app` 当前目录的更细结论应当是：
   - `App/CLI/main.swift` 继续留在 executable target，不进 library。证据在 `spare-life-ios-app/Package.swift:10-12` 与 `:41-45`。
   - `App/MainTabView.swift` 与 `App/ConversationRouter.swift` 暂时保留在 package，因为 preview host 直接以 `MainTabView()` 作为根 UI，`SpareLifeCoreSmokeTests` 也直接依赖 `MainTab`。证据在 `spare-life-ios-preview-host/App/SpareLifePreviewHostApp.swift:12-16` 与 `spare-life-ios-app/Tests/SpareLifeCoreTests/SpareLifeCoreSmokeTests.swift:4-7`。
   - `Features/Masters/MasterStage1Automation.swift` 应从 package 主目标中迁出，改成 preview host target 的 source，或单独做 `SpareLifeAutomationSupport`。因为它的能力不是用户功能，而是 automation command 解码和 result 文件写入。
3. 对 masters support 资源，当前建议不要急着把 `Features/Masters/Support` 全量并入 package。更稳的做法是先承认它现在属于 host resource layer，然后在下一步二选一：
   - 方案 A：给 package 增加显式 resources，使 `master_service_directory.json` 成为 package 自带资源。
   - 方案 B：保留 host resource 装配，但把 `MasterExperienceStore` 的资源定位改成注入式 provider，去掉 `Bundle.main` / `#filePath` 双路径兜底。
   在没有做出选择前，不应把 resource boundary 伪装成已经被 package 统一管理。
4. preview host 工程后续应改成依赖 `spare-life-ios-app/Package.swift` 的本地 package，而不是继续在 `.pbxproj` 里手填 49 个 Swift 文件。`spare-life-ios-preview-host/README.md` 已经说明 host 只是最小载体，因此最稳的长期结构是：host 只保留 `@main`、资源和 UITests，所有可复用 Swift surface 从 package 进入。
5. 当前 repo 里“app-only Swift files”其实很少，这本身就是需要写进文档的真相。不要人为捏造一个不存在的生产 app target。今天真正存在的是：
   - 一个 package/library compile lane
   - 一个 preview host app lane
   - 一个 CLI executable lane
   文档应该据此表述，而不是继续写成“`spare-life-ios-app/App/` 就是完整 app bootstrap”。

## 实施顺序

1. 先冻结文档口径：以后所有 Stage 3 文档都应把 `SpareLifeCore` 描述成“49 个可复用 Swift 文件的 library target”，同时补一句“preview host 目前直接编译了同一组源文件”。
2. 再处理最清晰的污染点：把 `MasterStage1Automation.swift` 从 package 主 runtime 中抽出，改由 preview host / automation support target 持有。
3. 然后只收敛一份 compile manifest：让 `SpareLifePreviewHost.xcodeproj` 依赖本地 package，而不是继续复制 source list。
4. 最后才处理资源边界：决定 masters support JSON 和图像资产是进 package resources，还是继续留在 host resource layer 并走注入式定位。

## 风险

1. 如果继续让 `Package.swift` 与 preview host `.pbxproj` 并行维护同一组 49 个 Swift 文件，后续增删文件时一定会出现“package 能过但 preview host 不过”或反过来的漂移。
2. 如果贸然把 `MasterStage1Automation.swift` 从 package 中拿掉，但没有同时给 preview host 或测试 lane 新的编译归属，现有 masters smoke 会直接断。
3. 如果在资源边界未澄清前就强推 preview host 改走 package dependency，`master_service_directory.json` 与角色图像目录极可能先成为第一个编译/运行 blocker。
4. 如果继续沿用 `spare-life-ios-app/README.md` 现有口径，团队会不断高估 `App/` 目录在进程入口层的职责，进而把更多 host-only 逻辑错误塞回 package。

代码和旧文档冲突时，本条研究结论以代码为准。
