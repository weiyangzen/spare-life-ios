// MasterHomeView.swift
// Spare Life – 闲聊首页与大师会话 UI
// Blueprint §3.2 功能点 1-7
// UIUX lane – slot 2

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit) && !canImport(UIKit)
import AppKit
#endif

struct MasterHomeView: View {
    @StateObject private var store: MasterExperienceStore
    @StateObject private var scrollState = WaterfallScrollState()

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
                        Color(red: 0.98, green: 0.96, blue: 0.91),
                        Color(.systemGroupedBackground)
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    directoryHeader

                    filterPanel
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, Spacing.sm)

                    Divider()

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

    private var directoryHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("闲聊")
                    .font(.spareTitle1)

                Text("Stage 1 首页只保留闲聊目录。当前首批资源为 8 位角色，先看人，再进入一对一对话，不在首页优先承接最近聊过、会诊或导向行动。")
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
            }

            DirectorySnapshotPanel(
                masterCount: store.masters.count,
                domainCount: store.domains.count,
                manifestName: store.directoryManifestName,
                serviceDirectoryAssetCount: store.catalogCoverage?.serviceDirectoryAssetCount ?? 0,
                fieldSourcePath: store.catalogCoverage?.fieldSourceDisplayPath ?? "./assets/char",
                fieldAssetCount: store.catalogCoverage?.localCharacterAssetCount ?? 0,
                imageSourcePath: store.catalogCoverage?.imageSourceDisplayPath ?? "./assets/assets",
                imageAssetCount: store.catalogCoverage?.localImageAssetCount ?? 0,
                imageIndexPath: store.catalogCoverage?.imageIndexDisplayPath ?? "./assets/assets/char",
                mappingSummary: store.resourceMappingSummary,
                indexCoverageSummary: store.catalogCoverage?.indexCoverageSummary ?? "目录0 · 字段0 · 图片0"
            )
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.sm)
    }

    private struct DirectorySnapshotPanel: View {
        let masterCount: Int
        let domainCount: Int
        let manifestName: String
        let serviceDirectoryAssetCount: Int
        let fieldSourcePath: String
        let fieldAssetCount: Int
        let imageSourcePath: String
        let imageAssetCount: Int
        let imageIndexPath: String
        let mappingSummary: String
        let indexCoverageSummary: String

        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    Label("\(masterCount) 位已装载", systemImage: "books.vertical.fill")
                        .font(.spareCaptionSB)
                        .foregroundColor(.primary)
                    Text("\(domainCount) 个领域")
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(mappingSummary)
                            .font(.spareCaptionSB)
                            .foregroundColor(.emotionPositive)
                        Text(indexCoverageSummary)
                            .font(.spareMicro)
                            .foregroundColor(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    DirectorySourceRow(
                        label: "服务端目录",
                        value: "\(manifestName) · \(serviceDirectoryAssetCount) 个 asset_id",
                        systemImage: "server.rack"
                    )
                    DirectorySourceRow(
                        label: "字段固定来源",
                        value: "\(fieldSourcePath) · \(fieldAssetCount) 个 JSON",
                        systemImage: "doc.text.fill"
                    )
                    DirectorySourceRow(
                        label: "图片固定来源",
                        value: "\(imageSourcePath) · \(imageAssetCount) 组角色图片",
                        systemImage: "photo.stack.fill"
                    )
                    DirectorySourceRow(label: "图片索引子目录", value: imageIndexPath, systemImage: "photo.on.rectangle.angled")
                }

                Spacer(minLength: 0)

                Text("目录索引只把服务端目录中的 \(serviceDirectoryAssetCount) 个 asset_id 映射到本地字段和图片资源，再进入目录卡片。首页不混入最近聊过、会诊或导向动作入口。")
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }
            .padding(Spacing.md)
            .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .stroke(Color.cardStroke, lineWidth: 1)
            )
        }
    }

    private struct DirectorySourceRow: View {
        let label: String
        let value: String
        let systemImage: String

        var body: some View {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: systemImage)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                    Text(value)
                        .font(.spareCaptionSB)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var filterPanel: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索领域、风格、故事关键词", text: $store.query)
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
            .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .stroke(Color.cardStroke, lineWidth: 1)
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    DomainChip(
                        title: "全部",
                        icon: "square.grid.2x2.fill",
                        isSelected: store.selectedDomainID == nil
                    ) {
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(.spareFast) { store.selectedDomainID = nil }
                    }

                    ForEach(store.domains) { domain in
                        DomainChip(
                            title: domain.title,
                            icon: domain.symbol,
                            isSelected: store.selectedDomainID == domain.id
                        ) {
                            UISelectionFeedbackGenerator().selectionChanged()
                            withAnimation(.spareFast) { store.selectedDomainID = domain.id }
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    @ViewBuilder
    private var feedBody: some View {
        if store.isLoading {
            WaterfallSkeleton(count: 8)
                .transition(.opacity)
        } else if let error = store.fatalErrorMessage {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    ReadOnlyCatalogBanner(policy: store.catalogAccessPolicy)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, Spacing.lg)

                    ErrorStateView(
                        message: error,
                        retry: { Task { await store.refreshCatalog() } }
                    )
                    .padding(.top, Spacing.xxxl)
                }
            }
        } else if store.directoryMasters.isEmpty {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    ReadOnlyCatalogBanner(policy: store.catalogAccessPolicy)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, Spacing.lg)

                    EmptyStateView(
                        icon: "book.closed",
                        title: "这组筛选里还没有合适的大师",
                        message: "试试切换领域或放宽搜索词。当前首页不会混入最近聊过、会诊或其他卡片。",
                        actionLabel: "清空筛选",
                        action: {
                            store.query = ""
                            store.selectedDomainID = nil
                        }
                    )
                }
            }
        } else {
            ScrollViewReader { proxy in
                ZStack(alignment: .bottomTrailing) {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            // Scroll offset tracker + anchor
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: MasterScrollOffsetKey.self,
                                    value: geo.frame(in: .named("masterFeedScroll")).minY
                                )
                            }
                            .frame(height: 0)
                            .id("master_feed_top")

                            VStack(spacing: Spacing.md) {
                                ReadOnlyCatalogBanner(policy: store.catalogAccessPolicy)
                            }
                            .padding(.horizontal, Spacing.lg)
                            .padding(.top, Spacing.md)

                            FeedSectionHeader(
                                title: "大师目录",
                                subtitle: store.hasMoreDirectoryMastersToLoad
                                    ? "\(store.visibleDirectoryMasters.count)/\(store.directoryMasters.count) 位大师，滑到底部继续加载"
                                    : "\(store.visibleDirectoryMasters.count) 位大师"
                            )
                            .padding(.top, Spacing.md)
                            .padding(.bottom, Spacing.xs)

                            GeometryReader { proxy in
                                WaterfallLayout(columns: WaterfallColumns.count(for: proxy.size.width), spacing: Spacing.md) {
                                    ForEach(store.visibleDirectoryMasters) { profile in
                                        MasterProfileCard(profile: profile) {
                                            store.openConversation(for: profile)
                                        }
                                        .onAppear {
                                            store.loadNextDirectoryBatchIfNeeded(after: profile)
                                        }
                                            .transition(.asymmetric(
                                                insertion: .scale(scale: 0.92).combined(with: .opacity),
                                                removal: .opacity
                                            ))
                                    }
                                }
                                .padding(.horizontal, Spacing.lg)
                                .padding(.top, Spacing.xs)
                                .padding(.bottom, Spacing.xxxl)
                            }
                            .frame(minHeight: CGFloat(max(store.visibleDirectoryMasters.count / 2 + 1, 1)) * 200)

                            if store.hasMoreDirectoryMastersToLoad {
                                HStack(spacing: Spacing.sm) {
                                    ProgressView()
                                    Text("继续加载更多大师…")
                                        .font(.spareCaption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.bottom, Spacing.xl)
                            }
                        }
                    }
                    .coordinateSpace(name: "masterFeedScroll")
                    .onPreferenceChange(MasterScrollOffsetKey.self) { offset in
                        scrollState.offsetY = offset
                        scrollState.isAtTop = offset > -40
                    }
                    .refreshable {
                        await store.refreshCatalog()
                    }

                    // Scroll-to-top FAB
                    if !scrollState.isAtTop {
                        ScrollToTopButton(isVisible: true) {
                            withAnimation(.spareSpring) {
                                proxy.scrollTo("master_feed_top", anchor: .top)
                            }
                        }
                        .padding(.trailing, Spacing.lg)
                        .padding(.bottom, Spacing.xl)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spareSpring, value: scrollState.isAtTop)
            }
        }
    }
}

