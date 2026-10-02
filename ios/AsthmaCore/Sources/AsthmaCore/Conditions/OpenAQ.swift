import Foundation

/// OpenAQ v3 decoding and station choice, ported from `web/src/lib/openaq.ts`.
/// The app does the HTTP; this decides which station to trust.
public enum OpenAQ {
    public static let baseURL = "https://api.openaq.org/v3"
    public static let radiusMeters = 25_000
    public static let maxReadingAge: TimeInterval = 36 * 60 * 60

    public struct Parameter: Codable, Sendable {
        public var id: Int?
        public var name: String?
        public var units: String?
    }

    public struct Sensor: Codable, Sendable {
        public var id: Int?
        public var name: String?
        public var parameter: Parameter?

        var paramName: String {
            (parameter?.name ?? name ?? "").lowercased().replacingOccurrences(of: " ", with: "")
        }

        public var measuresPM25: Bool {
            paramName.contains("pm25") || paramName.contains("pm2.5") || parameter?.id == 2
        }

        public var measuresOzone: Bool {
            paramName == "o3" || paramName.contains("ozone") || parameter?.id == 10
        }
    }

    public struct Coordinates: Codable, Sendable {
        public var latitude: Double?
        public var longitude: Double?
    }

    public struct Provider: Codable, Sendable {
        public var name: String?
    }

    public struct DateTimePair: Codable, Sendable {
        public var utc: String?
        public var local: String?
    }

    public struct Location: Codable, Sendable {
        public var id: Int?
        public var name: String?
        public var isMobile: Bool?
        public var isMonitor: Bool?
        public var provider: Provider?
        public var sensors: [Sensor]?
        public var coordinates: Coordinates?
        /// Meters from the query point.
        public var distance: Double?
        public var datetimeLast: DateTimePair?
    }

    public struct Latest: Codable, Sendable {
        public var datetime: DateTimePair?
        public var value: Double?
        public var sensorsId: Int?
    }

    public struct Results<T: Codable & Sendable>: Codable, Sendable {
        public var results: [T]?
    }

    public struct Reading: Sendable, Equatable {
        public var value: Double
        public var asOf: Date
        public var stationName: String?
        public var distanceKm: Double?
        public var isMonitor: Bool
    }

    static func parseDate(_ s: String?) -> Date? {
        guard let s else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    static func isFresh(_ iso: String?, now: Date) -> Bool {
        guard let d = parseDate(iso) else { return true }
        return now.timeIntervalSince(d) <= maxReadingAge
    }

    public static func distanceKm(_ loc: Location, lat: Double, lon: Double) -> Double? {
        if let la = loc.coordinates?.latitude, let lo = loc.coordinates?.longitude {
            return Geo.haversineKm(lat, lon, la, lo)
        }
        return loc.distance.map { $0 / 1000 }
    }

    /// Nearest fresh, fixed station measuring the pollutant. Regulatory monitors win over low-cost sensors.
    public static func nearest(
        _ locations: [Location], lat: Double, lon: Double, now: Date = Date(),
        measures: (Sensor) -> Bool
    ) -> Location? {
        locations
            .filter { $0.id != nil && $0.isMobile != true && ($0.sensors ?? []).contains(where: measures) }
            .filter { isFresh($0.datetimeLast?.utc, now: now) }
            .compactMap { loc in distanceKm(loc, lat: lat, lon: lon).map { (loc, $0) } }
            .sorted { a, b in
                let am = a.0.isMonitor == true, bm = b.0.isMonitor == true
                if am != bm { return am }
                return a.1 < b.1
            }
            .first?.0
    }

    /// Picks the latest value for the first matching sensor at `loc`, converting ppm → ppb/µg.
    public static func reading(
        at loc: Location, latest: [Latest], lat: Double, lon: Double, now: Date = Date(),
        measures: (Sensor) -> Bool
    ) -> Reading? {
        for sensor in (loc.sensors ?? []).filter(measures) {
            guard let sid = sensor.id,
                  let row = latest.first(where: { $0.sensorsId == sid }),
                  let raw = row.value, raw.isFinite, raw >= 0 else { continue }
            let asOfText = row.datetime?.utc ?? row.datetime?.local
            if asOfText != nil, !isFresh(asOfText, now: now) { continue }
            let units = (sensor.parameter?.units ?? "").lowercased()
            let value = units.contains("ppm") ? raw * 1000 : raw
            return Reading(
                value: value,
                asOf: parseDate(asOfText) ?? now,
                stationName: loc.name?.trimmingCharacters(in: .whitespaces).nonEmpty ?? loc.provider?.name,
                distanceKm: distanceKm(loc, lat: lat, lon: lon),
                isMonitor: loc.isMonitor == true
            )
        }
        return nil
    }

    public static func observation(_ r: Reading, signal: Signal) -> EnvObservation {
        EnvObservation(
            signal: signal,
            value: r.value,
            unit: signal == .pm25 ? "µg/m³" : "ppb",
            asOf: r.asOf,
            source: "OpenAQ",
            spatialScale: .station,
            distanceKm: r.distanceKm,
            confidence: r.isMonitor && (r.distanceKm ?? .infinity) <= 10 ? .high : .medium,
            stationName: r.stationName
        )
    }
}

/// AirNow (EPA) current observations and daily forecasts. Values are AQI, not concentrations.
/// Uses the 2026 services (`observation/current/ziplatLong`, `forecast/current`); the old
/// `…/latLong/` services were retired on 2026-09-30 and now answer 410.
public enum AirNow {
    /// One row of `observation/current/ziplatLong`: the closest reading per pollutant.
    public struct Observed: Codable, Sendable {
        public var dateObserved: String?
        /// Local hour as "HH:mm", e.g. "19:00".
        public var hourObserved: String?
        /// US zone abbreviation, e.g. "CDT".
        public var localTimeZone: String?
        public var reportingAreaName: String?
        public var siteName: String?
        public var parameterName: String?
        public var nowcastAQI: Int?
        public var aqiCategoryName: String?
    }

