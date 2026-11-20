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
        async let swing = weather.pressureChange(latitude: latitude, longitude: longitude)
        async let back = LookBackService.load(latitude: latitude, longitude: longitude, at: .now)
        async let aq = Self.attempt { () -> [EnvObservation] in
            guard let openAQKey else { return [] }
            return try await OpenAQProvider(key: openAQKey).observations(latitude: latitude, longitude: longitude)
        }
        async let an = Self.attempt { () -> [EnvObservation] in
            guard let airNowKey else { return [] }
            return try await AirNowProvider(key: airNowKey).current(latitude: latitude, longitude: longitude)
        }
        // Ambee: pollen and air, live and cached when there's a key; the sample (DemoAmbee, labelled
        // "Ambee (demo)", never in patterns) on a build without one.
        let ambee = await AmbeeClient.current
        async let am = Self.attempt { () -> AmbeeHour in
            try await ambee.latest(latitude: latitude, longitude: longitude, at: .now)
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
        case .success(let hour):
            result.observations += hour.observations(source: ambee.sourceName)
            // The species under the pollen totals, from the live source only (the sample has none).
            if !Ambee.isDemo(ambee.sourceName) { result.pollenSpecies = hour.species }
        case .failure(let e): result.errors.append("Ambee: \(e.localizedDescription)")
        }
        result.tempFallF = await fall
        result.pressureChangeHpa = await swing
        await Self.stampFires(&result, latitude: latitude, longitude: longitude, around: nil)
        result.lookBack = await back
        // A demo scenario's air, on every log while it's on (never in patterns).
        DemoScenario.current.apply(to: &result)

        return result
    }

    /// Detected fires nearby, looked up only when fine particles are raised and there's an Ambee key (the
    /// wildfire-smoke combination). Low particles need no lookup; a failed lookup stays missing.
    static func stampFires(_ c: inout Conditions, latitude: Double, longitude: Double, around: Date?,
                           fires known: [Ambee.FireResponse.Fire]? = nil) async {
        guard let key = Secrets.ambee, Banding.pm25(c.bestReal(.pm25)?.value) != .low,
              Banding.pm25(c.bestReal(.pm25)?.value) != .unknown else { return }
        let fires: [Ambee.FireResponse.Fire]
        if let known { fires = known } else {
            guard let found = await AmbeeClient(key: key).firesOrNil(latitude: latitude, longitude: longitude) else { return }
            fires = found
        }
        c.firesChecked = true
        c.nearestFireKm = WildfiresNearby.nearestKm(fires: fires, latitude: latitude, longitude: longitude, around: around)
    }

    private nonisolated static func attempt<T: Sendable>(_ work: @Sendable () async throws -> T) async -> Result<T, Error> {
        do { return .success(try await work()) } catch { return .failure(error) }
    }
}
