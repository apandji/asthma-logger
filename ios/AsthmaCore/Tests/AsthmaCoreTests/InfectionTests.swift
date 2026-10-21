import Foundation
import Testing
@testable import AsthmaCore

@Suite struct InfectionTests {
    @Test func offForTheMVP() {
        #expect(Infection.isEnabled == false)
        // Counted (v6), so data sets can show it; real moments carry nothing until it's on.
        #expect(Bins.all.contains { $0.bin == Infection.bin })
        #expect(AirProfile.Category.of(bin: Infection.bin) == .infections)
    }

    @Test func providerWordsBecomeLevels() {
        #expect(Infection.level(fromRisk: "Low") == .low)
        #expect(Infection.level(fromRisk: "Very High") == .high)
        #expect(Infection.level(fromRisk: "moderate ") == .moderate)
        #expect(Infection.level(fromRisk: nil) == .unknown)
        #expect(Infection.level(fromRisk: "spicy") == .unknown)
    }

    @Test func unstampedIsMissingNotLow() {
        let def = Bins.all.first { $0.bin == Infection.bin }!
        var f = FeatureFrame(id: "a", kind: .attack, hourOfDay: 9, season: .winter)
        #expect(def.levelOf(f) == nil)
        #expect(def.population([f]).isEmpty)
        f.infection = .unknown
        #expect(def.population([f]).isEmpty)
        f.infection = .high
        #expect(def.levelOf(f) == "high")
        #expect(def.population([f]).count == 1)
    }

    @Test func oldFramesDecodeWithoutIt() throws {
        let f = FeatureFrame(id: "a", kind: .baseline, hourOfDay: 9, season: .fall)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(f)) as! [String: Any]
        json.removeValue(forKey: "infection")
        let back = try JSONDecoder().decode(FeatureFrame.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(back.infection == nil)

        var g = f; g.infection = .moderate
        #expect(try JSONDecoder().decode(FeatureFrame.self, from: JSONEncoder().encode(g)).infection == .moderate)
    }

    @Test func theMVPSourceFindsNothing() async {
        #expect(await NoInfectionSource().reading(latitude: 38.6, longitude: -90.3, on: .now) == nil)
    }
}
