import Foundation

/// The three families the sky, the rail and Moment details group readings into, in the rail's order.
/// Each prints in its own ink (Weather pink, Pollutants aqua, Allergens yellow; docs/design/color-review-riso.md).
public enum ReadingFamily: String, CaseIterable, Sendable {
    case weather, pollutants, allergens

    public var title: String {
        switch self {
        case .weather: "Weather"
        case .pollutants: "Pollutants"
        case .allergens: "Allergens"
        }
    }

    /// The signals this family shows, in reading order. The AQI is an index across pollutants, so it's
    /// the family's summary line, not one of its readings.
    public var signals: [Signal] {
        switch self {
        case .weather: [.temperature, .humidity, .dewpoint, .windSpeed, .uvIndex]
        case .pollutants: [.pm25, .pm10, .ozone, .no2]
        case .allergens: [.pollenTree, .pollenGrass, .pollenWeed]
        }
    }

    public static func of(_ s: Signal) -> ReadingFamily {
        switch s {
        case .temperature, .humidity, .dewpoint, .windSpeed, .uvIndex: .weather
        case .pm25, .pm10, .ozone, .no2, .aqi: .pollutants
        case .pollenTree, .pollenGrass, .pollenWeed: .allergens
        }
    }

    /// This family's readings in a moment's conditions (the AQI included for pollutants).
    public func observations(in c: Conditions) -> [EnvObservation] {
        c.observations.filter { ReadingFamily.of($0.signal) == self }
    }
}

extension ObservationCopy {
    /// One quiet provenance line for a family's readings: the broadest scale word, then each source once
    /// with its nearest distance. "Regional outdoor · AirNow 11 mi · OpenAQ 2 mi". Nil with no readings.
    /// Never "at your location": a 15-mile monitor is regional (docs/env-signals-and-aggregators.md).
    public static func provenance(_ obs: [EnvObservation]) -> String? {
        guard !obs.isEmpty else { return nil }
        let words = obs.map(scaleWord)
        let scale = ["Regional outdoor", "Modeled outdoor", "Outdoor"].first(where: words.contains) ?? "Outdoor"
        var sources: [String] = []
        var nearest: [String: Double] = [:]
        for o in obs {
            if !sources.contains(o.source) { sources.append(o.source) }
            if let km = o.distanceKm { nearest[o.source] = min(nearest[o.source] ?? km, km) }
        }
        let named = sources.map { s -> String in
            guard let km = nearest[s] else { return s }
            let mi = km * 0.621371
            return "\(s) \(mi < 1 ? "<1" : String(Int(mi.rounded()))) mi"
        }
        return ([scale] + named).joined(separator: " · ")
    }

    /// The AQI as a summary under the pollutants: "AQI 42 · Good · mostly ozone". The word is the EPA
    /// band in felt air's three words (Good / OK / Not good); the main pollutant comes from AirNow's category.
    public static func aqiSummary(_ o: EnvObservation) -> String {
        let word = o.value <= 50 ? "Good" : o.value <= 100 ? "OK" : "Not good"
        var line = "AQI \(Int(o.value.rounded())) · \(word)"
        let parts = (o.category ?? "").components(separatedBy: " · ")
        if parts.count > 1, let p = parts.last?.trimmingCharacters(in: .whitespaces), !p.isEmpty {
            line += " · mostly \(p)"
        }
        return line
    }
}
