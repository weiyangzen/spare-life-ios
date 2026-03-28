import Foundation

@MainActor
enum MasterStage1Automation {
    static func isEnabled(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        Command(environment: environment) != nil
    }

    static func maybeRun(using store: MasterExperienceStore) async -> Bool {
        guard let command = Command(processInfo: .processInfo) else {
            return false
        }

        let runner = Runner(
            store: store,
            command: command,
            resultFileURL: store.automationResultFileURL
        )
        await runner.run()
        return true
    }
}

@MainActor
private extension MasterStage1Automation {
    struct Command {
        let kind: Kind
        let masterID: String
        let firstPrompt: String
        let secondPrompt: String
        let resumePrompt: String

        enum Kind: String {
            case directorySnapshot = "directory_snapshot"
            case seedChat = "seed_chat"
            case resumeChat = "resume_chat"
        }

        init?(
            processInfo: ProcessInfo
        ) {
            self.init(environment: processInfo.environment)
        }

        init?(
            environment: [String: String]
        ) {
            guard let rawValue = environment["SPARE_MASTERS_AUTOMATION_COMMAND"]?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                let kind = Kind(rawValue: rawValue) else {
                return nil
            }

            self.kind = kind
            masterID = environment["SPARE_MASTERS_AUTOMATION_MASTER_ID"]?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nonEmpty ?? "001546"
            firstPrompt = environment["SPARE_MASTERS_AUTOMATION_FIRST_PROMPT"]?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nonEmpty ?? "我准备在三个月内从内容运营转到 AI 产品，但现金流很紧。你先别安慰我，直接判断我现在最该收缩还是推进。"
            secondPrompt = environment["SPARE_MASTERS_AUTOMATION_SECOND_PROMPT"]?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nonEmpty ?? "如果只能做一个今天就能开始、七天内有反馈的动作，你会让我先做什么？"
            resumePrompt = environment["SPARE_MASTERS_AUTOMATION_RESUME_PROMPT"]?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nonEmpty ?? "我照你的话准备收成一个实验了。退出再回来后，请继续沿着刚才的话题追问我最容易自欺的地方。"
        }
    }

    struct Result: Codable {
        let command: String
        let success: Bool
        let validatedAt: String
        let masterID: String?
        let visibleMasterCount: Int?
        let totalMasterCount: Int?
        let matchedCoverageCount: Int?
        let hasExactStage1Coverage: Bool?
        let resumedTranscriptCount: Int?
        let transcriptCount: Int?
        let serviceMode: String?
        let serviceTitle: String?
        let serviceDetail: String?
        let replyPreview: String?
        let sessionID: String?
        let error: String?
    }

    @MainActor
    final class Runner {
        private let store: MasterExperienceStore
        private let command: Command
        private let resultFileURL: URL
        private let fileManager = FileManager.default

        init(store: MasterExperienceStore, command: Command, resultFileURL: URL) {
            self.store = store
            self.command = command
            self.resultFileURL = resultFileURL
        }

        func run() async {
            clearPreviousResult()

            do {
                await store.refreshCatalog()
                try await Task.sleep(nanoseconds: 250_000_000)

                let result: Result
                switch command.kind {
                case .directorySnapshot:
                    result = try directorySnapshotResult()
                case .seedChat:
                    result = try await seedChatResult()
                case .resumeChat:
                    result = try await resumeChatResult()
                }

                try write(result)
            } catch {
                try? write(
                    Result(
                        command: command.kind.rawValue,
                        success: false,
                        validatedAt: ISO8601DateFormatter().string(from: Date()),
                        masterID: command.masterID,
                        visibleMasterCount: store.visibleDirectoryMasters.count,
                        totalMasterCount: store.masters.count,
                        matchedCoverageCount: store.catalogCoverage?.matchedAssetCount,
                        hasExactStage1Coverage: store.catalogCoverage?.hasExactStage1Coverage,
                        resumedTranscriptCount: nil,
                        transcriptCount: store.conversation?.messages.count,
                        serviceMode: store.conversation?.serviceStatus.isLiveRemote == true ? "liveRemote" : "localFallback",
                        serviceTitle: store.conversation?.serviceStatus.title,
                        serviceDetail: store.conversation?.serviceStatus.detail,
                        replyPreview: store.conversation?.messages.last?.text,
                        sessionID: store.conversation?.session.id,
                        error: error.localizedDescription
                    )
                )
            }
        }

        private func directorySnapshotResult() throws -> Result {
            guard store.masters.count == 8 else {
                throw AutomationError("目录装载数量异常：expected=8 actual=\(store.masters.count)")
            }
            guard store.visibleDirectoryMasters.count == 8 else {
                throw AutomationError("目录可见数量异常：expected=8 actual=\(store.visibleDirectoryMasters.count)")
            }
            guard store.catalogCoverage?.hasExactStage1Coverage == true else {
                throw AutomationError("Stage 1 目录、字段、图片映射没有完全对齐。")
            }

            return Result(
                command: command.kind.rawValue,
                success: true,
                validatedAt: ISO8601DateFormatter().string(from: Date()),
                masterID: nil,
                visibleMasterCount: store.visibleDirectoryMasters.count,
                totalMasterCount: store.masters.count,
                matchedCoverageCount: store.catalogCoverage?.matchedAssetCount,
                hasExactStage1Coverage: store.catalogCoverage?.hasExactStage1Coverage,
                resumedTranscriptCount: nil,
                transcriptCount: nil,
                serviceMode: nil,
                serviceTitle: nil,
                serviceDetail: nil,
                replyPreview: nil,
                sessionID: nil,
                error: nil
            )
        }

