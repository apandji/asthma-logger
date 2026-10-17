import Foundation

/// What a journal moment is. Stored raw values for rescue and baseline match `FrameKind`, so logs
/// saved before maintenance existed read back unchanged. On-screen titles follow
/// `docs/design/felt-air-language.md` (Rescue / Standard / Baseline — never "I'm okay" or "attack").
public enum MomentKind: String, Codable, Sendable, CaseIterable {
    /// Used the rescue inhaler. The only kind that counts as an inhaler use in patterns.
    case rescue = "attack"
    /// Took the standard (maintenance / controller) inhaler. Recorded, but never part of the lift table:
    /// it's routine, not a sign of a hard breathing moment.
    case maintenance
    /// A baseline sample (ordinary moment, no inhaler), captured automatically or as first capture.
    case okay = "baseline"

    public init(_ kind: FrameKind) {
        self = kind == .attack ? .rescue : .okay
    }

    /// The frame kind for insights, or nil when this moment doesn't feed patterns.
    public var frameKind: FrameKind? {
        switch self {
        case .rescue: .attack
        case .okay: .baseline
        case .maintenance: nil
        }
    }

    public var title: String {
        switch self {
        case .rescue: "Rescue"
        case .maintenance: "Standard"
        case .okay: "Baseline"
        }
    }
}

/// A moment's outdoor conditions as a density weave: each factor low / medium / high, or absent when
/// there's no reading. Uses the v1 bands as they are (`Banding`), so the weave and the patterns agree.
///
/// Temperature and humidity bands carry direction (cold/mild/hot, dry/ok/humid). Here "high" means far
/// from comfortable either way and `words` says which way. v1 has no middle step for them, so they're
/// only ever low or high until the bands gain one (a `binSpecVersion` change).
public struct WeaveSpec: Sendable, Equatable {
    public enum Level: Int, Sendable, Comparable, CaseIterable {
        case low = 0, medium, high
        public static func < (a: Level, b: Level) -> Bool { a.rawValue < b.rawValue }
    }

    public enum Factor: String, Sendable, CaseIterable {
        case air, humidity, temperature, pollen
    }

    public var levels: [Factor: Level]
    public var words: [Factor: String]

    public init(levels: [Factor: Level] = [:], words: [Factor: String] = [:]) {
        self.levels = levels
        self.words = words
    }

    public init(_ c: ConditionsInput) {
        var levels: [Factor: Level] = [:]
        var words: [Factor: String] = [:]

        // Air: the worst of PM2.5, ozone and the official AQI. A station can sit just under a cut-off
        // while AirNow's AQI (a NowCast over hours) is over it; the worse one wins.
        let bands = [Banding.pm25(c.pm25), Banding.ozone(ppb: c.ozonePpb)].filter { $0 != .unknown }
        var air: Level? = bands.max(by: { Self.rank($0) < Self.rank($1) }).map(Self.level)
        if let aqi = c.aqi {
            let fromAQI: Level = aqi <= 50 ? .low : aqi <= 100 ? .medium : .high
            air = max(air ?? fromAQI, fromAQI)
        }
        levels[.air] = air
        if let l = levels[.air] { words[.air] = ["low", "moderate", "high"][l.rawValue] }

        switch Banding.humidity(c.humidityPct) {
        case .ok: levels[.humidity] = .low; words[.humidity] = "comfortable"
        case .dry: levels[.humidity] = .high; words[.humidity] = "dry"
        case .humid: levels[.humidity] = .high; words[.humidity] = "humid"
        case .unknown: break
        }

        switch Banding.temp(c.temperatureF, isExtreme: c.isExtremeTemp) {
        case .mild: levels[.temperature] = .low; words[.temperature] = "mild"
        case .cold: levels[.temperature] = .high; words[.temperature] = "cold"
        case .hot: levels[.temperature] = .high; words[.temperature] = "hot"
        case .unknown: break
        }

        switch Banding.pollen(risk: c.pollenWeedRisk) {
        case .none, .low: levels[.pollen] = .low; words[.pollen] = "low"
        case .moderate: levels[.pollen] = .medium; words[.pollen] = "moderate"
        case .high: levels[.pollen] = .high; words[.pollen] = "high"
        case .unknown: break
        }

        self.init(levels: levels, words: words)
    }

    public var isEmpty: Bool { levels.isEmpty }

    /// "Air moderate · humid · hot", in a fixed order, only for factors that have a reading.
    public var summary: String {
        Factor.allCases.compactMap { f in
            guard let w = words[f] else { return nil }
            switch f {
            case .air: return "Air \(w)"
            case .pollen: return "Pollen \(w)"
            case .humidity, .temperature: return w
            }
        }.joined(separator: " · ")
    }

    static func rank(_ b: PollutantBand) -> Int {
        switch b { case .low: 0; case .moderate: 1; case .high: 2; case .unknown: -1 }
    }

    static func level(_ b: PollutantBand) -> Level {
        switch b { case .moderate: .medium; case .high: .high; default: .low }
    }
}
