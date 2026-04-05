# S3-06 ASR Readiness 契约研究

本研究只覆盖 `Masters` 模块里的 ASR readiness 契约，不展开实时对话主状态机、`Xianxia` 数据层或 preview-host 产品代码改造。若旧文档与当前代码冲突，以当前代码和现有测试为准。

## 1. 当前代码现状

### 1.1 当前 ASR 契约把 endpoint、auth、payload、readiness 全揉在一个解析器里

当前核心入口是 `spare-life-ios-app/Features/Masters/MasterASRService.swift` 里的：

- `MasterASRConfiguration.current(...)`
- `MasterASRConfiguration.currentStatus(...)`
- `MasterASRConfiguration.resolved(...)`

这套解析逻辑一次性同时处理了：

- endpoint config
  - `MASTER_ASR_URL`
  - `MASTER_ASR_BASE_URL`
  - `MASTER_ASR_PATH`
  - `MASTER_ASR_METHOD`
- auth config
  - `MASTER_ASR_AUTH_HEADER`
  - `MASTER_ASR_AUTH_SCHEME`
  - `MASTER_ASR_API_KEY`
  - `MASTER_ASR_AUTH_TOKEN`
- payload tuning
  - `MASTER_ASR_MODEL`
  - `MASTER_ASR_LANGUAGE`
  - `MASTER_ASR_RESPONSE_FORMAT`
  - `MASTER_ASR_ROUTING_PROFILE`

解析器本身已经很完整，但边界上仍是“一个解析器同时定义配置和 readiness”，没有把责任拆开。

### 1.2 当前 readiness 结构过薄，只能表达 ready / warning 两态

`MasterASRConnectionStatus` 当前只有：

- `tone`
  - `.ready`
  - `.warning`
- `title`
- `detail`

这意味着下面这些本 item 明确要求的边界都没有独立对象：

- `endpoint config`
- `auth config`
- `preview-host capability`
- `smoke validation`
- `blocker reporting`

结果是 readiness 只能靠一段人类可读长文本近似表达，而不能被页面、自动化和测试稳定消费。

### 1.3 当前代码把“可解析配置”直接视为 ready，哪怕还没有真实验证

当前 `MasterASRConfigurationResolution.status` 的行为非常关键：

- 只要 URL 能解析，就直接返回 `.ready`
- 默认内建值：
  - `baseURL = http://100.82.60.69:8020`
  - `path = /v1/asr/transcribe`
  - `method = POST`
- 即便没有显式 auth header / apiKey，也仍然是 `.ready`

现有测试已经把这个行为固化下来：

- `MasterASRServiceTests.testMasterASRConfigurationStatusWarnsWhenStillUsingDefaultProbeRoute`
  - 断言 `tone == .ready`
  - 断言标题是 `"ClawDB ASR 已接通"`
- `MasterASRServiceTests.testMasterASRConfigurationStatusWarnsWhenEndpointExistsButAuthIsMissing`
  - 断言 `tone == .ready`
  - 断言标题是 `"ASR live 已接通"`

所以当前代码事实不是“未验证 endpoint 会被标红”，而是“只要解析成功就视为 ready”。

### 1.4 当前语音入口的 gating 只看 `tone != .ready`，不会识别“已配置但未验证”

`MasterSpeechInputActions.swift` 当前的阻断逻辑只有一条：

- `MasterSpeechTranscriptionAvailability.blockingMessage(for:)`
  - 只有 `status.tone != .ready` 才阻断

这会导致：

- 默认内建 endpoint 会放行录音和转写尝试
- 缺少 smoke evidence 不会阻断
- 缺少 preview-host capability 信息不会阻断
- 缺少结构化 blocker code 不会阻断

用户最终是在 `transcribeAudio(...)` 失败后，才通过 `error.localizedDescription` 得到 `405` 或 transport 错误。

### 1.5 当前 `endpoint config` 与 `auth config` 没有独立归属对象

虽然 `detail` 文案会写出：

