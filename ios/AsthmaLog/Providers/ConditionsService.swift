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
        async let fall = weather.tempFall(latitude: latitude, longitude: longitude)
        async let back = LookBackService.load(latitude: latitude, longitude: longitude, at: .now)
        async let aq = Self.attempt { () -> [EnvObservation] in
            guard let openAQKey else { return [] }
            return try await OpenAQProvider(key: openAQKey).observations(latitude: latitude, longitude: longitude)
        }
        async let an = Self.attempt { () -> [EnvObservation] in
            guard let airNowKey else { return [] }
            return try await AirNowProvider(key: airNowKey).current(latitude: latitude, longitude: longitude)
        }
        // Ambee: pollen and air in Ambee's own shapes, from the live API once there's a key and from the sample
        // (DemoAmbee, labelled "Ambee (demo)", never in patterns) until then.
        let ambee = await AmbeeClient.current
        async let am = Self.attempt { () -> [EnvObservation] in
            let hour = try await ambee.latest(latitude: latitude, longitude: longitude, at: .now)
            return hour.observations(source: ambee.sourceName)
        }

        var result = Conditions(fetchedAt: .now)
        switch await w {
        case .success(let v):
            result.observations += v.observations
            result.alerts += v.alerts
            result.weatherCondition = v.condition
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
        switch await am {
        case .success(let v): result.observations += v
        case .failure(let e): result.errors.append("Ambee: \(e.localizedDescription)")
        }
        result.tempFallF = await fall
        result.lookBack = await back
        // A demo scenario's air, on every log while it's on (never in patterns).
        DemoScenario.current.apply(to: &result)

        return result
    }

    private nonisolated static func attempt<T: Sendable>(_ work: @Sendable () async throws -> T) async -> Result<T, Error> {
        do { return .success(try await work()) } catch { return .failure(error) }
    }
}
