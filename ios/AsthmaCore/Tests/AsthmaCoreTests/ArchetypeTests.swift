import Foundation
import Testing
@testable import AsthmaCore

@Suite struct ArchetypeTests {
    func row(_ bin: String, _ level: String, _ a: Int, _ b: Int, gated: Bool = true) -> LiftRow {
        LiftRow(bin: bin, level: level, attacksWith: a, baselinesWith: b, nAttacks: 10, nBaselines: 24,
                attackRate: Double(a) / 10, baselineRate: Double(b) / 24, lift: 2, gated: gated)
    }

    func profile(_ rows: [LiftRow]) -> AirProfile {
        AirProfile(report: LiftReport(nAttacks: 10, nBaselines: 24, seasonHint: nil, rows: rows, gatedRows: rows.filter(\.gated)))
    }

    @Test func theScreenshotPersonIsHotAndHazy() {
        // Ozone 8 of 10 vs 0 of 24, hot 7 of 10 vs 2 of 24, weed pollen a little.
        let p = profile([row("ozone", "high", 8, 0), row("temp", "hot", 7, 2), row("pollen_weed", "high", 4, 6)])
        let a = Archetype(profile: p, learned: true)
        #expect(a.kind == .hotHazy)
        #expect(a.name == "Hot, hazy days")
        #expect(a.evidence == "Most often: high ozone (8 of 10) and heat (7 of 10).")
    }

    @Test func oneStrongCategoryNamesIt() {
        #expect(Archetype(profile: .demoPerson, learned: true).kind == .biologics)
    }

    @Test func threeStrongIsMixed() {
        let p = profile([row("ozone", "high", 7, 2), row("temp", "hot", 7, 2), row("pollen_weed", "high", 7, 2)])
        #expect(Archetype(profile: p, learned: true).kind == .mixed)
    }

    @Test func notLearnedIsFormingAndNothingIsNoClearTrigger() {
        #expect(Archetype(profile: .demoPerson, learned: false).kind == .forming)
        let flat = profile([row("ozone", "high", 2, 6, gated: false)])
        #expect(Archetype(profile: flat, learned: true).kind == .noClearTrigger)
    }

    @Test func everyNameAndLineIsPlainAndSafe() {
        for k in Archetype.Kind.allCases {
            let a = Archetype(kind: k, categories: [.weather, .biologics, .particulates], leads: [])
            for s in [a.name, a.line] {
                for w in AirAdvice.bannedWords { #expect(!s.lowercased().contains(w), "“\(s)”") }
                #expect(!s.contains("%"))
            }
        }
    }

    @Test func strengthWords() {
        #expect(AirProfile.Strength.of(row("ozone", "high", 8, 0)) == .strong)
        #expect(AirProfile.Strength.of(row("ozone", "high", 3, 2)) == .some)
        #expect(AirProfile.Strength.of(row("ozone", "high", 3, 2, gated: false)) == .leaning)
        #expect(AirProfile.Strength.of(row("ozone", "high", 1, 9)) == .none)
    }

    @Test func biologicsListsWhatIsntTrackedYet() {
        let t = AirProfile.triggers(.biologics, report: LiftReport(nAttacks: 10, nBaselines: 24, seasonHint: nil,
                                                                   rows: [row("pollen_weed", "high", 7, 2)], gatedRows: []))
        #expect(t.first?.name == "High weed pollen")
        #expect(t.contains { $0.name == "Tree pollen" && $0.strength == .notTracked })
    }

    @Test func rhythmNeedsAClearPart() {
        let cal = Calendar(identifier: .gregorian)
        func at(_ h: Int) -> Date { cal.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: h))! }
        let r = Rhythm(dates: [at(18), at(19), at(20), at(9)], calendar: cal)
        #expect(r?.sentence == "You tend to use your inhaler in the evening: 3 of your 4 rescue moments.")
        #expect(Rhythm(dates: [at(1), at(9)], calendar: cal) == nil)
    }

    @Test func historyRecordsChangesNotRepeats() {
        let d = Date(timeIntervalSince1970: 1_800_000_000)
        let a = ProfileSnapshot(date: d, kind: .biologics, strengths: [0, 0.5, 0.2, 0])
        var h = ProfileSnapshot.record(a, into: [])
        h = ProfileSnapshot.record(ProfileSnapshot(date: d.addingTimeInterval(86_400), kind: .biologics, strengths: [0, 0.5, 0.2, 0]), into: h)
        #expect(h.count == 1)
        h = ProfileSnapshot.record(ProfileSnapshot(date: d.addingTimeInterval(2 * 86_400), kind: .hotHazy, strengths: [0.4, 0.1, 0.5, 0]), into: h)
        #expect(h.count == 2)
        #expect(ProfileSnapshot.record(ProfileSnapshot(date: d, kind: .forming, strengths: []), into: []).isEmpty)
    }
}
