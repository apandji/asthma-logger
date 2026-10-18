import AsthmaCore
import Foundation
import Observation
import SwiftData
import UIKit

/// One note being captured for a moment, behind both capture styles (Crit.CaptureStyle):
/// - **chat**: a short interview, one question at a time (`Interview`), each answer spoken, typed or tapped;
/// - **journal**: the classic form, your words at the top and the same questions as sections of chips.
/// Same recorder and live words as the rail (`VoiceNotes`), same tagger. Tags are heard while you talk and,
/// with Crit.AutoSelect on, ticked as they're heard; untick one and it stays unticked. Nothing is written
/// until `save`; closing with anything said saves it (your words are never thrown away by a swipe).
@MainActor @Observable
final class CaptureSession: Identifiable {
    enum Turn: Identifiable, Equatable {
        case question(Interview.Question)
        case answer(UUID, String)
        case heard(UUID, [JournalTag])

        var id: String {
            switch self {
            case .question(let q): "q-\(q.rawValue)"
            case .answer(let u, _): "a-\(u)"
            case .heard(let u, _): "h-\(u)"
            }
        }
    }

    private struct Answer {
        var question: Interview.Question?
        var text: String
        var file: String?
        var at: Date
    }

    let id = UUID()
    let event: LogEvent
    private(set) var turns: [Turn] = []
    private(set) var question: Interview.Question?
    private(set) var listening = false
    private(set) var writing = false
    private(set) var done = false
    var denied = false
    /// Ticked tags (start from what the moment already has).
    private(set) var chosen: Set<JournalTag>
    /// Heard but not ticked (Crit.AutoSelect off): shown as suggestions to confirm.
    private(set) var suggested: Set<JournalTag> = []
    /// Unticked by you: never ticked again by what's heard.
    private(set) var removed: Set<JournalTag> = []
    /// Ticked in the last moment, for the chip's arrival.
    private(set) var justHeard: Set<JournalTag> = []
    /// The journal style's words: editable, and live words land here when the mic stops.
    var journalWords = ""
    private(set) var startedAt: Date?

    @ObservationIgnored private var answers: [Answer] = []
    /// What was ticked or suggested when this answer started: the "Heard" row is what's new since.
    @ObservationIgnored private var beforeAnswer: Set<JournalTag>?
    @ObservationIgnored private var asked: [Interview.Question] = []
    @ObservationIgnored private var scratch: LogEvent?
    @ObservationIgnored private let autoSelect: Bool
    @ObservationIgnored private let source: String
    @ObservationIgnored private let tick = UISelectionFeedbackGenerator()
    #if DEBUG
    /// `-fakeWords "first answer|second answer"`: words typed in as if heard, for the simulator (no mic).
    private(set) var fakeLive = ""
    @ObservationIgnored private var fakeTask: Task<Void, Never>?
    #endif

    init(event: LogEvent, chat: Bool, autoSelect: Bool) {
        self.event = event
        self.autoSelect = autoSelect
        source = chat ? "chat" : "journal"
        chosen = event.tags
        // A/B test A3: the opener rotates, or is always "What were you doing?".
        let q = UserDefaults.standard.string(forKey: "crit.opener") == "fixed" ? Interview.Question.doing
            : Interview.first(seed: Int(event.loggedAt.timeIntervalSince1970 / 60), isRescue: event.moment == .rescue)
        ask(q)
    }

    /// What's being said right now.
    var live: String {
        #if DEBUG
        if !fakeLive.isEmpty { return fakeLive }
        #endif
        return VoiceNotes.shared.liveWords
    }

    var hasAnything: Bool { !answers.isEmpty || !journalWords.trimmingCharacters(in: .whitespaces).isEmpty || chosen != event.tags }

    // MARK: Listening

    func startListening() async {
        guard !listening, !writing else { return }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        startedAt = .now
        beforeAnswer = chosen.union(suggested)
        #if DEBUG
        if let fake = Self.fakeAnswer(answers.count) {
            listening = true
            fakeTask = Task { [weak self] in
                for word in fake.split(separator: " ") {
                    try? await Task.sleep(for: .milliseconds(140))
                    guard let self, !Task.isCancelled else { return }
                    self.fakeLive += (self.fakeLive.isEmpty ? "" : " ") + word
                    self.hear(self.fakeLive)
                }
            }
            return
        }
        #endif
        _ = await NoteTranscriber.authorize()
        let s = LogEvent(moment: .note)
        guard await VoiceNotes.shared.startRecording(for: s) else { denied = true; return }
        scratch = s
        listening = true
    }

    /// Stops, writes it down, and takes it as the answer (chat) or adds it to your words (journal).
    func stopListening() async {
        guard listening else { return }
        listening = false
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        var text: String?
        var file: String?
        #if DEBUG
        if fakeTask != nil {
            fakeTask?.cancel(); fakeTask = nil
            text = fakeLive; fakeLive = ""
        }
        #endif
        if text == nil {
            writing = true
            VoiceNotes.shared.stopRecording()
            file = scratch?.voiceNoteFile
            text = await VoiceNotes.shared.finishLive()
            if text == nil, let file { text = await NoteTranscriber.transcribe(VoiceNotes.shared.url(file)) }
            writing = false
            scratch = nil
        }
        let words = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if source == "journal" {
            if !words.isEmpty { journalWords = journalWords.isEmpty ? words : journalWords + " " + words }
            if let file { answers.append(Answer(question: nil, text: "", file: file, at: startedAt ?? .now)) }
            hear(journalWords)
        } else {
            answer(words, file: file)
        }
    }

