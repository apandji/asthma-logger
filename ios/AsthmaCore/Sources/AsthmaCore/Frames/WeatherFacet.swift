import Foundation

/// Weather read by what it does to airways rather than by instrument (docs/design/weather-grouping.md,
/// option B): cold, dry air; heat and humidity; sudden change. Display only. The lift table keeps its
/// instrument bins (`temp`, `humidity`, `temp_drop`, `heat_alert`); a facet is a reading of them, never a bin
/// of its own, so the risk score doesn't count temperature twice.
public enum WeatherFacet: String, Sendable, CaseIterable, Identifiable {
    case coldDry, heatHumid, change
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .coldDry: "Cold, dry air"
        case .heatHumid: "Heat and humidity"
        case .change: "Sudden change"
        }
    }

    /// 0…1 between two edges, either direction.
    static func ramp(_ v: Double, from a: Double, to b: Double) -> Double {
        guard v.isFinite else { return 0 }
        return max(0, min(1, (v - a) / (b - a)))
    }

    /// How cold: 0 at 57°F, full at 32°F (the sky wash's scale).
    static func cold(_ f: Double?) -> Double { f.map { ramp($0, from: 57, to: 32) } ?? 0 }
    /// How dry: 0 at 40%, full at 15%.
    static func dry(_ h: Double?) -> Double { h.map { ramp($0, from: 40, to: 15) } ?? 0 }
    /// How hot: 0 at 73°F, full at 98°F.
    static func heat(_ f: Double?) -> Double { f.map { ramp($0, from: 73, to: 98) } ?? 0 }
    /// How muggy: 0 at 65%, full at 95%, and only from 60°F up (cold damp air isn't this).
    static func muggy(_ h: Double?, _ f: Double?) -> Double {
        guard let h, let f, f >= 60 else { return 0 }
        return ramp(h, from: 65, to: 95)
    }
    /// How far it fell in the 3 hours before: 0 at 3°F, full at the sharp-drop edge.
    static func fall(_ d: Double?) -> Double { d.map { ramp($0, from: 3, to: TempDrop.sharpDropF) } ?? 0 }

    /// 0…1: how much of this facet is in the air now. Missing readings count as nothing, not as mild.
    public func amount(temperatureF: Double?, humidityPct: Double?, tempFallF: Double?) -> Double {
        switch self {
        case .coldDry: max(Self.cold(temperatureF), Self.dry(humidityPct))
        case .heatHumid: max(Self.heat(temperatureF), Self.muggy(humidityPct, temperatureF))
        case .change: Self.fall(tempFallF)
        }
    }

    /// The plain word for it now. Facts, never effects ("Cold and dry", not "hard on your airways").
    public func word(temperatureF: Double?, humidityPct: Double?, tempFallF: Double?) -> String {
        switch self {
        case .coldDry:
            let c = Self.cold(temperatureF) > 0, d = Self.dry(humidityPct) > 0
            return c && d ? "Cold and dry" : c ? "Cold" : d ? "Dry" : "Not cold or dry"
        case .heatHumid:
            let h = Self.heat(temperatureF) > 0, m = Self.muggy(humidityPct, temperatureF) > 0
            return h && m ? "Hot and humid" : h ? "Hot" : m ? "Humid" : "Not hot or humid"
        case .change:
            guard let d = tempFallF else { return "No hours to compare" }
            if TempDrop.band(d) == .sharp { return "A sharp drop" }
            return Self.fall(d) > 0 ? "Cooling" : "Steady"
        }
    }

    /// Which facet a lift-table row belongs to, by bin and level (the Insights card's grouping). Nil for
    /// rows that aren't weather, and for the ordinary levels (mild, ok, no).
    public static func of(bin: String, level: String) -> WeatherFacet? {
        switch (bin, level) {
        case ("temp", "cold"), ("humidity", "dry"), ("tag_coldAir", "yes"): .coldDry
        case ("temp", "hot"), ("humidity", "humid"), ("heat_alert", "yes"): .heatHumid
        case ("temp_drop", "yes"), ("pressure_change", "yes"), ("storm", "yes"): .change
        default: nil
        }
    }
}
