// EarnSocialHomeView.swift
// Spare Life – Stage 2 earn-social home

import SwiftUI

struct EarnSocialHomeView: View {
    @State private var selectedCategory: EarnSocialCategory = .errand
    @State private var activeCard: EarnSocialMockCard?
    @State private var showPreferenceSheet = false

    private var visibleCards: [EarnSocialMockCard] {
        EarnSocialMockFixtures.cards[selectedCategory] ?? []
    }

    var body: some View {
        NavigationStack {
            ZStack {
                pageBackground

                VStack(spacing: 0) {
                    header

                    GeometryReader { proxy in
                        let spacing = Spacing.sm
                        let columns = WaterfallColumns.count(for: proxy.size.width)
                        let totalSpacing = spacing * CGFloat(columns - 1)
                        let horizontalPadding = Spacing.sm * 2
                        let columnWidth = max(120, floor((proxy.size.width - horizontalPadding - totalSpacing) / CGFloat(columns)))

                        ScrollView(.vertical, showsIndicators: false) {
                            WaterfallLayout(columns: columns, spacing: spacing) {
                                ForEach(visibleCards) { card in
                                    EarnSocialMockCardView(card: card) {
                                        activeCard = card
                                    }
                                    .frame(width: columnWidth)
                                }
                            }
                            .padding(.horizontal, Spacing.sm)
                            .padding(.bottom, Spacing.xxxl)
                        }
                    }
                }
            }
            .spareNavigationBarHidden(true)
            .sheet(item: $activeCard) { card in
                EarnSocialMockChatView(card: card)
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var pageBackground: some View {
        LinearGradient(
            colors: [
                Color.spareYellow.opacity(0.12),
                Color.white,
                Color.white
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Spacer()
                Text("赚闲能")
                    .font(.spareTitle2)
                    .foregroundColor(.primary)
                Spacer()
            }

            HStack(alignment: .center, spacing: Spacing.sm) {
                categoryTabs
                preferenceButton
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.md)
    }

    private var preferenceButton: some View {
        Button {
            showPreferenceSheet = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                Text("我的偏好")
                    .font(.spareCaptionSB)
            }
            .foregroundColor(.spareDark)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 10)
            .background(Color.white, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.spareYellow.opacity(0.24), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPreferenceSheet) {
            EarnSocialPreferenceSheet(category: selectedCategory)
                .presentationDragIndicator(.visible)
        }
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(EarnSocialCategory.allCases) { category in
                    EarnSocialCategoryTabButton(
                        category: category,
                        isSelected: category == selectedCategory
                    ) {
                        withAnimation(.spareEase) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, 1)
        }
    }
}

private enum EarnSocialCategory: String, CaseIterable, Identifiable {
    case errand
    case mouthpiece
    case buddy
    case romance
    case career
    case funding
    case idle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .errand: return "跑腿"
        case .mouthpiece: return "嘴替"
        case .buddy: return "搭子"
        case .romance: return "两性"
        case .career: return "求职招聘"
        case .funding: return "投融资"
        case .idle: return "闲置"
        }
    }

    var symbol: String {
        switch self {
        case .errand: return "figure.run"
        case .mouthpiece: return "bubble.left.and.bubble.right.fill"
        case .buddy: return "person.2.fill"
        case .romance: return "heart.fill"
        case .career: return "briefcase.fill"
        case .funding: return "banknote.fill"
        case .idle: return "shippingbox.fill"
        }
    }

    var summary: String {
        switch self {
        case .errand:
            return "有人发需求，也有人接单。先看时间、地点和预算能不能对上。"
        case .mouthpiece:
            return "有人想找人代聊、代沟通，也有人愿意出面表达。"
        case .buddy:
            return "有人找搭子，有人愿意一起去。重点看节奏、兴趣和城市。"
        case .romance:
            return "有人主动认识，也有人开放接触。重点先看边界和期待。"
        case .career:
            return "有人找工作，也有人招人。核心是岗位、履历和到岗方式。"
        case .funding:
            return "有人找钱，也有人找项目。先看阶段、金额和决策窗口。"
        case .idle:
            return "有人求购，也有人求售。先看成色、价格和交易方式。"
        }
    }

    var bidirectionalHint: String {
        switch self {
        case .errand: return "双向身份：发需求 / 可接单"
        case .mouthpiece: return "双向身份：求嘴替 / 做嘴替"
        case .buddy: return "双向身份：找搭子 / 可搭"
        case .romance: return "双向身份：想认识 / 愿意聊"
        case .career: return "双向身份：找工作 / 招人"
        case .funding: return "双向身份：找钱 / 找项目"
        case .idle: return "双向身份：求购 / 求售"
        }
    }

    var chatPrompt: String {
        switch self {
        case .errand: return "时间、地点和预算"
        case .mouthpiece: return "说话边界和目标"
        case .buddy: return "时间、活动和相处节奏"
        case .romance: return "边界、期待和安全感"
        case .career: return "岗位、履历和合作方式"
        case .funding: return "阶段、金额和决策窗口"
        case .idle: return "价格、成色和交易方式"
        }
    }
}

private struct EarnSocialMockCard: Identifiable, Hashable {
    let id: String
    let category: EarnSocialCategory
    let direction: String
    let actorRole: String
    let counterpartRole: String
    let title: String
    let summary: String
    let meta: String
    let reward: String
    let tags: [String]
}

private extension EarnSocialMockCard {
    var isAgentPreChatted: Bool {
        EarnSocialMockFixtures.preChattedCardIDs.contains(id)
    }
}

private enum EarnSocialMockFixtures {
    static let preChattedCardIDs: Set<String> = [
        "errand-01", "errand-06",
        "mouthpiece-02", "mouthpiece-08",
        "buddy-01", "buddy-10",
        "romance-02", "romance-07",
        "career-01", "career-08",
        "funding-01", "funding-06",
        "idle-02", "idle-07"
    ]

