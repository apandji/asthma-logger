import AsthmaCore
import Foundation

/// Flu-like illness around the moment's day (`Infection`), from Ambee's weekly forecast for the metro area.
/// On since Nov 19, 2026. Rescue and baseline moments are stamped alike. The forecast starts at the current
/// week, so a moment filled in a day later is still covered; older ones stay missing. Without an Ambee key
/// nothing is stamped. Fails open.
enum InfectionStamp {
    static let source: any InfectionSource = Secrets.ambee.map { AmbeeInfection(key: $0) } ?? NoInfectionSource()

    static func stamp(_ event: LogEvent) async {
        guard Infection.isEnabled, !event.isDemo, event.infectionRaw == nil,
              let lat = event.latitude, let lon = event.longitude,
              let r = await source.reading(latitude: lat, longitude: lon, on: event.loggedAt) else { return }
        event.infection = r.level
    }
}

/// Ambee's flu-like-illness forecast, kept for the day per metro-sized square so a day of moments is one call.
actor AmbeeInfection: InfectionSource {
    let key: String
    private var kept: [String: (at: Date, response: Ambee.ILIResponse)] = [:]

    init(key: String) { self.key = key }

    func reading(latitude: Double, longitude: Double, on day: Date) async -> InfectionReading? {
        // About 30 miles: the forecast is per metro area.
        let square = "\((latitude * 2).rounded() / 2),\((longitude * 2).rounded() / 2)"
        if let k = kept[square], Date.now.timeIntervalSince(k.at) < 12 * 3600 { return k.response.reading(on: day) }
        guard let r = await AmbeeClient(key: key).illness(latitude: latitude, longitude: longitude) else { return nil }
        kept[square] = (.now, r)
        return r.reading(on: day)
    }
}
