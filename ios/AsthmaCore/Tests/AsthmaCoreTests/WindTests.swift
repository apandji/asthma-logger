import Foundation
import Testing
@testable import AsthmaCore

/// The `wind` bin (v7): three steps of wind speed, missing without a reading.
@Suite struct WindTests {
    @Test func bandEdges() {
        #expect(Banding.wind(mph: nil) == .unknown)
        #expect(Banding.wind(mph: 0) == .calm)
        #expect(Banding.wind(mph: 7.9) == .calm)
        #expect(Banding.wind(mph: 8) == .breezy)
        #expect(Banding.wind(mph: 18.9) == .breezy)
        #expect(Banding.wind(mph: 19) == .windy)
        #expect(Banding.wind(mph: -1) == .unknown)
    }

    static func frame(_ kind: FrameKind, wind: Double?) -> FeatureFrame {
        FrameBuilder.frame(id: UUID().uuidString, kind: kind, hourOfDay: 14, month: 4,
                           conditions: ConditionsInput(temperatureF: 60, humidityPct: 50, windMph: wind))
    }

    @Test func windyDaysComeThroughTheGateAsWeather() {
        // 10 inhaler moments, 8 of them windy; 30 ordinary moments, 3 windy.
        let frames = (0..<10).map { Self.frame(.attack, wind: $0 < 8 ? 24 : 5) }
            + (0..<30).map { Self.frame(.baseline, wind: $0 < 3 ? 22 : 6) }
        let report = Lift.compute(frames, gate: .default)
        let row = report.gatedRows.first { $0.bin == "wind" && $0.level == "windy" }
        #expect(row != nil)
        #expect(row?.attacksWith == 8 && row?.baselinesWith == 3)
        #expect(AirProfile.Category.of(bin: "wind") == .weather)
    }

    @Test func noReadingIsMissingNotCalm() {
        // Inhaler moments have wind; ordinary ones don't: nothing to compare against, so no wind row passes.
        let frames = (0..<10).map { _ in Self.frame(.attack, wind: 24) } + (0..<30).map { _ in Self.frame(.baseline, wind: nil) }
        let report = Lift.compute(frames, gate: .default)
        #expect(!report.gatedRows.contains { $0.bin == "wind" })
        #expect(Self.frame(.baseline, wind: nil).windBand == .unknown)
    }

    @Test func forecastHoursUseTheSameSteps() {
        let f = FrameBuilder.forecastFrame(id: "h", hourOfDay: 15, month: 4, ForecastConditions(temperatureF: 60, windMph: 21))
        #expect(f.windBand == .windy)
    }

    @Test func wordsForEachStep() {
        #expect(TheRead.noun("wind", "windy") == "Windy weather")
        #expect(Narrator.clause("wind", "calm") == "the air was still")
        #expect(OutlookCopy.phrase("wind", "breezy") == "a breeze")
    }
}
