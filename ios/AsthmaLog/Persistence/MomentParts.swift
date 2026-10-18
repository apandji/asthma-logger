import AsthmaCore
import Foundation
import SwiftData

/// One use of an inhaler inside a moment (docs/data-model.md): which inhaler, how many puffs (presses within
/// the 2-minute event window add up), and how it was logged (which felt button, the watch, the phone).
@Model
final class InhalerUse {
    @Attribute(.unique) var id: UUID
    /// The first press.
    var at: Date
    /// The latest press: the window runs from here.
    var lastPressAt: Date
    var puffs: Int
    /// "rescue" or "controller": a property of the inhaler, copied here so old uses keep their meaning if the
    /// inhaler is renamed or removed.
    var kindRaw: String
    var inhalerID: UUID?
    var inhalerName: String?
    /// "button", "watch", "phone" or "unknown" (moments from before uses existed).
    var deviceRaw: String
    /// The felt button's id, when a button logged it.
    var deviceID: String?
    var healthSampleID: UUID?
    var moment: LogEvent?

    init(at: Date, kind: Inhaler.Kind, inhaler: Inhaler?, device: Device, deviceID: String? = nil, puffs: Int = 1) {
        id = UUID()
        self.at = at
        lastPressAt = at
        self.puffs = puffs
        kindRaw = kind.rawValue
        inhalerID = inhaler?.id
        inhalerName = inhaler?.name
        deviceRaw = device.rawValue
        self.deviceID = deviceID
    }

    enum Device: String { case button, watch, phone, unknown }

    var kind: Inhaler.Kind { Inhaler.Kind(rawValue: kindRaw) ?? .rescue }

    /// Presses this close to the last one add a puff to this use (owner decision, PR #51).
    static let window: TimeInterval = 120
}

/// One voice note on a moment. A moment can have several (a note during a rescue goes into that moment).
@Model
final class VoiceNote {
    @Attribute(.unique) var id: UUID
    var recordedAt: Date
    var audioFile: String?
    var transcript: String
    /// "rail", "lock_screen", "quick_record", "chat", "journal" or "unknown" (from before notes existed).
    var sourceRaw: String
    /// The question it answered, in the chat capture ("Did it wake you up?"). Nil for a free note.
    var question: String?
    var moment: LogEvent?

    init(recordedAt: Date, audioFile: String?, transcript: String, source: String) {
        id = UUID()
        self.recordedAt = recordedAt
        self.audioFile = audioFile
        self.transcript = transcript
        sourceRaw = source
    }
}

/// An inhaler you use, named in onboarding and renamed in Settings › Devices. Rescue or controller is a
/// property of the medicine, not of a moment. Kept in UserDefaults (two, for now: one of each kind).
nonisolated struct Inhaler: Codable, Identifiable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable { case rescue, controller }

    var id: UUID
    var name: String
    var kind: Kind

    static let key = "inhalers"

    static func load() -> [Inhaler] {
        if let data = UserDefaults.standard.data(forKey: key), let list = try? JSONDecoder().decode([Inhaler].self, from: data), !list.isEmpty {
            return list
        }
        return [Inhaler(id: UUID(), name: "Rescue inhaler", kind: .rescue), Inhaler(id: UUID(), name: "Daily inhaler", kind: .controller)]
    }

    static func save(_ list: [Inhaler]) {
        if let data = try? JSONEncoder().encode(list) { UserDefaults.standard.set(data, forKey: key) }
    }

    /// The inhaler for a kind (the orange cap logs the rescue inhaler, the teal cap the daily one).
    static func current(_ kind: Kind) -> Inhaler {
        let list = load()
        if UserDefaults.standard.data(forKey: key) == nil { save(list) }   // stable ids from the first use on
        return list.first { $0.kind == kind } ?? list[0]
    }
}

extension LogEvent {
    /// Adds a voice note, and keeps the moment's combined words (what tags and the read use) in step.
    func addNote(file: String?, transcript: String, source: String, at: Date = .now, question: String? = nil) {
        let n = VoiceNote(recordedAt: at, audioFile: file, transcript: transcript, source: source)
        n.question = question
        notes.append(n)
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            let before = (voiceTranscript ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            voiceTranscript = before.isEmpty ? text : before + "\n" + text
        }
        if let file { voiceNoteFile = file }
    }

    /// Puffs across this moment's uses.
    var puffs: Int { uses.reduce(0) { $0 + $1.puffs } }
}

/// The one-time upgrade to uses and notes: every inhaler moment gets one use (one puff, its kind's inhaler,
/// device unknown, its Health sample), every recorded note a VoiceNote. Additive and idempotent: nothing is
/// deleted, and running it again changes nothing.
enum ModelUpgrade {
    static let key = "model.usesAndNotes"

    static func run(_ context: ModelContext, force: Bool = false) {
        guard force || !UserDefaults.standard.bool(forKey: key) else { return }
        let all = (try? context.fetch(FetchDescriptor<LogEvent>())) ?? []
        for e in all {
            if (e.moment == .rescue || e.moment == .maintenance) && e.uses.isEmpty {
                let kind: Inhaler.Kind = e.moment == .rescue ? .rescue : .controller
                let use = InhalerUse(at: e.loggedAt, kind: kind, inhaler: Inhaler.current(kind), device: .unknown)
                use.healthSampleID = e.healthSampleID
                e.uses.append(use)
            }
            let words = (e.voiceTranscript ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if e.notes.isEmpty && (e.voiceNoteFile != nil || !words.isEmpty) {
                e.notes.append(VoiceNote(recordedAt: e.loggedAt, audioFile: e.voiceNoteFile, transcript: words, source: "unknown"))
            }
        }
        try? context.save()
        UserDefaults.standard.set(true, forKey: key)
    }
}

/// Until the Ambee key arrives, moments logged before the sample was wired in get Ambee's sample for their
/// hour (pollen and air, labelled "Ambee (demo)", never in patterns), so every moment shows what Ambee will
/// give. Additive and idempotent: a moment that already has an Ambee reading is left alone. Stops once
/// there's a key (real Ambee readings arrive with new moments; old ones keep their sample label).
enum AmbeeSampleFill {
    static func run(_ context: ModelContext) {
        guard Secrets.ambee == nil else { return }
        let all = (try? context.fetch(FetchDescriptor<LogEvent>())) ?? []
        var changed = false
        for e in all {
            guard let lat = e.latitude, let lon = e.longitude, var c = e.conditions,
                  !c.observations.contains(where: { $0.source == Ambee.demoSource || $0.source.hasPrefix("Ambee") }) else { continue }
            let hour = DemoAmbee().hour(lat, lon, e.loggedAt, forecast: false)
            c.observations += hour.observations(source: Ambee.demoSource)
            e.conditions = c
            changed = true
        }
        if changed { try? context.save() }
    }
}
