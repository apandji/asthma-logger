import AsthmaCore
import CoreLocation
import WeatherKit

/// Apple Weather (WeatherKit). Modeled outdoor values for the pin — labeled as such.
/// The Apple Weather attribution must be shown wherever these values appear (WeatherAttributionView).
struct WeatherProvider {
    /// How far the last few hours' temperature fell, for `Conditions.tempFallF`. Nil if the hours can't be read.
    func tempFall(latitude: Double, longitude: Double, at date: Date = .now) async -> Double? {
        guard let hours = try? await hourly(latitude: latitude, longitude: longitude, hours: 1,
                                            pastHours: Int(TempDrop.windowHours) + 1) else { return nil }
        return TempDrop.degreesFallen(at: date, in: hours.map(\.tempPoint))
    }

    static let source = "Apple Weather"

    func current(latitude: Double, longitude: Double) async throws -> (observations: [EnvObservation], alerts: [ConditionAlert], condition: String) {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let (now, alerts) = try await WeatherService.shared.weather(for: location, including: .current, .alerts)
        let asOf = now.date
        func obs(_ signal: Signal, _ value: Double, _ unit: String) -> EnvObservation {
            EnvObservation(signal: signal, value: value, unit: unit, asOf: asOf, source: Self.source,
                        spatialScale: .modelGrid, confidence: .medium)
        }
        let observations = [
            obs(.temperature, now.temperature.converted(to: .fahrenheit).value, "°F"),
            obs(.humidity, now.humidity * 100, "%"),
            obs(.dewpoint, now.dewPoint.converted(to: .fahrenheit).value, "°F"),
            obs(.uvIndex, Double(now.uvIndex.value), "UV"),
            obs(.windSpeed, now.wind.speed.converted(to: .milesPerHour).value, "mph"),
        ]
        let named = (alerts ?? []).map {
            ConditionAlert(name: $0.summary, source: $0.source, severity: String(describing: $0.severity))
        }
        return (observations, named, now.condition.description)
    }

    struct Hour: Sendable {
        let date: Date
        let temperatureF: Double
        let humidityPct: Double

        var tempPoint: TempPoint { TempPoint(date: date, temperatureF: temperatureF) }
    }

    /// Hourly from `pastHours` ago to `hours` ahead. Past hours feed the temperature-drop detector.
    func hourly(latitude: Double, longitude: Double, hours: Int, pastHours: Int = 0) async throws -> [Hour] {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let start = Date().addingTimeInterval(-Double(pastHours) * 3600)
        let end = Date().addingTimeInterval(Double(hours) * 3600)
        let forecast = try await WeatherService.shared.weather(for: location, including: .hourly(startDate: start, endDate: end))
        return forecast.map {
            Hour(date: $0.date, temperatureF: $0.temperature.converted(to: .fahrenheit).value, humidityPct: $0.humidity * 100)
        }
    }
}
