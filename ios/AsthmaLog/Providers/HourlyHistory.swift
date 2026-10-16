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

    nonisolated private struct SensorHour: Codable, Sendable {
        struct Period: Codable, Sendable { var datetimeFrom: OpenAQ.DateTimePair? }
        var value: Double?
        var period: Period?
    }

    private static func pm25Hours(_ lat: Double, _ lon: Double, _ from: Date, _ to: Date) async -> Result<(points: [HourPoint], station: String?), Error> {
        guard let key = Secrets.openAQ else { return .success(([], nil)) }
        do {
            let provider = OpenAQProvider(key: key)
            var locations = try await provider.search(lat, lon, monitor: true)
            if !locations.contains(where: { ($0.sensors ?? []).contains(where: \.measuresPM25) }) {
                locations += try await provider.search(lat, lon, monitor: false)
            }
            guard let loc = OpenAQ.nearest(locations, lat: lat, lon: lon, measures: { $0.measuresPM25 }),
                  let sensor = (loc.sensors ?? []).first(where: \.measuresPM25)?.id else { return .success(([], nil)) }
            let iso = ISO8601DateFormatter()
            var c = URLComponents(string: "\(OpenAQ.baseURL)/sensors/\(sensor)/hours")!
            c.queryItems = [
                URLQueryItem(name: "datetime_from", value: iso.string(from: from)),
                URLQueryItem(name: "datetime_to", value: iso.string(from: to)),
                URLQueryItem(name: "limit", value: "500"),
            ]
            let rows = try await HTTP.get(c.url!, headers: ["X-API-Key": key, "Accept": "application/json"],
                                          as: OpenAQ.Results<SensorHour>.self).results ?? []
            let parse = ISO8601DateFormatter()
            let points = rows.compactMap { r -> HourPoint? in
                guard let v = r.value, v >= 0, let s = r.period?.datetimeFrom?.utc, let d = parse.date(from: s) else { return nil }
                return HourPoint(date: d, value: v)
            }.sorted { $0.date < $1.date }
            return .success((points, loc.name))
        } catch { return .failure(error) }
    }
}
