import Foundation

/// Who you are with the air, in plain words (Personal Insights, Oct 17, 2026). Derived from the profile's
/// categories with a pattern; provisional by design ("So far…"), and it can change with the seasons, which is
/// what Profile History records. Names are a first pass for testing, not research-backed types.
public struct Archetype: Sendable, Equatable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case forming, noClearTrigger
        case weather, biologics, particulates, exertion
        case hotHazy, weatherAir, seasonal, airborne, weatherEffort, allergenEffort, outdoorEffort
        case mixed
    }

    public let kind: Kind
    /// The predominant categories, strongest first.
    public let categories: [AirProfile.Category]
    /// The rows behind them, for the evidence line.
    public let leads: [LiftRow]

    /// A category counts as predominant when it has a pattern at least this share of the strongest one's.
    public static let predominance = 0.6

    public init(profile: AirProfile, learned: Bool) {
        let patterns = profile.axes.filter { $0.status == .pattern }.sorted { $0.strength > $1.strength }
        guard learned else { self.init(kind: .forming, categories: [], leads: []); return }
        guard let top = patterns.first else { self.init(kind: .noClearTrigger, categories: [], leads: []); return }
        let main = patterns.filter { $0.strength >= top.strength * Self.predominance }
        let cats = main.map(\.category)
        let leads = main.compactMap(\.lead)
        let kind: Kind
        switch Set(cats) {
        case [.weather]: kind = .weather
        case [.biologics]: kind = .biologics
        case [.particulates]: kind = .particulates
        case [.exertion]: kind = .exertion
        case [.weather, .particulates]:
            let hot = main.first { $0.category == .weather }?.lead.map { ($0.bin == "temp" && $0.level == "hot") || $0.bin == "heat_alert" } ?? false
            kind = hot ? .hotHazy : .weatherAir
        case [.weather, .biologics]: kind = .seasonal
        case [.biologics, .particulates]: kind = .airborne
        case [.weather, .exertion]: kind = .weatherEffort
        case [.biologics, .exertion]: kind = .allergenEffort
        case [.particulates, .exertion]: kind = .outdoorEffort
        default: kind = .mixed
        }
        self.init(kind: kind, categories: cats, leads: leads)
    }

    public init(kind: Kind, categories: [AirProfile.Category], leads: [LiftRow]) {
        self.kind = kind
        self.categories = categories
        self.leads = leads
    }

    public var name: String { Self.name(kind) }

    public static func name(_ k: Kind) -> String {
        switch k {
        case .forming: "Still getting to know you"
        case .noClearTrigger: "Nothing stands out yet"
        case .weather: "Weather-sensitive"
        case .biologics: "Allergen-led"
        case .particulates: "Air-quality-led"
        case .exertion: "Effort-led"
        case .hotHazy: "Hot, hazy days"
        case .weatherAir: "Weather and air quality"
        case .seasonal: "Seasonal"
        case .airborne: "Airborne"
        case .weatherEffort: "Weather and effort"
        case .allergenEffort: "Allergens and effort"
        case .outdoorEffort: "Outdoor effort"
        case .mixed: "Mixed"
        }
    }

    /// One plain line about what that means.
    public var line: String {
        switch kind {
        case .forming: "Your profile appears once there are enough rescue and baseline moments to compare."
        case .noClearTrigger: "Nothing in the air shows up much more on your flare days than on others. That's worth knowing too."
        case .weather: "Your flare days follow the weather: heat, cold snaps or humid air."
        case .biologics: "Your flare days line up with living things in the air: pollen, pets or mold."
        case .particulates: "Your flare days line up with what's floating in the air: ozone, fine particles or smoke."
        case .exertion: "Your flare days come with effort: exercise, or laughing or crying hard."
        case .hotHazy: "Your flare days tend to be hot, with ozone or fine particles up."
        case .weatherAir: "Your flare days follow both the weather and what's in the air."
        case .seasonal: "Your flare days follow the seasons: the weather and what's growing."
        case .airborne: "Your flare days line up with what's in the air, living or not: pollen, particles, smoke."
        case .weatherEffort: "Your flare days come with effort in certain weather."
        case .allergenEffort: "Your flare days come with effort while pollen or other allergens are around."
        case .outdoorEffort: "Your flare days come with effort while the air is poor."
        case .mixed: "Several kinds of things show up on your flare days: \(categories.map { $0.title.lowercased() }.joined(separator: ", "))."
        }
    }

    /// "Most often: high ozone and heat." No counts.
    public var evidence: String? {
        guard !leads.isEmpty else { return nil }
        let parts = leads.prefix(3).map { TheRead.noun($0.bin, $0.level).lowercased() }
        let list = parts.count == 1 ? parts[0] : parts.dropLast().joined(separator: ", ") + " and " + parts.last!
        return "Most often: \(list)."
    }
}