- endpoint 注入键位
- auth 注入键位
- source summary

但代码里仍没有独立的：

- `MasterASREndpointConfig`
- `MasterASRAuthConfig`

于是调用方拿到的不是“结构化配置事实”，而是一段已经被拼好的 readiness 说明文案。

### 1.6 当前 `preview-host capability` 不在 readiness 契约里

录音能力目前分散在两个位置：

- `MasterSpeechInputActions` / `MasterAudioRecorderController`
  - 运行时请求 `AVAudioSession` 麦克风权限
- `spare-life-ios-preview-host/App/SpareLifePreviewHostInfo.plist`
  - 当前已经存在 `NSMicrophoneUsageDescription`

也就是说：

- host capability 现在确实影响 ASR 录音链路；
- 但 readiness 对象里完全没有这维信息。

所以当前契约无法回答：

- 这个 endpoint 配好了，但当前 host 是否允许录音？
- 当前是“只能导入文件做转写”，还是“录音 + 导入都可用”？

### 1.7 当前 `smoke validation` 只存在于 opt-in XCTest，不会反向喂给页面或 store

现有 smoke 入口是：

- `MasterASRServiceTests.testClawDBMasterASRServiceLiveSmokeRunsWhenExplicitlyEnabled`

它依赖：

- `MASTER_ASR_LIVE_SMOKE=1`
- `MASTER_ASR_SMOKE_AUDIO_FILE`
- 可选 `MASTER_ASR_SMOKE_EXPECT_SUBSTRING`

但 smoke 的结果不会回写到：

- `MasterASRConnectionStatus`
- `MasterExperienceStore`
- UI 页面

所以当前代码没有“已配置但未验证”与“已通过 smoke 验证”的结构化区别。

### 1.8 当前 blocker reporting 还是自由文本，缺少稳定 code

当前 blocker 主要通过：

- `MasterASRServiceError`
- `localizedDescription`
- `inlineError`

向上游传播。

优点是用户可读。

问题是没有稳定字段来表达：

- `invalid_base_url`
- `missing_auth`
- `host_capability_missing`
- `smoke_not_run`
- `method_not_allowed`
- `transport_failed`

因此：

- 页面只能显示长文本
- 自动化难以精确分类
- 文档容易把旧 blocker 继续写成当前事实

## 2. 当前文档偏差

### 2.1 `Stage2_Blueprint_0328_Checklist.md` 把默认探针描述得比当前代码更保守

旧文档多次写到：

- 默认 probe route 仍是 blocker
- 语音入口在 ASR 未 ready 时会提前阻断
- 不会把默认 route 误用成可写入口

但当前代码与测试事实是：

- 默认 `http://100.82.60.69:8020/v1/asr/transcribe` 会被标成 `.ready`
- `MasterSpeechInputActions` 只在 `tone != .ready` 时阻断
- 默认 route 会被放行到真实请求阶段

这里存在明确冲突，必须以代码为准。

### 2.2 旧文档记录的默认 ASR 路由已不是当前代码事实

旧文档大量围绕：

- `http://100.82.60.69:17880/v1/audio/transcriptions`
- `405 method_not_allowed`

展开。

但当前代码里的内建默认值已经是：

- `http://100.82.60.69:8020/v1/asr/transcribe`

并且请求体偏向：

- JSON `audio_base64`
- `routing_profile`

所以旧文档里的默认探针地址不能再被视为当前运行真相。

### 2.3 旧文档关于 preview host 缺少麦克风声明的描述已经过期

旧 Stage 2 checklist 明确写过：

- preview host 缺少 `NSMicrophoneUsageDescription`

但当前仓库里 `spare-life-ios-preview-host/App/SpareLifePreviewHostInfo.plist` 已经包含：

- `NSMicrophoneUsageDescription`

这说明文档关于 preview-host capability 的结论已经过期，而且再次证明该能力不应继续靠人工日志描述，而应回到结构化 readiness 契约。

