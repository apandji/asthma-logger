import Foundation
import Testing
@testable import AsthmaCore

/// The navigator data set, on the real air that ships in the app (`navigator-air.json`).
@Suite struct NavigatorSetTests {
    static func air() throws -> NavigatorAir {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appending(path: "../../../AsthmaLog/Resources/navigator-air.json")
        return try JSONDecoder().decode(NavigatorAir.self, from: Data(contentsOf: file))
    }

    static func report(_ moments: [NavigatorSet.Moment]) -> LiftReport {
        let frames = moments.compactMap { m -> FeatureFrame? in
            guard let kind = m.kind.frameKind else { return nil }
            return FrameBuilder.frame(id: UUID().uuidString, kind: kind, date: m.at, conditions: m.conditions.input,
                                      tags: m.tags, tagsReviewed: m.tagsReviewed)
        }
        return Lift.compute(frames, gate: .default)
    }

    @Test func threeCitiesEnoughToLearnFrom() throws {
        let ms = NavigatorSet.moments(air: try Self.air())
        #expect(Set(ms.map(\.city)) == ["Fresno", "Denver", "St. Louis"])
        let r = Self.report(ms)
        #expect(r.nAttacks >= LiftGate.default.minAttacks && r.nBaselines >= LiftGate.default.minBaselines)
    }

    @Test func fineParticlesComeThroughTheGate() throws {
        let r = Self.report(NavigatorSet.moments(air: try Self.air()))
        let gated = r.gatedRows.map { "\($0.bin):\($0.level) \($0.attacksWith)/\($0.nAttacks) vs \($0.baselinesWith)/\($0.nBaselines)" }
        #expect(r.gatedRows.contains { "\($0.bin)".contains("pm25") || "\($0.bin)".contains("smoke") }, "Gated: \(gated)")
        let learned = Archetype(profile: AirProfile(report: r), learned: true)
        print("Navigator archetype:", learned.name, gated)
    }

    @Test func everyReadingNamesARealSource() throws {
        let ms = NavigatorSet.moments(air: try Self.air())
        let sources = Set(ms.flatMap { $0.conditions.observations.map(\.source) })
        #expect(sources.isSubset(of: [NavigatorSet.openMeteo, Ambee.source]))
        #expect(ms.allSatisfy { $0.conditions.best(.pm25) != nil && $0.conditions.best(.temperature) != nil })
    }

    @Test func sameSeedSameJournal() throws {
        let air = try Self.air()
        #expect(NavigatorSet.moments(air: air).map(\.at) == NavigatorSet.moments(air: air).map(\.at))
    }
}