// MARK: - Scroll Offset Key

private struct MasterScrollOffsetKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct DomainChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(.spareCaption)
            }
            .foregroundColor(isSelected ? .spareDark : .primary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? Color.spareYellow : Color.white.opacity(0.82))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.spareYellow : Color.cardStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct EmptyRecentStrip: View {
    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "clock.badge.questionmark")
                .foregroundColor(.secondary)

            Text("你还没有和大师开过聊。先选一个领域，再从问题模板开始。")
                .font(.spareCaption)
                .foregroundColor(.secondary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
    }
}

private struct RecentMasterPill: View {
    let session: MasterRecentSession
    let action: () -> Void
    let pinAction: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: action) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(spacing: Spacing.sm) {
                        AvatarView(name: session.displayName, size: 42)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: Spacing.xs) {
                                Text(session.displayName)
                                    .font(.spareBodySB)
                                    .foregroundColor(.primary)
                                if session.unreadCount > 0 {
                                    Text("\(session.unreadCount)")
                                        .font(.spareMicro)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, Spacing.sm)
                                        .padding(.vertical, Spacing.xs)
                                        .background(Color.emotionNegative, in: Capsule())
                                }
                            }

                            Text(session.title)
                                .font(.spareCaption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }

                    Text(session.topic)
                        .font(.spareCaptionSB)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Text("恢复上下文")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }
                .padding(Spacing.md)
                .frame(width: 220)
                .background(Color.white.opacity(0.84), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .stroke(Color.cardStroke, lineWidth: 1)
                )
                .cardShadow()
            }
            .buttonStyle(.plain)

            Button(action: pinAction) {
                Image(systemName: session.isPinned ? "pin.fill" : "pin")
                    .foregroundColor(session.isPinned ? .spareYellow : .secondary)
                    .padding(Spacing.sm)
                    .background(Color.white, in: Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.cardStroke, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, Spacing.sm)
            .padding(.trailing, Spacing.sm)
        }
    }
}

private struct ReadOnlyCatalogBanner: View {
    let policy: MasterCatalogAccessPolicy

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "lock.doc.fill")
                .foregroundColor(.spareDark)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(policy.title)
                    .font(.spareBodySB)
                Text(policy.detail)
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(Spacing.md)
        .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
    }
}

private enum MasterPlatformImageLoader {
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

private struct MasterImageView: View {
    let path: String

    var body: some View {
        Group {
            if let image = MasterPlatformImageLoader.image(at: path) {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [Color(.systemGray5), Color(.systemGray6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}

private struct CatalogStateBanner: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(.spareBodySB)
                Text(message)
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(Spacing.md)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }
}

private struct MasterProfileCard: View {
    let profile: MasterProfile
    let chatAction: () -> Void

    var body: some View {
        Button(action: chatAction) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                ZStack(alignment: .bottomTrailing) {
                    MasterImageView(path: profile.imageSet.backgroundPath)
                        .frame(height: 196)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                colors: [Color.black.opacity(0.06), Color.black.opacity(0.62)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xl))

                    VStack(alignment: .leading, spacing: Spacing.md) {
                        HStack(alignment: .top, spacing: Spacing.sm) {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                PillTag(label: profile.domainTitle, color: .white, filled: false)
                                HStack(spacing: Spacing.xs) {
                                    Text(profile.sourceLabel)
                                    Text("#\(profile.imageSet.assetID)")
                                }
                                .font(.spareMicro)
                                .foregroundColor(.white.opacity(0.82))
                            }

                            Spacer()

                            Image(systemName: profile.portraitSymbol)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white.opacity(0.92))
                        }

                        Spacer()

                        HStack(alignment: .bottom, spacing: Spacing.md) {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text(profile.displayName)
                                    .font(.spareTitle2)
                                    .foregroundColor(.white)
                                Text(profile.title)
                                    .font(.spareCaptionSB)
                                    .foregroundColor(.white.opacity(0.82))
                                Text(profile.headline)
                                    .font(.spareCaption)
                                    .foregroundColor(.white.opacity(0.82))
                                    .lineLimit(2)
                            }

                            Spacer(minLength: 0)

                            MasterImageView(path: profile.imageSet.avatarPath)
                                .frame(width: 56, height: 56)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.92), lineWidth: 2)
                                )
                        }
                    }
                    .padding(Spacing.lg)
                }

                Text(profile.tagline)
                    .font(.spareBody)
                    .foregroundColor(.primary)
                    .lineLimit(4)

                FlowTagWrap(tags: Array((profile.expertiseTags + profile.focusTags).prefix(5)))

                HStack(spacing: Spacing.sm) {
                    Label("进入对话", systemImage: "bubble.left.and.bubble.right.fill")
                        .font(.spareCaptionSB)
                        .foregroundColor(.spareDark)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(Color.spareYellow, in: Capsule())

                    Spacer()

                    Text("已固定映射")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }
            }
            .padding(Spacing.md)
            .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: CornerRadius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.xl)
                    .stroke(Color.cardStroke, lineWidth: 1)
            )
            .cardShadow(prominent: true)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("master-card-\(profile.id)")
    }
}