### 2.4 `Stage_3_Codebase_Audit.md` 关于“diagnostics 很强”的判断对 ASR 不够精确

Audit 说 masters 模块在 diagnostics 和 fallback 上比较成熟，这个判断对对话链路大体成立，但对 ASR readiness 来说还不够：

- 当前 diagnostics 的确有不少 detail 文案；
- 但 readiness 结构没有把 endpoint / auth / host / smoke / blocker 分层。

所以 ASR 的问题不是“完全没诊断”，而是“诊断文本已经很多，但 readiness 契约边界还不清楚”。

## 3. 稳定 SOTA 或成熟实践

对 iOS 侧外部语音转写能力，更成熟的做法通常不是一个 `ready / warning` 开关，而是把 readiness 拆成多个独立维度。

### 3.1 配置存在不等于 readiness 成立

更稳定的判断通常至少分成三层：

- `configured`
  - endpoint / method / payload 可解析
- `capable`
  - 当前 host 有权限、有运行能力
- `verified`
  - 通过 smoke 或真实成功样本验证过

也就是说，“能拼出 URL”只能证明 configured，不能直接等于已接通。

### 3.2 endpoint 与 auth 应是不同归属对象

成熟实践通常把：

- endpoint
  - URL
  - method
  - payload kind
  - model / language / routing
- auth
  - header name
  - scheme
  - token presence
  - token source

分别建模。这样既避免配置边界继续混成一团，也方便页面分别提示“缺端点”和“缺鉴权”。

### 3.3 host capability 应属于客户端宿主层，而不是网络层

麦克风权限、plist 声明、preview-host / app-host 差异，属于客户端宿主能力，不是远端 ASR endpoint 的属性。

更成熟的做法通常会把它建成单独维度：

- `supportsImport`
- `supportsRecording`
- `hasMicrophoneUsageDescription`
- `hasMicrophonePermission`

然后由 UI 决定哪些入口可点。

### 3.4 smoke validation 应是结构化证据，而不是只存在于测试说明

更稳的实践不是“文档说我们跑过 smoke”，而是把 smoke 结果结构化：

- `status`
  - `notRun / skipped / passed / failed`
- `validatedAt`
- `requestURL`
- `environmentKind`
- `blockerCode`

这样 UI、自动化和文档才能共享一份验证事实。

### 3.5 blocker reporting 应该有 code、summary、remediation 三层

成熟实践里，blocker 通常不会只有一句错误文本，而是至少有：

- `code`
  - 用于测试和自动化
- `summary`
  - 用于 UI 一行提示
- `remediation`
  - 用于下一步操作指引

否则用户只能看到长文本，自动化只能做字符串 contains。

## 4. 面向本仓库的具体建议

### 4.1 把当前 ASR 契约拆成五个拥有者

更适合本仓库的结构是：

```swift
struct MasterASREndpointConfig {
    let url: URL
    let method: String
    let payloadKind: PayloadKind
    let model: String?
    let language: String?
    let responseFormat: String?
    let routingProfile: String?
    let sourceAudit: SourceAudit
}

struct MasterASRAuthConfig {
    let headerName: String?
    let scheme: String?
    let tokenPresent: Bool
    let tokenSource: SourceAudit?
}

struct MasterASRHostCapability {
    let supportsImport: Bool
    let supportsRecording: Bool
    let hasMicrophoneUsageDescription: Bool
    let hasRecordPermission: Bool?
}

struct MasterASRSmokeEvidence {
    let status: SmokeStatus
    let validatedAt: String?
    let requestURL: String?
    let blockerCode: String?
}

struct MasterASRReadiness {
    let phase: Phase
    let endpoint: MasterASREndpointConfig?
    let auth: MasterASRAuthConfig
    let host: MasterASRHostCapability
    let smoke: MasterASRSmokeEvidence
    let blockers: [MasterASRBlocker]
}
```

这正好对应本 item 要求的五个边界。

### 4.2 重新定义 overall readiness，相同 endpoint 不再直接等于“已接通”