        private func seedChatResult() async throws -> Result {
            let profile = try targetMaster()
            store.openConversation(for: profile)
            guard let initialConversation = store.conversation else {
                throw AutomationError("未能进入大师对话页：asset_id=\(profile.id)")
            }
            let initialMessageCount = initialConversation.messages.count

            try await sendAndRequireLiveReply(command.firstPrompt)
            try await sendAndRequireLiveReply(command.secondPrompt)

            guard let conversation = store.conversation else {
                throw AutomationError("发送两轮消息后对话状态丢失。")
            }
            guard conversation.messages.count >= initialMessageCount + 4 else {
                throw AutomationError("多轮对话消息数量不足：expected>=\(initialMessageCount + 4) actual=\(conversation.messages.count)")
            }

            return Result(
                command: command.kind.rawValue,
                success: true,
                validatedAt: ISO8601DateFormatter().string(from: Date()),
                masterID: profile.id,
                visibleMasterCount: store.visibleDirectoryMasters.count,
                totalMasterCount: store.masters.count,
                matchedCoverageCount: store.catalogCoverage?.matchedAssetCount,
                hasExactStage1Coverage: store.catalogCoverage?.hasExactStage1Coverage,
                resumedTranscriptCount: nil,
                transcriptCount: conversation.messages.count,
                serviceMode: conversation.serviceStatus.isLiveRemote ? "liveRemote" : "localFallback",
                serviceTitle: conversation.serviceStatus.title,
                serviceDetail: conversation.serviceStatus.detail,
                replyPreview: conversation.messages.last?.text,
                sessionID: conversation.session.id,
                error: nil
            )
        }

        private func resumeChatResult() async throws -> Result {
            let session = try targetSession()
            store.restoreSession(session)

            guard let restoredConversation = store.conversation else {
                throw AutomationError("未能恢复已保存的大师会话：session_id=\(session.id)")
            }
            let restoredCount = restoredConversation.messages.count
            guard restoredCount >= 5 else {
                throw AutomationError("恢复后的 transcript 过短，无法证明退出再进入继续聊天：actual=\(restoredCount)")
            }

            try await sendAndRequireLiveReply(command.resumePrompt)

            guard let conversation = store.conversation else {
                throw AutomationError("恢复会话后发送追问时对话状态丢失。")
            }
            guard conversation.messages.count >= restoredCount + 2 else {
                throw AutomationError("恢复后追问没有追加完整的一问一答：before=\(restoredCount) after=\(conversation.messages.count)")
            }

            return Result(
                command: command.kind.rawValue,
                success: true,
                validatedAt: ISO8601DateFormatter().string(from: Date()),
                masterID: session.masterID,
                visibleMasterCount: store.visibleDirectoryMasters.count,
                totalMasterCount: store.masters.count,
                matchedCoverageCount: store.catalogCoverage?.matchedAssetCount,
                hasExactStage1Coverage: store.catalogCoverage?.hasExactStage1Coverage,
                resumedTranscriptCount: restoredCount,
                transcriptCount: conversation.messages.count,
                serviceMode: conversation.serviceStatus.isLiveRemote ? "liveRemote" : "localFallback",
                serviceTitle: conversation.serviceStatus.title,
                serviceDetail: conversation.serviceStatus.detail,
                replyPreview: conversation.messages.last?.text,
                sessionID: conversation.session.id,
                error: nil
            )
        }

        private func targetMaster() throws -> MasterProfile {
            guard let profile = store.master(withID: command.masterID) ?? store.visibleDirectoryMasters.first else {
                throw AutomationError("当前目录里找不到要验证的大师：asset_id=\(command.masterID)")
            }
            return profile
        }

        private func targetSession() throws -> MasterRecentSession {
            if let matched = store.recentSessions.first(where: { $0.masterID == command.masterID }) {
                return matched
            }
            if let session = store.recentSessions.first {
                return session
            }
            throw AutomationError("没有找到可恢复的会话。请先执行 seed_chat。")
        }

        private func sendAndRequireLiveReply(_ prompt: String) async throws {
            let beforeCount = store.conversation?.messages.count ?? 0
            await store.sendMessage(prompt)

            guard let conversation = store.conversation else {
                throw AutomationError("发送消息后对话状态丢失。")
            }
            guard conversation.messages.count >= beforeCount + 2 else {
                throw AutomationError("消息发送后没有收到完整的一问一答：before=\(beforeCount) after=\(conversation.messages.count)")
            }
            guard conversation.messages.last?.role == .assistant else {
                throw AutomationError("最后一条消息不是大师回复。")
            }
            guard !(conversation.messages.last?.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) else {
                throw AutomationError("大师回复为空。")
            }
            guard conversation.serviceStatus.isLiveRemote else {
                throw AutomationError("实时大师服务未接通：\(conversation.serviceStatus.detail)")
            }
        }

        private func write(_ result: Result) throws {
            try fileManager.createDirectory(
                at: resultFileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(result)
            try data.write(to: resultFileURL, options: .atomic)
        }

        private func clearPreviousResult() {
            try? fileManager.removeItem(at: resultFileURL)
        }
    }

    struct AutomationError: LocalizedError {
        let detail: String

        init(_ detail: String) {
            self.detail = detail
        }

        var errorDescription: String? {
            detail
        }
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
