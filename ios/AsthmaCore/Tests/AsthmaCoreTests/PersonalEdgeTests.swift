import Foundation
import Testing
@testable import AsthmaCore

@Suite struct PersonalEdgeTests {
    static let end = ISO8601DateFormatter().date(from: "2026-10-17T20:00:00Z")!

    static func temps(_ p: DataSetPreset) -> (flare: [Double], baseline: [Double]) {
        let ms = p.moments(endingAt: end)
        let t = { (k: MomentKind) in ms.filter { $0.kind == k }.compactMap { $0.conditions.input.temperatureF } }
        return (t(.rescue), t(.okay))
    }

    @Test func findsYourOwnColdEdge() throws {
        let (f, b) = Self.temps(.coldBelow40)
        let e = try #require(PersonalEdge.find(flare: f, baseline: b, side: .below, general: 32))
        #expect(e.value == 40)
        #expect(!e.isGeneral)
        #expect(e.stability >= 0.6)
        #expect(e.phrase(unit: "°F") == "below about 40°F")
    }

    @Test func noEdgeWhenNothingStandsOut() {
        let (f, b) = Self.temps(.nothingStandsOut)
        #expect(PersonalEdge.find(flare: f, baseline: b, side: .below, general: 32) == nil)
        #expect(PersonalEdge.find(flare: f, baseline: b, side: .above, general: 90) == nil)
    }

    @Test func snapsToTheGeneralEdgeWhenClose() throws {
        // Flares at 26–31°F, baselines mild: the found cut sits within a step of 32, so say 32.
        let flare = (0..<14).map { 26 + Double($0 % 6) }
        let baseline = (0..<40).map { 45 + Double($0 % 25) } + [30, 31]
        let e = try #require(PersonalEdge.find(flare: flare, baseline: baseline, side: .below, general: 32))
        #expect(e.isGeneral)
        #expect(e.value == 32)
    }

    @Test func tooFewMomentsSaysNothing() {
        #expect(PersonalEdge.find(flare: [35, 36, 37], baseline: Array(repeating: 60, count: 40), side: .below, general: 32) == nil)
    }
}