private struct ResumeConversationCard: View {
    let session: MasterRecentSession
    let action: () -> Void
    let pinAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("继续上次话题")
                    .font(.spareCaptionSB)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: pinAction) {
                    Image(systemName: session.isPinned ? "pin.fill" : "pin")
                        .foregroundColor(session.isPinned ? .spareYellow : .secondary)
                }
                .buttonStyle(.plain)
            }

            Text(session.displayName)
                .font(.spareTitle3)

            Text(session.topic)
                .font(.spareBodySB)
                .lineLimit(3)

            Text(session.preview)
                .font(.spareCaption)
                .foregroundColor(.secondary)
                .lineLimit(4)

            HStack {
                Label(session.lastMessageAt, systemImage: "clock")
                    .font(.spareMicro)
                    .foregroundColor(.secondary)

                Spacer()

                if session.unreadCount > 0 {
                    Text("\(session.unreadCount) 条未读")
                        .font(.spareMicro)
                        .foregroundColor(.emotionNegative)
                }
            }

            Button("恢复上下文") {
                action()
            }
            .buttonStyle(.plain)
            .font(.spareCaptionSB)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(Color.primary, in: Capsule())
        }
        .padding(Spacing.md)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: CornerRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
        .cardShadow()
    }
}

private struct MasterTemplateCard: View {
    let master: MasterProfile
    let template: MasterQuestionTemplate
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("问题模板")
                    .font(.spareCaptionSB)
                    .foregroundColor(.secondary)
                Spacer()
                Text(template.mode.rawValue)
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }

            Text(template.title)
                .font(.spareTitle3)

            Text(template.prompt)
                .font(.spareCaption)
                .foregroundColor(.secondary)
                .lineLimit(5)

            HStack(spacing: Spacing.sm) {
                AvatarView(name: master.displayName, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(master.displayName)
                        .font(.spareCaptionSB)
                    Text(master.title)
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }
            }

            Button("带着模板开聊") {
                action()
            }
            .buttonStyle(.plain)
            .font(.spareCaptionSB)
            .foregroundColor(.spareDark)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color.spareYellowLight, in: Capsule())
        }
        .padding(Spacing.md)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: CornerRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
        .cardShadow()
    }
}

