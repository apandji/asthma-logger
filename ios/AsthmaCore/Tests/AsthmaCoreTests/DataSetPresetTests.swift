import Foundation
import Testing
@testable import AsthmaCore

@Suite struct DataSetPresetTests {
    static let end = ISO8601DateFormatter().date(from: "2026-10-17T20:00:00Z")!

    static func archetype(_ p: DataSetPreset) -> (Archetype, LiftReport) {
        let frames = p.moments(endingAt: end).compactMap { m -> FeatureFrame? in
            guard let kind = m.kind.frameKind else { return nil }
            return FrameBuilder.frame(id: UUID().uuidString, kind: kind, date: m.at, conditions: m.conditions.input,
                                      tags: m.tags, tagsReviewed: m.tagsReviewed,
                                      infection: m.infection)
        }
        let report = Lift.compute(frames, gate: .default)
        let learned = report.nAttacks >= LiftGate.default.minAttacks && report.nBaselines >= LiftGate.default.minBaselines
        return (Archetype(profile: AirProfile(report: report), learned: learned), report)
    }

    @Test(arguments: DataSetPreset.allCases)
    func eachPresetLandsOnItsArchetype(_ p: DataSetPreset) {
        let (a, report) = Self.archetype(p)
        #expect(a.kind == p.expected && a.name == p.title, "\(p.title) came out \(a.name). Gated: \(report.gatedRows.map { "\($0.bin):\($0.level) \($0.attacksWith)/\($0.nAttacks) vs \($0.baselinesWith)/\($0.nBaselines)" })")
    }

    @Test func sameSeedSameJournal() {
        let a = DataSetPreset.mixed.moments(endingAt: Self.end), b = DataSetPreset.mixed.moments(endingAt: Self.end)
        #expect(a.map(\.at) == b.map(\.at))
    }

    @Test func baselinesSpreadAcrossTheDay() {
        let hours = Set(DataSetPreset.allergenLed.moments(endingAt: Self.end).filter { $0.kind == .okay }
            .map { Calendar.current.component(.hour, from: $0.at) })
        #expect(hours.count >= 8)
    }
}
