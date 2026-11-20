import Foundation
import Testing
@testable import AsthmaCore

/// v8: pressure swings, storms, tree and grass pollen, and combinations of conditions.
@Suite struct CombinationTests {
    static func t(_ h: Double) -> Date { Date(timeIntervalSince1970: 1_800_000_000 + h * 3600) }

    @Test func pressureChangeOverThreeHours() {
        let pts = [PressurePoint(date: Self.t(0), hPa: 1016), PressurePoint(date: Self.t(1), hPa: 1015),
                   PressurePoint(date: Self.t(2), hPa: 1014), PressurePoint(date: Self.t(3), hPa: 1013.5)]
        #expect(PressureChange.change(at: Self.t(3), in: pts) == -2.5)
        #expect(PressureChange.band(-2.5) == .falling)
        #expect(PressureChange.band(1.6) == .rising)
        #expect(PressureChange.band(0.9) == .steady)
        #expect(PressureChange.band(nil) == .unknown)
        // No reading three hours back: missing, not steady.
        #expect(PressureChange.change(at: Self.t(3), in: Array(pts.suffix(1))) == nil)
    }

    static func frame(_ c: ConditionsInput, _ kind: FrameKind = .baseline) -> FeatureFrame {
        FrameBuilder.frame(id: UUID().uuidString, kind: kind, hourOfDay: 15, month: 6, conditions: c)
    }

    @Test func stormWithPollen() {
        let yes = Self.frame(ConditionsInput(temperatureF: 75, pollenGrassRisk: "High", storm: true))
        #expect(Combination.stormPollen.present(in: yes) == true)
        // A storm with low pollen is a known no; a storm with no pollen reading is missing.
        #expect(Combination.stormPollen.present(in: Self.frame(ConditionsInput(pollenGrassRisk: "Low", storm: true))) == false)
        #expect(Combination.stormPollen.present(in: Self.frame(ConditionsInput(temperatureF: 75, storm: true))) == nil)
        // No storm is a known no whatever the pollen.
        #expect(Combination.stormPollen.present(in: Self.frame(ConditionsInput(temperatureF: 75, storm: false))) == false)
    }

    @Test func wildfireSmokeNeedsTheLookup() {
        var c = Conditions(observations: [EnvObservation(signal: .pm25, value: 40, unit: "µg/m³", asOf: .now, source: "Ambee", spatialScale: .modelGrid)])
        #expect(c.fireNearby == nil)                       // particles up, never looked
        c.firesChecked = true
        #expect(c.fireNearby == false)                     // looked, none
        c.nearestFireKm = 30
        #expect(c.fireNearby == true)
        c.nearestFireKm = 120
        #expect(c.fireNearby == false)
        let low = Conditions(observations: [EnvObservation(signal: .pm25, value: 5, unit: "µg/m³", asOf: .now, source: "Ambee", spatialScale: .modelGrid)])
        #expect(low.fireNearby == false)                   // low particles: a known no without a lookup
    }

    @Test func otherCombinations() {
        #expect(Combination.hotHazy.present(in: Self.frame(ConditionsInput(ozonePpb: 62, temperatureF: 93))) == true)
        #expect(Combination.coldDry.present(in: Self.frame(ConditionsInput(temperatureF: 25, humidityPct: 22))) == true)
        #expect(Combination.stillHazy.present(in: Self.frame(ConditionsInput(pm25: 20, windMph: 3))) == true)
        #expect(Combination.stillHazy.present(in: Self.frame(ConditionsInput(pm25: 20))) == nil)
        #expect(Combination.windyPollen.present(in: Self.frame(ConditionsInput(pollenWeedRisk: "Moderate", windMph: 22))) == true)
        #expect(Combination.frontComing.present(in: Self.frame(ConditionsInput(humidityPct: 80, pressureChangeHpa: -2.1))) == true)
    }

