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
        let event = LogEvent(kind: kind)
        context.insert(event)
        try? context.save()

        if kind == .attack && writeToHealth && health.isAvailable {
            do {
                event.healthSampleID = try await health.savePuff(at: event.loggedAt, logID: event.id)
            } catch {
                lastError = "Apple Health: \(error.localizedDescription)"
            }
        }
        await enrich(event)
        try? context.save()
        return event
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
        let lastBaseline = events.first { $0.kind == .baseline }?.loggedAt
        let lastPuff = events.first { $0.kind == .attack }?.loggedAt
        if let b = lastBaseline, now.timeIntervalSince(b) < 20 * 3600 { return }
        if let p = lastPuff, now.timeIntervalSince(p) < 2 * 3600 { return }
        await log(.baseline, in: context, writeToHealth: false)
    }
}
