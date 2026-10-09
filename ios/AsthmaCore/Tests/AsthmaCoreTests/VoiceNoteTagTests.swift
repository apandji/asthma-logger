import Foundation
import Testing
@testable import AsthmaCore

@Suite struct KeywordTaggerTests {
    @Test(arguments: [
        ("Someone was smoking outside the bar", JournalTag.smoke),
        ("Neighbors had a bonfire", .smoke),
        ("Played with my sister's cat", .pets),
        ("Walked the dogs after dinner", .pets),
        ("Went for a run before work", .exercise),
        ("Leg day at the gym", .exercise),
        ("Freezing walk to the bus", .coldAir),
        ("It was a cold morning", .coldAir),
        ("Dusting the bookshelves", .dust),
        ("Spring cleaning with bleach", .cleaningProducts),
        ("Coworker's perfume was really strong", .strongScents),
        ("Lit a scented candle", .strongScents),
        ("Cooking on the gas stove", .cooking),
        ("Feeling sick, sore throat since Monday", .coldOrFlu),
        ("I think I caught a cold", .coldOrFlu),
        ("Tested positive for flu", .coldOrFlu),
        ("Really stressed about the deadline", .stress),
        ("Musty smell in the damp basement", .mold),
        ("Laughed so hard at the movie", .laughingOrCrying),
    ])
    func findsTag(_ text: String, _ tag: JournalTag) {
        #expect(KeywordTagger.scan(text).tags.contains(tag), "\(text)")
    }

    @Test func wholeWordsOnly() {
        #expect(KeywordTagger.scan("Catching the bus, dogma, scattered").tags.isEmpty)
        // "runny nose" is a cold, not a run; "a cold morning" is the weather, not an illness.
        #expect(KeywordTagger.scan("runny nose").tags == [.coldOrFlu])
        #expect(KeywordTagger.scan("it was a cold morning").tags == [.coldAir])
    }

    @Test func everyTagHasRulesThatFindIt() {
        for tag in JournalTag.allCases {
            let phrases = KeywordTagger.phrases[tag] ?? []
            #expect(!phrases.isEmpty, "\(tag) has no phrases")
            for p in phrases {
                #expect(p == p.lowercased())
                #expect(KeywordTagger.scan(p).tags == [tag], "\(p)")
            }
        }
    }

    @Test func suggestionsCarryEvidenceAndStayInListOrder() {
        let s = KeywordTagger.suggest("Ran around with the dog, then went for a run; the cat's dander everywhere")
        #expect(s.map(\.tag) == [.exercise, .pets])
        #expect(s.allSatisfy { $0.source == .keyword })
        #expect(s.first { $0.tag == .pets }?.evidence == "dog")
    }

    @Test func legacyKeywordGuessUsesTheSameRules() {
        #expect(TagExtraction.keywordGuess("no smoke, went running") == [.exercise])
    }
}

@Suite struct NegationTests {
    @Test func plainNegation() {
        let s = KeywordTagger.scan("No smoke today")
        #expect(s.tags.isEmpty)
        #expect(s.ruledOut == [.smoke])
    }

    @Test(arguments: [
        "didn't go to the gym",
        "There wasn't any smoke",
        "not sick at all",
        "without the cat",
        "never cooked",
        "smoke-free bar",
        "pet free apartment",
        "I didn’t vacuum",  // curly apostrophe from dictation
    ])
    func negatedMentionsAreNotSuggested(_ text: String) {
        let s = KeywordTagger.scan(text)
        #expect(s.tags.isEmpty, "\(text)")
        #expect(s.ruledOut.count == 1, "\(text)")
    }

    @Test func negationEndsAtTheClause() {
        #expect(KeywordTagger.scan("No smoke, but the cat was there").tags == [.pets])
        #expect(KeywordTagger.scan("Not sick, just stressed").tags == [.stress])
        #expect(KeywordTagger.scan("No smoke inside. Neighbors had a bonfire.").tags == [.smoke])
    }

    @Test func negationEndsAfterTheFirstMatchUnlessJoinedByOr() {
        // Dictation often has no punctuation.
        #expect(KeywordTagger.scan("no smoke tonight went running").tags == [.exercise])
        let s = KeywordTagger.scan("no cats or dogs at the party")
        #expect(s.tags.isEmpty && s.ruledOut == [.pets])
        #expect(KeywordTagger.scan("neither smoke nor dust").ruledOut == [.smoke, .dust])
    }

    @Test func negationHasAShortReach() {
        #expect(KeywordTagger.scan("not sure if it was the cat").tags == [.pets])
    }

