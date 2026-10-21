import Observation
import CoreLocation
import CoreMotion
import AsthmaCore

enum LocationError: LocalizedError {
    case denied
    case unavailable

    var errorDescription: String? {
        switch self {
        case .denied: "Location is off for felt air. Turn it on in Settings → Privacy → Location Services."
        case .unavailable: "Couldn't find where you are."
        }
    }
}

/// One precise fix per log. Uses the async CoreLocation API, no delegate.
@Observable
final class LocationService {
    private var session: CLServiceSession?
    private(set) var lastFix: CLLocation?

    /// Waits for a fix of ±65 m or better, or returns the best one seen when `timeout` runs out.
    func currentLocation(timeout: Duration = .seconds(5)) async throws -> CLLocation {
        if session == nil {
            session = CLServiceSession(authorization: .whenInUse)
        }
        let box = BestFix()
        let updates = Task {
            for try await update in CLLocationUpdate.liveUpdates() {
                if update.authorizationDenied || update.authorizationDeniedGlobally {
                    box.denied = true
                    return
                }
                if let loc = update.location {
                    box.offer(loc)
                    if loc.horizontalAccuracy <= 65 { return }  // indoors rarely beats ~50 m; good enough for outdoor air
                }
            }
        }
        let timer = Task {
            try? await Task.sleep(for: timeout)
            updates.cancel()
        }
        _ = await updates.result
        timer.cancel()

        if box.denied { throw LocationError.denied }
        guard let best = box.best else { throw LocationError.unavailable }
        lastFix = best
        return best
    }

    private final class BestFix {
        var best: CLLocation?
        var denied = false

        func offer(_ loc: CLLocation) {
            guard loc.horizontalAccuracy >= 0 else { return }
            if best == nil || loc.horizontalAccuracy < best!.horizontalAccuracy { best = loc }
        }
    }
}

/// Most recent motion activity (walking, driving, still…), used to guess indoors vs outdoors.
final class MotionService {
    private let manager = CMMotionActivityManager()

    func recent(window: TimeInterval = 5 * 60) async -> MotionState {
        guard CMMotionActivityManager.isActivityAvailable() else { return .unknown }
        let now = Date()
        return await withCheckedContinuation { continuation in
            manager.queryActivityStarting(from: now.addingTimeInterval(-window), to: now, to: .main) { activities, _ in
                continuation.resume(returning: Self.state(activities?.last))
            }
        }
    }

    /// For the exertion bin (`ExertionReader`): running and cycling minutes apart, so a moment can say "a run" or "a bike ride", and a note on what
    /// came back (Settings › Exertion check). Nil minutes: Motion can't say (not allowed, older than the
    /// week iOS keeps, or nothing recorded).
    func vigorous(before date: Date, window: TimeInterval = 30 * 60) async -> (running: Double?, cycling: Double?, note: String) {
        guard CMMotionActivityManager.isActivityAvailable() else { return (nil, nil, "Motion isn't available on this device.") }
        guard CMMotionActivityManager.authorizationStatus() == .authorized else {
            return (nil, nil, "Motion & Fitness isn't allowed (status \(CMMotionActivityManager.authorizationStatus().rawValue)).")
        }
        guard Exertion.motionCanSay(at: date) else { return (nil, nil, "Older than the week iOS keeps.") }
        let start = date.addingTimeInterval(-window)
        let end = min(date, .now)
        return await withCheckedContinuation { continuation in
            manager.queryActivityStarting(from: start, to: end, to: .main) { activities, error in
                guard error == nil, let a = activities, !a.isEmpty else {
                    continuation.resume(returning: (nil, nil, error.map { "Motion error: \($0.localizedDescription)" } ?? "Nothing recorded."))
                    return
                }
                var running = 0.0, cycling = 0.0, walking = 0.0
                for (i, x) in a.enumerated() {
                    let until = i + 1 < a.count ? a[i + 1].startDate : end
                    let minutes = max(0, until.timeIntervalSince(max(x.startDate, start))) / 60
                    if x.running { running += minutes } else if x.cycling { cycling += minutes } else if x.walking { walking += minutes }
                }
                let note = String(format: "In the 30 min before: running %.1f min, cycling %.1f min, walking %.1f min (%d readings).",
                                  running, cycling, walking, a.count)
                continuation.resume(returning: (running, cycling, note))
            }
        }
    }

    private nonisolated static func state(_ a: CMMotionActivity?) -> MotionState {
        guard let a else { return .unknown }
        if a.automotive { return .automotive }
        if a.cycling { return .cycling }
        if a.running { return .running }
        if a.walking { return .walking }
        if a.stationary { return .stationary }
        return .unknown
    }
}
