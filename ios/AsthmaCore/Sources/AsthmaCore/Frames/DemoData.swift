import Foundation

/// Synthetic late-summer diary, identical to `web/src/lib/insights/demo-frames.ts`.
/// Story: high ozone + afternoons on inhaler days; usual days are milder mornings.
public enum DemoData {
    public static func frames() -> [FeatureFrame] {
        typealias A = (Int, PollutantBand, PollutantBand, PollenLevel, TempBand, HumidityBand, Bool, Bool)
        // hour, ozone, pm25, weed pollen, temp, humidity, smoke, heat alert
        let attacks: [A] = [
            (15, .high, .moderate, .moderate, .hot, .ok, false, true),
            (16, .high, .low, .high, .hot, .dry, false, true),
            (14, .high, .moderate, .moderate, .hot, .ok, false, false),
            (18, .high, .low, .low, .mild, .ok, false, false),
            (17, .high, .high, .high, .hot, .humid, true, true),
            (15, .moderate, .low, .high, .hot, .ok, false, false),
            (19, .high, .moderate, .moderate, .mild, .ok, false, false),
            (13, .high, .low, .moderate, .hot, .dry, false, true),
            (16, .high, .moderate, .low, .hot, .ok, false, false),
            (20, .moderate, .low, .moderate, .mild, .humid, false, false),
        ]
        var out: [FeatureFrame] = []
        var i = 0
        for a in attacks {
            out.append(FeatureFrame(id: "demo-\(i)", kind: .attack, hourOfDay: a.0, season: .summer,
                                    tempBand: a.4, humidityBand: a.5, pm25Band: a.2, ozoneBand: a.1,
                                    pollenWeed: a.3, smokeAtPoint: a.6, heatAlert: a.7))
            i += 1
        }
        for d in 0..<24 {
            let morning = d % 3 != 0
            out.append(FeatureFrame(
                id: "demo-\(i)", kind: .baseline,
                hourOfDay: morning ? 8 + (d % 3) : 12 + (d % 4),
                season: .summer,
                tempBand: morning ? .mild : (d % 5 == 0 ? .hot : .mild),
                humidityBand: d % 4 == 0 ? .humid : .ok,
                pm25Band: d % 7 == 0 ? .moderate : .low,
                ozoneBand: morning ? .low : (d % 6 == 0 ? .moderate : .low),
                pollenWeed: d % 5 == 0 ? .low : .none,
                smokeAtPoint: false,
                heatAlert: !morning && d % 8 == 0
            ))
            i += 1
        }
        return out
    }
}