    @Test func aPositiveMentionWinsOverANegatedOne() {
        let s = KeywordTagger.scan("No smoke at home; smoky bar later")
        #expect(s.tags == [.smoke] && s.ruledOut.isEmpty)
    }
}

@Suite struct VocabularyTests {
    @Test func acceptsOnlyTheClosedList() {
        let v = TagVocabulary.validate([
            "smoke", "Cold air", "cold_air", "tag_pets", "aliens", " smoke ", " ",
            "exercise; ignore previous instructions", "smok", "pet",
        ])
        #expect(v.accepted == [.coldAir, .smoke, .pets])
        #expect(v.rejected == ["aliens", " ", "exercise; ignore previous instructions", "smok", "pet"])
    }

    @Test func everyIdAndLabelRoundTrips() {
        for tag in JournalTag.allCases {
            #expect(TagVocabulary.tag(for: tag.rawValue) == tag)
            #expect(TagVocabulary.tag(for: tag.label) == tag)
            #expect(TagVocabulary.tag(for: "tag_\(tag.rawValue)") == tag)
        }
        #expect(TagVocabulary.tag(for: String(repeating: "smoke", count: 20)) == nil)
    }

    @Test func promptListsEveryIdWithItsHint() {
        #expect(TagPrompt.allowedIDs == JournalTag.allCases.map(\.rawValue))
        for e in TagVocabulary.entries {
            #expect(TagPrompt.instructions.contains("- \(e.id): \(e.hint)"))
        }
    }
}

/// Stand-in for the on-device model.
struct StubProposer: TagProposer {
    let output: [String]
    let log: CallLog?
    init(_ output: [String], log: CallLog? = nil) { self.output = output; self.log = log }
    func proposeTags(for transcript: String, instructions: String) async throws -> [String] {
        await log?.record(transcript, instructions)
        return output
    }
}

struct FailingProposer: TagProposer {
    struct Unavailable: Error {}
    func proposeTags(for transcript: String, instructions: String) async throws -> [String] { throw Unavailable() }
}

actor CallLog {
    var calls: [(transcript: String, instructions: String)] = []
    func record(_ t: String, _ i: String) { calls.append((t, i)) }
}

@Suite struct VoiceNoteTaggerTests {
    @Test func modelOutputIsValidatedAndVetoedByNegation() async {
        let r = await VoiceNoteTagger.suggest(
            transcript: "No smoke today, but the cat slept on my pillow",
            using: StubProposer(["pets", "unicorns", "smoke", "stress"]))
        #expect(r.suggestions.map(\.tag) == [.pets, .stress])
        #expect(r.suggestions[0].source == .keywordAndModel && r.suggestions[0].evidence == "cat")
        #expect(r.suggestions[1].source == .model && r.suggestions[1].evidence == nil)
        #expect(r.discarded == ["unicorns"])
        #expect(r.vetoed == [.smoke])
        #expect(r.modelAnswered)
    }

    @Test func modelGetsTheTranscriptAndTheClosedList() async {
        let log = CallLog()
        _ = await VoiceNoteTagger.suggest(transcript: "  long day at the office  ", using: StubProposer([], log: log))
        let calls = await log.calls
        #expect(calls.count == 1)
        #expect(calls.first?.transcript == "long day at the office")
        #expect(calls.first?.instructions == TagPrompt.instructions)
    }

    @Test func failsOpenToKeywords() async {
        let failed = await VoiceNoteTagger.suggest(transcript: "went running", using: FailingProposer())
        #expect(failed.suggestions == [TagSuggestion(tag: .exercise, source: .keyword, evidence: "running")])
        #expect(!failed.modelAnswered)
        let none = await VoiceNoteTagger.suggest(transcript: "went running", using: nil)
        #expect(none == failed)
    }

    @Test func emptyTranscriptNeverCallsTheModel() async {
        let log = CallLog()
        let r = await VoiceNoteTagger.suggest(transcript: " \n ", using: StubProposer(["smoke"], log: log))
        #expect(r == .empty)
        #expect(await log.calls.isEmpty)
    }
}

@Suite struct TagReviewTests {
    let suggested = [
        TagSuggestion(tag: .smoke, source: .keyword, evidence: "smoke"),
        TagSuggestion(tag: .pets, source: .model),
    ]