private struct ConsultationLaunchCard: View {
    let masters: [MasterProfile]
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("多大师会诊")
                    .font(.spareCaptionSB)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: "person.3.sequence.fill")
                    .foregroundColor(.spareDark)
            }

            Text("复杂问题别只听一位。")
                .font(.spareTitle3)

            Text("把求职、现金流、情绪、表达等冲突判断摊开看，系统会保留分歧，不会把多位大师压成一句空泛建议。")
                .font(.spareCaption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(masters.prefix(3), id: \.id) { master in
                    HStack(spacing: Spacing.sm) {
                        AvatarView(name: master.displayName, size: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(master.displayName)
                                .font(.spareCaptionSB)
                            Text(master.domainTitle)
                                .font(.spareMicro)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(master.decisionStyle == "small_bets_profit" ? "先算账" : master.decisionStyle == "act_then_reflect" ? "先行动" : master.decisionStyle == "resilient_expression" ? "先稳住" : "先立边界")
                            .font(.spareMicro)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Button("发起会诊") {
                action()
            }
            .buttonStyle(.plain)
            .font(.spareCaptionSB)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(Color.primary, in: Capsule())
        }
        .padding(Spacing.md)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: CornerRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
        .cardShadow()
    }
}

struct MasterProfileView: View {
    @ObservedObject var store: MasterExperienceStore
    let masterID: String

    @State private var showingAssetSheet = false

    private var profile: MasterProfile? {
        store.master(withID: masterID)
    }

    var body: some View {
        Group {
            if let profile {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        hero(profile)
                        templateSection(profile)
                        memorySection(profile)
                        storySection(profile)
                        readOnlySection
                    }
                    .padding(Spacing.lg)
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle(profile.displayName)
                .spareNavigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .spareTopBarTrailing) {
                        Button("资产包") {
                            showingAssetSheet = true
                        }
                    }
                }
                .sheet(isPresented: $showingAssetSheet) {
                    MasterAssetBundleSheet(profile: profile)
                }
            } else {
                ErrorStateView(message: "当前大师资料已失效。", retry: nil)
            }
        }
    }

    private func hero(_ profile: MasterProfile) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .fill(LinearGradient(colors: profile.palette, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: 220)
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        HStack {
                            PillTag(label: profile.domainTitle, color: .white, filled: false)
                            Spacer()
                            Text(profile.sourceLabel)
                                .font(.spareMicro)
                                .foregroundColor(.white.opacity(0.8))
                        }

                        Spacer()

                        Text(profile.displayName)
                            .font(.spareTitle1)
                            .foregroundColor(.white)
                        Text(profile.title)
                            .font(.spareCaptionSB)
                            .foregroundColor(.white.opacity(0.82))
                        Text(profile.headline)
                            .font(.spareBody)
                            .foregroundColor(.white.opacity(0.88))
                    }
                    .padding(Spacing.lg)
                }

            Text(profile.tagline)
                .font(.spareBody)

            FlowTagWrap(tags: profile.expertiseTags + profile.focusTags)

            HStack(spacing: Spacing.sm) {
                Button("继续聊天") {
                    store.openConversation(for: profile)
                }
                .buttonStyle(.plain)
                .font(.spareCaptionSB)
                .foregroundColor(.spareDark)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(Color.spareYellow, in: Capsule())

                Button("发起会诊") {
                    store.presentConsultation(prefill: "想让 \(profile.displayName) 参与会诊，帮我把问题多视角摊开。")
                }
                .buttonStyle(.plain)
                .font(.spareCaptionSB)
                .foregroundColor(.primary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(Color.white, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.cardStroke, lineWidth: 1)
                )
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Label("回复风格", systemImage: "text.bubble.fill")
                    .font(.spareCaptionSB)
                Text(profile.voice)
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
                Text("Prompt 摘要：\(profile.promptPreview)")
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
            }
            .padding(Spacing.md)
            .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .stroke(Color.cardStroke, lineWidth: 1)
            )
        }
    }

    private func templateSection(_ profile: MasterProfile) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("降低开聊成本")
                .font(.spareTitle3)

            Text("首页优先解决“今天我找谁聊”，这里用问题模板把第一句话变短，但不喧宾夺主。")
                .font(.spareCaption)
                .foregroundColor(.secondary)

            ForEach(profile.featuredTemplates) { template in
                Button {
                    store.openConversation(for: profile, template: template)
                } label: {
                    HStack(alignment: .top, spacing: Spacing.md) {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(template.title)
                                .font(.spareBodySB)
                                .foregroundColor(.primary)
                            Text(template.prompt)
                                .font(.spareCaption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }

                        Spacer()

                        Text(template.mode.rawValue)
                            .font(.spareMicro)
                            .foregroundColor(.secondary)
                    }
                    .padding(Spacing.md)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.lg)
                            .stroke(Color.cardStroke, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func memorySection(_ profile: MasterProfile) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("长期记忆与授权范围")
                .font(.spareTitle3)

            Text("大师静态故事和用户动态记忆分层展示。你可以看见它记住了什么，也可以一键清空。")
                .font(.spareCaption)
                .foregroundColor(.secondary)

            ForEach(profile.goalSnapshots) { goal in
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text(goal.title)
                            .font(.spareBodySB)
                        Spacer()
                        Text(goal.status)
                            .font(.spareMicro)
                            .foregroundColor(.secondary)
                    }
                    Text(goal.nextAction)
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                    Text("更新于 \(goal.updatedAt)")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }
                .padding(Spacing.md)
                .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .stroke(Color.cardStroke, lineWidth: 1)
                )
            }

            if profile.memoryNotes.isEmpty {
                EmptyStateView(
                    icon: "brain.head.profile",
                    title: "这位大师暂时没有被授权长期记忆",
                    message: "你可以在会话里选择只给这位大师记住目标、经历或约束。",
                    actionLabel: nil,
                    action: nil
                )
                .padding(.horizontal, -Spacing.lg)
            } else {
                ForEach(profile.memoryNotes) { note in
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            HStack(spacing: Spacing.xs) {
                                Text(note.label)
                                    .font(.spareCaptionSB)
                                if note.isSensitive {
                                    PillTag(label: "敏感", color: .emotionNegative)
                                }
                                Text(note.scope.rawValue)
                                    .font(.spareMicro)
                                    .foregroundColor(.secondary)
                            }

                            Text(note.summary)
                                .font(.spareCaption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(note.updatedAt)
                            .font(.spareMicro)
                            .foregroundColor(.secondary)
                    }
                    .padding(Spacing.md)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.lg)
                            .stroke(Color.cardStroke, lineWidth: 1)
                    )
                }
            }

            Button(role: .destructive) {
                store.clearMemories(for: profile.id)
            } label: {
                Label("清空与这位大师的长期记忆", systemImage: "trash")
                    .font(.spareCaptionSB)
                    .foregroundColor(.emotionNegative)
            }
        }
    }

    private func storySection(_ profile: MasterProfile) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("为什么这位大师值得聊")
                .font(.spareTitle3)

            Text("每位大师固定 3-5 个重要故事。聊天时只引用相关摘要和 beats，不把整段长文塞进上下文。")
                .font(.spareCaption)
                .foregroundColor(.secondary)

            ForEach(profile.stories) { story in
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(story.title)
                        .font(.spareBodySB)
                    Text(story.summary)
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                    FlowTagWrap(tags: story.tags)
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        ForEach(story.beats, id: \.self) { beat in
                            HStack(alignment: .top, spacing: Spacing.xs) {
                                Circle()
                                    .fill(Color.spareYellow)
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 6)
                                Text(beat)
                                    .font(.spareCaption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(Spacing.md)
                .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .stroke(Color.cardStroke, lineWidth: 1)
                )
            }
        }
    }

    private var readOnlySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("目录权限边界")
                .font(.spareTitle3)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                PermissionRow(icon: "eye.fill", title: "允许浏览", detail: "看大师详情、故事、长期记忆解释和最近会话。")
                PermissionRow(icon: "bubble.left.and.bubble.right.fill", title: "允许聊天", detail: "继续上次话题、使用模板开聊、触发会诊。")
                PermissionRow(icon: "pin.fill", title: "允许收藏/置顶最近聊过", detail: "常用大师会浮到顶部，但不会改动目录本身。")
                PermissionRow(icon: "nosign", title: "禁止新建/删除/编辑大师", detail: "角色、故事、portrait 与 manifest 全部来自后台资产包导入。")
            }
            .padding(Spacing.md)
            .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .stroke(Color.cardStroke, lineWidth: 1)
            )
        }
    }
}