    static let cards: [EarnSocialCategory: [EarnSocialMockCard]] = [
        .errand: [
            card("errand-01", .errand, "发需求", "代取方", "想找接单人", "今晚代取静安体检报告", "6 点前从医院窗口代取报告，再顺路送到静安寺地铁口。", "上海 · 今晚 18:00 前", "预算 35", ["静安", "代取", "今晚"]),
            card("errand-02", .errand, "可接单", "接单方", "想找发需求的人", "晚高峰可接文件递送", "本人电瓶车通勤，黄浦到徐汇之间可接加急文件递送。", "上海 · 工作日 17:00 后", "接单 25 起", ["加急", "文件", "黄浦"]),
            card("errand-03", .errand, "发需求", "代买方", "想找顺路代买的人", "帮买两杯少糖奶茶送到公司", "公司楼下不方便离岗，想找人顺路代买并送到前台。", "深圳 · 福田", "预算 20 + 跑腿费", ["奶茶", "办公室", "即刻"]),
            card("errand-04", .errand, "可接单", "应答方", "想找临时任务", "午休时间可接同城小任务", "中午 11:30 到 13:30 有空，可以接打印、取件、代送一类的小单。", "北京 · 朝阳", "接单 18 起", ["午休", "同城", "临时"]),
            card("errand-05", .errand, "发需求", "发单方", "想找晚上能帮忙的人", "宠物医院开药后顺路送回家", "晚上加班脱不开身，需要有人把药从宠物医院送回小区门口。", "杭州 · 拱墅", "预算 40", ["宠物", "夜间", "顺路"]),
            card("errand-06", .errand, "可接单", "接单方", "想找稳定需求", "每周可固定代排队 2 次", "熟悉几家热门店取号流程，可以固定接早高峰排队任务。", "广州 · 天河", "接单 50 起", ["排队", "固定", "熟门熟路"]),
            card("errand-07", .errand, "发需求", "代办方", "想找周末跑腿", "周末帮送一箱书到朋友家", "书比较重，车程 20 分钟，希望有人帮忙搬上楼。", "成都 · 锦江", "预算 60", ["周末", "搬运", "书籍"]),
            card("errand-08", .errand, "可接单", "应答方", "想找校园附近需求", "大学城周边可接代拿快递", "住在学校旁边，晚上都在宿舍区，可以帮忙代拿快递和送上门。", "武汉 · 洪山", "接单 10 起", ["校园", "快递", "晚上"]),
            card("errand-09", .errand, "发需求", "帮办方", "想找熟悉政务的人", "明早帮我领一份营业执照副本", "需要早上去政务窗口排队取件，我中午才能请出时间。", "苏州 · 工业园区", "预算 50", ["政务", "排队", "明早"]),
            card("errand-10", .errand, "可接单", "接单方", "想找附近长期小单", "小区周边可顺手代送晚饭", "下班固定经过 3 个小区，能接顺路送餐和小件送达。", "南京 · 建邺", "接单 12 起", ["晚饭", "顺路", "长期"])
        ],
        .mouthpiece: [
            card("mouthpiece-01", .mouthpiece, "求嘴替", "委托方", "想找代聊的人", "帮我礼貌拒绝一个不合适的合作", "对方比较热情，我不想直接生硬拒绝，想先把话说圆一点。", "远程 · 今天内", "预算 30", ["合作", "礼貌拒绝", "微信"]),
            card("mouthpiece-02", .mouthpiece, "做嘴替", "代聊方", "想找明确场景", "擅长帮人写边界感消息", "适合处理暧昧拉扯、朋友越界、同事冒犯一类需要留体面的沟通。", "远程 · 晚上可接", "接单 25 起", ["边界感", "体面", "改文案"]),
            card("mouthpiece-03", .mouthpiece, "求嘴替", "委托方", "想找情绪稳的人", "帮我跟房东谈一次续租降价", "我自己一聊就容易上头，希望有人帮我先把话术准备好。", "上海 · 远程", "预算 50", ["房租", "谈判", "续租"]),
            card("mouthpiece-04", .mouthpiece, "做嘴替", "代聊方", "想找职场沟通需求", "可代写 HR 跟进和 offer 询问", "熟悉职场沟通语气，擅长写不卑不亢的催进度消息。", "远程 · 工作日", "接单 35 起", ["HR", "offer", "催进度"]),
            card("mouthpiece-05", .mouthpiece, "求嘴替", "委托方", "想找会安抚的人", "帮我给暧昧对象发一次止损消息", "不想继续拖着，但也不希望把话说得太伤人。", "远程 · 今晚", "预算 28", ["止损", "暧昧", "降温"]),
            card("mouthpiece-06", .mouthpiece, "做嘴替", "代聊方", "想找关系修复场景", "擅长写道歉和解释消息", "适合朋友冷战、情侣误会、家人冲突后的第一条消息。", "远程 · 随时", "接单 20 起", ["道歉", "修复", "第一条"]),
            card("mouthpiece-07", .mouthpiece, "求嘴替", "委托方", "想找强势表达的人", "帮我回绝临时加班要求", "需要表达我能配合到什么程度，同时把边界说清楚。", "远程 · 工作日", "预算 32", ["加班", "边界", "老板"]),
            card("mouthpiece-08", .mouthpiece, "做嘴替", "代聊方", "想找复杂对话场景", "可陪你一起打磨三轮聊天稿", "不只是写一句话，会一起把前后话术顺一遍。", "远程 · 3 轮内", "接单 45 起", ["打磨", "三轮", "复杂对话"]),
            card("mouthpiece-09", .mouthpiece, "求嘴替", "委托方", "想找会谈价格的人", "帮我跟供应商压一次报价", "我不是很会讨价还价，希望有人给出可复制的表达。", "远程 · 今天", "预算 40", ["报价", "压价", "供应商"]),
            card("mouthpiece-10", .mouthpiece, "做嘴替", "代聊方", "想找长期委托", "适合社媒私信和商务开场", "可以提供第一句开场、第二轮跟进和礼貌收尾。", "远程 · 长期", "接单 18 起", ["私信", "商务", "开场"])
        ],
        .buddy: [
            card("buddy-01", .buddy, "找搭子", "发起方", "想找同频的人", "周六看展 + citywalk", "想找一个不赶场、愿意边走边聊的人一起看展。", "上海 · 周六下午", "AA", ["看展", "citywalk", "轻松"]),
            card("buddy-02", .buddy, "可搭", "响应方", "想找稳定搭子", "我能做晨跑搭子", "工作日 6:30 固定晨跑，节奏稳定，不会临时放鸽子。", "杭州 · 滨江", "长期", ["晨跑", "规律", "长期"]),
            card("buddy-03", .buddy, "找搭子", "发起方", "想找周中咖啡搭子", "下班后一起探店 1 小时", "只是想找人一起喝杯咖啡聊聊近况，不卷社交任务。", "广州 · 珠江新城", "AA", ["咖啡", "下班后", "放松"]),
            card("buddy-04", .buddy, "可搭", "响应方", "想找周末活动", "周末羽毛球可拼半场", "有球拍，也知道场馆订位，适合新手一起打。", "深圳 · 南山", "AA", ["羽毛球", "新手友好", "周末"]),
            card("buddy-05", .buddy, "找搭子", "发起方", "想找写作共学", "每周两次安静共写", "线上也可以，重点是一起开着摄像头写，不聊天也行。", "远程 · 周二周四", "免费", ["共学", "写作", "线上"]),
            card("buddy-06", .buddy, "可搭", "响应方", "想找同城电影搭子", "可一起看偏冷门片单", "喜欢纪录片和独立电影，不适合纯爆米花路线。", "北京 · 朝阳", "AA", ["电影", "冷门片", "同城"]),
            card("buddy-07", .buddy, "找搭子", "发起方", "想找音乐节搭子", "五一音乐节想拼住宿和出行", "希望节奏合拍，不临时变计划，能提前把预算说清楚。", "成都 · 五一", "AA", ["音乐节", "住宿", "出行"]),
            card("buddy-08", .buddy, "可搭", "响应方", "想找学习搭子", "考公晚间自习可互相打卡", "不需要互相讲题，主要是监督和稳定在线。", "武汉 · 线上/同城", "免费", ["自习", "打卡", "考公"]),
            card("buddy-09", .buddy, "找搭子", "发起方", "想找周日徒步搭子", "中低强度山线，不卷配速", "希望一起拍照、补给，不是硬核拉练。", "厦门 · 周日", "AA", ["徒步", "拍照", "低强度"]),
            card("buddy-10", .buddy, "可搭", "响应方", "想找播客搭子", "可一起逛展并录一期播客", "我负责设备和剪辑，希望对方愿意聊天和表达。", "上海 · 双休日", "共创", ["播客", "逛展", "共创"])
        ],
        .romance: [
            card("romance-01", .romance, "想认识", "主动方", "想找认真接触的人", "慢热型，希望先稳定聊两周", "不着急线下见面，先确认价值观和沟通方式。", "上海 · 认真关系", "真诚优先", ["慢热", "稳定聊", "认真"]),
            card("romance-02", .romance, "愿意聊", "回应方", "想找边界清晰的人", "可以先从日常聊天开始", "接受慢慢认识，不接受凌晨高频轰炸式聊天。", "深圳 · 两周内可聊", "边界明确", ["边界", "日常聊天", "轻压力"]),
            card("romance-03", .romance, "想认识", "主动方", "想找同城线下可能性", "希望认识愿意一起做饭的人", "不看模板式自我介绍，更看重生活节奏是否能对上。", "杭州 · 同城", "认真接触", ["做饭", "生活感", "同城"]),
            card("romance-04", .romance, "愿意聊", "回应方", "想找表达稳定的人", "接受先语音再见面", "比较在意对方是不是能持续表达，而不是一开始很热后面失踪。", "北京 · 慢慢来", "先语音", ["稳定表达", "先语音", "不消失"]),
            card("romance-05", .romance, "想认识", "主动方", "想找不敷衍的人", "下班后能认真聊半小时就很好", "期待的是温和、持续、有回应的接触感。", "广州 · 工作日晚", "认真沟通", ["下班后", "认真聊", "持续"]),
            card("romance-06", .romance, "愿意聊", "回应方", "想找尊重节奏的人", "不接受刚认识就强推见面", "更适合先交换生活方式和边界，再决定要不要往前走。", "成都 · 线上先聊", "尊重节奏", ["节奏", "边界", "线上先聊"]),
            card("romance-07", .romance, "想认识", "主动方", "想找价值观合拍的人", "先聊消费观和亲密关系观", "不需要立刻甜，但需要方向明确。", "南京 · 同城优先", "价值观对齐", ["消费观", "方向明确", "同城"]),
            card("romance-08", .romance, "愿意聊", "回应方", "想找愿意共建的人", "接受从朋友感开始升温", "希望关系是慢慢长出来的，不是靠话术堆出来的。", "苏州 · 双向选择", "朋友感", ["共建", "升温", "自然"]),
            card("romance-09", .romance, "想认识", "主动方", "想找周末可以见面的人", "如果聊得顺，愿意周末咖啡见一面", "偏好低压力场景，不想上来就是饭局考核。", "厦门 · 周末", "咖啡见面", ["低压力", "咖啡", "周末"]),
            card("romance-10", .romance, "愿意聊", "回应方", "想找有安全感的人", "可以先交换真实生活照片", "不想玩失真滤镜式人设，希望一开始就轻度真实。", "重庆 · 真诚优先", "真实交换", ["安全感", "真实", "轻度真实"])
        ],
        .career: [
            card("career-01", .career, "找工作", "候选人", "想找招聘方", "iOS 工程师想聊正式岗位", "3 年 SwiftUI + UIKit，希望先确认团队节奏和业务方向。", "上海 · 可一月内到岗", "月薪面议", ["iOS", "正式岗位", "一月内"]),
            card("career-02", .career, "招人", "招聘方", "想找候选人", "招增长产品经理，偏内容社区", "希望候选人有 0 到 1 起盘经验，能接受小团队快节奏。", "北京 · 全职", "预算 25-35K", ["产品经理", "内容社区", "全职"]),
            card("career-03", .career, "找工作", "候选人", "想找远程机会", "后端工程师希望先看协作方式", "熟悉 Go 和微服务，希望团队文档和评审比较成熟。", "远程 · 即刻可聊", "薪资面议", ["Go", "远程", "协作"]),
            card("career-04", .career, "招人", "招聘方", "想找设计师", "招品牌设计，偏消费品视觉", "希望有人做过包装或电商视觉，不只是纯海报输出。", "广州 · 全职/合作", "预算 18-25K", ["品牌设计", "消费品", "视觉"]),
            card("career-05", .career, "找工作", "候选人", "想找兼职项目", "前端开发可接中短期外包", "更适合营销页、品牌官网、小程序前台项目。", "远程 · 两周内", "按项目报价", ["前端", "外包", "中短期"]),
            card("career-06", .career, "招人", "招聘方", "想找运营", "短视频账号招兼职脚本运营", "希望能写选题、拆结构，也能跟剪辑对一下方向。", "深圳 · 兼职", "时薪 80 起", ["短视频", "脚本", "兼职"]),
            card("career-07", .career, "找工作", "候选人", "想找更稳定团队", "测试工程师想换到业务清晰的团队", "偏功能测试和流程设计，想先看是不是长期岗位。", "杭州 · 同城优先", "薪资面议", ["测试", "稳定", "长期"]),
            card("career-08", .career, "招人", "招聘方", "想找销售", "ToB SaaS 招售前顾问", "需要能做需求梳理、演示支持和客户跟进。", "成都 · 全职", "预算 15-25K + 提成", ["售前", "SaaS", "ToB"]),
            card("career-09", .career, "找工作", "候选人", "想找转岗机会", "内容运营希望转用户研究", "需要有人愿意先聊 transferable skills 和试用方式。", "北京 · 可实习过渡", "薪资面议", ["转岗", "用户研究", "内容运营"]),
            card("career-10", .career, "招人", "招聘方", "想找工程顾问", "创业团队找兼职技术顾问", "每周固定看一次方案，给架构和节奏建议。", "远程 · 长期兼职", "月顾问费", ["顾问", "架构", "创业团队"])
        ],
        .funding: [
            card("funding-01", .funding, "找钱", "项目方", "想找投资人", "AI 工具项目想聊天使轮", "已有早期付费用户，想找懂效率工具和 ToC 的投资人。", "远程/上海", "目标 300 万", ["AI 工具", "天使轮", "付费用户"]),
            card("funding-02", .funding, "找项目", "投资方", "想找项目方", "看早期消费品牌项目", "更关心复购、单店模型和创始人执行力。", "远程 · 本月看项目", "单笔 100-300 万", ["消费品牌", "早期", "复购"]),
            card("funding-03", .funding, "找钱", "项目方", "想找懂 SaaS 的钱", "企业服务产品想聊 Pre-A", "团队来自行业一线，已经有 8 家付费 B 端客户。", "北京/远程", "目标 800 万", ["企业服务", "Pre-A", "B 端"]),
            card("funding-04", .funding, "找项目", "投资方", "想看硬科技团队", "关注机器人和智能制造方向", "可以接受长周期，但需要技术壁垒真实。", "深圳 · 季度内", "单笔 500 万起", ["机器人", "硬科技", "制造"]),
            card("funding-05", .funding, "找钱", "项目方", "想找产业资源型投资人", "跨境电商工具想换资源型股东", "需要的不只是钱，更希望带渠道和供应链资源。", "杭州 · 可见面", "目标 500 万", ["跨境", "资源型", "供应链"]),
            card("funding-06", .funding, "找项目", "投资方", "想找有现金流的项目", "看教育和职业培训方向", "偏好已经跑出小规模现金流、不是纯故事。", "上海 · 本季度", "单笔 200 万起", ["教育", "现金流", "职业培训"]),
            card("funding-07", .funding, "找钱", "项目方", "想找愿意陪跑的 FA", "想先找能打磨材料和结构的人", "BP 基本有了，但故事线还不够清楚。", "远程 · 两周内", "顾问费 + success fee", ["FA", "BP", "陪跑"]),
            card("funding-08", .funding, "找项目", "投资方", "想看文娱内容项目", "看有 IP 潜力和社群基础的内容品牌", "更看重内容效率和用户粘性，不急着规模化。", "远程 · 持续看", "单笔 50-150 万", ["文娱", "内容品牌", "IP"]),
            card("funding-09", .funding, "找钱", "项目方", "想找第一张机构支票", "健康食品品牌想从个人投资转机构投资", "已有稳定复购，希望资金用于放大渠道。", "广州 · 可路演", "目标 200 万", ["健康食品", "机构支票", "渠道"]),
            card("funding-10", .funding, "找项目", "投资方", "想找女性消费项目", "关注女性健康、情绪、关系类产品", "需要项目表达清楚用户增长与长期复购。", "远程 · 本月", "单笔 100-200 万", ["女性消费", "健康", "复购"])
        ],
        .idle: [
            card("idle-01", .idle, "求购", "买家", "想找卖家", "求一台 9 成新 Kindle Oasis", "偏好带原装壳和充电线，预算可以商量。", "上海 · 同城优先", "预算 900", ["Kindle", "同城", "原装"]),
            card("idle-02", .idle, "求售", "卖家", "想找买家", "出 95 新 AirPods Pro 2", "买来三个月，盒子和小票都在，支持验货。", "北京 · 可面交", "售价 1150", ["AirPods", "验货", "面交"]),
            card("idle-03", .idle, "求购", "买家", "想找稳定卖家", "求二手人体工学椅", "最好在 1500 以内，希望椅背和升降都正常。", "深圳 · 南山", "预算 1500", ["工学椅", "二手", "正常升降"]),
            card("idle-04", .idle, "求售", "卖家", "想找识货买家", "出 8 成新索尼相机镜头", "功能正常，无磕碰，适合入门人像拍摄。", "广州 · 可邮寄", "售价 1800", ["索尼", "镜头", "邮寄"]),
            card("idle-05", .idle, "求购", "买家", "想找女生衣柜清仓", "求购春夏通勤西装外套", "偏好基础色和轻薄材质，能接受轻微使用痕迹。", "杭州 · 同城/邮寄", "预算 200 内", ["通勤", "西装", "女生"]),
            card("idle-06", .idle, "求售", "卖家", "想找同城面交", "出 9 成新米家投影仪", "家里升级设备，原盒还在，可现场试机。", "成都 · 面交优先", "售价 1600", ["投影仪", "试机", "原盒"]),
            card("idle-07", .idle, "求购", "买家", "想找靠谱卖家", "求 Mac mini M2 基础版", "只要国行和正常使用机，面交最好。", "南京 · 面交", "预算 2500", ["Mac mini", "国行", "正常使用"]),
            card("idle-08", .idle, "求售", "卖家", "想找学生买家", "出考研全套英语资料", "标注比较全，适合二战或基础薄弱的人。", "武汉 · 校园周边", "售价 120", ["考研", "英语", "资料"]),
            card("idle-09", .idle, "求购", "买家", "想找带发票的卖家", "求二手显示器 24 寸左右", "主要办公用，希望屏幕无坏点，支架稳定。", "苏州 · 同城", "预算 500", ["显示器", "办公", "无坏点"]),
            card("idle-10", .idle, "求售", "卖家", "想找爽快买家", "出闲置咖啡机一台", "买来后使用不多，适合想入门手冲和意式的人。", "厦门 · 同城/邮寄", "售价 680", ["咖啡机", "入门", "闲置"])
        ]
    ]

