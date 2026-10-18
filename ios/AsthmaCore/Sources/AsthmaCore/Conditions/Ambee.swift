import Foundation

/// Ambee, the planned source for air quality, pollen, weather, fire and their history and forecasts
/// (docs/ambee-trigger-datasets.md, docs/ambee-integration.md). Until the contract and key arrive, the app
/// runs on `DemoAmbee`, which produces the same shapes. Everything below the response models works on
/// `AmbeeHour`, so swapping in the live client changes one file.
///
/// The response models follow Ambee's public docs. They are **not yet checked against a live response**:
/// every field is optional, and the decoding tests use the documented examples.
public enum Ambee {
    public static let source = "Ambee"
    public static let demoSource = "Ambee (demo)"
    /// Readings a demo scenario put in (Settings › Demo scenario): shown, never in patterns.
    public static let scenarioSource = "Demo scenario"
    public static func isDemo(_ source: String) -> Bool { source == demoSource || source == scenarioSource }

    // MARK: Responses (as documented)

    /// `GET /latest/by-lat-lng` and `GET /history/by-lat-lng`: air quality.
    public struct AirQualityResponse: Codable, Sendable {
        public var message: String?
        public var stations: [Station]?
        /// History returns `data` instead of `stations`.
        public var data: [Station]?

        public struct Station: Codable, Sendable {
            public var PM25: Double?
            public var PM10: Double?
            public var OZONE: Double?
            public var NO2: Double?
            public var SO2: Double?
            public var CO: Double?
            public var AQI: Double?
            public var aqiInfo: AQIInfo?
            public var createdAt: String?
            public var updatedAt: String?
        }

        public struct AQIInfo: Codable, Sendable {
            public var pollutant: String?
            public var concentration: Double?
            public var category: String?
        }

        public var rows: [Station] { stations ?? data ?? [] }

        public init(message: String? = nil, stations: [Station]? = nil, data: [Station]? = nil) {
            self.message = message; self.stations = stations; self.data = data
        }
    }

    /// `GET /v3/pollen/latest`, `/v3/pollen/history`, `/v3/pollen/forecast/48hrs`.
    public struct PollenResponse: Codable, Sendable {
        public var message: String?
        public var data: [Entry]?

        public struct Entry: Codable, Sendable {
            public var Count: Counts?
            public var Risk: Risks?
            /// North America with `speciesRisk=true`: e.g. `Species.Tree["Oak"]`, `Species.Weed["Ragweed"]`.
            public var Species: SpeciesCounts?
            public var updatedAt: String?
            public var time: Double?
        }

        public struct Counts: Codable, Sendable {
            public var tree_pollen: Double?
            public var grass_pollen: Double?
            public var weed_pollen: Double?
        }

        public struct Risks: Codable, Sendable {
            public var tree_pollen: String?
            public var grass_pollen: String?
            public var weed_pollen: String?
        }

        public struct SpeciesCounts: Codable, Sendable {
            public var Tree: [String: Double]?
            public var Grass: [String: Double]?
            public var Weed: [String: Double]?
        }
    }

    /// `GET /weather/latest/by-lat-lng`, `/weather/history/by-lat-lng`, `/weather/forecast/by-lat-lng`.
    public struct WeatherResponse: Codable, Sendable {
        public var message: String?
        public var data: Payload?

        /// Latest returns one object; history and forecast return a list under `history` / `forecast`.
        public struct Payload: Codable, Sendable {
            public var temperature: Double?
            public var apparentTemperature: Double?
            public var dewPoint: Double?
            public var humidity: Double?
            public var windSpeed: Double?
            public var precipIntensity: Double?
            public var summary: String?
            public var time: Double?
            public var history: [Payload]?
            public var forecast: [Payload]?
        }
    }

    /// `GET /fire/latest/by-lat-lng`.
    public struct FireResponse: Codable, Sendable {
        public var message: String?
        public var data: [Fire]?

