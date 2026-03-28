# Stage2 Blueprint 0328 Checklist

Authoritative source: `/Users/wangweiyang/GitHub/spare-life-ios/Docs/Stage2_Blueprint.md`

This file mirrors the authoritative Stage 2 checklist in Docs/Stage2_Blueprint.md.
Workers may update only their owned section and the guard will refresh this mirror from the blueprint.

### 4.1 全局 Foundation

- [x] 共享瀑布流在 iPad 横屏固定为 5 列，在 iPhone 与 iPad 竖屏固定为 2 列。
- [x] 共享卡片样式统一落地 `8:5` 比例、圆角和 `8px` 间距约束，供 5 个页面复用。
- [x] Stage 2 共享卡片容器与瀑布流实现从单页面抽离成可复用基础层。
- [x] 全局 bottom nav 稳定切换 5 个页面，不再出现点击后停在第一页的问题。
- [x] 全局 bottom nav 不再遮挡实际功能区，并且在 iPhone / iPad / 键盘弹起 / 长列表滚动场景下都有优雅的承接方案。
- [x] preview host 与主工程复用同一套 Stage 2 全局导航和共享样式实现。

### 4.2 闲人

- [ ] topic 列表真实走通后端读取，并具备本地缓存与分页承接。
- [ ] 单个 topic 详情真实走通 shard 拉取，并能覆盖到 Stage 2 目标的 `1200 topic shards` 数据规模。
- [ ] topic 卡片优先显示后端 summary，而不是直接暴露 raw text。
- [ ] topic shard 列表使用 IM 风格单条消息渲染，最少展示 id、时间、内容。
- [ ] 群名、人名等源字段缺失时，UI 化简成最后四位的稳定展示规则。
- [ ] 闲人页面基于真实 ClawDB / 后端链路完成验证，而不是纯本地 mock。


### 4.3 闲聊

- [ ] `./assets/char` 与 `./assets/assets` 现有大师资源全部刷成卡片，当前批次至少完整显示 8 位。
- [ ] 闲聊首页卡片列表复用共享瀑布流与共享卡片样式，不再挂旧的复杂首页。
- [ ] 点击任意大师卡后，稳定进入一对一闲聊页面。
- [ ] 闲聊聊天框接入 ClawDB 服务器的 ASR 接口，支持语音识别输入并正确回填到对话发送链路。
- [ ] 大师闲聊请求携带全量 context，而不是只带最后一轮浅上下文。
- [ ] 大师闲聊推理路径切到提供的 `k2p5` 模型与对应后端请求逻辑。
- [ ] 大师回复必须符合上下文和角色设定，像“小说场景中的角色台词”，而不是通用助手口吻。
- [ ] 闲聊页面完成当前 8 位大师卡片与至少 1 条真实对话链路的本机验证。


### 4.4 赚闲能

- [ ] 页面顶部分类轨道完整呈现 `跑腿 / 嘴替 / 搭子 / 两性 / 求职招聘 / 投融资 / 闲置` 7 个分类。
- [ ] 每个分类都能从本地存储 / assets 加载 10 个 Mock 卡片。
- [ ] 点击任意卡片后可以进入对应的聊天框页面。
- [ ] 分类页面与卡片详情页复用共享卡片和共享瀑布流规范。
- [ ] `../Social_Masks_EvoHack/` 与 `Docs/evomap_link.md` 的接入位置和输入契约在代码结构中预留清楚。


### 4.5 消息

- [x] 消息首页能从本地存储 / assets 刷出 10 个 Mock 联系人卡片。
- [x] 点击联系人后进入类 IM 的聊天详情页。
- [x] 聊天详情页提供 `真人 / 分身` 模式切换开关。
- [ ] 消息页的 mock 联系人、消息与模式状态支持本地存储承接。
- [ ] 消息页与闲聊页保持同一设计系统，但聊天语义明确区分“对大师闲聊”和“人与分身消息”。


### 4.6 我的

- [ ] 我的页面总览同时呈现 `闲人 / 闲聊 / 赚闲能 / 消息` 四组数据区域。
- [ ] 闲人区域真实读取 ClawDB 指标：渠道数、话题数、独立 id 数、被 Mention 次数。
- [ ] 闲聊区域呈现大师交互人数与交互次数。
- [ ] 赚闲能区域呈现 mock 的交互人数、交互次数和个人赚能风格描述。
- [ ] 消息区域呈现 mock 的真人 / 分身互动统计。
- [ ] 我的页面整体布局复用 Stage 2 共享卡片规范并完成 iPhone / iPad 适配验证。
