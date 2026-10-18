import AVFoundation
import Foundation
import Observation

/// Records and plays one short voice note per moment. Audio stays on the phone in Documents/VoiceNotes;
/// the moment keeps the file name. Transcription and tags come later (docs/on-device-insights.md).
@Observable
final class VoiceNotes: NSObject, AVAudioPlayerDelegate {
    static let shared = VoiceNotes()

    private(set) var recordingID: UUID?
    private(set) var playingID: UUID?
    private(set) var level: Float = 0
    var denied = false

    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var meter: Timer?

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
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        guard let r = try? AVAudioRecorder(url: url(file), settings: settings) else { return false }
        r.isMeteringEnabled = true
        r.record()
        recorder = r
        recordingID = event.id
        event.voiceNoteFile = file
        meter = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let r = self.recorder else { return }
                r.updateMeters()
                self.level = max(0, min(1, (r.averagePower(forChannel: 0) + 50) / 50))
            }
        }
        return true
    }

    func stopRecording() {
        recorder?.stop()
        recorder = nil
        recordingID = nil
        meter?.invalidate()
        meter = nil
        level = 0
    }

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