    private static func card(
        _ id: String,
        _ category: EarnSocialCategory,
        _ direction: String,
        _ actorRole: String,
        _ counterpartRole: String,
        _ title: String,
        _ summary: String,
        _ meta: String,
        _ reward: String,
        _ tags: [String]
    ) -> EarnSocialMockCard {
        EarnSocialMockCard(
            id: id,
            category: category,
            direction: direction,
            actorRole: actorRole,
            counterpartRole: counterpartRole,
            title: title,
            summary: summary,
            meta: meta,
            reward: reward,
            tags: tags
        )
    }
}

private struct EarnSocialCategoryTabButton: View {
    let category: EarnSocialCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: category.symbol)
                    .font(.system(size: 13, weight: .semibold))
                Text(category.title)
                    .font(.spareCaptionSB)
            }
            .foregroundColor(.spareDark)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? Color.spareYellow : Color.white)
            )
            .overlay(
                Capsule()
                    .stroke(Color.spareYellow.opacity(isSelected ? 0.55 : 0.20), lineWidth: 1)
            )
            .shadow(
                color: Color.spareYellow.opacity(isSelected ? 0.16 : 0.06),
                radius: isSelected ? 8 : 4,
                y: 2
            )
        }
        .buttonStyle(.plain)
    }
}

