import Foundation
import Testing
@testable import AsthmaCore

@Suite struct RelieverUseTests {
    let now = Date(timeIntervalSince1970: 1_760_000_000)
    func h(_ x: Double) -> Date { now.addingTimeInterval(-x * 3600) }

    @Test func againWithinFourHours() {
        #expect(RelieverUse.check(rescues: [h(3), h(0.5)], now: now) == .againWithin4Hours)
        // Five hours apart: not "again within 4 hours".
        #expect(RelieverUse.check(rescues: [h(6), h(0.5)], now: now) == nil)
        // The pair was yesterday: it's no longer now.
        #expect(RelieverUse.check(rescues: [h(30), h(28)], now: now) == nil)
    }

    @Test func moreThanTwoDaysAWeek() {
        #expect(RelieverUse.check(rescues: [h(24 * 5), h(24 * 3), h(24 * 1)], now: now) == .moreThanTwoDaysThisWeek)
        #expect(RelieverUse.check(rescues: [h(24 * 5), h(24 * 1)], now: now) == nil)
        // Ten days ago doesn't count.
        #expect(RelieverUse.check(rescues: [h(24 * 10), h(24 * 3), h(24 * 1)], now: now) == nil)
    }

    @Test func wordsFollowTheRules() {
        for c in [RelieverUse.Check.againWithin4Hours, .moreThanTwoDaysThisWeek] {
            let s = (c.title + " " + c.body).lowercased()
            for banned in ["attack", "%", "will have", "caused"] { #expect(!s.contains(banned)) }
            #expect(!c.source.isEmpty)
        }
    }
}