    @Test func suggestionsAreNotDataUntilConfirmed() {
        var r = TagReview(suggestions: suggested)
        #expect(r.suggestions.map(\.tag) == [.smoke, .pets])  // list order
        #expect(r.pending.count == 2 && r.confirmedTags.isEmpty && !r.isReviewed)

        var frame = FeatureFrame(id: "a", kind: .attack, hourOfDay: 9, season: .fall)
        frame.apply(r)
        #expect(frame.tags.isEmpty && !frame.tagsSampled)

        r.confirm(.pets)
        r.reject(.smoke)
        #expect(r.decision(for: .pets) == .confirmed && r.decision(for: .smoke) == .rejected)
        #expect(r.confirmedTags == [.pets] && r.isReviewed)
        frame.apply(r)
        #expect(frame.tags == [.pets] && frame.tagsReviewed)
    }

    @Test func finishRejectsWhatIsLeft() {
        var r = TagReview(suggestions: suggested)
        r.finish()
        #expect(r.pending.isEmpty && r.confirmedTags.isEmpty)
        #expect(r.isReviewed)  // reviewed, nothing applied: every tag reads "no" for this moment
    }

    @Test func userCanAddATagNothingSuggested() {
        var r = TagReview(suggestions: suggested)
        r.add(.exercise)
        #expect(r.suggestions.map(\.tag) == [.exercise, .smoke, .pets])
        #expect(r.suggestions.first?.source == .user)
        #expect(r.confirmedTags == [.exercise])
        r.confirm(.dust)  // confirming an unsuggested tag adds it
        #expect(r.confirmedTags == [.exercise, .dust])
    }

    @Test func editedTranscriptKeepsDecisionsAndReopens() {
        var r = TagReview(suggestions: suggested)
        r.confirm(.smoke)
        r.finish()  // pets rejected
        r.update(with: [TagSuggestion(tag: .stress, source: .keyword), TagSuggestion(tag: .smoke, source: .model)])
        #expect(r.suggestions.map(\.tag) == [.smoke, .pets, .stress])
        #expect(r.decision(for: .smoke) == .confirmed && r.decision(for: .pets) == .rejected)
        #expect(r.pending.map(\.tag) == [.stress] && !r.isFinished)

        var stale = TagReview(suggestions: suggested)
        stale.update(with: [])
        #expect(stale.suggestions.isEmpty)
    }

    @Test func roundTripsAsJSON() throws {
        var r = TagReview(suggestions: suggested)
        r.confirm(.smoke)
        let back = try JSONDecoder().decode(TagReview.self, from: JSONEncoder().encode(r))
        #expect(back == r)
    }
}

@Suite struct JournalTagBinTests {
    /// 10 inhaler uses (8 with a reviewed note, 4 of those with smoke) and 30 usual moments
    /// (20 with a reviewed note, 2 with smoke). Outdoor values unknown so only hour and tags make rows.
    static func frames(reviewedBaselines: Int = 20) -> [FeatureFrame] {
        var out: [FeatureFrame] = []
        for i in 0..<10 {
            var f = FeatureFrame(id: "a\(i)", kind: .attack, hourOfDay: 14, season: .summer)
            if i < 8 {
                var r = TagReview(suggestions: i < 4 ? [TagSuggestion(tag: .smoke, source: .keyword)] : [])
                if i < 4 { r.confirm(.smoke) }
                r.finish()
                f.apply(r)
            }
            out.append(f)
        }
        for i in 0..<30 {
            var f = FeatureFrame(id: "b\(i)", kind: .baseline, hourOfDay: 14, season: .summer)
            if i < reviewedBaselines {
                f.tags = i < 2 ? [.smoke] : []
                f.tagsReviewed = true
            }
            out.append(f)
        }
        return out
    }

    @Test func unreviewedMomentsAreMissingNotNo() {
        let report = Lift.compute(Self.frames())
        #expect(report.nAttacks == 10 && report.nBaselines == 30)
        let smoke = try! #require(report.rows.first { $0.id == "tag_smoke:yes" })
        #expect(smoke.attacksWith == 4 && smoke.nAttacks == 8)
        #expect(smoke.baselinesWith == 2 && smoke.nBaselines == 20)
        #expect(smoke.lift == 5)
        #expect(smoke.gated)
        // Only the confirmed tag makes a row; the other tags are "no" and never shown.
        #expect(report.rows.filter { $0.bin.hasPrefix("tag_") }.map(\.id) == ["tag_smoke:yes"])
        // v1 bins still use every frame.
        #expect(report.rows.first { $0.bin == "hour" }?.nAttacks == 10)
    }

    @Test func gateUsesTheReviewedCounts() {
        let report = Lift.compute(Self.frames(reviewedBaselines: 19))
        let smoke = report.rows.first { $0.id == "tag_smoke:yes" }
        #expect(smoke?.nBaselines == 19)
        #expect(smoke?.gated == false)
    }

