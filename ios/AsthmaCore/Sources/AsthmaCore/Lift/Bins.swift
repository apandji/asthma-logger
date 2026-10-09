import Foundation

/// One column of the lift table: a name and how to read a frame's level for it (nil = no data).
public struct BinDef: Sendable {
    public let bin: String
    /// Boolean bins only report their "yes" level.
    public let isBoolean: Bool
    /// Which frames were sampled for this bin; nil = every frame. A frame outside it is missing for this
    /// bin: it counts in neither the level nor the bin's denominators (journal tags without a reviewed note).
    public let sampled: (@Sendable (FeatureFrame) -> Bool)?
    public let levelOf: @Sendable (FeatureFrame) -> String?

    public init(bin: String, isBoolean: Bool, sampled: (@Sendable (FeatureFrame) -> Bool)? = nil,
                levelOf: @escaping @Sendable (FeatureFrame) -> String?) {
        self.bin = bin
        self.isBoolean = isBoolean
        self.sampled = sampled
        self.levelOf = levelOf
    }

    /// The frames this bin counts: all of them, or only the sampled ones.
    func population(_ frames: [FeatureFrame]) -> [FeatureFrame] {
        guard let sampled else { return frames }
        return frames.filter(sampled)
    }
}

public enum Bins {
    static func hourPart(_ h: Int) -> String {
        if h >= 5 && h < 12 { return "morning" }
        if h >= 12 && h < 17 { return "afternoon" }
        if h >= 17 && h < 22 { return "evening" }
        return "night"
    }

    static func yesNo(_ b: Bool) -> String { b ? "yes" : "no" }

    /// v1 order matches `web/src/lib/insights/lift.ts`; v2 bins are appended so v1 output is unchanged.
    public static let all: [BinDef] = [
        BinDef(bin: "pm25", isBoolean: false) { $0.pm25Band == .unknown ? nil : $0.pm25Band.rawValue },
        BinDef(bin: "ozone", isBoolean: false) { $0.ozoneBand == .unknown ? nil : $0.ozoneBand.rawValue },
        BinDef(bin: "pollen_weed", isBoolean: false) { $0.pollenWeed == .unknown ? nil : $0.pollenWeed.rawValue },
        BinDef(bin: "temp", isBoolean: false) { $0.tempBand == .unknown ? nil : $0.tempBand.rawValue },
        BinDef(bin: "humidity", isBoolean: false) { $0.humidityBand == .unknown ? nil : $0.humidityBand.rawValue },
        BinDef(bin: "smoke_at_point", isBoolean: true) { yesNo($0.smokeAtPoint) },
        BinDef(bin: "heat_alert", isBoolean: true) { yesNo($0.heatAlert) },
        BinDef(bin: "hour", isBoolean: false) { hourPart($0.hourOfDay) },
        // v2
        BinDef(bin: "place", isBoolean: false) { $0.place?.rawValue },
        BinDef(bin: "indoor_outdoor", isBoolean: false) { f in
            guard let io = f.indoorOutdoor, io != .unknown else { return nil }
            return io.rawValue
        },
    ] + JournalTag.allCases.map { tag in
        // Only frames with a reviewed note: an unreviewed moment is missing, not "no".
        BinDef(bin: "tag_\(tag.rawValue)", isBoolean: true, sampled: { $0.tagsSampled }) { f in
            f.tagsSampled ? yesNo(f.tags.contains(tag)) : nil
        }
    }

    public static func label(_ bin: String) -> String {
        switch bin {
        case "pm25": return "PM2.5"
        case "ozone": return "Ozone"
        case "pollen_weed": return "Weed pollen"
        case "temp": return "Temperature"
        case "humidity": return "Humidity"
        case "smoke_at_point": return "Smoke-like air"
        case "heat_alert": return "Heat alert"
        case "hour": return "Time of day"
        case "place": return "Place"
        case "indoor_outdoor": return "Indoors / outdoors"
        default:
            if bin.hasPrefix("tag_"), let tag = JournalTag(rawValue: String(bin.dropFirst(4))) {
                return tag.label
            }
            return bin
        }
    }
}
