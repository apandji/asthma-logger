import Foundation
import Testing
@testable import AsthmaCore

@Suite struct AmbeeTests {
    // Shapes as in Ambee's documentation (not yet checked against a live response).
    let airJSON = #"""
    {"message":"success","stations":[{"PM25":12.4,"PM10":20.1,"OZONE":41.2,"NO2":9.3,"SO2":1.1,"CO":0.3,"AQI":52,
     "aqiInfo":{"pollutant":"PM2.5","concentration":12.4,"category":"Moderate"},"createdAt":"2026-10-17T14:00:00.000Z"}]}
    """#
    let pollenJSON = #"""
    {"message":"Success","data":[{"Count":{"grass_pollen":12,"tree_pollen":3,"weed_pollen":180},
     "Risk":{"grass_pollen":"Low","tree_pollen":"Low","weed_pollen":"High"},
     "Species":{"Weed":{"Ragweed":170,"Mugwort":10},"Tree":{"Oak":3}},"updatedAt":"2026-10-17T14:00:00.000Z"}]}
    """#

    @Test func decodesAndMergesDocumentedShapes() throws {
        let air = try JSONDecoder().decode(Ambee.AirQualityResponse.self, from: Data(airJSON.utf8))
        let pollen = try JSONDecoder().decode(Ambee.PollenResponse.self, from: Data(pollenJSON.utf8))
        let weather = Ambee.WeatherResponse.Payload(temperature: 71, humidity: 64, time: 1_792_245_600)
        let hours = Ambee.hours(airQuality: air, pollen: pollen, weather: [weather], isForecast: false)
        let h = try #require(hours.first { $0.pm25 != nil })
        #expect(h.pm25 == 12.4)
        #expect(h.aqiPollutant == "PM2.5")
        #expect(h.weedPollen == 180)
        #expect(h.weedSpecies == "Ragweed")
    }

    @Test func observationsCarrySourceAndOutdoorScale() {
        let h = AmbeeHour(date: .now, pm25: 10, ozone: 30, weedPollen: 50, temperatureF: 60)
        let obs = h.observations(source: Ambee.demoSource)
        #expect(obs.count == 4)
        #expect(obs.allSatisfy { $0.source == Ambee.demoSource && $0.spatialScale == .modelGrid })
        #expect(obs.contains { $0.signal == .pollenWeed && $0.unit == "grains/m³" })
    }

    @Test func demoIsDeterministicAndSeasonal() async throws {
        let demo = DemoAmbee()
        let lat = 38.6, lon = -90.25
        let f = ISO8601DateFormatter()
        let sept = f.date(from: "2026-09-02T14:00:00Z")!, april = f.date(from: "2026-04-20T14:00:00Z")!
        let a = try await demo.latest(latitude: lat, longitude: lon, at: sept)
        let b = try await demo.latest(latitude: lat, longitude: lon, at: sept)
        #expect(a == b)
        #expect((a.weedPollen ?? 0) > (a.treePollen ?? 0))   // ragweed season
        let spring = try await demo.latest(latitude: lat, longitude: lon, at: april)
        #expect((spring.treePollen ?? 0) > (spring.weedPollen ?? 0))
    }

    @Test func historyFeedsTheLookBack() async throws {
        let now = ISO8601DateFormatter().date(from: "2026-10-17T18:00:00Z")!
        let hist = try await DemoAmbee().history(latitude: 38.6, longitude: -90.25, from: now.addingTimeInterval(-48 * 3600), to: now)
        #expect(hist.count == 49)
        let lb = Ambee.lookBack(at: now, history: hist)
        #expect(lb.pm25Now.hours >= 3)
        #expect(lb.pm25Earlier.hours >= 21)
        #expect(lb.pm25Level != nil)
    }
}
