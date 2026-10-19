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
