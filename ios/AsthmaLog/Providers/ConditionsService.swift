import AsthmaCore
import Foundation

/// Runs every provider in parallel and fails open: each missing key or error becomes a note, not a crash.
/// Merge order is priority: OpenAQ station readings beat AirNow's regional AQI.
struct ConditionsService {
    let weather = WeatherProvider()

    func conditions(latitude: Double, longitude: Double) async -> Conditions {
        let openAQKey = Secrets.openAQ
        let airNowKey = Secrets.airNow
        let weather = weather

        async let w = Self.attempt { try await weather.current(latitude: latitude, longitude: longitude) }
        async let aq = Self.attempt { () -> [EnvObservation] in
            guard let openAQKey else { return [] }
            return try await OpenAQProvider(key: openAQKey).observations(latitude: latitude, longitude: longitude)
        }
        async let an = Self.attempt { () -> [EnvObservation] in
            guard let airNowKey else { return [] }
            return try await AirNowProvider(key: airNowKey).current(latitude: latitude, longitude: longitude)
        }

        var result = Conditions(fetchedAt: .now)
        switch await w {
        case .success(let v):
            result.observations += v.observations
            result.alerts += v.alerts
        case .failure(let e): result.errors.append("Apple Weather: \(e.localizedDescription)")
        }
        switch await aq {
        case .success(let v): result.observations += v
        case .failure(let e): result.errors.append("OpenAQ: \(e.localizedDescription)")
        }
        switch await an {
        case .success(let v): result.observations += v
        case .failure(let e): result.errors.append("AirNow: \(e.localizedDescription)")
        }
        if openAQKey == nil && airNowKey == nil {
            result.errors.append("No air-quality key set — PM2.5 and ozone skipped.")
        }
        return result
    }

    private nonisolated static func attempt<T: Sendable>(_ work: @Sendable () async throws -> T) async -> Result<T, Error> {
        do { return .success(try await work()) } catch { return .failure(error) }
    }
}
