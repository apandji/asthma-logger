import Foundation
import Testing
@testable import AsthmaCore

@Suite struct ReadingFamilyTests {
    private let t = Date(timeIntervalSince1970: 16 * 3600)

    private func obs(_ s: Signal, _ v: Double, _ source: String, _ scale: SpatialScale, km: Double? = nil, category: String? = nil) -> EnvObservation {
        EnvObservation(signal: s, value: v, unit: "µg/m³", asOf: t, source: source, spatialScale: scale, distanceKm: km, category: category)
    }

    @Test func everySignalHasOneFamily() {
        for s in Signal.allCases where s != .aqi {
            #expect(ReadingFamily.allCases.filter { $0.signals.contains(s) } == [ReadingFamily.of(s)])
        }
        #expect(ReadingFamily.of(.aqi) == .pollutants)
        #expect(!ReadingFamily.pollutants.signals.contains(.aqi))
    }

    @Test func familySplitsConditions() {
        let c = Conditions(observations: [
            obs(.temperature, 88, "Apple Weather", .modelGrid), obs(.pm25, 30, "OpenAQ", .station, km: 3),
            obs(.aqi, 80, "AirNow", .region), obs(.pollenTree, 120, "Ambee", .city),
        ])
        #expect(ReadingFamily.weather.observations(in: c).map(\.signal) == [.temperature])
        #expect(ReadingFamily.pollutants.observations(in: c).map(\.signal) == [.pm25, .aqi])
        #expect(ReadingFamily.allergens.observations(in: c).map(\.signal) == [.pollenTree])
    }

    @Test func provenanceIsHonestAndShort() {
        #expect(ObservationCopy.provenance([]) == nil)
        // Near station only: plain outdoor, never "at your location".
        #expect(ObservationCopy.provenance([obs(.pm25, 9, "OpenAQ", .station, km: 3.2)]) == "Outdoor · OpenAQ 2 mi")
        // Any regional reading makes the whole family regional; each source once, at its nearest.
        let mixed = [obs(.pm25, 9, "OpenAQ", .station, km: 3.2), obs(.ozone, 40, "OpenAQ", .station, km: 9),
                     obs(.aqi, 38, "AirNow", .region, km: 17.7)]
        #expect(ObservationCopy.provenance(mixed) == "Regional outdoor · OpenAQ 2 mi · AirNow 11 mi")
        #expect(ObservationCopy.provenance([obs(.temperature, 70, "Apple Weather", .modelGrid)]) == "Modeled outdoor · Apple Weather")
        #expect(ObservationCopy.provenance([obs(.pm25, 9, "OpenAQ", .station, km: 0.4)]) == "Outdoor · OpenAQ <1 mi")
    }

    @Test func aqiSummaryNamesTheMainPollutant() {
        #expect(ObservationCopy.aqiSummary(obs(.aqi, 38, "AirNow", .region, category: "Good · ozone")) == "AQI 38 · Good · mostly ozone")
        #expect(ObservationCopy.aqiSummary(obs(.aqi, 72, "AirNow", .region, category: "Moderate")) == "AQI 72 · OK")
        #expect(ObservationCopy.aqiSummary(obs(.aqi, 151, "AirNow", .region)) == "AQI 151 · Not good")
    }
}
