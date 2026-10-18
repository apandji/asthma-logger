import Testing
@testable import AsthmaCore

@Suite struct SymptomTagTests {
    @Test func symptomsAreHeardAsTheyAreSaid() {
        #expect(KeywordTagger.scan("I was wheezing and coughing").tags == [.wheezing, .coughing])
        #expect(KeywordTagger.scan("my chest felt tight").tags == [.chestTightness])
        #expect(KeywordTagger.scan("I couldn't breathe on the stairs").tags == [.exercise, .shortOfBreath])
        #expect(KeywordTagger.scan("it woke me up at 3").tags == [.wokeAtNight])
        #expect(KeywordTagger.scan("I had to stop running").tags == [.exercise, .activityLimited])
        #expect(KeywordTagger.scan("I took two puffs and felt better").tags == [.secondPuff, .betterAfter])
    }

    @Test func negationStillWorks() {
        // "couldn't" opens a phrase here, but still negates what follows when nothing matches it.
        #expect(KeywordTagger.scan("no wheezing, no cough").tags.isEmpty)
        #expect(KeywordTagger.scan("it didn't wake me up").tags.isEmpty)
        #expect(KeywordTagger.scan("couldn't find the cat").tags.isEmpty)
    }

    @Test func symptomsAndOutcomesNeverBecomeBins() {
        let bins = Set(Bins.all.map(\.bin))
        for t in JournalTag.allCases {
            #expect(bins.contains("tag_\(t.rawValue)") == (t.kind == .trigger), "\(t)")
        }
        #expect(JournalTag.triggers.count + JournalTag.symptoms.count + JournalTag.outcomes.count == JournalTag.allCases.count)
    }
}

@Suite struct InterviewTests {
    let rescue = Interview.Context(hour: 15, puffs: 1, isRescue: true)

    @Test func followUpsGoInTheProvidersOrder() {
        var c = rescue
        c.asked = [.doing]
        #expect(Interview.next(c) == .symptoms)
        c.asked += [.symptoms]
        #expect(Interview.next(c) == .activity)
        c.asked += [.activity]
        // Afternoon: no night question. Then how the reliever worked.
        #expect(Interview.next(c) == .reliever)
    }

    @Test func answersSkipWhatTheyCovered() {
        var c = rescue
        c.asked = [.doing]
        c.tags = [.wheezing, .activityLimited]
        #expect(Interview.next(c) == .reliever)
    }

    @Test func nightOnlyAtNight() {
        var c = Interview.Context(hour: 3, puffs: 2, isRescue: true)
        c.asked = [.symptoms, .activity]
        #expect(Interview.next(c) == .night)
        c.hour = 14
        #expect(Interview.next(c) != .night)
    }

    @Test func elevatedAirAsksAboutExposureAfterSymptoms() {
        var c = Interview.Context(hour: 15, puffs: 1, isRescue: true, elevated: [.treePollen])
        c.asked = [.doing, .symptoms]
        #expect(Interview.next(c) == .exposure)
        #expect(Interview.Question.exposure.text(place: nil, time: nil, elevated: .treePollen)
                == "Tree pollen was high around then. Were you outside?")
        // Said already: not asked again.
        c.words = "I was outside walking the dog"
        #expect(Interview.next(c) != .exposure)
        // Nothing elevated: never asked.
        var clean = Interview.Context(hour: 15, puffs: 1, isRescue: true)
        clean.asked = [.doing, .symptoms]
        #expect(Interview.next(clean) == .activity)
    }

    @Test func exposureQuestionsStateAFactNeverACause() {
        for e in Interview.Elevated.allCases {
            let q = e.question.lowercased()
            #expect(q.hasSuffix("?"))
            for banned in ["caused", "triggered", "because", "set off", "attack", "%"] { #expect(!q.contains(banned)) }
        }
    }

    @Test func itEnds() {
        var c = rescue
        c.asked = [.doing, .symptoms, .activity, .reliever]
        #expect(Interview.next(c) == .anythingElse)
        c.asked += [.anythingElse]
        #expect(Interview.next(c) == nil)
    }

    @Test func aNoteNeverAsksAboutSymptomsFirst() {
        let note = Interview.Context(hour: 10, puffs: 0, isRescue: false)
        #expect(Interview.next(note) == .doing)
        #expect(Interview.first(seed: 0, isRescue: false) != .symptoms)
    }

    @Test func yesNo() {
        #expect(Interview.yesNo("Yes, around three") == true)
        #expect(Interview.yesNo("yeah it did") == true)
        #expect(Interview.yesNo("No") == false)
        #expect(Interview.yesNo("didn't really") == false)
        #expect(Interview.yesNo("the cat was there") == nil)
    }

    @Test func questionsArePastTenseAndNeverAskForACount() {
        for q in Interview.Question.allCases {
            let t = q.text.lowercased()
            #expect(!t.contains("how many") && !t.contains("how often") && !t.contains("how have you been"))
        }
    }
}