private struct EarnSocialPreferenceSheet: View {
    let category: EarnSocialCategory

    @Environment(\.dismiss) private var dismiss

    private var preferenceTags: [String] {
        switch category {
        case .errand:
            return ["同城优先", "预算明确", "晚上可聊", "只看已代聊"]
        case .mouthpiece:
            return ["边界清楚", "语气体面", "可三轮打磨", "只看已代聊"]
        case .buddy:
            return ["同城优先", "周末可约", "节奏稳定", "只看已代聊"]
        case .romance:
            return ["认真接触", "先聊边界", "慢热可接受", "只看已代聊"]
        case .career:
            return ["岗位明确", "先看合作方式", "远程可聊", "只看已代聊"]
        case .funding:
            return ["阶段清楚", "金额明确", "决策窗口短", "只看已代聊"]
        case .idle:
            return ["同城优先", "价格明确", "支持验货", "只看已代聊"]
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("我的偏好")
                    .font(.spareTitle2)

                Text("这些只是当前 \(category.title) 的 mock 偏好。带“分身已代聊”的卡片表示系统已经帮你先聊过一轮。")
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                FlexiblePreferenceFlow(tags: preferenceTags)

                Spacer()
            }
            .padding(Spacing.lg)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("我的偏好")
            .spareNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .spareNavigationLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct FlexiblePreferenceFlow: View {
    let tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(chunked(tags, size: 2), id: \.self) { row in
                HStack(spacing: Spacing.sm) {
                    ForEach(row, id: \.self) { tag in
                        Text(tag)
                            .font(.spareCaptionSB)
                            .foregroundColor(.spareDark)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .background(Color.white, in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.spareYellow.opacity(0.22), lineWidth: 1)
                            )
                    }
                    Spacer()
                }
            }
        }
    }
}

