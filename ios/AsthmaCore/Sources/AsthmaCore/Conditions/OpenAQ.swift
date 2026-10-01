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

    public static func observation(_ r: Reading, signal: Signal) -> Observation {
        Observation(
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
public enum AirNow {
    public struct Category: Codable, Sendable {
        public var Number: Int?
        public var Name: String?
    }

    public struct Row: Codable, Sendable {
        public var DateObserved: String?
        public var HourObserved: Int?
        public var DateForecast: String?
        public var ReportingArea: String?
        public var ParameterName: String?
        public var AQI: Int?
        public var Category: Category?
    }

    public static func signal(for row: Row) -> Signal? {
        let p = (row.ParameterName ?? "").uppercased()
        if p.contains("PM2.5") { return .pm25 }
        if p.contains("OZONE") || p == "O3" { return .ozone }
        return nil
    }

    /// AQI observation with the driver pollutant (the highest AQI row).
    public static func aqiObservation(_ rows: [Row], asOf: Date) -> Observation? {
        guard let best = rows.filter({ ($0.AQI ?? -1) >= 0 }).max(by: { ($0.AQI ?? -1) < ($1.AQI ?? -1) }),
              let aqi = best.AQI else { return nil }
        let driver = best.ParameterName.map { " (\($0))" } ?? ""
        return Observation(
            signal: .aqi, value: Double(aqi), unit: "AQI", asOf: asOf, source: "AirNow",
            spatialScale: .region, confidence: .medium,
            stationName: best.ReportingArea, category: (best.Category?.Name ?? "") + driver
        )
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
