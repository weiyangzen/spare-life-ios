import Foundation
import SwiftUI
#if canImport(Security)
import Security
#endif

private enum MastersPreviewAutomationMode: String {
    case idle
    case directorySnapshot = "directory_snapshot"
    case seedChat = "seed_chat"
    case resumeChat = "resume_chat"

    static func current(processInfo: ProcessInfo = .processInfo) -> MastersPreviewAutomationMode {
        MastersPreviewAutomationMode(
            rawValue: processInfo.environment["SPARELIFE_MASTERS_AUTOMATION_MODE"] ?? ""
        ) ?? .idle
    }
}

private struct MastersPreviewAutomationReport: Codable {
    let mode: String
    let success: Bool
    let masterIDs: [String]
    let visibleMasterCount: Int
    let targetMasterID: String?
    let targetMasterName: String?
    let messageCountBefore: Int?
    let messageCountAfter: Int?
    let assistantMessageCount: Int?
    let serviceMode: String
    let credentialSource: String
    let serviceDetail: String
    let detail: String
}

struct MastersPreviewRootView: View {
    @StateObject private var store: MasterExperienceStore
    @State private var hasRunAutomation = false

    private let processInfo: ProcessInfo
    private let localStateStore: MasterConversationLocalStateStore

    @MainActor
    init(
        processInfo: ProcessInfo = .processInfo,
        localStateStore: MasterConversationLocalStateStore = MasterConversationLocalStateStore()
    ) {
        self.processInfo = processInfo
        self.localStateStore = localStateStore
        _store = StateObject(
            wrappedValue: MasterExperienceStore(localStateStore: localStateStore)
        )
    }

    var body: some View {
        MasterHomeView(store: store)
            .task {
                guard !hasRunAutomation else { return }
                hasRunAutomation = true
                await runAutomationIfNeeded()
            }
    }

    @MainActor
    private func runAutomationIfNeeded() async {
        let mode = MastersPreviewAutomationMode.current(processInfo: processInfo)
        guard mode != .idle else { return }

        clearPreviousResult()
        seedConversationConfigurationIfNeeded()
        await store.refreshCatalog()

        switch mode {
        case .idle:
            return
        case .directorySnapshot:
            writeResult(
                MastersPreviewAutomationReport(
                    mode: mode.rawValue,
                    success: store.masters.count == 8,
                    masterIDs: store.masters.map(\.id),
                    visibleMasterCount: store.visibleDirectoryMasters.count,
                    targetMasterID: nil,
                    targetMasterName: nil,
                    messageCountBefore: nil,
                    messageCountAfter: nil,
                    assistantMessageCount: nil,
                    serviceMode: deliveryModeLabel(store.conversationServiceStatus),
                    credentialSource: store.conversationServiceStatus.credentialSource.rawValue,
                    serviceDetail: store.conversationServiceStatus.detail,
                    detail: "directory_loaded=\(store.masters.count)"
                )
            )
        case .seedChat:
            await runSeedChat(mode: mode)
        case .resumeChat:
            await runResumeChat(mode: mode)
        }
    }

    @MainActor
    private func runSeedChat(mode: MastersPreviewAutomationMode) async {
        guard let profile = targetProfile() else {
            writeResult(
                MastersPreviewAutomationReport(
                    mode: mode.rawValue,
                    success: false,
                    masterIDs: store.masters.map(\.id),
                    visibleMasterCount: store.visibleDirectoryMasters.count,
                    targetMasterID: nil,
                    targetMasterName: nil,
                    messageCountBefore: nil,
                    messageCountAfter: nil,
                    assistantMessageCount: nil,
                    serviceMode: deliveryModeLabel(store.conversationServiceStatus),
                    credentialSource: store.conversationServiceStatus.credentialSource.rawValue,
                    serviceDetail: store.conversationServiceStatus.detail,
                    detail: "missing_target_profile"
                )
            )
            return
        }

        store.openConversation(for: profile)
        let before = store.conversation?.messages.count ?? 0
        await store.sendMessage(
            processInfo.environment["SPARELIFE_MASTERS_FIRST_PROMPT"] ??
            "我准备在三个月内完成一次方向切换，但现金流只有半年。你先别安慰我，先判断我最该先补的缺口。"
        )
        await store.sendMessage(
            processInfo.environment["SPARELIFE_MASTERS_SECOND_PROMPT"] ??
            "如果我只能在这周做一个动作来验证你的判断，你会让我具体做什么？"
        )

        let after = store.conversation?.messages.count ?? 0
        let assistantCount = store.conversation?.messages.filter { $0.role == .assistant }.count ?? 0
        let status = store.conversation?.serviceStatus ?? store.conversationServiceStatus

        writeResult(
            MastersPreviewAutomationReport(
                mode: mode.rawValue,
                success: store.masters.count == 8 && after >= before + 4 && assistantCount >= 3,
                masterIDs: store.masters.map(\.id),
                visibleMasterCount: store.visibleDirectoryMasters.count,
                targetMasterID: profile.id,
                targetMasterName: profile.displayName,
                messageCountBefore: before,
                messageCountAfter: after,
                assistantMessageCount: assistantCount,
                serviceMode: deliveryModeLabel(status),
                credentialSource: status.credentialSource.rawValue,
                serviceDetail: status.detail,
                detail: "seed_chat_complete"
            )
        )
    }

