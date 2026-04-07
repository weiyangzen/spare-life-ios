import SwiftUI

@MainActor
final class ChatThreadStore: ObservableObject {
    let thread: ConversationThread

    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var agentMessages: [ChatMessage] = []
    @Published private(set) var isLoading = true
    @Published var showAgentPanel = false
    @Published var draftText = ""
    @Published var sendMode: ChatSendMode = .human

    init(thread: ConversationThread) {
        self.thread = thread
    }

    func load() {
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            self.messages = Self.mockMessages(thread: thread)
            self.agentMessages = Self.mockAgentMessages(thread: thread)
            self.isLoading = false
        }
    }

    func send() {
        guard !draftText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let senderRole = sendMode.senderRole
        let msg = ChatMessage(
            id: UUID().uuidString,
            senderRole: senderRole,
            senderName: senderRole.displayName,
            content: draftText,
            timestamp: Date(),
            isAgentThread: false
        )
        withAnimation(.spareEase) {
            messages.append(msg)
        }
        draftText = ""
    }

    private static func mockMessages(thread: ConversationThread) -> [ChatMessage] {
        let now = Date()

        switch thread.id {
        case "t1":
            return [
                ChatMessage(id: "m1", senderRole: .theirHuman, senderName: "Dubi",
                            content: "我刚出门，十分钟内能到那家咖啡馆。", timestamp: now - 3600,
                            isAgentThread: false),
                ChatMessage(id: "m2", senderRole: .myHuman, senderName: "我",
                            content: "好，我也在路上，今天还是坐窗边吧。", timestamp: now - 3300,
                            isAgentThread: false),
                ChatMessage(id: "m3", senderRole: .theirHuman, senderName: "Dubi",
                            content: "可以，我记得你上次说下午那边的光线最好。", timestamp: now - 3000,
                            isAgentThread: false),
                ChatMessage(id: "m4", senderRole: .myHuman, senderName: "我",
                            content: "对，顺便帮我点一杯热美式。", timestamp: now - 1200,
                            isAgentThread: false),
                ChatMessage(id: "m5", senderRole: .theirHuman, senderName: "Dubi",
                            content: "没问题，我到了就先帮你点。", timestamp: now - 720,
                            isAgentThread: false),
                ChatMessage(id: "m6", senderRole: .theirHuman, senderName: "Dubi",
                            content: "那我先去占窗边的位置。", timestamp: now - 300,
                            isAgentThread: false),
            ]

        case "t2":
            return [
                ChatMessage(id: "m1", senderRole: .theirHuman, senderName: "Sophie",
                            content: "今晚那个展我看了一下，7 点以后人会少一点。", timestamp: now - 5400,
                            isAgentThread: false),
                ChatMessage(id: "m2", senderRole: .myHuman, senderName: "我",
                            content: "那正好，我 6 点半下班，过去差不多。", timestamp: now - 5000,
                            isAgentThread: false),
                ChatMessage(id: "m3", senderRole: .myPersona, senderName: "我的分身",
                            content: "按照你们之前的偏好，先看摄影单元再看装置单元会更顺。", timestamp: now - 4600,
                            isAgentThread: false),
                ChatMessage(id: "m4", senderRole: .theirHuman, senderName: "Sophie",
                            content: "好，那我就不自己乱绕了。", timestamp: now - 4300,
                            isAgentThread: false),
                ChatMessage(id: "m5", senderRole: .myHuman, senderName: "我",
                            content: "我本来想自己做路线，你要是已经顺手了也行。", timestamp: now - 2200,
                            isAgentThread: false),
                ChatMessage(id: "m6", senderRole: .theirHuman, senderName: "Sophie",
                            content: "我让分身先把今晚的路线发你。", timestamp: now - 1800,
                            isAgentThread: false),
            ]

        case "t3":
            return [
                ChatMessage(id: "m1", senderRole: .theirHuman, senderName: "Omar",
                            content: "周五那场桌游局还继续吗？我这边可以早点去。", timestamp: now - 7200,
                            isAgentThread: false),
                ChatMessage(id: "m2", senderRole: .myHuman, senderName: "我",
                            content: "继续，我负责把清单再过一遍。", timestamp: now - 6800,
                            isAgentThread: false),
                ChatMessage(id: "m3", senderRole: .theirHuman, senderName: "Aris",
                            content: "投影和音箱我都能带。", timestamp: now - 6300,
                            isAgentThread: false),
                ChatMessage(id: "m4", senderRole: .theirHuman, senderName: "Omar",
                            content: "那我去问问老地方明晚还能不能留给我们。", timestamp: now - 4200,
                            isAgentThread: false),
                ChatMessage(id: "m5", senderRole: .myHuman, senderName: "我",
                            content: "如果能留就还是老地方，省得大家重新找。", timestamp: now - 3900,
                            isAgentThread: false),
                ChatMessage(id: "m6", senderRole: .theirHuman, senderName: "Aris",
                            content: "明晚先把场地定下来？", timestamp: now - 3600,
                            isAgentThread: false),
            ]

        case "t4":
            return [
                ChatMessage(id: "m1", senderRole: .myHuman, senderName: "我",
                            content: "昨晚提到的那几本书，你要不要我帮你整理成一个顺序？", timestamp: now - 9600,
                            isAgentThread: false),
                ChatMessage(id: "m2", senderRole: .theirHuman, senderName: "Mia",
                            content: "要，我怕自己回头就记混了。", timestamp: now - 9300,
                            isAgentThread: false),
                ChatMessage(id: "m3", senderRole: .myHuman, senderName: "我",
                            content: "我先列了三本最适合入门的，晚上发你。", timestamp: now - 9000,
                            isAgentThread: false),
                ChatMessage(id: "m4", senderRole: .theirHuman, senderName: "Mia",
                            content: "好，我开个共享文档，你直接往里补。", timestamp: now - 8700,
                            isAgentThread: false),
                ChatMessage(id: "m5", senderRole: .myHuman, senderName: "我",
                            content: "你补完告诉我，下周我们就按那个顺序聊。", timestamp: now - 7600,
                            isAgentThread: false),
                ChatMessage(id: "m6", senderRole: .theirHuman, senderName: "Mia",
                            content: "我把那份书单补在共享文档里了。", timestamp: now - 7200,
                            isAgentThread: false),
            ]

        case "t5":
            return [
                ChatMessage(id: "m1", senderRole: .myHuman, senderName: "我",
                            content: "Hannah，我今天事情有点乱，帮我顺一下优先级。", timestamp: now - 87200,
                            isAgentThread: false),
                ChatMessage(id: "m2", senderRole: .theirPersona, senderName: "Hannah",
                            content: "可以，你先告诉我哪些事今天必须完成。", timestamp: now - 87000,
                            isAgentThread: false),
                ChatMessage(id: "m3", senderRole: .myHuman, senderName: "我",
                            content: "产品稿、给 Dubi 回消息、还有明早的周会准备。", timestamp: now - 86800,
                            isAgentThread: false),
                ChatMessage(id: "m4", senderRole: .theirPersona, senderName: "Hannah",
                            content: "收到，我先按截止时间和切换成本帮你拆开。", timestamp: now - 86600,
                            isAgentThread: false),
                ChatMessage(id: "m5", senderRole: .myHuman, senderName: "我",
                            content: "顺便帮我留一段晚上复盘时间。", timestamp: now - 86500,
                            isAgentThread: false),
                ChatMessage(id: "m6", senderRole: .theirPersona, senderName: "Hannah",
                            content: "我已经把你的待办拆成 3 个优先级。", timestamp: now - 86400,
                            isAgentThread: false),
            ]

        default:
            return [
                ChatMessage(id: "m1", senderRole: .theirHuman, senderName: thread.contactName,
                            content: thread.lastMessage, timestamp: now - 300,
                            isAgentThread: false)
            ]
        }
    }

    private static func mockAgentMessages(thread: ConversationThread) -> [ChatMessage] {
        let now = Date()

        switch thread.id {
        case "t1":
            return [
                ChatMessage(id: "a1", senderRole: .myPersona, senderName: "你的分身",
                            content: "Dubi 已经先到店里，当前话题适合延续轻松见面节奏。",
                            timestamp: now - 260, isAgentThread: true),
                ChatMessage(id: "a2", senderRole: .agentHelper, senderName: "Agent 助手",
                            content: "建议你到场后先接 Dubi 的“窗边位置”话题，再自然转去今天的安排。",
                            timestamp: now - 220, isAgentThread: true),
            ]

        case "t2":
            return [
                ChatMessage(id: "a1", senderRole: .myPersona, senderName: "你的分身",
                            content: "我已根据你和 Sophie 的路线偏好整理出一条 90 分钟观展顺序。",
                            timestamp: now - 1200, isAgentThread: true),
                ChatMessage(id: "a2", senderRole: .agentHelper, senderName: "Agent 助手",
                            content: "当前更适合把路线作为附件发出，不必在主线程里解释太多细节。",
                            timestamp: now - 900, isAgentThread: true),
            ]

        case "t3":
            return [
                ChatMessage(id: "a1", senderRole: .agentHelper, senderName: "Agent 助手",
                            content: "群里当前共识是先定场地，再确认设备和到场时间。",
                            timestamp: now - 3000, isAgentThread: true),
                ChatMessage(id: "a2", senderRole: .agentHelper, senderName: "Agent 助手",
                            content: "如果你要回，可以直接确认“老地方可行就锁定”。",
                            timestamp: now - 2500, isAgentThread: true),
            ]

        case "t4":
            return [
                ChatMessage(id: "a1", senderRole: .myPersona, senderName: "你的分身",
                            content: "Mia 刚补完书单，下一轮对话可以直接切到第一本书的讨论。",
                            timestamp: now - 6800, isAgentThread: true),
                ChatMessage(id: "a2", senderRole: .agentHelper, senderName: "Agent 助手",
                            content: "建议开场问题：为什么她把第一本放在最前面。",
                            timestamp: now - 6500, isAgentThread: true),
            ]

        case "t5":
            return [
                ChatMessage(id: "a1", senderRole: .theirPersona, senderName: "Hannah",
                            content: "高优先级：产品稿；中优先级：周会准备；低优先级：整理回复消息。",
                            timestamp: now - 5400, isAgentThread: true),
                ChatMessage(id: "a2", senderRole: .agentHelper, senderName: "Agent 助手",
                            content: "今晚 21:30 之后预留 20 分钟复盘，会比现在插入更稳。",
                            timestamp: now - 5000, isAgentThread: true),
            ]

        default:
            return []
        }
    }
}