private struct PermissionRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(.primary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(.spareCaptionSB)
                Text(detail)
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct MasterAssetBundleSheet: View {
    let profile: MasterProfile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(profile.assetBundle.bundleID)
                            .font(.spareTitle3)
                        Text("版本 \(profile.assetBundle.version)")
                            .font(.spareCaption)
                            .foregroundColor(.secondary)
                        Text(profile.assetBundle.importNote)
                            .font(.spareCaption)
                            .foregroundColor(.secondary)
                    }
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.lg)
                            .stroke(Color.cardStroke, lineWidth: 1)
                    )

                    AssetFieldGroup(title: "角色字段映射", fields: profile.assetBundle.characterFields)
                    AssetFieldGroup(title: "故事字段映射", fields: profile.assetBundle.storyFields)
                    AssetFieldGroup(title: "Manifest 字段", fields: profile.assetBundle.manifestFields)

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("目录索引来源")
                            .font(.spareBodySB)
                        Text(profile.assetBundle.directoryManifestPath)
                            .font(.spareCaption)
                            .foregroundColor(.secondary)
                    }
                    .padding(Spacing.md)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.lg)
                            .stroke(Color.cardStroke, lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("portrait 资源")
                            .font(.spareBodySB)
                        Text(profile.assetBundle.portraitPackage)
                            .font(.spareCaption)
                            .foregroundColor(.secondary)
                        Text("该资源包只展示导入结果和版本，不提供端侧重新导入按钮。更新走后台幂等覆盖。")
                            .font(.spareCaption)
                            .foregroundColor(.secondary)
                    }
                    .padding(Spacing.md)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.lg)
                            .stroke(Color.cardStroke, lineWidth: 1)
                    )
                }
                .padding(Spacing.lg)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("资产包")
            .spareNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .spareTopBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

private struct AssetFieldGroup: View {
    let title: String
    let fields: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(.spareBodySB)
            FlowTagWrap(tags: fields)
        }
        .padding(Spacing.md)
        .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
    }
}

struct MasterConversationView: View {
    @ObservedObject var store: MasterExperienceStore
    @State private var draftText = ""
    @State private var showingPreferencesSheet = false
    private let bottomAnchorID = "master_conversation_bottom"

    var body: some View {
        Group {
            if let conversation = store.conversation,
               let profile = store.master(withID: conversation.masterID) {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.96, blue: 0.91),
                            Color(.systemGroupedBackground)
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                    .ignoresSafeArea()

                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                                ConversationIdentityCard(
                                    profile: profile,
                                    conversation: conversation
                                )
                                .accessibilityIdentifier("master-conversation-identity")

                                if let error = conversation.inlineError {
                                    ErrorBanner(message: error)
                                }

                                if conversation.messages.isEmpty {
                                    EmptyStateView(
                                        icon: "bubble.left.and.exclamationmark.bubble.right",
                                        title: "还没有对话",
                                        message: "直接说你的问题，或者先选一个模板开始。",
                                        actionLabel: nil,
                                        action: nil
                                    )
                                } else {
                                    ConversationDayMarker(label: "当前会话")

                                    VStack(alignment: .leading, spacing: Spacing.md) {
                                        ForEach(conversation.messages) { message in
                                            MessageBubble(
                                                message: message,
                                                assistantName: profile.displayName,
                                                assistantAvatarPath: profile.imageSet.avatarPath,
                                                isAdopted: { actionID in store.isActionAdopted(actionID) },
                                                actionTap: { action in
                                                    store.presentRoutePreview(action, sourceTitle: "与\(profile.displayName)的对话")
                                                }
                                            )
                                        }
                                    }
                                }

                                if conversation.isReplying {
                                    TypingStateCard()
                                }

                                Color.clear
                                    .frame(height: 4)
                                    .id(bottomAnchorID)
                            }
                            .padding(.horizontal, Spacing.lg)
                            .padding(.top, Spacing.lg)
                            .padding(.bottom, Spacing.xxxl)
                        }
                        .safeAreaInset(edge: .bottom) {
                            composer(profile: profile, conversation: conversation)
                        }
                        .onAppear {
                            if draftText.isEmpty {
                                draftText = conversation.prefilledPrompt
                            }
                            scrollToBottom(using: proxy)
                        }
                        .onChange(of: conversation.prefilledPrompt) { _ in
                            if !conversation.prefilledPrompt.isEmpty {
                                draftText = conversation.prefilledPrompt
                            }
                        }
                        .onChange(of: conversation.messages.count) { _ in
                            scrollToBottom(using: proxy)
                        }
                        .onChange(of: conversation.isReplying) { _ in
                            scrollToBottom(using: proxy)
                        }
                    }
                }
                .navigationTitle(profile.displayName)
                .spareNavigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .spareTopBarTrailing) {
                        Button {
                            showingPreferencesSheet = true
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .accessibilityIdentifier("master-conversation-settings-button")
                    }
                }
                .sheet(isPresented: $showingPreferencesSheet) {
                    MasterConversationSettingsSheet(
                        store: store,
                        profile: profile,
                        fallbackConversation: conversation
                    )
                }
            } else {
                ErrorStateView(message: "当前会话已失效。", retry: nil)
            }
        }
        .sheet(item: $store.routePreview) { preview in
            MasterRoutePreviewSheet(store: store, preview: preview)
        }
    }

    private func composer(profile: MasterProfile, conversation: MasterConversationDraft) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ConversationContextStrip(
                conversation: conversation,
                openPreferences: { showingPreferencesSheet = true }
            )
            .accessibilityIdentifier("master-conversation-status")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(profile.featuredTemplates) { template in
                        Button(template.title) {
                            draftText = template.prompt
                            store.conversation?.mode = template.mode
                        }
                        .buttonStyle(.plain)
                        .font(.spareMicro)
                        .foregroundColor(.primary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(Color.white, in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.cardStroke, lineWidth: 1)
                        )
                    }
                }
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .bottom, spacing: Spacing.sm) {
                    TextField("把问题写具体：目标、约束、下一步想验证什么", text: $draftText, axis: .vertical)
                        .lineLimit(2...6)
                        .font(.spareBody)
                        .disabled(conversation.isReplying)
                        .padding(Spacing.md)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.lg)
                                .stroke(Color.cardStroke, lineWidth: 1)
                        )
                        .accessibilityIdentifier("master-composer-input")

                    Button {
                        let pending = draftText
                        Task {
                            await store.sendMessage(pending)
                            if store.conversation?.inlineError == nil {
                                draftText = ""
                            }
                        }
                    } label: {
                        Image(systemName: conversation.isReplying ? "ellipsis.circle.fill" : "arrow.up.circle.fill")
                            .font(.system(size: 34))
                            .foregroundColor(sendButtonColor(for: conversation))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSendDisabled(for: conversation))
                    .accessibilityIdentifier("master-send-button")
                }

                HStack(spacing: Spacing.sm) {
                    Label("会带上最近消息、相关故事和已授权记忆。", systemImage: "brain.head.profile")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(conversation.serviceStatus.providerName)
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }
            }
            .padding(Spacing.md)
            .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: CornerRadius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.xl)
                    .stroke(Color.cardStroke, lineWidth: 1)
            )
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.md)
        .background(.ultraThinMaterial)
    }

    private func isSendDisabled(for conversation: MasterConversationDraft) -> Bool {
        trimmedDraft.isEmpty || conversation.isReplying
    }

    private func sendButtonColor(for conversation: MasterConversationDraft) -> Color {
        isSendDisabled(for: conversation) ? .secondary.opacity(0.6) : .spareYellow
    }

    private var trimmedDraft: String {
        draftText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func scrollToBottom(using proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.spareEase) {
                proxy.scrollTo(bottomAnchorID, anchor: .bottom)
            }
        }
    }
}