    @MainActor
    private func runResumeChat(mode: MastersPreviewAutomationMode) async {
        guard let profile = targetProfile() else {
            writeResult(
                MastersPreviewAutomationReport(
                    mode: mode.rawValue,
                    success: false,
                    masterIDs: store.masters.map(\.id),
                    visibleMasterCount: store.visibleDirectoryMasters.count,
                    targetMasterID: nil,
                    targetMasterName: nil,
                    messageCountBefore: nil,
                    messageCountAfter: nil,
                    assistantMessageCount: nil,
                    serviceMode: deliveryModeLabel(store.conversationServiceStatus),
                    credentialSource: store.conversationServiceStatus.credentialSource.rawValue,
                    serviceDetail: store.conversationServiceStatus.detail,
                    detail: "missing_target_profile"
                )
            )
            return
        }

        store.openConversation(for: profile)
        let before = store.conversation?.messages.count ?? 0
        await store.sendMessage(
            processInfo.environment["SPARELIFE_MASTERS_RESUME_PROMPT"] ??
            "我回来了。继续上次的话题，如果只能做一件最小动作，你会让我今天先做哪一步？"
        )

        let after = store.conversation?.messages.count ?? 0
        let assistantCount = store.conversation?.messages.filter { $0.role == .assistant }.count ?? 0
        let status = store.conversation?.serviceStatus ?? store.conversationServiceStatus

        writeResult(
            MastersPreviewAutomationReport(
                mode: mode.rawValue,
                success: store.masters.count == 8 && before >= 5 && after >= before + 2 && assistantCount >= 3,
                masterIDs: store.masters.map(\.id),
                visibleMasterCount: store.visibleDirectoryMasters.count,
                targetMasterID: profile.id,
                targetMasterName: profile.displayName,
                messageCountBefore: before,
                messageCountAfter: after,
                assistantMessageCount: assistantCount,
                serviceMode: deliveryModeLabel(status),
                credentialSource: status.credentialSource.rawValue,
                serviceDetail: status.detail,
                detail: "resume_chat_complete"
            )
        )
    }

    @MainActor
    private func targetProfile() -> MasterProfile? {
        if let targetAssetID = processInfo.environment["SPARELIFE_MASTERS_TARGET_ASSET_ID"],
           let matched = store.masters.first(where: { $0.id == targetAssetID }) {
            return matched
        }

        return store.masters.first
    }

    private func clearPreviousResult() {
        try? FileManager.default.removeItem(at: localStateStore.resultFileURL)
    }

    private func writeResult(_ report: MastersPreviewAutomationReport) {
        do {
            let data = try JSONEncoder().encode(report)
            try FileManager.default.createDirectory(
                at: localStateStore.resultFileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: localStateStore.resultFileURL, options: .atomic)
            print("[MastersPreviewAutomation] wrote result to \(localStateStore.resultFileURL.path)")
        } catch {
            print("[MastersPreviewAutomation] failed to write result: \(error.localizedDescription)")
        }
    }

    private func deliveryModeLabel(_ status: MasterConversationServiceStatus) -> String {
        switch status.deliveryMode {
        case .liveRemote:
            return "liveRemote"
        case .localFallback:
            return "localFallback"
        }
    }

    private func seedConversationConfigurationIfNeeded() {
        if processInfo.environment["SPARELIFE_MASTERS_FORCE_LOCAL_FALLBACK"] == "1" {
            UserDefaults.standard.removeObject(forKey: "masters.conversation.model")
            UserDefaults.standard.removeObject(forKey: "masters.conversation.baseURL")
            deleteAPIKeyFromKeychain()
            return
        }

        if let model = processInfo.environment["SPARELIFE_MASTERS_ANTHROPIC_MODEL"], !model.isEmpty {
            UserDefaults.standard.set(model, forKey: "masters.conversation.model")
        }

        if let baseURL = processInfo.environment["SPARELIFE_MASTERS_ANTHROPIC_BASE_URL"], !baseURL.isEmpty {
            UserDefaults.standard.set(baseURL, forKey: "masters.conversation.baseURL")
        }

        if let apiKey = processInfo.environment["SPARELIFE_MASTERS_ANTHROPIC_API_KEY"], !apiKey.isEmpty {
            storeAPIKeyInKeychain(apiKey)
        }
    }

    private func storeAPIKeyInKeychain(_ value: String) {
        #if canImport(Security)
        let encoded = Data(value.utf8)
        let baseQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "com.wangweiyang.sparelife.masters.conversation",
            kSecAttrAccount: "anthropic.api-key"
        ]

        let addQuery = baseQuery.merging([
            kSecValueData: encoded,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]) { _, new in new }

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecSuccess {
            return
        }

        guard addStatus == errSecDuplicateItem else {
            return
        }

        _ = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData: encoded] as CFDictionary
        )
        #endif
    }

    private func deleteAPIKeyFromKeychain() {
        #if canImport(Security)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "com.wangweiyang.sparelife.masters.conversation",
            kSecAttrAccount: "anthropic.api-key"
        ]
        SecItemDelete(query as CFDictionary)
        #endif
    }
}
