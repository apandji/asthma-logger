import Observation
import AsthmaCore
import CoreLocation
import Foundation
import SwiftData

/// Logging pipeline: save immediately (works offline), then stamp place, indoor/outdoor and conditions.
@Observable
final class LogService {
    let location = LocationService()
    let motion = MotionService()
    let conditions = ConditionsService()
    let health = HealthWriter()

    var lastError: String?
    private var isSampling = false

    @discardableResult
    func log(_ kind: FrameKind, in context: ModelContext, writeToHealth: Bool) async -> LogEvent {
        await log(MomentKind(kind), in: context, writeToHealth: writeToHealth)
    }

    /// Conditions are fetched for "now", so a moment that arrives late (e.g. queued on the watch while the
    /// phone was away) is saved without them rather than stamped with the wrong air.
    static let freshness: TimeInterval = 15 * 60

    @discardableResult
    func log(_ moment: MomentKind, at date: Date = .now, id: UUID = UUID(),
             in context: ModelContext, writeToHealth: Bool) async -> LogEvent {
        let event = LogEvent(moment: moment, loggedAt: date, id: id)
        context.insert(event)
        try? context.save()

        if Date().timeIntervalSince(date) <= Self.freshness {
            await enrich(event)
        } else {
            event.envStatus = .failed
            event.envError = "Logged on Apple Watch while your iPhone was away, so felt air couldn't note the air at that time."
        }
        try? context.save()

        if moment == .rescue && writeToHealth && health.isAvailable {
            do {
                event.healthSampleID = try await health.savePuff(at: event.loggedAt, logID: event.id)
            } catch {
                lastError = "Apple Health: \(error.localizedDescription)"
            }
        }
        try? context.save()
        return event
    }

    /// Moments left "noting the air" when the app was closed: retry if still fresh, otherwise say so.
    func resumePending(in context: ModelContext) async {
        let pending = EnvStatus.pending.rawValue
        let stuck = (try? context.fetch(FetchDescriptor<LogEvent>(predicate: #Predicate { $0.envStatusRaw == pending }))) ?? []
        for e in stuck {
            if Date().timeIntervalSince(e.loggedAt) <= Self.freshness {
                await enrich(e)
            } else {
                e.envStatus = .failed
                e.envError = "felt air was closed before it could note the air for this moment."
            }
        }
        try? context.save()
    }

    /// A moment logged on Apple Watch. Ignored if it already arrived (the watch can resend).
    func logFromWatch(_ log: WatchLog, in context: ModelContext) async {
        let id = log.id
        let existing = FetchDescriptor<LogEvent>(predicate: #Predicate { $0.id == id })
        if let count = try? context.fetchCount(existing), count > 0 { return }
        let moment: MomentKind = log.kind == .rescue ? .rescue : .maintenance
        let writeToHealth = UserDefaults.standard.object(forKey: Prefs.writeToHealth) as? Bool ?? true
        await self.log(moment, at: log.at, id: log.id, in: context, writeToHealth: writeToHealth)
    }

    /// Safe to call again (Retry) on a failed or partial log. Conditions are for now, so a retry
    /// on an old log stamps current air — only offer it shortly after logging.
    func enrich(_ event: LogEvent) async {
        event.envStatus = .pending
        event.envError = nil
        do {
            let fix = try await location.currentLocation()
            event.latitude = fix.coordinate.latitude
            event.longitude = fix.coordinate.longitude
            event.horizontalAccuracy = fix.horizontalAccuracy
            event.floorLevel = fix.floor?.level

            let state = await motion.recent()
            event.apply(IndoorOutdoorGuesser.guess(IndoorSignals(
                horizontalAccuracyM: fix.horizontalAccuracy, atPlace: nil, motion: state, floorLevel: fix.floor?.level
            )))

            let c = await conditions.conditions(latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude)
            event.conditions = c
            event.envStatus = c.observations.isEmpty ? .failed : (c.errors.isEmpty ? .ready : .partial)
            if c.observations.isEmpty { event.envError = c.errors.joined(separator: "\n") }
        } catch {
            event.envStatus = .failed
            event.envError = error.localizedDescription
        }
    }

    func delete(_ event: LogEvent, in context: ModelContext) async {
        if let id = event.healthSampleID {
            try? await health.deletePuff(sampleID: id)
        }
        context.delete(event)
        try? context.save()
    }

    /// Usual-day sample (docs/predictive-engine.md §4): on app open, if there's been no usual-day
    /// sample in 20 h and no puff in the last 2 h. Only after the first log, so the first launch
    /// doesn't open with a location prompt.
    func sampleUsualDayIfDue(in context: ModelContext) async {
        guard !isSampling else { return }
        isSampling = true
        defer { isSampling = false }
        var recent = FetchDescriptor<LogEvent>(sortBy: [SortDescriptor(\.loggedAt, order: .reverse)])
        recent.fetchLimit = 200
        guard let events = try? context.fetch(recent), !events.isEmpty else { return }
        let now = Date()
        let lastBaseline = events.first { $0.moment == .okay }?.loggedAt
        let lastPuff = events.first { $0.moment == .rescue }?.loggedAt
        if let b = lastBaseline, now.timeIntervalSince(b) < 20 * 3600 { return }
        if let p = lastPuff, now.timeIntervalSince(p) < 2 * 3600 { return }
        await log(.baseline, in: context, writeToHealth: false)
    }
}
