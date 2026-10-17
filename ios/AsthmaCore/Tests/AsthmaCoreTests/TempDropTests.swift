import Foundation
import Testing
@testable import AsthmaCore

@Suite struct TempDropTests {
    let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    /// Hourly temperatures starting at t0.
    func hours(_ temps: [Double]) -> [TempPoint] {
        temps.enumerated().map { TempPoint(date: t0.addingTimeInterval(Double($0.offset) * 3600), temperatureF: $0.element) }
    }

    func at(_ hour: Double) -> Date { t0.addingTimeInterval(hour * 3600) }

    @Test func sharpFallInsideThreeHours() {
        let points = hours([72, 70, 64, 58])
        #expect(TempDrop.degreesFallen(at: at(3), in: points) == 14)
        #expect(TempDrop.band(TempDrop.degreesFallen(at: at(3), in: points)) == .sharp)
    }

    @Test func slowFallIsNotSharp() {
        let points = hours([60, 58, 56, 54])
        #expect(TempDrop.degreesFallen(at: at(3), in: points) == 6)
        #expect(TempDrop.band(6) == .none)
    }

    @Test func exactlyTenCounts() {
        #expect(TempDrop.band(10) == .sharp)
        #expect(TempDrop.band(9.9) == .none)
    }

    @Test func peakOlderThanTheWindowIsIgnored() {
        // 80°F four hours before, then flat: only the last three hours count.
        let points = hours([80, 66, 66, 66, 66])
        #expect(TempDrop.degreesFallen(at: at(4), in: points) == 0)
    }

    @Test func riseReadsAsNoDrop() {
        let points = hours([50, 55, 60, 65])
        #expect(TempDrop.band(TempDrop.degreesFallen(at: at(3), in: points)) == .none)
    }

    @Test func missingDataIsUnknownNotNone() {
        #expect(TempDrop.degreesFallen(at: at(3), in: []) == nil)
        // A reading at the hour but nothing before it.
        #expect(TempDrop.degreesFallen(at: at(0), in: hours([60])) == nil)
        // Nothing within an hour of the moment.
        #expect(TempDrop.degreesFallen(at: at(6), in: hours([70, 60])) == nil)
        #expect(TempDrop.band(nil) == .unknown)
    }

    @Test func momentBetweenHoursUsesTheLatestReading() {
        let points = hours([72, 68, 61])
        #expect(TempDrop.degreesFallen(at: at(2.5), in: points) == 11)
    }

    @Test func futureHoursAreNotUsed() {
        let points = hours([60, 60, 60, 40])
        #expect(TempDrop.degreesFallen(at: at(2), in: points) == 0)
    }

    @Test func frameCarriesTheBand() {
        let past = FrameBuilder.frame(id: "a", kind: .attack, hourOfDay: 17, month: 10,
                                      conditions: ConditionsInput(temperatureF: 58, tempFallF: 12))
        #expect(past.tempDrop == .sharp)
        let noHistory = FrameBuilder.frame(id: "b", kind: .baseline, hourOfDay: 17, month: 10,
                                           conditions: ConditionsInput(temperatureF: 58))
        #expect(noHistory.tempDrop == .unknown)
        let forecast = FrameBuilder.forecastFrame(id: "f", hourOfDay: 18, month: 10,
                                                  ForecastConditions(temperatureF: 50, tempFallF: 11))
        #expect(forecast.tempDrop == .sharp)
    }

    @Test func binIsMissingWhenUnknown() {
        let def = Bins.all.first { $0.bin == "temp_drop" }!
        #expect(def.levelOf(FeatureFrame(id: "u", kind: .attack, hourOfDay: 9, season: .fall)) == nil)
        #expect(def.levelOf(FeatureFrame(id: "s", kind: .attack, hourOfDay: 9, season: .fall, tempDrop: .sharp)) == "yes")
        #expect(def.levelOf(FeatureFrame(id: "n", kind: .attack, hourOfDay: 9, season: .fall, tempDrop: .none)) == "no")
    }

    @Test func liftFindsADropPattern() {
        var frames = DemoData.frames()
        let before = Lift.compute(frames, gate: .demo).rows
        #expect(!before.contains { $0.bin == "temp_drop" })  // no history → no rows
        for i in frames.indices {
            frames[i].tempDrop = frames[i].kind == .attack && i % 2 == 0 ? .sharp : .none
        }
        let row = Lift.compute(frames, gate: .demo).rows.first { $0.id == "temp_drop:yes" }
        #expect(row != nil)
        #expect(row!.attacksWith > 0)
        #expect(row!.baselinesWith == 0)
    }

    @Test func oldSavedFramesDecodeAsUnknown() throws {
        let json = #"{"id":"x","kind":"attack","hourOfDay":8,"season":"fall","tempBand":"mild","humidityBand":"ok","pm25Band":"low","ozoneBand":"low","pollenWeed":"unknown","smokeAtPoint":false,"heatAlert":false}"#
        let f = try JSONDecoder().decode(FeatureFrame.self, from: Data(json.utf8))
        #expect(f.tempDrop == .unknown)
    }

    @Test func coldStartNamesTheDrop() {
        let f = FeatureFrame(id: "f", kind: .baseline, hourOfDay: 18, season: .fall, tempDrop: .sharp)
        #expect(GenericHazards.list(f).contains("a sharp temperature drop"))
    }

    @Test func copyHasNoNumbers() {
        // NarrationGuard rejects numbers that aren't in the table, so the clause must not carry "10°F".
        let clause = Narrator.clause("temp_drop", "yes")
        #expect(clause.rangeOfCharacter(from: .decimalDigits) == nil)
        #expect(OutlookCopy.phrase("temp_drop", "yes") == "a sharp temperature drop")
    }

    @Test func weatherLine() {
        #expect(TempDrop.line(12.4) == "Dropped 12°F in the 3 hours before.")
        #expect(TempDrop.line(4) == nil)
        #expect(TempDrop.line(nil) == nil)
    }

    @Test func conditionsPassTheFallThrough() throws {
        var c = Conditions()
        c.tempFallF = 11
        #expect(c.input.tempFallF == 11)
        // Moments saved before v4 have no field and decode as unknown.
        let old = try JSONDecoder().decode(Conditions.self, from: Data(#"{"observations":[],"alerts":[],"errors":[],"fetchedAt":0}"#.utf8))
        #expect(old.tempFallF == nil)
    }
}
