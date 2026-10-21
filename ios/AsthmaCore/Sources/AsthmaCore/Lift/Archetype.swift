import Foundation

/// Who you are with your triggers, in plain words (Personal Insights, Oct 17; trigger lens, Oct 21, 2026).
/// Provisional by design ("So far…"), and it can change with the seasons, which is what Profile History records.
///
/// Built, not looked up (docs/design/archetypes.md):
/// 1. Not learned yet → "Still getting to know you". Learned, no family with a gated pattern → "Nothing stands out".
/// 2. The families with a pattern at least `predominance` of the strongest one's are predominant.
/// 3. One → its own name; Weather is named by its group (cold, dry air · heat and humidity · sudden change).
/// 4. Two → a known pair has its own name (`pairs`); any other pair is "<lead>, with <companion>".
/// 5. Three or more → "Mixed".
/// Names are a first pass for testing, not research-backed types, and never diagnostic.
public struct Archetype: Sendable, Equatable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case forming, noClearTrigger
        // One family leads. Weather by its group; `weather` when its lead row has no group.
        case weather, coldAir, heatHumid, suddenChange, biologics, particulates, exertion, infections
        // Known pairs.
        case hotHazy, coldEffort, stormSeason, seasonal, coldSeason
        /// Any other pair: named from its lead and companion (`name` on the archetype, kept in the snapshot).
        case paired
        case mixed
        // Retired Oct 21 (the four-family profile). Still read from Profile History, never produced.
        case weatherAir, airborne, weatherEffort, allergenEffort, outdoorEffort
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
        let facet = main.first { $0.category == .weather }?.lead.flatMap { WeatherFacet.of(bin: $0.bin, level: $0.level) }
        let kind: Kind = switch cats.count {
        case 1: Self.single(cats[0], facet: facet)
        case 2: Self.pair(Set(cats), facet: facet) ?? .paired
        default: .mixed
        }
        self.init(kind: kind, categories: cats, leads: leads)
    }

    public init(kind: Kind, categories: [AirProfile.Category], leads: [LiftRow]) {
        self.kind = kind
        self.categories = categories
        self.leads = leads
    }

    static func single(_ c: AirProfile.Category, facet: WeatherFacet?) -> Kind {
        switch c {
        case .weather:
            switch facet {
            case .coldDry: .coldAir
            case .heatHumid: .heatHumid
            case .change: .suddenChange
            case nil: .weather
            }
        case .biologics: .biologics
        case .particulates: .particulates
        case .exertion: .exertion
        case .infections: .infections
        }
    }

    /// The pairs with a name of their own: combinations the research describes as a kind of person, not every
    /// pair. The weather group decides which one.
    static func pair(_ cats: Set<AirProfile.Category>, facet: WeatherFacet?) -> Kind? {
        switch (cats, facet) {
        case ([.weather, .particulates], .heatHumid): .hotHazy
        case ([.weather, .exertion], .coldDry): .coldEffort
        case ([.weather, .biologics], .change): .stormSeason
        case ([.weather, .biologics], _): .seasonal
        case ([.weather, .infections], .coldDry), ([.weather, .infections], .change): .coldSeason
        default: nil
        }
    }

    public var name: String {
        guard kind == .paired, categories.count == 2 else { return Self.name(kind) }
        return "\(Self.name(Self.single(categories[0], facet: facet))), with \(companion(categories[1]))"
    }

    /// The weather group behind this archetype, if weather is in it.
    public var facet: WeatherFacet? {
        guard categories.contains(.weather) else { return nil }
        return leads.lazy.compactMap { WeatherFacet.of(bin: $0.bin, level: $0.level) }.first
    }

    public static func name(_ k: Kind) -> String {
        switch k {
        case .forming: "Still getting to know you"
        case .noClearTrigger: "Nothing stands out yet"
        case .weather: "Weather-sensitive"
        case .coldAir: "Cold-air sensitive"
        case .heatHumid: "Heat-sensitive"
        case .suddenChange: "Sensitive to sudden changes"
        case .biologics: "Allergen-led"
        case .particulates: "Air-quality-led"
        case .exertion: "Effort-led"
        case .infections: "Comes with colds"
        case .hotHazy: "Hot, hazy days"
        case .coldEffort: "Cold air and effort"
        case .stormSeason: "Storm season"
        case .seasonal: "Seasonal"
        case .coldSeason: "Cold season"
        case .paired: "Two things together"
        case .mixed: "Mixed"
        case .weatherAir: "Weather and air quality"
        case .airborne: "Airborne"
        case .weatherEffort: "Weather and effort"
        case .allergenEffort: "Allergens and effort"
        case .outdoorEffort: "Outdoor effort"
        }
    }

    /// "with poor air", "with colds going around".
    private func companion(_ c: AirProfile.Category) -> String {
        switch c {
        case .weather:
            switch facet {
            case .coldDry: "cold air"
            case .heatHumid: "heat"
            case .change: "sudden changes"
            case nil: "the weather"
            }
        case .biologics: "allergens"
        case .particulates: "poor air"
        case .exertion: "effort"
        case .infections: "colds going around"
        }
    }

    /// One plain line about what that means.
    public var line: String {
        switch kind {
        case .forming: "Your profile appears once there are enough rescue and baseline moments to compare."
        case .noClearTrigger: "Nothing we track shows up much more on your flare days than on others. That's worth knowing too."
        case .weather: "Your flare days follow the weather."
        case .coldAir: "Your flare days tend to come with cold or dry air."
        case .heatHumid: "Your flare days tend to be hot, or heavy and humid."
        case .suddenChange: "Your flare days tend to follow a sharp drop in temperature or a change in the weather."
        case .biologics: "Your flare days line up with living things in the air: pollen, pets or mold."
        case .particulates: "Your flare days line up with what's floating in the air: ozone, fine particles or smoke."
        case .exertion: "Your flare days come with effort: exercise, or laughing or crying hard."
        case .infections: "Your flare days tend to come when colds and flu are going around."
        case .hotHazy: "Your flare days tend to be hot, with ozone or fine particles up."
        case .coldEffort: "Your flare days come with effort in cold or dry air."
        case .stormSeason: "Your flare days come when the weather turns while pollen is up."
        case .seasonal: "Your flare days follow the seasons: the weather and what's growing."
        case .coldSeason: "Your flare days come in the cold season: cold air, and colds going around."
        case .paired: "Your flare days come with \(companion(categories[0])), and often \(companion(categories[1])) too."
        case .mixed: "Several kinds of things show up on your flare days: \(mixedList)."
        case .weatherAir: "Your flare days followed both the weather and what's in the air."
        case .airborne: "Your flare days lined up with what's in the air, living or not."
        case .weatherEffort: "Your flare days came with effort in certain weather."
        case .allergenEffort: "Your flare days came with effort while allergens were around."
        case .outdoorEffort: "Your flare days came with effort while the air was poor."
        }
    }

    /// "the weather, poor air and effort".
    private var mixedList: String {
        let names = categories.map(companion)
        return names.count > 1 ? names.dropLast().joined(separator: ", ") + " and " + names.last! : names.joined()
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

    /// What each family will track that isn't measured yet, so the detail area shows the whole family, not
    /// only what has data: pollen kinds and mould spores until Ambee, pressure and wind until they're bins,
    /// PM10 and NO₂ (read on the rail, not yet in the table).
    public static let notYet: [Category: [String]] = [
        .weather: ["Pressure swings", "Wind", "Thunderstorms"],
        .biologics: ["Tree pollen", "Grass pollen", "Mould spores"],
        .particulates: ["Coarse dust (PM10)", "Traffic fumes (NO₂)"],
        .exertion: [],
        .infections: ["Coming down with something"],
    ]

    /// Every trigger in a category: the biggest flare-vs-baseline gap first (that's the one that leads the
    /// profile), then the rest by strength, then what isn't measured yet.
    static func triggers(_ c: Category, report: LiftReport) -> [Trigger] {
        let bins = Dictionary(grouping: report.rows.filter { Category.of(bin: $0.bin) == c }, by: \.bin)
        var out = bins.map { bin, rows -> Trigger in
            let best = rows.max { ($0.attackRate - $0.baselineRate) < ($1.attackRate - $1.baselineRate) }!
            let s = Strength.of(best)
            let name = (s == .none || s == .notTracked) ? Bins.label(bin) : TheRead.noun(best.bin, best.level)
            return Trigger(name: name, strength: s, row: best)
        }
        // Bins the table tracks but has no rows for yet (a sharp temperature drop before one has happened):
        // listed, so the family reads complete. Journal tags wait for a reviewed note, except in Self, which
        // is nothing but tags: without them the card would open on nothing.
        for def in Bins.all where Category.of(bin: def.bin) == c && bins[def.bin] == nil
            && (!def.bin.hasPrefix("tag_") || c == .exertion) {
            out.append(Trigger(name: Bins.label(def.bin), strength: .notTracked, row: nil))
        }
        for missing in notYet[c] ?? [] where !out.contains(where: { $0.name == missing }) {
            out.append(Trigger(name: missing, strength: .notTracked, row: nil))
        }
        let rank: [Strength: Int] = [.strong: 0, .some: 1, .leaning: 2, .none: 3, .notTracked: 4]
        func gap(_ t: Trigger) -> Double { t.row.map { $0.attackRate - $0.baselineRate } ?? 0 }
        return out.sorted { a, b in
            if rank[a.strength]! != rank[b.strength]! { return rank[a.strength]! < rank[b.strength]! }
            if gap(a) != gap(b) { return gap(a) > gap(b) }
            return a.name < b.name
        }
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
    /// The archetype's name when it was kept: a `paired` name is built from its families, so it's stored.
    public let name: String?
    /// Strength per category, in `AirProfile.Category.allCases` order.
    public let strengths: [Double]
    public var id: Date { date }

    public init(date: Date, kind: Archetype.Kind, name: String? = nil, strengths: [Double]) {
        self.date = date; self.kind = kind; self.name = name; self.strengths = strengths
    }

    public init(date: Date, profile: AirProfile, archetype: Archetype) {
        self.init(date: date, kind: archetype.kind, name: archetype.name, strengths: AirProfile.Category.allCases.map { profile.axis($0).strength })
    }

    public var title: String { name ?? Archetype.name(kind) }

    /// The history with this snapshot added when the archetype changed or a month has passed.
    /// "Still getting to know you" is never recorded.
    public static func record(_ s: ProfileSnapshot, into history: [ProfileSnapshot]) -> [ProfileSnapshot] {
        guard s.kind != .forming else { return history }
        guard let last = history.last else { return [s] }
        let monthOld = s.date.timeIntervalSince(last.date) >= 30 * 86_400
        return last.kind != s.kind || last.title != s.title || monthOld ? history + [s] : history
    }
}