private struct EarnSocialMockCardView: View {
    let card: EarnSocialMockCard
    let openChat: () -> Void

    var body: some View {
        Button(action: openChat) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                    .fill(Color.white)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        HStack(spacing: Spacing.xs) {
                            EarnSocialPill(label: card.direction, filled: true)
                            if card.isAgentPreChatted {
                                EarnSocialStatePill(label: "分身已代聊")
                            }
                        }

                        Spacer()

                        Text(card.reward)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.spareDark)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.spareYellowLight, in: Capsule())
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(card.title)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.spareDark)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Text("\(card.actorRole) · 面向 \(card.counterpartRole)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        Text(card.summary)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.secondary)
                            .lineSpacing(1)
                            .lineLimit(3)
                    }

                    EarnSocialMetaBlock(text: card.meta)

                    HStack(spacing: Spacing.xs) {
                        ForEach(Array(card.tags.prefix(3)), id: \.self) { tag in
                            EarnSocialPill(label: tag)
                        }
                    }

                    Spacer(minLength: 0)

                    Rectangle()
                        .fill(Color.spareYellow.opacity(0.14))
                        .frame(height: 1)

                    HStack {
                        Label(card.isAgentPreChatted ? "查看代聊后继续聊" : "打开聊天", systemImage: "message.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.spareDark)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
            }
            .aspectRatio(5.0 / 8.0, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                    .stroke(Color.spareYellow.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: Color.spareYellow.opacity(0.10), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}

private struct EarnSocialPill: View {
    let label: String
    var filled: Bool = false

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.spareDark)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(filled ? Color.spareYellow : Color.spareYellowLight.opacity(0.45))
            )
            .overlay(
                Capsule()
                    .stroke(Color.spareYellow.opacity(filled ? 0.45 : 0.18), lineWidth: 1)
            )
    }
}