        public struct Fire: Codable, Sendable {
            public var lat: Double?
            public var lng: Double?
            public var frp: Double?
            public var confidence: String?
            public var fireType: String?

            public init(lat: Double?, lng: Double?, frp: Double? = nil, confidence: String? = nil, fireType: String? = nil) {
                self.lat = lat; self.lng = lng; self.frp = frp; self.confidence = confidence; self.fireType = fireType
            }
        }
    }
}

/// One hour of Ambee data at one place, whatever endpoint it came from. Units are ours: µg/m³ for
/// particles, ppb for gases, grains/m³ for pollen, °F, %.
public struct AmbeeHour: Codable, Sendable, Equatable {
    public var date: Date
    public var pm25: Double?
    public var pm10: Double?
    public var ozone: Double?
    public var no2: Double?
    public var aqi: Double?
    /// Which pollutant drives the AQI, as Ambee names it ("PM2.5", "O3").
    public var aqiPollutant: String?
    public var treePollen: Double?
    public var grassPollen: Double?
    public var weedPollen: Double?
    /// The top species in each group, when Ambee sends them ("Oak", "Ragweed").
    public var treeSpecies: String?
    public var weedSpecies: String?
    public var temperatureF: Double?
    public var humidity: Double?
    public var dewpointF: Double?
    public var windSpeed: Double?
    public var precipitation: Double?
    public var summary: String?
    /// Nearest detected fire, km, computed from `/fire/latest` (nil when none within 50 km).
    public var nearestFireKm: Double?
    /// True when this hour is a forecast, not a reading.
    public var isForecast: Bool

    public init(date: Date, pm25: Double? = nil, pm10: Double? = nil, ozone: Double? = nil, no2: Double? = nil,
                aqi: Double? = nil, aqiPollutant: String? = nil, treePollen: Double? = nil, grassPollen: Double? = nil,
                weedPollen: Double? = nil, treeSpecies: String? = nil, weedSpecies: String? = nil,
                temperatureF: Double? = nil, humidity: Double? = nil, dewpointF: Double? = nil, windSpeed: Double? = nil,
                precipitation: Double? = nil, summary: String? = nil, nearestFireKm: Double? = nil, isForecast: Bool = false) {
        self.date = date; self.pm25 = pm25; self.pm10 = pm10; self.ozone = ozone; self.no2 = no2; self.aqi = aqi
        self.aqiPollutant = aqiPollutant; self.treePollen = treePollen; self.grassPollen = grassPollen
        self.weedPollen = weedPollen; self.treeSpecies = treeSpecies; self.weedSpecies = weedSpecies
        self.temperatureF = temperatureF; self.humidity = humidity; self.dewpointF = dewpointF
        self.windSpeed = windSpeed; self.precipitation = precipitation; self.summary = summary
        self.nearestFireKm = nearestFireKm; self.isForecast = isForecast
    }

    /// The hour as our readings, each labelled with its source and marked outdoor, model-grid scale.
    public func observations(source: String) -> [EnvObservation] {
        func o(_ s: Signal, _ v: Double?, _ unit: String) -> EnvObservation? {
            v.map { EnvObservation(signal: s, value: $0, unit: unit, asOf: date, source: source,
                                   spatialScale: .modelGrid, confidence: .medium, isForecast: isForecast) }
        }
        return [
            o(.pm25, pm25, "µg/m³"), o(.pm10, pm10, "µg/m³"), o(.ozone, ozone, "ppb"), o(.no2, no2, "ppb"),
            o(.aqi, aqi, "AQI"), o(.pollenTree, treePollen, "grains/m³"), o(.pollenGrass, grassPollen, "grains/m³"),
            o(.pollenWeed, weedPollen, "grains/m³"), o(.temperature, temperatureF, "°F"), o(.humidity, humidity, "%"),
            o(.dewpoint, dewpointF, "°F"), o(.windSpeed, windSpeed, "mph"),
        ].compactMap { $0 }
    }
}

