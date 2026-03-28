import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import AVFoundation
#endif

struct MasterSpeechTranscriptionResolution: Equatable {
    let draft: String
    let errorMessage: String?
}

struct MasterSpeechTranscriptionFlow {
    typealias Transcribe = @Sendable (URL) async throws -> String
    typealias MergeDraft = @Sendable (String, String) -> String
    typealias RemoveFile = @Sendable (URL) -> Void

    private let transcribe: Transcribe
    private let mergeDraft: MergeDraft
    private let removeFile: RemoveFile

    init(
        transcribe: @escaping Transcribe,
        mergeDraft: @escaping MergeDraft = { existingDraft, transcript in
            MasterSpeechDraftComposer.mergedDraft(
                existingDraft: existingDraft,
                transcript: transcript
            )
        },
        removeFile: @escaping RemoveFile = { url in
            try? FileManager.default.removeItem(at: url)
        }
    ) {
        self.transcribe = transcribe
        self.mergeDraft = mergeDraft
        self.removeFile = removeFile
    }

    func resolve(
        fileURL: URL,
        existingDraft: String,
        cleanupAfterTranscription: Bool
    ) async -> MasterSpeechTranscriptionResolution {
        defer {
            if cleanupAfterTranscription {
                removeFile(fileURL)
            }
        }

        do {
            let transcript = try await transcribe(fileURL)
            return MasterSpeechTranscriptionResolution(
                draft: mergeDraft(existingDraft, transcript),
                errorMessage: nil
            )
        } catch {
            return MasterSpeechTranscriptionResolution(
                draft: existingDraft,
                errorMessage: "语音识别失败：\(error.localizedDescription)"
            )
        }
    }
}

struct MasterSpeechInputActions: View {
    @ObservedObject var store: MasterExperienceStore
    @Binding var draftText: String
    let disabled: Bool

    @State private var showingAudioImporter = false
    @State private var isTranscribing = false
    #if os(iOS)
    @State private var showingRecorderSheet = false
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                actionButton(
                    title: "导入音频",
                    systemImage: "paperclip.circle.fill",
                    action: { showingAudioImporter = true }
                )

                #if os(iOS)
                actionButton(
                    title: "录音",
                    systemImage: "mic.circle.fill",
                    action: { showingRecorderSheet = true }
                )
                #endif

                Spacer(minLength: 0)

                if isTranscribing {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在识别语音…")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                } else {
                    Text("音频会先走 ASR，再回填到当前输入框。")
                        .font(.spareMicro)
                        .foregroundColor(.secondary)
                }
            }

            MasterSpeechStatusBanner(status: store.asrConnectionStatus)
        }
        .fileImporter(
            isPresented: $showingAudioImporter,
            allowedContentTypes: [.audio]
        ) { result in
            handleImport(result)
        }
        #if os(iOS)
        .sheet(isPresented: $showingRecorderSheet) {
            MasterAudioRecorderSheet { url in
                startTranscription(from: url, cleanupAfterTranscription: true)
            }
        }
        #endif
    }

    private func actionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.spareMicro)
                .foregroundColor(.primary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.cardStroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled || isTranscribing)
        .opacity((disabled || isTranscribing) ? 0.55 : 1)
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let sourceURL):
            do {
                let workingURL = try makeWorkingCopy(from: sourceURL)
                startTranscription(from: workingURL, cleanupAfterTranscription: true)
            } catch {
                Task { @MainActor in
                    store.setConversationInlineError("读取导入音频失败：\(error.localizedDescription)")
                }
            }
        case .failure(let error):
            Task { @MainActor in
                store.setConversationInlineError("选择音频失败：\(error.localizedDescription)")
            }
        }
    }

    private func startTranscription(from fileURL: URL, cleanupAfterTranscription: Bool) {
        Task {
            await MainActor.run {
                isTranscribing = true
                store.setConversationInlineError(nil)
            }

            let existingDraft = await MainActor.run { draftText }
            let flow = MasterSpeechTranscriptionFlow { url in
                try await store.transcribeAudio(at: url)
            }
            let resolution = await flow.resolve(
                fileURL: fileURL,
                existingDraft: existingDraft,
                cleanupAfterTranscription: cleanupAfterTranscription
            )

            await MainActor.run {
                draftText = resolution.draft
                store.setConversationInlineError(resolution.errorMessage)
                isTranscribing = false
            }
        }
    }

    private func makeWorkingCopy(from sourceURL: URL) throws -> URL {
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let ext = sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("master-asr-\(UUID().uuidString)")
            .appendingPathExtension(ext)
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return destination
    }
}

