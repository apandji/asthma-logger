import AVFoundation
import Foundation
import Observation
import Speech

/// Records one short voice note per moment and, while you talk, writes it down live. Audio stays on the phone
/// in Documents/VoiceNotes; the moment keeps the file name. The engine's tap feeds two things at once: the
/// file (AAC) and on-device speech recognition with partial results, so the words appear as they're said
/// (`liveWords`). When live recognition isn't available the file is transcribed afterwards instead.
@Observable
final class VoiceNotes: NSObject, AVAudioPlayerDelegate {
    static let shared = VoiceNotes()

    private(set) var recordingID: UUID?
    private(set) var playingID: UUID?
    private(set) var level: Float = 0
    /// What's been heard so far, updated as you speak. Empty when live recognition is off.
    private(set) var liveWords = ""
    var denied = false

    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var sink: Sink?
    @ObservationIgnored private var player: AVAudioPlayer?

    static let folder: URL = {
        let url = URL.documentsDirectory.appending(path: "VoiceNotes", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    func url(_ file: String) -> URL { Self.folder.appending(path: file) }

    /// Starts recording for this moment; returns false if the microphone isn't allowed.
    func startRecording(for event: LogEvent) async -> Bool {
        stopPlaying()
        guard await AVAudioApplication.requestRecordPermission() else { denied = true; return false }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try? session.setActive(true)
        // Its own file per recording: a moment can have several voice notes.
        let file = "\(event.id.uuidString)-\(Int(Date().timeIntervalSince1970)).m4a"
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0,
              let audioFile = try? AVAudioFile(forWriting: url(file), settings: [
                  AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: format.sampleRate, AVNumberOfChannelsKey: 1,
                  AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
              ], commonFormat: format.commonFormat, interleaved: format.isInterleaved) else { return false }
        // Live words, when speech recognition is allowed and the recogniser is up.
        var request: SFSpeechAudioBufferRecognitionRequest?
        var task: SFSpeechRecognitionTask?
        if await NoteTranscriber.authorize(), let r = SFSpeechRecognizer(), r.isAvailable {
            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            req.requiresOnDeviceRecognition = r.supportsOnDeviceRecognition
            req.addsPunctuation = true
            request = req
            task = r.recognitionTask(with: req) { @Sendable [weak self] result, _ in
                guard let result else { return }
                let text = result.bestTranscription.formattedString
                let final = result.isFinal
                Task { @MainActor in
                    guard let self else { return }
                    self.liveWords = text
                    if final { self.sink?.finish(text) }
                }
            }
        }
        let sink = Sink(file: audioFile, request: request, task: task)
        self.sink = sink
        liveWords = ""
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            sink.take(buffer)
        }
        engine.prepare()
        guard (try? engine.start()) != nil else {
            input.removeTap(onBus: 0)
            sink.close()
            return false
        }
        self.engine = engine
        recordingID = event.id
        event.voiceNoteFile = file
        return true
    }

    /// Stops the microphone. The last words may still be arriving: `finishLive()` waits for them.
    func stopRecording() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        sink?.close()
        recordingID = nil
        level = 0
    }

    /// The final transcript from live recognition, waiting a moment for the recogniser to settle. Nil when
    /// live recognition wasn't running (transcribe the file instead).
    func finishLive() async -> String? {
        guard let sink, sink.request != nil else { self.sink = nil; return nil }
        let text = await sink.finalText(timeout: .seconds(2)) ?? liveWords
        self.sink = nil
        return text.isEmpty ? nil : text
    }

    /// Posted by the audio thread: a smoothed level, 0…1, for the grain.
    fileprivate func post(level: Float) { self.level = level }

    func play(_ event: LogEvent) {
        stopRecording()
        guard let file = event.voiceNoteFile else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(contentsOf: url(file))
        player?.delegate = self
        player?.play()
        playingID = player == nil ? nil : event.id
    }

    func stopPlaying() {
        player?.stop()
        player = nil
        playingID = nil
    }

    func duration(_ event: LogEvent) -> TimeInterval? {
        guard let file = event.voiceNoteFile, let p = try? AVAudioPlayer(contentsOf: url(file)) else { return nil }
        return p.duration
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.playingID = nil }
    }
}

/// Where the tap's buffers go: the file and the recogniser. Lives off the main actor (the tap runs on the
/// audio thread) and guards its state with a lock; the lock is only ever taken in synchronous helpers.
nonisolated private final class Sink: @unchecked Sendable {
    let file: AVAudioFile
    let request: SFSpeechAudioBufferRecognitionRequest?
    private let task: SFSpeechRecognitionTask?
    private let lock = NSLock()
    private var closed = false
    private var frames = 0
    private var final: String?
    private var waiters: [CheckedContinuation<String?, Never>] = []

    init(file: AVAudioFile, request: SFSpeechAudioBufferRecognitionRequest?, task: SFSpeechRecognitionTask?) {
        self.file = file
        self.request = request
        self.task = task
    }

    func take(_ buffer: AVAudioPCMBuffer) {
        lock.lock(); defer { lock.unlock() }
        guard !closed else { return }
        try? file.write(from: buffer)
        request?.append(buffer)
        // The level: RMS of the buffer, every few buffers, to the main actor.
        frames += 1
        if frames % 3 == 0, let data = buffer.floatChannelData?[0] {
            let n = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<n { sum += data[i] * data[i] }
            let rms = n > 0 ? (sum / Float(n)).squareRoot() : 0
            let db = 20 * log10(max(rms, 1e-6))
            let level = max(0, min(1, (db + 50) / 50))
            Task { @MainActor in VoiceNotes.shared.post(level: level) }
        }
    }

    func close() {
        lock.lock(); defer { lock.unlock() }
        guard !closed else { return }
        closed = true
        request?.endAudio()
    }

    /// The recogniser's last word: resolves every waiter.
    func finish(_ text: String) {
        lock.lock()
        final = text
        let w = waiters; waiters = []
        lock.unlock()
        for c in w { c.resume(returning: text) }
    }

    /// Registers a waiter, or resumes it at once when the final text is already in.
    private func wait(_ c: CheckedContinuation<String?, Never>) {
        lock.lock()
        if let final { lock.unlock(); c.resume(returning: final); return }
        waiters.append(c)
        lock.unlock()
    }

    private func drain() -> [CheckedContinuation<String?, Never>] {
        lock.lock(); defer { lock.unlock() }
        let w = waiters; waiters = []
        return w
    }

    func finalText(timeout: Duration) async -> String? {
        await withTaskGroup(of: String?.self) { group in
            group.addTask { [self] in await withCheckedContinuation { c in wait(c) } }
            group.addTask { try? await Task.sleep(for: timeout); return nil }
            let first = await group.next() ?? nil
            group.cancelAll()
            // A waiter left behind by the timeout is resumed with nothing, so nothing leaks.
            for c in drain() { c.resume(returning: nil) }
            task?.cancel()
            return first
        }
    }
}