    /// While you talk: tags heard so far are ticked (or suggested), unless you've unticked them.
    func hear(_ text: String) {
        var heard = Set(KeywordTagger.scan(text).tags).subtracting(removed)
        if let q = question, q.isYesNo, Interview.yesNo(text) == true, let t = q.yesTag { heard.insert(t) }
        let fresh = heard.subtracting(chosen).subtracting(suggested)
        guard !fresh.isEmpty else { return }
        if autoSelect { chosen.formUnion(fresh) } else { suggested.formUnion(fresh) }
        justHeard = fresh
        tick.selectionChanged()
    }

    // MARK: Chat

    /// A spoken or typed answer to the current question.
    func answer(_ text: String, file: String? = nil) {
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty || file != nil else { return }
        let before = beforeAnswer ?? chosen.union(suggested)
        beforeAnswer = nil
        hear(words)
        answers.append(Answer(question: question, text: words, file: file, at: startedAt ?? .now))
        turns.append(.answer(UUID(), words.isEmpty ? "…" : words))
        let heard = chosen.union(suggested).subtracting(before)
        if !heard.isEmpty { turns.append(.heard(UUID(), JournalTag.allCases.filter { heard.contains($0) })) }
        advance()
    }

    /// A tapped reply chip. Tags toggle (several can be on); yes / no / none answer and move on.
    func reply(_ r: Interview.Reply) {
        switch r {
        case .tag(let t): toggle(t)
        case .yes:
            if let t = question?.yesTag { chosen.insert(t); removed.remove(t) }
            post("Yes")
        case .no:
            if let t = question?.yesTag { chosen.remove(t) }
            post("No")
        case .none: post("None of these")
        }
    }

    /// The tags picked for this question, sent as the answer.
    func sendPicked() {
        guard let q = question else { return }
        let picked = Interview.replies(q).compactMap { r -> JournalTag? in
            if case .tag(let t) = r, chosen.contains(t) { return t }
            return nil
        }
        post(picked.isEmpty ? "None of these" : picked.map(\.label).joined(separator: ", "))
    }

    /// The tags this question offers that are ticked.
    var pickedForQuestion: Bool {
        guard let q = question else { return false }
        return Interview.replies(q).contains { if case .tag(let t) = $0 { chosen.contains(t) } else { false } }
    }

    private func post(_ text: String) {
        answers.append(Answer(question: question, text: text, file: nil, at: .now))
        turns.append(.answer(UUID(), text))
        advance()
    }

    private func advance() {
        let words = answers.map(\.text).joined(separator: " ")
        let c = Interview.Context(asked: asked, tags: chosen.union(suggested), words: words,
                                  hour: Calendar.current.component(.hour, from: event.loggedAt),
                                  puffs: event.puffs, isRescue: event.moment == .rescue)
        if let q = Interview.next(c) { ask(q) } else { question = nil; done = true }
    }

    private func ask(_ q: Interview.Question) {
        question = q
        asked.append(q)
        turns.append(.question(q))
    }

    // MARK: Tags

    func toggle(_ t: JournalTag) {
        if chosen.contains(t) {
            chosen.remove(t); removed.insert(t)
        } else {
            chosen.insert(t); suggested.remove(t); removed.remove(t)
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    // MARK: Save

    /// Every answer becomes a voice note on the moment (with the question it answered), the ticked tags
    /// become the moment's, and the moment counts as reviewed for the tag bins.
    func save(context: ModelContext) {
        if listening { VoiceNotes.shared.stopRecording(); listening = false }
        if source == "journal" {
            let file = answers.last(where: { $0.file != nil })?.file
            let words = journalWords.trimmingCharacters(in: .whitespacesAndNewlines)
            if !words.isEmpty || file != nil { event.addNote(file: file, transcript: words, source: source, at: startedAt ?? .now) }
        } else {
            for a in answers where !a.text.isEmpty || a.file != nil {
                event.addNote(file: a.file, transcript: a.text, source: source, at: a.at, question: a.question?.text)
            }
        }
        event.tags = chosen
        event.tagsReviewed = true
        try? context.save()
        QuickRecordCenter.shared.scheduleEvening()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        answers = []
    }

    /// Nothing said and nothing ticked: throw the recordings away.
    func discard() {
        if listening { VoiceNotes.shared.stopRecording(); listening = false }
        for a in answers { if let f = a.file { try? FileManager.default.removeItem(at: VoiceNotes.shared.url(f)) } }
        if let f = scratch?.voiceNoteFile { try? FileManager.default.removeItem(at: VoiceNotes.shared.url(f)) }
        answers = []
    }

    #if DEBUG
    private static func fakeAnswer(_ i: Int) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let k = args.firstIndex(of: "-fakeWords"), k + 1 < args.count else { return nil }
        let parts = args[k + 1].split(separator: "|").map(String.init)
        return parts.isEmpty ? nil : parts[min(i, parts.count - 1)]
    }
    #endif
}
