import AsthmaCore
import Foundation

/// Flu-like illness around the moment's day (`Infection`). **Later, not MVP**: off until `Infection.isEnabled`,
/// and the source finds nothing. When it's turned on, swap `source` for the live Ambee ILI client. Rescue and
/// baseline moments are stamped alike, as they happen (Ambee has no history). Fails open.
enum InfectionStamp {
    static let source: any InfectionSource = NoInfectionSource()

    static func stamp(_ event: LogEvent) async {
        guard Infection.isEnabled, !event.isDemo, event.infectionRaw == nil,
              let lat = event.latitude, let lon = event.longitude,
              let r = await source.reading(latitude: lat, longitude: lon, on: event.loggedAt) else { return }
        event.infection = r.level
    }
}