private struct ConversationStatusBanner: View {
    let status: MasterConversationServiceStatus

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: status.tone == .success ? "checkmark.shield.fill" : "lock.trianglebadge.exclamationmark")
                .foregroundColor(status.tone == .success ? .emotionPositive : .orange)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(status.title)
                    .font(.spareBodySB)
                Text(status.detail)
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .background(
            status.tone == .success
                ? Color.emotionPositive.opacity(0.08)
                : Color.orange.opacity(0.08),
            in: RoundedRectangle(cornerRadius: CornerRadius.lg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(
                    status.tone == .success
                        ? Color.emotionPositive.opacity(0.16)
                        : Color.orange.opacity(0.2),
                    lineWidth: 1
                )
        )
    }
}

private struct ConversationIdentityCard: View {
    let profile: MasterProfile
    let conversation: MasterConversationDraft

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ZStack(alignment: .bottomLeading) {
                MasterImageView(path: profile.imageSet.backgroundPath)
                    .frame(height: 148)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [Color.black.opacity(0.14), Color.black.opacity(0.72)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        PillTag(label: profile.domainTitle, color: .white, filled: false)
                        Spacer()
                        ConversationStatusPill(status: conversation.serviceStatus)
                    }

                    HStack(alignment: .center, spacing: Spacing.md) {
                        MasterImageView(path: profile.imageSet.avatarPath)
                            .frame(width: 52, height: 52)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.92), lineWidth: 2)
                            )

                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(profile.displayName)
                                .font(.spareTitle3)
                                .foregroundColor(.white)
                            Text(profile.title)
                                .font(.spareCaptionSB)
                                .foregroundColor(.white.opacity(0.82))
                            Text(conversation.session.topic)
                                .font(.spareCaption)
                                .foregroundColor(.white.opacity(0.88))
                                .lineLimit(2)
                        }
                    }
                }
                .padding(Spacing.lg)
            }
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.xl)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .cardShadow(prominent: true)

            Text("对话页只保留头像抬头、消息流和底部输入区。模式、记忆范围与故事说明保留在辅助层，不挤占主聊天视野。")
                .font(.spareCaption)
                .foregroundColor(.secondary)
                .padding(.horizontal, Spacing.xs)
        }
    }
}

private struct ConversationStatusPill: View {
    let status: MasterConversationServiceStatus

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: status.tone == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            Text(status.isLiveRemote ? "实时" : "本地回退")
        }
        .font(.spareMicro)
        .foregroundColor(.white)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(Color.black.opacity(0.26), in: Capsule())
    }
}

private struct ConversationContextStrip: View {
    let conversation: MasterConversationDraft
    let openPreferences: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    ContextPill(systemImage: "sparkles", title: conversation.mode.rawValue)
                    ContextPill(systemImage: "brain.head.profile", title: conversation.memoryScope.rawValue)
                }
                Text(conversation.serviceStatus.title)
                    .font(.spareCaptionSB)
                    .foregroundColor(.primary)
                Text(conversation.serviceStatus.detail)
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Button("调整") {
                openPreferences()
            }
            .buttonStyle(.plain)
            .font(.spareCaptionSB)
            .foregroundColor(.spareDark)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color.spareYellowLight, in: Capsule())
        }
        .padding(Spacing.md)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: CornerRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
    }
}

private struct ContextPill: View {
    let systemImage: String
    let title: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.spareMicro)
            .foregroundColor(.secondary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(Color(.secondarySystemGroupedBackground), in: Capsule())
    }
}

private struct ConversationDayMarker: View {
    let label: String

    var body: some View {
        HStack {
            Spacer()
            Text(label)
                .font(.spareMicro)
                .foregroundColor(.secondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(Color.white.opacity(0.72), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.cardStroke, lineWidth: 1)
                )
            Spacer()
        }
    }
}

private struct MasterConversationSettingsSheet: View {
    @ObservedObject var store: MasterExperienceStore
    let profile: MasterProfile
    let fallbackConversation: MasterConversationDraft
    @Environment(\.dismiss) private var dismiss

    private var conversation: MasterConversationDraft {
        store.conversation ?? fallbackConversation
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    ConversationStatusBanner(status: conversation.serviceStatus)

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("回复模式")
                            .font(.spareBodySB)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.sm) {
                                ForEach(MasterConversationMode.allCases) { mode in
                                    SelectablePill(
                                        title: mode.rawValue,
                                        subtitle: mode.description,
                                        isSelected: conversation.mode == mode
                                    ) {
                                        store.conversation?.mode = mode
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("长期记忆范围")
                            .font(.spareBodySB)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.sm) {
                                ForEach(MasterMemoryScope.allCases) { scope in
                                    SelectablePill(
                                        title: scope.rawValue,
                                        subtitle: scope.detail,
                                        isSelected: conversation.memoryScope == scope
                                    ) {
                                        store.conversation?.memoryScope = scope
                                    }
                                }
                            }
                        }
                    }

