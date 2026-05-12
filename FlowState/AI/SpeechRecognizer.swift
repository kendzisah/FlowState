import Foundation
import Speech
import AVFoundation

/// Wraps `SFSpeechRecognizer` + `AVAudioEngine` for live dictation.
/// Emits partial results into `transcript` as they arrive. Caller observes via `@Observable`.
@MainActor
@Observable
final class SpeechRecognizer {
    /// Latest transcribed text. Updates live as the user speaks.
    private(set) var transcript: String = ""
    /// True while audio is actively being captured.
    private(set) var isRecording: Bool = false
    /// Set on permission denial or recognition failure. Caller can surface via UI.
    private(set) var lastError: String?

    @ObservationIgnored
    private let recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer()
    @ObservationIgnored
    private var audioEngine: AVAudioEngine?
    @ObservationIgnored
    private var recognitionTask: SFSpeechRecognitionTask?
    @ObservationIgnored
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

    /// Starts capturing + transcribing. Returns true if recording actually started.
    func start(seedText: String = "") async -> Bool {
        await stop()  // ensure clean state
        lastError = nil
        transcript = seedText

        guard await requestPermissions() else { return false }
        guard let recognizer, recognizer.isAvailable else {
            lastError = "Speech recognition is unavailable on this device or locale."
            return false
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            lastError = "Couldn't start audio session: \(error.localizedDescription)"
            return false
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        recognitionRequest = request

        let engine = AVAudioEngine()
        audioEngine = engine
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            lastError = "Couldn't start microphone: \(error.localizedDescription)"
            await stop()
            return false
        }

        isRecording = true

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            _Concurrency.Task { @MainActor in
                if let result {
                    let prefix = self.transcript.isEmpty ? "" : self.seedPrefix
                    self.transcript = prefix + result.bestTranscription.formattedString
                }
                if error != nil || result?.isFinal == true {
                    await self.stop()
                }
            }
        }
        seedPrefix = transcript.isEmpty ? "" : (transcript + " ")
        return true
    }

    /// Stops capturing. Idempotent.
    func stop() async {
        recognitionTask?.cancel()
        recognitionTask = nil

        if let engine = audioEngine, engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isRecording = false
    }

    // MARK: - Permissions

    private func requestPermissions() async -> Bool {
        let speechStatus: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else {
            lastError = "Speech recognition permission was denied."
            return false
        }

        let micGranted: Bool
        if #available(iOS 17.0, *) {
            micGranted = await AVAudioApplication.requestRecordPermission()
        } else {
            micGranted = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
        if !micGranted {
            lastError = "Microphone permission was denied."
            return false
        }
        return true
    }

    // MARK: - Private state

    @ObservationIgnored
    private var seedPrefix: String = ""
}
