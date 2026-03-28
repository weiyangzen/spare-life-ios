import SwiftUI

struct EarnSocialHoldingView: View {
    var body: some View {
        StageHoldingView(
            icon: "bolt.circle.fill",
            title: "赚闲能",
            subtitle: "Stage 1 暂时留空，但保留未来赛道、收益和陌生协作的设计位置。",
            accent: .spareYellow,
            gradient: [Color(red: 1.0, green: 0.94, blue: 0.78), Color(red: 1.0, green: 0.98, blue: 0.92)],
            cards: [
                ("赛道入口", "后续会放六条赛道入口、奖励和热点。"),
                ("任务收益", "这里会展示闲能余额、进行中任务和到账记录。"),
                ("协作破冰", "未来放 A2A 破冰、竞技场和行动卡。")
            ]
        )
    }
}

struct MessagesHoldingView: View {
    var body: some View {
        StageHoldingView(
            icon: "message.fill",
            title: "消息",
            subtitle: "Stage 1 暂时留空，但会保留为后续 IM、群聊和跨会话承接页。",
            accent: .blue,
            gradient: [Color(red: 0.88, green: 0.94, blue: 1.0), Color(red: 0.95, green: 0.98, blue: 1.0)],
            cards: [
                ("最近会话", "后面会把主 IM 列表和未读入口挂在这里。"),
                ("系统通知", "大师闲聊、任务进度和协作提醒会集中收口。"),
                ("跨页面承接", "这里会成为从其他 tab 回流后的统一消息中心。")
            ]
        )
    }
}

struct MyProfileHoldingView: View {
    var body: some View {
        StageHoldingView(
            icon: "person.crop.circle.fill",
            title: "我的",
            subtitle: "Stage 1 暂时留空，但会保留为分身资料、隐私和成长记录的主入口。",
            accent: .emotionPositive,
            gradient: [Color(red: 0.89, green: 0.98, blue: 0.92), Color(red: 0.96, green: 1.0, blue: 0.97)],
            cards: [
                ("我的资料", "后续会挂个人资料、分身状态和对外展示信息。"),
                ("隐私授权", "长期记忆、同步和本地数据权限会放在这里。"),
                ("成长记录", "后面接成长、统计和阶段总结。")
            ]
        )
    }
}

private struct StageHoldingView: View {
    let icon: String
    let title: String
    let subtitle: String
    let accent: Color
    let gradient: [Color]
    let cards: [(String, String)]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        hero

                        ForEach(Array(cards.enumerated()), id: \.offset) { _, card in
                            holdingCard(title: card.0, detail: card.1)
                        }

                        holdingFooter
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, Spacing.xxxl)
                }
            }
            .spareNavigationBarHidden(true)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.16))
                        .frame(width: 56, height: 56)
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.spareTitle1)
                    Text("暂时留空")
                        .font(.spareCaptionSB)
                        .foregroundColor(.secondary)
                }
            }

            Text(subtitle)
                .font(.spareBody)
                .foregroundColor(.secondary)

            HStack(spacing: Spacing.sm) {
                PillTag(label: "Stage 1", color: accent, filled: true)
                PillTag(label: "有设计占位", color: .secondary)
                PillTag(label: "后续可直接接功能", color: .secondary)
            }
        }
        .padding(Spacing.xl)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: CornerRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
        .cardShadow(prominent: true)
    }

    private func holdingCard(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(title)
                    .font(.spareTitle3)
                Spacer()
                Image(systemName: "circle.dashed")
                    .foregroundColor(accent)
            }

            Text(detail)
                .font(.spareCaption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
    }

    private var holdingFooter: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "sparkles")
                .foregroundColor(accent)
            Text("这个页面现在只保留布局锚点，后续功能接回时不会再重做导航结构。")
                .font(.spareCaption)
                .foregroundColor(.secondary)
        }
        .padding(.top, Spacing.sm)
    }
}