/// Where Ambee data comes from: the live API (once there's a key) or `DemoAmbee`. All calls are by lat/lng.
public protocol AmbeeSource: Sendable {
    var sourceName: String { get }
    func latest(latitude: Double, longitude: Double, at date: Date) async throws -> AmbeeHour
    /// Hourly, oldest first. Ambee's history covers 48 h per call.
    func history(latitude: Double, longitude: Double, from: Date, to: Date) async throws -> [AmbeeHour]
    /// Hourly, from now. Air quality and pollen run to 48 h (pollen) / 5 days (AQ); the app asks for 48.
    func forecast(latitude: Double, longitude: Double, from: Date, hours: Int) async throws -> [AmbeeHour]
}

extension Ambee {
    /// Response models → hours. Kept here so the live client and the tests share one mapping.
    public static func hours(airQuality: AirQualityResponse, pollen: PollenResponse?, weather: [WeatherResponse.Payload],
                             isForecast: Bool) -> [AmbeeHour] {
        var byHour: [Date: AmbeeHour] = [:]
        func slot(_ d: Date) -> Date { Date(timeIntervalSince1970: (d.timeIntervalSince1970 / 3600).rounded(.down) * 3600) }
        func upsert(_ d: Date, _ f: (inout AmbeeHour) -> Void) {
            var h = byHour[slot(d)] ?? AmbeeHour(date: slot(d), isForecast: isForecast)
            f(&h); byHour[slot(d)] = h
        }
        for s in airQuality.rows {
            guard let d = parseDate(s.createdAt ?? s.updatedAt) else { continue }
            upsert(d) {
                $0.pm25 = s.PM25; $0.pm10 = s.PM10; $0.ozone = s.OZONE; $0.no2 = s.NO2
                $0.aqi = s.AQI; $0.aqiPollutant = s.aqiInfo?.pollutant
            }
        }
        for e in pollen?.data ?? [] {
            guard let d = e.time.map({ Date(timeIntervalSince1970: $0) }) ?? parseDate(e.updatedAt) else { continue }
            upsert(d) {
                $0.treePollen = e.Count?.tree_pollen; $0.grassPollen = e.Count?.grass_pollen; $0.weedPollen = e.Count?.weed_pollen
                $0.treeSpecies = e.Species?.Tree?.max { $0.value < $1.value }?.key
                $0.weedSpecies = e.Species?.Weed?.max { $0.value < $1.value }?.key
            }
        }
        for w in weather {
            guard let t = w.time else { continue }
            upsert(Date(timeIntervalSince1970: t)) {
                $0.temperatureF = w.temperature; $0.humidity = w.humidity; $0.dewpointF = w.dewPoint
                $0.windSpeed = w.windSpeed; $0.precipitation = w.precipIntensity; $0.summary = w.summary
            }
        }
        return byHour.values.sorted { $0.date < $1.date }
    }

    static func parseDate(_ s: String?) -> Date? {
        guard let s else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: s) { return d }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: s)
    }

    /// The 48 hours before a moment as the look-back (`LookBack`), from Ambee history.
    public static func lookBack(at date: Date, history: [AmbeeHour]) -> LookBack {
        let pm = history.compactMap { h in h.pm25.map { HourValue(date: h.date, value: $0) } }
        let o3 = history.compactMap { h in h.ozone.map { HourValue(date: h.date, value: $0) } }
        let temps = history.compactMap { h in h.temperatureF.map { TempPoint(date: h.date, temperatureF: $0) } }
        return LookBack.compute(at: date, pm25: pm, ozone: o3, temps: temps)
    }
}

/// Pretend Ambee: realistic, deterministic hours for any place and time, in Ambee's own shapes and units,
/// so every screen and table can be built before the key arrives. Labelled "Ambee (demo)" everywhere and
/// never fed into patterns.
public struct DemoAmbee: AmbeeSource {
    public let sourceName = Ambee.demoSource

    public init() {}