                    if let firstStory = profile.stories.first {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("故事驱动提醒")
                                .font(.spareBodySB)
                            Text("这一页只引用相关故事摘要和 beats，例如“\(firstStory.title)”这样的证据，不会把整段长故事塞进上下文。")
                                .font(.spareCaption)
                                .foregroundColor(.secondary)
                        }
                        .padding(Spacing.md)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.lg)
                                .stroke(Color.cardStroke, lineWidth: 1)
                        )
                    }
                }
                .padding(Spacing.lg)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("对话设置")
            .spareNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .spareTopBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

private struct TypingStateCard: View {
    var body: some View {
        HStack(spacing: Spacing.sm) {
            ProgressView()
            Text("大师正在结合最近上下文、相关故事和授权记忆准备回复。")
                .font(.spareCaption)
                .foregroundColor(.secondary)
        }
        .padding(Spacing.md)
        .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
    }
}

private struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.emotionNegative)
            Text(message)
                .font(.spareCaption)
                .foregroundColor(.secondary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.emotionNegative.opacity(0.08), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(Color.emotionNegative.opacity(0.2), lineWidth: 1)
        )
    }
}

private struct MessageBubble: View {
    let message: MasterMessage
    let assistantName: String
    let assistantAvatarPath: String
    let isAdopted: (String) -> Bool
    let actionTap: (MasterActionRecommendation) -> Void

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        Group {
            if message.role == .system {
                systemMessage
            } else {
                HStack(alignment: .bottom, spacing: Spacing.sm) {
                    if !isUser {
                        speakerBadge
                    } else {
                        Spacer(minLength: 36)
                    }

                    VStack(alignment: isUser ? .trailing : .leading, spacing: Spacing.xs) {
                        Text(isUser ? "你" : assistantName)
                            .font(.spareMicro)
                            .foregroundColor(.secondary)

                        Text(message.text)
                            .font(.spareBody)
                            .foregroundColor(isUser ? .white : .primary)
                            .padding(Spacing.md)
                            .frame(maxWidth: 320, alignment: isUser ? .trailing : .leading)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.xl)
                                    .fill(isUser ? Color.spareDark : Color.white.opacity(0.94))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.xl)
                                    .stroke(isUser ? Color.clear : Color.cardStroke, lineWidth: 1)
                            )
                            .cardShadow()

                        if !message.referencedStoryTitles.isEmpty {
                            FlowTagWrap(tags: message.referencedStoryTitles.map { "故事·\($0)" })
                        }

                        if !message.referencedMemoryLabels.isEmpty {
                            FlowTagWrap(tags: message.referencedMemoryLabels.map { "记忆·\($0)" })
                        }

                        if !message.ctas.isEmpty {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                Text("导向行动")
                                    .font(.spareMicro)
                                    .foregroundColor(.secondary)
                                ForEach(message.ctas) { action in
                                    Button {
                                        actionTap(action)
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(action.label)
                                                    .font(.spareCaptionSB)
                                                    .foregroundColor(.primary)
                                                Text(action.reason)
                                                    .font(.spareMicro)
                                                    .foregroundColor(.secondary)
                                                    .multilineTextAlignment(.leading)
                                            }
                                            Spacer()
                                            if isAdopted(action.id) {
                                                Label("已采纳", systemImage: "checkmark.circle.fill")
                                                    .font(.spareMicro)
                                                    .foregroundColor(.emotionPositive)
                                            } else {
                                                Image(systemName: action.target.icon)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(Spacing.md)
                                        .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: CornerRadius.lg)
                                                .stroke(Color.cardStroke, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Text(message.timestamp)
                            .font(.spareMicro)
                            .foregroundColor(.secondary)
                    }

                    if isUser {
                        speakerBadge
                    } else {
                        Spacer(minLength: 36)
                    }
                }
                .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
            }
        }
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var speakerBadge: some View {
        Group {
            if message.role == .assistant {
                MasterImageView(path: assistantAvatarPath)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.92), lineWidth: 1.5)
                    )
            } else if isUser {
                Circle()
                    .fill(Color.spareYellow)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.spareDark)
                    )
            } else {
                Circle()
                    .fill(Color.secondary.opacity(0.16))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    )
            }
        }
    }

    private var systemMessage: some View {
        HStack {
            Spacer()
            HStack(alignment: .center, spacing: Spacing.sm) {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.secondary)
                Text(message.text)
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color.white.opacity(0.78), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.cardStroke, lineWidth: 1)
            )
            Spacer()
        }
    }

    private var accessibilityIdentifier: String {
        switch message.role {
        case .user:
            return "master-user-message-\(message.id)"
        case .assistant:
            return "master-assistant-message-\(message.id)"
        case .system:
            return "master-system-message-\(message.id)"
        }
    }
}