private struct EarnSocialStatePill: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color(.systemGray6), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
    }
}

private struct EarnSocialMetaBlock: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("场景信息")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)

            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.spareDark)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                .fill(Color.spareYellow.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                .stroke(Color.spareYellow.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct EarnSocialMockChatView: View {
    let card: EarnSocialMockCard

    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""
    @State private var messages: [EarnSocialChatMessage]

    init(card: EarnSocialMockCard) {
        self.card = card
        _messages = State(initialValue: EarnSocialChatMessage.seed(for: card))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        chatHeader

                        ForEach(messages) { message in
                            EarnSocialChatBubble(message: message)
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, Spacing.xxxl)
                }

                composer
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(card.category.title)
            .spareNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .spareNavigationLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var chatHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                EarnSocialPill(label: card.direction, filled: true)
                if card.isAgentPreChatted {
                    EarnSocialStatePill(label: "分身已代聊")
                }
            }

            Text(card.title)
                .font(.spareTitle3)

            Text("先把 \(card.category.chatPrompt) 说清楚，再决定要不要继续往下聊。")
                .font(.spareCaption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.lg)
        .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                .stroke(Color.spareYellow.opacity(0.22), lineWidth: 1)
        )
    }

    private var composer: some View {
        HStack(spacing: Spacing.sm) {
            TextField("输入消息", text: $draft)
                .font(.spareBody)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)
                .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                        .stroke(Color.spareYellow.opacity(0.18), lineWidth: 1)
                )

            Button("发送") {
                sendDraft()
            }
            .font(.spareCaptionSB)
            .foregroundColor(.spareDark)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(Color.spareYellow, in: Capsule())
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.lg)
        .background(Color.white.opacity(0.96))
    }

    private func sendDraft() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        withAnimation(.spareEase) {
            messages.append(
                EarnSocialChatMessage(sender: .me, text: trimmed)
            )
            messages.append(
                EarnSocialChatMessage(
                    sender: .other,
                    text: "收到。我这边更想先确认 \(card.category.chatPrompt)，如果这些能对上，我们再继续。"
                )
            )
        }

        draft = ""
    }
}