    public func latest(latitude: Double, longitude: Double, at date: Date) async throws -> AmbeeHour {
        hour(latitude, longitude, date, forecast: false)
    }

    public func history(latitude: Double, longitude: Double, from: Date, to: Date) async throws -> [AmbeeHour] {
        stride(from: from.timeIntervalSince1970, through: to.timeIntervalSince1970, by: 3600).map {
            hour(latitude, longitude, Date(timeIntervalSince1970: $0), forecast: false)
        }
    }

    public func forecast(latitude: Double, longitude: Double, from: Date, hours: Int) async throws -> [AmbeeHour] {
        (0..<hours).map { hour(latitude, longitude, from.addingTimeInterval(Double($0) * 3600), forecast: true) }
    }

    /// Daily and seasonal shapes: ozone peaks mid-afternoon in summer, particles in the morning and evening
    /// rush, tree pollen in spring mornings, grass in early summer, weed (ragweed) in late summer; a cooling
    /// front every few days. Seeded by place and day so it's the same every time.
    public func hour(_ lat: Double, _ lon: Double, _ date: Date, forecast: Bool) -> AmbeeHour {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: Int((lon / 15).rounded()) * 3600) ?? .current
        let h = Double(cal.component(.hour, from: date))
        let doy = Double(cal.ordinality(of: .day, in: .year, for: date) ?? 180)
        let day = (date.timeIntervalSince1970 / 86_400).rounded(.down)
        let seed = Self.noise(day * 7.31 + lat * 3.1 + lon * 1.7)
        func bump(_ center: Double, _ width: Double) -> Double { exp(-pow((h - center) / width, 2)) }
        func season(_ peakDay: Double, _ width: Double) -> Double { exp(-pow((doy - peakDay) / width, 2)) }
        let summer = season(196, 60)
        let temp = 30 + 50 * season(200, 95) + 12 * (bump(15, 5) - 0.5) - 14 * max(0, seed - 0.7) / 0.3
        let humidity = min(98, max(20, 55 + 25 * (bump(5, 4) - bump(15, 4)) + 20 * (seed - 0.5)))
        let ozone = 18 + 52 * summer * bump(15, 3.5) + 10 * seed
        let pm25 = 5 + 9 * (bump(8, 1.6) + bump(19, 2)) + 22 * max(0, seed - 0.82) / 0.18
        let morning = 0.4 + 0.6 * bump(8, 3)
        let tree = 360 * season(110, 22) * morning * (0.6 + 0.8 * seed)
        let grass = 75 * season(160, 25) * morning * (0.6 + 0.8 * seed)
        let weed = 230 * season(245, 18) * morning * (0.6 + 0.8 * seed)
        let r = { (x: Double) in (x * 10).rounded() / 10 }
        return AmbeeHour(
            date: date, pm25: r(pm25), pm10: r(pm25 * 1.7 + 4), ozone: r(ozone), no2: r(8 + 14 * (bump(8, 1.5) + bump(18, 2))),
            aqi: (max(pm25 * 4.2, ozone * 0.9)).rounded(), aqiPollutant: pm25 * 4.2 > ozone * 0.9 ? "PM2.5" : "O3",
            treePollen: tree.rounded(), grassPollen: grass.rounded(), weedPollen: weed.rounded(),
            treeSpecies: tree > 5 ? (doy < 105 ? "Maple" : "Oak") : nil, weedSpecies: weed > 5 ? "Ragweed" : nil,
            temperatureF: r(temp), humidity: humidity.rounded(), dewpointF: r(temp - (100 - humidity) / 5),
            windSpeed: r(4 + 8 * seed), precipitation: seed > 0.9 ? 0.2 : 0, summary: seed > 0.9 ? "Rain" : nil,
            nearestFireKm: nil, isForecast: forecast
        )
    }

    static func noise(_ x: Double) -> Double {
        let s = sin(x * 12.9898) * 43_758.5453
        return s - s.rounded(.down)
    }
}
