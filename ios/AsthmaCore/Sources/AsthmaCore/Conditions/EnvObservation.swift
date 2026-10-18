import Foundation

public enum Signal: String, Codable, Sendable, CaseIterable {
    case temperature, humidity, dewpoint, pm25, ozone, aqi, pollenWeed, uvIndex, windSpeed, pm10, no2, pollenTree, pollenGrass
}

public enum SpatialScale: String, Codable, Sendable {
    case station, neighborhood, city, region, modelGrid
}

public enum Confidence: String, Codable, Sendable, Comparable {
    case low, medium, high

    private var rank: Int {
        switch self {
        case .low: 0
        case .medium: 1
        case .high: 2
        }
    }

    public static func < (a: Confidence, b: Confidence) -> Bool { a.rank < b.rank }
}

/// One outdoor number with where and when it came from. Every number the UI shows is one of these.
/// See docs/data-architecture.md §5 ("the honesty contract").
/// Named `EnvObservation`, not `Observation`: that name would shadow Apple's Observation module and
/// break `@Observable` / `@Model` in any app file that imports AsthmaCore.
public struct EnvObservation: Codable, Sendable, Equatable {
    public var signal: Signal
    public var value: Double
    /// e.g. "°F", "%", "µg/m³", "ppb", "AQI"
    public var unit: String
    /// When the value was observed or modeled — not when the user logged.
    public var asOf: Date
    /// e.g. "Apple Weather", "OpenAQ", "AirNow"
    public var source: String
    public var spatialScale: SpatialScale
    public var distanceKm: Double?
    public var confidence: Confidence
    public var stationName: String?
    /// Category text that came with the value, e.g. AQI "Moderate" or pollen "High".
    public var category: String?
    /// True for forecast values (look-ahead), false for observations.
    public var isForecast: Bool

    public init(
        signal: Signal,
        value: Double,
        unit: String,
        asOf: Date,
        source: String,
        spatialScale: SpatialScale,
        distanceKm: Double? = nil,
        confidence: Confidence = .medium,
        stationName: String? = nil,
        category: String? = nil,
        isForecast: Bool = false
    ) {
        self.signal = signal
        self.value = value
        self.unit = unit
        self.asOf = asOf
        self.source = source
        self.spatialScale = spatialScale
        self.distanceKm = distanceKm
        self.confidence = confidence
        self.stationName = stationName
        self.category = category
        self.isForecast = isForecast
    }
}

/// An official alert active at the place and time (e.g. Heat Advisory). Not an observation.
public struct ConditionAlert: Codable, Sendable, Equatable {
    public var name: String
    public var source: String
    public var severity: String?

    public init(name: String, source: String, severity: String? = nil) {
        self.name = name
        self.source = source
        self.severity = severity
    }
}

/// Everything stamped on one log. Providers fail open: a missing source adds an error string, not a crash.
public struct Conditions: Codable, Sendable, Equatable {
    public var observations: [EnvObservation]
    public var alerts: [ConditionAlert]
    public var errors: [String]
    public var fetchedAt: Date
    /// Apple Weather's description at the time ("Rain", "Mostly Cloudy"). Nil on older moments.
    public var weatherCondition: String?
    /// °F the outdoor temperature fell in the 3 hours before (`TempDrop`), from Apple Weather's past
    /// hours. Nil when those hours couldn't be read, and on older moments.
    public var tempFallF: Double?
    /// The 48 hours before the moment, in two windows (`LookBack`). Nil until fetched or backfilled.
    public var lookBack: LookBack?

    public init(observations: [EnvObservation] = [], alerts: [ConditionAlert] = [], errors: [String] = [], fetchedAt: Date = Date()) {
        self.observations = observations
        self.alerts = alerts
        self.errors = errors
        self.fetchedAt = fetchedAt
    }

    /// Best observation for a signal: the order providers were merged in is the priority order.
    public func best(_ signal: Signal) -> EnvObservation? {
        observations.first { $0.signal == signal }
    }

    /// The best reading from a real source: Ambee's sample (until the contract) is shown, never binned.
    public func bestReal(_ signal: Signal) -> EnvObservation? {
        observations.first { $0.signal == signal && !Ambee.isDemo($0.source) }
    }

    /// What the patterns see: real sources only (docs/ambee: the sample stands in on screen until the key).
    public var input: ConditionsInput {
        ConditionsInput(
            pm25: bestReal(.pm25)?.value,
            ozonePpb: bestReal(.ozone)?.value,
            temperatureF: bestReal(.temperature)?.value,
            humidityPct: bestReal(.humidity)?.value,
            pollenWeedRisk: bestReal(.pollenWeed)?.category,
            aqi: bestReal(.aqi).map { Int($0.value.rounded()) },
            alertNames: alerts.map(\.name),
            tempFallF: tempFallF
        )
    }
}

/// Honest one-line copy for an observation, e.g. "Outdoor PM2.5 27 µg/m³ · 11 mi from Denver-CAMP · 4:00 PM".
public enum ObservationCopy {
    public static let regionalKm: Double = 16  // ~10 mi

    public static func label(_ signal: Signal) -> String {
        switch signal {
        case .temperature: "Temp"
        case .humidity: "Humidity"
        case .dewpoint: "Dew point"
        case .pm25: "PM2.5"
        case .pm10: "PM10"
        case .no2: "NO₂"
        case .ozone: "Ozone"
        case .aqi: "AQI"
        case .pollenWeed: "Weed pollen"
        case .pollenTree: "Tree pollen"
        case .pollenGrass: "Grass pollen"
        case .uvIndex: "UV index"
        case .windSpeed: "Wind"
        }
    }

    /// "outdoor", "regional outdoor" or "modeled outdoor" — never "at your location".
    public static func scaleWord(_ o: EnvObservation) -> String {
        if o.spatialScale == .modelGrid { return "Modeled outdoor" }
        if o.spatialScale == .region || o.spatialScale == .city { return "Regional outdoor" }
        if let km = o.distanceKm, km > regionalKm { return "Regional outdoor" }
        return "Outdoor"
    }

    public static func value(_ o: EnvObservation) -> String {
        if o.signal == .pollenWeed, let c = o.category { return c }
        let rounded = o.value.rounded()
        let number = rounded == o.value || abs(o.value) >= 10 ? String(Int(rounded)) : String(format: "%.1f", o.value)
        switch o.unit {
        case "°F": return "\(number)°F"
        case "%": return "\(number)%"
        case "AQI": return o.category.map { "\(number) · \($0)" } ?? number
        case "UV": return number
        default: return "\(number) \(o.unit)"
        }
    }

    public static func line(_ o: EnvObservation, timeZone: TimeZone = .current, locale: Locale = Locale(identifier: "en_US")) -> String {
        var parts = ["\(scaleWord(o)) \(label(o.signal)) \(value(o))"]
        if let km = o.distanceKm {
            let mi = km * 0.621371
            let miText = mi < 1 ? "<1 mi" : "\(Int(mi.rounded())) mi"
            parts.append(o.stationName.map { "\(miText) from \($0)" } ?? miText)
        } else if let name = o.stationName {
            parts.append(name)
        }
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = timeZone
        f.dateFormat = "h:mm a"
        parts.append(f.string(from: o.asOf))
        parts.append(o.source)
        return parts.joined(separator: " · ")
    }
}
