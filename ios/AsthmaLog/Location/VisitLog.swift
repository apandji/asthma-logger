import AsthmaCore
import CoreLocation
import Foundation

/// Where you spent time, from iOS visit monitoring, so baseline moments filled in later are placed where you
/// actually were (not always at home). Needs the Always location permission, asked only from Settings.
/// Visits stay on this iPhone (Application Support/visits.json), 60 days at most, and are only ever used to
/// place baseline moments. iOS can relaunch the app in the background to deliver a visit, so this starts
/// from the app's init.
@MainActor
final class VisitLog: NSObject, CLLocationManagerDelegate {
    static let shared = VisitLog()

    private let manager = CLLocationManager()
    private(set) var visits: [BaselineBackfill.Visit] = []

    private static let file: URL = {
        let dir = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "visits.json")
    }()

    override init() {
        super.init()
        visits = (try? JSONDecoder().decode([BaselineBackfill.Visit].self, from: Data(contentsOf: Self.file))) ?? []
        manager.delegate = self
    }

    var isAlways: Bool { manager.authorizationStatus == .authorizedAlways }

    /// Starts monitoring when Always is granted; otherwise does nothing (asks nothing).
    func start() {
        if isAlways { manager.startMonitoringVisits() }
    }

    /// Settings › "Use where you've been": the Always prompt (iOS may show it as a follow-up later).
    func requestAlways() {
        manager.requestAlwaysAuthorization()
    }

    func stop() { manager.stopMonitoringVisits() }

    /// Visits with an open end (still there) end now, for planning.
    var forPlanning: [BaselineBackfill.Visit] {
        visits.map { v in
            var v = v
            if v.departure > .now { v.departure = .now }
            return v
        }
    }

    private func add(_ v: BaselineBackfill.Visit) {
        let cutoff = Date().addingTimeInterval(-60 * 86_400)
        // A visit's arrival comes first and its departure later, as the same visit: replace by arrival.
        visits.removeAll { $0.arrival == v.arrival || $0.departure < cutoff }
        visits.append(v)
        visits.sort { $0.arrival < $1.arrival }
        if let data = try? JSONEncoder().encode(visits) { try? data.write(to: Self.file, options: .atomic) }
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        let arrival = visit.arrivalDate == .distantPast ? visit.departureDate.addingTimeInterval(-3600) : visit.arrivalDate
        let v = BaselineBackfill.Visit(latitude: visit.coordinate.latitude, longitude: visit.coordinate.longitude,
                                       arrival: arrival, departure: visit.departureDate)
        Task { @MainActor in VisitLog.shared.add(v) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in VisitLog.shared.start() }
    }
}
