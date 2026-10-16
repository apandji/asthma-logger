import AsthmaCore
import Foundation

/// Nearest monitors for PM2.5, PM10, ozone and NO₂. Station choice lives in AsthmaCore (OpenAQ) and
/// is unit-tested. Each pollutant comes from its own nearest station; missing ones are simply left out.
struct OpenAQProvider {
    let key: String

    private static let pollutants: [(signal: Signal, measures: @Sendable (OpenAQ.Sensor) -> Bool)] = [
        (.pm25, { $0.measuresPM25 }), (.pm10, { $0.measuresPM10 }),
        (.ozone, { $0.measuresOzone }), (.no2, { $0.measuresNO2 }),
    ]

    func observations(latitude lat: Double, longitude lon: Double) async throws -> [EnvObservation] {
        var locations = try await search(lat, lon, monitor: true)
        let hasPM = locations.contains { ($0.sensors ?? []).contains(where: \.measuresPM25) }
        let hasO3 = locations.contains { ($0.sensors ?? []).contains(where: \.measuresOzone) }
        if !hasPM || !hasO3 {
            let seen = Set(locations.compactMap(\.id))
            locations += try await search(lat, lon, monitor: false).filter { $0.id.map { !seen.contains($0) } ?? false }
        }

        let picks = Self.pollutants.map { p in (p, OpenAQ.nearest(locations, lat: lat, lon: lon, measures: p.measures)) }
        var latest: [Int: [OpenAQ.Latest]] = [:]
        for id in Set(picks.compactMap { $0.1?.id }) {
            let url = URL(string: "\(OpenAQ.baseURL)/locations/\(id)/latest")!
            latest[id] = try await HTTP.get(url, headers: headers, as: OpenAQ.Results<OpenAQ.Latest>.self).results ?? []
        }

        return picks.compactMap { p, loc in
            guard let loc, let id = loc.id,
                  let r = OpenAQ.reading(at: loc, latest: latest[id] ?? [], lat: lat, lon: lon, measures: p.measures) else { return nil }
            return OpenAQ.observation(r, signal: p.signal)
        }
    }

    private var headers: [String: String] { ["X-API-Key": key, "Accept": "application/json"] }

    func search(_ lat: Double, _ lon: Double, monitor: Bool) async throws -> [OpenAQ.Location] {
        var c = URLComponents(string: "\(OpenAQ.baseURL)/locations")!
        c.queryItems = [
            URLQueryItem(name: "coordinates", value: String(format: "%.4f,%.4f", lat, lon)),
            URLQueryItem(name: "radius", value: String(OpenAQ.radiusMeters)),
            URLQueryItem(name: "limit", value: "100"),
            URLQueryItem(name: "mobile", value: "false"),
            URLQueryItem(name: "monitor", value: String(monitor)),
        ]
        return try await HTTP.get(c.url!, headers: headers, as: OpenAQ.Results<OpenAQ.Location>.self).results ?? []
    }
}

/// EPA AirNow: regional AQI now (fallback) and the daily AQ forecast for the look-ahead.
struct AirNowProvider {
    let key: String

    func current(latitude: Double, longitude: Double) async throws -> [EnvObservation] {
        let rows: [AirNow.Observed] = try await HTTP.get(url("observation/current/ziplatLong/", latitude, longitude))
        return AirNow.aqiObservation(rows, fetchedAt: .now).map { [$0] } ?? []
    }

    /// AQI category numbers by local date string "yyyy-MM-dd".
    func forecast(latitude: Double, longitude: Double) async throws -> [String: (pm25: Int?, ozone: Int?)] {
        let rows: [AirNow.Forecast] = try await HTTP.get(url("forecast/current/", latitude, longitude))
        return AirNow.categoriesByDay(rows)
    }

    static func dayString(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func url(_ path: String, _ lat: Double, _ lon: Double) -> URL {
        var c = URLComponents(string: "https://www.airnowapi.org/aq/\(path)")!
        c.queryItems = [
            URLQueryItem(name: "format", value: "application/json"),
            URLQueryItem(name: "latitude", value: String(lat)),
            URLQueryItem(name: "longitude", value: String(lon)),
            URLQueryItem(name: "API_KEY", value: key),
        ]
        return c.url!
    }
}
