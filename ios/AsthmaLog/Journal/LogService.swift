import UIKit
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
             lateNote: String = "Logged on Apple Watch while your iPhone was away, so there's no air reading.",
             device: InhalerUse.Device = .phone, deviceID: String? = nil,
             in context: ModelContext, writeToHealth: Bool) async -> LogEvent {
        lastError = nil
        let event = LogEvent(moment: moment, loggedAt: date, id: id)
        // An inhaler moment holds its use: which inhaler, one puff so far, how it was logged.
        if moment == .rescue || moment == .maintenance {
            let kind: Inhaler.Kind = moment == .rescue ? .rescue : .controller
            event.uses.append(InhalerUse(at: date, kind: kind, inhaler: Inhaler.current(kind), device: device, deviceID: deviceID))
        }
        context.insert(event)
        try? context.save()

        if Date().timeIntervalSince(date) <= Self.freshness {
            await enrich(event)
        } else {
            event.envStatus = .failed
            event.envError = lateNote
        }
        try? context.save()

        if moment == .rescue && writeToHealth && health.isAvailable {
            do {
                event.healthSampleID = try await health.savePuff(at: event.loggedAt, logID: event.id)
                event.uses.first?.healthSampleID = event.healthSampleID
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
                e.envError = "The app closed before it could check the air."
            }
        }
        try? context.save()
    }

    /// A press from any device. Within 2 minutes of the last press of the same inhaler kind, it's another puff
    /// in that use (and its Health sample is replaced with one more puff); otherwise a new moment.
    /// Returns the moment and whether this press opened it.
    @discardableResult
    func press(_ moment: MomentKind, at date: Date = .now, id: UUID = UUID(), lateNote: String? = nil,
               device: InhalerUse.Device, deviceID: String? = nil, in context: ModelContext) async -> (event: LogEvent, isNew: Bool) {
        let kind: Inhaler.Kind = moment == .rescue ? .rescue : .controller
        let since = date.addingTimeInterval(-InhalerUse.window)
        var recent = FetchDescriptor<LogEvent>(predicate: #Predicate { $0.loggedAt >= since },
                                              sortBy: [SortDescriptor(\.loggedAt, order: .reverse)])
        recent.fetchLimit = 10
        let candidates = (try? context.fetch(recent)) ?? []
        if let e = candidates.first(where: { !$0.isDemo }),
           let use = e.uses.last(where: { $0.kind == kind && date.timeIntervalSince($0.lastPressAt) <= InhalerUse.window && date >= $0.at }) {
            use.puffs += 1
            use.lastPressAt = date
            try? context.save()
            // Health: one sample per use, its value the puffs.
            if let old = use.healthSampleID, kind == .rescue, health.isAvailable {
                try? await health.deletePuff(sampleID: old)
                use.healthSampleID = try? await health.savePuff(at: use.at, logID: e.id, puffs: use.puffs)
                e.healthSampleID = use.healthSampleID
                try? context.save()
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return (e, false)
        }
        let writeToHealth = UserDefaults.standard.object(forKey: Prefs.writeToHealth) as? Bool ?? true
        let e = await log(moment, at: date, id: id,
                          lateNote: lateNote ?? "Logged on Apple Watch while your iPhone was away, so there's no air reading.",
                          device: device, deviceID: deviceID, in: context, writeToHealth: writeToHealth)
        return (e, true)
    }

    /// Undo the last press: one puff off, or the whole moment when it was the only one.
    func undoPress(_ event: LogEvent, in context: ModelContext) async {
        if let use = event.uses.last, use.puffs > 1 {
            use.puffs -= 1
            if let old = use.healthSampleID, health.isAvailable {
                try? await health.deletePuff(sampleID: old)
                use.healthSampleID = try? await health.savePuff(at: use.at, logID: event.id, puffs: use.puffs)
                event.healthSampleID = use.healthSampleID
            }
            try? context.save()
        } else {
            await delete(event, in: context)
        }
    }

    /// A moment logged on Apple Watch. Ignored if it already arrived (the watch can resend).
    func logFromWatch(_ log: WatchLog, in context: ModelContext) async {
        let id = log.id
        let existing = FetchDescriptor<LogEvent>(predicate: #Predicate { $0.id == id })
        if let count = try? context.fetchCount(existing), count > 0 { return }
        let moment: MomentKind = log.kind == .rescue ? .rescue : .maintenance
        let (e, isNew) = await press(moment, at: log.at, id: log.id, device: .watch, in: context)
        if isNew { QuickRecordCenter.shared.notify(for: e) }
    }

    /// A press on the felt button. `ButtonLink` has already dropped resends; the press time comes
    /// from the button (it can queue presses while the phone is away).
    func logFromButton(_ packet: ButtonPacket, receivedAt: Date, deviceID: UUID?, in context: ModelContext) async {
        let moment: MomentKind = packet.cap == .rescue ? .rescue : .maintenance
        let (e, isNew) = await press(moment, at: packet.pressedAt(receivedAt: receivedAt),
                                     lateNote: "Pressed on your felt button while your iPhone was away, so there's no air reading.",
                                     device: .button, deviceID: deviceID?.uuidString, in: context)
        if isNew { QuickRecordCenter.shared.notify(for: e) }
    }

    /// Onboarding's first press (or tap): a baseline moment with its own label, air and place stamped.
    @discardableResult
    func logFirstCapture(in context: ModelContext) async -> LogEvent {
        let e = await log(.okay, in: context, writeToHealth: false)
        e.isFirstCapture = true
        try? context.save()
        return e
    }

    /// Safe to call again (Retry) on a failed or partial log. Conditions are for now, so a retry
    /// on an old log stamps current air — only offer it shortly after logging.
    func enrich(_ event: LogEvent) async {
        event.envStatus = .pending
        event.envError = nil
        // Active in the hour before (a pattern of its own, in the profile's Self family). Needs no location,
        // so a failed fix doesn't lose it.
        await ExertionReader.stamp(event)
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
            if c.observations.isEmpty { event.envError = "Couldn't reach the air services. Open the moment to try again." }
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

    /// Older moments saved before look-back existed: fetch their 48 hours once, a few per app open so it
    /// never floods the air services. Same windows as a new moment, measured back from when it was logged.
    func backfillLookBack(in context: ModelContext, limit: Int = 10) async {
        let ready = EnvStatus.ready.rawValue, partial = EnvStatus.partial.rawValue
        var d = FetchDescriptor<LogEvent>(predicate: #Predicate { $0.envStatusRaw == ready || $0.envStatusRaw == partial },
                                          sortBy: [SortDescriptor(\.loggedAt, order: .reverse)])
        d.fetchLimit = 500
        let todo = ((try? context.fetch(d)) ?? []).filter {
            !$0.isDemo && $0.latitude != nil && $0.longitude != nil && $0.conditions != nil && $0.conditions?.lookBack == nil
        }
        for e in todo.prefix(limit) {
            guard let lat = e.latitude, let lon = e.longitude,
                  let back = await LookBackService.load(latitude: lat, longitude: lon, at: e.loggedAt) else { continue }
            var c = e.conditions
            c?.lookBack = back
            e.conditions = c
        }
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
        // Demo moments don't count: a demo week must neither hold back nor start real baseline samples.
        guard let events = try? context.fetch(recent).filter({ !$0.isDemo }), !events.isEmpty else { return }
        let now = Date()
        let lastBaseline = events.first { $0.moment == .okay }?.loggedAt
        let lastPuff = events.first { $0.moment == .rescue }?.loggedAt
        if let b = lastBaseline, now.timeIntervalSince(b) < 20 * 3600 { return }
        if let p = lastPuff, now.timeIntervalSince(p) < 2 * 3600 { return }
        await log(.baseline, in: context, writeToHealth: false)
    }
}
