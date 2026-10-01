import AsthmaCore
import Foundation

/// Nearest PM2.5 and ozone stations. Station choice lives in AsthmaCore (OpenAQ) and is unit-tested.
struct OpenAQProvider {
    let key: String

    func observations(latitude lat: Double, longitude lon: Double) async throws -> [EnvObservation] {
        var locations = try await search(lat, lon, monitor: true)
        let hasPM = locations.contains { ($0.sensors ?? []).contains(where: \.measuresPM25) }
        let hasO3 = locations.contains { ($0.sensors ?? []).contains(where: \.measuresOzone) }
        if !hasPM || !hasO3 {
            let seen = Set(locations.compactMap(\.id))
            locations += try await search(lat, lon, monitor: false).filter { $0.id.map { !seen.contains($0) } ?? false }
        }

        let pmLoc = OpenAQ.nearest(locations, lat: lat, lon: lon) { $0.measuresPM25 }
        let o3Loc = OpenAQ.nearest(locations, lat: lat, lon: lon) { $0.measuresOzone }
        var latest: [Int: [OpenAQ.Latest]] = [:]
        for id in Set([pmLoc?.id, o3Loc?.id].compactMap { $0 }) {
            let url = URL(string: "\(OpenAQ.baseURL)/locations/\(id)/latest")!
            latest[id] = try await HTTP.get(url, headers: headers, as: OpenAQ.Results<OpenAQ.Latest>.self).results ?? []
        }

        var out: [EnvObservation] = []
        if let loc = pmLoc, let id = loc.id,
           let r = OpenAQ.reading(at: loc, latest: latest[id] ?? [], lat: lat, lon: lon, measures: { $0.measuresPM25 }) {
            out.append(OpenAQ.observation(r, signal: .pm25))
        }
        if let loc = o3Loc, let id = loc.id,
           let r = OpenAQ.reading(at: loc, latest: latest[id] ?? [], lat: lat, lon: lon, measures: { $0.measuresOzone }) {
            out.append(OpenAQ.observation(r, signal: .ozone))
        }
        return out
    }

    private var headers: [String: String] { ["X-API-Key": key, "Accept": "application/json"] }

    private func search(_ lat: Double, _ lon: Double, monitor: Bool) async throws -> [OpenAQ.Location] {
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
        let rows: [AirNow.Row] = try await HTTP.get(url("observation/latLong/current/", latitude, longitude))
        return AirNow.aqiObservation(rows, asOf: .now).map { [$0] } ?? []
    }

    /// AQI category numbers by local date string "yyyy-MM-dd".
    func forecast(latitude: Double, longitude: Double) async throws -> [String: (pm25: Int?, ozone: Int?)] {
        let today = Self.dayString(.now)
        let rows: [AirNow.Row] = try await HTTP.get(url("forecast/latLong/", latitude, longitude, extra: [URLQueryItem(name: "date", value: today)]))
        var out: [String: (pm25: Int?, ozone: Int?)] = [:]
        for row in rows {
            guard let day = row.DateForecast?.trimmingCharacters(in: .whitespaces), let cat = row.Category?.Number else { continue }
            var entry = out[day] ?? (nil, nil)
            switch AirNow.signal(for: row) {
            case .pm25?: entry.pm25 = max(entry.pm25 ?? 0, cat)
            case .ozone?: entry.ozone = max(entry.ozone ?? 0, cat)
            default: continue
            }
            out[day] = entry
        }
        return out
    }

    static func dayString(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func url(_ path: String, _ lat: Double, _ lon: Double, extra: [URLQueryItem] = []) -> URL {
        var c = URLComponents(string: "https://www.airnowapi.org/aq/\(path)")!
        c.queryItems = [
            URLQueryItem(name: "format", value: "application/json"),
            URLQueryItem(name: "latitude", value: String(lat)),
            URLQueryItem(name: "longitude", value: String(lon)),
            URLQueryItem(name: "distance", value: "25"),
            URLQueryItem(name: "API_KEY", value: key),
        ] + extra
        return c.url!
    }
}
