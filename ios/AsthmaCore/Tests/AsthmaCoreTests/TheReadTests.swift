import Testing
@testable import AsthmaCore

@Suite struct TheReadTests {
    let weed = LiftRow(bin: "pollen_weed", level: "high", attacksWith: 9, baselinesWith: 6, nAttacks: 14, nBaselines: 40,
                       attackRate: 9.0 / 14, baselineRate: 6.0 / 40, lift: 4.3, gated: true)

    @Test func nowLearnedLeadsWithCounts() {
        let s = TheRead.sentence(time: .now, learned: true, event: nil, fallF: nil, shared: [weed], notable: [])
        #expect(s == "High weed pollen is here. \u{E000}")
        #expect(TheRead.spoken(s) == "High weed pollen is here. It often shows up on your flare days.")
        #expect(s.allSatisfy { !$0.isNumber })
    }

    @Test func eventLeadsWithoutTheTemperature() {
        let s = TheRead.sentence(time: .now, learned: false, event: .tempDrop, fallF: 16, shared: [], notable: ["ozone is high"])
        #expect(s == "The temperature has fallen 16° in three hours.")
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
        lines = lines.map(TheRead.spoken)
        for l in lines { for w in AirAdvice.bannedWords { #expect(!l.lowercased().contains(w), "“\(l)”") } }
        #expect(lines.allSatisfy { !$0.contains("%") && !$0.contains(";") })
    }
}

@Suite struct MarkTests {
    @Test func pluralsAndTenses() {
        #expect(TheRead.marked("Raised fine particles", time: .back, mark: .sometimes) == "Raised fine particles were there. \u{E001}")
        #expect(TheRead.marked("Humid air", time: .now, mark: .often) == "Humid air is here. \u{E000}")
        #expect(TheRead.spoken(TheRead.marked("Heat", time: .ahead("Friday"), mark: .sometimes))
                == "Heat is in the forecast. It sometimes shows up on your flare days.")
    }
}

@Suite struct NoReadingTests {
    @Test func neverImpliesCleanAir() {
        for t: TheRead.Time in [.now, .back, .ahead("Friday morning")] {
            let s = TheRead.noReading(t)
            #expect(!s.lowercased().contains("stand"))
            #expect(!s.lowercased().contains("clear"))
        }
        #expect(TheRead.noReading(.back, reason: "Logged on Apple Watch while your iPhone was away, so there's no air reading.")
                .hasPrefix("Logged on Apple Watch"))
        #expect(TheRead.noReading(.now, checking: true) == "Checking the air near you…")
    }

    @Test func notesLeadWithTheirWords() {
        #expect(TheRead.note("Tight chest after the bus") == "You noted: “Tight chest after the bus”")
        #expect(TheRead.note(nil) == "A note, nothing said.")
        #expect(TheRead.note(nil, tags: [.coldAir, .pets]) == "A note: cold air, pets.")
        #expect(TheRead.note(String(repeating: "a", count: 120)).hasSuffix("…”"))
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
        #expect(TheRead.personal([r]) == ["You tend to use your inhaler in the evening."])
    }

    @Test func theReadLeavesWhenAndWhereToInsights() {
        let r = LiftRow(bin: "hour", level: "evening", attacksWith: 4, baselinesWith: 2, nAttacks: 10, nBaselines: 30,
                        attackRate: 0.4, baselineRate: 0.07, lift: 6, gated: true)
        let frame = FrameBuilder.frame(id: "x", kind: .baseline, hourOfDay: 20, month: 10, conditions: ConditionsInput())
        #expect(TheRead.shared(frame, rows: [r]).isEmpty)
    }
}