// MARK: Triggers inside a category

public extension AirProfile {
    /// How a trigger shows up on flare moments compared with baseline ones. Words, not "correlation": the
    /// counts are small and this is a comparison of shares.
    enum Strength: String, Sendable, Equatable {
        case strong, some, leaning, none, notTracked

        /// Plain frequency, not statistics (owner, Oct 17: no "quantified self"). Counts are one tap away.
        public var word: String {
            switch self {
            case .strong: "Often"
            case .some: "Sometimes"
            case .leaning: "Maybe"
            case .none: "No more than usual"
            case .notTracked: "Not tracked yet"
            }
        }

        /// Gated with a gap of 30 points or more is strong; gated is some; more on flare days but not enough
        /// moments is leaning.
        public static func of(_ r: LiftRow) -> Strength {
            guard r.nAttacks > 0, r.nBaselines > 0 else { return .notTracked }
            let gap = r.attackRate - r.baselineRate
            if r.gated && gap > 0 { return gap >= 0.3 ? .strong : .some }
            // One moment is noise, not a leaning.
            return r.attacksWith >= 2 && gap > 0 ? .leaning : .none
        }
    }

    struct Trigger: Sendable, Equatable, Identifiable {
        public let name: String
        public let strength: Strength
        public let row: LiftRow?
        public var id: String { name }
    }

    /// Every trigger in a category, strongest first: one per bin (its level that leans most toward flare days),
    /// plus what isn't measured yet (tree and grass pollen until Ambee).
    static func triggers(_ c: Category, report: LiftReport) -> [Trigger] {
        let bins = Dictionary(grouping: report.rows.filter { Category.of(bin: $0.bin) == c }, by: \.bin)
        var out = bins.map { bin, rows -> Trigger in
            let best = rows.max { ($0.attackRate - $0.baselineRate) < ($1.attackRate - $1.baselineRate) }!
            let s = Strength.of(best)
            let name = (s == .none || s == .notTracked) ? Bins.label(bin) : TheRead.noun(best.bin, best.level)
            return Trigger(name: name, strength: s, row: best)
        }
        if c == .biologics {
            for missing in ["Tree pollen", "Grass pollen"] where !out.contains(where: { $0.name == missing }) {
                out.append(Trigger(name: missing, strength: .notTracked, row: nil))
            }
        }
        let rank: [Strength: Int] = [.strong: 0, .some: 1, .leaning: 2, .none: 3, .notTracked: 4]
        return out.sorted { (rank[$0.strength]!, $0.name) < (rank[$1.strength]!, $1.name) }
    }
}

// MARK: When

/// When your rescue moments happen, as plain counts (not a comparison: baseline moments are sampled when the
/// app opens, so their hours are biased).
public struct Rhythm: Sendable, Equatable {
    public let part: String
    public let count: Int
    public let total: Int

    /// The most common part of the day, once there are at least 3 moments and it holds at least 40% of them.
    public init?(dates: [Date], calendar: Calendar = .current) {
        guard dates.count >= 3 else { return nil }
        let parts = dates.map { Bins.hourPart(calendar.component(.hour, from: $0)) }
        let counts = Dictionary(grouping: parts, by: { $0 }).mapValues(\.count)
        guard let top = counts.max(by: { $0.value < $1.value }), Double(top.value) / Double(dates.count) >= 0.4 else { return nil }
        part = top.key; count = top.value; total = dates.count
    }

    /// "You tend to use your inhaler in the evening." (`count`/`total` stay internal: never on screen.)
    public var sentence: String { "You tend to use your inhaler in the \(part)." }
}

// MARK: Profile history

/// A dated snapshot of your profile, kept when it changes (or monthly), so Profile History can show how it
/// moves with the seasons.
public struct ProfileSnapshot: Codable, Sendable, Equatable, Identifiable {
    public let date: Date
    public let kind: Archetype.Kind
    /// Strength per category, in `AirProfile.Category.allCases` order.
    public let strengths: [Double]
    public var id: Date { date }

    public init(date: Date, kind: Archetype.Kind, strengths: [Double]) {
        self.date = date; self.kind = kind; self.strengths = strengths
    }

    public init(date: Date, profile: AirProfile, archetype: Archetype) {
        self.init(date: date, kind: archetype.kind, strengths: AirProfile.Category.allCases.map { profile.axis($0).strength })
    }

    /// The history with this snapshot added when the archetype changed or a month has passed.
    /// "Still getting to know you" is never recorded.
    public static func record(_ s: ProfileSnapshot, into history: [ProfileSnapshot]) -> [ProfileSnapshot] {
        guard s.kind != .forming else { return history }
        guard let last = history.last else { return [s] }
        let monthOld = s.date.timeIntervalSince(last.date) >= 30 * 86_400
        return last.kind != s.kind || monthOld ? history + [s] : history
    }
}
