// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI
import Speech
import AVFoundation

enum NativeDictationLanguage {
    static let key = "native.dictation-language"
    static let locales = SFSpeechRecognizer.supportedLocales().sorted { $0.identifier < $1.identifier }
    static func resolved(_ identifier: String) -> Locale {
        identifier.isEmpty ? Locale(identifier: Locale.preferredLanguages.first ?? "en-US") : Locale(identifier: identifier)
    }
}

@available(iOS 17.0, *)
struct NativeDictationLanguagePicker: View {
    @AppStorage(NativeDictationLanguage.key) private var language = ""
    @Environment(\.locale) private var locale
    var body: some View {
        Picker(selection: $language) {
            Text(NativeL("跟随系统")).tag("")
            ForEach(NativeDictationLanguage.locales, id: \.identifier) { item in
                Text(locale.localizedString(forIdentifier: item.identifier) ?? item.identifier).tag(item.identifier)
            }
        } label: { Label(NativeL("听写语言"), systemImage: "mic") }
        .accessibilityIdentifier("native.dictationLanguage")
    }
}

struct NativeDictationEdit: Equatable {
    let deleteCount: Int
    let insertion: String
    init(previous: String, next: String) {
        let common = zip(previous, next).prefix { $0 == $1 }.count
        deleteCount = previous.count - common
        insertion = String(next.dropFirst(common))
    }
}

@available(iOS 17.0, *)
@MainActor
final class NativeDictation: ObservableObject {
    private var update: ((String) throws -> Void)?
    @Published private(set) var recording = false
    @Published private(set) var preparing = false
    @Published private(set) var error: String?
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognizer: SFSpeechRecognizer?
    private var recognition: SFSpeechRecognitionTask?
    private var startTask: Task<Void, Never>?
    private var tapped = false
    private var previousAudio: (AVAudioSession.Category, AVAudioSession.Mode, AVAudioSession.CategoryOptions)?

    static func isNormalCompletion(_ error: NSError, finishing: Bool) -> Bool {
        (error.domain == "kAFAssistantErrorDomain" && error.code == 1110)
            || (finishing && error.domain == "kLSRErrorDomain" && error.code == 301)
    }

    func start(language: String, update: @escaping (String) throws -> Void) {
        guard !recording, !preparing else { return }
        error = nil
        self.update = update
        preparing = true
        startTask = Task { [weak self] in
            let speech = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
            }
            guard !Task.isCancelled, let self else { return }
            guard speech == .authorized else { self.fail("请在系统设置中允许语音识别。"); return }
            let microphone = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
            }
            guard !Task.isCancelled else { return }
            guard microphone else { self.fail("请在系统设置中允许麦克风访问。"); return }
            self.begin(language: language)
        }
    }

    private func begin(language: String) {
        guard let recognizer = SFSpeechRecognizer(locale: NativeDictationLanguage.resolved(language)),
              recognizer.supportsOnDeviceRecognition else {
            fail("此语言的本地听写不可用，请选择其他语言或在系统中下载听写语言。"); return
        }
        guard recognizer.isAvailable else { fail("听写暂时不可用，请稍后重试。"); return }
        self.recognizer = recognizer
        do {
            let audio = AVAudioSession.sharedInstance()
            previousAudio = (audio.category, audio.mode, audio.categoryOptions)
            try audio.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .mixWithOthers])
            try audio.setActive(true)
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = true
            request.taskHint = .dictation
            self.request = request
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                fail("没有可用的麦克风。"); return
            }
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }
            tapped = true
            recording = true
            recognition = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let transcript = result?.bestTranscription.formattedString
                let final = result?.isFinal == true
                let failure = error.map { $0 as NSError }
                Task { @MainActor [weak self] in
                    guard let self, self.request === request, self.recording || self.preparing else { return }
                    if let transcript {
                        do { try self.update?(transcript) }
                        catch { self.stop(); self.error = error.localizedDescription; return }
                    }
                    if final { self.stop() }
                    else if let failure {
                        if Self.isNormalCompletion(failure, finishing: self.preparing && !self.recording) { self.stop() }
                        else { self.fail("听写已停止，请重试。") }
                    }
                }
            }
            engine.prepare()
            try engine.start()
            preparing = false
        } catch {
            fail("无法启动本地听写，请检查麦克风和听写语言。");
        }
    }

    func finish() {
        guard recording else { return }
        recording = false; preparing = true
        engine.stop()
        if tapped { engine.inputNode.removeTap(onBus: 0); tapped = false }
        request?.endAudio()
        recognition?.finish()
    }

    func stop() {
        update = nil
        startTask?.cancel(); startTask = nil
        recording = false; preparing = false
        engine.stop()
        if tapped { engine.inputNode.removeTap(onBus: 0); tapped = false }
        request?.endAudio(); request = nil
        recognition?.cancel(); recognition = nil
        recognizer = nil
        if let previousAudio {
            let audio = AVAudioSession.sharedInstance()
            try? audio.setActive(false, options: .notifyOthersOnDeactivation)
            try? audio.setCategory(previousAudio.0, mode: previousAudio.1, options: previousAudio.2)
            self.previousAudio = nil
        }
    }

    private func fail(_ message: String) { stop(); error = message }
}

@available(iOS 17.0, *)
struct NativeDictationButton: View {
    @ObservedObject var model: NativeShellModel
    @StateObject private var dictation = NativeDictation()
    @State private var sentText = ""
    @AppStorage(NativeDictationLanguage.key) private var language = ""
    var body: some View {
        Button {
            if dictation.recording { dictation.finish() }
            else {
                model.canvas?.releaseInput()
                let session = model.currentSessionID
                sentText = ""
                dictation.start(language: language) { text in
                    guard model.connected, model.currentSessionID == session, model.remoteKind == .desktop,
                          model.keyboardAllowed, !model.sessionToggle("view-only") else { dictation.stop(); return }
                    let edit = NativeDictationEdit(previous: sentText, next: text)
                    for _ in 0..<edit.deleteCount { _ = try model.core.call("key", ["value": "VK_BACK"]) }
                    if !edit.insertion.isEmpty { _ = try model.core.call("text", ["value": edit.insertion]) }
                    sentText = text
                }
            }
        } label: {
            Image(systemName: dictation.recording || dictation.preparing ? "pause.fill" : "mic")
                .frame(width: 36, height: 34)
        }
        .accessibilityLabel(NativeL(dictation.recording || dictation.preparing ? "停止听写" : "听写"))
        .accessibilityIdentifier("native.dictation")
        .disabled(dictation.preparing || !model.connected || model.remoteKind != .desktop || !model.keyboardAllowed || model.sessionToggle("view-only"))
        .onDisappear { dictation.stop() }
        .onChange(of: model.currentSessionID) { _, _ in dictation.stop() }
        .onChange(of: model.connected) { _, value in if !value { dictation.stop() } }
        .onChange(of: model.keyboardAllowed) { _, value in if !value { dictation.stop() } }
        .onChange(of: model.sessionToggle("view-only")) { _, value in if value { dictation.stop() } }
        .onChange(of: dictation.error) { _, value in if let value { model.errorMessage = NativeL(value) } }
        .onReceive(NotificationCenter.default.publisher(for: UIScene.didEnterBackgroundNotification)) { notification in
            if let scene = notification.object as? UIWindowScene, scene === model.window?.windowScene { dictation.stop() }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in dictation.stop() }
    }
}