private struct SelectablePill: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.spareCaptionSB)
                Text(subtitle)
                    .font(.spareMicro)
                    .lineLimit(2)
                    .foregroundColor(isSelected ? .spareDark.opacity(0.8) : .secondary)
            }
            .foregroundColor(isSelected ? .spareDark : .primary)
            .padding(Spacing.md)
            .frame(width: 168, alignment: .leading)
            .background(isSelected ? Color.spareYellowLight : Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .stroke(isSelected ? Color.spareYellow : Color.cardStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct MasterConsultationView: View {
    @ObservedObject var store: MasterExperienceStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let consultation = store.consultation {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Spacing.lg) {
                            Text("多大师会诊适合复杂问题。每位大师只带自己的相关故事，不共享完整人生故事库。")
                                .font(.spareCaption)
                                .foregroundColor(.secondary)

                            consultationSelection(consultation)

                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                Text("你要会诊的问题")
                                    .font(.spareBodySB)

                                TextEditor(text: Binding(
                                    get: { store.consultation?.issue ?? "" },
                                    set: { store.consultation?.issue = $0 }
                                ))
                                .frame(minHeight: 120)
                                .padding(Spacing.sm)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                                        .stroke(Color.cardStroke, lineWidth: 1)
                                )
                            }

                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                Text("会诊共享范围")
                                    .font(.spareBodySB)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: Spacing.sm) {
                                        ForEach(MasterMemoryScope.allCases) { scope in
                                            SelectablePill(
                                                title: scope.rawValue,
                                                subtitle: scope.detail,
                                                isSelected: consultation.shareScope == scope
                                            ) {
                                                store.consultation?.shareScope = scope
                                            }
                                        }
                                    }
                                }
                            }

                            if let error = consultation.inlineError {
                                ErrorBanner(message: error)
                            }

                            consultationPhase(consultation.phase)
                        }
                        .padding(Spacing.lg)
                    }
                    .background(Color(.systemGroupedBackground))
                    .safeAreaInset(edge: .bottom) {
                        Button {
                            Task { await store.runConsultation() }
                        } label: {
                            Text("开始会诊")
                                .font(.spareBodySB)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.md)
                                .background(Color.primary, in: Capsule())
                        }
                        .padding(Spacing.lg)
                        .background(.ultraThinMaterial)
                    }
                } else {
                    ErrorStateView(message: "当前会诊上下文已失效。", retry: nil)
                }
            }
            .navigationTitle("多大师会诊")
            .spareNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .spareTopBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func consultationSelection(_ consultation: MasterConsultationDraft) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("选择 1-3 位大师")
                .font(.spareBodySB)

            if store.masters.isEmpty {
                EmptyStateView(
                    icon: "person.3.sequence.fill",
                    title: "当前没有可选大师",
                    message: "先回首页调整筛选或恢复内容源，再发起会诊。",
                    actionLabel: nil,
                    action: nil
                )
            } else {
                ForEach(store.masters) { master in
                    Button {
                        store.toggleConsultSelection(master.id)
                    } label: {
                        HStack(spacing: Spacing.md) {
                            AvatarView(name: master.displayName, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(master.displayName)
                                    .font(.spareBodySB)
                                    .foregroundColor(.primary)
                                Text(master.title)
                                    .font(.spareCaption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: consultation.selectedMasterIDs.contains(master.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(consultation.selectedMasterIDs.contains(master.id) ? .emotionPositive : .secondary)
                        }
                        .padding(Spacing.md)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.lg)
                                .stroke(Color.cardStroke, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func consultationPhase(_ phase: MasterConsultationPhase) -> some View {
        switch phase {
        case .drafting:
            EmptyStateView(
                icon: "person.3.sequence.fill",
                title: "把问题写得越具体，会诊越有用",
                message: "例如把目标、风险、时间和你最纠结的冲突写出来，系统会显式保留不同大师的分歧。",
                actionLabel: nil,
                action: nil
            )
        case .loading:
            HStack(spacing: Spacing.sm) {
                ProgressView()
                Text("正在合并多位大师的立场、故事证据和 CTA。")
                    .font(.spareCaption)
                    .foregroundColor(.secondary)
            }
            .padding(Spacing.md)
            .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        case .error(let message):
            ErrorStateView(message: message, retry: nil)
        case .loaded(let result):
            VStack(alignment: .leading, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("合并建议")
                        .font(.spareBodySB)
                    Text(result.mergedSummary)
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                }
                .padding(Spacing.md)
                .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .stroke(Color.cardStroke, lineWidth: 1)
                )

                if let conflict = result.conflictSummary {
                    ErrorBanner(message: conflict)
                }

                if !result.ctas.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("导向行动")
                            .font(.spareBodySB)
                        ForEach(result.ctas) { action in
                            Button {
                                store.presentRoutePreview(action, sourceTitle: "多大师会诊")
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(action.label)
                                            .font(.spareCaptionSB)
                                            .foregroundColor(.primary)
                                        Text(action.reason)
                                            .font(.spareMicro)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: action.target.icon)
                                        .foregroundColor(.secondary)
                                }
                                .padding(Spacing.md)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                                        .stroke(Color.cardStroke, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                ForEach(result.members) { member in
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack {
                            Text(member.displayName)
                                .font(.spareBodySB)
                            Spacer()
                            Text(member.stance)
                                .font(.spareMicro)
                                .foregroundColor(.secondary)
                        }
                        Text(member.advice)
                            .font(.spareCaption)
                            .foregroundColor(.secondary)
                        FlowTagWrap(tags: member.storyTitles.map { "故事·\($0)" })
                    }
                    .padding(Spacing.md)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.lg)
                            .stroke(Color.cardStroke, lineWidth: 1)
                    )
                }
            }
        }
    }
}

private struct MasterRoutePreviewSheet: View {
    @ObservedObject var store: MasterExperienceStore
    let preview: MasterRoutePreview
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Label(preview.action.target.title, systemImage: preview.action.target.icon)
                        .font(.spareCaptionSB)
                    Text(preview.action.label)
                        .font(.spareTitle3)
                    Text(preview.action.reason)
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("来自")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                    Text(preview.sourceTitle)
                        .font(.spareBodySB)
                }
                .padding(Spacing.md)
                .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .stroke(Color.cardStroke, lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("目标路由")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                    Text(preview.action.route)
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                .padding(Spacing.md)
                .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .stroke(Color.cardStroke, lineWidth: 1)
                )

                Button {
                    store.markActionAdopted(preview.action.id)
                } label: {
                    Label(store.isActionAdopted(preview.action.id) ? "已记录采纳" : "标记为已采纳", systemImage: "checkmark.circle.fill")
                        .font(.spareBodySB)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(store.isActionAdopted(preview.action.id) ? Color.emotionPositive : Color.primary, in: Capsule())
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(Spacing.lg)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("导向行动")
            .spareNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .spareTopBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

private struct MasterCatalogSourceSheet: View {
    @ObservedObject var store: MasterExperienceStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("内容来源") {
                    ForEach(MasterCatalogSourceMode.allCases) { mode in
                        Button {
                            store.applyCatalogSourceMode(mode)
                            dismiss()
                        } label: {
                            HStack(alignment: .top, spacing: Spacing.sm) {
                                Image(systemName: mode.icon)
                                    .foregroundColor(mode.tint)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mode.title)
                                        .font(.spareBodySB)
                                        .foregroundColor(.primary)
                                    Text(mode.subtitle)
                                        .font(.spareCaption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if store.catalogSourceMode == mode {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.emotionPositive)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("说明") {
                    Text("这个入口不是调试开关，而是内容状态中心。大师页本身就需要明确告诉用户当前来自实时目录、缓存目录，还是进入异常降级。")
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("内容状态")
            .spareNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .spareTopBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

private struct FlowTagWrap: View {
    let tags: [String]

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 72), spacing: 6, alignment: .leading)],
            alignment: .leading,
            spacing: 6
        ) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(Color(.systemGray6), in: Capsule())
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
