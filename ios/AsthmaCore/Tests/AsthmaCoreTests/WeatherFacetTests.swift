import Foundation
import Testing
@testable import AsthmaCore

@Suite struct WeatherFacetTests {
    func amounts(_ f: Double?, _ h: Double?, _ d: Double? = nil) -> [WeatherFacet: Double] {
        Dictionary(uniqueKeysWithValues: WeatherFacet.allCases.map { ($0, $0.amount(temperatureF: f, humidityPct: h, tempFallF: d)) })
    }

    @Test func mildDayIsNothing() {
        let a = amounts(65, 50, 0)
        #expect(a.values.allSatisfy { $0 == 0 })
        #expect(WeatherFacet.coldDry.word(temperatureF: 65, humidityPct: 50, tempFallF: 0) == "Not cold or dry")
        #expect(WeatherFacet.change.word(temperatureF: 65, humidityPct: 50, tempFallF: 0) == "Steady")
    }

    @Test func coldIsFullAtFreezing() {
        #expect(amounts(32, 50)[.coldDry] == 1)
        #expect(amounts(32, 50)[.heatHumid] == 0)
        #expect(WeatherFacet.coldDry.word(temperatureF: 32, humidityPct: 20, tempFallF: nil) == "Cold and dry")
    }

    @Test func dryAloneCounts() {
        #expect(amounts(70, 15)[.coldDry] == 1)
        #expect(WeatherFacet.coldDry.word(temperatureF: 70, humidityPct: 20, tempFallF: nil) == "Dry")
    }

    @Test func muggyNeedsWarmth() {
        // Cold damp air isn't heat and humidity.
        #expect(amounts(45, 95)[.heatHumid] == 0)
        #expect(amounts(80, 95)[.heatHumid] == 1)
        #expect(WeatherFacet.heatHumid.word(temperatureF: 70, humidityPct: 85, tempFallF: nil) == "Humid")
        #expect(WeatherFacet.heatHumid.word(temperatureF: 92, humidityPct: 85, tempFallF: nil) == "Hot and humid")
    }

    @Test func changeFollowsTheSharpDropEdge() {
        #expect(amounts(50, 50, 10)[.change] == 1)
        #expect(amounts(50, 50, 2)[.change] == 0)
        #expect(WeatherFacet.change.word(temperatureF: nil, humidityPct: nil, tempFallF: 12) == "A sharp drop")
        #expect(WeatherFacet.change.word(temperatureF: nil, humidityPct: nil, tempFallF: 6) == "Cooling")
        #expect(WeatherFacet.change.word(temperatureF: nil, humidityPct: nil, tempFallF: nil) == "No hours to compare")
    }

    @Test func missingIsNothingNotMild() {
        #expect(amounts(nil, nil, nil).values.allSatisfy { $0 == 0 })
    }

    @Test func rowsMapByLevel() {
        #expect(WeatherFacet.of(bin: "temp", level: "cold") == .coldDry)
        #expect(WeatherFacet.of(bin: "temp", level: "hot") == .heatHumid)
        #expect(WeatherFacet.of(bin: "temp", level: "mild") == nil)
        #expect(WeatherFacet.of(bin: "humidity", level: "dry") == .coldDry)
        #expect(WeatherFacet.of(bin: "humidity", level: "humid") == .heatHumid)
        #expect(WeatherFacet.of(bin: "temp_drop", level: "yes") == .change)
        #expect(WeatherFacet.of(bin: "pm25", level: "high") == nil)
        // Every weather bin the table has today lands somewhere for its notable level.
        for bin in ["temp", "humidity", "temp_drop", "heat_alert", "tag_coldAir"] {
            let levels = ["cold", "hot", "dry", "humid", "yes"]
            #expect(levels.contains { WeatherFacet.of(bin: bin, level: $0) != nil }, "\(bin)")
            #expect(AirProfile.Category.of(bin: bin) == .weather)
        }
    }
}
