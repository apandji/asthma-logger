import Foundation

/// The Insights radar (FigJam "On Insights", Oct 17, 2026): the lift table folded into five trigger families of things
/// that show up on flare days. Code finds the shape; nothing here is a model or a prediction.
///
/// Each axis's strength is the biggest gap, among its rows, between how often a level shows up on flare
/// moments and how often on baseline ones (`attackRate - baselineRate`, 0…1). A gap is a share of moments,
/// so it's bounded and honest where lift can run to infinity on small counts. Raw counts travel with it.
public struct AirProfile: Sendable, Equatable {
    /// The guideline trigger families (GINA, NAEPP; docs/research/trigger-lens.md), five on the radar: the air's
    /// three, then the two about you. Stress and strong feelings are tags only, never sampled on baselines, so
    /// they stay off the radar until they have a signal that can be compared. Raw values are stored in Profile
    /// History: keep them (`exertion` reads "Exercise").
    public enum Category: String, Sendable, CaseIterable, Identifiable {
        case weather, biologics, particulates, exertion, infections
        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .weather: "Weather"
            case .biologics: "Allergens"
            case .particulates: "Irritants and pollution"
            case .exertion: "Exercise"
            // Colds going around and colds you mention. Never "infection" about you.
            case .infections: "Colds and flu"
            }
        }

        /// What goes in it, in plain words.
        public var covers: String {
            switch self {
            case .weather: "Cold, dry air, heat and humidity, sudden changes"
            case .biologics: "Pollen, mold, pets"
            case .particulates: "Fine particles, ozone, smoke, fumes, strong scents"
            case .exertion: "Being active in the hour before"
            case .infections: "Flu-like illness around, colds you mention"
            }
        }

        /// About you, not the air: printed in the text colour, never on the map.
        public var isBody: Bool { self == .exertion || self == .infections }

        /// Which lift-table bins belong here. Time and place (hour, season, place, indoor/outdoor) and stress
        /// sit outside the families.
        public static func of(bin: String) -> Category? {
            switch bin {
            case "temp", "humidity", "temp_drop", "heat_alert", "tag_coldAir", "pressure_change", "storm": .weather
            case "pollen_weed", "pollen_tree", "pollen_grass", "tag_pets", "tag_mold": .biologics
            case "pm25", "ozone", "smoke_at_point", "tag_smoke", "tag_dust", "tag_cleaningProducts", "tag_strongScents",
                 "tag_cooking": .particulates
            case "tag_exercise", "exertion": .exertion
            case "ili", "tag_coldOrFlu": .infections
            default: nil
            }
        }
    }

    public enum Status: String, Sendable, Equatable {
        /// At least one row passed the gate.
        case pattern
        /// Something leans toward flare days, but not enough moments yet to call it.
        case early
        /// Sampled, and nothing here shows up more on flare days.
        case nothing
        /// Nothing sampled yet (e.g. exertion before any reviewed voice notes).
        case notTracked
    }

    public struct Axis: Sendable, Equatable, Identifiable {
        public let category: Category
        /// 0…1: the biggest flare-vs-baseline gap among this family's rows.
        public let strength: Double
        public let status: Status
        /// The row behind the strength (gated first), for the counts.
        public let lead: LiftRow?
        public var id: Category { category }

        public init(category: Category, strength: Double, status: Status, lead: LiftRow?) {
            self.category = category; self.strength = strength; self.status = status; self.lead = lead
        }
    }

    public let axes: [Axis]

    public init(axes: [Axis]) { self.axes = axes }

    public init(report: LiftReport) {
        axes = Category.allCases.map { cat in
            let rows = report.rows.filter { Category.of(bin: $0.bin) == cat }
            guard rows.contains(where: { $0.nAttacks > 0 && $0.nBaselines > 0 }) else {
                return Axis(category: cat, strength: 0, status: .notTracked, lead: nil)
            }
            let leaning = rows.filter { $0.attacksWith > 0 && $0.attackRate > $0.baselineRate }
            func gap(_ r: LiftRow) -> Double { r.attackRate - r.baselineRate }
            let gated = leaning.filter(\.gated)
            if let lead = gated.max(by: { gap($0) < gap($1) }) {
                return Axis(category: cat, strength: min(1, gap(lead)), status: .pattern, lead: lead)
            }
            if let lead = leaning.max(by: { gap($0) < gap($1) }) {
                return Axis(category: cat, strength: min(1, gap(lead)), status: .early, lead: lead)
            }
            return Axis(category: cat, strength: 0, status: .nothing, lead: nil)
        }
    }

    public func axis(_ c: Category) -> Axis { axes.first { $0.category == c }! }

    /// The strongest family with a pattern, for the headline.
    public var leading: Axis? {
        axes.filter { $0.status == .pattern }.max { $0.strength < $1.strength }
    }


    /// The presentation's made-up person (Design crit › Insights state › learned): pollen-led, as the rest
    /// of the demo story ("Weed pollen showed up on 9 of 14 flare days vs 6 of 40 baseline days").
    public static let demoPerson: AirProfile = {
        func row(_ bin: String, _ level: String, _ a: Int, _ na: Int, _ b: Int, _ nb: Int, gated: Bool) -> LiftRow {
            let ar = Double(a) / Double(na), br = Double(b) / Double(nb)
            return LiftRow(bin: bin, level: level, attacksWith: a, baselinesWith: b, nAttacks: na, nBaselines: nb,
                           attackRate: ar, baselineRate: br, lift: br > 0 ? ar / br : .infinity, gated: gated)
        }
        let weed = row("pollen_weed", "high", 9, 14, 6, 40, gated: true)
        let ozone = row("ozone", "high", 6, 14, 7, 40, gated: true)
        let humid = row("humidity", "humid", 5, 14, 9, 40, gated: false)
        let exercise = row("tag_exercise", "yes", 2, 6, 2, 15, gated: false)
        func gap(_ r: LiftRow) -> Double { r.attackRate - r.baselineRate }
        return AirProfile(axes: [
            Axis(category: .weather, strength: gap(humid), status: .early, lead: humid),
            Axis(category: .biologics, strength: gap(weed), status: .pattern, lead: weed),
            Axis(category: .particulates, strength: gap(ozone), status: .pattern, lead: ozone),
            Axis(category: .exertion, strength: gap(exercise), status: .early, lead: exercise),
            Axis(category: .infections, strength: 0, status: .notTracked, lead: nil),
        ])
    }()
}