建议把 overall phase 至少拆成：

- `blocked`
- `configuredUnverified`
- `verified`

对应到当前代码可先这样落地：

- 默认内建 endpoint：
  - 不再直接显示“已接通”
  - 至少应该是 `configuredUnverified`
- endpoint 无效：
  - `blocked`
- endpoint 可用且 smoke / 真实成功证据成立：
  - 才能进入 `verified`

这能解决现在“只要 URL 能解析就 ready”的过度乐观。

### 4.3 把 `MasterSpeechInputActions` 的 gating 从 `tone` 切到结构化 readiness

当前逻辑过于粗糙。更适合本仓库的 gating 是：

- 导入音频：
  - 只要求 endpoint configured + blocker 不致命
- 录音转写：
  - 还要要求 host capability 支持 recording
- 真实发送前：
  - 再检查 auth / smoke / blocker code

也就是说，`supportsImport` 和 `supportsRecording` 应该是两套 gate，不要继续共用一个 `tone != .ready`。

### 4.4 明确五类边界的归属，不再让 `MasterASRConfiguration.currentStatus()` 一把抓

建议归属划分如下：

- `MasterASRService`
  - 只负责 endpoint + auth 解析、请求拼装、响应解码、传输错误映射
- app / preview host
  - 负责 host capability 采集
- smoke harness / tests
  - 负责生成 smoke evidence
- `MasterExperienceStore`
  - 只消费 `MasterASRReadiness`，不自己拼 readiness 文案
- UI
  - 只根据 readiness 和 blocker 呈现入口与文案

这能避免同一段代码同时决定配置、宿主能力和验证结论。

### 4.5 把 blocker 从长文本升级成稳定 code

建议至少补出以下 blocker code：

- `invalid_endpoint`
- `missing_endpoint_override`
- `missing_auth`
- `host_capability_missing`
- `microphone_permission_denied`
- `smoke_not_run`
- `smoke_failed`
- `method_not_allowed`
- `transport_failed`

然后把当前 `localizedDescription` 拆成：

- `summary`
- `detail`
- `remediation`

页面继续展示中文文案，但自动化和测试不再靠模糊字符串匹配。

### 4.6 让 smoke evidence 回流到 readiness，而不是只停在 XCTest

对本仓库最现实的做法不是引入复杂后端，而是先让当前 smoke test 结果可被 store 消费。最小路径可以是：

1. 保留现有 `MASTER_ASR_LIVE_SMOKE=1` XCTest。
2. 让 smoke 结果写一个轻量本地 evidence 文件或内存 snapshot。
3. `MasterASRReadiness` 读取最近一次 smoke evidence。
4. 页面据此区分：
   - 已配置但未验证
   - 已验证可用
   - 最近一次 smoke 失败

这一步不需要改产品功能，只是在代码边界上把验证事实结构化。

## 5. 实施顺序和风险

### 5.1 实施顺序

1. 先新增 `MasterASREndpointConfig`、`MasterASRAuthConfig`、`MasterASRReadiness` 等值类型，用 adapter 保持现有 UI 不立即失效。
2. 再把 `MasterASRConfiguration.currentStatus()` 改成产出 `configuredUnverified / blocked / verified`，不再用单纯 `ready / warning` 表意。
3. 把 `MasterSpeechInputActions` 改成消费结构化 readiness，并把“导入”和“录音”分开 gating。
4. 最后接入 preview-host capability 与 smoke evidence，让页面和自动化共享同一 readiness 事实。

### 5.2 主要风险

- 当前测试已经把“默认 route 也是 ready”写死；一旦改契约，相关测试与 UI 文案会一起回归。
- 如果没有把 `supportsImport` 和 `supportsRecording` 分开，容易把所有语音入口一起误伤掉。
- 若 smoke evidence 不区分 host / environment，很容易把别的机器上通过的验证误判成当前宿主也可用。
- 结构化 blocker 时必须继续避免泄露明文 token；只能记录来源与 presence，不能记录原始值。

