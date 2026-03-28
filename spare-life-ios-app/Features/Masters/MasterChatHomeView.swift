import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit) && !canImport(UIKit)
import AppKit
#endif

private let masterStage1CardAspectRatio: CGFloat = 5.0 / 8.0

struct MasterChatHomeView: View {
    @StateObject private var store: MasterExperienceStore

    @MainActor
    init() {
        _store = StateObject(wrappedValue: MasterExperienceStore())
    }

    @MainActor
    init(store: MasterExperienceStore) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.spareYellowWash,
                        Color.white,
                        Color(.systemGroupedBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    filterBar
                    feedBody
                }
            }
            .spareNavigationBarHidden(true)
            .navigationDestination(isPresented: conversationDestinationBinding) {
                MasterConversationView(store: store)
            }
            .task {
                store.loadIfNeeded()
            }
            .onChange(of: store.query) { _ in
                store.resetDirectoryPagination()
            }
            .onChange(of: store.selectedDomainID) { _ in
                store.resetDirectoryPagination()
            }
        }
    }

    private var conversationDestinationBinding: Binding<Bool> {
        Binding(
            get: { store.conversation != nil },
            set: { isPresented in
                if !isPresented {
                    store.conversation = nil
                }
            }
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("和大师闲聊")
                    .font(.spareTitle1)
                    .foregroundColor(.primary)

                Text("先看卡片，再进入一对一闲聊。当前目录会把已接入的本地大师资源完整刷出来。")
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: Spacing.sm) {
                statusChip(
                    icon: "person.2.crop.square.stack.fill",
                    title: "\(store.visibleDirectoryMasters.count)",
                    subtitle: "当前可见"
                )
                statusChip(
                    icon: "books.vertical.fill",
                    title: "\(store.masters.count)",
                    subtitle: "已装载大师"
                )
                statusChip(
                    icon: "checkmark.seal.fill",
                    title: store.resourceMappingSummary,
                    subtitle: store.catalogCoverage?.indexCoverageSummary ?? "目录校验中"
                )
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.md)
    }

    private func statusChip(icon: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.spareYellow)
            Text(title)
                .font(.spareCaptionSB)
                .foregroundColor(.primary)
                .lineLimit(1)
            Text(subtitle)
                .font(.spareMicro)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
    }

    private var filterBar: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索大师、领域或关键词", text: $store.query)
                    .font(.spareBody)
                if !store.query.isEmpty {
                    Button {
                        store.query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Spacing.md)
            .background(Color.white.opacity(0.84), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .stroke(Color.cardStroke, lineWidth: 1)
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    directoryChip(title: "全部", symbol: "square.grid.2x2.fill", isSelected: store.selectedDomainID == nil) {
                        withAnimation(.spareFast) {
                            store.selectedDomainID = nil
                        }
                    }

                    ForEach(store.domains) { domain in
                        directoryChip(title: domain.title, symbol: domain.symbol, isSelected: store.selectedDomainID == domain.id) {
                            withAnimation(.spareFast) {
                                store.selectedDomainID = domain.id
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.md)
    }

    private func directoryChip(title: String, symbol: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(.spareCaption)
            }
            .foregroundColor(isSelected ? .spareDark : .primary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? Color.spareYellow : Color.white.opacity(0.88))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.spareYellow : Color.cardStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var feedBody: some View {
        if store.isLoading {
            WaterfallSkeleton(count: 8)
        } else if let error = store.fatalErrorMessage {
            ScrollView {
                ErrorStateView(
                    message: error,
                    retry: { Task { await store.refreshCatalog() } }
                )
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.xxxl)
            }
        } else if store.directoryMasters.isEmpty {
            ScrollView {
                EmptyStateView(
                    icon: "person.crop.rectangle.stack",
                    title: "暂时没有可闲聊的大师",
                    message: "试试清空筛选，或者等本地资源目录更新后再来。",
                    actionLabel: "清空筛选",
                    action: {
                        store.query = ""
                        store.selectedDomainID = nil
                    }
                )
                .padding(.top, Spacing.xxxl)
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    FeedSectionHeader(
                        title: "大师卡片",
                        subtitle: store.hasMoreDirectoryMastersToLoad
                            ? "\(store.visibleDirectoryMasters.count)/\(store.directoryMasters.count) 位，继续下滑会自动加载"
                            : "\(store.visibleDirectoryMasters.count) 位已全部展开"
                    )
                    .padding(.horizontal, Spacing.lg)

                    GeometryReader { proxy in
                        WaterfallLayout(columns: WaterfallColumns.count(for: proxy.size.width), spacing: Spacing.md) {
                            ForEach(store.visibleDirectoryMasters) { profile in
                                MasterStage1Card(profile: profile) {
                                    store.openConversation(for: profile)
                                }
                                .onAppear {
                                    store.loadNextDirectoryBatchIfNeeded(after: profile)
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.lg)
                    }
                    .frame(minHeight: CGFloat(max(store.visibleDirectoryMasters.count / 2 + 1, 1)) * 242)

                    if store.hasMoreDirectoryMastersToLoad {
                        HStack(spacing: Spacing.sm) {
                            ProgressView()
                            Text("继续加载更多大师…")
                                .font(.spareCaption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, Spacing.xl)
                    }
                }
                .padding(.top, Spacing.xs)
                .padding(.bottom, Spacing.xxxl)
            }
            .refreshable {
                await store.refreshCatalog()
            }
        }
    }
}

private struct MasterStage1Card: View {
    let profile: MasterProfile
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ZStack(alignment: .bottomLeading) {
                    MasterStage1ImageView(path: profile.imageSet.backgroundPath)
                        .frame(height: 136)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                        .overlay(
                            LinearGradient(
                                colors: [Color.black.opacity(0.03), Color.black.opacity(0.58)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                        )

                    HStack(alignment: .bottom, spacing: Spacing.sm) {
                        MasterStage1ImageView(path: profile.imageSet.avatarPath)
                            .frame(width: 46, height: 46)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.92), lineWidth: 2)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.displayName)
                                .font(.spareBodySB)
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text(profile.title)
                                .font(.spareMicro)
                                .foregroundColor(.white.opacity(0.84))
                                .lineLimit(1)
                        }
                    }
                    .padding(Spacing.md)
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xs) {
                        PillTag(label: profile.domainTitle, color: .spareYellow, filled: true)
                        Spacer()
                        Image(systemName: "arrow.up.right.circle.fill")
                            .foregroundColor(.spareYellow)
                    }

                    Text(profile.tagline)
                        .font(.spareCaptionSB)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Text(profile.promptPreview)
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    FlowLayoutRow(tags: Array(profile.expertiseTags.prefix(3)))

                    Label("进入一对一闲聊", systemImage: "bubble.left.and.bubble.right.fill")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(Color.cardStroke, lineWidth: 1)
            )
            .aspectRatio(masterStage1CardAspectRatio, contentMode: .fit)
            .contentShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .cardShadow()
        }
        .buttonStyle(CardPressStyle())
        .accessibilityIdentifier("master-stage1-card-\(profile.id)")
    }
}

private struct FlowLayoutRow: View {
    let tags: [String]

    var body: some View {
        if tags.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: Spacing.xs) {
                ForEach(tags, id: \.self) { tag in
                    PillTag(label: tag, color: .secondary)
                }
            }
        }
    }
}

private enum MasterStage1ImageLoader {
    static func image(at path: String) -> Image? {
        #if canImport(UIKit)
        guard let image = UIImage(contentsOfFile: path) else { return nil }
        return Image(uiImage: image)
        #elseif canImport(AppKit) && !canImport(UIKit)
        guard let image = NSImage(contentsOfFile: path) else { return nil }
        return Image(nsImage: image)
        #else
        return nil
        #endif
    }
}

private struct MasterStage1ImageView: View {
    let path: String

    var body: some View {
        Group {
            if let image = MasterStage1ImageLoader.image(at: path) {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [Color.spareYellowLight, Color.white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
                    Image(systemName: "person.crop.square")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.7))
                )
            }
        }
    }
}
