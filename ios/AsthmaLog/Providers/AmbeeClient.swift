import AsthmaCore
import CoreLocation
import Foundation

/// The live Ambee API, behind the same `AmbeeSource` as the demo: air quality and pollen only (weather stays
/// on WeatherKit, docs/ambee/poc-estimate.md). Air and pollen responses checked live Nov 13, 2026. Fails open.
nonisolated struct AmbeeClient: AmbeeSource {
    let key: String
    let sourceName = Ambee.source
    private let base = "https://api.ambeedata.com"

    /// The app's Ambee: the live client behind the cache when there's a key, otherwise the labelled demo.
    @MainActor static var current: any AmbeeSource { cached ?? DemoAmbee() }

    /// One cache for the app's life, saved in Caches (iOS may clear it; it only costs calls).
    @MainActor private static let cached: CachedAmbee? = Secrets.ambee.map { key in
        let file = URL.cachesDirectory.appending(path: "ambee-cache.json")
        return CachedAmbee(AmbeeClient(key: key), saved: try? Data(contentsOf: file),
                           save: { try? $0.write(to: file, options: .atomic) })
    }

    /// True when Ambee answers are real, not the demo.
    @MainActor static var isLive: Bool { cached != nil }

    func latest(latitude: Double, longitude: Double, at date: Date) async throws -> AmbeeHour {
        async let air: Ambee.AirQualityResponse = get("/latest/by-lat-lng", latitude, longitude)
        async let pollen: Ambee.PollenResponse = get("/v3/pollen/latest", latitude, longitude, ["speciesRisk": "true"])
        let hours = Ambee.hours(airQuality: (try? await air) ?? .init(), pollen: try? await pollen,
                                weather: [], isForecast: false)
        guard var h = Ambee.newest(hours) else { throw URLError(.zeroByteResource) }
        h.date = date
        return h
    }

    func history(latitude: Double, longitude: Double, from: Date, to: Date) async throws -> [AmbeeHour] {
        let range = ["from": stamp(from), "to": stamp(to)]
        async let air: Ambee.AirQualityResponse = get("/history/by-lat-lng", latitude, longitude, range)
        async let pollen: Ambee.PollenResponse = get("/v3/pollen/history", latitude, longitude, range)
        return Ambee.hours(airQuality: (try? await air) ?? .init(), pollen: try? await pollen,
                           weather: [], isForecast: false)
    }

    func forecast(latitude: Double, longitude: Double, from: Date, hours: Int) async throws -> [AmbeeHour] {
        async let air: Ambee.AirQualityResponse = get("/forecast/aq/by-lat-lng", latitude, longitude)
        async let pollen: Ambee.PollenResponse = get("/v3/pollen/forecast/48hrs", latitude, longitude)
        let all = Ambee.hours(airQuality: (try? await air) ?? .init(), pollen: try? await pollen,
                              weather: [], isForecast: true)
        return Array(all.filter { $0.date >= from.addingTimeInterval(-3600) }.prefix(hours))
    }

    /// Active fires near the place (`/fire/latest/by-lat-lng`).
    func fires(latitude: Double, longitude: Double) async -> [Ambee.FireResponse.Fire] {
        let r: Ambee.FireResponse? = try? await get("/fire/latest/by-lat-lng", latitude, longitude)
        return r?.data ?? []
    }

    /// Wildfires near a place: live Ambee when there's a key, the demo's otherwise.
    @MainActor static func wildfires(latitude: Double, longitude: Double) async -> WildfiresNearby? {
        let fires: [Ambee.FireResponse.Fire]
        if let key = Secrets.ambee { fires = await AmbeeClient(key: key).fires(latitude: latitude, longitude: longitude) }
        else { fires = DemoAmbee().fires(latitude: latitude, longitude: longitude) }
        return WildfiresNearby(fires: fires, latitude: latitude, longitude: longitude)
    }

    private func get<T: Decodable & Sendable>(_ path: String, _ lat: Double, _ lng: Double, _ extra: [String: String] = [:]) async throws -> T {
        var c = URLComponents(string: base + path)!
        c.queryItems = [URLQueryItem(name: "lat", value: Coarse.string(lat)), URLQueryItem(name: "lng", value: Coarse.string(lng))]
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
