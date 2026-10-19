import Testing
@testable import AsthmaCore

@Suite struct PrimingTests {
    @Test func quickBurstsLookLikePriming() {
        #expect(Priming.looksLike(puffs: 4, span: 6))
        #expect(Priming.looksLike(puffs: 3, span: 10))
    }

    @Test func realPuffsDont() {
        #expect(!Priming.looksLike(puffs: 2, span: 3))        // a double press
        #expect(!Priming.looksLike(puffs: 3, span: 90))       // three puffs a minute apart
    }
}
