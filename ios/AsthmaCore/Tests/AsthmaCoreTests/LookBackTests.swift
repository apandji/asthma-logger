import Foundation
import Testing
@testable import AsthmaCore

@Suite struct LookBackTests {
    let moment = Date(timeIntervalSince1970: 1_790_000_000)

    /// One value per hour for the 48 hours before the moment, oldest first. `f(hoursBefore)`.
    func series(_ f: (Int) -> Double?) -> [HourValue] {
        (0...48).reversed().compactMap { h in f(h).map { HourValue(date: moment.addingTimeInterval(Double(-h) * 3600), value: $0) } }
    }

    @Test func windowsSplitAtSixHours() {
        let w = LookBack.windows(at: moment)
        #expect(w.now.contains(moment))
        #expect(w.now.contains(moment.addingTimeInterval(-6 * 3600)))
        #expect(!w.earlier.contains(moment.addingTimeInterval(-6 * 3600)))
        #expect(w.earlier.contains(moment.addingTimeInterval(-6 * 3600 - 1)))
        #expect(w.earlier.contains(moment.addingTimeInterval(-48 * 3600)))
        #expect(!w.earlier.contains(moment.addingTimeInterval(-48 * 3600 - 1)))
    }

    @Test func smokeYesterdayIsEarlier() {
        // PM2.5 45 µg/m³ 20–30 hours before, clean otherwise.
        let pm = series { h in (20...30).contains(h) ? 45 : 8 }
        let b = LookBack.compute(at: moment, pm25: pm, ozone: [], temps: [])
        #expect(b.pm25Now.worst == 8)
        #expect(b.pm25Earlier.worst == 45)
        #expect(b.pm25Level == .earlier)
    }

    @Test func highNowWinsOverEarlier() {
        let pm = series { _ in 50 }
        #expect(LookBack.compute(at: moment, pm25: pm, ozone: [], temps: []).pm25Level == .now)
    }

    @Test func cleanIsNeither() {
        let pm = series { _ in 6 }
        #expect(LookBack.compute(at: moment, pm25: pm, ozone: [], temps: []).pm25Level == .neither)
    }

    @Test func thinWindowIsUnknownNotNeither() {
        // Only the last 6 hours were read: "earlier" has no data, so the level is missing.
        let pm = series { h in h <= 6 ? 6 : nil }
        let b = LookBack.compute(at: moment, pm25: pm, ozone: [], temps: [])
        #expect(b.pm25Earlier.hours == 0)
        #expect(b.pm25Level == nil)
        // A few scattered hours aren't enough either.
        let sparse = series { h in h <= 6 || h % 10 == 0 ? 6 : nil }
        #expect(LookBack.compute(at: moment, pm25: sparse, ozone: [], temps: []).pm25Level == nil)
    }

    @Test func ozoneUsesItsOwnCutOff() {
        let o3 = series { h in h == 30 ? 75 : 40 }
        #expect(LookBack.compute(at: moment, pm25: [], ozone: o3, temps: []).ozoneLevel == .earlier)
    }

    @Test func coldFrontYesterday() {
        // 70°F until 30 h before, then 56°F within two hours, then flat.
        let temps = series { h in h > 30 ? 70 : (h == 30 ? 63 : 56) }.map { TempPoint(date: $0.date, temperatureF: $0.value) }
        let b = LookBack.compute(at: moment, pm25: [], ozone: [], temps: temps)
        #expect(b.tempFallEarlier.worst == 14)
        #expect(b.tempFallNow.worst == 0)
        #expect(b.tempDropLevel == .earlier)
    }

    @Test func openAQHoursConvertPpm() {
        let rows = [
            OpenAQ.SensorHour(value: 0.072, period: .init(datetimeFrom: .init(utc: "2026-10-16T14:00:00Z", local: nil))),
            OpenAQ.SensorHour(value: 0.041, period: .init(datetimeFrom: .init(utc: "2026-10-16T13:00:00Z", local: nil))),
            OpenAQ.SensorHour(value: -1, period: .init(datetimeFrom: .init(utc: "2026-10-16T12:00:00Z", local: nil))),
        ]
        let v = OpenAQ.hourValues(rows, units: "ppm")
        #expect(v.count == 2)
        #expect(v.first!.value == 41)  // sorted oldest first, ppm → ppb
        #expect(abs(v.last!.value - 72) < 0.0001)
        #expect(OpenAQ.hourValues(rows, units: "µg/m³").last!.value == 0.072)
    }

    @Test func conditionsKeepLookBackAndOldOnesDecode() throws {
        var c = Conditions()
        c.lookBack = LookBack(pm25Earlier: WindowPeak(worst: 40, hours: 42))
        let round = try JSONDecoder().decode(Conditions.self, from: JSONEncoder().encode(c))
        #expect(round.lookBack?.pm25Earlier.worst == 40)
        let old = try JSONDecoder().decode(Conditions.self, from: Data(#"{"observations":[],"alerts":[],"errors":[],"fetchedAt":0}"#.utf8))
        #expect(old.lookBack == nil)
    }
}
