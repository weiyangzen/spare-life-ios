import SwiftUI
#if os(iOS)
import AVFoundation
import UIKit
#endif

struct MasterSpeechTranscriptionResolution: Equatable {
    let draft: String
    let errorMessage: String?
}

struct MasterSpeechTranscriptionAvailability {
    static func blockingMessage(for status: MasterASRConnectionStatus) -> String? {
        guard status.tone != .ready else {
            return nil
        }

        return "语音识别暂不可用：\(status.title)。\(status.detail)"
    }
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

    #if os(iOS)
    @StateObject private var recorder = MasterAudioRecorderController()
    @State private var isPressing = false
    @State private var isTranscribing = false
    @State private var statusText: String? = nil
    #endif

    var body: some View {
        #if os(iOS)
        pressToTalkButton
        #else
        EmptyView()
        #endif
    }

    #if os(iOS)
    private var pressToTalkButton: some View {
        let isActive = recorder.isRecording || isTranscribing

        return VStack(alignment: .center, spacing: 6) {
            ZStack {
                Circle()
                    .fill(
                        isActive
                            ? Color.red.opacity(0.92)
                            : Color.white.opacity(0.14)
                    )
                    .frame(width: 46, height: 46)

                Circle()
                    .stroke(
                        isActive
                            ? Color.red.opacity(0.45)
                            : Color.white.opacity(0.12),
                        lineWidth: 1
                    )
                    .frame(width: 46, height: 46)

                Image(systemName: recorder.isRecording ? "waveform" : "mic.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(recorder.isRecording ? 1.08 : 1.0)
            .animation(.spareSpring, value: recorder.isRecording)

            if let statusText, !statusText.isEmpty {
                Text(statusText)
                    .font(.spareMicro)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize()
            }
        }
        .contentShape(Rectangle())
        .opacity((disabled || isTranscribing) ? 0.45 : 1)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    beginRecordingIfNeeded()
                }
                .onEnded { _ in
                    finishRecordingIfNeeded()
                }
        )
        .onDisappear {
            recorder.cancel()
        }
    }

    private func beginRecordingIfNeeded() {
        guard !disabled, !isTranscribing, !isPressing, !recorder.isRecording else {
            return
        }

        if let blocker = MasterSpeechTranscriptionAvailability.blockingMessage(for: store.asrConnectionStatus) {
            store.setConversationInlineError(blocker)
            return
        }

        isPressing = true
        statusText = "按住说话"
        dismissKeyboardIfNeeded()

        Task {
            await recorder.start()
            await MainActor.run {
                if recorder.isRecording {
                    statusText = "松开发送"
                    store.setConversationInlineError(nil)
                } else {
                    isPressing = false
                    statusText = nil
                    if let errorMessage = recorder.errorMessage {
                        store.setConversationInlineError(errorMessage)
                    }
                }
            }
        }
    }

    private func finishRecordingIfNeeded() {
        guard isPressing else { return }
        isPressing = false

        guard recorder.isRecording else {
            statusText = nil
            return
        }

        Task {
            await MainActor.run {
                isTranscribing = true
                statusText = "正在识别…"
            }

            do {
                let fileURL = try recorder.finish()
                let existingDraft = await MainActor.run { draftText }
                let flow = MasterSpeechTranscriptionFlow { url in
                    try await store.transcribeAudio(at: url)
                }
                let resolution = await flow.resolve(
                    fileURL: fileURL,
                    existingDraft: existingDraft,
                    cleanupAfterTranscription: true
                )

                if let errorMessage = resolution.errorMessage {
                    await MainActor.run {
                        statusText = nil
                        isTranscribing = false
                        store.setConversationInlineError(errorMessage)
                    }
                    return
                }

                let outgoing = resolution.draft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !outgoing.isEmpty else {
                    await MainActor.run {
                        statusText = nil
                        isTranscribing = false
                        store.setConversationInlineError("语音转写结果为空，未发送。")
                    }
                    return
                }

                await MainActor.run {
                    draftText = ""
                    statusText = "正在发送…"
                    store.setConversationInlineError(nil)
                }

                await store.sendMessage(outgoing)

                await MainActor.run {
                    if store.conversation?.inlineError != nil {
                        draftText = outgoing
                    }
                    statusText = nil
                    isTranscribing = false
                }
            } catch {
                await MainActor.run {
                    statusText = nil
                    isTranscribing = false
                    store.setConversationInlineError("录音失败：\(error.localizedDescription)")
                }
            }
        }
    }

    private func dismissKeyboardIfNeeded() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
    #endif
}

#if os(iOS)
@MainActor
private final class MasterAudioRecorderController: ObservableObject {
    @Published private(set) var isRecording = false
    @Published var errorMessage: String?

    private var recorder: AVAudioRecorder?
    private var recordedFileURL: URL?

    func start() async {
        errorMessage = nil

        do {
            let permitted = await requestPermission()
            guard permitted else {
                errorMessage = "麦克风权限未开启，当前不能录音。"
                return
            }

            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: [.defaultToSpeaker, .allowBluetoothHFP]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let targetURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("master-recording-\(UUID().uuidString)")
                .appendingPathExtension("m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
            ]

            let recorder = try AVAudioRecorder(url: targetURL, settings: settings)
            recorder.isMeteringEnabled = false
            guard recorder.record() else {
                throw MasterASRServiceError.transport("录音启动失败。")
            }

            self.recorder = recorder
            recordedFileURL = targetURL
            isRecording = true
        } catch {
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
