import Foundation
import Testing
@testable import AsthmaCore

@Suite struct BaselineBackfillTests {
    let cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "America/Chicago")!; return c }()
    func at(_ day: Int, _ h: Int, _ m: Int = 0) -> Date { cal.date(from: DateComponents(year: 2026, month: 10, day: day, hour: h, minute: m))! }
    let home = BaselineBackfill.Spot(latitude: 38.6, longitude: -90.25, name: "Home")

    @Test func oneSamplePerPartOfTheDay() {
        let slots = BaselineBackfill.plan(day: at(10, 12), inhaler: [], baselines: [], visits: [], home: home, logged: [], calendar: cal)
        #expect(slots.count == 3)
        let hours = slots.map { cal.component(.hour, from: $0.date) }
        for (part, h) in zip(BaselineBackfill.parts, hours) { #expect(part.contains(h)) }
        #expect(slots.allSatisfy { $0.source == .home })
    }

    @Test func staysClearOfInhalerUse() {
        let puffs = [at(10, 9), at(10, 14)]
        let slots = BaselineBackfill.plan(day: at(10, 12), inhaler: puffs, baselines: [], visits: [], home: home, logged: [], calendar: cal)
        for s in slots { for p in puffs { #expect(abs(s.date.timeIntervalSince(p)) >= BaselineBackfill.clearOfInhaler) } }
    }

    @Test func aVisitWinsOverHome() {
        let work = BaselineBackfill.Visit(latitude: 38.63, longitude: -90.25, arrival: at(10, 7), departure: at(10, 23))
        let slots = BaselineBackfill.plan(day: at(10, 12), inhaler: [], baselines: [], visits: [work], home: home, logged: [], calendar: cal)
        #expect(slots.allSatisfy { $0.source == .visit && $0.latitude == 38.63 })
    }

    @Test func nothingKnownLeavesTheDayUnsampled() {
        #expect(BaselineBackfill.plan(day: at(10, 12), inhaler: [], baselines: [], visits: [], home: nil, logged: [], calendar: cal).isEmpty)
        let spot = BaselineBackfill.Spot(latitude: 38.61, longitude: -90.2, name: "Soulard", at: at(10, 18))
        let s = BaselineBackfill.plan(day: at(10, 12), inhaler: [], baselines: [], visits: [], home: nil, logged: [spot], calendar: cal)
        #expect(s.count == 3 && s.allSatisfy { $0.source == .loggedSpot })
    }

    @Test func alreadySampledPartsAreLeft() {
        let s = BaselineBackfill.plan(day: at(10, 12), inhaler: [], baselines: [at(10, 8)], visits: [], home: home, logged: [], calendar: cal)
        #expect(s.count == 2)
    }

    @Test func deterministicPerDay() {
        let a = BaselineBackfill.plan(day: at(10, 1), inhaler: [], baselines: [], visits: [], home: home, logged: [], calendar: cal)
        let b = BaselineBackfill.plan(day: at(10, 20), inhaler: [], baselines: [], visits: [], home: home, logged: [], calendar: cal)
        #expect(a == b)
    }

    @Test func daysRunFromTheFirstMomentToYesterday() {
        let days = BaselineBackfill.days(firstMoment: at(10, 15), now: at(13, 9), done: [cal.startOfDay(for: at(11, 0))], calendar: cal)
        #expect(days == [cal.startOfDay(for: at(10, 0)), cal.startOfDay(for: at(12, 0))])
    }
}
