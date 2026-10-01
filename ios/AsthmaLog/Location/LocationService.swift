import Observation
import CoreLocation
import CoreMotion
import AsthmaCore

enum LocationError: LocalizedError {
    case denied
    case unavailable

    var errorDescription: String? {
        switch self {
        case .denied: "Location is off for Asthma Log. Turn it on in Settings → Privacy → Location Services."
        case .unavailable: "Couldn't get a location fix."
        }
    }
}

/// One precise fix per log. Uses the async CoreLocation API, no delegate.
@Observable
final class LocationService {
    private var session: CLServiceSession?
    private(set) var lastFix: CLLocation?

    /// Waits for a fix of ±20 m or better, or returns the best one seen when `timeout` runs out.
    func currentLocation(timeout: Duration = .seconds(10)) async throws -> CLLocation {
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
                    if loc.horizontalAccuracy <= 20 { return }
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
