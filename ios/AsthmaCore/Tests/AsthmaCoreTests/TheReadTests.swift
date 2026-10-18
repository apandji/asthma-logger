import Testing
@testable import AsthmaCore

@Suite struct TheReadTests {
    let weed = LiftRow(bin: "pollen_weed", level: "high", attacksWith: 9, baselinesWith: 6, nAttacks: 14, nBaselines: 40,
                       attackRate: 9.0 / 14, baselineRate: 6.0 / 40, lift: 4.3, gated: true)

    @Test func nowLearnedLeadsWithCounts() {
        let s = TheRead.sentence(time: .now, learned: true, event: nil, fallF: nil, shared: [weed], notable: [])
        #expect(s == "High weed pollen came up at 9 of your 14 rescue moments.")
    }

    @Test func eventLeadsWithoutTheTemperature() {
        let s = TheRead.sentence(time: .now, learned: false, event: .tempDrop, fallF: 16, shared: [], notable: ["ozone is high"])
        #expect(s == "A sharp cold drop: 16° in three hours.")
        #expect(!s.contains("It's"))
    }

    @Test func learningWithNothingHigh() {
        #expect(TheRead.sentence(time: .now, learned: false, event: nil, fallF: nil, shared: [], notable: [])
                == "Nothing in the air stands out right now.")
        #expect(TheRead.sentence(time: .now, learned: false, event: nil, fallF: nil, shared: [], notable: ["weed pollen is high"])
                == "Weed pollen is high.")
    }

    @Test func aheadNamesTheTimeAndFactor() {
        let s = TheRead.sentence(time: .ahead("Thursday afternoon"), learned: true, event: nil, fallF: nil, shared: [weed],
                                 notable: [], looksLikeFlare: true)
        #expect(s == "Thursday afternoon looks more like your flare days: high weed pollen.")
        #expect(TheRead.sentence(time: .ahead("Thursday afternoon"), learned: true, event: nil, fallF: nil, shared: [],
                                 notable: []) == "Thursday afternoon looks like your baseline days.")
    }

    @Test func neverCausalOrOdds() {
        var lines = [TheRead.standard, TheRead.justLogged("Rescue")]
        for e in AirAdvice.Event.allCases {
            for t: TheRead.Time in [.now, .back, .ahead("Friday morning")] {
                lines.append(TheRead.sentence(time: t, learned: true, event: e, fallF: 12, shared: [weed], notable: [], looksLikeFlare: true))
            }
        }
        for l in lines { for w in AirAdvice.bannedWords { #expect(!l.lowercased().contains(w), "“\(l)”") } }
        #expect(lines.allSatisfy { !$0.contains("%") && !$0.contains(";") })
    }
}