    /// One row of `forecast/current`: a daily category per pollutant. `aqi` is often -1 (category only).
    public struct Forecast: Codable, Sendable {
        /// Local date "yyyy-MM-dd" the forecast is for.
        public var dateValid: String?
        public var reportingArea: String?
        public var parameterName: String?
        public var aqi: Int?
        public var categoryNumber: Int?
        public var categoryName: String?
    }

    public static func signal(for parameterName: String?) -> Signal? {
        let p = (parameterName ?? "").uppercased()
        if p.contains("PM2.5") { return .pm25 }
        if p.contains("OZONE") || p == "O3" { return .ozone }
        return nil
    }

    /// AQI observation with the driver pollutant (the highest AQI row), stamped with the hour AirNow
    /// observed it. Falls back to `fetchedAt` only if that hour can't be read.
    public static func aqiObservation(_ rows: [Observed], fetchedAt: Date) -> EnvObservation? {
        guard let best = rows.filter({ ($0.nowcastAQI ?? -1) >= 0 }).max(by: { ($0.nowcastAQI ?? -1) < ($1.nowcastAQI ?? -1) }),
              let aqi = best.nowcastAQI else { return nil }
        let category = [best.aqiCategoryName, pollutantName(best.parameterName)].compactMap { $0 }.joined(separator: " · ")
        return EnvObservation(
            signal: .aqi, value: Double(aqi), unit: "AQI", asOf: observedAt(best) ?? fetchedAt, source: "AirNow",
            spatialScale: .region, confidence: .medium,
            stationName: best.reportingAreaName, category: category.nonEmpty
        )
    }

    /// "ozone", "PM2.5", or AirNow's own name for anything else.
    static func pollutantName(_ parameterName: String?) -> String? {
        switch signal(for: parameterName) {
        case .ozone?: "ozone"
        case .pm25?: "PM2.5"
        default: parameterName?.nonEmpty
        }
    }

    /// AirNow's US zone abbreviations → UTC offset in hours. A fixed table so Linux and Apple agree.
    static let zoneOffsets: [String: Int] = [
        "EST": -5, "EDT": -4, "CST": -6, "CDT": -5, "MST": -7, "MDT": -6, "PST": -8, "PDT": -7,
        "AKST": -9, "AKDT": -8, "HST": -10, "SST": -11, "CHST": 10, "AST": -4, "UTC": 0, "GMT": 0,
    ]

    /// `dateObserved` "2026-10-01" + `hourObserved` "19:00" + `localTimeZone` "CDT" → the instant observed.
    public static func observedAt(_ row: Observed) -> Date? {
        guard let day = row.dateObserved, let hour = row.hourObserved,
              let zone = row.localTimeZone?.trimmingCharacters(in: .whitespaces).uppercased(),
              let offset = zoneOffsets[zone], let tz = TimeZone(secondsFromGMT: offset * 3600) else { return nil }
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = tz
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: "\(day.trimmingCharacters(in: .whitespaces)) \(hour.trimmingCharacters(in: .whitespaces))")
    }

    /// Highest PM2.5 and ozone category (1–6) per local date "yyyy-MM-dd".
    public static func categoriesByDay(_ rows: [Forecast]) -> [String: (pm25: Int?, ozone: Int?)] {
        var out: [String: (pm25: Int?, ozone: Int?)] = [:]
        for row in rows {
            guard let day = row.dateValid?.trimmingCharacters(in: .whitespaces), let cat = row.categoryNumber, cat >= 1 else { continue }
            var entry = out[day] ?? (nil, nil)
            switch signal(for: row.parameterName) {
            case .pm25?: entry.pm25 = max(entry.pm25 ?? 0, cat)
            case .ozone?: entry.ozone = max(entry.ozone ?? 0, cat)
            default: continue
            }
            out[day] = entry
        }
        return out
    }
}

enum Geo {
    static func haversineKm(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let r = 6371.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = pow(sin(dLat / 2), 2) + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * pow(sin(dLon / 2), 2)
        return 2 * r * asin(min(1, a.squareRoot()))
    }
}

extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
