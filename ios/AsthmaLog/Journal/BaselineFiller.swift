import AsthmaCore
import Foundation
import SwiftData

/// Fills in baseline moments across past days (AsthmaCore `BaselineBackfill` picks the hours and places;
/// this fetches each hour's outdoor air from history and saves the moment). Runs when the app comes forward,
/// a week of days at a time, back to your first moment (60 days at most). Never on a made-up data set or
/// demo moments. Fails open: a day whose air can't be fetched is tried again next time.
@MainActor
final class BaselineFiller {
    static let shared = BaselineFiller()
    private var running = false

    private static let doneKey = "backfill.doneDays"
    private static let lastRunKey = "backfill.lastRun"
    /// Days per run, so a first run on a long history doesn't hammer the APIs.
    static let daysPerRun = 7

    var enabled: Bool { UserDefaults.standard.object(forKey: Prefs.autoBaseline) as? Bool ?? true }

    func runIfDue(in context: ModelContext, force: Bool = false) async {
        guard enabled, !running, DataSets.active == nil else { return }
        let last = UserDefaults.standard.object(forKey: Self.lastRunKey) as? Date ?? .distantPast
        guard force || Date().timeIntervalSince(last) > 3 * 3600 else { return }
        running = true
        defer { running = false }

        let all = ((try? context.fetch(FetchDescriptor<LogEvent>(sortBy: [SortDescriptor(\.loggedAt)]))) ?? []).filter { !$0.isDemo }
        let inhaler = all.filter { $0.moment != .okay }.map(\.loggedAt)
        var baselines = all.filter { $0.moment == .okay }.map(\.loggedAt)
        let logged = all.compactMap { e -> BaselineBackfill.Spot? in
            guard let lat = e.latitude, let lon = e.longitude else { return nil }
            return .init(latitude: lat, longitude: lon, name: e.placeName, at: e.loggedAt)
        }
        let home = SavedPlace.load(SavedPlace.homeKey).map { BaselineBackfill.Spot(latitude: $0.lat, longitude: $0.lon, name: "Home") }
        var done = Set((UserDefaults.standard.array(forKey: Self.doneKey) as? [Double] ?? []).map(Date.init(timeIntervalSince1970:)))
        let days = BaselineBackfill.days(firstMoment: all.first?.loggedAt, now: .now, done: done).suffix(Self.daysPerRun)

        for day in days {
            let slots = BaselineBackfill.plan(day: day, inhaler: inhaler, baselines: baselines, visits: VisitLog.shared.forPlanning,
                                              home: home, logged: logged)
            var fetchedAny = slots.isEmpty
            // One fetch per place per day.
            let byPlace = Dictionary(grouping: slots) { "\(($0.latitude * 100).rounded()),\(($0.longitude * 100).rounded())" }
            for (_, group) in byPlace {
                guard let first = group.first else { continue }
                let air = await Self.dayOfAir(latitude: first.latitude, longitude: first.longitude, day: day)
                for slot in group {
                    guard let c = air.conditions(at: slot.date) else { continue }
                    fetchedAny = true
                    let e = LogEvent(moment: .okay, loggedAt: slot.date)
                    e.conditions = c
                    e.envStatus = .ready
                    e.latitude = slot.latitude
                    e.longitude = slot.longitude
                    e.placeName = slot.name
                    e.isBackfilled = true
                    // Active or not in the hour before, from Motion and Health history (missing when they can't say).
                    await ExertionReader.stamp(e, demo: false)
                    context.insert(e)
                    baselines.append(slot.date)
                }
            }
            if fetchedAny { done.insert(day) }
            try? context.save()
        }
        UserDefaults.standard.set(done.map(\.timeIntervalSince1970), forKey: Self.doneKey)
        UserDefaults.standard.set(Date.now, forKey: Self.lastRunKey)
    }

    /// Forget which days were filled (e.g. after loading your own data back).
    static func reset() {
        UserDefaults.standard.removeObject(forKey: doneKey)
        UserDefaults.standard.removeObject(forKey: lastRunKey)
    }

    // MARK: History

    /// A day's hourly air at one place: Apple Weather temperature and humidity, the nearest stations' PM2.5
    /// and ozone, with the 48 hours before so each moment gets its look-back.
    struct DayOfAir {
        var weather: [WeatherProvider.Hour]
        var pm25: LookBackService.Series
        var ozone: LookBackService.Series

        func conditions(at t: Date) -> Conditions? {
            /// The reading closest to the moment, within an hour.
            func nearest<T>(_ items: [T], _ date: (T) -> Date) -> T? {
                items.filter { abs(date($0).timeIntervalSince(t)) <= 3600 }
                    .min { abs(date($0).timeIntervalSince(t)) < abs(date($1).timeIntervalSince(t)) }
            }
            var obs: [EnvObservation] = []
            if let w = nearest(weather, \.date) {
                obs.append(EnvObservation(signal: .temperature, value: w.temperatureF, unit: "°F", asOf: w.date,
                                          source: WeatherProvider.source, spatialScale: .modelGrid))
                obs.append(EnvObservation(signal: .humidity, value: w.humidityPct, unit: "%", asOf: w.date,
                                          source: WeatherProvider.source, spatialScale: .modelGrid))
            }
            if let p = nearest(pm25.values, \.date) {
                obs.append(EnvObservation(signal: .pm25, value: p.value, unit: "µg/m³", asOf: p.date, source: "OpenAQ",
                                          spatialScale: .station, stationName: pm25.station))
            }
            if let o = nearest(ozone.values, \.date) {
                obs.append(EnvObservation(signal: .ozone, value: o.value, unit: "ppb", asOf: o.date, source: "OpenAQ",
                                          spatialScale: .station, stationName: ozone.station))
            }
            guard !obs.isEmpty else { return nil }
            var c = Conditions(observations: obs, fetchedAt: .now)
            let temps = weather.map(\.tempPoint)
            // The same drop check as a live moment.
            c.tempFallF = TempDrop.degreesFallen(at: t, in: temps)
            c.lookBack = LookBack.compute(at: t, pm25: pm25.values, ozone: ozone.values, temps: temps,
                                          pm25Station: pm25.station, ozoneStation: ozone.station)
            return c
        }
    }

    static func dayOfAir(latitude: Double, longitude: Double, day: Date) async -> DayOfAir {
        let start = Calendar.current.startOfDay(for: day)
        let end = start.addingTimeInterval(86_400)
        let from = start.addingTimeInterval(-(LookBack.spanHours + TempDrop.windowHours) * 3600)
        async let weather = try? WeatherProvider().hours(latitude: latitude, longitude: longitude, from: from, to: end)
        async let air = LookBackService.airHours(latitude, longitude, start.addingTimeInterval(-LookBack.spanHours * 3600), end)
        let a = await air
        return DayOfAir(weather: await weather ?? [], pm25: a.pm25, ozone: a.ozone)
    }
}
