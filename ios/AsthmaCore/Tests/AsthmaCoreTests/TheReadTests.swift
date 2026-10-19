import Testing
@testable import AsthmaCore

@Suite struct TheReadTests {
    let weed = LiftRow(bin: "pollen_weed", level: "high", attacksWith: 9, baselinesWith: 6, nAttacks: 14, nBaselines: 40,
                       attackRate: 9.0 / 14, baselineRate: 6.0 / 40, lift: 4.3, gated: true)

    @Test func nowLearnedLeadsWithCounts() {
        let s = TheRead.sentence(time: .now, learned: true, event: nil, fallF: nil, shared: [weed], notable: [])
        #expect(s == "Weed pollen is high.\u{00A0}\u{E000}")
        #expect(TheRead.spoken(s) == "Weed pollen is high. It often shows up on your flare days.")
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
        #expect(TheRead.spoken(s) == "Thursday afternoon: weed pollen looks high. It often shows up on your flare days.")
        // Never the verdict: that's the pill's job, so the two can't contradict.
        #expect(TheRead.sentence(time: .ahead("Thursday afternoon"), learned: true, event: nil, fallF: nil, shared: [],
                                 notable: []) == "Thursday afternoon: nothing in the forecast stands out.")
        #expect(TheRead.sentence(time: .ahead("Monday morning"), learned: true, event: nil, fallF: nil, shared: [],
                                 notable: ["weed pollen is high"]) == "Monday morning: weed pollen is high.")
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
    @Test func factorReadBack() {
        #expect(TheRead.factor(in: TheRead.marked(bin: "pollen_weed", level: "high", time: .back, mark: .often)) == "High weed pollen")
        #expect(TheRead.factor(in: "It's humid.\u{00A0}\u{E000}") == "Humid air")
        #expect(TheRead.factor(in: "The temperature had fallen 19° in three hours.\u{00A0}\u{E001} The day before was wet.") == "A sharp temperature drop")
        #expect(TheRead.factor(in: "Thursday afternoon: weed pollen looks high.\u{00A0}\u{E000}") == "High weed pollen")
        #expect(TheRead.factor(in: "It was hot.\u{00A0}\u{E000}") == "Heat")
        #expect(TheRead.factor(in: "Nothing here.") == nil)
    }

    /// The copy pass (Oct 18): each factor reads as a plain sentence, never "<Thing> was there."
    @Test func readsLikeASentence() {
        #expect(TheRead.fact("temp", "hot", time: .back) == "It was hot.")
        #expect(TheRead.fact("ozone", "high", time: .back) == "Ozone was high.")
        #expect(TheRead.fact("pm25", "moderate", time: .back) == "Fine particles were up a little.")
        #expect(TheRead.fact("humidity", "humid", time: .now) == "It's humid.")
        #expect(TheRead.fact("temp_drop", "yes", time: .back) == "The temperature had dropped fast.")
        #expect(TheRead.fact("pollen_weed", "high", time: .ahead("Friday")) == "weed pollen looks high.")
        for (b, l) in [("pm25", "high"), ("ozone", "moderate"), ("temp", "cold"), ("smoke_at_point", "yes"), ("tag_pets", "yes")] {
            for t: TheRead.Time in [.back, .now, .ahead("Friday")] {
                let f = TheRead.fact(b, l, time: t)
                #expect(!f.contains(" there.") && !f.contains(" here.") && !f.contains("will"), "“\(f)”")
            }
        }
    }
}

@Suite struct JoinedReadTests {
    let hot = LiftRow(bin: "temp", level: "hot", attacksWith: 9, baselinesWith: 6, nAttacks: 14, nBaselines: 40,
                      attackRate: 9.0 / 14, baselineRate: 6.0 / 40, lift: 4.3, gated: true)

    /// Owner, Oct 18: two facts in one sentence, each underlined only if it's yours.
    @Test func aPatternAndAPlainFact() {
        let s = TheRead.joined(TheRead.clauses([hot], notable: ["ozone was high"], time: .back))
        #expect(s == "It was hot\u{00A0}\u{E000} and ozone was high.")
        #expect(TheRead.factors(in: s).map(\.factor) == ["Heat"])
        #expect(TheRead.spoken(s) == "It was hot (often on your flare days) and ozone was high.")
    }

    @Test func twoPatternsEachMarked() {
        let ozone = LiftRow(bin: "ozone", level: "high", attacksWith: 5, baselinesWith: 6, nAttacks: 14, nBaselines: 40,
                            attackRate: 5.0 / 14, baselineRate: 6.0 / 40, lift: 2.4, gated: true)
        let s = TheRead.joined(TheRead.clauses([hot, ozone], notable: [], time: .back))
        #expect(TheRead.factors(in: s).map(\.factor) == ["Heat", "High ozone"])
        #expect(s.hasPrefix("It was hot\u{00A0}"))
        #expect(s.contains(" and ozone was high."))
    }

    @Test func everythingHighNamesTwoThenToo() {
        let all = TheRead.allClauses([hot], notable: ["ozone was high", "fine particles were high", "tree pollen was high"], time: .back)
        #expect(TheRead.joined(Array(all.prefix(2))) == "It was hot\u{00A0}\u{E000} and ozone was high.")
        #expect(TheRead.tooLine(all, time: .back) == "Fine particles and tree pollen were high too.")
    }

    @Test func anEventLeadsAndOnlyOneJoinsIt() {
        let s = TheRead.sentence(time: .now, learned: true, event: .smoke, fallF: nil, shared: [hot], notable: ["ozone is high"])
        #expect(s.hasPrefix("Heavy smoke is drifting into your area."))
        #expect(s.contains("It's hot") && s.hasSuffix("Ozone is high too."))
    }

    @Test func oneSubjectOnce() {
        // A notable reading about the same thing as a pattern isn't said twice.
        let weed = LiftRow(bin: "pollen_weed", level: "high", attacksWith: 9, baselinesWith: 6, nAttacks: 14, nBaselines: 40,
                           attackRate: 9.0 / 14, baselineRate: 6.0 / 40, lift: 4.3, gated: true)
        let cs = TheRead.clauses([weed], notable: ["weed pollen is high", "ozone is high"], time: .now)
        #expect(cs.count == 2 && cs[1].text == "Ozone is high." && cs[1].mark == nil)
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
        #expect(TheRead.note(nil) == "A note.")
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
