import Foundation

/// Several conditions at once: the days people with asthma are warned about in general (thunderstorm asthma,
/// wildfire smoke, hot hazy afternoons). Each is a rule over one frame, so a logged moment and a forecast hour
/// are read the same way, and each is a boolean bin (`combo_…`) in the same lift table as everything else.
/// Nothing here is personal until a row passes the gate: then it's surfaced as one of yours.
///
/// A combination is missing (nil) when any part it needs is missing. It is never guessed.
public enum Combination: String, CaseIterable, Sendable, Identifiable {
    /// A thunderstorm while any pollen is raised ("thunderstorm asthma").
    case stormPollen
    /// Fine particles raised with a detected fire within 50 km.
    case wildfireSmoke
    /// Hot with ozone raised.
    case hotHazy
    /// Cold and dry.
    case coldDry
    /// Little wind while fine particles are raised: the air isn't clearing.
    case stillHazy
    /// Windy while any pollen is raised.
    case windyPollen
    /// Pressure falling with humid air: weather coming in.
    case frontComing

    public var id: String { rawValue }
    public var bin: String { "combo_" + rawValue }

    public static func of(bin: String) -> Combination? {
        bin.hasPrefix("combo_") ? Combination(rawValue: String(bin.dropFirst(6))) : nil
    }

    /// The name on screen: a kind of day.
    public var title: String {
        switch self {
        case .stormPollen: "Thunderstorms with pollen"
        case .wildfireSmoke: "Wildfire smoke"
        case .hotHazy: "Hot, hazy air"
        case .coldDry: "Cold, dry air"
        case .stillHazy: "Still, hazy air"
        case .windyPollen: "Windy with pollen"
        case .frontComing: "Weather moving in"
        }
    }

    /// What it's made of, in plain words.
    public var parts: String {
        switch self {
        case .stormPollen: "A thunderstorm while pollen is up"
        case .wildfireSmoke: "Fine particles up, with a fire detected within 30 miles"
        case .hotHazy: "Hot, with ozone up"
        case .coldDry: "Cold and dry together"
        case .stillHazy: "Little wind while fine particles are up"
        case .windyPollen: "Wind while pollen is up"
        case .frontComing: "Pressure falling in humid air"
        }
    }

    /// Whether a weather description means a thunderstorm ("Thunderstorms", "Isolated Thunderstorms").
    public static func isStorm(_ condition: String) -> Bool { condition.lowercased().contains("thunder") }

    static func raised(_ p: PollutantBand) -> Bool? { p == .unknown ? nil : p != .low }

    /// Any pollen at moderate or high. Known as soon as one kind is known.
    static func pollenUp(_ f: FeatureFrame) -> Bool? {
        let known = [f.pollenTree, f.pollenGrass, f.pollenWeed].filter { $0 != .unknown }
        guard !known.isEmpty else { return nil }
        return known.contains { $0 == .moderate || $0 == .high }
    }

    /// Both parts must be known, unless one is a known "no" (then the combination is a known "no").
    static func both(_ a: Bool?, _ b: Bool?) -> Bool? {
        if a == false || b == false { return false }
        guard let a, let b else { return nil }
        return a && b
    }

    public func present(in f: FeatureFrame) -> Bool? {
        switch self {
        case .stormPollen: Self.both(f.storm, Self.pollenUp(f))
        case .wildfireSmoke: f.fireNearby
        case .hotHazy: Self.both(f.tempBand == .unknown ? nil : f.tempBand == .hot, Self.raised(f.ozoneBand))
        case .coldDry: Self.both(f.tempBand == .unknown ? nil : f.tempBand == .cold,
                                 f.humidityBand == .unknown ? nil : f.humidityBand == .dry)
        case .stillHazy: Self.both(f.windBand == .unknown ? nil : f.windBand == .calm, Self.raised(f.pm25Band))
        case .windyPollen: Self.both(f.windBand == .unknown ? nil : f.windBand == .windy, Self.pollenUp(f))
        case .frontComing: Self.both(f.pressureChange == .unknown ? nil : f.pressureChange == .falling,
                                     f.humidityBand == .unknown ? nil : f.humidityBand == .humid)
        }
    }
}

public extension LiftReport {
    /// Combinations that passed the gate for this person, strongest first: "this kind of day is one of yours".
    var combinations: [(combination: Combination, row: LiftRow)] {
        gatedRows.compactMap { r in
            guard r.level == "yes", let c = Combination.of(bin: r.bin) else { return nil }
            return (c, r)
        }.sorted { $0.row.lift > $1.row.lift }
    }
}