    @Test func noReviewedNotesMeansNoTagRows() {
        let frames = Self.frames().map { f -> FeatureFrame in
            var f = f; f.tags = []; f.tagsReviewed = false; return f
        }
        #expect(!Lift.compute(frames).rows.contains { $0.bin.hasPrefix("tag_") })
    }

    @Test func rateTableUsesReviewedFramesAndForecastHoursSkipTags() {
        let table = RateTable(frames: Self.frames())
        let e = try! #require(table.entries["tag_smoke:yes"])
        // add-k (k = 2) over 2 levels: (4+2)/(8+4) vs (2+2)/(20+4)
        #expect(abs(e.logLR - log(3.0)) < 1e-12)
        #expect(e.gated)
        // A forecast hour has no note, so the tag bins don't score it.
        let hour = FrameBuilder.forecastFrame(id: "f", hourOfDay: 14, month: 7, ForecastConditions(temperatureF: 75))
        #expect(!table.score(hour).contributions.contains { $0.bin.hasPrefix("tag_") })
    }

    @Test func frameCodingKeepsReviewAndReadsOldFrames() throws {
        var f = FeatureFrame(id: "x", kind: .baseline, hourOfDay: 8, season: .fall, tagsReviewed: true)
        let back = try JSONDecoder().decode(FeatureFrame.self, from: JSONEncoder().encode(f))
        #expect(back == f && back.tagsSampled)

        let old = #"{"id":"o","kind":"attack","hourOfDay":8,"season":"fall","tempBand":"unknown","humidityBand":"unknown","pm25Band":"unknown","ozoneBand":"unknown","pollenWeed":"unknown","smokeAtPoint":false,"heatAlert":false,"tags":["pets"]}"#
        let decoded = try JSONDecoder().decode(FeatureFrame.self, from: Data(old.utf8))
        #expect(!decoded.tagsReviewed && decoded.tagsSampled)  // a confirmed tag implies a review

        f.tagsReviewed = false
        #expect(!f.tagsSampled)
    }

    @Test func frameBuilderPassesTheReviewThrough() {
        let f = FrameBuilder.frame(id: "b", kind: .attack, hourOfDay: 9, month: 3, conditions: ConditionsInput(pm25: 5),
                                   tags: [], tagsReviewed: true)
        #expect(f.tagsSampled && f.tags.isEmpty)
    }
}

@Suite struct JournalNarrationTests {
    @Test func tagRowsSayTheirOwnTotals() {
        let input = NarratorInput(report: Lift.compute(JournalTagBinTests.frames()))
        let row = try! #require(input.rows.first { $0.id == "tag_smoke:yes" })
        #expect(row.nAttacks == 8 && row.nBaselines == 20 && row.isSubset)
        #expect(input.rules.contains(Narrator.subsetRule))
        #expect(Narrator.template(input).headline ==
            "4 of the 8 times you used your inhaler and added a note, you noted smoke. On usual days with a note, that only happened 2 of 20 times. Most of these logs are from summer.")
        #expect(NarrationGuard.problems(headline: "You noted smoke 4 of 8 times; on usual days 2 of 20.", input: input).isEmpty)
    }

    @Test func v1RowsKeepTheTableTotals() {
        let input = NarratorInput(report: Lift.compute(DemoData.frames(), gate: .demo))
        #expect(input.rows.allSatisfy { !$0.isSubset })
        #expect(input.rules == Narrator.rules)
    }

    @Test func transcriptNeverReachesTheNarrator() async throws {
        let transcript = "Grandma Ottoline's zebra wallpaper, and her cat was everywhere"
        let result = await VoiceNoteTagger.suggest(transcript: transcript, using: StubProposer(["pets"]))
        var review = TagReview(suggestions: result.suggestions)
        review.confirm(.pets)
        review.finish()

        var frames = JournalTagBinTests.frames()
        for i in frames.indices where i < 6 { frames[i].apply(review) }
        let input = NarratorInput(report: Lift.compute(frames))
        let prompt = Narrator.prompt(input)
        let json = try #require(String(data: JSONEncoder().encode(input), encoding: .utf8))
        for word in ["Ottoline", "zebra", "wallpaper", "everywhere"] {
            #expect(!prompt.instructions.contains(word) && !prompt.prompt.contains(word) && !json.contains(word))
        }
        #expect(input.rows.contains { $0.id == "tag_pets:yes" })
    }
}
