import Foundation

/// Made-up Journals for demos and design reviews (Settings › Data sets). Each preset is about six weeks of
/// rescue and baseline moments whose air is ordinary, except that the preset's conditions turn up far more
/// often on rescue moments. They go through the real pipeline (frames → lift → profile → archetype), so
/// "Allergen-led" is computed, not forced. `DataSetPresetTests` checks each lands where it says.
public enum DataSetPreset: String, CaseIterable, Sendable, Identifiable {
    case stillLearning, allergenLed, airQualityLed, weatherSensitive, hotHazy, effortLed, mixed, nothingStandsOut

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .stillLearning: "Still learning"
        case .allergenLed: "Allergen-led"
        case .airQualityLed: "Air-quality-led"
        case .weatherSensitive: "Weather-sensitive"
        case .hotHazy: "Hot, hazy days"
        case .effortLed: "Effort-led"
        case .mixed: "Mixed"
        case .nothingStandsOut: "Nothing stands out"
        }
    }

    /// The archetype the preset should produce.
    public var expected: Archetype.Kind {
        switch self {
        case .stillLearning: .forming
        case .allergenLed: .biologics
        case .airQualityLed: .particulates
        case .weatherSensitive: .weather
        case .hotHazy: .hotHazy
        case .effortLed: .exertion
        case .mixed: .mixed
        case .nothingStandsOut: .noClearTrigger
        }
    }

    enum Raise: CaseIterable { case weed, ozone, pm25, humid, hot, drop, exercise }

    var raised: Set<Raise> {
        switch self {
        case .stillLearning, .allergenLed: [.weed]
        case .airQualityLed: [.ozone, .pm25]
        case .weatherSensitive: [.humid, .drop]
        case .hotHazy: [.hot, .ozone]
        case .effortLed: [.exercise]
        case .mixed: [.weed, .ozone, .humid]
        case .nothingStandsOut: []
        }
    }

    var counts: (rescue: Int, baseline: Int) { self == .stillLearning ? (4, 9) : (14, 40) }

    public struct Moment: Sendable {
        public let kind: MomentKind
        public let at: Date
        public let conditions: Conditions
        public let tags: Set<JournalTag>
        public let tagsReviewed: Bool
    }

    /// The preset's moments, oldest first, ending at `end`. Same seed, same Journal.
    public func moments(endingAt end: Date, calendar: Calendar = .current, seed: UInt64 = 17) -> [Moment] {
        var rng = SeededRandom(seed: seed &+ UInt64(rawValue.count) &* 7919)
        let (nr, nb) = counts
        let start = end.addingTimeInterval(-42 * 86_400)
        // Notes reviewed on every moment only where exertion is the story; elsewhere tags stay unread.
        let reviewed = raised.contains(.exercise)
        var out: [Moment] = []
        for i in 0..<(nr + nb) {
            let rescue = i < nr
            // Spread across the six weeks and across the waking day (baselines too: not only at app open).
            let day = start.addingTimeInterval(Double(rng.int(0, 41)) * 86_400)
            let hour = rng.int(7, 22), minute = rng.int(0, 59)
            let at = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
            func on(_ r: Raise) -> Bool { raised.contains(r) && rng.chance(rescue ? 0.72 : 0.08) }
            var t = rng.normal(64, 9), rh = rng.normal(50, 8), pm = abs(rng.normal(8, 3)), o3 = abs(rng.normal(36, 8))
            var weed = "Low", fall: Double? = rng.chance(0.5) ? abs(rng.normal(3, 2)) : nil
            if on(.weed) { weed = "High" }
            if on(.ozone) { o3 = rng.normal(82, 6) }
            if on(.pm25) { pm = rng.normal(42, 5) }
            if on(.humid) { rh = rng.normal(82, 5) }
            if on(.hot) { t = rng.normal(94, 2) }
            if on(.drop) { fall = rng.normal(19, 2) }
            let tags: Set<JournalTag> = on(.exercise) ? [.exercise] : []
            let src = "Data set"
            var c = Conditions(observations: [
                EnvObservation(signal: .temperature, value: t.rounded(), unit: "°F", asOf: at, source: src, spatialScale: .modelGrid),
                EnvObservation(signal: .humidity, value: min(99, max(10, rh.rounded())), unit: "%", asOf: at, source: src, spatialScale: .modelGrid),
                EnvObservation(signal: .pm25, value: (pm * 10).rounded() / 10, unit: "µg/m³", asOf: at, source: src, spatialScale: .station, distanceKm: 4.8),
                EnvObservation(signal: .ozone, value: o3.rounded(), unit: "ppb", asOf: at, source: src, spatialScale: .station, distanceKm: 4.8),
                EnvObservation(signal: .pollenWeed, value: weed == "High" ? 180 : 12, unit: "grains/m³", asOf: at, source: src,
                               spatialScale: .modelGrid, category: weed),
            ], fetchedAt: at)
            c.tempFallF = fall
            out.append(Moment(kind: rescue ? .rescue : .okay, at: at, conditions: c, tags: tags, tagsReviewed: reviewed))
        }
        return out.sorted { $0.at < $1.at }
    }
}

/// A small deterministic generator (SplitMix64), so a preset is the same Journal every time.
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func int(_ lo: Int, _ hi: Int) -> Int { lo + Int(unit() * Double(hi - lo + 1)) % (hi - lo + 1) }
    mutating func chance(_ p: Double) -> Bool { unit() < p }
    /// Box–Muller.
    mutating func normal(_ mean: Double, _ sd: Double) -> Double {
        let u = max(unit(), 1e-12), v = unit()
        return mean + sd * sqrt(-2 * log(u)) * cos(2 * .pi * v)
    }
}
