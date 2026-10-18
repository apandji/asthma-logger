import AVFoundation
import Foundation
import Speech

/// Live, on-device transcription with Apple's newer speech model (`SpeechAnalyzer` + `SpeechTranscriber`, the
/// one Notes and Voice Memos use). Much better than `SFSpeechRecognizer` at long, natural speech. Words arrive
/// as they're said: finalised phrases accumulate, the phrase still being heard is replaced as it firms up.
/// Audio is converted to the model's format on the audio thread and never leaves the phone.
/// `make` returns nil when the model isn't on this phone yet (or the language isn't supported): the caller
/// falls back to `SFSpeechRecognizer`. `prepare()` fetches the model ahead of time so the first note has it.
nonisolated final class LiveTranscriber: @unchecked Sendable {
    private let transcriber: SpeechTranscriber
    private let analyzer: SpeechAnalyzer
    private let format: AVAudioFormat
    private let input: AsyncStream<AnalyzerInput>
    private let feed: AsyncStream<AnalyzerInput>.Continuation
    private let onText: @Sendable (String) -> Void
    private let lock = NSLock()
    private var converter: AVAudioConverter?
    private var finalized = ""
    private var volatile = ""
    private var results: Task<Void, Never>?

    /// Words felt air listens for, so they're heard as themselves ("wheeze", not "we's").
    static let vocabulary = [
        "inhaler", "rescue inhaler", "puff", "puffs", "albuterol", "Ventolin", "wheeze", "wheezing", "tight chest",
        "short of breath", "cough", "coughing", "asthma", "pollen", "ragweed", "mold", "ozone", "smoke", "wildfire",
        "humid", "cold air", "dust", "pets", "cat", "dog", "exercise", "stairs", "flare",
    ]

    /// Downloads the speech model for this language if it isn't on the phone yet. Safe to call often.
    static func prepare() async {
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current) else { return }
        let t = SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [.volatileResults], attributeOptions: [])
        if let request = try? await AssetInventory.assetInstallationRequest(supporting: [t]) {
            try? await request.downloadAndInstall()
        }
    }

    static func make(onText: @escaping @Sendable (String) -> Void) async -> LiveTranscriber? {
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current) else { return nil }
        let t = SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [.volatileResults], attributeOptions: [])
        // Not installed yet: don't make someone wait mid-flare. Fall back now, fetch for next time.
        if (try? await AssetInventory.assetInstallationRequest(supporting: [t])) != nil {
            Task.detached(priority: .utility) { await prepare() }
            return nil
        }
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [t]) else { return nil }
        let analyzer = SpeechAnalyzer(modules: [t])
        let live = LiveTranscriber(transcriber: t, analyzer: analyzer, format: format, onText: onText)
        do {
            let context = AnalysisContext()
            context.contextualStrings[.general] = vocabulary
            try? await analyzer.setContext(context)
            try await analyzer.start(inputSequence: live.input)
        } catch {
            return nil
        }
        live.listen()
        return live
    }

    private init(transcriber: SpeechTranscriber, analyzer: SpeechAnalyzer, format: AVAudioFormat,
                 onText: @escaping @Sendable (String) -> Void) {
        self.transcriber = transcriber
        self.analyzer = analyzer
        self.format = format
        self.onText = onText
        (input, feed) = AsyncStream<AnalyzerInput>.makeStream()
    }

    private func listen() {
        results = Task { [weak self] in
            guard let self else { return }
            do {
                for try await result in transcriber.results {
                    let words = String(result.text.characters)
                    let text = update(words, final: result.isFinal)
                    onText(text)
                }
            } catch {}
        }
    }

    /// Final phrases append; the phrase still being heard replaces the last one.
    private func update(_ words: String, final: Bool) -> String {
        lock.lock(); defer { lock.unlock() }
        if final {
            let w = words.trimmingCharacters(in: .whitespaces)
            if !w.isEmpty { finalized += (finalized.isEmpty ? "" : " ") + w }
            volatile = ""
        } else {
            volatile = words.trimmingCharacters(in: .whitespaces)
        }
        return [finalized, volatile].filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// From the audio thread: converted to the model's format (a copy, so the tap can reuse its buffer).
    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        if converter == nil { converter = AVAudioConverter(from: buffer.format, to: format) }
        let converter = self.converter
        lock.unlock()
        guard let converter else { return }
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 32)
        guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return }
        var fed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if fed { status.pointee = .noDataNow; return nil }
            fed = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, out.frameLength > 0 else { return }
        feed.yield(AnalyzerInput(buffer: out))
    }

    /// The mic has stopped: let the model finish the last phrase (up to a few seconds), then the full text.
    func finish() async -> String? {
        feed.finish()
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [analyzer] in try? await analyzer.finalizeAndFinishThroughEndOfInput() }
            group.addTask { try? await Task.sleep(for: .seconds(3)) }
            await group.next()
            group.cancelAll()
        }
        results?.cancel()
        let text = current()
        return text.isEmpty ? nil : text
    }

    private func current() -> String {
        lock.lock(); defer { lock.unlock() }
        return [finalized, volatile].filter { !$0.isEmpty }.joined(separator: " ")
    }
}