    @Test func aCombinationThatComesUpALotIsSurfaced() {
        // 10 inhaler moments, 7 in a storm with pollen up; 30 ordinary moments, 2 like that.
        let storm = ConditionsInput(temperatureF: 75, pollenGrassRisk: "High", storm: true)
        let plain = ConditionsInput(temperatureF: 75, pollenGrassRisk: "Low", storm: false)
        let frames = (0..<10).map { Self.frame($0 < 7 ? storm : plain, .attack) } + (0..<30).map { Self.frame($0 < 2 ? storm : plain, .baseline) }
        let report = Lift.compute(frames, gate: .default)
        #expect(report.combinations.first?.combination == .stormPollen)
        #expect(Bins.label("combo_stormPollen") == "Thunderstorms with pollen")
        // Combinations sit outside the five families: they don't move the radar.
        #expect(AirProfile.Category.of(bin: "combo_stormPollen") == nil)
    }

    @Test func rareCombinationsStayQuiet() {
        // Only 2 inhaler moments like it: under the gate's 4 in the level.
        let storm = ConditionsInput(temperatureF: 75, pollenGrassRisk: "High", storm: true)
        let plain = ConditionsInput(temperatureF: 75, pollenGrassRisk: "Low", storm: false)
        let frames = (0..<10).map { Self.frame($0 < 2 ? storm : plain, .attack) } + (0..<30).map { _ in Self.frame(plain, .baseline) }
        #expect(Lift.compute(frames, gate: .default).combinations.isEmpty)
    }

    @Test func ambeeIllnessForecastPicksTheWeek() throws {
        let json = #"{"message":"success","cbsa_name":"St. Louis, MO-IL","init_ts":"2026-11-14T00:00:00.000Z","data":[{"epi_week_start_date":"2026-11-15T00:00:00.000Z","epi_week_end_date":"2026-11-21T00:00:00.000Z","ili_risk":3,"ili_risk_category":"Low","surge_expected":false},{"epi_week_start_date":"2026-11-22T00:00:00.000Z","epi_week_end_date":"2026-11-28T00:00:00.000Z","ili_risk":4,"ili_risk_category":"Moderate","surge_expected":false}]}"#
        let r = try JSONDecoder().decode(Ambee.ILIResponse.self, from: Data(json.utf8))
        let day = ISO8601DateFormatter().date(from: "2026-11-24T15:00:00Z")!
        #expect(r.reading(on: day)?.level == .moderate)
        #expect(r.reading(on: ISO8601DateFormatter().date(from: "2027-01-10T15:00:00Z")!) == nil)
    }

    @Test func ambeePollenCarriesItsRiskWord() {
        var h = AmbeeHour(date: .now, weedPollen: 110)
        h.weedRisk = "High"; h.pressureHpa = 1012
        let c = Conditions(observations: h.observations(source: Ambee.source))
        #expect(c.input.pollenWeedRisk == "High")
        #expect(c.best(.pressure)?.value == 1012)
    }
}

/// The species under a pollen total (`PollenSpecies`): kept as sent, zeros too.
@Suite struct PollenSpeciesTests {
    @Test func speciesComeThroughFromAmbee() throws {
        let json = #"{"message":"success","data":[{"Risk":{"grass_pollen":"Low","tree_pollen":"Low","weed_pollen":"Low"},"Count":{"grass_pollen":0,"tree_pollen":3,"weed_pollen":11},"Species":{"Grass":{"Grass":0},"Others":2,"Tree":{"Ash":0,"Oak":3,"Elm":0},"Weed":{"Ragweed":11}},"timestamp":"2026-11-18T10:00:00.000Z","unixTs":1794996000}]}"#
        let pollen = try JSONDecoder().decode(Ambee.PollenResponse.self, from: Data(json.utf8))
        let hour = try #require(Ambee.hours(airQuality: .init(), pollen: pollen, weather: [], isForecast: false).first)
        let s = try #require(hour.species)
        #expect(s.counts(.tree).map(\.name) == ["Oak", "Ash", "Elm"])        // most first, then by name; zeros kept
        #expect(s.counts(.weed).first?.count == 11)
        #expect(s.others == 2 && s.source == Ambee.source)
        #expect(hour.weedRisk == "Low")
        #expect(PollenSpecies.text(11) == "11 particles/m³")
    }

    @Test func oldUnitReadsAsAmbees() {
        let old = EnvObservation(signal: .pollenTree, value: 40, unit: "grains/m³", asOf: .now, source: "Ambee", spatialScale: .modelGrid)
        #expect(ObservationCopy.value(old) == "40 particles/m³")
    }
}
