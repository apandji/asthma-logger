import Testing
@testable import AsthmaCore

@Suite struct AirProfileTests {
    @Test func everyBinHasAFamilyOrIsKnowinglyLeftOut() {
        // Stress is a tag only, never sampled on baselines: off the radar until it has a signal (trigger lens).
        let outside: Set<String> = ["hour", "season", "place", "indoor_outdoor", "tag_stress"]
        for def in Bins.all where !outside.contains(def.bin) {
            #expect(AirProfile.Category.of(bin: def.bin) != nil, "\(def.bin) has no family")
        }
    }

    @Test func emptyTableIsNotTracked() {
        let p = AirProfile(report: Lift.compute([], gate: .default))
        #expect(p.axes.allSatisfy { $0.status == .notTracked && $0.strength == 0 })
        #expect(p.leading == nil)
    }

    @Test func demoFramesGiveABoundedShapeWithCounts() {
        let p = AirProfile(report: Lift.compute(DemoData.frames(), gate: .demo))
        #expect(p.axes.count == 5)
        #expect(p.axis(.infections).status == .notTracked)
        #expect(p.axes.allSatisfy { (0...1).contains($0.strength) })
        // No reviewed notes in the demo frames: exertion can't be read yet.
        #expect(p.axis(.exertion).status == .notTracked)
        for a in p.axes where a.status == .pattern || a.status == .early {
            let r = try! #require(a.lead)
            #expect(r.attacksWith > 0 && r.attackRate > r.baselineRate)
        }
    }

    @Test func patternWinsOverAStrongerEarlyRow() {
        let gated = LiftRow(bin: "pm25", level: "high", attacksWith: 6, baselinesWith: 4, nAttacks: 12, nBaselines: 30,
                            attackRate: 0.5, baselineRate: 4.0 / 30, lift: 3.75, gated: true)
        let early = LiftRow(bin: "ozone", level: "high", attacksWith: 3, baselinesWith: 0, nAttacks: 4, nBaselines: 30,
                            attackRate: 0.75, baselineRate: 0, lift: .infinity, gated: false)
        let p = AirProfile(report: LiftReport(nAttacks: 12, nBaselines: 30, seasonHint: nil, rows: [early, gated], gatedRows: [gated]))
        #expect(p.axis(.particulates).status == .pattern)
        #expect(p.axis(.particulates).lead?.bin == "pm25")
        #expect(p.leading?.category == .particulates)
    }

    @Test func demoPersonIsPollenLed() {
        #expect(AirProfile.demoPerson.leading?.category == .biologics)
    }
}
