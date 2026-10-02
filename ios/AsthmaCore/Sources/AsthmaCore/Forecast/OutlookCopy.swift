import Foundation

/// Plain words for a look-ahead window. Same voice as the template headline: inhaler "times",
/// raw counts, no ratio, and never a prediction ("looks more like", not "you will").
public enum OutlookCopy {
    /// "8 PM–10 PM looks more like the times you used your inhaler: evening and high ozone."
    public static func headline(_ w: RiskWindow, timeRange: String) -> String {
        let phrases = w.drivers.map { phrase($0.bin, $0.level) }
        guard !phrases.isEmpty else { return "\(timeRange) looks more like the times you used your inhaler." }
        return "\(timeRange) looks more like the times you used your inhaler: \(phrases.joined(separator: " and "))."
    }

    /// One line per driver: "Evening: 4 of your 10 inhaler times, 0 of 24 usual days."
    /// Plus a note when the air-quality forecast was missing for these hours.
    public static func evidence(_ w: RiskWindow) -> [String] {
        var lines = w.drivers.map {
            "\(capitalized(phrase($0.bin, $0.level))): \($0.attacksWith) of your \(w.nAttacks) inhaler times, \($0.baselinesWith) of \(w.nBaselines) usual days."
        }
        if w.isPartial { lines.append("No air-quality forecast for these hours, so this is weather only.") }
        return lines
    }

    /// A bin level as a short noun phrase: "evening", "high ozone", "humid air".
    public static func phrase(_ bin: String, _ level: String) -> String {
        switch bin {
        case "pm25": return "\(level) PM2.5"
        case "ozone": return "\(level) ozone"
        case "pollen_weed": return level == "none" ? "no weed pollen" : "\(level) weed pollen"
        case "temp": return "\(level) weather"
        case "humidity": return level == "ok" ? "normal humidity" : "\(level) air"
        case "smoke_at_point": return level == "yes" ? "signs of smoke" : "no signs of smoke"
        case "heat_alert": return level == "yes" ? "a heat alert" : "no heat alert"
        case "hour", "season": return level
        default: return "\(Bins.label(bin).lowercased()) \(level)"
        }
    }

    static func capitalized(_ s: String) -> String {
        guard let first = s.first else { return s }
        return first.uppercased() + s.dropFirst()
    }
}
