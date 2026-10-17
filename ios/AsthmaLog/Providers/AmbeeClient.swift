import AsthmaCore
import CoreLocation
import Foundation

/// The live Ambee API, behind the same `AmbeeSource` as the demo. Endpoints and headers follow Ambee's
/// docs (docs/ambee-integration.md); **not yet run against a real key**. Fails open like every provider.
nonisolated struct AmbeeClient: AmbeeSource {
    let key: String
    let sourceName = Ambee.source
    private let base = "https://api.ambeedata.com"

    /// The app's Ambee: the live client when there's a key, otherwise the labelled demo.
    @MainActor static var current: any AmbeeSource { Secrets.ambee.map { AmbeeClient(key: $0) } ?? DemoAmbee() }

    func latest(latitude: Double, longitude: Double, at date: Date) async throws -> AmbeeHour {
        async let air: Ambee.AirQualityResponse = get("/latest/by-lat-lng", latitude, longitude)
        async let pollen: Ambee.PollenResponse = get("/v3/pollen/latest", latitude, longitude, ["speciesRisk": "true"])
        async let weather: Ambee.WeatherResponse = get("/weather/latest/by-lat-lng", latitude, longitude, ["units": "us"])
        let w = (try? await weather)?.data
        let hours = Ambee.hours(airQuality: (try? await air) ?? .init(), pollen: try? await pollen,
                                weather: w.map { [$0] } ?? [], isForecast: false)
        guard var h = hours.last else { throw URLError(.zeroByteResource) }
        h.date = date
        return h
    }

    func history(latitude: Double, longitude: Double, from: Date, to: Date) async throws -> [AmbeeHour] {
        let range = ["from": stamp(from), "to": stamp(to)]
        async let air: Ambee.AirQualityResponse = get("/history/by-lat-lng", latitude, longitude, range)
        async let pollen: Ambee.PollenResponse = get("/v3/pollen/history", latitude, longitude, range)
        async let weather: Ambee.WeatherResponse = get("/weather/history/by-lat-lng", latitude, longitude, range.merging(["units": "us"]) { a, _ in a })
        return Ambee.hours(airQuality: (try? await air) ?? .init(), pollen: try? await pollen,
                           weather: (try? await weather)?.data?.history ?? [], isForecast: false)
    }

    func forecast(latitude: Double, longitude: Double, from: Date, hours: Int) async throws -> [AmbeeHour] {
        async let air: Ambee.AirQualityResponse = get("/forecast/aq/by-lat-lng", latitude, longitude)
        async let pollen: Ambee.PollenResponse = get("/v3/pollen/forecast/48hrs", latitude, longitude)
        async let weather: Ambee.WeatherResponse = get("/weather/forecast/by-lat-lng", latitude, longitude, ["units": "us"])
        let all = Ambee.hours(airQuality: (try? await air) ?? .init(), pollen: try? await pollen,
                              weather: (try? await weather)?.data?.forecast ?? [], isForecast: true)
        return Array(all.filter { $0.date >= from.addingTimeInterval(-3600) }.prefix(hours))
    }

    private func get<T: Decodable & Sendable>(_ path: String, _ lat: Double, _ lng: Double, _ extra: [String: String] = [:]) async throws -> T {
        var c = URLComponents(string: base + path)!
        c.queryItems = [URLQueryItem(name: "lat", value: String(lat)), URLQueryItem(name: "lng", value: String(lng))]
            + extra.map { URLQueryItem(name: $0.key, value: $0.value) }
        return try await HTTP.get(c.url!, headers: ["x-api-key": key, "Content-type": "application/json"])
    }

    private func stamp(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: d)
    }
}
