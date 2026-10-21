import AsthmaCore
import Foundation
import SwiftData

/// Asks Health and Motion about the time before a moment and stamps `exerted` / `exertedBy` (AsthmaCore
/// `Exertion.decide`). One place for a live log, a filled-in baseline and the one-time re-stamp, so they
/// all read the same way. Each source fails open: what it can't say is missing, never "not active".
@MainActor
enum ExertionReader {
    struct Result {
        var reading: Exertion.Reading
        var decision: Exertion.Decision
        /// Plain notes on what each source returned, for Settings › Exertion check (Debug only).
        var healthNote: String
        var motionNote: String
    }

    static func read(before date: Date) async -> Result {
        let h = await HealthReader.shared.activity(before: date)
        let m = await MotionService().vigorous(before: date)
        let r = Exertion.Reading(workout: h.workout, workoutKind: h.kind, runningMinutes: m.running,
                                 cyclingMinutes: m.cycling, steps: h.steps)
        return Result(reading: r, decision: Exertion.decide(r), healthNote: h.note, motionNote: m.note)
    }

    /// Stamps a moment. The Settings › Demo triggers switch marks it active from a walk instead (no reads).
    static func stamp(_ e: LogEvent, demo: Bool = UserDefaults.standard.bool(forKey: demoKey)) async {
        if demo {
            e.exerted = true
            e.exertedBy = .workout(.walk)
            return
        }
        let d = await read(before: e.loggedAt).decision
        e.exerted = d.active
        e.exertedBy = d.source
    }

    static let demoKey = "demo.active"
    private static let restampKey = "exertion.restamped.v1"

    /// One time: real moments logged before exertion was stamped (or whose sources said nothing then) get
    /// it from Health and Motion history. Motion keeps about a week, Health keeps everything. Runs once
    /// per install unless `force` (Settings › Exertion check › Re-stamp). Returns how many changed.
    @discardableResult
    static func restampIfNeeded(in context: ModelContext, force: Bool = false) async -> Int {
        guard force || !UserDefaults.standard.bool(forKey: restampKey), DataSets.active == nil else { return 0 }
        // Wait until Health has been asked: before that every read is "can't say", and the one chance is spent.
        guard !(await HealthReader.shared.shouldAsk()) || force else { return 0 }
        let all = (try? context.fetch(FetchDescriptor<LogEvent>())) ?? []
        var changed = 0
        for e in all where !e.isDemo && e.exerted == nil {
            let d = await read(before: e.loggedAt).decision
            guard d.active != nil else { continue }
            e.exerted = d.active
            e.exertedBy = d.source
            changed += 1
        }
        try? context.save()
        UserDefaults.standard.set(true, forKey: restampKey)
        return changed
    }
}
