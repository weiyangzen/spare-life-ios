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
    @State private var showConversation = false

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
                        Color.spareYellow.opacity(0.12),
                        Color.white,
                        Color.white
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    searchBar
                    feedBody
                }
            }
            .spareNavigationBarHidden(true)
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
        .modifier(MasterConversationPresentationModifier(showConversation: $showConversation, store: store))
    }

    private var header: some View {
        HStack {
            Spacer()
            Text("闲聊")
                .font(.spareTitle2)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.md)
    }

    private var searchBar: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("搜索大师或关键词", text: $store.query)
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
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.md)
    }

    @ViewBuilder
    private var feedBody: some View {
        GeometryReader { proxy in
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
                        MasterPortraitGrid(
                            profiles: store.visibleDirectoryMasters,
                            containerWidth: proxy.size.width,
                            onOpen: { profile in
                                store.openConversation(for: profile)
                                showConversation = true
                            },
                            onVisible: { profile in
                                store.loadNextDirectoryBatchIfNeeded(after: profile)
                            }
                        )

                        if store.hasMoreDirectoryMastersToLoad {
                            HStack(spacing: Spacing.sm) {
                                ProgressView()
                                Text("继续加载更多大师…")
                                    .font(.spareCaption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, Spacing.sm)
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
}

private struct MasterConversationPresentationModifier: ViewModifier {
    @Binding var showConversation: Bool
    @ObservedObject var store: MasterExperienceStore

    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .fullScreenCover(isPresented: $showConversation, onDismiss: dismissConversation) {
                MasterConversationView(store: store, onBack: dismissConversation)
            }
        #else
        content
            .navigationDestination(isPresented: $showConversation) {
                MasterConversationView(store: store, onBack: dismissConversation)
            }
        #endif
    }

    private func dismissConversation() {
        showConversation = false
        store.conversation = nil
    }
}

private struct MasterPortraitGrid: View {
    let profiles: [MasterProfile]
    let containerWidth: CGFloat
    let onOpen: (MasterProfile) -> Void
    let onVisible: (MasterProfile) -> Void

    var body: some View {
        let columnCount = max(WaterfallColumns.count(for: containerWidth - Spacing.sm * 2), 1)
        let columns = Array(
            repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: Spacing.sm, alignment: .top),
            count: columnCount
        )

        LazyVGrid(columns: columns, alignment: .leading, spacing: Spacing.sm) {
            ForEach(profiles) { profile in
                MasterStage1Card(profile: profile) {
                    onOpen(profile)
                }
                .onAppear {
                    onVisible(profile)
                }
            }
        }
        .padding(.horizontal, Spacing.sm)
    }
}

private struct MasterStage1Card: View {
    let profile: MasterProfile
    let action: () -> Void
    private let shape = RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                MasterStage1ImageView(path: profile.imageSet.portraitPath)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(
                        LinearGradient(
                            colors: [Color.black.opacity(0.02), Color.black.opacity(0.78)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Spacer(minLength: 0)
                    Text(profile.displayName)
                        .font(.spareTitle3)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    Text(profile.title)
                        .font(.spareCaptionSB)
                        .foregroundColor(.white.opacity(0.86))
                        .lineLimit(2)
                    Text(profile.promptPreview.isEmpty ? profile.tagline : profile.promptPreview)
                        .font(.spareCaption)
                        .foregroundColor(.white.opacity(0.92))
                        .lineLimit(3)
                    Label("进入一对一闲聊", systemImage: "bubble.left.and.bubble.right.fill")
                        .font(.spareMicro)
                        .foregroundColor(.white.opacity(0.86))
                }
                .padding(Spacing.md)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.cardBackground)
            .clipShape(shape)
            .overlay(
                shape
                    .stroke(Color.cardStroke, lineWidth: 1)
            )
            .contentShape(shape)
            .cardShadow()
        }
        .buttonStyle(CardPressStyle())
        .accessibilityIdentifier("master-stage1-card-\(profile.id)")
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
