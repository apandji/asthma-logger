import AsthmaCore
import Foundation

/// The 48 hours before a moment (docs/air-outlook.md › Looking back): Apple Weather's past hours for
/// temperature, the nearest OpenAQ stations' hourly PM2.5 and ozone. Works for a moment logged now and,
/// for backfill, one logged days ago. Fails open: whatever loads is kept; nil only when nothing did.
enum LookBackService {
    static func load(latitude: Double, longitude: Double, at date: Date) async -> LookBack? {
        let from = date.addingTimeInterval(-LookBack.spanHours * 3600)
        // Three hours more, so the first hours of "earlier" can still measure a 3-hour drop.
        let weatherFrom = from.addingTimeInterval(-TempDrop.windowHours * 3600)
        async let weather = try? WeatherProvider().hours(latitude: latitude, longitude: longitude, from: weatherFrom, to: date)
        async let air = airHours(latitude, longitude, from, date)

        let temps = (await weather ?? []).map(\.tempPoint)
        let a = await air
        if temps.isEmpty && a.pm25.values.isEmpty && a.ozone.values.isEmpty { return nil }
        return LookBack.compute(at: date, pm25: a.pm25.values, ozone: a.ozone.values, temps: temps,
                                pm25Station: a.pm25.station, ozoneStation: a.ozone.station)
    }

    private typealias Series = (values: [HourValue], station: String?)

    private static func airHours(_ lat: Double, _ lon: Double, _ from: Date, _ to: Date) async -> (pm25: Series, ozone: Series) {
        guard let key = Secrets.openAQ else { return (([], nil), ([], nil)) }
        let provider = OpenAQProvider(key: key)
        guard let near = try? await provider.search(lat, lon, monitor: true) else { return (([], nil), ([], nil)) }
        async let pm = try? provider.hours(lat, lon, from: from, to: to, measures: { $0.measuresPM25 }, locations: near)
        async let o3 = try? provider.hours(lat, lon, from: from, to: to, measures: { $0.measuresOzone }, locations: near)
        return (await pm ?? ([], nil), await o3 ?? ([], nil))
    }
}
