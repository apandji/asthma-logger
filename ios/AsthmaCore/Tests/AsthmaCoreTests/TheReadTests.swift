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

@Suite struct WildfireTests {
    @Test func demoFiresReadLikeTheBoard() throws {
        let lat = 38.6, lon = -90.25
        let w = try #require(WildfiresNearby(fires: DemoAmbee().fires(latitude: lat, longitude: lon), latitude: lat, longitude: lon))
        #expect(w.count == 2)
        #expect(w.direction == "north")
        #expect(w.sentence == "There are two active wildfires 50 miles north.")
        #expect(TheRead.eventFact(.smoke, time: .now, fallF: nil, fires: w)
                == "There are two active wildfires 50 miles north. Heavy smoke is drifting into your area.")
    }

    @Test func farFiresDontCount() {
        let far = [Ambee.FireResponse.Fire(lat: 45, lng: -100)]
        #expect(WildfiresNearby(fires: far, latitude: 38.6, longitude: -90.25) == nil)
    }

    @Test func timeOfDayReadsAsMoments() {
        let r = LiftRow(bin: "hour", level: "evening", attacksWith: 4, baselinesWith: 2, nAttacks: 10, nBaselines: 30,
                        attackRate: 0.4, baselineRate: 0.07, lift: 6, gated: true)
        #expect(TheRead.personal([r]) == ["You used your inhaler most in the evening: 4 of your 10 rescue moments."])
    }

    @Test func theReadLeavesWhenAndWhereToInsights() {
        let r = LiftRow(bin: "hour", level: "evening", attacksWith: 4, baselinesWith: 2, nAttacks: 10, nBaselines: 30,
                        attackRate: 0.4, baselineRate: 0.07, lift: 6, gated: true)
        let frame = FrameBuilder.frame(id: "x", kind: .baseline, hourOfDay: 20, month: 10, conditions: ConditionsInput())
        #expect(TheRead.shared(frame, rows: [r]).isEmpty)
    }
}
