import Foundation
import Testing
@testable import AsthmaCore

struct LiftFixture: Decodable {
    struct Template: Decodable {
        let headline: String
        let caveat: String
        let drivers: [String]
    }

    let binSpecVersion: Int
    let gate: LiftGate
    let frames: [FeatureFrame]
    let expected: LiftReport
    let expectedTemplate: Template
}

struct BandFixture: Decodable {
    struct Input: Decodable {
        var pm25: Double?
        var ozone: Double?
        var temperatureF: Double?
        var isExtremeTemp: Bool?
        var humidity: Double?
        var weed: String?
        var aqi: Int?
        var stormSummary: String?
        var loggedAt: String?
    }

    struct Expected: Decodable, Equatable {
        let hourOfDay: Int
        let season: Season
        let tempBand: TempBand
        let humidityBand: HumidityBand
        let pm25Band: PollutantBand
        let ozoneBand: PollutantBand
        let pollenWeed: PollenLevel
        let smokeAtPoint: Bool
        let heatAlert: Bool
    }

    struct Case: Decodable {
        let input: Input
        let expected: Expected
    }

    let cases: [Case]
}

@Suite("Matches the web prototype")
struct GoldenTests {
    @Test func liftFixturesExist() throws {
        #expect(try Fixtures.liftFiles().count >= 3)
    }

    @Test(arguments: try Fixtures.liftFiles())
    func liftMatchesPrototype(_ url: URL) throws {
        let fx = try Fixtures.load(LiftFixture.self, url)
        let got = Lift.compute(fx.frames, gate: fx.gate)
        let want = fx.expected

        #expect(got.nAttacks == want.nAttacks)
        #expect(got.nBaselines == want.nBaselines)
        #expect(got.seasonHint == want.seasonHint)
        #expect(got.rows.map(\.id) == want.rows.map(\.id), "row order")
        #expect(got.gatedRows.map(\.id) == want.gatedRows.map(\.id))
        for (g, w) in zip(got.rows, want.rows) {
            #expect(g.attacksWith == w.attacksWith && g.baselinesWith == w.baselinesWith, "\(g.id)")
            #expect(abs(g.attackRate - w.attackRate) < 1e-9 && abs(g.baselineRate - w.baselineRate) < 1e-9, "\(g.id)")
            #expect(g.lift.isFinite == w.lift.isFinite, "\(g.id)")
            if g.lift.isFinite { #expect(abs(g.lift - w.lift) < 1e-9, "\(g.id)") }
            #expect(g.gated == w.gated, "\(g.id)")
        }

        let t = Narrator.template(NarratorInput(report: got))
        #expect(t.headline == fx.expectedTemplate.headline)
        #expect(t.caveat == fx.expectedTemplate.caveat)
        #expect(t.drivers == fx.expectedTemplate.drivers)
    }

    @Test func bandsMatchPrototype() throws {
        let fx = try Fixtures.load(BandFixture.self, Fixtures.root.appendingPathComponent("bands-v1.json"))
        #expect(fx.cases.count > 20)
        for c in fx.cases {
            let i = c.input
            // loggedAt is local wall time "YYYY-MM-DDTHH:MM:SS"; default matches the export script.
            let stamp = i.loggedAt ?? "2026-07-15T15:30:00"
            let month = Int(stamp.dropFirst(5).prefix(2))!
            let hour = Int(stamp.dropFirst(11).prefix(2))!
            let input = ConditionsInput(
                pm25: i.pm25, ozonePpb: i.ozone, temperatureF: i.temperatureF, humidityPct: i.humidity,
                pollenWeedRisk: i.weed, aqi: i.aqi, isExtremeTemp: i.isExtremeTemp ?? false,
                alertNames: i.stormSummary.map { [$0] } ?? []
            )
            let f = FrameBuilder.frame(id: "x", kind: .attack, hourOfDay: hour, month: month, conditions: input)
            let got = BandFixture.Expected(
                hourOfDay: f.hourOfDay, season: f.season, tempBand: f.tempBand, humidityBand: f.humidityBand,
                pm25Band: f.pm25Band, ozoneBand: f.ozoneBand, pollenWeed: f.pollenWeed,
                smokeAtPoint: f.smokeAtPoint, heatAlert: f.heatAlert
            )
            #expect(got == c.expected, "\(i)")
        }
    }

    @Test func demoDataMatchesPrototype() throws {
        let fx = try Fixtures.load(LiftFixture.self, Fixtures.root.appendingPathComponent("lift-demo-gate.json"))
        #expect(DemoData.frames() == fx.frames)
    }
}
