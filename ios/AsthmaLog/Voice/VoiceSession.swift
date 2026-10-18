import AsthmaCore
import Foundation
import Observation
import SwiftData
import UIKit

/// One voice note from the rail (slide into Voice's panel to record, lift to stop). It records into a scratch
/// moment, so nothing is written until you tap Save on the review: your words (editable) and the tags they
/// suggest. Saving attaches them to the moment you're on, or, on Now with nothing logged, to a new Note moment
/// (never in patterns). Same recorder, on-device transcriber and tagger as Quick Record.
@MainActor @Observable
final class VoiceSession {
    enum Phase { case idle, recording, writing, review }

    var phase = Phase.idle
    var startedAt: Date?
    var words = ""
    var suggested: [JournalTag] = []
    var chosen: Set<JournalTag> = []
    var denied = false
    @ObservationIgnored private var scratch: LogEvent?

    /// Starts recording. False when the microphone isn't allowed.
    @discardableResult
    func start() async -> Bool {
        guard phase == .idle || phase == .review else { return false }
        discardScratch()
        _ = await NoteTranscriber.authorize()
        let s = LogEvent(moment: .note)
        guard await VoiceNotes.shared.startRecording(for: s) else { denied = true; return false }
        scratch = s
        startedAt = .now
        phase = .recording
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        return true
    }

    /// Lift: stop, write it down, suggest tags, and wait for Save.
    func finish() async {
        guard phase == .recording else { return }
        VoiceNotes.shared.stopRecording()
        phase = .writing
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        // The words were written down as you spoke; the file is only transcribed when live recognition was off.
        var text = await VoiceNotes.shared.finishLive()
        if text == nil, let file = scratch?.voiceNoteFile { text = await NoteTranscriber.transcribe(VoiceNotes.shared.url(file)) }
        if let text {
            words = text
            let result = await VoiceNoteTagger.suggest(transcript: text, using: ModelTagProposer())
            suggested = result.suggestions.map(\.tag)
            chosen = Set(suggested)
        }
        phase = .review
    }

    /// Slid back out before lifting: nothing kept.
    func cancel() {
        if phase == .recording { VoiceNotes.shared.stopRecording() }
        discardScratch()
        reset()
    }

    /// Writes the words, recording and tags to `target`, or to a new Note moment from `makeNote`.
    func save(into target: LogEvent?, makeNote: () async -> LogEvent?, context: ModelContext) async {
        guard phase == .review else { return }
        var made: LogEvent?
        if target == nil { made = await makeNote() }
        guard let e = target ?? made else { return }
        // One more voice note on the moment (several are fine; a note during a rescue goes into it).
        e.addNote(file: scratch?.voiceNoteFile, transcript: words, source: "rail", at: startedAt ?? .now)
        e.tags.formUnion(chosen)
        e.tagsReviewed = true
        try? context.save()
        QuickRecordCenter.shared.scheduleEvening()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        scratch = nil   // the file now belongs to the moment
        reset()
    }

    /// Redo / close the review without saving.
    func discard() {
        discardScratch()
        reset()
    }

    private func discardScratch() {
        if let file = scratch?.voiceNoteFile { try? FileManager.default.removeItem(at: VoiceNotes.shared.url(file)) }
        scratch = nil
    }

    private func reset() {
        phase = .idle; startedAt = nil; words = ""; suggested = []; chosen = []
    }
}
