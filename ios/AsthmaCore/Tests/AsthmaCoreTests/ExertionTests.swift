import Foundation
import Testing
@testable import AsthmaCore

@Suite struct ExertionTests {
    @Test func activeFromAnySource() {
        #expect(Exertion.active(workout: true, vigorousMinutes: nil, steps: nil) == true)
        #expect(Exertion.active(workout: nil, vigorousMinutes: 8, steps: nil) == true)
        #expect(Exertion.active(workout: false, vigorousMinutes: 0, steps: 2400) == true)
        #expect(Exertion.active(workout: false, vigorousMinutes: 1, steps: 300) == false)
    }

    @Test func noDataIsMissingNotNo() {
        #expect(Exertion.active(workout: nil, vigorousMinutes: nil, steps: nil) == nil)
    }

    @Test func theBinCountsOnlyFramesThatKnow() {
        let def = Bins.all.first { $0.bin == "exertion" }!
        var f = FeatureFrame(id: "a", kind: .attack, hourOfDay: 9, season: .fall)
        #expect(def.levelOf(f) == nil)
        f.exerted = true
        #expect(def.levelOf(f) == "yes")
        #expect(AirProfile.Category.of(bin: "exertion") == .exertion)
        #expect(TheRead.fact("exertion", "yes", time: .back) == "You'd been active.")
    }
}

@Suite struct ExertionSourceTests {
    @Test func aWorkoutWinsAndKeepsItsKind() {
        let d = Exertion.decide(.init(workout: true, workoutKind: .walk, runningMinutes: 10, steps: 3000))
        #expect(d == .init(active: true, source: .workout(.walk)))
        #expect(Exertion.decide(.init(workout: true)).source == .workout(.other))
    }

    @Test func motionThenSteps() {
        #expect(Exertion.decide(.init(workout: false, runningMinutes: 6, cyclingMinutes: 0, steps: 3000)).source == .running)
        #expect(Exertion.decide(.init(runningMinutes: 2, cyclingMinutes: 4)).source == .cycling)
        #expect(Exertion.decide(.init(workout: false, runningMinutes: 1, cyclingMinutes: 0, steps: 2400)).source == .steps)
    }

    @Test func notActiveOrUnknownHasNoSource() {
        #expect(Exertion.decide(.init(workout: false, runningMinutes: 1, cyclingMinutes: 0, steps: 300)) == .init(active: false, source: nil))
        #expect(Exertion.decide(.init()) == .init(active: nil, source: nil))
    }

    @Test func decideAgreesWithActive() {
        let cases: [Exertion.Reading] = [
            .init(), .init(workout: true), .init(workout: false, steps: 1999), .init(steps: 2000),
            .init(runningMinutes: 2.5, cyclingMinutes: 2.5), .init(runningMinutes: 4.9), .init(workout: false),
        ]
        for r in cases {
            #expect(Exertion.decide(r).active == Exertion.active(workout: r.workout, vigorousMinutes: r.vigorousMinutes, steps: r.steps))
        }
    }

    @Test func rawValuesRoundTrip() {
        let all: [ExertionSource] = ExertionSource.WorkoutKind.allCases.map { .workout($0) } + [.running, .cycling, .steps]
        for s in all { #expect(ExertionSource(rawValue: s.rawValue) == s) }
        #expect(ExertionSource(rawValue: "workout.somethingNew") == .workout(.other))
        #expect(ExertionSource(rawValue: "nonsense") == nil)
    }

    @Test func wordsNeverCarryNumbers() {
        #expect(Exertion.line(active: true) == "You'd been active in the hour before.")
        #expect(Exertion.line(active: false) == nil)
        #expect(Exertion.line(active: nil) == nil)
        #expect(Exertion.detail(.workout(.walk)) == "A walk, from Apple Health.")
        #expect(Exertion.detail(.running) == "A run, from your iPhone's motion.")
        #expect(Exertion.detail(.steps) == "A lot of steps, from Apple Health.")
        #expect(Exertion.detail(nil) == nil)
        let all: [ExertionSource] = ExertionSource.WorkoutKind.allCases.map { .workout($0) } + [.running, .cycling, .steps]
        for s in all { #expect(Exertion.detail(s)!.allSatisfy { !$0.isNumber }) }
    }

    @Test func motionKeepsAWeek() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        #expect(Exertion.motionCanSay(at: now.addingTimeInterval(-6 * 86_400), now: now))
        #expect(!Exertion.motionCanSay(at: now.addingTimeInterval(-8 * 86_400), now: now))
    }
}
