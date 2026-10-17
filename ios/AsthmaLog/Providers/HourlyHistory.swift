import AsthmaCore
import CoreLocation
import Foundation
import WeatherKit

/// One hourly value for the Data view's charts.
struct HourPoint: Identifiable, Sendable {
    let date: Date
    let value: Double
    var id: Date { date }
}

/// Hour-by-hour outdoor history for one spot, so the charts draw continuous lines without the phone
/// sampling in the background: Apple Weather's past hours for temperature and humidity, and the
/// nearest OpenAQ monitor's hourly PM2.5. Fails open: whatever loads is shown, the rest is a note.
struct HourlyHistory: Sendable {
    var temperature: [HourPoint] = []
    var humidity: [HourPoint] = []
    var pm25: [HourPoint] = []
    var pm25Station: String?
    var notes: [String] = []

    static func load(latitude: Double, longitude: Double, from: Date, to: Date) async -> HourlyHistory {
        async let weather = weatherHours(latitude, longitude, from, to)
        async let air = pm25Hours(latitude, longitude, from, to)
        var h = HourlyHistory()
        switch await weather {
        case .success(let hours):
            h.temperature = hours.map { HourPoint(date: $0.date, value: $0.temperatureF) }
            h.humidity = hours.map { HourPoint(date: $0.date, value: $0.humidityPct) }
        case .failure(let e): h.notes.append("Apple Weather: \(e.localizedDescription)")
        }
        switch await air {
        case .success(let r):
            h.pm25 = r.points
            h.pm25Station = r.station
            if r.points.isEmpty { h.notes.append("No hourly PM2.5 from a nearby monitor.") }
        case .failure(let e): h.notes.append("OpenAQ: \(e.localizedDescription)")
        }
        return h
    }

    private static func weatherHours(_ lat: Double, _ lon: Double, _ from: Date, _ to: Date) async -> Result<[WeatherProvider.Hour], Error> {
        do {
            let forecast = try await WeatherService.shared.weather(
                for: CLLocation(latitude: lat, longitude: lon), including: .hourly(startDate: from, endDate: to))
            return .success(forecast.map {
                WeatherProvider.Hour(date: $0.date, temperatureF: $0.temperature.converted(to: .fahrenheit).value,
                                     humidityPct: $0.humidity * 100)
            })
        } catch { return .failure(error) }
    }

    private static func pm25Hours(_ lat: Double, _ lon: Double, _ from: Date, _ to: Date) async -> Result<(points: [HourPoint], station: String?), Error> {
        guard let key = Secrets.openAQ else { return .success(([], nil)) }
        do {
            let r = try await OpenAQProvider(key: key).hours(lat, lon, from: from, to: to, measures: { $0.measuresPM25 })
            return .success((r.values.map { HourPoint(date: $0.date, value: $0.value) }, r.station))
        } catch { return .failure(error) }
    }
}