private struct MasterSpeechErrorBanner: View {
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

private struct MasterSpeechStatusBanner: View {
    let status: MasterASRConnectionStatus

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: status.tone == .ready ? "checkmark.shield.fill" : "lock.trianglebadge.exclamationmark")
                .foregroundColor(status.tone == .ready ? .emotionPositive : .orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(status.title)
                    .font(.spareCaptionSB)
                    .foregroundColor(.primary)
                Text(status.detail)
                    .font(.spareMicro)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            status.tone == .ready
                ? Color.emotionPositive.opacity(0.08)
                : Color.orange.opacity(0.08),
            in: RoundedRectangle(cornerRadius: CornerRadius.md)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(
                    status.tone == .ready
                        ? Color.emotionPositive.opacity(0.18)
                        : Color.orange.opacity(0.2),
                    lineWidth: 1
                )
        )
    }
}

#if os(iOS)
private struct MasterAudioRecorderSheet: View {
    let onCommit: (URL) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = MasterAudioRecorderController()

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                ZStack {
                    Circle()
                        .fill(recorder.isRecording ? Color.red.opacity(0.14) : Color.spareYellowLight)
                        .frame(width: 88, height: 88)
                    Image(systemName: recorder.isRecording ? "waveform.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundColor(recorder.isRecording ? .red : .spareDark)
                }

                VStack(spacing: Spacing.xs) {
                    Text(recorder.isRecording ? "正在录音" : "录一段语音")
                        .font(.spareTitle3)
                    Text(recorder.statusText)
                        .font(.spareCaption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                if let errorMessage = recorder.errorMessage {
                    MasterSpeechErrorBanner(message: errorMessage)
                }

                VStack(spacing: Spacing.sm) {
                    if recorder.isRecording {
                        Button("结束录音并转写") {
                            finishRecording()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.spareYellow)

                        Button("取消") {
                            recorder.cancel()
                            dismiss()
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button("开始录音") {
                            Task {
                                await recorder.start()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.spareYellow)

                        Button("稍后再说") {
                            dismiss()
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(Spacing.lg)
            .navigationTitle("语音输入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        recorder.cancel()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func finishRecording() {
        do {
            let url = try recorder.finish()
            onCommit(url)
            dismiss()
        } catch {
            recorder.errorMessage = error.localizedDescription
        }
    }
}

@MainActor
private final class MasterAudioRecorderController: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var statusText = "点击开始录音，结束后会送入同一条 ASR 转写链路。"
    @Published var errorMessage: String?

    private var recorder: AVAudioRecorder?
    private var recordedFileURL: URL?

    func start() async {
        errorMessage = nil

        do {
            let permitted = await requestPermission()
            guard permitted else {
                statusText = "系统没有授予麦克风权限。"
                errorMessage = "麦克风权限未开启，当前不能录音。"
                return
            }

            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let targetURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("master-recording-\(UUID().uuidString)")
                .appendingPathExtension("m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            let recorder = try AVAudioRecorder(url: targetURL, settings: settings)
            guard recorder.record() else {
                throw MasterASRServiceError.transport("录音启动失败。")
            }

            self.recorder = recorder
            recordedFileURL = targetURL
            isRecording = true
            statusText = "说完后结束录音，文本会直接回填到当前聊天输入框。"
        } catch {
            statusText = "录音启动失败。"
            errorMessage = error.localizedDescription
        }
    }

    func finish() throws -> URL {
        guard isRecording, let recorder, let recordedFileURL else {
            throw MasterASRServiceError.transport("当前没有可提交的录音文件。")
        }

        recorder.stop()
        try? AVAudioSession.sharedInstance().setActive(false)

        self.recorder = nil
        self.recordedFileURL = nil
        isRecording = false
        statusText = "录音已结束，准备送去转写。"
        return recordedFileURL
    }

    func cancel() {
        recorder?.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
        if let recordedFileURL {
            try? FileManager.default.removeItem(at: recordedFileURL)
        }
        recorder = nil
        recordedFileURL = nil
        isRecording = false
    }

    private func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
#endif