private struct EarnSocialChatMessage: Identifiable, Hashable {
    enum Sender {
        case me
        case other
    }

    let id = UUID()
    let sender: Sender
    let text: String

    static func seed(for card: EarnSocialMockCard) -> [EarnSocialChatMessage] {
        var messages: [EarnSocialChatMessage] = []

        if card.isAgentPreChatted {
            messages.append(
                EarnSocialChatMessage(
                    sender: .other,
                    text: "这张卡片已经由分身先代聊过一轮，基础条件大致对齐。"
                )
            )
        }

        messages.append(
            EarnSocialChatMessage(
                sender: .other,
                text: "你好，我这边发的是「\(card.direction)」卡片。"
            )
        )
        messages.append(
            EarnSocialChatMessage(
                sender: .other,
                text: card.summary
            )
        )
        messages.append(
            EarnSocialChatMessage(
                sender: .me,
                text: "我对这个方向有兴趣，想先确认一下 \(card.category.chatPrompt)。"
            )
        )

        return messages
    }
}

private struct EarnSocialChatBubble: View {
    let message: EarnSocialChatMessage

    var body: some View {
        HStack {
            if message.sender == .me { Spacer(minLength: 40) }

            Text(message.text)
                .font(.spareBody)
                .foregroundColor(.spareDark)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)
                .background(
                    message.sender == .me ? Color.spareYellow : Color.white,
                    in: RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                        .stroke(Color.spareYellow.opacity(0.18), lineWidth: 1)
                )

            if message.sender == .other { Spacer(minLength: 40) }
        }
    }
}

private func chunked<T>(_ array: [T], size: Int) -> [[T]] {
    guard size > 0 else { return [array] }
    var result: [[T]] = []
    var index = 0

    while index < array.count {
        let end = min(index + size, array.count)
        result.append(Array(array[index..<end]))
        index += size
    }

    return result
}
